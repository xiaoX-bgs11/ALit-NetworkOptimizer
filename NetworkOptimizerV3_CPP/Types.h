#pragma once

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <cstdint>

namespace NetOpt {

// Optimization category
enum class OptCategory {
    TcpStack,
    RegistryTcp,
    Dns,
    QoS,
    Adapter,
    SystemProfile,
    MTU
};

// Optimization level
enum class OptLevel {
    Gaming,       // Maximum latency reduction (for PvP)
    Balanced,     // Good balance of speed and latency
    Bandwidth,    // Maximum throughput
    Custom        // User-defined
};

// Result of an optimization operation
struct OptResult {
    bool success = false;
    std::wstring message;
    std::wstring detail;
};

// A single optimization action
struct OptimizationItem {
    std::wstring id;
    std::wstring displayName;
    std::wstring description;
    OptCategory category;
    bool recommended = true;
    bool applied = false;
    // The command or registry operation to apply
    std::wstring applyCommand;
    std::wstring revertCommand;
    // For registry operations
    std::wstring regKeyPath;
    std::wstring regValueName;
    std::wstring regApplyValue;
    std::wstring regRevertValue;    // empty = delete
    bool isRegistry = false;
    std::wstring regInterfaceGuid;  // for per-interface settings
};

// Network adapter info
struct AdapterInfo {
    std::wstring name;          // Interface name (e.g., "Ethernet")
    std::wstring description;   // Adapter description
    std::wstring guid;          // Interface GUID
    std::wstring ipAddress;
    std::wstring gateway;
    std::wstring dnsServers;
    std::wstring macAddress;
    uint32_t linkSpeed = 0;     // in Mbps
    bool isUp = false;
    uint32_t mtu = 0;
};

// DNS benchmark result
struct DnsResult {
    std::wstring server;
    std::wstring ip;
    uint32_t latencyMs = 0;     // Average latency
    bool success = false;
};

// Bandwidth measurement
struct BandwidthSample {
    uint64_t timestamp = 0;     // Unix ms
    uint64_t bytesSent = 0;
    uint64_t bytesReceived = 0;
    double uploadSpeed = 0;     // Mbps
    double downloadSpeed = 0;   // Mbps
};

// Diagnostic info
struct NetworkDiagnostic {
    std::wstring adapterName;
    std::wstring ipAddress;
    std::wstring gateway;
    double pingMs = 0;          // Ping to gateway
    double jitterMs = 0;
    uint32_t packetLoss = 0;    // percentage
    uint32_t mtu = 0;
    double downloadSpeed = 0;   // Mbps (estimated)
    double uploadSpeed = 0;     // Mbps (estimated)
    std::wstring dnsServer;
    double dnsLatencyMs = 0;
};

// Optimization profile
struct Profile {
    std::wstring name;
    std::wstring description;
    OptLevel level;
    std::vector<OptimizationItem> items;
};

// Log entry
struct LogEntry {
    std::wstring timestamp;
    std::wstring level;         // INFO, WARN, ERROR
    std::wstring message;
};

// Callback for progress updates
using ProgressCallback = std::function<void(const std::wstring&, int)>;
using LogCallback = std::function<void(const LogEntry&)>;

} // namespace NetOpt
