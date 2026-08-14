#include "pch.h"
#include "AdapterOptimizer.h"
#include "CommandRunner.h"
#include <windows.h>
#include <iphlpapi.h>
#include <sstream>
#include <algorithm>

#pragma comment(lib, "iphlpapi.lib")

namespace NetOpt {

AdapterOptimizer::AdapterOptimizer() {}
AdapterOptimizer::~AdapterOptimizer() {}

std::vector<AdapterInfo> AdapterOptimizer::GetActiveAdapters() const {
    std::vector<AdapterInfo> adapters;

    std::wstring script =
        L"Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | "
        L"ForEach-Object { "
        L"  $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress; "
        L"  $gw = (Get-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop; "
        L"  $mac = $_.MacAddress; "
        L"  Write-Output ($_.InterfaceGuid + '|' + $_.Name + '|' + $_.InterfaceDescription + '|' + $ip + '|' + $gw + '|' + $mac + '|' + $_.MtuSize + '|' + $_.LinkSpeed); "
        L"}";

    int exitCode = 0;
    std::wstring output = RunPowerShell(script, &exitCode);
    if (exitCode != 0) return adapters;

    std::wistringstream stream(output);
    std::wstring line;
    while (std::getline(stream, line)) {
        line.erase(0, line.find_first_not_of(L" \t\r\n"));
        line.erase(line.find_last_not_of(L" \t\r\n") + 1);
        if (line.empty()) continue;

        std::vector<std::wstring> parts;
        size_t start = 0, end = 0;
        while ((end = line.find(L'|', start)) != std::wstring::npos) {
            parts.push_back(line.substr(start, end - start));
            start = end + 1;
        }
        parts.push_back(line.substr(start));

        if (parts.size() >= 5) {
            AdapterInfo info;
            info.guid = parts[0];
            info.name = parts[1];
            info.description = parts[2];
            info.ipAddress = parts[3];
            info.gateway = parts[4];
            if (parts.size() > 5) info.macAddress = parts[5];
            if (parts.size() > 6) {
                try { info.mtu = std::stoul(parts[6]); } catch (...) {}
            }
            if (parts.size() > 7) {
                std::wstring speedStr = parts[7];
                if (speedStr.find(L"Gbps") != std::wstring::npos) {
                    try {
                        double v = std::stod(speedStr.substr(0, speedStr.find(L' ')));
                        info.linkSpeed = (uint32_t)(v * 1000);
                    } catch (...) {}
                } else if (speedStr.find(L"Mbps") != std::wstring::npos) {
                    try {
                        info.linkSpeed = (uint32_t)std::stod(speedStr.substr(0, speedStr.find(L' ')));
                    } catch (...) {}
                }
            }
            info.isUp = true;
            adapters.push_back(info);
        }
    }

    return adapters;
}

std::vector<AdapterOptimizer::AdapterProperty> AdapterOptimizer::GetAdvancedProperties(
    const std::wstring& interfaceName) const {

    std::vector<AdapterProperty> props;

    std::wstring script =
        L"Get-NetAdapterAdvancedProperty -Name '" + interfaceName + L"' | "
        L"ForEach-Object { "
        L"  $valid = ($_.ValidDisplayValues -join ','); "
        L"  Write-Output ($_.DisplayName + '|' + $_.RegistryKeyword + '|' + "
        L"  $_.RegistryValue + '|' + $_.DisplayValue + '|' + $valid); "
        L"}";

    int exitCode = 0;
    std::wstring output = RunPowerShell(script, &exitCode);
    if (exitCode != 0) return props;

    std::wistringstream stream(output);
    std::wstring line;
    while (std::getline(stream, line)) {
        line.erase(0, line.find_first_not_of(L" \t\r\n"));
        line.erase(line.find_last_not_of(L" \t\r\n") + 1);
        if (line.empty()) continue;

        std::vector<std::wstring> parts;
        size_t start = 0, end = 0;
        while ((end = line.find(L'|', start)) != std::wstring::npos) {
            parts.push_back(line.substr(start, end - start));
            start = end + 1;
        }
        parts.push_back(line.substr(start));

        if (parts.size() >= 4) {
            AdapterProperty prop;
            prop.displayName = parts[0];
            prop.registryKeyword = parts[1];
            prop.currentValue = parts[2];
            prop.displayValue = parts[3];
            if (parts.size() > 4 && !parts[4].empty()) {
                size_t s = 0, e = 0;
                while ((e = parts[4].find(L',', s)) != std::wstring::npos) {
                    prop.validValues.push_back(parts[4].substr(s, e - s));
                    s = e + 1;
                }
                prop.validValues.push_back(parts[4].substr(s));
            }
            props.push_back(prop);
        }
    }

    return props;
}

OptResult AdapterOptimizer::SetProperty(const std::wstring& interfaceName,
                                         const std::wstring& registryKeyword,
                                         const std::wstring& value) {
    OptResult result;

    std::wstring ps = L"Set-NetAdapterAdvancedProperty -Name '" + interfaceName +
                      L"' -RegistryKeyword '" + registryKeyword +
                      L"' -RegistryValue '" + value + L"' -NoRestart";

    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"Property set: " + registryKeyword : L"Failed to set property";
    result.detail = output;
    return result;
}

OptResult AdapterOptimizer::DisablePowerManagement(const std::wstring& interfaceName) {
    OptResult result;

    // Disable adapter power management via PowerShell
    std::wstring ps =
        L"Disable-NetAdapterPowerManagement -Name '" + interfaceName +
        L"' -Confirm:$false -NoRestart";

    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);

