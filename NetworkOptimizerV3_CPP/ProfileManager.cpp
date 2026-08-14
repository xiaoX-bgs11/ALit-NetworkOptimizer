#include "pch.h"
#include "ProfileManager.h"
#include <windows.h>
#include <shlobj.h>
#include <fstream>
#include <sstream>
#include <algorithm>

namespace NetOpt {

ProfileManager::ProfileManager() {
    // Use %APPDATA%\NetOptimizer\profiles
    wchar_t appData[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_APPDATA, nullptr, 0, appData))) {
        m_profilesDir = std::wstring(appData) + L"\\NetOptimizer\\profiles";
        m_lastAppliedFile = std::wstring(appData) + L"\\NetOptimizer\\last_applied.txt";
    } else {
        m_profilesDir = L"NetOptimizer\\profiles";
        m_lastAppliedFile = L"NetOptimizer\\last_applied.txt";
    }

    // Create directory if it doesn't exist
    DWORD attr = GetFileAttributesW(m_profilesDir.c_str());
    if (attr == INVALID_FILE_ATTRIBUTES) {
        // Create parent dir first
        std::wstring parent = m_profilesDir.substr(0, m_profilesDir.find_last_of(L'\\'));
        CreateDirectoryW(parent.c_str(), nullptr);
        CreateDirectoryW(m_profilesDir.c_str(), nullptr);
    }
}

ProfileManager::~ProfileManager() {}

std::wstring ProfileManager::GetProfilesDir() const {
    return m_profilesDir;
}

std::wstring ProfileManager::EscapeJson(const std::wstring& str) const {
    std::wstring result;
    result.reserve(str.size() + 10);
    for (wchar_t c : str) {
        switch (c) {
            case L'"':  result += L"\\\""; break;
            case L'\\': result += L"\\\\"; break;
            case L'\n': result += L"\\n"; break;
            case L'\r': result += L"\\r"; break;
            case L'\t': result += L"\\t"; break;
            default:
                if (c < 0x20) {
                    wchar_t buf[8];
                    swprintf_s(buf, 8, L"\\u%04x", (unsigned int)c);
                    result += buf;
                } else {
                    result += c;
                }
        }
    }
    return result;
}

std::wstring ProfileManager::UnescapeJson(const std::wstring& str) const {
    std::wstring result;
    result.reserve(str.size());
    for (size_t i = 0; i < str.size(); ++i) {
        if (str[i] == L'\\' && i + 1 < str.size()) {
            switch (str[i + 1]) {
                case L'"':  result += L'"';  i++; break;
                case L'\\': result += L'\\'; i++; break;
                case L'n':  result += L'\n'; i++; break;
                case L'r':  result += L'\r'; i++; break;
                case L't':  result += L'\t'; i++; break;
                case L'u':
                    if (i + 5 < str.size()) {
                        std::wstring hex = str.substr(i + 2, 4);
                        try {
                            wchar_t ch = (wchar_t)std::stoul(hex, nullptr, 16);
                            result += ch;
                        } catch (...) {
                            result += str[i];
                        }
                        i += 5;
                    }
                    break;
                default:
                    result += str[i];
            }
        } else {
            result += str[i];
        }
    }
    return result;
}

