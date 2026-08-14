#include "pch.h"
#include "MainWindow.xaml.h"
#include <winrt/Microsoft.UI.Dispatching.h>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Microsoft::UI::Xaml::Media;
using namespace Windows::UI;
using namespace Windows::Foundation;

namespace winrt::NetworkOptimizer::implementation
{
    // ================================================================
    // Helper: create colors and brushes
    // ================================================================
    static SolidColorBrush MakeBrush(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255) {
        Color c;
        c.A = a; c.R = r; c.G = g; c.B = b;
        return SolidColorBrush(c);
    }

    static TextBlock MakeTextBlock(const std::wstring& text, uint8_t r, uint8_t g, uint8_t b,
                                    double fontSize = 13, bool bold = false) {
        TextBlock tb;
        tb.Text(text);
        tb.FontSize(fontSize);
        tb.Foreground(MakeBrush(r, g, b));
        if (bold) tb.FontWeight(Windows::UI::Text::FontWeight{ 600 });
        tb.TextWrapping(TextWrapping::Wrap);
        return tb;
    }

    // ================================================================
    // Constructor
    // ================================================================
    MainWindow::MainWindow()
        : m_engine(NetOpt::NetworkOptimizationEngine::Instance())
    {
        InitializeComponent();

        // Set up logging callback
        m_engine.SetLogCallback([this](const NetOpt::LogEntry& entry) {
            auto dispatcher = DispatcherQueue::GetForCurrentThread();
            if (dispatcher) {
                dispatcher.TryEnqueue([this, entry]() {
                    AddLogEntry(entry.level, entry.message);
                });
            }
        });

        // Check admin status
        if (!m_engine.IsAdmin()) {
            // Could show a warning, but the manifest requires admin
        }

        // Populate UI
        PopulateInterfaceSelector();
        PopulateTcpItems();
        PopulateDnsPresets();
        PopulateQoSPresets();
        PopulateProfiles();

        // Initial refresh
        RefreshDashboard();
    }

    // ================================================================
    // Navigation
    // ================================================================
    void MainWindow::NavView_SelectionChanged(
        NavigationView const&, NavigationViewSelectionChangedEventArgs const& args)
    {
        auto item = args.SelectedItemItem().try_as<NavigationViewItem>();
        if (!item) return;

        auto tag = item.Tag().as<hstring>();
        ShowPanel(tag);
    }

    void MainWindow::ShowPanel(hstring tag) {
        DashboardPanel().Visibility(tag == L"Dashboard" ? Visibility::Visible : Visibility::Collapsed);
        TcpPanel().Visibility(tag == L"Tcp" ? Visibility::Visible : Visibility::Collapsed);
        DnsPanel().Visibility(tag == L"Dns" ? Visibility::Visible : Visibility::Collapsed);
        QosPanel().Visibility(tag == L"Qos" ? Visibility::Visible : Visibility::Collapsed);
        AdapterPanel().Visibility(tag == L"Adapter" ? Visibility::Visible : Visibility::Collapsed);
        DiagPanel().Visibility(tag == L"Diag" ? Visibility::Visible : Visibility::Collapsed);
        ProfilesPanel().Visibility(tag == L"Profiles" ? Visibility::Visible : Visibility::Collapsed);
        LogPanel().Visibility(tag == L"Log" ? Visibility::Visible : Visibility::Collapsed);

        if (tag == L"Dns") RefreshDnsInfo();
        if (tag == L"Qos") RefreshQoS_Click(nullptr, nullptr);
        if (tag == L"Tcp") RefreshTcp_Click(nullptr, nullptr);
    }

    // ================================================================
    // Dashboard
    // ================================================================
    std::wstring MainWindow::GetSelectedInterface() const {
        auto sel = InterfaceSelector().SelectedItem();
        if (!sel) return L"";
        auto box = sel.try_as<ComboBoxItem>();
        if (box) return box.Content().as<hstring>().c_str();
        return sel.as<hstring>().c_str();
    }

    fire_and_forget MainWindow::QuickOptimize_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto interfaceName = GetSelectedInterface();
        if (interfaceName.empty()) {
            // Try to get primary adapter
            auto adapter = m_engine.GetPrimaryAdapter();
            interfaceName = adapter.name;
        }
        if (interfaceName.empty()) {
            AddLogEntry(L"WARN", L"No network interface selected");
            co_return;
        }

        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        // Show progress
        dispatcher.TryEnqueue([weak]() {
            if (auto self = weak.get()) {
                self->OptimizeProgressPanel().Visibility(Visibility::Visible);
                self->QuickOptimizeButton().IsEnabled(false);
                self->OptimizeProgressText().Text(L"Starting optimization...");
            }
        });

        // Run optimization on background thread
        co_await winrt::resume_background();

