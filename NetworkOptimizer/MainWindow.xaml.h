#pragma once
#include "MainWindow.g.h"

namespace winrt::NetworkOptimizer::implementation
{
    struct MainWindow : MainWindowT<MainWindow>
    {
        MainWindow();

        // Navigation
        void NavView_SelectionChanged(
            winrt::Microsoft::UI::Xaml::Controls::NavigationView const& sender,
            winrt::Microsoft::UI::Xaml::Controls::NavigationViewSelectionChangedEventArgs const& args);

        // Dashboard
        void QuickOptimize_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RevertAll_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void SpeedTest_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RefreshStatus_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // TCP/IP
        void ApplyTcp_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RevertTcp_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RefreshTcp_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // DNS
        void ApplyDns_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RestoreDns_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void FlushDns_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void BenchmarkDns_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // QoS
        void ApplyQoS_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RemoveQoS_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RefreshQoS_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // Adapter
        void AdapterSelector_SelectionChanged(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::Controls::SelectionChangedEventArgs const& e);
        void OptimizeAdapter_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RevertAdapter_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // Diagnostics
        void MonitorToggle_Toggled(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void RunDiagnostic_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // Profiles
        void LoadProfile_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void DeleteProfile_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);
        void SaveProfile_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

        // Log
        void ClearLog_Click(
            winrt::Windows::Foundation::IInspectable const& sender,
            winrt::Microsoft::UI::Xaml::RoutedEventArgs const& e);

    private:
        // UI helpers
        void ShowPanel(winrt::hstring tag);
        void PopulateInterfaceSelector();
        void PopulateTcpItems();
        void PopulateDnsPresets();
        void PopulateQoSPresets();
        void PopulateProfiles();
        void PopulateAdapterInfo(const std::wstring& adapterName);
        void RefreshDashboard();
        void RefreshDnsInfo();
        void AddLogEntry(const std::wstring& level, const std::wstring& message);
        void UpdateStatusBadge(bool optimized);
        void AddInfoRow(
            winrt::Microsoft::UI::Xaml::Controls::StackPanel const& parent,
            const std::wstring& key, const std::wstring& value);
        void AddActivityItem(const std::wstring& message, bool success);

        // Get currently selected interface name
        std::wstring GetSelectedInterface() const;

        // Engine reference
        NetOpt::NetworkOptimizationEngine& m_engine;

        // Selected DNS preset index
        int m_selectedDnsPreset = 0;

        // Bandwidth monitor
        std::atomic<bool> m_monitoring{ false };
        std::thread m_monitorThread;
    };
}
