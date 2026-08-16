#pragma once

#include "Types.h"
#include "TcpOptimizer.h"
#include "DnsOptimizer.h"
#include "QoSManager.h"
#include "AdapterOptimizer.h"
#include "NetworkDiagnostics.h"
#include "ProfileManager.h"
#include <memory>
#include <vector>

namespace NetOpt {

// Main orchestrator that coordinates all optimization modules.
// This is the primary API the UI layer interacts with.
class NetworkOptimizationEngine {
public:
    static NetworkOptimizationEngine& Instance();

    // --- Initialization ---

    // Check if running as admin
    bool IsAdmin() const;

    // Restart with admin privileges
    bool RequestAdmin();

    // --- One-Click Optimization ---

    // Apply all optimizations for a given level (TCP + DNS + QoS + Adapter)
    struct OptimizationSummary {
        int totalItems;
        int successCount;
        int failureCount;
        std::vector<OptResult> results;
        std::vector<std::wstring> successMessages;
        std::vector<std::wstring> failureMessages;
    };

    OptimizationSummary ApplyAllOptimizations(
        OptLevel level,
        const std::wstring& interfaceName,
        const ProgressCallback& progress = nullptr);

    // Revert all optimizations
    OptimizationSummary RevertAllOptimizations(
        OptLevel level,
        const std::wstring& interfaceName,
        const ProgressCallback& progress = nullptr);

    // --- Module Accessors ---

    TcpOptimizer& GetTcpOptimizer() { return m_tcp; }
    DnsOptimizer& GetDnsOptimizer() { return m_dns; }
    QoSManager& GetQoSManager() { return m_qos; }
    AdapterOptimizer& GetAdapterOptimizer() { return m_adapter; }
    NetworkDiagnostics& GetDiagnostics() { return m_diag; }
    ProfileManager& GetProfileManager() { return m_profile; }

    // --- Convenience Methods ---

    // Get all active network adapters
    std::vector<AdapterInfo> GetActiveAdapters() const;

    // Get the primary (default gateway) adapter
    AdapterInfo GetPrimaryAdapter() const;

    // Apply Minecraft PvP specific optimizations
    OptimizationSummary ApplyMinecraftPvPOptimizations(
        const std::wstring& interfaceName,
        const ProgressCallback& progress = nullptr);

    // Apply DNS optimization with a preset
    OptResult ApplyDnsPreset(const std::wstring& interfaceName,
                             const std::wstring& presetName);

    // Flush DNS cache
    OptResult FlushDns();

    // Run speed test
    struct SpeedTestResult {
        double downloadMbps;
        double uploadMbps;
        double pingMs;
        std::wstring server;
    };
    SpeedTestResult RunSpeedTest(const std::wstring& testServer = L"");

    // Get current network diagnostic
    NetworkDiagnostic GetDiagnostic(const std::wstring& interfaceName) const;

    // --- Logging ---

    void SetLogCallback(const LogCallback& callback) { m_logCallback = callback; }
    void Log(const std::wstring& level, const std::wstring& message);

    // --- Status ---

    // Check if optimizations have been applied
    bool IsOptimized() const { return m_optimized; }
    void SetOptimized(bool val) { m_optimized = val; }

    // Get the last applied optimization level
    OptLevel GetLastLevel() const { return m_lastLevel; }

private:
    NetworkOptimizationEngine();
    ~NetworkOptimizationEngine();
    NetworkOptimizationEngine(const NetworkOptimizationEngine&) = delete;
    NetworkOptimizationEngine& operator=(const NetworkOptimizationEngine&) = delete;

    TcpOptimizer m_tcp;
    DnsOptimizer m_dns;
    QoSManager m_qos;
    AdapterOptimizer m_adapter;
    NetworkDiagnostics m_diag;
    ProfileManager m_profile;

    LogCallback m_logCallback;
    bool m_optimized = false;
    OptLevel m_lastLevel = OptLevel::Gaming;
};

} // namespace NetOpt
