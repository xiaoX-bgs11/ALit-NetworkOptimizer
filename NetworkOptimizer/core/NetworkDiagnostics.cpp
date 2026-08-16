#include "pch.h"
#include "NetworkDiagnostics.h"
#include "CommandRunner.h"
#include <windows.h>
#include <iphlpapi.h>
#include <icmpapi.h>
#include <ws2tcpip.h>
#include <winhttp.h>
#include <chrono>
#include <sstream>
#include <algorithm>
#include <cmath>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "winhttp.lib")

namespace NetOpt {

NetworkDiagnostics::NetworkDiagnostics() {
    WSADATA wsaData;
    WSAStartup(MAKEWORD(2, 2), &wsaData);
}

NetworkDiagnostics::~NetworkDiagnostics() {
    StopBandwidthMonitor();
    WSACleanup();
}

// ============================================================
// Bandwidth Monitoring
// ============================================================

uint32_t NetworkDiagnostics::GetInterfaceIndex(const std::wstring& interfaceName) const {
    std::wstring ps = L"(Get-NetAdapter -Name '" + interfaceName +
                      L"' -ErrorAction SilentlyContinue).ifIndex";
    int exitCode = 0;
    std::wstring output = RunPowerShell(ps, &exitCode);
    output.erase(0, output.find_first_not_of(L" \t\r\n"));
    output.erase(output.find_last_not_of(L" \t\r\n") + 1);
    try {
        return std::stoul(output);
    } catch (...) {
        return 0;
    }
}

bool NetworkDiagnostics::GetInterfaceStats(uint32_t ifIndex,
                                            uint64_t& bytesSent,
                                            uint64_t& bytesReceived) const {
    MIB_IF_ROW2 row;
    ZeroMemory(&row, sizeof(row));
    row.InterfaceIndex = ifIndex;

    DWORD result = GetIfEntry2(&row);
    if (result != NO_ERROR) return false;

    bytesSent = row.OutOctets;
    bytesReceived = row.InOctets;
    return true;
}

BandwidthSample NetworkDiagnostics::GetBandwidthSample(
    const std::wstring& interfaceName) const {

    BandwidthSample sample;
    sample.timestamp = (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();

    uint32_t ifIndex = GetInterfaceIndex(interfaceName);
    if (ifIndex == 0) return sample;

    uint64_t bytesSent = 0, bytesReceived = 0;
    if (!GetInterfaceStats(ifIndex, bytesSent, bytesReceived)) return sample;

    sample.bytesSent = bytesSent;
    sample.bytesReceived = bytesReceived;

    // Calculate speed using previous sample
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_prevTimestamp > 0) {
            double timeDelta = (double)(sample.timestamp - m_prevTimestamp) / 1000.0; // seconds
            if (timeDelta > 0) {
                double sentDelta = (double)(bytesSent - m_prevBytesSent);
                double recvDelta = (double)(bytesReceived - m_prevBytesReceived);

                // Convert bytes/sec to Mbps
                sample.uploadSpeed = (sentDelta * 8.0 / 1000000.0) / timeDelta;
                sample.downloadSpeed = (recvDelta * 8.0 / 1000000.0) / timeDelta;

                // Clamp negative values (counter reset)
                if (sample.uploadSpeed < 0) sample.uploadSpeed = 0;
                if (sample.downloadSpeed < 0) sample.downloadSpeed = 0;
            }
        }
        m_prevBytesSent = bytesSent;
        m_prevBytesReceived = bytesReceived;
        m_prevTimestamp = sample.timestamp;
    }

    return sample;
}

void NetworkDiagnostics::StartBandwidthMonitor(const std::wstring& interfaceName,
                                                 BandwidthCallback callback,
                                                 uint32_t intervalMs) {
    StopBandwidthMonitor();

    // Reset previous sample
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_prevTimestamp = 0;
        m_prevBytesSent = 0;
        m_prevBytesReceived = 0;
    }

    m_monitoring = true;
    m_monitorThread = std::thread([this, interfaceName, callback, intervalMs]() {
        // Get initial sample to establish baseline
        GetBandwidthSample(interfaceName);

        while (m_monitoring) {
            std::this_thread::sleep_for(std::chrono::milliseconds(intervalMs));
            if (!m_monitoring) break;

            BandwidthSample sample = GetBandwidthSample(interfaceName);
            if (callback) {
                callback(sample);
            }
        }
    });
}

