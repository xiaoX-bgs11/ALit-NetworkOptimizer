#pragma once

#include <string>
#include <cstdint>

namespace NetOpt {

// Runs a command line process and captures stdout/stderr.
// Returns the combined output as a wide string.
// exitCode is set to the process exit code.
std::wstring RunCommand(const std::wstring& command, int* exitCode = nullptr);

// Runs a command with elevated privileges (UAC prompt).
// Uses ShellExecuteW with "runas" verb.
// Returns true if the elevated process was launched successfully.
// Note: cannot capture output from elevated processes directly;
// the command should write results to a temp file if needed.
bool RunCommandElevated(const std::wstring& command, const std::wstring& params = L"");

// Runs a PowerShell command/script and returns the output.
std::wstring RunPowerShell(const std::wstring& script, int* exitCode = nullptr);

// Runs an elevated PowerShell script.
// The script is written to a temp file, then executed elevated.
bool RunPowerShellElevated(const std::wstring& script);

// Checks if the current process is running as administrator.
bool IsRunningAsAdmin();

// Restarts the current process with elevated privileges.
bool RestartAsAdmin();

} // namespace NetOpt
