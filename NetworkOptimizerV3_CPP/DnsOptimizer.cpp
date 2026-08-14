#include "pch.h"
#include "DnsOptimizer.h"
#include "CommandRunner.h"
#include <windows.h>
#include <iphlpapi.h>
#include <ws2tcpip.h>
#include <chrono>
#include <sstream>
#include <algorithm>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

namespace NetOpt {

DnsOptimizer::DnsOptimizer() {
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
}

DnsOptimizer::~DnsOptimizer() {
    WSACleanup();
}

std::vector<AdapterInfo> DnsOptimizer::GetAdapters() const {
    std::vector<AdapterInfo> adapters;

    // Use PowerShell to get adapter info
    std::wstring script =
        L"$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }; "
        L"foreach ($a in $adapters) { "
        L"  $ip = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress; "
        L"  $dns = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ','; "
        L"  $gw = (Get-NetRoute -InterfaceIndex $a.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop; "
        L"  $mtu = $a.MtuSize; "
        L"  $speed = $a.LinkSpeed; "
        L"  Write-Output ($a.InterfaceGuid + '|' + $a.Name + '|' + $a.InterfaceDescription + '|' + $ip + '|' + $gw + '|' + $dns + '|' + $mtu + '|' + $speed); "
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

        AdapterInfo info;
        std::vector<std::wstring> parts;
        size_t start = 0, end = 0;
        while ((end = line.find(L'|', start)) != std::wstring::npos) {
            parts.push_back(line.substr(start, end - start));
            start = end + 1;
        }
        parts.push_back(line.substr(start));

        if (parts.size() >= 6) {
            info.guid = parts[0];
            info.name = parts[1];
            info.description = parts[2];
            info.ipAddress = parts[3];
            info.gateway = parts[4];
            info.dnsServers = parts[5];
            if (parts.size() > 6) {
                try { info.mtu = std::stoul(parts[6]); } catch (...) {}
            }
            if (parts.size() > 7) {
                // LinkSpeed may be like "1 Gbps" or "100 Mbps"
                std::wstring speedStr = parts[7];
                if (speedStr.find(L"Gbps") != std::wstring::npos) {
                    try {
                        double gbps = std::stod(speedStr.substr(0, speedStr.find(L' ')));
                        info.linkSpeed = (uint32_t)(gbps * 1000);
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

std::wstring DnsOptimizer::GetCurrentDns(const std::wstring& interfaceName) const {
    std::wstring script =
        L"(Get-DnsClientServerAddress -InterfaceAlias '" + interfaceName +
        L"' -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ', '";
    int exitCode = 0;
    std::wstring result = RunPowerShell(script, &exitCode);
    // Trim
    result.erase(0, result.find_first_not_of(L" \t\r\n"));
    result.erase(result.find_last_not_of(L" \t\r\n") + 1);
    return result;
}

OptResult DnsOptimizer::SetDns(const std::wstring& interfaceName,
                                const std::wstring& primary,
                                const std::wstring& secondary) {
    OptResult result;

    // Set primary DNS
    std::wstring cmd = L"netsh interface ip set dns name=\"" + interfaceName +
                       L"\" static " + primary + L" primary";
    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);
    if (exitCode != 0) {
        // Try PowerShell alternative
        std::wstring ps = L"Set-DnsClientServerAddress -InterfaceAlias '" +
                          interfaceName + L"' -ServerAddresses ('" + primary + L"')";
        if (!secondary.empty()) {
            ps += L", '" + secondary + L"'";
        }
        ps += L")";
        output = RunPowerShell(ps, &exitCode);
    }

    result.success = (exitCode == 0);
    result.message = result.success ? L"DNS updated" : L"Failed to set DNS";
    result.detail = output;

    // Add secondary DNS if provided and primary succeeded
    if (result.success && !secondary.empty()) {
        std::wstring cmd2 = L"netsh interface ip add dns name=\"" + interfaceName +
                             L"\" " + secondary + L" index=2";
        RunCommand(cmd2, &exitCode);
    }

    return result;
}

OptResult DnsOptimizer::RestoreDns(const std::wstring& interfaceName) {
    OptResult result;
    std::wstring cmd = L"netsh interface ip set dns name=\"" + interfaceName +
                       L"\" source=dhcp";
    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);
    if (exitCode != 0) {
        std::wstring ps = L"Set-DnsClientServerAddress -InterfaceAlias '" +
                          interfaceName + L"' -ResetServerAddresses";
        output = RunPowerShell(ps, &exitCode);
    }
    result.success = (exitCode == 0);
    result.message = result.success ? L"DNS restored to DHCP" : L"Failed to restore DNS";
    result.detail = output;
    return result;
}

OptResult DnsOptimizer::FlushDnsCache() {
    OptResult result;
    int exitCode = 0;
    std::wstring output = RunCommand(L"ipconfig /flushdns", &exitCode);
    result.success = (exitCode == 0);
    result.message = result.success ? L"DNS cache flushed" : L"Failed to flush DNS cache";
    result.detail = output;
    return result;
}

uint32_t DnsOptimizer::MeasureDnsLatency(const std::wstring& dnsServer) const {
    // Use nslookup to measure DNS resolution time
    // nslookup returns quickly if the server responds
    auto start = std::chrono::high_resolution_clock::now();

    std::wstring cmd = L"nslookup example.com " + dnsServer;
    int exitCode = 0;
    RunCommand(cmd, &exitCode);

    auto end = std::chrono::high_resolution_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    // Subtract a baseline (nslookup overhead ~100ms)
    if (ms > 100) ms -= 100;
    return (uint32_t)ms;
}

double DnsOptimizer::PingHost(const std::wstring& host, int count) const {
    std::wstring cmd = L"ping -n " + std::to_wstring(count) + L" " + host;
    int exitCode = 0;
    std::wstring output = RunCommand(cmd, &exitCode);

    // Parse average from "Average = Xms" (Chinese) or "Average = Xms" (English)
    std::wstring avgMarker = L"Average = ";
    size_t pos = output.find(avgMarker);
    if (pos == std::wstring::npos) {
        avgMarker = L"\u5e73\u5747 = ";  // Chinese: 平均 = 
        pos = output.find(avgMarker);
    }
    if (pos == std::wstring::npos) return -1.0;

    pos += avgMarker.size();
    size_t end = output.find(L"ms", pos);
    if (end == std::wstring::npos) return -1.0;

    std::wstring numStr = output.substr(pos, end - pos);
    try {
        return std::stod(numStr);
    } catch (...) {
        return -1.0;
    }
}

std::vector<DnsResult> DnsOptimizer::BenchmarkDns(
    const std::vector<std::pair<std::wstring, std::wstring>>& servers) const {

    std::vector<DnsResult> results;
    for (const auto& srv : servers) {
        DnsResult r;
        r.server = srv.first;
        r.ip = srv.second;

        // Ping the DNS server to measure network latency
        double ping = PingHost(srv.second, 3);
        if (ping > 0) {
            r.latencyMs = (uint32_t)ping;
            r.success = true;
        } else {
            r.latencyMs = 0;
            r.success = false;
        }
        results.push_back(r);
    }

    // Sort by latency
    std::sort(results.begin(), results.end(),
              [](const DnsResult& a, const DnsResult& b) {
                  if (a.success != b.success) return a.success > b.success;
                  return a.latencyMs < b.latencyMs;
              });

    return results;
}

std::vector<DnsOptimizer::DnsProfile> DnsOptimizer::GetPresetProfiles() const {
    return {
        { L"Cloudflare", L"1.1.1.1", L"1.0.0.1",
          L"\u96f6\u65e5\u5fd7 DNS\uff0c\u9690\u79c1\u4f18\u5148\uff0c\u5168\u7403\u4f4e\u5ef6\u8fdf" },
        { L"Google", L"8.8.8.8", L"8.8.4.4",
          L"Google \u516c\u5171 DNS\uff0c\u7a33\u5b9a\u53ef\u9760" },
        { L"Cloudflare Gaming", L"1.1.1.1", L"1.0.0.1",
          L"Cloudflare DNS\uff0c\u9002\u5408\u6e38\u620f\u573a\u666f" },
        { L"114 DNS", L"114.114.114.114", L"114.114.115.115",
          L"\u56fd\u5185 114DNS\uff0c\u56fd\u5185\u89e3\u6790\u5feb" },
        { L"AliDNS", L"223.5.5.5", L"223.6.6.6",
          L"\u963f\u91cc\u4e91 DNS\uff0c\u56fd\u5185\u89e3\u6790\u5feb\uff0c\u7a33\u5b9a" },
        { L"DNSPod", L"119.29.29.29", L"182.254.116.116",
          L"DNSPod\uff0c\u817e\u8baf\u63d0\u4f9b\uff0c\u56fd\u5185\u4f18\u5316" },
    };
}

OptResult DnsOptimizer::ApplyPreset(const std::wstring& interfaceName,
                                     const DnsProfile& profile) {
    return SetDns(interfaceName, profile.primary, profile.secondary);
}

} // namespace NetOpt
