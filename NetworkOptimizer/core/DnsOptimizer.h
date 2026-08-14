#pragma once

#include "Types.h"
#include <vector>
#include <string>

namespace NetOpt {

// Optimizes DNS settings for faster resolution and lower latency.
class DnsOptimizer {
public:
    DnsOptimizer();
    ~DnsOptimizer();

    // Get list of active network adapters with their current DNS
    std::vector<AdapterInfo> GetAdapters() const;

    // Get current DNS servers for an interface
    std::wstring GetCurrentDns(const std::wstring& interfaceName) const;

    // Set DNS servers for an interface
    // primary and secondary are IP addresses (e.g., "1.1.1.1")
    OptResult SetDns(const std::wstring& interfaceName,
                     const std::wstring& primary,
                     const std::wstring& secondary);

    // Restore DHCP-assigned DNS (clear static DNS)
    OptResult RestoreDns(const std::wstring& interfaceName);

    // Clear DNS resolver cache
    OptResult FlushDnsCache();

    // Benchmark a list of DNS servers
    // servers: vector of {name, ip} pairs
    std::vector<DnsResult> BenchmarkDns(
        const std::vector<std::pair<std::wstring, std::wstring>>& servers) const;

    // Get preset DNS profiles
    struct DnsProfile {
        std::wstring name;
        std::wstring primary;
        std::wstring secondary;
        std::wstring description;
    };
    std::vector<DnsProfile> GetPresetProfiles() const;

    // Apply a preset DNS profile to an interface
    OptResult ApplyPreset(const std::wstring& interfaceName,
                          const DnsProfile& profile);

private:
    // Measure DNS resolution latency using nslookup
    uint32_t MeasureDnsLatency(const std::wstring& dnsServer) const;

    // Run a ping and extract average latency
    double PingHost(const std::wstring& host, int count = 4) const;
};

} // namespace NetOpt
