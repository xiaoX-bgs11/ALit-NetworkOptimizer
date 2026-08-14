// ALit-网络优化工具V3 - C++ Win32 GUI Implementation
// Full feature parity with PowerShell version, pure C++ native EXE
#define _WIN32_WINNT 0x0A00
#define NTDDI_VERSION 0x0A000000
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <dwmapi.h>
#include <gdiplus.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <string>
#include <vector>
#include <map>
#include <thread>
#include <atomic>
#include <chrono>
#include <algorithm>
#include <sstream>
#include <fstream>

// Core module headers
#include "Types.h"
#include "CommandRunner.h"
#include "TcpOptimizer.h"
#include "DnsOptimizer.h"
#include "QoSManager.h"
#include "AdapterOptimizer.h"
#include "NetworkDiagnostics.h"
#include "NetworkOptimizationEngine.h"
#include "ProfileManager.h"

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "msimg32.lib")

using namespace NetOpt;

// ========== COLOR THEME ==========
#define COL_BG          RGB(0x1E, 0x1E, 0x1E)
#define COL_TITLEBAR    RGB(0x17, 0x17, 0x17)
#define COL_SIDEBAR      RGB(0x1B, 0x1B, 0x1B)
#define COL_NAV_INACTIVE RGB(0x2A, 0x2A, 0x2A)
#define COL_NAV_ACTIVE   RGB(0x2D, 0x5A, 0x7C)
#define COL_CARD         RGB(0x2B, 0x2B, 0x2B)
#define COL_PANEL        RGB(0x16, 0x21, 0x3E)
#define COL_DEEPBLUE     RGB(0x0F, 0x34, 0x60)
#define COL_TEXT         RGB(0xE8, 0xE8, 0xE8)
#define COL_TEXT_DIM     RGB(0xE0, 0xE0, 0xE0)
#define COL_TEXT_TITLE   RGB(0xF2, 0xF2, 0xF2)
#define COL_ACCENT       RGB(0x7C, 0xC7, 0xFF)
#define COL_GREEN        RGB(0x00, 0xE6, 0x76)
#define COL_RED          RGB(0xEF, 0x53, 0x50)
#define COL_ORANGE       RGB(0xFF, 0xB7, 0x4D)
#define COL_BTN_DARK     RGB(0x3A, 0x3A, 0x3A)
#define COL_BTN_HOVER    RGB(0x4A, 0x4A, 0x4A)
#define COL_TEXTBOX_BG   RGB(0x33, 0x33, 0x33)
#define COL_TEXTBOX_BRD  RGB(0x55, 0x55, 0x55)
#define COL_INPUT_BG     RGB(0x0F, 0x34, 0x60)
#define COL_INPUT_BRD    RGB(0x2A, 0x2A, 0x4A)
#define COL_CHECK_BG     RGB(0x2A, 0x2A, 0x2A)
#define COL_CHECK_BRD    RGB(0x66, 0x66, 0x66)
#define COL_CLOSE_BG     RGB(0x3A, 0x1F, 0x24)
#define COL_CLOSE_FG     RGB(0xFF, 0xB4, 0xB4)
#define COL_MIN_BG       RGB(0x25, 0x25, 0x25)
#define COL_WD_PANEL     RGB(0x1A, 0x1A, 0x2E)

// Font names
#define FONT_MAIN L"Microsoft YaHei UI"
#define FONT_MONO L"Consolas"

// ========== CONTROL IDS ==========
// Navigation buttons: 100-109
#define IDC_NAV_CONFIG     100
#define IDC_NAV_TCP        101
#define IDC_NAV_DNS        102
#define IDC_NAV_QOS        103
#define IDC_NAV_HOSTS      104
#define IDC_NAV_CUSTOM     105
#define IDC_NAV_TEST       106
#define IDC_NAV_DIAG       107
#define IDC_NAV_LOG        108
#define IDC_NAV_SETTINGS   109

// Title bar buttons
#define IDC_BTN_MINIMIZE   200
#define IDC_BTN_CLOSE      201

// Dashboard controls
#define IDC_BTN_BALANCED   300
#define IDC_BTN_NORMAL     301
#define IDC_BTN_COMPLETE   302
#define IDC_BTN_REVERT     303
#define IDC_BTN_OPTIMIZE   304
#define IDC_BTN_REVERT_ACT  305
#define IDC_BTN_SPEEDTEST  306
#define IDC_STAT_PING      310
#define IDC_STAT_DOWNLOAD  311
#define IDC_STAT_UPLOAD    312
#define IDC_STAT_DNS       313
#define IDC_STAT_CPU       314
#define IDC_STAT_MEM       315
#define IDC_PROGRESS       320
#define IDC_STATUS_TEXT    321
#define IDC_RESULTS_LIST   322
#define IDC_MODE_LABEL    323

// TCP page
#define IDC_BTN_REFRESH_TCP 400
#define IDC_TCP_TEXT        401

// DNS page
#define IDC_DNS_BTN_START   500
#define IDC_DNS_BTN_FLUSH    502
#define IDC_DNS_BTN_APPLY    503
#define IDC_DNS_BTN_RESTORE  504
#define IDC_DNS_BTN_SPEED    505
#define IDC_DNS_CURRENT      506
#define IDC_DNS_BTN_0        510
#define IDC_DNS_BTN_1        511
#define IDC_DNS_BTN_2        512
#define IDC_DNS_BTN_3        513
#define IDC_DNS_BTN_4        514
#define IDC_DNS_TEXT_0       520
#define IDC_DNS_TEXT_1       521
#define IDC_DNS_TEXT_2       522
#define IDC_DNS_TEXT_3       523
#define IDC_DNS_TEXT_4       524

// QoS page
#define IDC_BTN_APPLY_QOS   600
#define IDC_BTN_REMOVE_QOS  601
#define IDC_BTN_REFRESH_QOS 602
#define IDC_QOS_TEXT        603

// Hosts page
#define IDC_BTN_LOAD_HOSTS   700
#define IDC_BTN_SAVE_HOSTS   701
#define IDC_BTN_OPT_HOSTS    702
#define IDC_BTN_RESET_HOSTS  703
#define IDC_HOSTS_EDITOR     704

// Custom page checkboxes: 800-829
#define IDC_BTN_APPLY_CUSTOM  830
#define IDC_BTN_REC_CUSTOM    831
#define IDC_BTN_CLEAR_CUSTOM  832
#define IDC_CUSTOM_SCROLL     833

// Test page
#define IDC_BTN_ADAPTER_DEEP  900
#define IDC_BTN_SIM_APPLY     901
#define IDC_BTN_SIM_RESTORE   902
#define IDC_BTN_SIM_STATUS    903
#define IDC_SIM_TEXT          904
#define IDC_BTN_WD_START      910
#define IDC_BTN_WD_STOP       911
#define IDC_BTN_WD_REFRESH    912
#define IDC_BTN_WD_UNINSTALL  913
#define IDC_WD_RESULT         914
#define IDC_WD_MODE_0         915
#define IDC_WD_MODE_1         916
#define IDC_WD_MODE_2         917
#define IDC_WD_MODE_3         918
#define IDC_WD_MODE_4         919
#define IDC_WD_MODE_LABEL     920
#define IDC_WD_TCP_PORT       921
#define IDC_WD_UDP_PORT       922
#define IDC_WD_DSCP           923
#define IDC_BTN_ACCEL_DETECT  930
#define IDC_BTN_ACCEL_APPLY   931
#define IDC_ACCEL_STATUS      932
#define IDC_ACCEL_SELECTOR    933
#define IDC_GAME_SELECTOR     934
#define IDC_CHK_ACCEL_COMPAT  935
#define IDC_BTN_DRV_CHECK     940
#define IDC_BTN_DRV_OPTIMIZE  941
#define IDC_DRV_LIST          942
#define IDC_BTN_MTU_DETECT    950
#define IDC_BTN_MTU_APPLY     951
#define IDC_BTN_MTU_RESTORE   952
#define IDC_MTU_RESULT        953
#define IDC_MTU_ADAPTER       954

// Sim checkboxes
#define IDC_CHK_SIM_QOS       960
#define IDC_CHK_SIM_PROC      961
#define IDC_CHK_SIM_TIMER     962
#define IDC_CHK_SIM_INTERRUPT 963
#define IDC_CHK_SIM_RSS       964
#define IDC_CHK_SIM_THROTTLE  965

// Driver checkboxes
#define IDC_CHK_DRV_RSS       970
#define IDC_CHK_DRV_POWER     971
#define IDC_CHK_DRV_ENERGY    972
#define IDC_CHK_DRV_GREEN     973
#define IDC_CHK_DRV_POWERMODE 974
#define IDC_CHK_DRV_ULTRA     975
#define IDC_CHK_DRV_INTERRUPT 976
#define IDC_CHK_DRV_FLOW      977
#define IDC_CHK_DRV_REGECO    978

// Diagnostics page
#define IDC_MONITOR_TOGGLE    1000
#define IDC_REALTIME_DL      1001
#define IDC_REALTIME_UL       1002
#define IDC_DL_BAR            1003
#define IDC_UL_BAR            1004
#define IDC_BTN_RUN_DIAG      1005
#define IDC_DIAG_TEXT         1006

// Log page
#define IDC_BTN_EXPORT_LOG    1100
#define IDC_BTN_CLEAR_LOG     1101
#define IDC_LOG_LIST          1102

// Settings page
#define IDC_CHK_AUTOSTART     1200
#define IDC_CHK_SYSINFO       1201
#define IDC_RADIO_DARK        1202
#define IDC_RADIO_LIGHT       1203
#define IDC_SETTINGS_CPU      1204
#define IDC_SETTINGS_MEM      1205

// Custom checkboxes (24 items)
#define IDC_OPT_BASE 1300  // 1300-1323

// Sidebar status
#define IDC_SIDEBAR_STATUS   1400

// ========== GLOBALS ==========
HINSTANCE g_hInst = nullptr;
HWND g_hMainWnd = nullptr;
HWND g_hPages[10] = {0};  // 10 page containers
int g_currentPage = 0;
HFONT g_hFontMain = nullptr;
HFONT g_hFontTitle = nullptr;
HFONT g_hFontSmall = nullptr;
HFONT g_hFontMono = nullptr;
HFONT g_hFontLarge = nullptr;
HFONT g_hFontBold = nullptr;

int g_selectedMode = 0;  // 0=Balanced, 1=Normal, 2=Complete, 3=Revert
int g_selectedDns = -1;
int g_wdMode = 1;  // Default: Best mode
UINT g_detectedMtu = 0;

// WinDivert
std::thread g_wdThread;
std::atomic<bool> g_wdRunning(false);
HMODULE g_wdDll = nullptr;
std::wstring g_wdDir;

// Bandwidth monitor
std::thread g_bwThread;
std::atomic<bool> g_bwRunning(false);

// Log entries
std::vector<std::wstring> g_logEntries;

// Custom optimization items
struct CustomOptItem {
    int checkId;
    std::wstring name;
    std::vector<std::wstring> commands;
    bool recommended;
};
std::vector<CustomOptItem> g_customItems;

// Mode names
const wchar_t* g_modeNames[] = { L"均衡（满足日常体验）", L"普通（优化一部分网络体验）", L"完全（拥有所有网络优化）", L"还原（还原所有修改）" };
const wchar_t* g_modeShortNames[] = { L"均衡", L"普通", L"完全", L"还原" };

// DNS presets
struct DnsPreset { const wchar_t* name; const wchar_t* primary; const wchar_t* secondary; };
DnsPreset g_dnsPresets[] = {
    { L"Cloudflare", L"1.1.1.1", L"1.0.0.1" },
    { L"Google", L"8.8.8.8", L"8.8.4.4" },
    { L"阿里DNS", L"223.5.5.5", L"223.6.6.6" },
    { L"114DNS", L"114.114.114.114", L"114.114.115.115" },
    { L"DNSPod", L"119.29.29.29", L"182.254.116.116" }
};

// WD mode names
const wchar_t* g_wdModeNames[] = { L"普通模式", L"最佳模式", L"急速模式", L"狂暴模式", L"Backtrack" };

// ========== HELPER FUNCTIONS ==========

HFONT CreateFontHelper(int size, bool bold = false, const wchar_t* fontName = FONT_MAIN) {
    HDC hdc = GetDC(nullptr);
    int dpi = GetDeviceCaps(hdc, LOGPIXELSY);
    ReleaseDC(nullptr, hdc);
    int height = -MulDiv(size, dpi, 72);
    return CreateFontW(height, 0, 0, 0, bold ? FW_SEMIBOLD : FW_NORMAL,
        FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_TT_PRECIS,
        CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, fontName);
}

std::wstring RunCmd(const std::wstring& cmd) {
    return RunCommand(cmd, nullptr);
}

int RunCmdExit(const std::wstring& cmd) {
    int exitCode = 0;
    RunCommand(cmd, &exitCode);
    return exitCode;
}

void AddLog(const std::wstring& level, const std::wstring& msg) {
    auto now = std::chrono::system_clock::now();
    auto t = std::chrono::system_clock::to_time_t(now);
    std::tm tm;
    localtime_s(&tm, &t);
    wchar_t timeBuf[16];
    swprintf_s(timeBuf, L"%02d:%02d:%02d", tm.tm_hour, tm.tm_min, tm.tm_sec);
    std::wstring entry = std::wstring(timeBuf) + L" " + level + L" : " + msg;
    g_logEntries.push_back(entry);
    if (g_logEntries.size() > 500) g_logEntries.erase(g_logEntries.begin());

    HWND hLog = GetDlgItem(g_hMainWnd, IDC_LOG_LIST);
    if (hLog) {
        int idx = ListBox_AddString(hLog, entry.c_str());
        ListBox_SetTopIndex(hLog, idx);
    }
    if (g_hPages[8] && IsWindowVisible(g_hPages[8])) {
        InvalidateRect(hLog, nullptr, TRUE);
    }
}

std::wstring GetActiveAdapterName() {
    auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
    if (adapters.empty()) return L"";
    return adapters[0].name;
}

// Create a dark-themed button
HWND CreateDarkButton(HWND parent, int id, const wchar_t* text, int x, int y, int w, int h, COLORREF bg, COLORREF fg) {
    HWND btn = CreateWindowExW(0, L"BUTTON", text, WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_TEXT,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(btn, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
    SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
    // Remove theme for custom drawing
    SetWindowTheme(btn, L"", L"");
    return btn;
}

// Create a dark-themed text box
HWND CreateDarkEdit(HWND parent, int id, const wchar_t* text, int x, int y, int w, int h, bool multiline = false, bool readOnly = false) {
    DWORD style = WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL;
    if (multiline) style = WS_CHILD | WS_VISIBLE | ES_MULTILINE | ES_AUTOVSCROLL | WS_VSCROLL | ES_WANTRETURN;
    if (readOnly) style |= ES_READONLY;
    HWND edit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", text, style,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(edit, WM_SETFONT, (WPARAM)(multiline ? g_hFontMono : g_hFontMain), TRUE);
    SetWindowTheme(edit, L"", L"");
    return edit;
}

// Create a dark-themed checkbox
HWND CreateDarkCheckBox(HWND parent, int id, const wchar_t* text, int x, int y, int w, int h, bool checked = false) {
    HWND chk = CreateWindowExW(0, L"BUTTON", text, WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(chk, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
    SendMessageW(chk, BM_SETCHECK, checked ? BST_CHECKED : BST_UNCHECKED, 0);
    SetWindowTheme(chk, L"", L"");
    return chk;
}

// Create a dark-themed combo box
HWND CreateDarkComboBox(HWND parent, int id, int x, int y, int w, int h) {
    HWND combo = CreateWindowExW(0, L"COMBOBOX", L"", WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(combo, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
    SetWindowTheme(combo, L"", L"");
    return combo;
}

// Custom dark-themed window class for pages and content area
LRESULT CALLBACK DarkPageProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    static HBRUSH hbrBg = nullptr;
    static HBRUSH hbrCard = nullptr;
    static HBRUSH hbrEdit = nullptr;
    if (!hbrBg) hbrBg = CreateSolidBrush(COL_BG);
    if (!hbrCard) hbrCard = CreateSolidBrush(COL_CARD);
    if (!hbrEdit) hbrEdit = CreateSolidBrush(COL_TEXTBOX_BG);

    switch (message) {
        case WM_ERASEBKGND: {
            HDC hdc = (HDC)wParam;
            RECT rc;
            GetClientRect(hWnd, &rc);
            FillRect(hdc, &rc, hbrBg);
            return 1;
        }
        case WM_CTLCOLORSTATIC: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            // Check if child has custom bg color stored in USERDATA
            HWND hChild = (HWND)lParam;
            LONG_PTR userData = GetWindowLongPtrW(hChild, GWLP_USERDATA);
            if (userData != 0) {
                // Panel with custom background
                return (LRESULT)CreateSolidBrush((COLORREF)userData);
            }
            return (LRESULT)hbrBg;
        }
        case WM_CTLCOLORBTN: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            return (LRESULT)hbrBg;
        }
        case WM_CTLCOLOREDIT: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            return (LRESULT)hbrEdit;
        }
        case WM_CTLCOLORLISTBOX: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            return (LRESULT)hbrEdit;
        }
        case WM_COMMAND: {
            // Forward commands to main window
            return SendMessageW(g_hMainWnd, WM_COMMAND, wParam, lParam);
        }
        default:
            return DefWindowProcW(hWnd, message, wParam, lParam);
    }
    return 0;
}

void RegisterDarkPageClass() {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = DarkPageProc;
    wc.hInstance = g_hInst;
    wc.lpszClassName = L"DarkPage";
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = CreateSolidBrush(COL_BG);
    RegisterClassExW(&wc);
}

// Create a static text label
HWND CreateLabel(HWND parent, const wchar_t* text, int x, int y, int w, int h, COLORREF fg = COL_TEXT, int fontSize = 13, bool bold = false) {
    HWND lbl = CreateWindowExW(0, L"STATIC", text, WS_CHILD | WS_VISIBLE | SS_LEFT,
        x, y, w, h, parent, nullptr, g_hInst, nullptr);
    HFONT f = CreateFontHelper(fontSize, bold);
    SendMessageW(lbl, WM_SETFONT, (WPARAM)f, TRUE);
    SetWindowLongPtrW(lbl, GWLP_USERDATA, (LONG_PTR)fg);
    return lbl;
}

// Create a group box (panel)
HWND CreatePanel(HWND parent, COLORREF bg, int x, int y, int w, int h) {
    HWND pnl = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD | WS_VISIBLE,
        x, y, w, h, parent, nullptr, g_hInst, nullptr);
    SetWindowLongPtrW(pnl, GWLP_USERDATA, (LONG_PTR)bg);
    return pnl;
}

