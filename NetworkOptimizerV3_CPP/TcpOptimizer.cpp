#include "pch.h"
#include "TcpOptimizer.h"
#include "CommandRunner.h"
#include <windows.h>
#include <algorithm>
#include <cwctype>

namespace NetOpt {

TcpOptimizer::TcpOptimizer() {}
TcpOptimizer::~TcpOptimizer() {}

// ============================================================
// Registry helpers
// ============================================================

bool TcpOptimizer::SetRegistryValue(const std::wstring& keyPath,
                                     const std::wstring& valueName,
                                     DWORD value) {
    HKEY hKey;
    LONG result = RegCreateKeyExW(HKEY_LOCAL_MACHINE, keyPath.c_str(),
                                   0, nullptr, 0, KEY_SET_VALUE,
                                   nullptr, &hKey, nullptr);
    if (result != ERROR_SUCCESS) return false;

    result = RegSetValueExW(hKey, valueName.c_str(), 0, REG_DWORD,
                            (const BYTE*)&value, sizeof(value));
    RegCloseKey(hKey);
    return result == ERROR_SUCCESS;
}

bool TcpOptimizer::SetRegistryValue(const std::wstring& keyPath,
                                     const std::wstring& valueName,
                                     const std::wstring& value) {
    HKEY hKey;
    LONG result = RegCreateKeyExW(HKEY_LOCAL_MACHINE, keyPath.c_str(),
                                   0, nullptr, 0, KEY_SET_VALUE,
                                   nullptr, &hKey, nullptr);
    if (result != ERROR_SUCCESS) return false;

    result = RegSetValueExW(hKey, valueName.c_str(), 0, REG_SZ,
                            (const BYTE*)value.c_str(),
                            (DWORD)((value.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(hKey);
    return result == ERROR_SUCCESS;
}

bool TcpOptimizer::DeleteRegistryValue(const std::wstring& keyPath,
                                        const std::wstring& valueName) {
    HKEY hKey;
    LONG result = RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath.c_str(),
                                 0, KEY_SET_VALUE, &hKey);
    if (result != ERROR_SUCCESS) return false;

    result = RegDeleteValueW(hKey, valueName.c_str());
    RegCloseKey(hKey);
    // ERROR_FILE_NOT_FOUND is OK - value doesn't exist
    return result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND;
}

std::wstring TcpOptimizer::GetRegistryValue(const std::wstring& keyPath,
                                             const std::wstring& valueName) const {
    HKEY hKey;
    LONG result = RegOpenKeyExW(HKEY_LOCAL_MACHINE, keyPath.c_str(),
                                 0, KEY_READ, &hKey);
    if (result != ERROR_SUCCESS) return L"";

    DWORD type = 0;
    DWORD dataSize = 0;
    result = RegQueryValueExW(hKey, valueName.c_str(), nullptr, &type,
                               nullptr, &dataSize);
    if (result != ERROR_SUCCESS) {
        RegCloseKey(hKey);
        return L"";
    }

    std::vector<BYTE> data(dataSize);
    result = RegQueryValueExW(hKey, valueName.c_str(), nullptr, &type,
                               data.data(), &dataSize);
    RegCloseKey(hKey);

    if (result != ERROR_SUCCESS) return L"";

    if (type == REG_DWORD && dataSize >= sizeof(DWORD)) {
        DWORD val = *(DWORD*)data.data();
        return std::to_wstring(val);
    } else if (type == REG_SZ || type == REG_EXPAND_SZ) {
        return std::wstring((wchar_t*)data.data(),
                            dataSize / sizeof(wchar_t) - 1);
    }
    return L"";
}

// ============================================================
// Netsh helper
// ============================================================

OptResult TcpOptimizer::RunNetshCommand(const std::wstring& command) {
    OptResult result;
    int exitCode = 0;
    std::wstring output = RunCommand(command, &exitCode);
    result.success = (exitCode == 0);
    result.detail = output;
    if (!result.success) {
        // Trim output for error message
        if (output.size() > 500) output = output.substr(0, 500);
        result.message = L"Command failed: " + output;
    } else {
        result.message = L"OK";
    }
    return result;
}

// ============================================================
// Interface discovery
// ============================================================

std::vector<std::wstring> TcpOptimizer::GetActiveInterfaceGuids() const {
    std::vector<std::wstring> guids;
    // Query active interfaces via PowerShell
    std::wstring script =
        L"Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | "
        L"Select-Object -ExpandProperty InterfaceGuid";
    int exitCode = 0;
    std::wstring output = RunPowerShell(script, &exitCode);
    if (exitCode != 0) return guids;

    std::wistringstream stream(output);
    std::wstring line;
    while (std::getline(stream, line)) {
        // Trim whitespace
        line.erase(0, line.find_first_not_of(L" \t\r\n"));
        line.erase(line.find_last_not_of(L" \t\r\n") + 1);
        if (!line.empty() && line.front() == L'{' && line.back() == L'}') {
            guids.push_back(line);
        }
    }
    return guids;
}

std::map<std::wstring, std::wstring> TcpOptimizer::GetInterfaceNames() const {
    std::map<std::wstring, std::wstring> names;
    std::wstring script =
        L"Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | "
        L"ForEach-Object { $_.InterfaceGuid + '|' + $_.Name }";
    int exitCode = 0;
    std::wstring output = RunPowerShell(script, &exitCode);
    if (exitCode != 0) return names;

    std::wistringstream stream(output);
    std::wstring line;
    while (std::getline(stream, line)) {
        line.erase(0, line.find_first_not_of(L" \t\r\n"));
        line.erase(line.find_last_not_of(L" \t\r\n") + 1);
        size_t pos = line.find(L'|');
        if (pos != std::wstring::npos) {
            std::wstring guid = line.substr(0, pos);
            std::wstring name = line.substr(pos + 1);
            names[guid] = name;
        }
    }
    return names;
}

// ============================================================
// Optimization item builders
// ============================================================

std::vector<OptimizationItem> TcpOptimizer::BuildGamingItems() const {
    std::vector<OptimizationItem> items;

    // --- TCP Global Settings (netsh) ---

    // 1. TCP Auto-Tuning: Use "normal" for best balance
    // Disabled auto-tuning caps throughput; normal allows dynamic window scaling
    {
        OptimizationItem item;
        item.id = L"tcp_autotuning";
        item.displayName = L"TCP \u81ea\u52a8\u8c03\u4f18 (Auto-Tuning)";
        item.description = L"\u542f\u7528 TCP \u63a5\u6536\u7a97\u53e3\u81ea\u52a8\u8c03\u4f18\uff0c\u52a8\u6001\u8c03\u6574\u63a5\u6536\u7f13\u51b2\u533a\u5927\u5c0f\u3002"
                           L"\u201cnormal\u201d \u6a21\u5f0f\u5141\u8bb8\u7cfb\u7edf\u6839\u636e\u7f51\u7edc\u72b6\u51b5\u52a8\u6001\u4f18\u5316\u541e\u5410\u91cf\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global autotuninglevel=normal";
        item.revertCommand = L"netsh interface tcp set global autotuninglevel=normal";
        items.push_back(item);
    }

    // 2. ECN (Explicit Congestion Notification)
    {
        OptimizationItem item;
        item.id = L"tcp_ecn";
        item.displayName = L"ECN \u663e\u5f0f\u62e5\u585e\u901a\u77e5";
        item.description = L"\u542f\u7528 ECN \u5141\u8bb8\u8def\u7531\u5668\u5728\u4e22\u5305\u524d\u901a\u77e5\u62e5\u585e\uff0c\u51cf\u5c11\u91cd\u4f20\u3002"
                           L"\u5bf9\u4e8e\u652f\u6301 ECN \u7684\u670d\u52a1\u5668\u53ef\u63d0\u5347\u541e\u5410\u91cf\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global ecncapability=enabled";
        item.revertCommand = L"netsh interface tcp set global ecncapability=disabled";
        items.push_back(item);
    }

    // 3. RSS (Receive Side Scaling)
    {
        OptimizationItem item;
        item.id = L"tcp_rss";
        item.displayName = L"RSS \u63a5\u6536\u7aef\u7f29\u653e";
        item.description = L"\u542f\u7528 RSS \u5c06\u7f51\u7edc\u4e2d\u65ad\u5206\u53d1\u5230\u591a\u4e2a CPU \u6838\u5fc3\uff0c"
                           L"\u63d0\u5347\u591a\u6838\u5904\u7406\u5668\u4e0b\u7684\u7f51\u7edc\u541e\u5410\u91cf\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global rss=enabled";
        item.revertCommand = L"netsh interface tcp set global rss=enabled";
        items.push_back(item);
    }

    // 4. TCP Timestamps - disable for gaming (saves 12 bytes per packet)
    {
        OptimizationItem item;
        item.id = L"tcp_timestamps";
        item.displayName = L"TCP \u65f6\u95f4\u6233 (Timestamps)";
        item.description = L"\u7981\u7528 TCP \u65f6\u95f4\u6233\u53ef\u51cf\u5c11\u6bcf\u4e2a\u6570\u636e\u5305 12 \u5b57\u8282\u5f00\u9500\uff0c"
                           L"\u5728\u4f4e\u5ef6\u8fdf PvP \u573a\u666f\u4e2d\u53ef\u5fae\u5999\u63d0\u5347\u54cd\u5e94\u901f\u5ea6\u3002"
                           L"\u6ce8\uff1a\u5f71\u54cd RTT \u4f30\u7b97\u7cbe\u5ea6\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global timestamps=disabled";
        item.revertCommand = L"netsh interface tcp set global timestamps=enabled";
        items.push_back(item);
    }

    // 5. Initial RTO (Retransmission Timeout) - lower for faster recovery
    {
        OptimizationItem item;
        item.id = L"tcp_initialrto";
        item.displayName = L"TCP \u521d\u59cb\u91cd\u4f20\u8d85\u65f6 (Initial RTO)";
        item.description = L"\u5c06\u521d\u59cb RTO \u8bbe\u4e3a 300ms\uff0c\u52a0\u5feb\u8fde\u63a5\u5efa\u7acb\u548c\u91cd\u4f20\u6062\u590d\u901f\u5ea6\u3002"
                           L"\u9ed8\u8ba4\u503c\u4e3a 1000ms\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global initialrto=300";
        item.revertCommand = L"netsh interface tcp set global initialrto=1000";
        items.push_back(item);
    }

    // 6. Congestion Provider - CTCP for gaming
    // CTCP provides better throughput on high-latency links while maintaining responsiveness
    {
        OptimizationItem item;
        item.id = L"tcp_congestion";
        item.displayName = L"TCP \u62e5\u585e\u63a7\u5236 (Congestion Provider)";
        item.description = L"\u4f7f\u7528 CTCP (Compound TCP) \u62e5\u585e\u63a7\u5236\u7b97\u6cd5\uff0c"
                           L"\u5728\u9ad8\u5ef6\u8fdf\u94fe\u8def\u4e0a\u63d0\u4f9b\u66f4\u597d\u7684\u541e\u5410\u91cf\u548c\u54cd\u5e94\u6027\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp";
        item.revertCommand = L"netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic";
        items.push_back(item);
    }

    // 7. RSC (Receive Segment Coalescing) - enable for throughput
    {
        OptimizationItem item;
        item.id = L"tcp_rsc";
        item.displayName = L"RSC \u63a5\u6536\u6bb5\u5408\u5e76";
        item.description = L"\u542f\u7528 RSC \u5c06\u591a\u4e2a\u5c0f\u6570\u636e\u5305\u5408\u5e76\u4e3a\u4e00\u4e2a\u5927\u5757\uff0c"
                           L"\u51cf\u5c11 CPU \u5f00\u9500\uff0c\u63d0\u5347\u541e\u5410\u91cf\u3002";
        item.category = OptCategory::TcpStack;
        item.applyCommand = L"netsh interface tcp set global rsc=enabled";
        item.revertCommand = L"netsh interface tcp set global rsc=enabled";
        items.push_back(item);
    }

    // --- Registry: TCP/IP Parameters ---

    // 8. TcpNoDelay - disable Nagle's algorithm (CRITICAL for PvP)
    // Nagle's algorithm batches small packets, adding latency to interactive apps
    {
        OptimizationItem item;
        item.id = L"tcp_nodelay";
        item.displayName = L"TcpNoDelay \u7981\u7528 Nagle \u7b97\u6cd5";
        item.description = L"\u7981\u7528 Nagle \u7b97\u6cd5\uff0c\u907f\u514d\u5c0f\u6570\u636e\u5305\u88ab\u6279\u5904\u7406\u5ef6\u8fdf\u53d1\u9001\u3002"
                           L"\u8fd9\u662f PvP \u573a\u666f\u6700\u91cd\u8981\u7684\u4f18\u5316\u4e4b\u4e00\uff0c\u76f4\u63a5\u51cf\u5c11\u4ea4\u4e92\u5ef6\u8fdf\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"TcpNoDelay";
        item.regApplyValue = L"1";
        item.regRevertValue = L"";  // Delete to restore default
        items.push_back(item);
    }

    // 9. TcpAckFrequency - ACK every segment (CRITICAL for PvP)
    // Default sends ACKs after every 2nd segment, delaying feedback
    {
        OptimizationItem item;
        item.id = L"tcp_ackfreq";
        item.displayName = L"TcpAckFrequency = 1";
        item.description = L"\u8bbe\u7f6e\u6bcf\u63a5\u6536\u4e00\u4e2a TCP \u6bb5\u5c31\u53d1\u9001 ACK\uff0c"
                           L"\u52a0\u5feb\u670d\u52a1\u5668\u7684\u62e5\u585e\u7a97\u53e3\u66f4\u65b0\u901f\u5ea6\u3002"
                           L"\u9ed8\u8ba4\u4e3a\u6bcf 2 \u4e2a\u6bb5\u53d1\u9001 ACK\uff0c\u8bbe\u4e3a 1 \u53ef\u663e\u8457\u964d\u4f4e\u5ef6\u8fdf\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"TcpAckFrequency";
        item.regApplyValue = L"1";
        item.regRevertValue = L"";
        items.push_back(item);
    }

    // 10. TCP Window Scaling (Tcp1323Opts)
    {
        OptimizationItem item;
        item.id = L"tcp_1323";
        item.displayName = L"TCP \u7a97\u53e3\u7f29\u653e (Tcp1323Opts)";
        item.description = L"\u542f\u7528 TCP \u7a97\u53e3\u7f29\u653e\uff0c\u5141\u8bb8\u4f7f\u7528\u5927\u4e8e 64KB \u7684\u63a5\u6536\u7a97\u53e3\u3002"
                           L"\u5bf9\u9ad8\u5e26\u5bbd\u94fe\u8def\u81f3\u5173\u91cd\u8981\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"Tcp1323Opts";
        item.regApplyValue = L"1";  // 1 = window scaling only (no timestamps)
        item.regRevertValue = L"1";
        items.push_back(item);
    }

    // 11. DefaultSendWindow
    {
        OptimizationItem item;
        item.id = L"tcp_sendwindow";
        item.displayName = L"\u9ed8\u8ba4\u53d1\u9001\u7a97\u53e3 (DefaultSendWindow)";
        item.description = L"\u589e\u5927\u9ed8\u8ba4\u53d1\u9001\u7f13\u51b2\u533a\uff0c\u63d0\u5347\u4e0a\u4f20\u541e\u5410\u91cf\u3002"
                           L"\u8bbe\u4e3a 65535 \u5b57\u8282\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"DefaultSendWindow";
        item.regApplyValue = L"65535";
        item.regRevertValue = L"";
        items.push_back(item);
    }

    // 12. DefaultReceiveWindow
    {
        OptimizationItem item;
        item.id = L"tcp_recvwindow";
        item.displayName = L"\u9ed8\u8ba4\u63a5\u6536\u7a97\u53e3 (DefaultReceiveWindow)";
        item.description = L"\u589e\u5927\u9ed8\u8ba4\u63a5\u6536\u7f13\u51b2\u533a\uff0c\u63d0\u5347\u4e0b\u8f7d\u541e\u5410\u91cf\u3002"
                           L"\u8bbe\u4e3a 65535 \u5b57\u8282\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"DefaultReceiveWindow";
        item.regApplyValue = L"65535";
        item.regRevertValue = L"";
        items.push_back(item);
    }

    // 13. MaxUserPort - increase ephemeral port range
    {
        OptimizationItem item;
        item.id = L"tcp_maxuserport";
        item.displayName = L"\u6700\u5927\u7528\u6237\u7aef\u53e3 (MaxUserPort)";
        item.description = L"\u6269\u5927\u4e34\u65f6\u7aef\u53e3\u8303\u56f4\uff0c\u907f\u514d\u7aef\u53e3\u8017\u5c3d\u3002"
                           L"\u8bbe\u4e3a 65534\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"MaxUserPort";
        item.regApplyValue = L"65534";
        item.regRevertValue = L"";
        items.push_back(item);
    }

    // 14. TcpTimedWaitDelay - reduce TIME_WAIT
    {
        OptimizationItem item;
        item.id = L"tcp_timedwait";
        item.displayName = L"TIME_WAIT \u5ef6\u8fdf (TcpTimedWaitDelay)";
        item.description = L"\u51cf\u5c11 TCP \u8fde\u63a5\u5173\u95ed\u540e\u7684 TIME_WAIT \u7b49\u5f85\u65f6\u95f4\uff0c"
                           L"\u52a0\u5feb\u8fde\u63a5\u91ca\u653e\u548c\u91cd\u7528\u3002\u8bbe\u4e3a 30 \u79d2\u3002";
        item.category = OptCategory::RegistryTcp;
        item.isRegistry = true;
        item.regKeyPath = kTcpParamsPath;
        item.regValueName = L"TcpTimedWaitDelay";
        item.regApplyValue = L"30";
        item.regRevertValue = L"";
        items.push_back(item);
    }

    // --- System Profile / Network Throttling ---

    // 15. NetworkThrottlingIndex - disable network throttling
    // Windows throttles network interrupts to 10 packets per millisecond by default
    {
        OptimizationItem item;
        item.id = L"sys_netthrottle";
        item.displayName = L"\u7981\u7528\u7f51\u7edc\u9650\u6d41 (NetworkThrottlingIndex)";
        item.description = L"\u7981\u7528 Multimedia Class Scheduler \u7684\u7f51\u7edc\u4e2d\u65ad\u9650\u6d41\u3002"
                           L"\u9ed8\u8ba4\u9650\u5236\u6bcf\u6beb\u79d2 10 \u4e2a\u7f51\u7edc\u4e2d\u65ad\uff0c\u7981\u7528\u540e\u53ef\u63d0\u5347\u541e\u5410\u91cf\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kSystemProfilePath;
        item.regValueName = L"NetworkThrottlingIndex";
        item.regApplyValue = L"4294967295";  // 0xFFFFFFFF
        item.regRevertValue = L"10";
        items.push_back(item);
    }

    // 16. SystemResponsiveness - set to 0 for maximum gaming CPU
    {
        OptimizationItem item;
        item.id = L"sys_responsiveness";
        item.displayName = L"\u7cfb\u7edf\u54cd\u5e94\u6027 (SystemResponsiveness)";
        item.description = L"\u8bbe\u4e3a 0\uff0c\u5c06\u6700\u5927 CPU \u8d44\u6e90\u5206\u914d\u7ed9\u6e38\u620f\u548c\u4ea4\u4e92\u5e94\u7528\u3002"
                           L"\u9ed8\u8ba4\u503c 20 \u8868\u793a\u4fdd\u7559 20% CPU \u7ed9\u540e\u53f0\u4efb\u52a1\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kSystemProfilePath;
        item.regValueName = L"SystemResponsiveness";
        item.regApplyValue = L"0";
        item.regRevertValue = L"20";
        items.push_back(item);
    }

    // 17. Games Task - GPU Priority
    {
        OptimizationItem item;
        item.id = L"game_gpu_priority";
        item.displayName = L"\u6e38\u620f GPU \u4f18\u5148\u7ea7";
        item.description = L"\u63d0\u5347\u6e38\u620f\u4efb\u52a1\u7684 GPU \u4f18\u5148\u7ea7\uff0c\u51cf\u5c11\u56fe\u5f62\u5ef6\u8fdf\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kGamesTaskPath;
        item.regValueName = L"GPU Priority";
        item.regApplyValue = L"8";
        item.regRevertValue = L"2";
        items.push_back(item);
    }

    // 18. Games Task - Priority
    {
        OptimizationItem item;
        item.id = L"game_priority";
        item.displayName = L"\u6e38\u620f\u4efb\u52a1\u4f18\u5148\u7ea7";
        item.description = L"\u63d0\u5347\u6e38\u620f\u8fdb\u7a0b\u7684 CPU \u8c03\u5ea6\u4f18\u5148\u7ea7\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kGamesTaskPath;
        item.regValueName = L"Priority";
        item.regApplyValue = L"6";
        item.regRevertValue = L"2";
        items.push_back(item);
    }

    // 19. Games Task - Scheduling Category
    {
        OptimizationItem item;
        item.id = L"game_sched_cat";
        item.displayName = L"\u6e38\u620f\u8c03\u5ea6\u7c7b\u522b";
        item.description = L"\u8bbe\u4e3a High\uff0c\u7ed9\u4e88\u6e38\u620f\u8fdb\u7a0b\u66f4\u9ad8\u7684\u8c03\u5ea6\u4f18\u5148\u7ea7\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kGamesTaskPath;
        item.regValueName = L"Scheduling Category";
        item.regApplyValue = L"High";
        item.regRevertValue = L"Medium";
        items.push_back(item);
    }

    // 20. Games Task - SFIO Priority
    {
        OptimizationItem item;
        item.id = L"game_sfio";
        item.displayName = L"\u6e38\u620f SFIO \u4f18\u5148\u7ea7";
        item.description = L"\u8bbe\u4e3a High\uff0c\u63d0\u5347\u6e38\u620f\u7684 I/O \u4f18\u5148\u7ea7\u3002";
        item.category = OptCategory::SystemProfile;
        item.isRegistry = true;
        item.regKeyPath = kGamesTaskPath;
        item.regValueName = L"SFIO Priority";
        item.regApplyValue = L"High";
        item.regRevertValue = L"Normal";
        items.push_back(item);
    }

    return items;
}

std::vector<OptimizationItem> TcpOptimizer::BuildBalancedItems() const {
    auto items = BuildGamingItems();
    // Balanced: keep timestamps enabled, use normal congestion provider
    for (auto& item : items) {
        if (item.id == L"tcp_timestamps") {
            item.applyCommand = L"netsh interface tcp set global timestamps=enabled";
            item.description = L"\u4fdd\u6301 TCP \u65f6\u95f4\u6233\u542f\u7528\uff0c\u4fdd\u7559 RTT \u4f30\u7b97\u7cbe\u5ea6\u3002";
        }
        if (item.id == L"tcp_congestion") {
            item.applyCommand = L"netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic";
            item.description = L"\u4f7f\u7528 CUBIC \u62e5\u585e\u63a7\u5236\uff0c\u5e73\u8861\u541e\u5410\u91cf\u548c\u516c\u5e73\u6027\u3002";
        }
    }
    return items;
}

std::vector<OptimizationItem> TcpOptimizer::BuildBandwidthItems() const {
    auto items = BuildGamingItems();
    // Bandwidth mode: maximize throughput, keep timestamps for RTT estimation
    for (auto& item : items) {
        if (item.id == L"tcp_timestamps") {
            item.applyCommand = L"netsh interface tcp set global timestamps=enabled";
        }
        if (item.id == L"tcp_congestion") {
            item.applyCommand = L"netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp";
        }
        if (item.id == L"tcp_sendwindow") {
            item.regApplyValue = L"131072";  // 128KB
        }
        if (item.id == L"tcp_recvwindow") {
            item.regApplyValue = L"131072";  // 128KB
        }
    }
    return items;
}

// ============================================================
// Public API
// ============================================================

std::vector<OptimizationItem> TcpOptimizer::GetOptimizationItems(OptLevel level) const {
    switch (level) {
        case OptLevel::Gaming:    return BuildGamingItems();
        case OptLevel::Balanced:  return BuildBalancedItems();
        case OptLevel::Bandwidth: return BuildBandwidthItems();
        default:                  return BuildGamingItems();
    }
}

std::wstring TcpOptimizer::GetCurrentTcpGlobalSettings() const {
    int exitCode = 0;
    std::wstring output = RunCommand(L"netsh interface tcp show global", &exitCode);
    if (exitCode != 0) {
        output = RunPowerShell(L"Get-NetTCPSetting -SettingName Internet | Format-List");
    }
    return output;
}

OptResult TcpOptimizer::ApplyItem(const OptimizationItem& item) {
    OptResult result;

    if (item.isRegistry) {
        // Determine the registry path (may include interface GUID)
        std::wstring keyPath = item.regKeyPath;
        if (!item.regInterfaceGuid.empty()) {
            keyPath = std::wstring(kTcpInterfacesPath) + L"\\" + item.regInterfaceGuid;
        }

        // For per-interface TcpNoDelay and TcpAckFrequency, we apply to all active interfaces
        if (!item.regInterfaceGuid.empty()) {
            // Apply to a specific interface
            DWORD val = 0;
            try { val = std::stoul(item.regApplyValue); } catch (...) { val = 0; }
            bool ok = SetRegistryValue(keyPath, item.regValueName, val);
            result.success = ok;
            result.message = ok ? L"Applied to interface " + item.regInterfaceGuid : L"Failed";
            return result;
        }

        // Check if this is a per-interface setting that needs to be applied to all interfaces
        if (item.regValueName == L"TcpNoDelay" || item.regValueName == L"TcpAckFrequency") {
            // Apply to all active interfaces as well
            auto guids = GetActiveInterfaceGuids();
            bool allOk = true;
            for (const auto& guid : guids) {
                std::wstring ifacePath = std::wstring(kTcpInterfacesPath) + L"\\" + guid;
                DWORD val = 0;
                try { val = std::stoul(item.regApplyValue); } catch (...) {}
                if (!SetRegistryValue(ifacePath, item.regValueName, val)) {
                    allOk = false;
                }
            }
        }

        // Apply the global registry value
        // Check if value is numeric (DWORD) or string (SZ)
        bool isNumeric = true;
        for (wchar_t c : item.regApplyValue) {
            if (!iswdigit(c)) { isNumeric = false; break; }
        }

        if (isNumeric && !item.regApplyValue.empty()) {
            DWORD val = 0;
            try { val = std::stoul(item.regApplyValue); } catch (...) {}
            result.success = SetRegistryValue(keyPath, item.regValueName, val);
        } else {
            // String value (e.g., "High")
            result.success = SetRegistryValue(keyPath, item.regValueName, item.regApplyValue);
        }
        result.message = result.success ? L"OK" : L"Failed to set registry value";
        result.detail = keyPath + L"\\" + item.regValueName + L" = " + item.regApplyValue;
    } else {
        // Netsh command
        result = RunNetshCommand(item.applyCommand);
    }
    return result;
}

OptResult TcpOptimizer::RevertItem(const OptimizationItem& item) {
    OptResult result;

    if (item.isRegistry) {
        std::wstring keyPath = item.regKeyPath;

        // Revert per-interface settings
        if (item.regValueName == L"TcpNoDelay" || item.regValueName == L"TcpAckFrequency") {
            auto guids = GetActiveInterfaceGuids();
            for (const auto& guid : guids) {
                std::wstring ifacePath = std::wstring(kTcpInterfacesPath) + L"\\" + guid;
                if (item.regRevertValue.empty()) {
                    DeleteRegistryValue(ifacePath, item.regValueName);
                } else {
                    DWORD val = 0;
                    try { val = std::stoul(item.regRevertValue); } catch (...) {}
                    SetRegistryValue(ifacePath, item.regValueName, val);
                }
            }
        }

        if (item.regRevertValue.empty()) {
            // Delete the value to restore default
            result.success = DeleteRegistryValue(keyPath, item.regValueName);
            result.message = result.success ? L"Deleted (restored default)" : L"Failed to delete";
        } else {
            bool isNumeric = true;
            for (wchar_t c : item.regRevertValue) {
                if (!iswdigit(c)) { isNumeric = false; break; }
            }
            if (isNumeric) {
                DWORD val = 0;
                try { val = std::stoul(item.regRevertValue); } catch (...) {}
                result.success = SetRegistryValue(keyPath, item.regValueName, val);
            } else {
                result.success = SetRegistryValue(keyPath, item.regValueName, item.regRevertValue);
            }
            result.message = result.success ? L"Reverted" : L"Failed to revert";
        }
    } else {
        if (!item.revertCommand.empty()) {
            result = RunNetshCommand(item.revertCommand);
        } else {
            result.success = true;
            result.message = L"No revert needed";
        }
    }
    return result;
}

std::vector<OptResult> TcpOptimizer::ApplyAll(OptLevel level,
                                               const ProgressCallback& progress) {
    auto items = GetOptimizationItems(level);
    std::vector<OptResult> results;
    results.reserve(items.size());

    for (size_t i = 0; i < items.size(); ++i) {
        if (progress) {
            progress(items[i].displayName,
                     (int)((i + 1) * 100 / items.size()));
        }
        results.push_back(ApplyItem(items[i]));
    }

    return results;
}

std::vector<OptResult> TcpOptimizer::RevertAll(OptLevel level,
                                                 const ProgressCallback& progress) {
    auto items = GetOptimizationItems(level);
    std::vector<OptResult> results;
    results.reserve(items.size());

    for (size_t i = 0; i < items.size(); ++i) {
        if (progress) {
            progress(items[i].displayName,
                     (int)((i + 1) * 100 / items.size()));
        }
        results.push_back(RevertItem(items[i]));
    }

    return results;
}

} // namespace NetOpt