        auto summary = m_engine.ApplyAllOptimizations(NetOpt::OptLevel::Gaming,
            interfaceName,
            [weak, dispatcher](const std::wstring& name, int pct) {
                dispatcher.TryEnqueue([weak, name, pct]() {
                    if (auto self = weak.get()) {
                        self->OptimizeProgressText().Text(name);
                        self->OptimizeProgress().SetValue(ProgressBar::ValueProperty(),
                            winrt::box_value((double)pct));
                    }
                });
            });

        // Update UI on main thread
        co_await winrt::resume_foreground(dispatcher);

        OptimizeProgressPanel().Visibility(Visibility::Collapsed);
        QuickOptimizeButton().IsEnabled(true);

        // Show results
        ActiveOptList().Children().Clear();
        for (const auto& msg : summary.successMessages) {
            AddActivityItem(msg, true);
        }
        for (const auto& msg : summary.failureMessages) {
            AddActivityItem(msg, false);
        }

        UpdateStatusBadge(summary.failureCount == 0);
        AddLogEntry(L"INFO", L"Optimization complete: " +
            std::to_wstring(summary.successCount) + L"/" +
            std::to_wstring(summary.totalItems) + L" succeeded");

        RefreshDashboard();
    }

    fire_and_forget MainWindow::RevertAll_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto interfaceName = GetSelectedInterface();
        if (interfaceName.empty()) {
            auto adapter = m_engine.GetPrimaryAdapter();
            interfaceName = adapter.name;
        }

        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        dispatcher.TryEnqueue([weak]() {
            if (auto self = weak.get()) {
                self->OptimizeProgressPanel().Visibility(Visibility::Visible);
                self->QuickOptimizeButton().IsEnabled(false);
                self->OptimizeProgressText().Text(L"Reverting...");
            }
        });

        co_await winrt::resume_background();

        auto summary = m_engine.RevertAllOptimizations(NetOpt::OptLevel::Gaming,
            interfaceName, nullptr);

        co_await winrt::resume_foreground(dispatcher);

        OptimizeProgressPanel().Visibility(Visibility::Collapsed);
        QuickOptimizeButton().IsEnabled(true);

        ActiveOptList().Children().Clear();
        for (const auto& msg : summary.successMessages) {
            AddActivityItem(msg, true);
        }

        UpdateStatusBadge(false);
        AddLogEntry(L"INFO", L"All optimizations reverted");
        RefreshDashboard();
    }

    fire_and_forget MainWindow::SpeedTest_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        SpeedTestProgressPanel().Visibility(Visibility::Visible);
        SpeedTestButton().IsEnabled(false);
        SpeedTestProgressText().Text(L"Measuring ping...");
        SpeedTestResults().Visibility(Visibility::Collapsed);

        co_await winrt::resume_background();

        dispatcher.TryEnqueue([weak]() {
            if (auto self = weak.get()) {
                self->SpeedTestProgressText().Text(L"Testing download speed...");
            }
        });

        auto result = m_engine.RunSpeedTest();

        co_await winrt::resume_foreground(dispatcher);

        SpeedTestProgressPanel().Visibility(Visibility::Collapsed);
        SpeedTestButton().IsEnabled(true);
        SpeedTestResults().Visibility(Visibility::Visible);

        TestPingLabel().Text(L"Ping: " + std::to_wstring((int)result.pingMs) + L" ms");
        TestDownloadLabel().Text(L"Download: " + std::to_wstring((int)result.downloadMbps) + L" Mbps");
        TestUploadLabel().Text(L"Upload: " + std::to_wstring((int)result.uploadMbps) + L" Mbps");

        PingValue().Text(std::to_wstring((int)result.pingMs));
        DownloadValue().Text(std::to_wstring((int)result.downloadMbps));
        UploadValue().Text(std::to_wstring((int)result.uploadMbps));

        AddLogEntry(L"INFO", L"Speed test: DL=" + std::to_wstring((int)result.downloadMbps) +
            L" Mbps, UL=" + std::to_wstring((int)result.uploadMbps) +
            L" Mbps, Ping=" + std::to_wstring((int)result.pingMs) + L" ms");
    }

    fire_and_forget MainWindow::RefreshStatus_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        co_await winrt::resume_background();
        co_await winrt::resume_foreground(dispatcher);

        RefreshDashboard();
    }

    void MainWindow::RefreshDashboard() {
        auto adapters = m_engine.GetActiveAdapters();
        if (!adapters.empty()) {
            auto& adapter = adapters[0];
            if (!adapter.gateway.empty()) {
                double ping = m_engine.GetDiagnostics().MeasurePing(adapter.gateway, 3);
                PingValue().Text(ping > 0 ? std::to_wstring((int)ping) : L"--");
            }
        }
    }

    // ================================================================
    // TCP/IP
    // ================================================================
    void MainWindow::PopulateTcpItems() {
        TcpItemsList().Children().Clear();

        auto items = m_engine.GetTcpOptimizer().GetOptimizationItems(NetOpt::OptLevel::Gaming);
        for (const auto& item : items) {
            // Create a card for each item
            auto card = Border();
            card.Background(MakeBrush(15, 52, 96)); // #0F3460
            card.CornerRadius(RadiusHelper::FromValue(6));
            card.Padding(ThicknessHelper::FromUniforms(12));

            auto panel = StackPanel();
            panel.Spacing(4);

            // Title row
            auto titleGrid = Grid();
            auto col1 = ColumnDefinition();
            col1.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
            auto col2 = ColumnDefinition();
            col2.Width(GridLengthHelper::FromValueAndType(0, GridUnitType::Auto));

            auto title = MakeTextBlock(item.displayName, 224, 224, 224, 14, true);
            Grid::SetColumn(title, 0);

            std::wstring catName;
            switch (item.category) {
                case NetOpt::OptCategory::TcpStack: catName = L"TCP Stack"; break;
                case NetOpt::OptCategory::RegistryTcp: catName = L"Registry"; break;
                case NetOpt::OptCategory::SystemProfile: catName = L"System"; break;
                default: catName = L"Other"; break;
            }
            auto badge = Border();
            badge.Background(MakeBrush(26, 26, 46));
            badge.CornerRadius(RadiusHelper::FromValue(4));
            badge.Padding(ThicknessHelper::FromUniforms(6));
            auto badgeText = MakeTextBlock(catName, 158, 158, 158, 11);
            badge.Child(badgeText);
            Grid::SetColumn(badge, 1);

            titleGrid.ColumnDefinitions().Append(col1);
            titleGrid.ColumnDefinitions().Append(col2);
            titleGrid.Children().Append(title);
            titleGrid.Children().Append(badge);

            panel.Children().Append(titleGrid);
            panel.Children().Append(MakeTextBlock(item.description, 158, 158, 158, 12));

            card.Child(panel);
            TcpItemsList().Children().Append(card);
        }
    }

    fire_and_forget MainWindow::ApplyTcp_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        int levelIdx = TcpLevelSelector().SelectedIndex();
        auto level = levelIdx == 0 ? NetOpt::OptLevel::Gaming :
                     levelIdx == 1 ? NetOpt::OptLevel::Balanced :
                     NetOpt::OptLevel::Bandwidth;

        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        TcpProgress().Visibility(Visibility::Visible);
        ApplyTcpButton().IsEnabled(false);

        co_await winrt::resume_background();

        auto results = m_engine.GetTcpOptimizer().ApplyAll(level,
            [weak, dispatcher](const std::wstring& name, int pct) {
                dispatcher.TryEnqueue([weak, name, pct]() {
                    if (auto self = weak.get()) {
                        self->TcpProgress().Value(pct);
                    }
                });
            });

        int success = 0;
        for (const auto& r : results) if (r.success) success++;

        co_await winrt::resume_foreground(dispatcher);

        TcpProgress().Visibility(Visibility::Collapsed);
        ApplyTcpButton().IsEnabled(true);

        AddLogEntry(L"INFO", L"TCP optimization: " + std::to_wstring(success) +
            L"/" + std::to_wstring(results.size()) + L" items applied");
        RefreshTcp_Click(nullptr, nullptr);
    }

    fire_and_forget MainWindow::RevertTcp_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        int levelIdx = TcpLevelSelector().SelectedIndex();
        auto level = levelIdx == 0 ? NetOpt::OptLevel::Gaming :
                     levelIdx == 1 ? NetOpt::OptLevel::Balanced :
                     NetOpt::OptLevel::Bandwidth;

        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        TcpProgress().Visibility(Visibility::Visible);
        RevertTcpButton().IsEnabled(false);

        co_await winrt::resume_background();

        m_engine.GetTcpOptimizer().RevertAll(level, nullptr);

        co_await winrt::resume_foreground(dispatcher);

        TcpProgress().Visibility(Visibility::Collapsed);
        RevertTcpButton().IsEnabled(true);

        AddLogEntry(L"INFO", L"TCP optimizations reverted");
        RefreshTcp_Click(nullptr, nullptr);
    }

    fire_and_forget MainWindow::RefreshTcp_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        co_await winrt::resume_background();

        auto settings = m_engine.GetTcpOptimizer().GetCurrentTcpGlobalSettings();

        co_await winrt::resume_foreground(dispatcher);
        TcpSettingsText().Text(settings.empty() ? L"Unable to retrieve settings" : settings);
    }

    // ================================================================
    // DNS
    // ================================================================
    void MainWindow::PopulateDnsPresets() {
        DnsPresetList().Children().Clear();

        auto presets = m_engine.GetDnsOptimizer().GetPresetProfiles();
        int idx = 0;
        for (const auto& preset : presets) {
            auto rb = RadioButton();
            rb.GroupName(L"DnsPreset");
            rb.Tag(box_value(hstring(preset.name)));
            rb.Checked([this, idx](IInspectable const&, RoutedEventArgs const&) {
                m_selectedDnsPreset = idx;
            });

            auto panel = StackPanel();
            panel.Spacing(2);
            panel.Children().Append(MakeTextBlock(preset.name, 224, 224, 224, 14, true));
            panel.Children().Append(MakeTextBlock(preset.description, 158, 158, 158, 12));
            auto detail = MakeTextBlock(preset.primary + L" / " + preset.secondary, 0, 230, 118, 12);
            detail.FontFamily(Media::FontFamily(L"Consolas"));
            panel.Children().Append(detail);

            rb.Content(panel);
            DnsPresetList().Children().Append(rb);
            idx++;
        }
    }

    void MainWindow::RefreshDnsInfo() {
        auto sel = DnsInterfaceSelector().SelectedItem();
        if (!sel) return;
        std::wstring ifaceName;
        auto box = sel.try_as<ComboBoxItem>();
        if (box) ifaceName = box.Content().as<hstring>().c_str();
        else ifaceName = sel.as<hstring>().c_str();

        if (ifaceName.empty()) return;

        auto dns = m_engine.GetDnsOptimizer().GetCurrentDns(ifaceName);
        CurrentDnsText().Text(dns.empty() ? L"Not configured" : dns);
    }

    fire_and_forget MainWindow::ApplyDns_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto sel = DnsInterfaceSelector().SelectedItem();
        if (!sel) { AddLogEntry(L"WARN", L"Select a network interface first"); co_return; }

        std::wstring ifaceName;
        auto box = sel.try_as<ComboBoxItem>();
        if (box) ifaceName = box.Content().as<hstring>().c_str();
        else ifaceName = sel.as<hstring>().c_str();

        auto presets = m_engine.GetDnsOptimizer().GetPresetProfiles();
        if (m_selectedDnsPreset >= (int)presets.size()) co_return;

        auto& preset = presets[m_selectedDnsPreset];
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        co_await winrt::resume_background();

        auto result = m_engine.GetDnsOptimizer().ApplyPreset(ifaceName, preset);

        co_await winrt::resume_foreground(dispatcher);

        AddLogEntry(result.success ? L"INFO" : L"ERROR",
            L"DNS preset '" + preset.name + L"': " + result.message);
        RefreshDnsInfo();
    }

    fire_and_forget MainWindow::RestoreDns_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto sel = DnsInterfaceSelector().SelectedItem();
        if (!sel) co_return;
        std::wstring ifaceName;
        auto box = sel.try_as<ComboBoxItem>();
        if (box) ifaceName = box.Content().as<hstring>().c_str();
        else ifaceName = sel.as<hstring>().c_str();

        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        co_await winrt::resume_background();
        auto result = m_engine.GetDnsOptimizer().RestoreDns(ifaceName);
        co_await winrt::resume_foreground(dispatcher);

        AddLogEntry(result.success ? L"INFO" : L"ERROR", L"DNS restored: " + result.message);
        RefreshDnsInfo();
    }

    fire_and_forget MainWindow::FlushDns_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        co_await winrt::resume_background();
        auto result = m_engine.FlushDns();
        co_await winrt::resume_foreground(dispatcher);
        AddLogEntry(result.success ? L"INFO" : L"ERROR", L"DNS cache: " + result.message);
    }

    fire_and_forget MainWindow::BenchmarkDns_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        DnsBenchmarkResults().Children().Clear();
        DnsBenchmarkResults().Children().Append(MakeTextBlock(L"Running benchmark...", 158, 158, 158, 12));

        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        co_await winrt::resume_background();

        std::vector<std::pair<std::wstring, std::wstring>> servers = {
            { L"Cloudflare", L"1.1.1.1" },
            { L"Google", L"8.8.8.8" },
            { L"114 DNS", L"114.114.114.114" },
            { L"AliDNS", L"223.5.5.5" },
            { L"DNSPod", L"119.29.29.29" },
        };

        auto results = m_engine.GetDnsOptimizer().BenchmarkDns(servers);

        co_await winrt::resume_foreground(dispatcher);

        DnsBenchmarkResults().Children().Clear();
        for (const auto& r : results) {
            auto grid = Grid();
            auto col1 = ColumnDefinition();
            col1.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
            auto col2 = ColumnDefinition();
            col2.Width(GridLengthHelper::FromValueAndType(0, GridUnitType::Auto));
            grid.ColumnDefinitions().Append(col1);
            grid.ColumnDefinitions().Append(col2);

            auto name = MakeTextBlock(r.server + L" (" + r.ip + L")", 224, 224, 224, 12);
            Grid::SetColumn(name, 0);

            std::wstring latencyStr = r.success ?
                std::to_wstring(r.latencyMs) + L" ms" : L"Timeout";
            auto latency = MakeTextBlock(latencyStr,
                r.success ? 0 : 239, r.success ? 230 : 83, r.success ? 118 : 80, 12, true);
            Grid::SetColumn(latency, 1);

            grid.Children().Append(name);
            grid.Children().Append(latency);
            DnsBenchmarkResults().Children().Append(grid);
        }
    }

    // ================================================================
    // QoS
    // ================================================================
    void MainWindow::PopulateQoSPresets() {
        QoSPresetList().Children().Clear();

        auto presets = m_engine.GetQoSManager().GetPresets();
        for (const auto& preset : presets) {
            auto card = Border();
            card.Background(MakeBrush(15, 52, 96));
            card.CornerRadius(RadiusHelper::FromValue(6));
            card.Padding(ThicknessHelper::FromUniforms(10));

            auto panel = StackPanel();
            panel.Spacing(2);
            panel.Children().Append(MakeTextBlock(preset.name, 224, 224, 224, 13, true));
            panel.Children().Append(MakeTextBlock(preset.description, 158, 158, 158, 12));

            card.Child(panel);
            QoSPresetList().Children().Append(card);
        }
    }

    fire_and_forget MainWindow::ApplyQoS_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        ApplyQoSButton().IsEnabled(false);

        co_await winrt::resume_background();

        auto results = m_engine.GetQoSManager().ApplyMinecraftPvPPresets();

        int success = 0;
        for (const auto& r : results) if (r.success) success++;

        co_await winrt::resume_foreground(dispatcher);
        ApplyQoSButton().IsEnabled(true);

        AddLogEntry(L"INFO", L"QoS: " + std::to_wstring(success) +
            L"/" + std::to_wstring(results.size()) + L" policies applied");
        RefreshQoS_Click(nullptr, nullptr);
    }

    fire_and_forget MainWindow::RemoveQoS_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        RemoveQoSButton().IsEnabled(false);

        co_await winrt::resume_background();
        auto result = m_engine.GetQoSManager().RemoveAllAppPolicies();
        co_await winrt::resume_foreground(dispatcher);
        RemoveQoSButton().IsEnabled(true);

        AddLogEntry(result.success ? L"INFO" : L"ERROR", L"QoS: " + result.message);
        RefreshQoS_Click(nullptr, nullptr);
    }

    fire_and_forget MainWindow::RefreshQoS_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        co_await winrt::resume_background();
        auto policies = m_engine.GetQoSManager().ListPolicies();
        co_await winrt::resume_foreground(dispatcher);
        QoSPolicyText().Text(policies.empty() ? L"No policies found" : policies);
    }

    // ================================================================
    // Adapter
    // ================================================================
    void MainWindow::PopulateInterfaceSelector() {
        auto adapters = m_engine.GetActiveAdapters();
        for (const auto& adapter : adapters) {
            ComboBoxItem item;
            item.Content(box_value(hstring(adapter.name)));
            InterfaceSelector().Items().Append(item);

            ComboBoxItem dnsItem;
            dnsItem.Content(box_value(hstring(adapter.name)));
            DnsInterfaceSelector().Items().Append(dnsItem);

            ComboBoxItem adaptItem;
            adaptItem.Content(box_value(hstring(adapter.name)));
            AdapterSelector().Items().Append(adaptItem);
        }

        if (!adapters.empty()) {
            InterfaceSelector().SelectedIndex(0);
            DnsInterfaceSelector().SelectedIndex(0);
            AdapterSelector().SelectedIndex(0);
        }
    }

    void MainWindow::AdapterSelector_SelectionChanged(
        IInspectable const&, Controls::SelectionChangedEventArgs const&)
    {
        auto sel = AdapterSelector().SelectedItem();
        if (!sel) return;
        auto box = sel.try_as<ComboBoxItem>();
        if (!box) return;
        auto name = box.Content().as<hstring>().c_str();
        PopulateAdapterInfo(name);
    }

    void MainWindow::PopulateAdapterInfo(const std::wstring& adapterName) {
        AdapterInfoList().Children().Clear();

        auto adapters = m_engine.GetActiveAdapters();
        for (const auto& adapter : adapters) {
            if (adapter.name != adapterName) continue;

            AddInfoRow(AdapterInfoList(), L"Name", adapter.name);
            AddInfoRow(AdapterInfoList(), L"Description", adapter.description);
            AddInfoRow(AdapterInfoList(), L"IP Address", adapter.ipAddress);
            AddInfoRow(AdapterInfoList(), L"Gateway", adapter.gateway);
            AddInfoRow(AdapterInfoList(), L"DNS Servers", adapter.dnsServers);
            AddInfoRow(AdapterInfoList(), L"MAC Address", adapter.macAddress);
            AddInfoRow(AdapterInfoList(), L"Link Speed",
                std::to_wstring(adapter.linkSpeed) + L" Mbps");
            AddInfoRow(AdapterInfoList(), L"MTU", std::to_wstring(adapter.mtu));
            break;
        }
    }

    fire_and_forget MainWindow::OptimizeAdapter_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto sel = AdapterSelector().SelectedItem();
        if (!sel) co_return;
        auto box = sel.try_as<ComboBoxItem>();
        if (!box) co_return;
        auto name = box.Content().as<hstring>();

        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        AdapterProgress().Visibility(Visibility::Visible);
        OptimizeAdapterButton().IsEnabled(false);

        co_await winrt::resume_background();

        auto results = m_engine.GetAdapterOptimizer().ApplyGamingOptimizations(
            name.c_str(), nullptr);

        int success = 0;
        for (const auto& r : results) if (r.success) success++;

        co_await winrt::resume_foreground(dispatcher);

        AdapterProgress().Visibility(Visibility::Collapsed);
        OptimizeAdapterButton().IsEnabled(true);

        AddLogEntry(L"INFO", L"Adapter optimized: " + std::to_wstring(success) +
            L"/" + std::to_wstring(results.size()) + L" succeeded");
    }

    fire_and_forget MainWindow::RevertAdapter_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto sel = AdapterSelector().SelectedItem();
        if (!sel) co_return;
        auto box = sel.try_as<ComboBoxItem>();
        if (!box) co_return;
        auto name = box.Content().as<hstring>();

        auto dispatcher = DispatcherQueue::GetForCurrentThread();
        AdapterProgress().Visibility(Visibility::Visible);
        RevertAdapterButton().IsEnabled(false);

        co_await winrt::resume_background();
        m_engine.GetAdapterOptimizer().RevertOptimizations(name.c_str(), nullptr);
        co_await winrt::resume_foreground(dispatcher);

        AdapterProgress().Visibility(Visibility::Collapsed);
        RevertAdapterButton().IsEnabled(true);
        AddLogEntry(L"INFO", L"Adapter settings reverted");
    }

    // ================================================================
    // Diagnostics
    // ================================================================
    void MainWindow::MonitorToggle_Toggled(
        IInspectable const&, RoutedEventArgs const&)
    {
        if (MonitorToggle().IsOn()) {
            m_monitoring = true;
            auto sel = InterfaceSelector().SelectedItem();
            std::wstring ifaceName;
            if (sel) {
                auto box = sel.try_as<ComboBoxItem>();
                if (box) ifaceName = box.Content().as<hstring>().c_str();
            }
            if (ifaceName.empty()) {
                auto adapter = m_engine.GetPrimaryAdapter();
                ifaceName = adapter.name;
            }

            m_monitorThread = std::thread([this, ifaceName]() {
                m_engine.GetDiagnostics().StartBandwidthMonitor(
                    ifaceName,
                    [this](const NetOpt::BandwidthSample& sample) {
                        if (!m_monitoring) return;
                        auto dispatcher = DispatcherQueue::GetForCurrentThread();
                        if (dispatcher) {
                            dispatcher.TryEnqueue([this, sample]() {
                                RealtimeDownload().Text(
                                    std::to_wstring(sample.downloadSpeed).substr(0, 5));
                                RealtimeUpload().Text(
                                    std::to_wstring(sample.uploadSpeed).substr(0, 5));
                                DownloadBar().Value(sample.downloadSpeed);
                                UploadBar().Value(sample.uploadSpeed);
                            });
                        }
                    },
                    1000);
            });
        } else {
            m_monitoring = false;
            m_engine.GetDiagnostics().StopBandwidthMonitor();
            if (m_monitorThread.joinable()) m_monitorThread.join();
        }
    }

    fire_and_forget MainWindow::RunDiagnostic_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto sel = InterfaceSelector().SelectedItem();
        std::wstring ifaceName;
        if (sel) {
            auto box = sel.try_as<ComboBoxItem>();
            if (box) ifaceName = box.Content().as<hstring>().c_str();
        }
        if (ifaceName.empty()) {
            auto adapter = m_engine.GetPrimaryAdapter();
            ifaceName = adapter.name;
        }

        auto weak = get_weak();
        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        DiagProgress().Visibility(Visibility::Visible);
        RunDiagnosticButton().IsEnabled(false);
        DiagResultsList().Children().Clear();
        DiagResultsList().Children().Append(MakeTextBlock(L"Running diagnostics...", 158, 158, 158, 12));

        co_await winrt::resume_background();

        auto diag = m_engine.GetDiagnostic(ifaceName);

        co_await winrt::resume_foreground(dispatcher);

        DiagProgress().Visibility(Visibility::Collapsed);
        RunDiagnosticButton().IsEnabled(true);
        DiagResultsList().Children().Clear();

        AddInfoRow(DiagResultsList(), L"Adapter", diag.adapterName);
        AddInfoRow(DiagResultsList(), L"IP Address", diag.ipAddress);
        AddInfoRow(DiagResultsList(), L"Gateway", diag.gateway);
        AddInfoRow(DiagResultsList(), L"Ping (gateway)",
            diag.pingMs > 0 ? std::to_wstring((int)diag.pingMs) + L" ms" : L"Failed");
        AddInfoRow(DiagResultsList(), L"Jitter",
            diag.jitterMs > 0 ? std::to_wstring((int)diag.jitterMs) + L" ms" : L"--");
        AddInfoRow(DiagResultsList(), L"Packet Loss",
            std::to_wstring(diag.packetLoss) + L"%");
        AddInfoRow(DiagResultsList(), L"MTU", std::to_wstring(diag.mtu));
        AddInfoRow(DiagResultsList(), L"Download (est.)",
            std::to_wstring((int)diag.downloadSpeed) + L" Mbps");
        AddInfoRow(DiagResultsList(), L"Upload (est.)",
            std::to_wstring((int)diag.uploadSpeed) + L" Mbps");
        AddInfoRow(DiagResultsList(), L"DNS Server", diag.dnsServer);
        AddInfoRow(DiagResultsList(), L"DNS Latency",
            diag.dnsLatencyMs > 0 ? std::to_wstring((int)diag.dnsLatencyMs) + L" ms" : L"--");

        AddLogEntry(L"INFO", L"Diagnostic complete");
    }

    // ================================================================
    // Profiles
    // ================================================================
    void MainWindow::PopulateProfiles() {
        ProfileList().Children().Clear();

        auto profiles = m_engine.GetProfileManager().ListProfiles();
        if (profiles.empty()) {
            ProfileList().Children().Append(MakeTextBlock(L"No saved profiles", 158, 158, 158, 13));
            return;
        }

        for (const auto& name : profiles) {
            auto rb = RadioButton();
            rb.GroupName(L"ProfileSelect");
            rb.Tag(box_value(hstring(name)));
            rb.Content(box_value(hstring(name)));
            ProfileList().Children().Append(rb);
        }
    }

    fire_and_forget MainWindow::LoadProfile_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        // Find selected profile
        std::wstring selectedProfile;
        for (auto child : ProfileList().Children()) {
            auto rb = child.try_as<RadioButton>();
            if (rb && rb.IsChecked().Value()) {
                selectedProfile = rb.Tag().as<hstring>().c_str();
                break;
            }
        }
        if (selectedProfile.empty()) {
            AddLogEntry(L"WARN", L"Select a profile first");
            co_return;
        }

        NetOpt::Profile profile;
        if (!m_engine.GetProfileManager().LoadProfile(selectedProfile, profile)) {
            AddLogEntry(L"ERROR", L"Failed to load profile: " + selectedProfile);
            co_return;
        }

        auto ifaceName = GetSelectedInterface();
        if (ifaceName.empty()) {
            auto adapter = m_engine.GetPrimaryAdapter();
            ifaceName = adapter.name;
        }

        auto dispatcher = DispatcherQueue::GetForCurrentThread();

        co_await winrt::resume_background();
        m_engine.ApplyAllOptimizations(profile.level, ifaceName, nullptr);
        co_await winrt::resume_foreground(dispatcher);

        AddLogEntry(L"INFO", L"Profile loaded: " + selectedProfile);
        UpdateStatusBadge(true);
    }

    void MainWindow::DeleteProfile_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        std::wstring selectedProfile;
        for (auto child : ProfileList().Children()) {
            auto rb = child.try_as<RadioButton>();
            if (rb && rb.IsChecked().Value()) {
                selectedProfile = rb.Tag().as<hstring>().c_str();
                break;
            }
        }
        if (selectedProfile.empty()) {
            AddLogEntry(L"WARN", L"Select a profile first");
            return;
        }

        if (m_engine.GetProfileManager().DeleteProfile(selectedProfile)) {
            AddLogEntry(L"INFO", L"Profile deleted: " + selectedProfile);
            PopulateProfiles();
        } else {
            AddLogEntry(L"ERROR", L"Failed to delete profile");
        }
    }

    void MainWindow::SaveProfile_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        auto name = ProfileNameInput().Text();
        auto desc = ProfileDescInput().Text();
        if (name.empty()) {
            AddLogEntry(L"WARN", L"Enter a profile name");
            return;
        }

        int levelIdx = ProfileLevelSelector().SelectedIndex();
        auto level = levelIdx == 0 ? NetOpt::OptLevel::Gaming :
                     levelIdx == 1 ? NetOpt::OptLevel::Balanced :
                     NetOpt::OptLevel::Bandwidth;

        auto items = m_engine.GetTcpOptimizer().GetOptimizationItems(level);

        if (m_engine.GetProfileManager().SaveProfile(
            name.c_str(), desc.c_str(), level, items)) {
            AddLogEntry(L"INFO", L"Profile saved: " + std::wstring(name.c_str()));
            ProfileNameInput().Text(L"");
            ProfileDescInput().Text(L"");
            PopulateProfiles();
        } else {
            AddLogEntry(L"ERROR", L"Failed to save profile");
        }
    }

    // ================================================================
    // Log
    // ================================================================
    void MainWindow::ClearLog_Click(
        IInspectable const&, RoutedEventArgs const&)
    {
        LogList().Children().Clear();
    }

    void MainWindow::AddLogEntry(const std::wstring& level, const std::wstring& message) {
        auto grid = Grid();
        auto col1 = ColumnDefinition();
        col1.Width(GridLengthHelper::FromPixels(160));
        auto col2 = ColumnDefinition();
        col2.Width(GridLengthHelper::FromPixels(60));
        auto col3 = ColumnDefinition();
        col3.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
        grid.ColumnDefinitions().Append(col1);
        grid.ColumnDefinitions().Append(col2);
        grid.ColumnDefinitions().Append(col3);

        // Timestamp
        SYSTEMTIME st;
        GetLocalTime(&st);
        wchar_t timeBuf[64];
        swprintf_s(timeBuf, 64, L"%02d:%02d:%02d", st.wHour, st.wMinute, st.wSecond);

        auto timeTb = MakeTextBlock(timeBuf, 158, 158, 158, 11);
        timeTb.FontFamily(FontFamily(L"Consolas"));
        Grid::SetColumn(timeTb, 0);

        // Level
        uint8_t lr = 0, lg = 230, lb = 118;
        if (level == L"WARN") { lr = 255; lg = 183; lb = 77; }
        else if (level == L"ERROR") { lr = 239; lg = 83; lb = 80; }
        auto levelTb = MakeTextBlock(level, lr, lg, lb, 11, true);
        levelTb.FontFamily(FontFamily(L"Consolas"));
        Grid::SetColumn(levelTb, 1);

        // Message
        auto msgTb = MakeTextBlock(message, 224, 224, 224, 12);
        Grid::SetColumn(msgTb, 2);

        grid.Children().Append(timeTb);
        grid.Children().Append(levelTb);
        grid.Children().Append(msgTb);

        LogList().Children().Append(grid);

        // Limit log entries
        if (LogList().Children().Size() > 200) {
            LogList().Children().RemoveAt(0);
        }
    }

    // ================================================================
    // UI Helpers
    // ================================================================
    void MainWindow::UpdateStatusBadge(bool optimized) {
        if (optimized) {
            StatusDot().Fill(MakeBrush(0, 230, 118));
            StatusBadge().Text(L"Optimized");
        } else {
            StatusDot().Fill(MakeBrush(255, 183, 77));
            StatusBadge().Text(L"Not Optimized");
        }
    }

    void MainWindow::AddActivityItem(const std::wstring& message, bool success) {
        auto grid = Grid();
        auto col1 = ColumnDefinition();
        col1.Width(GridLengthHelper::FromPixels(20));
        auto col2 = ColumnDefinition();
        col2.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
        grid.ColumnDefinitions().Append(col1);
        grid.ColumnDefinitions().Append(col2);

        auto status = MakeTextBlock(success ? L"\u2713" : L"\u2717",
            success ? 0 : 239, success ? 230 : 83, success ? 118 : 80, 14, true);
        Grid::SetColumn(status, 0);

        auto msg = MakeTextBlock(message, 224, 224, 224, 12);
        Grid::SetColumn(msg, 1);

        grid.Children().Append(status);
        grid.Children().Append(msg);
        ActiveOptList().Children().Append(grid);
    }

    void MainWindow::AddInfoRow(
        StackPanel const& parent, const std::wstring& key, const std::wstring& value)
    {
        auto grid = Grid();
        auto col1 = ColumnDefinition();
        col1.Width(GridLengthHelper::FromPixels(180));
        auto col2 = ColumnDefinition();
        col2.Width(GridLengthHelper::FromValueAndType(1, GridUnitType::Star));
        grid.ColumnDefinitions().Append(col1);
        grid.ColumnDefinitions().Append(col2);

        auto keyTb = MakeTextBlock(key, 158, 158, 158, 13);
        Grid::SetColumn(keyTb, 0);

        auto valTb = MakeTextBlock(value.empty() ? L"--" : value, 224, 224, 224, 13);
        valTb.TextWrapping(TextWrapping::Wrap);
        Grid::SetColumn(valTb, 1);

        grid.Children().Append(keyTb);
        grid.Children().Append(valTb);
        parent.Children().Append(grid);
    }

} // namespace winrt::NetworkOptimizer::implementation
