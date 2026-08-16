#pragma once

#include "Types.h"
#include <vector>
#include <string>

namespace NetOpt {

// Manages Windows QoS (Quality of Service) policies to prioritize
// Minecraft and game traffic. Uses netsh qos commands.
class QoSManager {
public:
    QoSManager();
    ~QoSManager();

    // Add a QoS policy to prioritize an application
    // appName: e.g., "javaw.exe" for Minecraft
    // dscp: DSCP value (46 = EF for real-time, 0 = default)
    // throttleRate: "none" for no throttling, or a number in bytes/sec
    OptResult AddAppPolicy(const std::wstring& policyName,
                           const std::wstring& appPath,
                           int dscp = 46,
                           const std::wstring& throttleRate = L"none");

    // Add a QoS policy for a specific port (e.g., 25565 for Minecraft)
    OptResult AddPortPolicy(const std::wstring& policyName,
                            int port,
                            int dscp = 46,
                            const std::wstring& throttleRate = L"none");

    // Remove a QoS policy by name
    OptResult RemovePolicy(const std::wstring& policyName);

    // List all QoS policies
    std::wstring ListPolicies() const;

    // Remove all QoS policies created by this app (prefix "NetOpt_")
    OptResult RemoveAllAppPolicies();

    // Get preset QoS profiles for Minecraft
    struct QoSPreset {
        std::wstring name;
        std::wstring appPath;
        int port;
        int dscp;
        std::wstring description;
        bool isPortBased;
    };
    std::vector<QoSPreset> GetPresets() const;

    // Apply all preset QoS policies for Minecraft PvP
    std::vector<OptResult> ApplyMinecraftPvPPresets();

    // Check if a policy exists
    bool PolicyExists(const std::wstring& policyName) const;

private:
    static constexpr const wchar_t* kPolicyPrefix = L"NetOpt_";

    std::wstring GetFullPolicyName(const std::wstring& name) const {
        return kPolicyPrefix + name;
    }
};

} // namespace NetOpt
