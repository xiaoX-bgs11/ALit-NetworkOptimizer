#pragma once

#include "Types.h"
#include <vector>
#include <string>

namespace NetOpt {

// Manages saving and loading optimization profiles.
// Profiles are stored as JSON files in the app data directory.
class ProfileManager {
public:
    ProfileManager();
    ~ProfileManager();

    // Save current optimization state as a named profile
    bool SaveProfile(const std::wstring& name,
                     const std::wstring& description,
                     OptLevel level,
                     const std::vector<OptimizationItem>& items);

    // Load a saved profile
    bool LoadProfile(const std::wstring& name, Profile& outProfile) const;

    // Delete a saved profile
    bool DeleteProfile(const std::wstring& name);

    // List all saved profiles
    std::vector<std::wstring> ListProfiles() const;

    // Get the profiles directory path
    std::wstring GetProfilesDir() const;

    // Export a profile to a file
    bool ExportProfile(const std::wstring& name,
                       const std::wstring& filePath) const;

    // Import a profile from a file
    bool ImportProfile(const std::wstring& filePath,
                       std::wstring& outName);

    // Get the last applied profile name
    std::wstring GetLastAppliedProfile() const;

    // Set the last applied profile name
    void SetLastAppliedProfile(const std::wstring& name);

private:
    // Simple JSON serialization (no external dependency)
    std::wstring SerializeProfile(const Profile& profile) const;
    bool DeserializeProfile(const std::wstring& json, Profile& outProfile) const;

    // Escape/unescape JSON strings
    std::wstring EscapeJson(const std::wstring& str) const;
    std::wstring UnescapeJson(const std::wstring& str) const;

    // Get a temp/app data path for storing profiles
    std::wstring m_profilesDir;
    std::wstring m_lastAppliedFile;
};

} // namespace NetOpt
