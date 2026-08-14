#pragma once

#include "Types.h"
#include <vector>
#include <string>

namespace NetOpt {

// Optimizes network adapter hardware settings for lower latency
// and higher throughput. Uses PowerShell NetAdapter cmdlets.
class AdapterOptimizer {
public:
    AdapterOptimizer();
    ~AdapterOptimizer();

    // Get detailed info about all active adapters
    std::vector<AdapterInfo> GetActiveAdapters() const;

    // Get advanced properties of an adapter
    struct AdapterProperty {
        std::wstring displayName;
        std::wstring registryKeyword;
        std::wstring currentValue;
        std::wstring defaultValue;
        std::vector<std::wstring> validValues;
        std::wstring displayValue;
    };
    std::vector<AdapterProperty> GetAdvancedProperties(
        const std::wstring& interfaceName) const;

    // Set an advanced property
    OptResult SetProperty(const std::wstring& interfaceName,
                          const std::wstring& registryKeyword,
                          const std::wstring& value);

    // --- Preset optimizations ---

    // Disable power management on adapter (prevent sleep/wake)
    OptResult DisablePowerManagement(const std::wstring& interfaceName);

    // Enable interrupt moderation (reduces CPU, may add slight latency)
    // For PvP, disabling may reduce latency but increase CPU usage
    OptResult SetInterruptModeration(const std::wstring& interfaceName,
                                      bool enable);

    // Set receive buffers
    OptResult SetReceiveBuffers(const std::wstring& interfaceName,
                                 uint32_t value);

    // Set transmit/send buffers
    OptResult SetTransmitBuffers(const std::wstring& interfaceName,
                                  uint32_t value);

    // Enable Receive Side Scaling (RSS)
    OptResult SetRSS(const std::wstring& interfaceName, bool enable);

    // Enable jumbo frames (MTU 9000) - only if adapter supports it
    OptResult SetJumboFrames(const std::wstring& interfaceName, bool enable);

    // Set MTU for an interface
    OptResult SetMTU(const std::wstring& interfaceName, uint32_t mtu);

    // Disable Large Send Offload (LSO) - can reduce latency for small packets
    OptResult SetLSO(const std::wstring& interfaceName, bool enable);

    // Apply gaming-optimized adapter settings
    std::vector<OptResult> ApplyGamingOptimizations(
        const std::wstring& interfaceName,
        const ProgressCallback& progress = nullptr);

    // Revert adapter settings to defaults
    std::vector<OptResult> RevertOptimizations(
        const std::wstring& interfaceName,
        const ProgressCallback& progress = nullptr);

    // Check if an adapter supports a given feature
    bool SupportsFeature(const std::wstring& interfaceName,
                         const std::wstring& featureKeyword) const;

private:
    // Get the registry keyword for a display name
    std::wstring FindRegistryKeyword(const std::wstring& interfaceName,
                                      const std::wstring& displayName) const;
};

} // namespace NetOpt
