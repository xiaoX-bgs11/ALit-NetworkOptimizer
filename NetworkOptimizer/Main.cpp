#include "pch.h"
#include "App.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;

// WinUI 3 unpackaged app entry point
int __stdcall wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    init_apartment(apartment_type::single_threaded);
    Application::Start([](auto&&) {
        make<winrt::NetworkOptimizer::implementation::App>();
    });
    return 0;
}