std::wstring ProfileManager::SerializeProfile(const Profile& profile) const {
    std::wostringstream ss;
    ss << L"{\n";
    ss << L"  \"name\": \"" << EscapeJson(profile.name) << L"\",\n";
    ss << L"  \"description\": \"" << EscapeJson(profile.description) << L"\",\n";
    ss << L"  \"level\": " << (int)profile.level << L",\n";
    ss << L"  \"items\": [\n";

    for (size_t i = 0; i < profile.items.size(); ++i) {
        const auto& item = profile.items[i];
        ss << L"    {\n";
        ss << L"      \"id\": \"" << EscapeJson(item.id) << L"\",\n";
        ss << L"      \"displayName\": \"" << EscapeJson(item.displayName) << L"\",\n";
        ss << L"      \"description\": \"" << EscapeJson(item.description) << L"\",\n";
        ss << L"      \"category\": " << (int)item.category << L",\n";
        ss << L"      \"recommended\": " << (item.recommended ? L"true" : L"false") << L",\n";
        ss << L"      \"applied\": " << (item.applied ? L"true" : L"false") << L",\n";
        ss << L"      \"applyCommand\": \"" << EscapeJson(item.applyCommand) << L"\",\n";
        ss << L"      \"revertCommand\": \"" << EscapeJson(item.revertCommand) << L"\",\n";
        ss << L"      \"regKeyPath\": \"" << EscapeJson(item.regKeyPath) << L"\",\n";
        ss << L"      \"regValueName\": \"" << EscapeJson(item.regValueName) << L"\",\n";
        ss << L"      \"regApplyValue\": \"" << EscapeJson(item.regApplyValue) << L"\",\n";
        ss << L"      \"regRevertValue\": \"" << EscapeJson(item.regRevertValue) << L"\",\n";
        ss << L"      \"isRegistry\": " << (item.isRegistry ? L"true" : L"false") << L"\n";
        ss << L"    }";
        if (i + 1 < profile.items.size()) ss << L",";
        ss << L"\n";
    }

    ss << L"  ]\n";
    ss << L"}\n";
    return ss.str();
}

bool ProfileManager::DeserializeProfile(const std::wstring& json,
                                          Profile& outProfile) const {
    // Simple JSON parser (not full-featured, but sufficient for our format)
    auto findValue = [&](const std::wstring& key) -> std::wstring {
        std::wstring search = L"\"" + key + L"\":";
        size_t pos = json.find(search);
        if (pos == std::wstring::npos) return L"";
        pos += search.size();
        // Skip whitespace
        while (pos < json.size() && (json[pos] == L' ' || json[pos] == L'\t')) pos++;
        if (pos >= json.size()) return L"";

        if (json[pos] == L'"') {
            // String value
            pos++;
            size_t end = pos;
            while (end < json.size()) {
                if (json[end] == L'\\' && end + 1 < json.size()) {
                    end += 2;
                } else if (json[end] == L'"') {
                    break;
                } else {
                    end++;
                }
            }
            return UnescapeJson(json.substr(pos, end - pos));
        } else {
            // Numeric/boolean value
            size_t end = pos;
            while (end < json.size() && json[end] != L',' && json[end] != L'}'
                   && json[end] != L'\n' && json[end] != L']') {
                end++;
            }
            std::wstring val = json.substr(pos, end - pos);
            // Trim
            val.erase(0, val.find_first_not_of(L" \t"));
            val.erase(val.find_last_not_of(L" \t") + 1);
            return val;
        }
    };

    outProfile.name = findValue(L"name");
    outProfile.description = findValue(L"description");

    std::wstring levelStr = findValue(L"level");
    try { outProfile.level = (OptLevel)std::stoul(levelStr); }
    catch (...) { outProfile.level = OptLevel::Gaming; }

    // Parse items array
    size_t arrayStart = json.find(L"\"items\":");
    if (arrayStart == std::wstring::npos) return true;
    arrayStart = json.find(L'[', arrayStart);
    if (arrayStart == std::wstring::npos) return true;

    size_t pos = arrayStart + 1;
    while (pos < json.size()) {
        size_t objStart = json.find(L'{', pos);
        if (objStart == std::wstring::npos) break;
        size_t objEnd = json.find(L'}', objStart);
        if (objEnd == std::wstring::npos) break;

        std::wstring objJson = json.substr(objStart, objEnd - objStart + 1);
        OptimizationItem item;

        auto getStr = [&](const std::wstring& key) -> std::wstring {
            std::wstring search = L"\"" + key + L"\":";
            size_t p = objJson.find(search);
            if (p == std::wstring::npos) return L"";
            p += search.size();
            while (p < objJson.size() && (objJson[p] == L' ' || objJson[p] == L'\t')) p++;
            if (p >= objJson.size() || objJson[p] != L'"') return L"";
            p++;
            size_t e = p;
            while (e < objJson.size()) {
                if (objJson[e] == L'\\' && e + 1 < objJson.size()) e += 2;
                else if (objJson[e] == L'"') break;
                else e++;
            }
            return UnescapeJson(objJson.substr(p, e - p));
        };

        auto getBool = [&](const std::wstring& key) -> bool {
            std::wstring search = L"\"" + key + L"\":";
            size_t p = objJson.find(search);
            if (p == std::wstring::npos) return false;
            p += search.size();
            while (p < objJson.size() && (objJson[p] == L' ' || objJson[p] == L'\t')) p++;
            return objJson.substr(p, 4) == L"true";
        };

        auto getInt = [&](const std::wstring& key) -> int {
            std::wstring search = L"\"" + key + L"\":";
            size_t p = objJson.find(search);
            if (p == std::wstring::npos) return 0;
            p += search.size();
            while (p < objJson.size() && (objJson[p] == L' ' || objJson[p] == L'\t')) p++;
            size_t e = p;
            while (e < objJson.size() && objJson[e] != L',' && objJson[e] != L'}') e++;
            try { return std::stoi(objJson.substr(p, e - p)); }
            catch (...) { return 0; }
        };

        item.id = getStr(L"id");
        item.displayName = getStr(L"displayName");
        item.description = getStr(L"description");
        item.category = (OptCategory)getInt(L"category");
        item.recommended = getBool(L"recommended");
        item.applied = getBool(L"applied");
        item.applyCommand = getStr(L"applyCommand");
        item.revertCommand = getStr(L"revertCommand");
        item.regKeyPath = getStr(L"regKeyPath");
        item.regValueName = getStr(L"regValueName");
        item.regApplyValue = getStr(L"regApplyValue");
        item.regRevertValue = getStr(L"regRevertValue");
        item.isRegistry = getBool(L"isRegistry");

        outProfile.items.push_back(item);
        pos = objEnd + 1;
    }

    return true;
}

