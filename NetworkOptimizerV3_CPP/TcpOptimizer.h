#pragma once

#include "Types.h"
#include <vector>
#include <string>

namespace NetOpt {

// Optimizes the Windows TCP/IP stack for low latency and high throughput.
// All settings are documented Microsoft Windows parameters.
class TcpOptimizer {
public:
    TcpOptimizer();
    ~TcpOptimizer();

    // Get all available optimization items
    std::vector<OptimizationItem> GetOptimizationItems(OptLevel level) const;

    // Get current TCP global settings (via netsh)
    std::wstring GetCurrentTcpGlobalSettings() const;

    // Get current registry TCP parameter value
    std::wstring GetRegistryValue(const std::wstring& keyPath,
                                    const std::wstring& valueName) const;

    // Apply a single optimization item
    OptResult ApplyItem(const OptimizationItem& item);

    // Revert a single optimization item
    OptResult RevertItem(const OptimizationItem& item);

    // Apply all items for a given level
    std::vector<OptResult> ApplyAll(OptLevel level,
                                     const ProgressCallback& progress = nullptr);

    // Revert all items for a given level
    std::vector<OptResult> RevertAll(OptLevel level,
                                      const ProgressCallback& progress = nullptr);

    // Get the list of active network interface GUIDs
    std::vector<std::wstring> GetActiveInterfaceGuids() const;

    // Get interface names mapped to GUIDs
    std::map<std::wstring, std::wstring> GetInterfaceNames() const;

private:
    // Registry helpers
    bool SetRegistryValue(const std::wstring& keyPath,
                          const std::wstring& valueName,
                          DWORD value);
    bool SetRegistryValue(const std::wstring& keyPath,
                          const std::wstring& valueName,
                          const std::wstring& value);
    bool DeleteRegistryValue(const std::wstring& keyPath,
                             const std::wstring& valueName);

    // Netsh helper
    OptResult RunNetshCommand(const std::wstring& command);

    // Build optimization items for different levels
    std::vector<OptimizationItem> BuildGamingItems() const;
    std::vector<OptimizationItem> BuildBalancedItems() const;
    std::vector<OptimizationItem> BuildBandwidthItems() const;

    // Get the TCP/IP Parameters registry base path
    static constexpr const wchar_t* kTcpParamsPath =
        L"SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters";
    static constexpr const wchar_t* kTcpInterfacesPath =
        L"SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces";
    static constexpr const wchar_t* kSystemProfilePath =
        L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile";
    static constexpr const wchar_t* kGamesTaskPath =
        L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games";
};

} // namespace NetOpt