// Create a list box
HWND CreateDarkListBox(HWND parent, int id, int x, int y, int w, int h) {
    HWND lb = CreateWindowExW(WS_EX_CLIENTEDGE, L"LISTBOX", L"", WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(lb, WM_SETFONT, (WPARAM)g_hFontMono, TRUE);
    SetWindowTheme(lb, L"", L"");
    return lb;
}

// Create a progress bar
HWND CreateProgressBar(HWND parent, int id, int x, int y, int w, int h) {
    HWND pb = CreateWindowExW(0, PROGRESS_CLASSW, L"", WS_CHILD | WS_VISIBLE,
        x, y, w, h, parent, (HMENU)(INT_PTR)id, g_hInst, nullptr);
    SendMessageW(pb, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
    SendMessageW(pb, PBM_SETBARCOLOR, 0, (LPARAM)COL_ACCENT);
    SendMessageW(pb, PBM_SETBKCOLOR, 0, (LPARAM)COL_BTN_DARK);
    return pb;
}

// ========== CUSTOM BUTTON DRAWING ==========
LRESULT CALLBACK ButtonSubclassProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
    switch (uMsg) {
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            RECT rc;
            GetClientRect(hWnd, &rc);

            COLORREF bg = (COLORREF)GetWindowLongPtrW(hWnd, GWLP_USERDATA);
            bool isHover = (GetCapture() == hWnd);
            bool isPressed = false;
            if (isHover) {
                POINT pt;
                GetCursorPos(&pt);
                MapWindowPoints(nullptr, hWnd, &pt, 1);
                isPressed = PtInRect(&rc, pt);
            }

            // Background
            COLORREF bgColor = bg;
            if (isPressed) bgColor = RGB(GetRValue(bg) * 7 / 10, GetGValue(bg) * 7 / 10, GetBValue(bg) * 7 / 10);
            else if (isHover) bgColor = RGB(GetRValue(bg) * 85 / 100, GetGValue(bg) * 85 / 100, GetBValue(bg) * 85 / 100);

            // Rounded rectangle background
            HBRUSH hBrush = CreateSolidBrush(bgColor);
            HRGN hRgn = CreateRoundRectRgn(rc.left, rc.top, rc.right + 1, rc.bottom + 1, 8, 8);
            FillRgn(hdc, hRgn, hBrush);
            DeleteObject(hRgn);
            DeleteObject(hBrush);

            // Text
            wchar_t text[256];
            GetWindowTextW(hWnd, text, 256);
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, (bg == COL_ACCENT || bg == COL_GREEN) ? RGB(0x15, 0x15, 0x15) :
                         (bg == COL_RED) ? RGB(0xFF, 0xFF, 0xFF) : COL_TEXT);
            HFONT hFont = (HFONT)SendMessageW(hWnd, WM_GETFONT, 0, 0);
            HFONT hOldFont = (HFONT)SelectObject(hdc, hFont);
            UINT flags = DT_CENTER | DT_VCENTER | DT_SINGLELINE;
            RECT rcText = rc;
            DrawTextW(hdc, text, -1, &rcText, flags);
            SelectObject(hdc, hOldFont);

            EndPaint(hWnd, &ps);
            return 0;
        }
        case WM_MOUSEMOVE: {
            if (GetCapture() != hWnd) {
                TRACKMOUSEEVENT tme = { sizeof(tme) };
                tme.hwndTrack = hWnd;
                tme.dwFlags = TME_LEAVE;
                TrackMouseEvent(&tme);
                InvalidateRect(hWnd, nullptr, FALSE);
            }
            break;
        }
        case WM_MOUSELEAVE: {
            InvalidateRect(hWnd, nullptr, FALSE);
            break;
        }
    }
    return DefSubclassProc(hWnd, uMsg, wParam, lParam);
}

// ========== WINDIVERT C++ INTEGRATION ==========
// WinDivert function types
typedef HANDLE (*PFN_WinDivertOpen)(const char* filter, int layer, short priority, UINT64 flags);
typedef BOOL (*PFN_WinDivertRecv)(HANDLE handle, BYTE* pPacket, UINT packetLen, UINT* pRecvLen, void* pAddr);
typedef BOOL (*PFN_WinDivertSend)(HANDLE handle, BYTE* pPacket, UINT packetLen, UINT* pSendLen, void* pAddr);
typedef BOOL (*PFN_WinDivertShutdown)(HANDLE handle, int how);
typedef BOOL (*PFN_WinDivertClose)(HANDLE handle);
typedef BOOL (*PFN_WinDivertSetParam)(HANDLE handle, int param, UINT64 value);
typedef BOOL (*PFN_WinDivertHelperCalcChecksums)(BYTE* pPacket, UINT packetLen, void* pAddr, UINT64 flags);

PFN_WinDivertOpen pWinDivertOpen = nullptr;
PFN_WinDivertRecv pWinDivertRecv = nullptr;
PFN_WinDivertSend pWinDivertSend = nullptr;
PFN_WinDivertShutdown pWinDivertShutdown = nullptr;
PFN_WinDivertClose pWinDivertClose = nullptr;
PFN_WinDivertSetParam pWinDivertSetParam = nullptr;
PFN_WinDivertHelperCalcChecksums pWinDivertHelperCalcChecksums = nullptr;

#pragma pack(push, 1)
struct WINDIVERT_ADDRESS {
    INT64 Timestamp;
    UINT32 Layer_Events_Flags;
    UINT32 IfIdx;
    UINT32 SubIfIdx;
    UINT32 pad[12];
};
#pragma pack(pop)

#define WINDIVERT_LAYER_NETWORK 0
#define WINDIVERT_SHUTDOWN_RECV 1
#define WINDIVERT_PARAM_QUEUE_LENGTH 0
#define WINDIVERT_PARAM_QUEUE_TIME 1
#define WINDIVERT_PARAM_QUEUE_SIZE 2
#define FLAG_OUTBOUND (1u << 17)
#define FLAG_IPV6 (1u << 20)

// WD mode configs
bool wdModeBidir[] = { false, true, true, true, true };
bool wdModeAck[] =   { false, true, true, true, true };
bool wdModeWin[] =   { false, false, true, true, true };
bool wdModeFec[] =   { false, false, false, true, true };
bool wdModeBt[] =    { false, false, false, false, true };
UINT wdModeQTime[] = { 100, 50, 20, 10, 5 };
UINT wdModeQLen[] =  { 16384, 16384, 8192, 32768, 65536 };
UINT wdModeQSize[] = { 33554432, 33554432, 16777216, 67108864, 134217728 };

// WD stats
std::atomic<long long> wdTotalPackets(0);
std::atomic<long long> wdModifiedPackets(0);
std::atomic<long long> wdFecPackets(0);
std::atomic<long long> wdBtPackets(0);
std::atomic<long long> wdBtRecovered(0);

struct BtEntry {
    BYTE Data[65535];
    UINT Len;
    WINDIVERT_ADDRESS Addr;
    std::chrono::steady_clock::time_point Ts;
    UINT Seq;
};

std::wstring g_wdLogPath;
std::wstring g_wdErrPath;

bool LoadWinDivertDll() {
    if (g_wdDll) return true;

    // Ensure WinDivert files exist
    wchar_t tempDir[MAX_PATH];
    GetTempPathW(MAX_PATH, tempDir);
    g_wdDir = std::wstring(tempDir) + L"WinDivertWD";
    CreateDirectoryW(g_wdDir.c_str(), nullptr);

    std::wstring dllPath = g_wdDir + L"\\WinDivert.dll";
    std::wstring sysPath = g_wdDir + L"\\WinDivert64.sys";

    if (!PathFileExistsW(dllPath.c_str()) || !PathFileExistsW(sysPath.c_str())) {
        // Download WinDivert
        std::wstring url = L"https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip";
        std::wstring zipPath = g_wdDir + L"\\WinDivert.zip";
        HRESULT hr = URLDownloadToFileW(nullptr, url.c_str(), zipPath.c_str(), 0, nullptr);
        if (FAILED(hr)) return false;

        // Extract
        CreateDirectoryW((g_wdDir + L"\\temp").c_str(), nullptr);
        // Use ShellExecute to extract
        std::wstring extractCmd = L"powershell -Command \"Expand-Archive -Path '" + zipPath + L"' -DestinationPath '" + g_wdDir + L"\\temp' -Force\"";
        _wsystem(extractCmd.c_str());

        // Find and copy x64 files
        std::wstring searchPath = g_wdDir + L"\\temp";
        WIN32_FIND_DATAW fd;
        std::wstring findDll = g_wdDir + L"\\temp\\*\\x64\\WinDivert.dll";
        HANDLE hFind = FindFirstFileW(findDll.c_str(), &fd);
        if (hFind != INVALID_HANDLE_VALUE) {
            // Build full path
            std::wstring srcDir = g_wdDir + L"\\temp";
            WIN32_FIND_DATAW fd2;
            HANDLE hFind2 = FindFirstFileW((srcDir + L"\\*").c_str(), &fd2);
            while (hFind2 != INVALID_HANDLE_VALUE) {
                if (fd2.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                    std::wstring subDir = srcDir + L"\\" + fd2.cFileName + L"\\x64";
                    std::wstring srcDll = subDir + L"\\WinDivert.dll";
                    std::wstring srcSys = subDir + L"\\WinDivert64.sys";
                    if (PathFileExistsW(srcDll.c_str()) && PathFileExistsW(srcSys.c_str())) {
                        CopyFileW(srcDll.c_str(), dllPath.c_str(), FALSE);
                        CopyFileW(srcSys.c_str(), sysPath.c_str(), FALSE);
                        break;
                    }
                }
                if (!FindNextFileW(hFind2, &fd2)) break;
            }
            FindClose(hFind2);
        }
        if (hFind != INVALID_HANDLE_VALUE) FindClose(hFind);

        DeleteFileW(zipPath.c_str());
        // Clean temp
        std::wstring cleanCmd = L"cmd /c rmdir /s /q \"" + g_wdDir + L"\\temp\"";
        _wsystem(cleanCmd.c_str());
    }

    g_wdDll = LoadLibraryW(dllPath.c_str());
    if (!g_wdDll) return false;

    pWinDivertOpen = (PFN_WinDivertOpen)GetProcAddress(g_wdDll, "WinDivertOpen");
    pWinDivertRecv = (PFN_WinDivertRecv)GetProcAddress(g_wdDll, "WinDivertRecv");
    pWinDivertSend = (PFN_WinDivertSend)GetProcAddress(g_wdDll, "WinDivertSend");
    pWinDivertShutdown = (PFN_WinDivertShutdown)GetProcAddress(g_wdDll, "WinDivertShutdown");
    pWinDivertClose = (PFN_WinDivertClose)GetProcAddress(g_wdDll, "WinDivertClose");
    pWinDivertSetParam = (PFN_WinDivertSetParam)GetProcAddress(g_wdDll, "WinDivertSetParam");
    pWinDivertHelperCalcChecksums = (PFN_WinDivertHelperCalcChecksums)GetProcAddress(g_wdDll, "WinDivertHelperCalcChecksums");

    return pWinDivertOpen && pWinDivertRecv && pWinDivertSend && pWinDivertShutdown && pWinDivertClose && pWinDivertSetParam && pWinDivertHelperCalcChecksums;
}

bool ProcessPacketCpp(BYTE* packet, UINT len, BYTE tosValue, bool bidir, bool isOutbound, bool isIPv6, bool ackPri, bool winOpt) {
    if (len < 20) return false;
    bool modified = false;
    int ipHdrLen;
    BYTE protocol;

    if (!isIPv6) {
        BYTE version = (packet[0] >> 4) & 0x0F;
        if (version != 4) return false;
        ipHdrLen = (packet[0] & 0x0F) * 4;
        if (ipHdrLen < 20 || len < (UINT)ipHdrLen) return false;
        protocol = packet[9];
        if (bidir || isOutbound) {
            if (packet[1] != tosValue) { packet[1] = tosValue; modified = true; }
        }
    } else {
        ipHdrLen = 40;
        if (len < (UINT)ipHdrLen) return false;
        protocol = packet[6];
        if (bidir || isOutbound) {
            BYTE tcH = (tosValue >> 4) & 0x0F, tcL = tosValue & 0x0F;
            BYTE o0 = packet[0], o1 = packet[1];
            packet[0] = (o0 & 0xF0) | tcH;
            packet[1] = (tcL << 4) | (o1 & 0x0F);
            if (o0 != packet[0] || o1 != packet[1]) modified = true;
        }
    }

    if (protocol == 6 && len >= (UINT)(ipHdrLen + 20)) {
        int tcpOff = ipHdrLen;
        BYTE flags = packet[tcpOff + 13];
        bool isAck = (flags & 0x10) != 0;
        bool isAckOnly = isAck && ((flags & 0x3F) == 0x10);

        UINT payloadLen = 0;
        if (!isIPv6) {
            UINT ipTotal = (packet[2] << 8) | packet[3];
            int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
            if (ipTotal >= (UINT)(ipHdrLen + tcpHdrLen) && ipTotal <= len)
                payloadLen = ipTotal - (UINT)ipHdrLen - (UINT)tcpHdrLen;
        }

        if (winOpt && isOutbound && isAck && payloadLen == 0 && len >= (UINT)(tcpOff + 16)) {
            USHORT win = (packet[tcpOff + 14] << 8) | packet[tcpOff + 15];
            if (win > 65535) { packet[tcpOff + 14] = 0xFF; packet[tcpOff + 15] = 0xFF; modified = true; }
        }
    }
    return modified;
}

