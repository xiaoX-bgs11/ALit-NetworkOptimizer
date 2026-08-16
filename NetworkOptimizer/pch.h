#pragma once

// Windows headers
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <unknwn.h>
#include <shellapi.h>
#include <combaseapi.h>

// C++ standard library
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <algorithm>
#include <sstream>
#include <fstream>
#include <thread>
#include <atomic>
#include <mutex>
#include <chrono>
#include <cstdint>

// C++/WinRT
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>

// WinUI 3 (Windows App SDK)
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Data.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Navigation.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>

// Windowing
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.UI.Interop.h>

// WIL (Windows Implementation Library)
#include <wil/cppwinrt.h>
#include <wil/resource.h>

// Project core headers
#include "core/Types.h"
#include "core/CommandRunner.h"
#include "core/TcpOptimizer.h"
#include "core/DnsOptimizer.h"
#include "core/QoSManager.h"
#include "core/AdapterOptimizer.h"
#include "core/NetworkDiagnostics.h"
#include "core/ProfileManager.h"
#include "core/NetworkOptimizationEngine.h"