bool ProfileManager::SaveProfile(const std::wstring& name,
                                  const std::wstring& description,
                                  OptLevel level,
                                  const std::vector<OptimizationItem>& items) {
    Profile profile;
    profile.name = name;
    profile.description = description;
    profile.level = level;
    profile.items = items;

    std::wstring json = SerializeProfile(profile);
    std::wstring filePath = m_profilesDir + L"\\" + name + L".json";

    std::ofstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    // Write UTF-8 BOM
    file.write("\xEF\xBB\xBF", 3);
    // Convert wide string to UTF-8
    std::string utf8;
    utf8.reserve(json.size() * 3);
    for (wchar_t c : json) {
        if (c < 0x80) {
            utf8 += (char)c;
        } else if (c < 0x800) {
            utf8 += (char)(0xC0 | (c >> 6));
            utf8 += (char)(0x80 | (c & 0x3F));
        } else {
            utf8 += (char)(0xE0 | (c >> 12));
            utf8 += (char)(0x80 | ((c >> 6) & 0x3F));
            utf8 += (char)(0x80 | (c & 0x3F));
        }
    }
    file.write(utf8.data(), utf8.size());
    file.close();

    return true;
}

bool ProfileManager::LoadProfile(const std::wstring& name, Profile& outProfile) const {
    std::wstring filePath = m_profilesDir + L"\\" + name + L".json";
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());
    file.close();

    // Skip BOM if present
    if (content.size() >= 3 &&
        (unsigned char)content[0] == 0xEF &&
        (unsigned char)content[1] == 0xBB &&
        (unsigned char)content[2] == 0xBF) {
        content = content.substr(3);
    }

    // Convert UTF-8 to wide string
    std::wstring json;
    for (size_t i = 0; i < content.size();) {
        unsigned char c = content[i];
        if (c < 0x80) {
            json += (wchar_t)c;
            i++;
        } else if (c < 0xE0) {
            if (i + 1 < content.size()) {
                wchar_t ch = ((c & 0x1F) << 6) | (content[i + 1] & 0x3F);
                json += ch;
                i += 2;
            } else { break; }
        } else {
            if (i + 2 < content.size()) {
                wchar_t ch = ((c & 0x0F) << 12) |
                             ((content[i + 1] & 0x3F) << 6) |
                             (content[i + 2] & 0x3F);
                json += ch;
                i += 3;
            } else { break; }
        }
    }

    return DeserializeProfile(json, outProfile);
}