    if (exitCode != 0) {
        // Fallback: use powercfg to disable wake
        ps = L"$adapter = Get-PnpDevice | Where-Object { $_.FriendlyName -like '" +
             interfaceName + L"' -or $_.FriendlyName -like '*Ethernet*' }; "
             L"if ($adapter) { Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false }";
        output = RunPowerShell(ps, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"Power management disabled" : L"Failed to disable power management";
    result.detail = output;
    return result;
}

OptResult AdapterOptimizer::SetInterruptModeration(const std::wstring& interfaceName,
                                                     bool enable) {
    return SetProperty(interfaceName, L"*InterruptModeration",
                       enable ? L"1" : L"0");
}

OptResult AdapterOptimizer::SetReceiveBuffers(const std::wstring& interfaceName,
                                                uint32_t value) {
    return SetProperty(interfaceName, L"*ReceiveBuffers",
                       std::to_wstring(value));
}

OptResult AdapterOptimizer::SetTransmitBuffers(const std::wstring& interfaceName,
                                                 uint32_t value) {
    return SetProperty(interfaceName, L"*TransmitBuffers",
                       std::to_wstring(value));
}

OptResult AdapterOptimizer::SetRSS(const std::wstring& interfaceName, bool enable) {
    OptResult result;
    if (enable) {
        std::wstring ps = L"Enable-NetAdapterRss -Name '" + interfaceName +
                          L"' -Confirm:$false -NoRestart";
        int exitCode = 0;
        std::wstring output = RunPowerShell(ps, &exitCode);
        result.success = (exitCode == 0);
        result.detail = output;
    } else {
        std::wstring ps = L"Disable-NetAdapterRss -Name '" + interfaceName +
                          L"' -Confirm:$false -NoRestart";
        int exitCode = 0;
        std::wstring output = RunPowerShell(ps, &exitCode);
        result.success = (exitCode == 0);
        result.detail = output;
    }
    result.message = result.success ?
        (enable ? L"RSS enabled" : L"RSS disabled") : L"Failed to set RSS";
    return result;
}

OptResult AdapterOptimizer::SetJumboFrames(const std::wstring& interfaceName,
                                             bool enable) {
    // JumboPacket: 1514 = disabled, 9014 = enabled
    return SetProperty(interfaceName, L"*JumboPacket",
                       enable ? L"9014" : L"1514");
}

OptResult AdapterOptimizer::SetMTU(const std::wstring& interfaceName, uint32_t mtu) {
    OptResult result;
    std::wstring cmd = L"netsh interface ipv4 set subinterface \"" +
                       interfaceName + L"\" mtu=" + std::to_wstring(mtu);
    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);

    if (exitCode != 0) {
        // Try PowerShell
        std::wstring ps = L"Set-NetIPInterface -InterfaceAlias '" +
                          interfaceName + L"' -NlMtu " + std::to_wstring(mtu);
        output = RunPowerShell(ps, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ?
        L"MTU set to " + std::to_wstring(mtu) : L"Failed to set MTU";
    result.detail = output;
    return result;
}

OptResult AdapterOptimizer::SetLSO(const std::wstring& interfaceName, bool enable) {
    // LSO V2 IPv4: 1 = enabled, 0 = disabled
    // Disabling LSO reduces latency for small packets but may reduce throughput
    OptResult r1 = SetProperty(interfaceName, L"*LSOv2IPv4",
                               enable ? L"1" : L"0");
    OptResult r2 = SetProperty(interfaceName, L"*LSOv2IPv6",
                               enable ? L"1" : L"0");
    r1.success = r1.success && r2.success;
    r1.message = r1.success ?
        (enable ? L"LSO enabled" : L"LSO disabled (lower latency)") : L"Failed to set LSO";
    return r1;
}

std::vector<OptResult> AdapterOptimizer::ApplyGamingOptimizations(
    const std::wstring& interfaceName,
    const ProgressCallback& progress) {

    std::vector<OptResult> results;

    struct Step {
        std::wstring name;
        std::function<OptResult()> action;
    };

    std::vector<Step> steps = {
        { L"\u7981\u7528\u7535\u6e90\u7ba1\u7406",
          [&]() { return DisablePowerManagement(interfaceName); } },
        { L"\u8bbe\u7f6e\u63a5\u6536\u7f13\u51b2\u533a",
          [&]() { return SetReceiveBuffers(interfaceName, 2048); } },
        { L"\u8bbe\u7f6e\u53d1\u9001\u7f13\u51b2\u533a",
          [&]() { return SetTransmitBuffers(interfaceName, 2048); } },
        { L"\u542f\u7528 RSS",
          [&]() { return SetRSS(interfaceName, true); } },
        { L"\u8bbe\u7f6e MTU",
          [&]() { return SetMTU(interfaceName, 1500); } },
        { L"\u7981\u7528 LSO (\u964d\u4f4e\u5ef6\u8fdf)",
          [&]() { return SetLSO(interfaceName, false); } },
        { L"\u7981\u7528\u4e2d\u65ad\u8282\u6d41 (\u964d\u4f4e\u5ef6\u8fdf)",
          [&]() { return SetInterruptModeration(interfaceName, false); } },
    };

    for (size_t i = 0; i < steps.size(); ++i) {
        if (progress) {
            progress(steps[i].name, (int)((i + 1) * 100 / steps.size()));
        }
        results.push_back(steps[i].action());
    }

    return results;
}

std::vector<OptResult> AdapterOptimizer::RevertOptimizations(
    const std::wstring& interfaceName,
    const ProgressCallback& progress) {

    std::vector<OptResult> results;

    struct Step {
        std::wstring name;
        std::function<OptResult()> action;
    };

    std::vector<Step> steps = {
        { L"\u6062\u590d\u7535\u6e90\u7ba1\u7406",
          [&]() {
              std::wstring ps = L"Enable-NetAdapterPowerManagement -Name '" +
                                interfaceName + L"' -Confirm:$false -NoRestart";
              int ec = 0;
              std::wstring out = RunPowerShell(ps, &ec);
              OptResult r; r.success = (ec == 0); r.message = r.success ? L"OK" : L"Failed"; r.detail = out;
              return r;
          } },
        { L"\u6062\u590d\u63a5\u6536\u7f13\u51b2\u533a",
          [&]() { return SetReceiveBuffers(interfaceName, 512); } },
        { L"\u6062\u590d\u53d1\u9001\u7f13\u51b2\u533a",
          [&]() { return SetTransmitBuffers(interfaceName, 512); } },
        { L"\u6062\u590d MTU",
          [&]() { return SetMTU(interfaceName, 1500); } },
        { L"\u542f\u7528 LSO",
          [&]() { return SetLSO(interfaceName, true); } },
        { L"\u542f\u7528\u4e2d\u65ad\u8282\u6d41",
          [&]() { return SetInterruptModeration(interfaceName, true); } },
    };

    for (size_t i = 0; i < steps.size(); ++i) {
        if (progress) {
            progress(steps[i].name, (int)((i + 1) * 100 / steps.size()));
        }
        results.push_back(steps[i].action());
    }

    return results;
}

bool AdapterOptimizer::SupportsFeature(const std::wstring& interfaceName,
                                        const std::wstring& featureKeyword) const {
    auto props = GetAdvancedProperties(interfaceName);
    for (const auto& p : props) {
        if (p.registryKeyword == featureKeyword ||
            p.displayName.find(featureKeyword) != std::wstring::npos) {
            return true;
        }
    }
    return false;
}

std::wstring AdapterOptimizer::FindRegistryKeyword(const std::wstring& interfaceName,
                                                     const std::wstring& displayName) const {
    auto props = GetAdvancedProperties(interfaceName);
    for (const auto& p : props) {
        if (p.displayName == displayName) {
            return p.registryKeyword;
        }
    }
    return L"";
}

} // namespace NetOpt
