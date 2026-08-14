#pragma once

#include "Types.h"
#include <vector>
#include <string>
#include <atomic>
#include <thread>
#include <mutex>
#include <functional>

namespace NetOpt {

// Provides real-time network diagnostics: bandwidth monitoring,
// latency measurement, MTU detection, and packet loss analysis.
class NetworkDiagnostics {
public:
    NetworkDiagnostics();
    ~NetworkDiagnostics();

    // --- Bandwidth Monitoring ---

    // Start monitoring bandwidth on a specific interface
    // callback is called periodically with current speeds
    using BandwidthCallback = std::function<void(const BandwidthSample&)>;
    void StartBandwidthMonitor(const std::wstring& interfaceName,
                                BandwidthCallback callback,
                                uint32_t intervalMs = 1000);
    void StopBandwidthMonitor();

    // Get a single bandwidth sample
    BandwidthSample GetBandwidthSample(const std::wstring& interfaceName) const;

    // --- Latency Measurement ---

    // Ping a host and return average latency in ms
    // Uses IcmpSendEcho for native ICMP
    double MeasurePing(const std::wstring& host, int count = 10) const;

    // Measure jitter (variation in latency)
    double MeasureJitter(const std::wstring& host, int count = 10) const;

    // Measure packet loss percentage
    uint32_t MeasurePacketLoss(const std::wstring& host, int count = 20) const;

    // --- MTU Detection ---

    // Detect the optimal MTU (maximum payload without fragmentation)
    // Returns the MTU value (e.g., 1500 for standard Ethernet)
    uint32_t DetectOptimalMTU(const std::wstring& gateway) const;

    // --- Full Diagnostics ---

    // Run a complete network diagnostic
    NetworkDiagnostic RunFullDiagnostic(const std::wstring& interfaceName) const;

    // Get current network adapter info
    std::vector<AdapterInfo> GetAdapters() const;

    // --- Speed Test ---

    // Estimate download speed by downloading a test file
    // Uses WinHTTP to download from a speed test endpoint
    double EstimateDownloadSpeed() const;

    // Estimate upload speed
    double EstimateUploadSpeed() const;

private:
    // Get interface index from name
    uint32_t GetInterfaceIndex(const std::wstring& interfaceName) const;

    // Get bytes sent/received for an interface
    bool GetInterfaceStats(uint32_t ifIndex,
                           uint64_t& bytesSent,
                           uint64_t& bytesReceived) const;

    // ICMP ping helper
    struct PingResult {
        bool success;
        double latencyMs;
    };
    PingResult IcmpPing(const std::wstring& host, uint32_t timeoutMs = 1000) const;

    std::atomic<bool> m_monitoring{false};
    std::thread m_monitorThread;
    mutable std::mutex m_mutex;

    // Previous sample for delta calculation
    uint64_t m_prevBytesSent = 0;
    uint64_t m_prevBytesReceived = 0;
    uint64_t m_prevTimestamp = 0;
};

} // namespace NetOpt
