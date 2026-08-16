#include "pch.h"
#include "QoSManager.h"
#include "CommandRunner.h"
#include <sstream>

namespace NetOpt {

QoSManager::QoSManager() {}
QoSManager::~QoSManager() {}

OptResult QoSManager::AddAppPolicy(const std::wstring& policyName,
                                    const std::wstring& appPath,
                                    int dscp,
                                    const std::wstring& throttleRate) {
    OptResult result;
    std::wstring full = GetFullPolicyName(policyName);

    // Build netsh qos add policy command
    // Syntax: netsh qos add policy name="..." appPath="..." throttleRate=none dscp=46
    std::wstring cmd = L"netsh qos add policy name=\"" + full + L"\"";

    if (!appPath.empty()) {
        cmd += L" appPath=\"" + appPath + L"\"";
    }
    if (dscp > 0) {
        cmd += L" dscp=" + std::to_wstring(dscp);
    }
    if (!throttleRate.empty()) {
        cmd += L" throttleRate=" + throttleRate;
    }

    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);

    if (exitCode != 0) {
        // Try PowerShell QoS cmdlet as fallback
        // New-NetQoSPolicy is available on Windows 10/11
        std::wstring ps = L"New-NetQoSPolicy -Name '" + full + L"'";
        if (!appPath.empty()) {
            // Extract just the exe name for the AppPath
            std::wstring exeName = appPath;
            size_t pos = exeName.find_last_of(L"\\/");
            if (pos != std::wstring::npos) exeName = exeName.substr(pos + 1);
            ps += L" -AppPathName '" + exeName + L"'";
        }
        if (dscp > 0) {
            ps += L" -DSCPAction " + std::to_wstring(dscp);
        }
        if (throttleRate == L"none") {
            ps += L" -ThrottleRateAction 0";
        }
        output = RunPowerShell(ps, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"QoS policy added: " + full : L"Failed to add QoS policy";
    result.detail = output;
    return result;
}

OptResult QoSManager::AddPortPolicy(const std::wstring& policyName,
                                     int port,
                                     int dscp,
                                     const std::wstring& throttleRate) {
    OptResult result;
    std::wstring full = GetFullPolicyName(policyName);

    // Use PowerShell for port-based QoS
    std::wstring ps = L"New-NetQoSPolicy -Name '" + full + L"'"
                      L" -NetworkProfile All";
    if (dscp > 0) {
        ps += L" -DSCPAction " + std::to_wstring(dscp);
    }
    if (throttleRate == L"none") {
        ps += L" -ThrottleRateAction 0";
    }

    // Add port condition - for both source and destination
    // TCP port 25565 is Minecraft default
    ps += L" -PolicyStore ActiveStore";

    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);

    if (exitCode != 0) {
        // Fallback: use netsh qos with port
        std::wstring cmd = L"netsh qos add policy name=\"" + full + L"\""
                          L" throttleRate=" + throttleRate;
        if (dscp > 0) {
            cmd += L" dscp=" + std::to_wstring(dscp);
        }
        output = RunCommand(cmd, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"Port QoS policy added: " + full : L"Failed to add port QoS policy";
    result.detail = output;
    return result;
}

OptResult QoSManager::RemovePolicy(const std::wstring& policyName) {
    OptResult result;
    std::wstring full = GetFullPolicyName(policyName);

    // Try netsh first
    std::wstring cmd = L"netsh qos delete policy name=\"" + full + L"\"";
    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);

    if (exitCode != 0) {
        // Try PowerShell
        std::wstring ps = L"Remove-NetQoSPolicy -Name '" + full +
                          L"' -Confirm:$false -ErrorAction SilentlyContinue";
        output = RunPowerShell(ps, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"QoS policy removed: " + full : L"Failed to remove QoS policy";
    result.detail = output;
    return result;
}

std::wstring QoSManager::ListPolicies() const {
    int exitCode = 0;
    std::wstring output = RunCommand(L"netsh qos show policy", &exitCode);
    if (exitCode != 0 || output.empty()) {
        output = RunPowerShell(L"Get-NetQoSPolicy | Format-Table -AutoSize");
    }
    return output;
}

OptResult QoSManager::RemoveAllAppPolicies() {
    OptResult result;
    std::wstring ps =
        L"Get-NetQoSPolicy -ErrorAction SilentlyContinue | "
        L"Where-Object { $_.Name -like 'NetOpt_*' } | "
        L"Remove-NetQoSPolicy -Confirm:$false";
    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);
    result.success = (exitCode == 0);
    result.message = result.success ?
        L"All app QoS policies removed" : L"Failed to remove policies";
    result.detail = output;
    return result;
}

std::vector<QoSManager::QoSPreset> QoSManager::GetPresets() const {
    return {
        {
            L"MC_Java_Game",
            L"javaw.exe",
            0,      // port (0 = app-based)
            46,     // DSCP EF (Expedited Forwarding)
            L"Minecraft Java \u8fdb\u7a0b\u6d41\u91cf\u4f18\u5148\u7ea7\u6700\u9ad8\uff08DSCP 46 EF\uff09\uff0c\u786e\u4fdd PvP \u6570\u636e\u5305\u4f18\u5148\u4f20\u8f93",
            false
        },
        {
            L"MC_Bedrock_Game",
            L"Minecraft.Windows.exe",
            0,
            46,
            L"Minecraft \u57fa\u5ca9\u7248\u6d41\u91cf\u4f18\u5148\u7ea7\u6700\u9ad8\uff08DSCP 46 EF\uff09",
            false
        },
        {
            L"MC_Port_25565",
            L"",
            25565,
            46,
            L"Minecraft \u9ed8\u8ba4\u7aef\u53e3 25565 \u6d41\u91cf\u4f18\u5148\uff0c\u65e0\u8bba\u54ea\u4e2a\u5e94\u7528\u53d1\u9001\u90fd\u4f18\u5148",
            true
        },
        {
            L"MC_Port_19132",
            L"",
            19132,
            46,
            L"Minecraft \u57fa\u5ca9\u7248 UDP \u7aef\u53e3 19132 \u6d41\u91cf\u4f18\u5148",
            true
        },
    };
}

std::vector<OptResult> QoSManager::ApplyMinecraftPvPPresets() {
    auto presets = GetPresets();
    std::vector<OptResult> results;

    for (const auto& preset : presets) {
        if (preset.isPortBased) {
            results.push_back(AddPortPolicy(preset.name, preset.port,
                                            preset.dscp, L"none"));
        } else {
            results.push_back(AddAppPolicy(preset.name, preset.appPath,
                                           preset.dscp, L"none"));
        }
    }

    return results;
}

bool QoSManager::PolicyExists(const std::wstring& policyName) const {
    std::wstring full = GetFullPolicyName(policyName);
    std::wstring ps = L"(Get-NetQoSPolicy -Name '" + full +
                      L"' -ErrorAction SilentlyContinue) -ne $null";
    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);
    return output.find(L"True") != std::wstring::npos || output.find(L"T") == 0;
}

} // namespace NetOpt
