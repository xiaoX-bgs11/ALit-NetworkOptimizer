#include "pch.h"
#include "CommandRunner.h"
#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <wincrypt.h>
#include <fstream>
#include <sstream>
#include <vector>

#pragma comment(lib, "crypt32.lib")

namespace NetOpt {

// Convert UTF-8 to UTF-16
static std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), nullptr, 0);
    std::wstring result(size, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), &result[0], size);
    return result;
}

// Convert UTF-16 to UTF-8
static std::string WideToUtf8(const std::wstring& str) {
    if (str.empty()) return std::string();
    int size = WideCharToMultiByte(CP_UTF8, 0, str.c_str(), (int)str.size(), nullptr, 0, nullptr, nullptr);
    std::string result(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, str.c_str(), (int)str.size(), &result[0], size, nullptr, nullptr);
    return result;
}

std::wstring RunCommand(const std::wstring& command, int* exitCode) {
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.bInheritHandle = TRUE;
    sa.lpSecurityDescriptor = nullptr;

    HANDLE hReadPipe = nullptr, hWritePipe = nullptr;
    if (!CreatePipe(&hReadPipe, &hWritePipe, &sa, 0)) {
        if (exitCode) *exitCode = -1;
        return L"";
    }
    SetHandleInformation(hReadPipe, HANDLE_FLAG_INHERIT, 0);

    // Build the command line: cmd.exe /C <command>
    std::wstring cmdLine = L"cmd.exe /C " + command;

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.hStdError = hWritePipe;
    si.hStdOutput = hWritePipe;
    si.dwFlags |= STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    // CreateProcessW requires a writable command line buffer
    std::vector<wchar_t> cmdBuf(cmdLine.begin(), cmdLine.end());
    cmdBuf.push_back(0);

    BOOL success = CreateProcessW(
        nullptr,
        cmdBuf.data(),
        nullptr, nullptr,
        TRUE,
        CREATE_NO_WINDOW,
        nullptr, nullptr,
        &si, &pi
    );

    CloseHandle(hWritePipe);

    if (!success) {
        CloseHandle(hReadPipe);
        if (exitCode) *exitCode = -1;
        return L"Failed to create process";
    }

    // Read output
    std::string output;
    constexpr DWORD BUF_SIZE = 4096;
    char buffer[BUF_SIZE];
    DWORD bytesRead = 0;

    while (ReadFile(hReadPipe, buffer, BUF_SIZE, &bytesRead, nullptr) && bytesRead > 0) {
        output.append(buffer, bytesRead);
    }

    WaitForSingleObject(pi.hProcess, 30000); // 30 second timeout

    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    if (exitCode) *exitCode = (int)code;

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    CloseHandle(hReadPipe);

    return Utf8ToWide(output);
}

bool RunCommandElevated(const std::wstring& command, const std::wstring& params) {
    SHELLEXECUTEINFOW sei;
    ZeroMemory(&sei, sizeof(sei));
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"runas";
    sei.lpFile = command.c_str();
    sei.lpParameters = params.c_str();
    sei.nShow = SW_HIDE;

    if (!ShellExecuteExW(&sei)) {
        return false;
    }

    if (sei.hProcess) {
        WaitForSingleObject(sei.hProcess, 30000);
        CloseHandle(sei.hProcess);
    }
    return true;
}

std::wstring RunPowerShell(const std::wstring& script, int* exitCode) {
    // Escape the script for command-line passing
    // Use -EncodedCommand for reliability with special characters
    std::string utf8Script = WideToUtf8(script);
    DWORD encodedLen = 0;
    CryptBinaryToStringA(
        (const BYTE*)utf8Script.data(),
        (DWORD)utf8Script.size(),
        CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
        nullptr, &encodedLen
    );
    std::string encoded(encodedLen, 0);
    CryptBinaryToStringA(
        (const BYTE*)utf8Script.data(),
        (DWORD)utf8Script.size(),
        CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
        encoded.data(), &encodedLen
    );
    // Trim trailing null
    if (!encoded.empty() && encoded.back() == 0) encoded.pop_back();

    std::wstring cmd = L"powershell.exe -NoProfile -NonInteractive -EncodedCommand " + Utf8ToWide(encoded);
    return RunCommand(cmd, exitCode);
}

bool RunPowerShellElevated(const std::wstring& script) {
    // Write script to temp file
    wchar_t tempPath[MAX_PATH];
    GetTempPathW(MAX_PATH, tempPath);
    std::wstring scriptPath = std::wstring(tempPath) + L"netopt_script.ps1";

    std::ofstream file(scriptPath, std::ios::binary);
    std::string utf8 = WideToUtf8(script);
    // Write UTF-8 BOM for PowerShell compatibility
    file.write("\xEF\xBB\xBF", 3);
    file.write(utf8.data(), utf8.size());
    file.close();

    std::wstring params = L"-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + L"\"";
    bool result = RunCommandElevated(L"powershell.exe", params);

    // Clean up temp file
    DeleteFileW(scriptPath.c_str());

    return result;
}

bool IsRunningAsAdmin() {
    BOOL isAdmin = FALSE;
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
    PSID adminGroup = nullptr;

    if (AllocateAndInitializeSid(&ntAuthority, 2,
        SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS,
        0, 0, 0, 0, 0, 0, &adminGroup)) {
        CheckTokenMembership(nullptr, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }

    return isAdmin != FALSE;
}

bool RestartAsAdmin() {
    wchar_t exePath[MAX_PATH];
    if (!GetModuleFileNameW(nullptr, exePath, MAX_PATH)) {
        return false;
    }

    SHELLEXECUTEINFOW sei;
    ZeroMemory(&sei, sizeof(sei));
    sei.cbSize = sizeof(sei);
    sei.lpVerb = L"runas";
    sei.lpFile = exePath;
    sei.nShow = SW_SHOWNORMAL;

    return ShellExecuteExW(&sei) != FALSE;
}

} // namespace NetOpt