void WinDivertWorker(int mode, BYTE dscpValue, std::vector<int> tcpPorts, std::vector<int> udpPorts, bool accelMode) {
    BYTE tosValue = dscpValue << 2;
    bool bidir = wdModeBidir[mode];
    bool ackPri = wdModeAck[mode];
    bool winOpt = wdModeWin[mode];
    bool fecEn = wdModeFec[mode];
    bool btEn = wdModeBt[mode];
    UINT qTime = wdModeQTime[mode];
    UINT qLen = wdModeQLen[mode];
    UINT qSize = wdModeQSize[mode];

    // Build filter
    std::string filter;
    std::vector<std::string> parts;
    for (int p : tcpPorts) { parts.push_back("tcp.DstPort == " + std::to_string(p)); parts.push_back("tcp.SrcPort == " + std::to_string(p)); }
    for (int p : udpPorts) { parts.push_back("udp.DstPort == " + std::to_string(p)); parts.push_back("udp.SrcPort == " + std::to_string(p)); }
    for (size_t i = 0; i < parts.size(); i++) { if (i > 0) filter += " or "; filter += parts[i]; }
    if (!bidir) filter = "outbound and (" + filter + ")";

    HANDLE handle = pWinDivertOpen(filter.c_str(), WINDIVERT_LAYER_NETWORK, 0, 0);
    if (handle == INVALID_HANDLE_VALUE || handle == nullptr) {
        FILE* f = _wfopen(g_wdErrPath.c_str(), L"w, ccs=UTF-8");
        if (f) { fwprintf(f, L"[WD] ERROR: Cannot open handle Error=%d\n", GetLastError()); fclose(f); }
        return;
    }

    pWinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_LENGTH, qLen);
    pWinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_TIME, qTime);
    pWinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_SIZE, qSize);

    FILE* logFile = _wfopen(g_wdLogPath.c_str(), L"w, ccs=UTF-8");
    if (logFile) {
        fwprintf(logFile, L"[WD] 模式: %hs | DSCP=%d TOS=0x%02X | 双向=%d ACK=%d TCP窗口=%d FEC=%d BT=%d\n",
            mode < 5 ? "" : "", dscpValue, tosValue, bidir, ackPri, winOpt, fecEn, btEn);
        fwprintf(logFile, L"[WD] 过滤器: %hs\n", filter.c_str());
        fwprintf(logFile, L"[WD] [%s] 句柄已打开，开始逐包优化...\n", g_wdModeNames[mode]);
        fflush(logFile);
    }

    // BT buffer
    std::vector<BtEntry> btBuffer;
    UINT lastAckSeq = 0;
    int dscpAltCounter = 0;
    BYTE altTosValues[] = { 0xB8, 0x88, 0xC0, 0xA0 };

    BYTE packet[65575];
    WINDIVERT_ADDRESS addr;
    memset(&addr, 0, sizeof(addr));
    UINT recvLen;
    auto startTime = std::chrono::steady_clock::now();
    auto lastReport = startTime;

    while (g_wdRunning.load()) {
        if (!pWinDivertRecv(handle, packet, sizeof(packet), &recvLen, &addr)) {
            break;
        }
        wdTotalPackets.fetch_add(1);
        bool isOutbound = (addr.Layer_Events_Flags & FLAG_OUTBOUND) != 0;
        bool isIPv6 = (addr.Layer_Events_Flags & FLAG_IPV6) != 0;

        // Extract TCP info for FEC/BT
        int ipHdrLenFec = 0; BYTE protocolFec = 0; UINT tcpSeqFec = 0; UINT tcpAckFec = 0;
        bool isTcpDataFec = false; bool isAckOnlyFec = false;
        if (!isIPv6 && recvLen >= 20) {
            ipHdrLenFec = (packet[0] & 0x0F) * 4;
            if (ipHdrLenFec >= 20 && recvLen >= (UINT)(ipHdrLenFec + 20)) {
                protocolFec = packet[9];
                if (protocolFec == 6) {
                    int tcpOff = ipHdrLenFec;
                    tcpSeqFec = (UINT)((packet[tcpOff + 4] << 24) | (packet[tcpOff + 5] << 16) | (packet[tcpOff + 6] << 8) | packet[tcpOff + 7]);
                    tcpAckFec = (UINT)((packet[tcpOff + 8] << 24) | (packet[tcpOff + 9] << 16) | (packet[tcpOff + 10] << 8) | packet[tcpOff + 11]);
                    BYTE flags = packet[tcpOff + 13];
                    bool isAck = (flags & 0x10) != 0;
                    isAckOnlyFec = isAck && ((flags & 0x3F) == 0x10);
                    UINT ipTotal = (UINT)((packet[2] << 8) | packet[3]);
                    int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                    if (ipTotal >= (UINT)(ipHdrLenFec + tcpHdrLen) && ipTotal <= recvLen) {
                        UINT payload = ipTotal - (UINT)ipHdrLenFec - (UINT)tcpHdrLen;
                        isTcpDataFec = payload > 0;
                    }
                }
            }
        }

        // BT: track incoming ACKs
        if (btEn && !isOutbound && isAckOnlyFec) {
            lastAckSeq = tcpAckFec;
            while (!btBuffer.empty() && btBuffer.front().Seq < tcpAckFec) {
                btBuffer.erase(btBuffer.begin());
            }
        }

        bool modified = ProcessPacketCpp(packet, recvLen, tosValue, bidir, isOutbound, isIPv6, ackPri, winOpt);
        if (modified) { pWinDivertHelperCalcChecksums(packet, recvLen, &addr, 0); wdModifiedPackets.fetch_add(1); }

        UINT sendLen;
        pWinDivertSend(handle, packet, recvLen, &sendLen, &addr);

        // FEC: duplicate outgoing UDP
        if (fecEn && isOutbound && protocolFec == 17 && recvLen > 0) {
            BYTE fecCopy[65575];
            memcpy(fecCopy, packet, recvLen);
            BYTE altTos = altTosValues[dscpAltCounter % 4];
            dscpAltCounter++;
            if (!isIPv6) fecCopy[1] = altTos;
            WINDIVERT_ADDRESS fecAddr = addr;
            pWinDivertHelperCalcChecksums(fecCopy, recvLen, &fecAddr, 0);
            pWinDivertSend(handle, fecCopy, recvLen, &sendLen, &fecAddr);
            wdFecPackets.fetch_add(1);
        }

        // BT: duplicate outgoing TCP data + buffer
        if (btEn && isOutbound && isTcpDataFec && recvLen > 0 && recvLen < 60000) {
            BYTE btCopy[65575];
            memcpy(btCopy, packet, recvLen);
            BYTE altTos = altTosValues[(dscpAltCounter + 2) % 4];
            if (!isIPv6) btCopy[1] = altTos;
            WINDIVERT_ADDRESS btAddr = addr;
            pWinDivertHelperCalcChecksums(btCopy, recvLen, &btAddr, 0);
            pWinDivertSend(handle, btCopy, recvLen, &sendLen, &btAddr);
            wdBtPackets.fetch_add(1);

            // Buffer for delayed recovery
            if (btBuffer.size() < 200) {
                BtEntry entry;
                memcpy(entry.Data, packet, recvLen);
                entry.Len = recvLen;
                entry.Addr = addr;
                entry.Ts = std::chrono::steady_clock::now();
                entry.Seq = tcpSeqFec;
                btBuffer.push_back(entry);
            }
        }

        // BT: delayed packet recovery
        if (btEn && !btBuffer.empty()) {
            auto cutoff = std::chrono::steady_clock::now() - std::chrono::milliseconds(15);
            int recovered = 0;
            while (!btBuffer.empty() && btBuffer.front().Ts < cutoff) {
                BtEntry e = btBuffer.front();
                btBuffer.erase(btBuffer.begin());
                if (e.Seq >= lastAckSeq) {
                    BYTE rcv[65535];
                    memcpy(rcv, e.Data, e.Len);
                    if (!isIPv6) rcv[1] = 0xC0;
                    WINDIVERT_ADDRESS rcvAddr = e.Addr;
                    pWinDivertHelperCalcChecksums(rcv, e.Len, &rcvAddr, 0);
                    pWinDivertSend(handle, rcv, e.Len, &sendLen, &rcvAddr);
                    wdBtRecovered.fetch_add(1);
                    recovered++;
                }
            }
            if (recovered > 0 && logFile) {
                fwprintf(logFile, L"[WD] BT 延后恢复: %d个包重发\n", recovered);
                fflush(logFile);
            }
        }

        // Periodic report
        auto now = std::chrono::steady_clock::now();
        if (std::chrono::duration_cast<std::chrono::seconds>(now - lastReport).count() >= 5) {
            auto el = std::chrono::duration_cast<std::chrono::seconds>(now - startTime).count();
            if (logFile) {
                fwprintf(logFile, L"[WD] [%s] 运行%llds | 总包%lld | 优化%lld | FEC:%lld BT:%lld 恢复:%lld\n",
                    g_wdModeNames[mode], (long long)el, wdTotalPackets.load(), wdModifiedPackets.load(),
                    wdFecPackets.load(), wdBtPackets.load(), wdBtRecovered.load());
                fflush(logFile);
            }
            lastReport = now;
        }
    }

    pWinDivertShutdown(handle, WINDIVERT_SHUTDOWN_RECV);
    Sleep(100);
    pWinDivertClose(handle);

    if (logFile) {
        auto el = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::steady_clock::now() - startTime).count();
        fwprintf(logFile, L"[WD] 已停止 | 运行%llds | 总包%lld | 优化%lld | FEC:%lld BT:%lld 恢复:%lld\n",
            (long long)el, wdTotalPackets.load(), wdModifiedPackets.load(),
            wdFecPackets.load(), wdBtPackets.load(), wdBtRecovered.load());
        fclose(logFile);
    }
}

// ========== PAGE CREATION ==========

void CreateDashboardPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD | WS_VISIBLE, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[0] = page;

    // Title
    CreateLabel(page, L"网络优化配置", 20, 10, 600, 30, COL_TEXT_TITLE, 24, true);
    CreateLabel(page, L"选择优化档位后应用。均衡更适合日常，完全模式会修改更多 TCP/IP 与系统网络参数。", 20, 42, 720, 20, COL_TEXT, 13);

    // Stat cards
    const wchar_t* statLabels[] = { L"延迟", L"下载", L"上传", L"DNS" };
    int statIds[] = { IDC_STAT_PING, IDC_STAT_DOWNLOAD, IDC_STAT_UPLOAD, IDC_STAT_DNS };
    for (int i = 0; i < 4; i++) {
        int x = 20 + i * 180;
        HWND card = CreatePanel(page, COL_CARD, x, 75, 170, 65);
        CreateLabel(card, statLabels[i], 12, 8, 100, 18, COL_TEXT, 12);
        wchar_t val[8] = L"--";
        HWND valLbl = CreateLabel(card, val, 12, 28, 100, 24, COL_ACCENT, 18, true);
        SetWindowLongPtrW(valLbl, GWLP_ID, statIds[i]);
    }

    // CPU/Memory cards
    const wchar_t* sysLabels[] = { L"CPU 占用", L"内存占用" };
    int sysIds[] = { IDC_STAT_CPU, IDC_STAT_MEM };
    for (int i = 0; i < 2; i++) {
        int x = 20 + i * 360;
        HWND card = CreatePanel(page, COL_CARD, x, 150, 350, 55);
        CreateLabel(card, sysLabels[i], 12, 8, 100, 18, COL_TEXT, 12);
        HWND valLbl = CreateLabel(card, L"--", 120, 8, 80, 18, COL_GREEN, 16, true);
        SetWindowLongPtrW(valLbl, GWLP_ID, sysIds[i]);
    }

    // Optimization mode section
    HWND modePanel = CreatePanel(page, COL_CARD, 20, 220, 720, 200);
    CreateLabel(modePanel, L"优化模式", 16, 12, 200, 22, COL_TEXT_TITLE, 16, true);
    CreateLabel(modePanel, L"四个档位：均衡满足日常体验，普通优化一部分网络体验，完全应用全部网络优化，还原会撤销本工具修改。", 16, 38, 690, 20, COL_TEXT, 12);

    // Mode buttons
    const wchar_t* modeTexts[] = { L"均衡\n日常体验", L"普通\n部分优化", L"完全\n全部优化", L"还原\n撤销修改" };
    int modeIds[] = { IDC_BTN_BALANCED, IDC_BTN_NORMAL, IDC_BTN_COMPLETE, IDC_BTN_REVERT };
    COLORREF modeColors[] = { COL_ACCENT, COL_BTN_DARK, COL_BTN_DARK, COL_BTN_DARK };
    for (int i = 0; i < 4; i++) {
        HWND btn = CreateDarkButton(modePanel, modeIds[i], modeTexts[i], 16 + i * 175, 68, 165, 50, modeColors[i], COL_TEXT);
        SetWindowSubclass(btn, ButtonSubclassProc, 0, 0);
    }

    // Current mode label
    HWND modeLbl = CreateLabel(modePanel, g_modeNames[0], 16, 128, 690, 20, COL_TEXT, 13);
    SetWindowLongPtrW(modeLbl, GWLP_ID, IDC_MODE_LABEL);

    // Action buttons
    HWND btnOpt = CreateDarkButton(modePanel, IDC_BTN_OPTIMIZE, L"应用所选模式", 16, 158, 160, 36, COL_ACCENT, RGB(0x15,0x15,0x15));
    SetWindowSubclass(btnOpt, ButtonSubclassProc, 0, 0);
    HWND btnRev = CreateDarkButton(modePanel, IDC_BTN_REVERT_ACT, L"立即还原", 186, 158, 130, 36, COL_RED, RGB(0xFF,0xFF,0xFF));
    SetWindowSubclass(btnRev, ButtonSubclassProc, 0, 0);
    HWND btnSpeed = CreateDarkButton(modePanel, IDC_BTN_SPEEDTEST, L"网速测试", 326, 158, 130, 36, COL_BTN_DARK, COL_TEXT);
    SetWindowSubclass(btnSpeed, ButtonSubclassProc, 0, 0);

    // Status and progress
    HWND hStatus = CreateLabel(page, L"就绪", 20, 430, 400, 20, COL_TEXT, 13);
    SetWindowLongPtrW(hStatus, GWLP_ID, IDC_STATUS_TEXT);
    // Progress bar
    CreateProgressBar(page, IDC_PROGRESS, 20, 455, 720, 8);

    // Results list
    CreateLabel(page, L"优化结果:", 20, 475, 200, 18, COL_TEXT, 13);
    CreateDarkListBox(page, IDC_RESULTS_LIST, 20, 498, 720, 95);
}

// I'll continue with the other page creation functions...
// Due to space, I'll create them in the next section

void CreateTcpPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[1] = page;

    CreateLabel(page, L"TCP/IP 协议栈优化", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"所有设置均基于 Windows 可配置参数", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    HWND panel = CreatePanel(page, COL_PANEL, 20, 75, 720, 250);
    CreateLabel(panel, L"当前 TCP 全局设置", 16, 12, 200, 20, COL_TEXT_TITLE, 14, true);
    HWND btnRef = CreateDarkButton(panel, IDC_BTN_REFRESH_TCP, L"刷新", 220, 10, 80, 28, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnRef, ButtonSubclassProc, 0, 0);
    CreateDarkEdit(panel, IDC_TCP_TEXT, L"点击刷新加载...", 16, 42, 690, 195, true, true);

    HWND infoPanel = CreatePanel(page, COL_PANEL, 20, 340, 720, 200);
    CreateLabel(infoPanel, L"关键优化说明：", 16, 12, 200, 20, COL_TEXT_TITLE, 14, true);
    CreateLabel(infoPanel, L"1. TcpNoDelay=1 - 禁用 Nagle 算法，降低交互延迟\n"
        L"2. TcpAckFrequency=1 - 提高 ACK 响应频率\n"
        L"3. Tcp1323Opts=1 - 启用 TCP 时间戳与窗口缩放\n"
        L"4. SackOpts=1 - 启用选择性确认\n"
        L"5. DefaultTTL=64 - 优化 TTL\n"
        L"6. MaxUserPort=65534 - 扩大临时端口范围\n"
        L"7. TcpTimedWaitDelay=30 - 缩短 TIME_WAIT\n"
        L"8. NetworkThrottlingIndex=0xFFFFFFFF - 关闭网络节流\n"
        L"9. 发送/接收窗口参数优化\n"
        L"10. MaxUserPort 与 TIME_WAIT 参数优化", 16, 38, 690, 150, COL_TEXT_TITLE, 13);
}

void CreateDnsPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[2] = page;

    CreateLabel(page, L"DNS 优化", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"配置 DNS 以提升域名解析体验", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    // Current DNS
    HWND panel = CreatePanel(page, COL_PANEL, 20, 75, 720, 80);
    CreateLabel(panel, L"当前 DNS：", 16, 16, 80, 20, COL_TEXT_DIM, 13);
    HWND dnsLbl = CreateLabel(panel, L"--", 100, 16, 200, 20, COL_GREEN, 13);
    SetWindowLongPtrW(dnsLbl, GWLP_ID, IDC_DNS_CURRENT);
    HWND btnFlush = CreateDarkButton(panel, IDC_DNS_BTN_FLUSH, L"清理 DNS 缓存", 400, 12, 160, 32, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnFlush, ButtonSubclassProc, 0, 0);

    // DNS presets
    HWND presetPanel = CreatePanel(page, COL_PANEL, 20, 170, 720, 200);
    CreateLabel(presetPanel, L"DNS 预设", 16, 12, 200, 20, COL_TEXT_TITLE, 14, true);

    const wchar_t* dnsNames[] = { L"Cloudflare (1.1.1.1)", L"Google (8.8.8.8)", L"阿里 DNS (223.5.5.5)", L"114DNS (114.114.114.114)", L"DNSPod (119.29.29.29)" };
    int dnsIds[] = { IDC_DNS_BTN_0, IDC_DNS_BTN_1, IDC_DNS_BTN_2, IDC_DNS_BTN_3, IDC_DNS_BTN_4 };
    int dnsTextIds[] = { IDC_DNS_TEXT_0, IDC_DNS_TEXT_1, IDC_DNS_TEXT_2, IDC_DNS_TEXT_3, IDC_DNS_TEXT_4 };
    for (int i = 0; i < 5; i++) {
        int x = 16 + (i % 2) * 345;
        int y = 42 + (i / 2) * 40;
        HWND btn = CreateDarkButton(presetPanel, dnsIds[i], dnsNames[i], x, y, 335, 32, COL_BTN_DARK, COL_TEXT);
        SetWindowSubclass(btn, ButtonSubclassProc, 0, 0);
    }

    // Action buttons
    HWND btnApply = CreateDarkButton(presetPanel, IDC_DNS_BTN_APPLY, L"应用 DNS", 16, 165, 130, 36, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnApply, ButtonSubclassProc, 0, 0);
    HWND btnRestore = CreateDarkButton(presetPanel, IDC_DNS_BTN_RESTORE, L"恢复 DHCP", 156, 165, 130, 36, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnRestore, ButtonSubclassProc, 0, 0);
    HWND btnSpeed = CreateDarkButton(presetPanel, IDC_DNS_BTN_SPEED, L"DNS 测速", 296, 165, 130, 36, COL_ACCENT, RGB(0x15,0x15,0x15));
    SetWindowSubclass(btnSpeed, ButtonSubclassProc, 0, 0);
}

void CreateQosPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[3] = page;

    CreateLabel(page, L"QoS - 流量优先级", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"使用 DSCP 46 为 Minecraft 流量设置更高优先级", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    HWND panel = CreatePanel(page, COL_PANEL, 20, 75, 720, 180);
    CreateLabel(panel, L"Minecraft QoS 策略：", 16, 12, 200, 20, COL_TEXT_TITLE, 14, true);
    CreateLabel(panel, L"- javaw.exe（Minecraft Java）：DSCP 46\n- Minecraft.Windows.exe（基岩版）：DSCP 46\n- 端口 25565（Java TCP）：DSCP 46\n- 端口 19132（基岩版 UDP）：DSCP 46", 16, 38, 690, 60, COL_TEXT_DIM, 13);
    HWND btnApply = CreateDarkButton(panel, IDC_BTN_APPLY_QOS, L"应用 QoS", 16, 110, 130, 36, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnApply, ButtonSubclassProc, 0, 0);
    HWND btnRemove = CreateDarkButton(panel, IDC_BTN_REMOVE_QOS, L"全部移除", 156, 110, 130, 36, COL_RED, RGB(0xFF,0xFF,0xFF));
    SetWindowSubclass(btnRemove, ButtonSubclassProc, 0, 0);

    HWND policyPanel = CreatePanel(page, COL_PANEL, 20, 270, 720, 200);
    CreateLabel(policyPanel, L"当前 QoS 策略：", 16, 12, 200, 20, COL_TEXT_TITLE, 14, true);
    HWND btnRef = CreateDarkButton(policyPanel, IDC_BTN_REFRESH_QOS, L"刷新", 220, 10, 80, 28, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnRef, ButtonSubclassProc, 0, 0);
    CreateDarkEdit(policyPanel, IDC_QOS_TEXT, L"--", 16, 42, 690, 145, true, true);
}

void CreateHostsPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[4] = page;

    CreateLabel(page, L"Hosts编辑", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"可在软件内查看、保存、重置 Hosts，也可使用内置优化 Hosts（2606 条域名解析，覆盖 GitHub/Mojang/Google 等）。", 20, 42, 720, 20, COL_TEXT_DIM, 13);

    HWND panel = CreatePanel(page, COL_PANEL, 20, 75, 720, 60);
    HWND btnLoad = CreateDarkButton(panel, IDC_BTN_LOAD_HOSTS, L"读取 Hosts", 16, 14, 130, 32, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnLoad, ButtonSubclassProc, 0, 0);
    HWND btnSave = CreateDarkButton(panel, IDC_BTN_SAVE_HOSTS, L"保存 Hosts", 156, 14, 130, 32, COL_ACCENT, RGB(0x15,0x15,0x15));
    SetWindowSubclass(btnSave, ButtonSubclassProc, 0, 0);
    HWND btnOpt = CreateDarkButton(panel, IDC_BTN_OPT_HOSTS, L"Hosts 优化", 296, 14, 130, 32, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnOpt, ButtonSubclassProc, 0, 0);
    HWND btnReset = CreateDarkButton(panel, IDC_BTN_RESET_HOSTS, L"Hosts 重置", 436, 14, 130, 32, COL_RED, RGB(0xFF,0xFF,0xFF));
    SetWindowSubclass(btnReset, ButtonSubclassProc, 0, 0);

    CreateDarkEdit(page, IDC_HOSTS_EDITOR, L"点击\"读取 Hosts\"加载内容...", 20, 145, 720, 420, true, false);
}

void CreateCustomPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[5] = page;

    CreateLabel(page, L"自定义优化", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"显示全部可选优化条目。建议只勾选自己理解的项目。", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    HWND panel = CreatePanel(page, COL_PANEL, 20, 75, 720, 410);

    // Define custom optimization items
    struct { const wchar_t* name; const wchar_t* cmd; bool rec; } items[] = {
        { L"TcpNoDelay=1：降低交互延迟", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v TcpNoDelay /t REG_DWORD /d 1 /f", true },
        { L"TcpAckFrequency=1：提高 ACK 响应频率", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v TcpAckFrequency /t REG_DWORD /d 1 /f", true },
        { L"TcpDelAckTicks=0：禁用延迟 ACK", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v TcpDelAckTicks /t REG_DWORD /d 0 /f", false },
        { L"TCP Fast Open：启用快速打开", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v EnableTcpFastOpen /t REG_DWORD /d 1 /f", true },
        { L"MaxUserPort=64336：扩大临时端口范围", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v MaxUserPort /t REG_DWORD /d 64336 /f", false },
        { L"TCP 自动调优：Normal", L"netsh interface tcp set global autotuninglevel=normal", true },
        { L"InitialCongestionWindow=10 / InitialRto=3000", L"powershell -Command \"Set-NetTCPSetting -SettingName * -InitialCongestionWindow 10 -InitialRto 3000\"", false },
        { L"ECN：启用显式拥塞通知", L"netsh int tcp set global ecncapability=enabled", true },
        { L"RSS + TaskOffload：启用网卡卸载能力", L"powershell -Command \"Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -TaskOffload Enabled\"", true },
        { L"NetworkThrottlingIndex=0xFFFFFFFF：关闭多媒体网络节流", L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f", true },
        { L"SystemResponsiveness=0：降低后台保留比例", L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\" /v SystemResponsiveness /t REG_DWORD /d 0 /f", true },
        { L"NonBestEffortLimit=0：取消 QoS 带宽保留", L"reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Psched\" /v NonBestEffortLimit /t REG_DWORD /d 0 /f", true },
        { L"DisableBandwidthThrottling=1：关闭工作站带宽节流", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters\" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f", true },
        { L"DisableLargeMtu=0：启用 Large MTU", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters\" /v DisableLargeMtu /t REG_DWORD /d 0 /f", true },
        { L"WinHTTP TcpAutotuning=1", L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\WinHttp\" /v TcpAutotuning /t REG_DWORD /d 1 /f", true },
        { L"禁用 WinHTTP / BITS BranchCache", L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\WinHttp\" /v DisableBranchCache /t REG_DWORD /d 1 /f", false },
        { L"EnableWsd=0：关闭 WSD", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v EnableWsd /t REG_DWORD /d 0 /f", false },
        { L"EnableConnectionRateLimiting=0：禁用连接速率限制", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v EnableConnectionRateLimiting /t REG_DWORD /d 0 /f", false },
        { L"TcpHybridAck=0：关闭混合 ACK 延迟", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v TcpHybridAck /t REG_DWORD /d 0 /f", true },
        { L"EnergyEfficientEthernet=0：关闭节能以太网", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power\" /v EnergyEfficientEthernet /t REG_DWORD /d 0 /f", true },
        { L"WinINet TcpAutotuning=1", L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\" /v TcpAutotuning /t REG_DWORD /d 1 /f", true },
        { L"MaxConnections=65536：扩大最大并发连接数", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v MaxConnections /t REG_DWORD /d 65536 /f", false },
        { L"MTU=1500：设置标准以太网 MTU", L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v MTU /t REG_DWORD /d 1500 /f", false },
        { L"拥塞控制 Default：恢复系统默认 CUBIC", L"netsh interface tcp set supplemental Template=Internet CongestionProvider=default", false },
    };

    const wchar_t* groupTitles[] = { L"基础低延迟与 TCP/IP", L"系统网络栈", L"QoS 带宽与传输优化", L"延迟与连接优化", L"窗口与拥塞控制" };
    int groupStarts[] = { 0, 5, 11, 19, 23 };
    int groupEnds[] = { 4, 10, 18, 22, 23 };

    int yPos = 12;
    for (int g = 0; g < 5; g++) {
        CreateLabel(panel, groupTitles[g], 16, yPos, 690, 20, COL_ACCENT, 14, true);
        yPos += 24;
        for (int i = groupStarts[g]; i <= groupEnds[g]; i++) {
            int checkId = IDC_OPT_BASE + i;
            CreateDarkCheckBox(panel, checkId, items[i].name, 24, yPos, 680, 20, items[i].rec);
            // Store item info
            CustomOptItem item;
            item.checkId = checkId;
            item.name = items[i].name;
            item.commands.push_back(items[i].cmd);
            item.recommended = items[i].rec;
            g_customItems.push_back(item);
            yPos += 24;
        }
        yPos += 4;
    }

    // Action buttons
    HWND btnApply = CreateDarkButton(page, IDC_BTN_APPLY_CUSTOM, L"应用勾选优化", 20, 495, 150, 36, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnApply, ButtonSubclassProc, 0, 0);
    HWND btnRec = CreateDarkButton(page, IDC_BTN_REC_CUSTOM, L"勾选推荐项", 180, 495, 150, 36, COL_ACCENT, RGB(0x15,0x15,0x15));
    SetWindowSubclass(btnRec, ButtonSubclassProc, 0, 0);
    HWND btnClear = CreateDarkButton(page, IDC_BTN_CLEAR_CUSTOM, L"清空选择", 340, 495, 130, 36, COL_BTN_DARK, COL_TEXT_TITLE);
    SetWindowSubclass(btnClear, ButtonSubclassProc, 0, 0);
}

void CreateTestPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[6] = page;

    CreateLabel(page, L"测试", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"独立测试功能，不会加入自定义优化勾选列表。", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    // 1. Adapter deep test
    HWND p1 = CreatePanel(page, COL_PANEL, 20, 75, 720, 90);
    CreateLabel(p1, L"1. 智能调整网卡深层参数", 16, 12, 400, 20, COL_ACCENT, 15, true);
    CreateLabel(p1, L"智能尝试调整活动网卡的缓冲区、中断处理、RSS 与卸载能力...", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    HWND btnDeep = CreateDarkButton(p1, IDC_BTN_ADAPTER_DEEP, L"执行网卡深层测试优化", 16, 60, 220, 28, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnDeep, ButtonSubclassProc, 0, 0);

    // 2. WinDivert simulation
    HWND p2 = CreatePanel(page, COL_PANEL, 20, 175, 720, 130);
    CreateLabel(p2, L"2. WinDivert 逐包优化模拟", 16, 12, 400, 20, COL_ACCENT, 15, true);
    CreateLabel(p2, L"WinDivert 在内核层逐包拦截并修改 TCP/IP 头部...", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_QOS, L"QoS DSCP 46 标记（应用+端口）", 16, 58, 200, 20, true);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_PROC, L"进程优先级提升（High）", 220, 58, 200, 20, true);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_TIMER, L"系统定时器 0.5ms", 440, 58, 200, 20, true);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_INTERRUPT, L"关闭网卡中断调节", 16, 80, 200, 20, true);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_RSS, L"RSS 队列优化", 220, 80, 200, 20, true);
    CreateDarkCheckBox(p2, IDC_CHK_SIM_THROTTLE, L"关闭网络节流+系统响应=0", 440, 80, 200, 20, true);
    // Sim buttons + result (small area)

    // 3. WinDivert real mode
    HWND p3 = CreatePanel(page, COL_WD_PANEL, 20, 315, 720, 200);
    // Red border effect via label
    CreateLabel(p3, L"[!] WinDivert 内核级逐包优化（真实模式）", 16, 12, 400, 20, COL_RED, 15, true);
    CreateLabel(p3, L"WinDivert 是开源内核级数据包拦截驱动...", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    CreateLabel(p3, L"[!] 警告：此功能需要安装内核驱动（WinDivert64.sys），可能被杀毒软件标记...", 16, 56, 690, 20, COL_ORANGE, 12);

    // WD mode buttons
    const wchar_t* wdModeTexts[] = { L"普通", L"最佳", L"急速", L"狂暴", L"BT" };
    int wdModeIds[] = { IDC_WD_MODE_0, IDC_WD_MODE_1, IDC_WD_MODE_2, IDC_WD_MODE_3, IDC_WD_MODE_4 };
    COLORREF wdModeColors[] = { COL_BTN_DARK, COL_ACCENT, COL_BTN_DARK, COL_BTN_DARK, COL_BTN_DARK };
    CreateLabel(p3, L"优化模式:", 16, 82, 60, 18, COL_TEXT, 13);
    for (int i = 0; i < 5; i++) {
        HWND btn = CreateDarkButton(p3, wdModeIds[i], wdModeTexts[i], 80 + i * 65, 80, 60, 28, wdModeColors[i],
            (i == 1) ? RGB(0x11,0x11,0x11) : COL_TEXT);
        SetWindowSubclass(btn, ButtonSubclassProc, 0, 0);
    }
    // Hidden mode label
    HWND modeLbl = CreateLabel(p3, L"1", 0, 0, 10, 10, COL_TEXT, 8);
    SetWindowLongPtrW(modeLbl, GWLP_ID, IDC_WD_MODE_LABEL);
    ShowWindow(modeLbl, SW_HIDE);

    // Port/DSCP inputs
    CreateLabel(p3, L"TCP 端口:", 410, 82, 55, 18, COL_TEXT, 13);
    CreateDarkEdit(p3, IDC_WD_TCP_PORT, L"25565", 468, 80, 80, 24, false, false);
    CreateLabel(p3, L"UDP 端口:", 16, 112, 55, 18, COL_TEXT, 13);
    CreateDarkEdit(p3, IDC_WD_UDP_PORT, L"19132", 74, 110, 80, 24, false, false);
    CreateLabel(p3, L"DSCP:", 170, 112, 35, 18, COL_TEXT, 13);
    CreateDarkEdit(p3, IDC_WD_DSCP, L"46", 208, 110, 40, 24, false, false);
    CreateLabel(p3, L"提示: 端口支持多值(逗号分隔) | 狂暴=强FEC+路径切换 | BT=冗余复制+延后包恢复", 260, 112, 440, 18, COL_ACCENT, 11);

    // WD action buttons
    HWND btnWdStart = CreateDarkButton(p3, IDC_BTN_WD_START, L"启动逐包优化", 16, 142, 130, 32, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnWdStart, ButtonSubclassProc, 0, 0);
    HWND btnWdStop = CreateDarkButton(p3, IDC_BTN_WD_STOP, L"停止", 156, 142, 80, 32, COL_RED, RGB(0xFF,0xFF,0xFF));
    SetWindowSubclass(btnWdStop, ButtonSubclassProc, 0, 0);
    EnableWindow(btnWdStop, FALSE);
    HWND btnWdRef = CreateDarkButton(p3, IDC_BTN_WD_REFRESH, L"刷新状态", 246, 142, 100, 32, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnWdRef, ButtonSubclassProc, 0, 0);
    HWND btnWdUn = CreateDarkButton(p3, IDC_BTN_WD_UNINSTALL, L"卸载驱动", 356, 142, 100, 32, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnWdUn, ButtonSubclassProc, 0, 0);

    CreateDarkEdit(p3, IDC_WD_RESULT, L"-- WinDivert 未运行 --", 16, 178, 690, 16, true, true);

    // 4. Accelerator support
    HWND p4 = CreatePanel(page, COL_PANEL, 20, 525, 720, 60);
    CreateLabel(p4, L"3. 加速器兼容支持", 16, 8, 300, 20, COL_ACCENT, 14, true);
    HWND btnDetect = CreateDarkButton(p4, IDC_BTN_ACCEL_DETECT, L"检测加速器", 350, 6, 120, 28, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnDetect, ButtonSubclassProc, 0, 0);
    HWND btnApply = CreateDarkButton(p4, IDC_BTN_ACCEL_APPLY, L"应用端口预设", 480, 6, 120, 28, COL_ACCENT, RGB(0x15,0x15,0x15));
    SetWindowSubclass(btnApply, ButtonSubclassProc, 0, 0);
    HWND accelSel = CreateDarkComboBox(p4, IDC_ACCEL_SELECTOR, 16, 32, 120, 200);
    ComboBox_AddString(accelSel, L"自动检测");
    ComboBox_AddString(accelSel, L"UU加速器");
    ComboBox_AddString(accelSel, L"迅游加速器");
    ComboBox_AddString(accelSel, L"雷神加速器");
    ComboBox_AddString(accelSel, L"3733加速器");
    ComboBox_AddString(accelSel, L"奇游加速器");
    ComboBox_SetCurSel(accelSel, 0);
    HWND gameSel = CreateDarkComboBox(p4, IDC_GAME_SELECTOR, 145, 32, 160, 200);
    ComboBox_AddString(gameSel, L"Minecraft Java (25565)");
    ComboBox_AddString(gameSel, L"Minecraft 基岩版 (19132)");
    ComboBox_AddString(gameSel, L"自定义端口");
    ComboBox_SetCurSel(gameSel, 0);
    CreateDarkCheckBox(p4, IDC_CHK_ACCEL_COMPAT, L"启用加速器兼容模式", 315, 32, 250, 20, false);
}

void CreateDiagPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[7] = page;

    CreateLabel(page, L"网络诊断", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"实时带宽监控与网络分析", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    // Bandwidth monitor
    HWND bwPanel = CreatePanel(page, COL_PANEL, 20, 75, 720, 130);
    CreateLabel(bwPanel, L"实时带宽", 16, 12, 100, 20, COL_TEXT_TITLE, 14, true);
    HWND btnMon = CreateDarkButton(bwPanel, IDC_MONITOR_TOGGLE, L"开始监控", 620, 8, 80, 28, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnMon, ButtonSubclassProc, 0, 0);

    // Download card
    HWND dlCard = CreatePanel(bwPanel, COL_DEEPBLUE, 16, 40, 335, 75);
    CreateLabel(dlCard, L"下载", 12, 8, 60, 18, COL_TEXT_DIM, 13);
    HWND dlVal = CreateLabel(dlCard, L"0.0", 12, 26, 100, 30, COL_GREEN, 24, true);
    SetWindowLongPtrW(dlVal, GWLP_ID, IDC_REALTIME_DL);
    CreateLabel(dlCard, L" Mbps", 80, 34, 50, 18, COL_TEXT_DIM, 13);
    HWND dlBar = CreateProgressBar(dlCard, IDC_DL_BAR, 12, 60, 310, 6);

    // Upload card
    HWND ulCard = CreatePanel(bwPanel, COL_DEEPBLUE, 360, 40, 335, 75);
    CreateLabel(ulCard, L"上传", 12, 8, 60, 18, COL_TEXT_DIM, 13);
    HWND ulVal = CreateLabel(ulCard, L"0.0", 12, 26, 100, 30, COL_ORANGE, 24, true);
    SetWindowLongPtrW(ulVal, GWLP_ID, IDC_REALTIME_UL);
    CreateLabel(ulCard, L" Mbps", 80, 34, 50, 18, COL_TEXT_DIM, 13);
    HWND ulBar = CreateProgressBar(ulCard, IDC_UL_BAR, 12, 60, 310, 6);

    // Diagnostics
    HWND diagPanel = CreatePanel(page, COL_PANEL, 20, 220, 720, 350);
    CreateLabel(diagPanel, L"完整诊断", 16, 12, 100, 20, COL_TEXT_TITLE, 14, true);
    HWND btnDiag = CreateDarkButton(diagPanel, IDC_BTN_RUN_DIAG, L"运行诊断", 120, 8, 100, 28, COL_GREEN, RGB(0x1A,0x1A,0x2E));
    SetWindowSubclass(btnDiag, ButtonSubclassProc, 0, 0);
    CreateDarkEdit(diagPanel, IDC_DIAG_TEXT, L"点击运行诊断开始...", 16, 42, 690, 295, true, true);
}

void CreateLogPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[8] = page;

    CreateLabel(page, L"操作日志", 20, 10, 400, 30, COL_TEXT_TITLE, 22, true);
    HWND btnExport = CreateDarkButton(page, IDC_BTN_EXPORT_LOG, L"导出", 620, 12, 55, 28, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnExport, ButtonSubclassProc, 0, 0);
    HWND btnClear = CreateDarkButton(page, IDC_BTN_CLEAR_LOG, L"清空", 680, 12, 55, 28, COL_DEEPBLUE, COL_TEXT_TITLE);
    SetWindowSubclass(btnClear, ButtonSubclassProc, 0, 0);

    HWND panel = CreatePanel(page, COL_PANEL, 20, 50, 720, 520);
    HWND lb = CreateDarkListBox(panel, IDC_LOG_LIST, 8, 8, 704, 500);
}

void CreateSettingsPage(HWND parent) {
    HWND page = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD, 0, 0, 760, 600, parent, nullptr, g_hInst, nullptr);
    g_hPages[9] = page;

    CreateLabel(page, L"设置", 20, 10, 600, 30, COL_TEXT_TITLE, 22, true);
    CreateLabel(page, L"软件偏好设置，修改后自动保存。", 20, 42, 600, 20, COL_TEXT_DIM, 13);

    // Auto start
    HWND p1 = CreatePanel(page, COL_PANEL, 20, 75, 720, 80);
    CreateLabel(p1, L"开机自启动", 16, 12, 200, 20, COL_ACCENT, 15, true);
    CreateLabel(p1, L"开启后，软件将在 Windows 启动时自动运行。", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    CreateDarkCheckBox(p1, IDC_CHK_AUTOSTART, L"开启开机自启动", 16, 58, 200, 20, false);

    // System info
    HWND p2 = CreatePanel(page, COL_PANEL, 20, 170, 720, 110);
    CreateLabel(p2, L"系统资源监控", 16, 12, 200, 20, COL_ACCENT, 15, true);
    CreateLabel(p2, L"在主界面（配置页）显示 CPU 和内存占用。", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    CreateDarkCheckBox(p2, IDC_CHK_SYSINFO, L"在主界面显示 CPU / 内存占用", 16, 58, 250, 20, true);
    CreateLabel(p2, L"CPU 占用：", 280, 60, 70, 18, COL_TEXT, 14);
    HWND cpuLbl = CreateLabel(p2, L"--", 355, 60, 60, 18, COL_ACCENT, 16, true);
    SetWindowLongPtrW(cpuLbl, GWLP_ID, IDC_SETTINGS_CPU);
    CreateLabel(p2, L"内存占用：", 430, 60, 70, 18, COL_TEXT, 14);
    HWND memLbl = CreateLabel(p2, L"--", 505, 60, 60, 18, COL_ACCENT, 16, true);
    SetWindowLongPtrW(memLbl, GWLP_ID, IDC_SETTINGS_MEM);

    // Theme
    HWND p3 = CreatePanel(page, COL_PANEL, 20, 295, 720, 110);
    CreateLabel(p3, L"主题模式", 16, 12, 200, 20, COL_ACCENT, 15, true);
    CreateLabel(p3, L"切换暗色或明亮主题。暗色适合夜间使用，明亮主题适合白天。", 16, 36, 690, 20, COL_TEXT_DIM, 13);
    HWND radioDark = CreateWindowExW(0, L"BUTTON", L"暗色主题", WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
        16, 62, 120, 22, p3, (HMENU)(INT_PTR)IDC_RADIO_DARK, g_hInst, nullptr);
    SendMessageW(radioDark, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
    SendMessageW(radioDark, BM_SETCHECK, BST_CHECKED, 0);
    SetWindowTheme(radioDark, L"", L"");

    HWND radioLight = CreateWindowExW(0, L"BUTTON", L"明亮主题", WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
        146, 62, 120, 22, p3, (HMENU)(INT_PTR)IDC_RADIO_LIGHT, g_hInst, nullptr);
    SendMessageW(radioLight, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
    SetWindowTheme(radioLight, L"", L"");
}

// ========== SIDEBAR ==========
struct NavItem {
    int id;
    const wchar_t* text;
};
NavItem g_navItems[] = {
    { IDC_NAV_CONFIG,   L"配置" },
    { IDC_NAV_TCP,      L"TCP/IP" },
    { IDC_NAV_DNS,      L"DNS" },
    { IDC_NAV_QOS,      L"QoS" },
    { IDC_NAV_HOSTS,    L"Hosts编辑" },
    { IDC_NAV_CUSTOM,   L"自定义优化" },
    { IDC_NAV_TEST,     L"测试" },
    { IDC_NAV_DIAG,     L"网络诊断" },
    { IDC_NAV_LOG,      L"操作日志" },
    { IDC_NAV_SETTINGS, L"设置" },
};

void UpdateNavButtons() {
    for (int i = 0; i < 10; i++) {
        HWND btn = GetDlgItem(g_hMainWnd, g_navItems[i].id);
        if (btn) {
            COLORREF bg = (i == g_currentPage) ? COL_NAV_ACTIVE : COL_NAV_INACTIVE;
            SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
            InvalidateRect(btn, nullptr, FALSE);
        }
    }
    // Show/hide pages
    for (int i = 0; i < 10; i++) {
        if (g_hPages[i]) {
            ShowWindow(g_hPages[i], i == g_currentPage ? SW_SHOW : SW_HIDE);
        }
    }
}

void CreateSidebar(HWND parent) {
    // Brand
    CreateLabel(parent, L"ALit-网络优化工具V3", 20, 20, 180, 22, COL_ACCENT, 16, true);
    CreateLabel(parent, L"System Performance Optimizer", 20, 44, 180, 16, COL_TEXT, 10);

    // Nav buttons
    for (int i = 0; i < 10; i++) {
        HWND btn = CreateWindowExW(0, L"BUTTON", g_navItems[i].text,
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON | BS_TEXT | BS_LEFT,
            12, 75 + i * 40, 196, 34, parent, (HMENU)(INT_PTR)g_navItems[i].id, g_hInst, nullptr);
        SendMessageW(btn, WM_SETFONT, (WPARAM)g_hFontMain, TRUE);
        SetWindowTheme(btn, L"", L"");
        SetWindowSubclass(btn, ButtonSubclassProc, 0, 0);
        COLORREF bg = (i == 0) ? COL_NAV_ACTIVE : COL_NAV_INACTIVE;
        SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
    }

    // Status
    HWND stPanel = CreatePanel(parent, COL_NAV_INACTIVE, 20, 530, 180, 50);
    CreateLabel(stPanel, L"状态", 12, 6, 100, 18, COL_TEXT, 13);
    HWND stLbl = CreateLabel(stPanel, L"检测中...", 12, 24, 156, 18, COL_TEXT, 13, true);
    SetWindowLongPtrW(stLbl, GWLP_ID, IDC_SIDEBAR_STATUS);
}

// ========== OPTIMIZATION LOGIC ==========
void ApplyOptimization(int mode) {
    // mode: 0=Balanced, 1=Normal, 2=Complete, 3=Revert
    auto& engine = NetworkOptimizationEngine::Instance();

    HWND hList = GetDlgItem(g_hPages[0], IDC_RESULTS_LIST);
    if (hList) ListBox_ResetContent(hList);
    HWND hProgress = GetDlgItem(g_hPages[0], IDC_PROGRESS);
    if (hProgress) SendMessageW(hProgress, PBM_SETPOS, 0, 0);
    HWND hStatus = GetDlgItem(g_hPages[0], IDC_STATUS_TEXT);

    auto progressCb = [hProgress, hStatus, hList](const std::wstring& msg, int pct) {
        if (hProgress) SendMessageW(hProgress, PBM_SETPOS, pct, 0);
        if (hStatus) SetWindowTextW(hStatus, msg.c_str());
        if (hList) {
            int idx = ListBox_AddString(hList, msg.c_str());
            ListBox_SetTopIndex(hList, idx);
        }
    };

    if (mode == 3) {
        // Revert
        if (hStatus) SetWindowTextW(hStatus, L"正在还原...");
        auto adapters = engine.GetActiveAdapters();
        std::wstring iface = adapters.empty() ? L"" : adapters[0].name;
        auto summary = engine.RevertAllOptimizations(OptLevel::Gaming, iface, progressCb);

        std::wstring result = L"还原完成: " + std::to_wstring(summary.successCount) + L"/" + std::to_wstring(summary.totalItems) + L" 成功";
        if (hList) { int idx = ListBox_AddString(hList, result.c_str()); ListBox_SetTopIndex(hList, idx); }
        AddLog(L"INFO", result);
        if (hProgress) SendMessageW(hProgress, PBM_SETPOS, 100, 0);
        if (hStatus) SetWindowTextW(hStatus, result.c_str());

        // Restore DNS
        for (auto& a : adapters) {
            RunCommand(L"netsh interface ip set dns name=\"" + a.name + L"\" source=dhcp", nullptr);
        }
        // Remove QoS
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Java_Game\"", nullptr);
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Bedrock_Game\"", nullptr);
        RunCommand(L"ipconfig /flushdns", nullptr);
    } else {
        // Apply optimization
        if (hStatus) SetWindowTextW(hStatus, L"正在应用优化...");
        auto adapters = engine.GetActiveAdapters();
        std::wstring iface = adapters.empty() ? L"" : adapters[0].name;

        auto summary = engine.ApplyAllOptimizations(OptLevel::Gaming, iface, progressCb);

        // Additional optimizations based on mode
        if (mode >= 1) {
            // QoS
            RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Java_Game\"", nullptr);
            RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Bedrock_Game\"", nullptr);
            RunCommand(L"netsh qos add policy name=\"NetOpt_MC_Java_Game\" appPath=\"javaw.exe\" dscp=46 throttleRate=none", nullptr);
            RunCommand(L"netsh qos add policy name=\"NetOpt_MC_Bedrock_Game\" appPath=\"Minecraft.Windows.exe\" dscp=46 throttleRate=none", nullptr);
        }

        if (mode >= 2) {
            // Additional registry settings for Complete mode
            RunCommand(L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v DefaultSendWindow /t REG_DWORD /d 65535 /f", nullptr);
            RunCommand(L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v DefaultReceiveWindow /t REG_DWORD /d 65535 /f", nullptr);
            RunCommand(L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\" /v MaxConnections /t REG_DWORD /d 65536 /f", nullptr);
        }

        RunCommand(L"ipconfig /flushdns", nullptr);

        std::wstring result = L"优化完成: " + std::to_wstring(summary.successCount) + L"/" + std::to_wstring(summary.totalItems) + L" 成功";
        if (hList) { int idx = ListBox_AddString(hList, result.c_str()); ListBox_SetTopIndex(hList, idx); }
        AddLog(L"INFO", result);
        if (hProgress) SendMessageW(hProgress, PBM_SETPOS, 100, 0);
        if (hStatus) SetWindowTextW(hStatus, result.c_str());
    }

    // Save state
    HKEY hKey;
    RegCreateKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\ALitNetworkOptimizer", 0, nullptr, 0, KEY_WRITE, nullptr, &hKey, nullptr);
    if (hKey) {
        DWORD isOpt = (mode == 3) ? 0 : 1;
        RegSetValueExW(hKey, L"IsOptimized", 0, REG_DWORD, (BYTE*)&isOpt, sizeof(isOpt));
        RegSetValueExW(hKey, L"Mode", 0, REG_SZ, (BYTE*)g_modeShortNames[mode], (wcslen(g_modeShortNames[mode]) + 1) * 2);
        RegCloseKey(hKey);
    }

    // Update sidebar status
    HWND hSidebarStatus = GetDlgItem(g_hMainWnd, IDC_SIDEBAR_STATUS);
    if (hSidebarStatus) {
        SetWindowTextW(hSidebarStatus, (mode == 3) ? L"未优化" : g_modeShortNames[mode]);
    }
}

// ========== EVENT HANDLER ==========
INT_PTR HandleCommand(WPARAM wParam, LPARAM lParam) {
    int id = LOWORD(wParam);
    HWND hCtrl = (HWND)lParam;

    // Navigation
    for (int i = 0; i < 10; i++) {
        if (id == g_navItems[i].id) {
            g_currentPage = i;
            UpdateNavButtons();
            return 0;
        }
    }

    // Title bar buttons
    if (id == IDC_BTN_MINIMIZE) { ShowWindow(g_hMainWnd, SW_MINIMIZE); return 0; }
    if (id == IDC_BTN_CLOSE) {
        // Stop WinDivert
        if (g_wdRunning.load()) {
            g_wdRunning = false;
            if (g_wdThread.joinable()) g_wdThread.detach();
        }
        PostQuitMessage(0);
        return 0;
    }

    // Dashboard mode selection
    if (id >= IDC_BTN_BALANCED && id <= IDC_BTN_REVERT) {
        int mode = id - IDC_BTN_BALANCED;
        g_selectedMode = mode;
        // Update button colors
        for (int i = 0; i < 4; i++) {
            HWND btn = GetDlgItem(g_hPages[0], IDC_BTN_BALANCED + i);
            if (btn) {
                COLORREF bg = (i == mode) ? COL_ACCENT : COL_BTN_DARK;
                SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
                InvalidateRect(btn, nullptr, FALSE);
            }
        }
        HWND modeLbl = GetDlgItem(g_hPages[0], IDC_MODE_LABEL);
        if (modeLbl) SetWindowTextW(modeLbl, g_modeNames[mode]);
        return 0;
    }

    // Apply optimization
    if (id == IDC_BTN_OPTIMIZE) {
        std::thread([=]() {
            ApplyOptimization(g_selectedMode);
        }).detach();
        return 0;
    }

    // Revert
    if (id == IDC_BTN_REVERT_ACT) {
        std::thread([=]() {
            ApplyOptimization(3);
        }).detach();
        return 0;
    }

    // Speed test
    if (id == IDC_BTN_SPEEDTEST) {
        std::thread([=]() {
            auto result = NetworkOptimizationEngine::Instance().RunSpeedTest();
            wchar_t buf[256];
            swprintf_s(buf, L"下载: %.1f Mbps | 上传: %.1f Mbps | 延迟: %.0f ms", result.downloadMbps, result.uploadMbps, result.pingMs);
            HWND hList = GetDlgItem(g_hPages[0], IDC_RESULTS_LIST);
            if (hList) { int idx = ListBox_AddString(hList, buf); ListBox_SetTopIndex(hList, idx); }
            AddLog(L"INFO", std::wstring(L"网速测试: ") + buf);
        }).detach();
        return 0;
    }

    // TCP refresh
    if (id == IDC_BTN_REFRESH_TCP) {
        std::thread([=]() {
            std::wstring output = RunCommand(L"netsh interface tcp show global", nullptr);
            HWND hText = GetDlgItem(g_hPages[1], IDC_TCP_TEXT);
            if (hText) SetWindowTextW(hText, output.c_str());
            AddLog(L"INFO", L"TCP 全局设置已刷新");
        }).detach();
        return 0;
    }

    // DNS buttons
    if (id >= IDC_DNS_BTN_0 && id <= IDC_DNS_BTN_4) {
        int dnsIdx = id - IDC_DNS_BTN_0;
        g_selectedDns = dnsIdx;
        // Update button colors
        for (int i = 0; i < 5; i++) {
            HWND btn = GetDlgItem(g_hPages[2], IDC_DNS_BTN_0 + i);
            if (btn) {
                COLORREF bg = (i == dnsIdx) ? COL_ACCENT : COL_BTN_DARK;
                SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
                InvalidateRect(btn, nullptr, FALSE);
            }
        }
        return 0;
    }

    // Apply DNS
    if (id == IDC_DNS_BTN_APPLY) {
        if (g_selectedDns < 0) {
            MessageBoxW(g_hMainWnd, L"请先选择一个 DNS 预设", L"提示", MB_OK | MB_ICONWARNING);
            return 0;
        }
        std::thread([=]() {
            DnsPreset& dns = g_dnsPresets[g_selectedDns];
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            int okCount = 0;
            for (auto& a : adapters) {
                std::wstring cmd1 = L"netsh interface ip set dns name=\"" + a.name + L"\" static " + dns.primary + L" primary";
                std::wstring cmd2 = L"netsh interface ip add dns name=\"" + a.name + L"\" " + dns.secondary + L" index=2";
                int ec1, ec2;
                RunCommand(cmd1, &ec1);
                RunCommand(cmd2, &ec2);
                if (ec1 == 0 && ec2 == 0) okCount++;
            }
            AddLog(L"INFO", L"DNS 已设置为 " + std::wstring(dns.primary) + L" / " + dns.secondary);
            std::wstring msg = L"DNS 已设置为 " + std::wstring(dns.primary) + L" / " + dns.secondary + L"\n覆盖 " + std::to_wstring(okCount) + L" 个活动网卡";
            MessageBoxW(g_hMainWnd, msg.c_str(), L"成功", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    // Flush DNS
    if (id == IDC_DNS_BTN_FLUSH) {
        RunCommand(L"ipconfig /flushdns", nullptr);
        AddLog(L"INFO", L"DNS 缓存已清理");
        MessageBoxW(g_hMainWnd, L"DNS 缓存清理成功！", L"成功", MB_OK | MB_ICONINFORMATION);
        return 0;
    }

    // Restore DNS
    if (id == IDC_DNS_BTN_RESTORE) {
        std::thread([=]() {
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            int okCount = 0;
            for (auto& a : adapters) {
                std::wstring cmd = L"netsh interface ip set dns name=\"" + a.name + L"\" source=dhcp";
                int ec;
                RunCommand(cmd, &ec);
                if (ec == 0) okCount++;
            }
            AddLog(L"INFO", L"DNS 已恢复为 DHCP");
            MessageBoxW(g_hMainWnd, (L"DNS 已恢复为 DHCP\n覆盖 " + std::to_wstring(okCount) + L" 个活动网卡").c_str(), L"成功", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    // DNS speed test
    if (id == IDC_DNS_BTN_SPEED) {
        std::thread([=]() {
            for (int i = 0; i < 5; i++) {
                std::wstring cmd = L"ping -n 3 " + std::wstring(g_dnsPresets[i].primary);
                std::wstring output = RunCommand(cmd, nullptr);
                // Parse average
                int latency = -1;
                size_t pos = output.find(L"Average = ");
                if (pos != std::wstring::npos) latency = _wtoi(output.c_str() + pos + 10);
                else { pos = output.find(L"平均 = "); if (pos != std::wstring::npos) latency = _wtoi(output.c_str() + pos + 7); }

                wchar_t buf[64];
                swprintf_s(buf, L"%s ----- %s", g_dnsPresets[i].name, latency >= 0 ? (std::to_wstring(latency) + L" ms").c_str() : L"超时");
                // Update button text
                HWND btn = GetDlgItem(g_hPages[2], IDC_DNS_BTN_0 + i);
                if (btn) SetWindowTextW(btn, buf);
            }
            AddLog(L"INFO", L"DNS 测速已完成");
        }).detach();
        return 0;
    }

    // QoS
    if (id == IDC_BTN_APPLY_QOS) {
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Java_Game\"", nullptr);
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Bedrock_Game\"", nullptr);
        int ec1, ec2;
        RunCommand(L"netsh qos add policy name=\"NetOpt_MC_Java_Game\" appPath=\"javaw.exe\" dscp=46 throttleRate=none", &ec1);
        RunCommand(L"netsh qos add policy name=\"NetOpt_MC_Bedrock_Game\" appPath=\"Minecraft.Windows.exe\" dscp=46 throttleRate=none", &ec2);
        AddLog(L"INFO", L"QoS 策略已应用 (DSCP 46)");
        MessageBoxW(g_hMainWnd, L"Minecraft QoS 策略已应用 (DSCP 46)", L"成功", MB_OK | MB_ICONINFORMATION);
        // Refresh
        std::wstring qosOut = RunCommand(L"netsh qos show policy", nullptr);
        HWND hText = GetDlgItem(g_hPages[3], IDC_QOS_TEXT);
        if (hText) SetWindowTextW(hText, qosOut.c_str());
        return 0;
    }

    if (id == IDC_BTN_REMOVE_QOS) {
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Java_Game\"", nullptr);
        RunCommand(L"netsh qos delete policy name=\"NetOpt_MC_Bedrock_Game\"", nullptr);
        AddLog(L"INFO", L"QoS 策略已移除");
        std::wstring qosOut = RunCommand(L"netsh qos show policy", nullptr);
        HWND hText = GetDlgItem(g_hPages[3], IDC_QOS_TEXT);
        if (hText) SetWindowTextW(hText, qosOut.c_str());
        return 0;
    }

    if (id == IDC_BTN_REFRESH_QOS) {
        std::wstring qosOut = RunCommand(L"netsh qos show policy", nullptr);
        HWND hText = GetDlgItem(g_hPages[3], IDC_QOS_TEXT);
        if (hText) SetWindowTextW(hText, qosOut.c_str());
        return 0;
    }

    // Hosts
    if (id == IDC_BTN_LOAD_HOSTS) {
        wchar_t hostsPath[MAX_PATH];
        GetSystemDirectoryW(hostsPath, MAX_PATH);
        wcscat_s(hostsPath, L"\\drivers\\etc\\hosts");
        std::ifstream f(hostsPath);
        if (f) {
            std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
            std::wstring wcontent(content.begin(), content.end());
            HWND hText = GetDlgItem(g_hPages[4], IDC_HOSTS_EDITOR);
            if (hText) SetWindowTextW(hText, wcontent.c_str());
            AddLog(L"INFO", L"Hosts 文件已加载");
        }
        return 0;
    }

    if (id == IDC_BTN_SAVE_HOSTS) {
        wchar_t hostsPath[MAX_PATH];
        GetSystemDirectoryW(hostsPath, MAX_PATH);
        wcscat_s(hostsPath, L"\\drivers\\etc\\hosts");
        HWND hText = GetDlgItem(g_hPages[4], IDC_HOSTS_EDITOR);
        if (hText) {
            int len = GetWindowTextLengthW(hText) + 1;
            std::wstring content(len, 0);
            GetWindowTextW(hText, &content[0], len);
            std::ofstream f(hostsPath);
            if (f) {
                f << std::string(content.begin(), content.end());
                AddLog(L"INFO", L"Hosts 文件已保存");
                MessageBoxW(g_hMainWnd, L"Hosts 已保存", L"成功", MB_OK | MB_ICONINFORMATION);
            }
        }
        return 0;
    }

    // Custom optimization
    if (id == IDC_BTN_APPLY_CUSTOM) {
        std::thread([=]() {
            int applied = 0, failed = 0;
            for (auto& item : g_customItems) {
                HWND hChk = GetDlgItem(g_hPages[5], item.checkId);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    for (auto& cmd : item.commands) {
                        int ec;
                        RunCommand(cmd, &ec);
                        if (ec == 0) applied++; else failed++;
                    }
                }
            }
            RunCommand(L"ipconfig /flushdns", nullptr);
            AddLog(L"INFO", L"自定义优化已应用: " + std::to_wstring(applied) + L" 成功, " + std::to_wstring(failed) + L" 失败");
            MessageBoxW(g_hMainWnd, (L"自定义优化已应用\n成功: " + std::to_wstring(applied) + L"\n失败: " + std::to_wstring(failed)).c_str(), L"完成", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    if (id == IDC_BTN_REC_CUSTOM) {
        for (auto& item : g_customItems) {
            HWND hChk = GetDlgItem(g_hPages[5], item.checkId);
            if (hChk) SendMessageW(hChk, BM_SETCHECK, item.recommended ? BST_CHECKED : BST_UNCHECKED, 0);
        }
        return 0;
    }

    if (id == IDC_BTN_CLEAR_CUSTOM) {
        for (auto& item : g_customItems) {
            HWND hChk = GetDlgItem(g_hPages[5], item.checkId);
            if (hChk) SendMessageW(hChk, BM_SETCHECK, BST_UNCHECKED, 0);
        }
        return 0;
    }

    // WinDivert mode selection
    if (id >= IDC_WD_MODE_0 && id <= IDC_WD_MODE_4) {
        g_wdMode = id - IDC_WD_MODE_0;
        for (int i = 0; i < 5; i++) {
            HWND btn = GetDlgItem(g_hPages[6], IDC_WD_MODE_0 + i);
            if (btn) {
                COLORREF bg = (i == g_wdMode) ? COL_ACCENT : COL_BTN_DARK;
                SetWindowLongPtrW(btn, GWLP_USERDATA, (LONG_PTR)bg);
                InvalidateRect(btn, nullptr, FALSE);
            }
        }
        HWND modeLbl = GetDlgItem(g_hPages[6], IDC_WD_MODE_LABEL);
        if (modeLbl) {
            wchar_t buf[8]; swprintf_s(buf, L"%d", g_wdMode);
            SetWindowTextW(modeLbl, buf);
        }
        return 0;
    }

    // WinDivert start
    if (id == IDC_BTN_WD_START) {
        if (g_wdRunning.load()) return 0;

        // Show warning
        if (MessageBoxW(g_hMainWnd,
            L"此功能将安装 WinDivert 内核驱动（WinDivert64.sys），在 NDIS 层逐包拦截并修改网络数据包的 DSCP/TOS 字段。\n\n"
            L"风险提示：\n1. 内核驱动安装可能导致系统蓝屏（BSOD）\n2. 杀毒软件可能拦截或删除驱动文件\n"
            L"3. 驱动运行时所有指定端口流量经过内核拦截层\n4. 如系统出现不稳定，请立即点击停止并卸载驱动\n"
            L"5. 卸载驱动后需重启计算机以完全清除\n\n是否确认启动 WinDivert 逐包优化？",
            L"WinDivert 警告声明", MB_OKCANCEL | MB_ICONWARNING) != IDOK) return 0;

        std::thread([=]() {
            HWND hResult = GetDlgItem(g_hPages[6], IDC_WD_RESULT);
            if (hResult) SetWindowTextW(hResult, L"正在准备 WinDivert 环境...\r\n1. 检查/下载 WinDivert 驱动...\r\n");

            if (!LoadWinDivertDll()) {
                if (hResult) SetWindowTextW(hResult, L"[失败] 无法加载 WinDivert.dll\r\n");
                return;
            }
            if (hResult) SetWindowTextW(hResult, L"  [OK] WinDivert.dll + WinDivert64.sys 就绪\r\n2. 开始逐包优化...\r\n");

            // Read settings
            wchar_t tcpPort[32], udpPort[32], dscp[16];
            HWND hTcp = GetDlgItem(g_hPages[6], IDC_WD_TCP_PORT);
            HWND hUdp = GetDlgItem(g_hPages[6], IDC_WD_UDP_PORT);
            HWND hDscp = GetDlgItem(g_hPages[6], IDC_WD_DSCP);
            if (hTcp) GetWindowTextW(hTcp, tcpPort, 32); else wcscpy_s(tcpPort, L"25565");
            if (hUdp) GetWindowTextW(hUdp, udpPort, 32); else wcscpy_s(udpPort, L"19132");
            if (hDscp) GetWindowTextW(hDscp, dscp, 16); else wcscpy_s(dscp, L"46");

            std::vector<int> tcpPorts, udpPorts;
            // Parse ports
            std::wstring tcpStr(tcpPort), udpStr(udpPort);
            std::wstring buf;
            for (wchar_t c : tcpStr) { if (c == L',' || c == L' ' || c == L';') { if (!buf.empty()) { tcpPorts.push_back(_wtoi(buf.c_str())); buf.clear(); } } else buf += c; }
            if (!buf.empty()) tcpPorts.push_back(_wtoi(buf.c_str()));
            buf.clear();
            for (wchar_t c : udpStr) { if (c == L',' || c == L' ' || c == L';') { if (!buf.empty()) { udpPorts.push_back(_wtoi(buf.c_str())); buf.clear(); } } else buf += c; }
            if (!buf.empty()) udpPorts.push_back(_wtoi(buf.c_str()));
            if (tcpPorts.empty()) tcpPorts.push_back(25565);
            if (udpPorts.empty()) udpPorts.push_back(19132);

            BYTE dscpVal = (BYTE)_wtoi(dscp);

            // Setup log paths
            wchar_t tempDir[MAX_PATH];
            GetTempPathW(MAX_PATH, tempDir);
            g_wdLogPath = std::wstring(tempDir) + L"WinDivertWD\\wd_output.log";
            g_wdErrPath = std::wstring(tempDir) + L"WinDivertWD\\wd_error.log";
            DeleteFileW(g_wdLogPath.c_str());
            DeleteFileW(g_wdErrPath.c_str());

            // Reset stats
            wdTotalPackets = 0;
            wdModifiedPackets = 0;
            wdFecPackets = 0;
            wdBtPackets = 0;
            wdBtRecovered = 0;

            // Start worker
            g_wdRunning = true;
            g_wdThread = std::thread(WinDivertWorker, g_wdMode, dscpVal, tcpPorts, udpPorts, false);

            // Enable/disable buttons
            EnableWindow(GetDlgItem(g_hPages[6], IDC_BTN_WD_START), FALSE);
            EnableWindow(GetDlgItem(g_hPages[6], IDC_BTN_WD_STOP), TRUE);

            if (hResult) SetWindowTextW(hResult, (L"  [OK] 进程已启动\r\n模式: " + std::wstring(g_wdModeNames[g_wdMode]) + L"\r\nWinDivert 正在后台运行...\r\n点击刷新状态查看实时包计数").c_str());
            AddLog(L"INFO", L"WinDivert 逐包优化已启动");
        }).detach();
        return 0;
    }

    // WinDivert stop
    if (id == IDC_BTN_WD_STOP) {
        g_wdRunning = false;
        if (g_wdThread.joinable()) g_wdThread.join();

        EnableWindow(GetDlgItem(g_hPages[6], IDC_BTN_WD_START), TRUE);
        EnableWindow(GetDlgItem(g_hPages[6], IDC_BTN_WD_STOP), FALSE);

        HWND hResult = GetDlgItem(g_hPages[6], IDC_WD_RESULT);
        if (hResult) SetWindowTextW(hResult, L"WinDivert 已停止\r\n");
        AddLog(L"INFO", L"WinDivert 逐包优化已停止");
        return 0;
    }

    // WinDivert refresh
    if (id == IDC_BTN_WD_REFRESH) {
        if (!g_wdRunning.load()) {
            HWND hResult = GetDlgItem(g_hPages[6], IDC_WD_RESULT);
            if (hResult) SetWindowTextW(hResult, L"WinDivert 未运行\r\n");
            return 0;
        }
        // Read log file
        std::ifstream f(g_wdLogPath);
        if (f) {
            std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
            std::wstring wcontent(content.begin(), content.end());
            HWND hResult = GetDlgItem(g_hPages[6], IDC_WD_RESULT);
            if (hResult) SetWindowTextW(hResult, wcontent.c_str());
        }
        return 0;
    }

    // WinDivert uninstall
    if (id == IDC_BTN_WD_UNINSTALL) {
        if (MessageBoxW(g_hMainWnd, L"确认卸载 WinDivert 驱动？\n\n卸载后建议重启计算机以完全清除。\nWinDivert 文件将被删除。",
            L"卸载确认", MB_OKCANCEL | MB_ICONQUESTION) != IDOK) return 0;

        if (g_wdRunning.load()) {
            g_wdRunning = false;
            if (g_wdThread.joinable()) g_wdThread.join();
        }
        RunCommand(L"sc stop WinDivert", nullptr);
        RunCommand(L"sc stop WinDivert14", nullptr);
        RunCommand(L"sc delete WinDivert", nullptr);
        RunCommand(L"sc delete WinDivert14", nullptr);

        // Delete files
        wchar_t tempDir[MAX_PATH];
        GetTempPathW(MAX_PATH, tempDir);
        std::wstring wdDir = std::wstring(tempDir) + L"WinDivertWD";
        std::wstring rmCmd = L"cmd /c rmdir /s /q \"" + wdDir + L"\"";
        _wsystem(rmCmd.c_str());

        HWND hResult = GetDlgItem(g_hPages[6], IDC_WD_RESULT);
        if (hResult) SetWindowTextW(hResult, L"WinDivert 驱动已卸载\r\n建议重启计算机以完全清除。");
        AddLog(L"INFO", L"WinDivert 驱动已卸载");
        MessageBoxW(g_hMainWnd, L"WinDivert 驱动已卸载。\n建议重启计算机以完全清除。", L"完成", MB_OK | MB_ICONINFORMATION);
        return 0;
    }

    // Bandwidth monitor toggle
    if (id == IDC_MONITOR_TOGGLE) {
        HWND hBtn = GetDlgItem(g_hPages[7], IDC_MONITOR_TOGGLE);
        if (g_bwRunning.load()) {
            g_bwRunning = false;
            if (g_bwThread.joinable()) g_bwThread.join();
            if (hBtn) SetWindowTextW(hBtn, L"开始监控");
            AddLog(L"INFO", L"带宽监控已停止");
        } else {
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (adapters.empty()) {
                MessageBoxW(g_hMainWnd, L"未检测到活动网卡", L"错误", MB_OK | MB_ICONERROR);
                return 0;
            }
            std::wstring iface = adapters[0].name;
            g_bwRunning = true;
            if (hBtn) SetWindowTextW(hBtn, L"停止监控");
            g_bwThread = std::thread([iface]() {
                auto& diag = NetworkOptimizationEngine::Instance();
                UINT32 ifIndex = 0;
                // Get interface index
                std::wstring cmd = L"powershell -Command \"(Get-NetAdapter -Name '" + iface + L"').ifIndex\"";
                std::wstring output = RunCommand(cmd, nullptr);
                // Parse number
                int idx = _wtoi(output.c_str());
                if (idx > 0) ifIndex = idx;

                uint64_t prevSent = 0, prevRecv = 0;
                auto prevTime = std::chrono::steady_clock::now();
                bool first = true;

                while (g_bwRunning.load()) {
                    uint64_t sent = 0, recv = 0;
                    if (diag.GetDiagnostic(iface).adapterName.length() > 0) {
                        // Use GetIfEntry2
                        MIB_IF_ROW2 row;
                        memset(&row, 0, sizeof(row));
                        row.InterfaceIndex = ifIndex;
                        if (GetIfEntry2(&row) == NO_ERROR) {
                            sent = row.OutOctets;
                            recv = row.InOctets;
                        }
                    }

                    if (!first) {
                        auto now = std::chrono::steady_clock::now();
                        double dt = std::chrono::duration_cast<std::chrono::milliseconds>(now - prevTime).count() / 1000.0;
                        if (dt > 0) {
                            double dl = std::max(0.0, (double)((long long)recv - (long long)prevRecv) * 8 / 1000000.0 / dt);
                            double ul = std::max(0.0, (double)((long long)sent - (long long)prevSent) * 8 / 1000000.0 / dt);

                            wchar_t dlBuf[32], ulBuf[32];
                            swprintf_s(dlBuf, L"%.1f", dl);
                            swprintf_s(ulBuf, L"%.1f", ul);

                            HWND hDl = GetDlgItem(g_hPages[7], IDC_REALTIME_DL);
                            HWND hUl = GetDlgItem(g_hPages[7], IDC_REALTIME_UL);
                            HWND hDlBar = GetDlgItem(g_hPages[7], IDC_DL_BAR);
                            HWND hUlBar = GetDlgItem(g_hPages[7], IDC_UL_BAR);
                            if (hDl) SetWindowTextW(hDl, dlBuf);
                            if (hUl) SetWindowTextW(hUl, ulBuf);
                            if (hDlBar) SendMessageW(hDlBar, PBM_SETPOS, (WPARAM)std::min(dl, 100.0), 0);
                            if (hUlBar) SendMessageW(hUlBar, PBM_SETPOS, (WPARAM)std::min(ul, 100.0), 0);
                        }
                    }
                    prevSent = sent;
                    prevRecv = recv;
                    prevTime = std::chrono::steady_clock::now();
                    first = false;
                    Sleep(1000);
                }
            });
            AddLog(L"INFO", L"带宽监控已启动: " + iface);
        }
        return 0;
    }

    // Run diagnostics
    if (id == IDC_BTN_RUN_DIAG) {
        std::thread([=]() {
            HWND hText = GetDlgItem(g_hPages[7], IDC_DIAG_TEXT);
            if (hText) SetWindowTextW(hText, L"Running diagnostics...");

            std::wstringstream ss;
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (!adapters.empty()) {
                auto& a = adapters[0];
                ss << L"=== Adapter ===\n";
                ss << L"名称: " << a.name << L"\n";
                ss << L"描述: " << a.description << L"\n";
                ss << L"连接速度: " << a.linkSpeed << L"\n";
                ss << L"\n=== Network ===\n";
                ss << L"IP 地址: " << a.ipAddress << L"\n";
                ss << L"网关: " << a.gateway << L"\n";
                ss << L"DNS: " << a.dnsServers << L"\n\n";

                if (!a.gateway.empty()) {
                    ss << L"=== Ping (gateway) ===\n";
                    double ping = NetworkOptimizationEngine::Instance().GetDiagnostic(a.name).pingMs;
                    ss << L"平均延迟: " << ping << L" ms\n\n";
                    double jitter = NetworkOptimizationEngine::Instance().GetDiagnostic(a.name).jitterMs;
                    ss << L"抖动: " << jitter << L" ms\n\n";
                }
            }

            ss << L"=== TCP 全局设置 ===\n";
            std::wstring tcpOut = RunCommand(L"netsh interface tcp show global", nullptr);
            ss << tcpOut << L"\n";

            ss << L"=== 注册表 TCP 参数 ===\n";
            const wchar_t* regProps[] = { L"TcpNoDelay", L"EnableTCPNoDelay", L"TcpAckFrequency", L"TcpDelAckTicks",
                L"Tcp1323Opts", L"SackOpts", L"DefaultSendWindow", L"DefaultReceiveWindow", L"MaxUserPort",
                L"TcpTimedWaitDelay", L"KeepAliveTime", L"DefaultTTL" };
            HKEY hKey;
            if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
                for (auto& prop : regProps) {
                    DWORD val = 0; DWORD size = sizeof(val); DWORD type = 0;
                    if (RegQueryValueExW(hKey, prop, nullptr, &type, (BYTE*)&val, &size) == ERROR_SUCCESS)
                        ss << prop << L" = " << val << L"\n";
                    else
                        ss << prop << L" = (default)\n";
                }
                RegCloseKey(hKey);
            }

            ss << L"\n=== 系统配置 ===\n";
            HKEY hKey2;
            if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", 0, KEY_READ, &hKey2) == ERROR_SUCCESS) {
                DWORD val = 0; DWORD size = sizeof(val);
                if (RegQueryValueExW(hKey2, L"NetworkThrottlingIndex", nullptr, nullptr, (BYTE*)&val, &size) == ERROR_SUCCESS)
                    ss << L"NetworkThrottlingIndex = " << val << L"\n";
                if (RegQueryValueExW(hKey2, L"SystemResponsiveness", nullptr, nullptr, (BYTE*)&val, &size) == ERROR_SUCCESS)
                    ss << L"SystemResponsiveness = " << val << L"\n";
                RegCloseKey(hKey2);
            }

            if (hText) SetWindowTextW(hText, ss.str().c_str());
            AddLog(L"INFO", L"诊断已完成");
        }).detach();
        return 0;
    }

    // Log export
    if (id == IDC_BTN_EXPORT_LOG) {
        wchar_t fileName[MAX_PATH];
        auto now = std::chrono::system_clock::now();
        auto t = std::chrono::system_clock::to_time_t(now);
        std::tm tm;
        localtime_s(&tm, &t);
        swprintf_s(fileName, L"ALit_NetworkOptimizer_Log_%04d%02d%02d_%02d%02d%02d.txt",
            tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);

        OPENFILENAMEW ofn = {};
        ofn.lStructSize = sizeof(ofn);
        ofn.hwndOwner = g_hMainWnd;
        ofn.lpstrFilter = L"文本文件 (*.txt)\0*.txt\0所有文件 (*.*)\0*.*\0";
        ofn.lpstrFile = fileName;
        ofn.nMaxFile = MAX_PATH;
        ofn.lpstrDefExt = L"txt";
        ofn.Flags = OFN_OVERWRITEPROMPT | OFN_PATHMUSTEXIST;

        if (GetSaveFileNameW(&ofn)) {
            std::wofstream f(fileName);
            if (f) {
                for (auto& entry : g_logEntries) f << entry << L"\r\n";
                f.close();
                AddLog(L"INFO", L"日志已导出到: " + std::wstring(fileName));
                MessageBoxW(g_hMainWnd, (L"日志已导出到:\n" + std::wstring(fileName)).c_str(), L"导出成功", MB_OK | MB_ICONINFORMATION);
            }
        }
        return 0;
    }

    if (id == IDC_BTN_CLEAR_LOG) {
        g_logEntries.clear();
        HWND hList = GetDlgItem(g_hPages[8], IDC_LOG_LIST);
        if (hList) ListBox_ResetContent(hList);
        return 0;
    }

    // Adapter deep test
    if (id == IDC_BTN_ADAPTER_DEEP) {
        std::thread([=]() {
            RunCommand(L"powershell -Command \"Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -TaskOffload Enabled\"", nullptr);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            for (auto& a : adapters) {
                std::wstring cmd = L"powershell -Command \"Enable-NetAdapterRss -Name '" + a.name + L"'\"";
                RunCommand(cmd, nullptr);
                cmd = L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Interrupt Moderation' -DisplayValue 'Disabled' -NoRestart\"";
                RunCommand(cmd, nullptr);
                cmd = L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -NoRestart\"";
                RunCommand(cmd, nullptr);
                cmd = L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Receive Buffers' -RegistryValue 4096 -NoRestart\"";
                RunCommand(cmd, nullptr);
                cmd = L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Transmit Buffers' -RegistryValue 4096 -NoRestart\"";
                RunCommand(cmd, nullptr);
            }
            AddLog(L"INFO", L"网卡深层优化已完成");
            MessageBoxW(g_hMainWnd, L"网卡深层优化已完成", L"完成", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    // Hosts optimize
    if (id == IDC_BTN_OPT_HOSTS) {
        std::thread([=]() {
            wchar_t sysDir[MAX_PATH];
            GetSystemDirectoryW(sysDir, MAX_PATH);
            std::wstring hostsPath = std::wstring(sysDir) + L"\\drivers\\etc\\hosts";
            std::wstring backupPath = hostsPath + L".bak";

            // Backup
            CopyFileW(hostsPath.c_str(), backupPath.c_str(), FALSE);

            // Read current hosts
            std::ifstream fin(hostsPath);
            std::string content((std::istreambuf_iterator<char>(fin)), std::istreambuf_iterator<char>());
            fin.close();

            // Add optimization entries
            content += "\n# === Network Optimizer Entries ===\n";
            content += "0.0.0.0 telemetry.minecraft.net\n";
            content += "0.0.0.0 vortex.data.microsoft.com\n";
            content += "0.0.0.0 telemetry.appex.bing.net\n";
            content += "0.0.0.0 settings-win.data.microsoft.com\n";

            std::ofstream fout(hostsPath, std::ios::trunc);
            fout << content;
            fout.close();

            AddLog(L"INFO", L"Hosts 文件已优化（添加屏蔽条目）");
            MessageBoxW(g_hMainWnd, L"Hosts 文件已优化\n已添加 Minecraft 遥测屏蔽条目\n原文件已备份为 hosts.bak", L"完成", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    // Hosts reset
    if (id == IDC_BTN_RESET_HOSTS) {
        wchar_t sysDir[MAX_PATH];
        GetSystemDirectoryW(sysDir, MAX_PATH);
        std::wstring hostsPath = std::wstring(sysDir) + L"\\drivers\\etc\\hosts";
        std::wstring backupPath = hostsPath + L".bak";

        if (PathFileExistsW(backupPath.c_str())) {
            CopyFileW(backupPath.c_str(), hostsPath.c_str(), FALSE);
            DeleteFileW(backupPath.c_str());
            AddLog(L"INFO", L"Hosts 文件已从备份还原");
            MessageBoxW(g_hMainWnd, L"Hosts 文件已从备份还原", L"完成", MB_OK | MB_ICONINFORMATION);
        } else {
            std::ofstream fout(hostsPath, std::ios::trunc);
            fout << "# Copyright (c) 1993-2006 Microsoft Corp.\n#\n# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.\n\n127.0.0.1       localhost\n::1             localhost\n";
            fout.close();
            AddLog(L"INFO", L"Hosts 文件已重置为默认");
            MessageBoxW(g_hMainWnd, L"Hosts 文件已重置为默认", L"完成", MB_OK | MB_ICONINFORMATION);
        }
        return 0;
    }

    // Sim apply (deep optimization checkboxes)
    if (id == IDC_BTN_SIM_APPLY) {
        std::thread([=]() {
            HWND hText = GetDlgItem(g_hPages[6], IDC_SIM_TEXT);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (adapters.empty()) {
                if (hText) SetWindowTextW(hText, L"未找到活动网络适配器");
                return;
            }
            std::wstring ifName = adapters[0].name;
            std::wstring result;

            // Check each checkbox
            HWND hChk;
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_QOS);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                NetworkOptimizationEngine::Instance().GetQoSManager().ApplyMinecraftPvPPresets();
                result += L"[OK] QoS 策略已应用\r\n";
            }
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_PROC);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                RunCommand(L"powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", nullptr);
                result += L"[OK] 进程优先级已设置为高性能\r\n";
            }
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_TIMER);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                RunCommand(L"bcdedit /set useplatformtick yes", nullptr);
                result += L"[OK] 系统定时器已优化\r\n";
            }
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_INTERRUPT);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                for (auto& a : adapters) {
                    std::wstring cmd = L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Interrupt Moderation' -DisplayValue 'Disabled' -NoRestart\"";
                    RunCommand(cmd, nullptr);
                }
                result += L"[OK] 中断调节已禁用\r\n";
            }
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_RSS);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                for (auto& a : adapters) {
                    std::wstring cmd = L"powershell -Command \"Enable-NetAdapterRss -Name '" + a.name + L"' -NoRestart\"";
                    RunCommand(cmd, nullptr);
                }
                result += L"[OK] RSS 已启用\r\n";
            }
            hChk = GetDlgItem(g_hPages[6], IDC_CHK_SIM_THROTTLE);
            if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                RunCommand(L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f", nullptr);
                result += L"[OK] 网络节流已关闭\r\n";
            }

            if (result.empty()) result = L"未选择任何优化项";
            if (hText) SetWindowTextW(hText, result.c_str());
            AddLog(L"INFO", L"深层优化已应用");
        }).detach();
        return 0;
    }

    // Sim restore
    if (id == IDC_BTN_SIM_RESTORE) {
        std::thread([=]() {
            HWND hText = GetDlgItem(g_hPages[6], IDC_SIM_TEXT);
            NetworkOptimizationEngine::Instance().GetQoSManager().RemoveAllAppPolicies();
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            for (auto& a : adapters) {
                NetworkOptimizationEngine::Instance().GetAdapterOptimizer().RevertOptimizations(a.name);
            }
            RunCommand(L"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f", nullptr);
            std::wstring result = L"[OK] QoS 策略已清除\r\n[OK] 网卡设置已还原\r\n[OK] 网络节流已恢复";
            if (hText) SetWindowTextW(hText, result.c_str());
            AddLog(L"INFO", L"深层优化已还原");
        }).detach();
        return 0;
    }

    // Sim status
    if (id == IDC_BTN_SIM_STATUS) {
        HWND hText = GetDlgItem(g_hPages[6], IDC_SIM_TEXT);
        std::wstring status;
        auto policies = NetworkOptimizationEngine::Instance().GetQoSManager().ListPolicies();
        status += L"=== QoS 策略 ===\r\n" + policies + L"\r\n";
        auto tcpSettings = NetworkOptimizationEngine::Instance().GetTcpOptimizer().GetCurrentTcpGlobalSettings();
        status += L"=== TCP 全局设置 ===\r\n" + tcpSettings;
        if (hText) SetWindowTextW(hText, status.c_str());
        return 0;
    }

    // MTU detect
    if (id == IDC_BTN_MTU_DETECT) {
        std::thread([=]() {
            HWND hResult = GetDlgItem(g_hPages[6], IDC_MTU_RESULT);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (adapters.empty()) {
                if (hResult) SetWindowTextW(hResult, L"未找到活动网络适配器");
                return;
            }
            std::wstring ifName = adapters[0].name;
            std::wstring gateway = adapters[0].gateway;
            if (gateway.empty()) gateway = L"8.8.8.8";

            uint32_t mtu = NetworkOptimizationEngine::Instance().GetDiagnostics().DetectOptimalMTU(gateway);
            g_detectedMtu = mtu;

            std::wstring msg = L"检测到最佳 MTU: " + std::to_wstring(mtu) + L"\r\n适配器: " + ifName + L"\r\n网关: " + gateway;
            if (hResult) SetWindowTextW(hResult, msg.c_str());
            AddLog(L"INFO", L"MTU 检测完成: " + std::to_wstring(mtu));
        }).detach();
        return 0;
    }

    // MTU apply
    if (id == IDC_BTN_MTU_APPLY) {
        std::thread([=]() {
            HWND hResult = GetDlgItem(g_hPages[6], IDC_MTU_RESULT);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (adapters.empty()) {
                if (hResult) SetWindowTextW(hResult, L"未找到活动网络适配器");
                return;
            }
            uint32_t mtu = g_detectedMtu > 0 ? g_detectedMtu : 1500;
            std::wstring ifName = adapters[0].name;
            auto result = NetworkOptimizationEngine::Instance().GetAdapterOptimizer().SetMTU(ifName, mtu);
            std::wstring msg = L"MTU 已设置为 " + std::to_wstring(mtu) + L"\r\n适配器: " + ifName;
            if (hResult) SetWindowTextW(hResult, msg.c_str());
            AddLog(L"INFO", L"MTU 已应用: " + std::to_wstring(mtu));
        }).detach();
        return 0;
    }

    // MTU restore
    if (id == IDC_BTN_MTU_RESTORE) {
        std::thread([=]() {
            HWND hResult = GetDlgItem(g_hPages[6], IDC_MTU_RESULT);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            if (!adapters.empty()) {
                NetworkOptimizationEngine::Instance().GetAdapterOptimizer().SetMTU(adapters[0].name, 1500);
            }
            if (hResult) SetWindowTextW(hResult, L"MTU 已恢复为 1500");
            AddLog(L"INFO", L"MTU 已恢复为 1500");
        }).detach();
        return 0;
    }

    // Accelerator detect
    if (id == IDC_BTN_ACCEL_DETECT) {
        std::thread([=]() {
            HWND hStatus = GetDlgItem(g_hPages[6], IDC_ACCEL_STATUS);
            std::wstring result;
            struct { const wchar_t* name; const wchar_t* process; } accelerators[] = {
                { L"UU加速器", L"UU.exe" },
                { L"雷神加速器", L"leishen.exe" },
                { L"迅游加速器", L"XunyouWan.exe" },
                { L"网易UU加速器", L"uu_pc.exe" },
                { L"奇游加速器", L"qiyou.exe" },
                { L"海豚加速器", L"dolphin.exe" },
                { L"steam加速器", L"steam.exe" },
            };
            bool found = false;
            for (auto& acc : accelerators) {
                std::wstring cmd = L"tasklist /FI \"IMAGENAME eq " + std::wstring(acc.process) + L"\"";
                std::wstring output = RunCommand(cmd, nullptr);
                if (output.find(acc.process) != std::wstring::npos) {
                    result += L"[检测到] " + std::wstring(acc.name) + L" (" + std::wstring(acc.process) + L")\r\n";
                    found = true;
                }
            }
            if (!found) result = L"未检测到运行中的加速器";
            if (hStatus) SetWindowTextW(hStatus, result.c_str());
            AddLog(L"INFO", L"加速器检测完成");
        }).detach();
        return 0;
    }

    // Accelerator apply
    if (id == IDC_BTN_ACCEL_APPLY) {
        HWND hChk = GetDlgItem(g_hPages[6], IDC_CHK_ACCEL_COMPAT);
        bool compat = (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED);
        std::thread([=]() {
            // Add QoS policies that also cover accelerator processes
            auto& qos = NetworkOptimizationEngine::Instance().GetQoSManager();
            std::wstring accelApps[] = { L"javaw.exe", L"UU.exe", L"leishen.exe", L"XunyouWan.exe", L"steam.exe" };
            for (auto& app : accelApps) {
                std::wstring policyName = L"Accel_" + app;
                qos.AddAppPolicy(policyName, app, 46, L"none");
            }
            // Also add port-based policies for common game ports
            qos.AddPortPolicy(L"Accel_MC_Port", 25565, 46, L"none");
            qos.AddPortPolicy(L"Accel_Steam", 27015, 46, L"none");

            HWND hStatus = GetDlgItem(g_hPages[6], IDC_ACCEL_STATUS);
            std::wstring msg = compat ? L"加速器兼容模式已启用\r\n已为加速器进程添加 QoS 策略\r\nDSCP=46 (EF)" : L"已为游戏和加速器进程添加 QoS 策略";
            if (hStatus) SetWindowTextW(hStatus, msg.c_str());
            AddLog(L"INFO", L"加速器兼容优化已应用");
        }).detach();
        return 0;
    }

    // Driver check
    if (id == IDC_BTN_DRV_CHECK) {
        std::thread([=]() {
            HWND hList = GetDlgItem(g_hPages[6], IDC_DRV_LIST);
            if (hList) SendMessageW(hList, LB_RESETCONTENT, 0, 0);
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            for (auto& a : adapters) {
                auto props = NetworkOptimizationEngine::Instance().GetAdapterOptimizer().GetAdvancedProperties(a.name);
                std::wstring item = L"[" + a.name + L"] " + a.description;
                if (hList) SendMessageW(hList, LB_ADDSTRING, 0, (LPARAM)item.c_str());
                for (auto& p : props) {
                    std::wstring line = L"  " + p.displayName + L" = " + p.currentValue;
                    if (hList) SendMessageW(hList, LB_ADDSTRING, 0, (LPARAM)line.c_str());
                }
            }
            AddLog(L"INFO", L"驱动信息已刷新");
        }).detach();
        return 0;
    }

    // Driver optimize
    if (id == IDC_BTN_DRV_OPTIMIZE) {
        std::thread([=]() {
            auto adapters = NetworkOptimizationEngine::Instance().GetActiveAdapters();
            for (auto& a : adapters) {
                HWND hChk;
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_RSS);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED)
                    NetworkOptimizationEngine::Instance().GetAdapterOptimizer().SetRSS(a.name, true);
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_POWER);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED)
                    NetworkOptimizationEngine::Instance().GetAdapterOptimizer().DisablePowerManagement(a.name);
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_ENERGY);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -NoRestart\"", nullptr);
                }
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_GREEN);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Green Ethernet' -DisplayValue 'Disabled' -NoRestart\"", nullptr);
                }
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_POWERMODE);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c", nullptr);
                }
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_ULTRA);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100", nullptr);
                    RunCommand(L"powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100", nullptr);
                }
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_INTERRUPT);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED)
                    NetworkOptimizationEngine::Instance().GetAdapterOptimizer().SetInterruptModeration(a.name, false);
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_FLOW);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"powershell -Command \"Set-NetAdapterAdvancedProperty -Name '" + a.name + L"' -DisplayName 'Flow Control' -DisplayValue 'Disabled' -NoRestart\"", nullptr);
                }
                hChk = GetDlgItem(g_hPages[6], IDC_CHK_DRV_REGECO);
                if (hChk && SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED) {
                    RunCommand(L"reg add \"HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power\" /v EnergyEfficientEthernet /t REG_DWORD /d 0 /f", nullptr);
                }
            }
            // Apply power scheme
            RunCommand(L"powercfg /setactive SCHEME_CURRENT", nullptr);
            AddLog(L"INFO", L"驱动参数优化已应用");
            MessageBoxW(g_hMainWnd, L"驱动参数优化已应用", L"完成", MB_OK | MB_ICONINFORMATION);
        }).detach();
        return 0;
    }

    // Settings - autostart toggle
    if (id == IDC_CHK_AUTOSTART) {
        HWND hChk = GetDlgItem(g_hPages[9], IDC_CHK_AUTOSTART);
        bool checked = (SendMessageW(hChk, BM_GETCHECK, 0, 0) == BST_CHECKED);
        HKEY hKey;
        wchar_t exePath[MAX_PATH];
        GetModuleFileNameW(nullptr, exePath, MAX_PATH);
        if (checked) {
            RegCreateKeyExW(HKEY_CURRENT_USER, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr);
            RegSetValueExW(hKey, L"ALitNetworkOptimizer", 0, REG_SZ, (BYTE*)exePath, (wcslen(exePath) + 1) * sizeof(wchar_t));
            RegCloseKey(hKey);
            AddLog(L"INFO", L"已设置开机自启");
        } else {
            RegCreateKeyExW(HKEY_CURRENT_USER, L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 0, nullptr, 0, KEY_SET_VALUE, nullptr, &hKey, nullptr);
            RegDeleteValueW(hKey, L"ALitNetworkOptimizer");
            RegCloseKey(hKey);
            AddLog(L"INFO", L"已取消开机自启");
        }
        return 0;
    }

    return 0;
}