void NetworkDiagnostics::StopBandwidthMonitor() {
    m_monitoring = false;
    if (m_monitorThread.joinable()) {
        m_monitorThread.join();
    }
}

// ============================================================
// ICMP Ping
// ============================================================

NetworkDiagnostics::PingResult NetworkDiagnostics::IcmpPing(
    const std::wstring& host, uint32_t timeoutMs) const {

    PingResult result = { false, 0.0 };

    // Resolve hostname to IP
    ADDRINFOW hints;
    ZeroMemory(&hints, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    PADDRINFOW addrInfo = nullptr;
    if (GetAddrInfoW(host.c_str(), L"80", &hints, &addrInfo) != 0 || !addrInfo) {
        return result;
    }

    sockaddr_in* destAddr = (sockaddr_in*)addrInfo->ai_addr;
    IPAddr destIp = destAddr->sin_addr.S_un.S_addr;

    // Create ICMP handle
    HANDLE hIcmp = IcmpCreateFile();
    if (hIcmp == INVALID_HANDLE_VALUE) {
        FreeAddrInfoW(addrInfo);
        return result;
    }

    // Send echo request
    uint8_t sendData[32] = { 0 };
    uint8_t replyBuffer[sizeof(ICMP_ECHO_REPLY) + 32];
    DWORD replyCount = IcmpSendEcho(hIcmp, destIp, sendData, sizeof(sendData),
                                     nullptr, replyBuffer, sizeof(replyBuffer),
                                     timeoutMs);

    if (replyCount > 0) {
        ICMP_ECHO_REPLY* echoReply = (ICMP_ECHO_REPLY*)replyBuffer;
        if (echoReply->Status == IP_SUCCESS) {
            result.success = true;
            result.latencyMs = (double)echoReply->RoundTripTime;
        }
    }

    IcmpCloseHandle(hIcmp);
    FreeAddrInfoW(addrInfo);
    return result;
}

double NetworkDiagnostics::MeasurePing(const std::wstring& host, int count) const {
    double total = 0;
    int successes = 0;

    for (int i = 0; i < count; ++i) {
        auto result = IcmpPing(host, 2000);
        if (result.success) {
            total += result.latencyMs;
            successes++;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    return successes > 0 ? total / successes : -1.0;
}

double NetworkDiagnostics::MeasureJitter(const std::wstring& host, int count) const {
    std::vector<double> latencies;
    latencies.reserve(count);

    for (int i = 0; i < count; ++i) {
        auto result = IcmpPing(host, 2000);
        if (result.success) {
            latencies.push_back(result.latencyMs);
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    if (latencies.size() < 2) return -1.0;

    // Calculate average absolute difference between consecutive samples
    double totalDiff = 0;
    for (size_t i = 1; i < latencies.size(); ++i) {
        totalDiff += std::abs(latencies[i] - latencies[i - 1]);
    }

    return totalDiff / (latencies.size() - 1);
}

uint32_t NetworkDiagnostics::MeasurePacketLoss(const std::wstring& host, int count) const {
    int failures = 0;
    for (int i = 0; i < count; ++i) {
        auto result = IcmpPing(host, 2000);
        if (!result.success) {
            failures++;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    return (uint32_t)((double)failures * 100.0 / count);
}

// ============================================================
// MTU Detection
// ============================================================

uint32_t NetworkDiagnostics::DetectOptimalMTU(const std::wstring& gateway) const {
    // Binary search for the largest packet size that doesn't fragment
    // MTU = packet payload + 28 (IP header 20 + ICMP header 8)

    uint32_t low = 68;     // Minimum MTU
    uint32_t high = 1472;  // Maximum payload for 1500 MTU
    uint32_t optimal = 1472;

    while (low <= high) {
        uint32_t mid = (low + high) / 2;

        // Ping with don't-fragment flag and specified payload size
        // Using command-line ping since IcmpSendEcho doesn't support DF flag
        std::wstring cmd = L"ping -n 1 -f -l " + std::to_wstring(mid) +
                           L" " + gateway;
        int exitCode = 0;
        std::wstring output = RunCommand(cmd, &exitCode);

        // Check if packet was fragmented
        if (output.find(L"\u9700\u8981\u62c6\u5206") != std::wstring::npos ||
            output.find(L"fragmented") != std::wstring::npos ||
            output.find(L"Fragmented") != std::wstring::npos ||
            output.find(L"DF") != std::wstring::npos) {
            // Packet needs fragmentation, try smaller
            high = mid - 1;
        } else if (output.find(L"\u56de\u590d") != std::wstring::npos ||
                   output.find(L"reply") != std::wstring::npos ||
                   output.find(L"Reply") != std::wstring::npos ||
                   output.find(L"\u6765\u81ea") != std::wstring::npos) {
            // Success, try larger
            optimal = mid;
            low = mid + 1;
        } else {
            // Timeout or error, try smaller
            high = mid - 1;
        }
    }

    // Return actual MTU (payload + 28 bytes headers)
    return optimal + 28;
}

// ============================================================
// Full Diagnostic
// ============================================================

std::vector<AdapterInfo> NetworkDiagnostics::GetAdapters() const {
    std::vector<AdapterInfo> adapters;

    std::wstring script =
        L"Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | "
        L"ForEach-Object { "
        L"  $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress; "
        L"  $gw = (Get-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue).NextHop; "
        L"  $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ','; "
        L"  Write-Output ($_.Name + '|' + $ip + '|' + $gw + '|' + $dns + '|' + $_.MtuSize); "
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
            info.name = parts[0];
            info.ipAddress = parts[1];
            info.gateway = parts[2];
            info.dnsServers = parts[3];
            try { info.mtu = std::stoul(parts[4]); } catch (...) {}
            info.isUp = true;
            adapters.push_back(info);
        }
    }

    return adapters;
}

NetworkDiagnostic NetworkDiagnostics::RunFullDiagnostic(
    const std::wstring& interfaceName) const {

    NetworkDiagnostic diag;
    diag.adapterName = interfaceName;

    auto adapters = GetAdapters();
    for (const auto& a : adapters) {
        if (a.name == interfaceName) {
            diag.ipAddress = a.ipAddress;
            diag.gateway = a.gateway;
            diag.dnsServer = a.dnsServers;
            diag.mtu = a.mtu;
            break;
        }
    }

    // Measure ping to gateway
    if (!diag.gateway.empty()) {
        diag.pingMs = MeasurePing(diag.gateway, 5);
        diag.jitterMs = MeasureJitter(diag.gateway, 5);
        diag.packetLoss = MeasurePacketLoss(diag.gateway, 10);
    }

    // Measure DNS latency (ping the first DNS server)
    if (!diag.dnsServer.empty()) {
        // Extract first DNS server
        std::wstring firstDns = diag.dnsServer;
        size_t commaPos = firstDns.find(L',');
        if (commaPos != std::wstring::npos) {
            firstDns = firstDns.substr(0, commaPos);
        }
        firstDns.erase(0, firstDns.find_first_not_of(L" \t"));
        firstDns.erase(firstDns.find_last_not_of(L" \t") + 1);
        if (!firstDns.empty()) {
            diag.dnsLatencyMs = MeasurePing(firstDns, 3);
        }
    }

    // Get bandwidth estimate from current interface stats
    BandwidthSample s1 = GetBandwidthSample(interfaceName);
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    BandwidthSample s2 = GetBandwidthSample(interfaceName);

    if (s2.timestamp > s1.timestamp) {
        double dt = (double)(s2.timestamp - s1.timestamp) / 1000.0;
        if (dt > 0) {
            diag.downloadSpeed = (double)(s2.bytesReceived - s1.bytesReceived) * 8.0 / 1000000.0 / dt;
            diag.uploadSpeed = (double)(s2.bytesSent - s1.bytesSent) * 8.0 / 1000000.0 / dt;
        }
    }

    return diag;
}

// ============================================================
// Speed Test
// ============================================================

double NetworkDiagnostics::EstimateDownloadSpeed() const {
    // Download a test file from a reliable server and measure speed
    // Using Cloudflare's speed test endpoint
    HINTERNET hSession = WinHttpOpen(L"NetOptimizer/1.0",
                                      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                      WINHTTP_NO_PROXY_NAME,
                                      WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) return -1.0;

    HINTERNET hConnect = WinHttpConnect(hSession, L"speed.cloudflare.com",
                                         INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!hConnect) {
        WinHttpCloseHandle(hSession);
        return -1.0;
    }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET",
        L"/__down?bytes=10000000",  // 10MB download
        WINHTTP_NO_REFERER, WINHTTP_NO_DEFAULT_HEADERS,
        WINHTTP_DEFAULT_ACCEPT_FLAGS,
        WINHTTP_FLAG_SECURE);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return -1.0;
    }

    BOOL bResults = WinHttpSendRequest(hRequest,
        WINHTTP_NO_ADDITIONAL_HEADERS, 0,
        WINHTTP_NO_REQUEST_DATA, 0,
        WINHTTP_IGNORE_REQUEST_TOTAL_LENGTH, 0);

    if (bResults) {
        bResults = WinHttpReceiveResponse(hRequest, nullptr);
    }

    double speed = -1.0;
    if (bResults) {
        auto start = std::chrono::high_resolution_clock::now();
        uint64_t totalBytes = 0;

        DWORD bytesAvailable = 0;
        uint8_t buffer[65536];
        DWORD bytesRead = 0;

        while (WinHttpQueryDataAvailable(hRequest, &bytesAvailable) && bytesAvailable > 0) {
            DWORD toRead = min(bytesAvailable, (DWORD)sizeof(buffer));
            if (WinHttpReadData(hRequest, buffer, toRead, &bytesRead) && bytesRead > 0) {
                totalBytes += bytesRead;
            } else {
                break;
            }
        }

        auto end = std::chrono::high_resolution_clock::now();
        double seconds = std::chrono::duration<double>(end - start).count();

        if (seconds > 0 && totalBytes > 0) {
            speed = (double)totalBytes * 8.0 / 1000000.0 / seconds; // Mbps
        }
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    return speed;
}

double NetworkDiagnostics::EstimateUploadSpeed() const {
    // Upload test data to Cloudflare speed test endpoint
    HINTERNET hSession = WinHttpOpen(L"NetOptimizer/1.0",
                                      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                      WINHTTP_NO_PROXY_NAME,
                                      WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hSession) return -1.0;

    HINTERNET hConnect = WinHttpConnect(hSession, L"speed.cloudflare.com",
                                         INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!hConnect) {
        WinHttpCloseHandle(hSession);
        return -1.0;
    }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"POST",
        L"/__up",
        WINHTTP_NO_REFERER, WINHTTP_NO_DEFAULT_HEADERS,
        WINHTTP_DEFAULT_ACCEPT_FLAGS,
        WINHTTP_FLAG_SECURE);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return -1.0;
    }

    // Create 5MB of test data
    const size_t uploadSize = 5 * 1024 * 1024;
    std::vector<uint8_t> uploadData(uploadSize, 0x41);

    // Add content-type header
    std::wstring headers = L"Content-Type: application/octet-stream\r\n";
    WinHttpAddRequestHeaders(hRequest, headers.c_str(),
                              (DWORD)-1, WINHTTP_ADDREQ_FLAG_ADD);

    auto start = std::chrono::high_resolution_clock::now();

    BOOL bResults = WinHttpSendRequest(hRequest,
        WINHTTP_NO_ADDITIONAL_HEADERS, 0,
        uploadData.data(), (DWORD)uploadSize,
        (DWORD)uploadSize, 0);

    if (bResults) {
        bResults = WinHttpReceiveResponse(hRequest, nullptr);
    }

    double speed = -1.0;
    if (bResults) {
        auto end = std::chrono::high_resolution_clock::now();
        double seconds = std::chrono::duration<double>(end - start).count();

        if (seconds > 0) {
            speed = (double)uploadSize * 8.0 / 1000000.0 / seconds; // Mbps
        }

        // Read response (to complete the request)
        DWORD bytesAvailable = 0;
        uint8_t buffer[4096];
        DWORD bytesRead = 0;
        while (WinHttpQueryDataAvailable(hRequest, &bytesAvailable) && bytesAvailable > 0) {
            WinHttpReadData(hRequest, buffer,
                            min(bytesAvailable, (DWORD)sizeof(buffer)), &bytesRead);
        }
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    return speed;
}

} // namespace NetOpt