bool ProfileManager::DeleteProfile(const std::wstring& name) {
    std::wstring filePath = m_profilesDir + L"\\" + name + L".json";
    return DeleteFileW(filePath.c_str()) != 0;
}

std::vector<std::wstring> ProfileManager::ListProfiles() const {
    std::vector<std::wstring> profiles;
    std::wstring searchPattern = m_profilesDir + L"\\*.json";

    WIN32_FIND_DATAW findData;
    HANDLE hFind = FindFirstFileW(searchPattern.c_str(), &findData);
    if (hFind == INVALID_HANDLE_VALUE) return profiles;

    do {
        if (!(findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
            std::wstring filename = findData.cFileName;
            // Remove .json extension
            size_t pos = filename.rfind(L".json");
            if (pos != std::wstring::npos) {
                filename = filename.substr(0, pos);
            }
            profiles.push_back(filename);
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);
    return profiles;
}

bool ProfileManager::ExportProfile(const std::wstring& name,
                                    const std::wstring& filePath) const {
    Profile profile;
    if (!LoadProfile(name, profile)) return false;

    std::wstring json = SerializeProfile(profile);
    std::ofstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    file.write("\xEF\xBB\xBF", 3);
    std::string utf8;
    for (wchar_t c : json) {
        if (c < 0x80) {
            utf8 += (char)c;
        } else if (c < 0x800) {
            utf8 += (char)(0xC0 | (c >> 6));
            utf8 += (char)(0x80 | (c & 0x3F));
        } else {
            utf8 += (char)(0xE0 | (c >> 12));
            utf8 += (char)(0x80 | ((c >> 6) & 0x3F));
            utf8 += (char)(0x80 | (c & 0x3F));
        }
    }
    file.write(utf8.data(), utf8.size());
    file.close();
    return true;
}

bool ProfileManager::ImportProfile(const std::wstring& filePath,
                                    std::wstring& outName) {
    // Read file
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());
    file.close();

    // Skip BOM
    if (content.size() >= 3 &&
        (unsigned char)content[0] == 0xEF &&
        (unsigned char)content[1] == 0xBB &&
        (unsigned char)content[2] == 0xBF) {
        content = content.substr(3);
    }

    // Convert to wide
    std::wstring json;
    for (size_t i = 0; i < content.size();) {
        unsigned char c = content[i];
        if (c < 0x80) {
            json += (wchar_t)c;
            i++;
        } else if (c < 0xE0) {
            if (i + 1 < content.size()) {
                wchar_t ch = ((c & 0x1F) << 6) | (content[i + 1] & 0x3F);
                json += ch;
                i += 2;
            } else { break; }
        } else {
            if (i + 2 < content.size()) {
                wchar_t ch = ((c & 0x0F) << 12) |
                             ((content[i + 1] & 0x3F) << 6) |
                             (content[i + 2] & 0x3F);
                json += ch;
                i += 3;
            } else { break; }
        }
    }

    Profile profile;
    if (!DeserializeProfile(json, profile)) return false;

    outName = profile.name;
    return SaveProfile(profile.name, profile.description,
                       profile.level, profile.items);
}

std::wstring ProfileManager::GetLastAppliedProfile() const {
    std::ifstream file(m_lastAppliedFile);
    if (!file.is_open()) return L"";
    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());

    std::wstring result;
    for (char c : content) {
        if (c != '\r' && c != '\n') result += (wchar_t)c;
    }
    return result;
}

void ProfileManager::SetLastAppliedProfile(const std::wstring& name) {
    std::ofstream file(m_lastAppliedFile);
    if (file.is_open()) {
        for (wchar_t c : name) {
            if (c < 0x80) file << (char)c;
        }
    }
}

} // namespace NetOpt