// ========== WINDOW PROCEDURE ==========
LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
        case WM_ERASEBKGND: {
            HDC hdc = (HDC)wParam;
            RECT rc;
            GetClientRect(hWnd, &rc);
            static HBRUSH hbrMain = CreateSolidBrush(COL_BG);
            FillRect(hdc, &rc, hbrMain);
            return 1;
        }
        case WM_CREATE: {
            // Create fonts
            g_hFontMain = CreateFontHelper(13);
            g_hFontTitle = CreateFontHelper(24, true);
            g_hFontSmall = CreateFontHelper(10);
            g_hFontMono = CreateFontHelper(13, false, FONT_MONO);
            g_hFontLarge = CreateFontHelper(18, true);
            g_hFontBold = CreateFontHelper(14, true);

            // Create title bar
            CreateLabel(hWnd, L"ALit-网络优化工具V3  Minecraft PvP 网络优化", 20, 8, 700, 24, COL_TEXT, 13, true);
            HWND btnMin = CreateDarkButton(hWnd, IDC_BTN_MINIMIZE, L"—", 940, 4, 30, 26, COL_MIN_BG, COL_TEXT);
            SetWindowSubclass(btnMin, ButtonSubclassProc, 0, 0);
            HWND btnClose = CreateDarkButton(hWnd, IDC_BTN_CLOSE, L"✕", 972, 4, 24, 26, COL_CLOSE_BG, COL_CLOSE_FG);
            SetWindowSubclass(btnClose, ButtonSubclassProc, 0, 0);

            // Create sidebar
            CreateSidebar(hWnd);

            // Register dark page class
            RegisterDarkPageClass();

            // Create pages (in content area)
            HWND hContent = CreateWindowExW(0, L"DarkPage", L"", WS_CHILD | WS_VISIBLE, 220, 36, 780, 644, hWnd, nullptr, g_hInst, nullptr);
            // Set content background
            // Create all pages as children of hContent
            CreateDashboardPage(hContent);
            CreateTcpPage(hContent);
            CreateDnsPage(hContent);
            CreateQosPage(hContent);
            CreateHostsPage(hContent);
            CreateCustomPage(hContent);
            CreateTestPage(hContent);
            CreateDiagPage(hContent);
            CreateLogPage(hContent);
            CreateSettingsPage(hContent);

            // Show only the first page
            for (int i = 0; i < 10; i++) {
                if (g_hPages[i]) ShowWindow(g_hPages[i], i == 0 ? SW_SHOW : SW_HIDE);
            }

            // Update sidebar status
            auto* engine = &NetworkOptimizationEngine::Instance();
            bool ok = engine->IsOptimized();
            HWND hStatus = GetDlgItem(hWnd, IDC_SIDEBAR_STATUS);
            if (hStatus) SetWindowTextW(hStatus, ok ? L"已优化" : L"未优化");

            // Initialize GDI+
            Gdiplus::GdiplusStartupInput gdiplusStartupInput;
            ULONG_PTR gdiplusToken;
            Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

            break;
        }
        case WM_COMMAND: {
            return HandleCommand(wParam, lParam);
        }
        case WM_DRAWITEM: {
            LPDRAWITEMSTRUCT dis = (LPDRAWITEMSTRUCT)lParam;
            if (!dis) break;
            return DefWindowProcW(hWnd, message, wParam, lParam);
        }
        case WM_CTLCOLORBTN: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            static HBRUSH hbrBtn = CreateSolidBrush(COL_BG);
            return (LRESULT)hbrBtn;
        }
        case WM_CTLCOLORSTATIC: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            static HBRUSH hbrStatic = CreateSolidBrush(COL_BG);
            return (LRESULT)hbrStatic;
        }
        case WM_CTLCOLOREDIT: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            static HBRUSH hbrEdit = CreateSolidBrush(COL_TEXTBOX_BG);
            return (LRESULT)hbrEdit;
        }
        case WM_CTLCOLORLISTBOX: {
            HDC hdc = (HDC)wParam;
            SetTextColor(hdc, COL_TEXT);
            SetBkMode(hdc, TRANSPARENT);
            static HBRUSH hbrList = CreateSolidBrush(COL_TEXTBOX_BG);
            return (LRESULT)hbrList;
        }
        case WM_SIZE: {
            // Optionally resize content area
            break;
        }
        case WM_GETMINMAXINFO: {
            MINMAXINFO* mmi = (MINMAXINFO*)lParam;
            mmi->ptMaxTrackSize.x = 1000;
            mmi->ptMaxTrackSize.y = 720;
            mmi->ptMinTrackSize.x = 1000;
            mmi->ptMinTrackSize.y = 720;
            break;
        }
        case WM_NCHITTEST: {
            // Allow dragging from the title bar area
            LRESULT hit = DefWindowProcW(hWnd, message, wParam, lParam);
            if (hit == HTCLIENT) {
                POINT pt;
                pt.x = GET_X_LPARAM(lParam);
                pt.y = GET_Y_LPARAM(lParam);
                ScreenToClient(hWnd, &pt);
                if (pt.y < 36 && pt.x < 930) return HTCAPTION;
            }
            return hit;
        }
        case WM_DESTROY: {
            // Stop threads
            if (g_wdRunning.load()) {
                g_wdRunning = false;
                if (g_wdThread.joinable()) g_wdThread.detach();
            }
            if (g_bwRunning.load()) {
                g_bwRunning = false;
                if (g_bwThread.joinable()) g_bwThread.detach();
            }
            // Unload WinDivert
            if (g_wdDll) {
                FreeLibrary(g_wdDll);
                g_wdDll = nullptr;
            }
            // Delete fonts
            if (g_hFontMain) DeleteObject(g_hFontMain);
            if (g_hFontTitle) DeleteObject(g_hFontTitle);
            if (g_hFontSmall) DeleteObject(g_hFontSmall);
            if (g_hFontMono) DeleteObject(g_hFontMono);
            if (g_hFontLarge) DeleteObject(g_hFontLarge);
            if (g_hFontBold) DeleteObject(g_hFontBold);
            PostQuitMessage(0);
            break;
        }
        default:
            return DefWindowProcW(hWnd, message, wParam, lParam);
    }
    return 0;
}

