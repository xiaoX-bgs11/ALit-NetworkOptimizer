#include "pch.h"
#include "NetworkOptimizationEngine.h"
#include "CommandRunner.h"
#include <algorithm>

namespace NetOpt {

NetworkOptimizationEngine& NetworkOptimizationEngine::Instance() {
    static NetworkOptimizationEngine instance;
    return instance;
}

NetworkOptimizationEngine::NetworkOptimizationEngine() {
    Log(L"INFO", L"Network Optimization Engine initialized");
}

NetworkOptimizationEngine::~NetworkOptimizationEngine() {}

bool NetworkOptimizationEngine::IsAdmin() const {
    return NetOpt::IsRunningAsAdmin();
}

bool NetworkOptimizationEngine::RequestAdmin() {
    return NetOpt::RestartAsAdmin();
}

void NetworkOptimizationEngine::Log(const std::wstring& level,
                                     const std::wstring& message) {
    if (m_logCallback) {
        LogEntry entry;
        // Format timestamp
        SYSTEMTIME st;
        GetLocalTime(&st);
        wchar_t timeBuf[64];
        swprintf_s(timeBuf, 64, L"%04d-%02d-%02d %02d:%02d:%02d",
                   st.wYear, st.wMonth, st.wDay,
                   st.wHour, st.wMinute, st.wSecond);
        entry.timestamp = timeBuf;
        entry.level = level;
        entry.message = message;
        m_logCallback(entry);
    }
}

std::vector<AdapterInfo> NetworkOptimizationEngine::GetActiveAdapters() const {
    return m_adapter.GetActiveAdapters();
}

AdapterInfo NetworkOptimizationEngine::GetPrimaryAdapter() const {
    auto adapters = GetActiveAdapters();
    // Find the adapter with a default gateway
    for (const auto& a : adapters) {
        if (!a.gateway.empty() && a.gateway != L"0.0.0.0") {
            return a;
        }
    }
    if (!adapters.empty()) return adapters[0];

    AdapterInfo empty;
    return empty;
}

NetworkOptimizationEngine::OptimizationSummary
NetworkOptimizationEngine::ApplyAllOptimizations(
    OptLevel level,
    const std::wstring& interfaceName,
    const ProgressCallback& progress) {

    OptimizationSummary summary;
    summary.totalItems = 0;
    summary.successCount = 0;
    summary.failureCount = 0;

    Log(L"INFO", L"Starting full optimization (level=" +
        std::to_wstring((int)level) + L")");

    // Phase 1: TCP/IP Stack + Registry optimizations
    Log(L"INFO", L"Phase 1: TCP/IP Stack Optimization");
    auto tcpProgress = [&](const std::wstring& name, int pct) {
        if (progress) progress(L"[TCP] " + name, pct * 30 / 100);
    };
    auto tcpResults = m_tcp.ApplyAll(level, tcpProgress);
    for (const auto& r : tcpResults) {
        summary.totalItems++;
        if (r.success) {
            summary.successCount++;
            summary.successMessages.push_back(r.message);
        } else {
            summary.failureCount++;
            summary.failureMessages.push_back(r.message + L": " + r.detail);
        }
    }

    // Phase 2: QoS policies for Minecraft
    Log(L"INFO", L"Phase 2: QoS Policy Configuration");
    if (progress) progress(L"[QoS] Applying Minecraft PvP QoS policies", 40);
    auto qosResults = m_qos.ApplyMinecraftPvPPresets();
    for (const auto& r : qosResults) {
        summary.totalItems++;
        if (r.success) {
            summary.successCount++;
            summary.successMessages.push_back(r.message);
        } else {
            summary.failureCount++;
            summary.failureMessages.push_back(r.message);
        }
    }

    // Phase 3: DNS optimization (set to Cloudflare for gaming)
    Log(L"INFO", L"Phase 3: DNS Optimization");
    if (progress) progress(L"[DNS] Setting optimized DNS servers", 60);
    if (!interfaceName.empty()) {
        auto presets = m_dns.GetPresetProfiles();
        if (!presets.empty()) {
            // Use Cloudflare for international, or AliDNS for China
            // Default to Cloudflare
            auto dnsResult = m_dns.ApplyPreset(interfaceName, presets[0]);
            summary.totalItems++;
            if (dnsResult.success) {
                summary.successCount++;
                summary.successMessages.push_back(L"DNS set to " + presets[0].name);
            } else {
                summary.failureCount++;
                summary.failureMessages.push_back(dnsResult.message);
            }
        }

        // Flush DNS cache
        auto flushResult = m_dns.FlushDnsCache();
        summary.totalItems++;
        if (flushResult.success) {
            summary.successCount++;
        } else {
            summary.failureCount++;
            summary.failureMessages.push_back(flushResult.message);
        }
    }

    // Phase 4: Adapter optimizations
    Log(L"INFO", L"Phase 4: Network Adapter Optimization");
    if (!interfaceName.empty()) {
        auto adapterProgress = [&](const std::wstring& name, int pct) {
            if (progress) progress(L"[Adapter] " + name, 70 + pct * 30 / 100);
        };
        auto adapterResults = m_adapter.ApplyGamingOptimizations(
            interfaceName, adapterProgress);
        for (const auto& r : adapterResults) {
            summary.totalItems++;
            if (r.success) {
                summary.successCount++;
                summary.successMessages.push_back(r.message);
            } else {
                summary.failureCount++;
                summary.failureMessages.push_back(r.message);
            }
        }
    }

    if (progress) progress(L"Complete", 100);

    m_optimized = true;
    m_lastLevel = level;

    Log(L"INFO", L"Optimization complete: " +
        std::to_wstring(summary.successCount) + L" succeeded, " +
        std::to_wstring(summary.failureCount) + L" failed");

    // Save the applied profile
    m_profile.SetLastAppliedProfile(
        level == OptLevel::Gaming ? L"Gaming" :
        level == OptLevel::Balanced ? L"Balanced" :
        level == OptLevel::Bandwidth ? L"Bandwidth" : L"Custom");

    return summary;
}

NetworkOptimizationEngine::OptimizationSummary
NetworkOptimizationEngine::RevertAllOptimizations(
    OptLevel level,
    const std::wstring& interfaceName,
    const ProgressCallback& progress) {

    OptimizationSummary summary;
    summary.totalItems = 0;
    summary.successCount = 0;
    summary.failureCount = 0;

    Log(L"INFO", L"Starting revert process");

    // Revert TCP
    auto tcpProgress = [&](const std::wstring& name, int pct) {
        if (progress) progress(L"[TCP] " + name, pct * 30 / 100);
    };
    auto tcpResults = m_tcp.RevertAll(level, tcpProgress);
    for (const auto& r : tcpResults) {
        summary.totalItems++;
        if (r.success) { summary.successCount++; }
        else { summary.failureCount++; summary.failureMessages.push_back(r.message); }
    }

    // Remove QoS policies
    if (progress) progress(L"[QoS] Removing QoS policies", 40);
    auto qosResult = m_qos.RemoveAllAppPolicies();
    summary.totalItems++;
    if (qosResult.success) {
        summary.successCount++;
    } else {
        summary.failureCount++;
        summary.failureMessages.push_back(qosResult.message);
    }

    // Restore DNS to DHCP
    if (progress) progress(L"[DNS] Restoring DNS", 60);
    if (!interfaceName.empty()) {
        auto dnsResult = m_dns.RestoreDns(interfaceName);
        summary.totalItems++;
        if (dnsResult.success) {
            summary.successCount++;
        } else {
            summary.failureCount++;
            summary.failureMessages.push_back(dnsResult.message);
        }
    }

    // Revert adapter
    if (progress) progress(L"[Adapter] Reverting adapter settings", 70);
    if (!interfaceName.empty()) {
        auto adapterProgress = [&](const std::wstring& name, int pct) {
            if (progress) progress(L"[Adapter] " + name, 70 + pct * 30 / 100);
        };
        auto adapterResults = m_adapter.RevertOptimizations(
            interfaceName, adapterProgress);
        for (const auto& r : adapterResults) {
            summary.totalItems++;
            if (r.success) { summary.successCount++; }
            else { summary.failureCount++; summary.failureMessages.push_back(r.message); }
        }
    }

    if (progress) progress(L"Complete", 100);

    m_optimized = false;

    Log(L"INFO", L"Revert complete: " +
        std::to_wstring(summary.successCount) + L" succeeded, " +
        std::to_wstring(summary.failureCount) + L" failed");

    return summary;
}

NetworkOptimizationEngine::OptimizationSummary
NetworkOptimizationEngine::ApplyMinecraftPvPOptimizations(
    const std::wstring& interfaceName,
    const ProgressCallback& progress) {

    return ApplyAllOptimizations(OptLevel::Gaming, interfaceName, progress);
}

OptResult NetworkOptimizationEngine::ApplyDnsPreset(
    const std::wstring& interfaceName,
    const std::wstring& presetName) {

    auto presets = m_dns.GetPresetProfiles();
    for (const auto& p : presets) {
        if (p.name == presetName) {
            return m_dns.ApplyPreset(interfaceName, p);
        }
    }

    OptResult result;
    result.success = false;
    result.message = L"DNS preset not found: " + presetName;
    return result;
}

OptResult NetworkOptimizationEngine::FlushDns() {
    return m_dns.FlushDnsCache();
}

NetworkOptimizationEngine::SpeedTestResult
NetworkOptimizationEngine::RunSpeedTest(const std::wstring& testServer) {
    SpeedTestResult result;
    result.downloadMbps = 0;
    result.uploadMbps = 0;
    result.pingMs = 0;

    Log(L"INFO", L"Running speed test...");

    // Ping test
    auto adapter = GetPrimaryAdapter();
    if (!adapter.gateway.empty()) {
        result.pingMs = m_diag.MeasurePing(adapter.gateway, 5);
    }
    if (result.pingMs <= 0) {
        // Try pinging a public server
        result.pingMs = m_diag.MeasurePing(L"1.1.1.1", 5);
    }

    // Download speed
    result.downloadMbps = m_diag.EstimateDownloadSpeed();
    result.server = L"Cloudflare";

    // Upload speed
    result.uploadMbps = m_diag.EstimateUploadSpeed();

    Log(L"INFO", L"Speed test: Download=" +
        std::to_wstring((int)result.downloadMbps) + L"Mbps, Upload=" +
        std::to_wstring((int)result.uploadMbps) + L"Mbps, Ping=" +
        std::to_wstring((int)result.pingMs) + L"ms");

    return result;
}

NetworkDiagnostic NetworkOptimizationEngine::GetDiagnostic(
    const std::wstring& interfaceName) const {
    return m_diag.RunFullDiagnostic(interfaceName);
}

} // namespace NetOpt