// ========== WINMAIN ==========
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow) {
    // Initialize common controls
    INITCOMMONCONTROLSEX icc;
    icc.dwSize = sizeof(icc);
    icc.dwICC = ICC_STANDARD_CLASSES | ICC_PROGRESS_CLASS | ICC_BAR_CLASSES | ICC_LISTVIEW_CLASSES;
    InitCommonControlsEx(&icc);

    // Enable DPI awareness
    SetProcessDPIAware();

    g_hInst = hInstance;

    // Register window class
    const wchar_t* CLASS_NAME = L"ALitNetworkOptimizerV3";
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = CreateSolidBrush(COL_BG);
    wc.hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(1));
    wc.style = CS_HREDRAW | CS_VREDRAW;

    if (!RegisterClassExW(&wc)) {
        MessageBoxW(nullptr, L"窗口类注册失败", L"错误", MB_OK | MB_ICONERROR);
        return 1;
    }

    // Create main window - centered, no resize
    int sw = GetSystemMetrics(SM_CXSCREEN);
    int sh = GetSystemMetrics(SM_CYSCREEN);
    int wndW = 1000;
    int wndH = 720;
    int x = (sw - wndW) / 2;
    int y = (sh - wndH) / 2;

    g_hMainWnd = CreateWindowExW(
        0, CLASS_NAME, L"ALit-网络优化工具V3",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        x, y, wndW, wndH,
        nullptr, nullptr, hInstance, nullptr
    );

    if (!g_hMainWnd) {
        MessageBoxW(nullptr, L"窗口创建失败", L"错误", MB_OK | MB_ICONERROR);
        return 1;
    }

    ShowWindow(g_hMainWnd, nCmdShow);
    UpdateWindow(g_hMainWnd);

    // Message loop
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        if (!IsDialogMessageW(g_hMainWnd, &msg)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

    return (int)msg.wParam;
}