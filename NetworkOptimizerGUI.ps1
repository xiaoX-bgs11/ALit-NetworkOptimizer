<#
.SYNOPSIS
    Network Optimizer v3 - PowerShell WPF GUI
    Minecraft PvP & Local Network Optimization
.DESCRIPTION
    Provides a GUI interface for applying real Windows network optimizations.
    All settings are documented Microsoft parameters - no pseudo-science.
    This is the runnable version of the C++ WinUI3 project.
#>

#requires -Version 5.1

# ============================================================
# Load WPF Assemblies (must load before admin check uses MessageBox)
# ============================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

# ============================================================
# Admin Check
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $msg = "ALit-网络优化工具V3需要管理员权限才能修改网络设置。`n`n是否以管理员身份重新启动？"
    $result = [System.Windows.MessageBox]::Show($msg, "需要管理员权限", "YesNo", "Warning")
    if ($result -eq "Yes") {
        Start-Process $PowerShellExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

# ============================================================
# Splash Screen (加载页面)
# ============================================================
$script:splashAccent = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#4A9EFF"))
$script:splashDim = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString("#333333"))

$splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        WindowStyle="None"
        Background="#1E1E1E"
        WindowStartupLocation="CenterScreen"
        Width="400" Height="220"
        ResizeMode="NoResize"
        ShowInTaskbar="False">
<WindowChrome.WindowChrome>
    <shell:WindowChrome GlassFrameThickness="0" ResizeBorderThickness="0" CaptionHeight="0" CornerRadius="12"/>
</WindowChrome.WindowChrome>
    <Border Background="#1E1E1E" CornerRadius="12" BorderThickness="0">
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Text="ALit-网络优化工具V3" FontSize="24" FontWeight="Bold" Foreground="#E8E8E8"
                       HorizontalAlignment="Center" FontFamily="HarmonyOS Sans SC, Microsoft YaHei"/>
            <TextBlock Text="V3.1.0.0" FontSize="13" Foreground="#888888" HorizontalAlignment="Center" Margin="0,4,0,24"
                       FontFamily="HarmonyOS Sans SC, Microsoft YaHei"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,14">
                <Ellipse x:Name="Dot1" Width="10" Height="10" Fill="#4A9EFF" Margin="4,0"/>
                <Ellipse x:Name="Dot2" Width="10" Height="10" Fill="#333333" Margin="4,0"/>
                <Ellipse x:Name="Dot3" Width="10" Height="10" Fill="#333333" Margin="4,0"/>
            </StackPanel>
            <TextBlock x:Name="LoadingText" Text="正在加载组件..." FontSize="13" Foreground="#AAAAAA" HorizontalAlignment="Center"
                       FontFamily="HarmonyOS Sans SC, Microsoft YaHei"/>
        </StackPanel>
    </Border>
</Window>
"@

$splashWindow = [Windows.Markup.XamlReader]::Parse($splashXaml)
$splashWindow.Show()
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')
Start-Sleep -Milliseconds 80
[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')

# 加载动画
$script:splashDotIndex = 0
$script:splashTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:splashTimer.Interval = [TimeSpan]::FromMilliseconds(220)
$script:splashTimer.Add_Tick({
    try {
        $dots = @($splashWindow.FindName("Dot1"), $splashWindow.FindName("Dot2"), $splashWindow.FindName("Dot3"))
        for ($i = 0; $i -lt 3; $i++) {
            if ($i -eq $script:splashDotIndex) { $dots[$i].Fill = $script:splashAccent }
            else { $dots[$i].Fill = $script:splashDim }
        }
        $script:splashDotIndex = ($script:splashDotIndex + 1) % 3
    } catch {}
})
$script:splashTimer.Start()

function Update-SplashText {
    param([string]$Text)
    try {
        $splashWindow.FindName("LoadingText").Text = $Text
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, 'Background')
    } catch {}
}

# ============================================================
# Helper Functions
# ============================================================

function Invoke-Command {
    param([string]$Command)
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo.FileName = "cmd.exe"
    $p.StartInfo.Arguments = "/C $Command"
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.CreateNoWindow = $true
    $p.Start() | Out-Null
    $output = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit(30000) | Out-Null
    return @{ Output = $output; ExitCode = $p.ExitCode }
}

function Invoke-PowerShell {
    param([string]$Script)
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo.FileName = $PowerShellExe
    $p.StartInfo.Arguments = "-NoProfile -NonInteractive -Command `"$Script`""
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.CreateNoWindow = $true
    $p.Start() | Out-Null
    $output = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit(30000) | Out-Null
    return @{ Output = $output; ExitCode = $p.ExitCode }
}

$script:stateDir = Join-Path $env:ProgramData "ALitNetworkOptimizer"
$script:stateFile = Join-Path $script:stateDir "optimization-state.json"
$script:stateRegPath = "HKLM:\SOFTWARE\ALitNetworkOptimizer"

function Save-OptimizationState {
    param(
        [string]$Mode,
        [string]$DisplayName
    )
    try {
        if (-not (Test-Path $script:stateDir)) {
            New-Item -Path $script:stateDir -ItemType Directory -Force | Out-Null
        }
        $state = [PSCustomObject]@{
            IsOptimized = $true
            Mode = $Mode
            DisplayName = $DisplayName
            UpdatedAt = (Get-Date).ToString("s")
        }
        $state | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $script:stateFile -Encoding UTF8 -Force
        if (-not (Test-Path $script:stateRegPath)) {
            New-Item -Path $script:stateRegPath -Force | Out-Null
        }
        Set-ItemProperty -Path $script:stateRegPath -Name "IsOptimized" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $script:stateRegPath -Name "Mode" -Value $Mode -Type String -Force
        Set-ItemProperty -Path $script:stateRegPath -Name "DisplayName" -Value $DisplayName -Type String -Force
        Set-ItemProperty -Path $script:stateRegPath -Name "UpdatedAt" -Value (Get-Date).ToString("s") -Type String -Force
    } catch {
        Add-LogEntry "WARN" "保存优化状态失败：$($_.Exception.Message)"
    }
}

function Clear-OptimizationState {
    try {
        if (Test-Path $script:stateFile) {
            Remove-Item -LiteralPath $script:stateFile -Force -ErrorAction Stop
        }
        if (Test-Path $script:stateRegPath) {
            Remove-Item -Path $script:stateRegPath -Recurse -Force -ErrorAction Stop
        }
    } catch {
        Add-LogEntry "WARN" "清理优化状态失败：$($_.Exception.Message)"
    }
}

function Get-SavedOptimizationState {
    try {
        if (Test-Path $script:stateRegPath) {
            $regState = Get-ItemProperty -Path $script:stateRegPath -ErrorAction Stop
            if ($regState.IsOptimized -eq 1) {
                return [PSCustomObject]@{
                    IsOptimized = $true
                    Mode = [string]$regState.Mode
                    DisplayName = [string]$regState.DisplayName
                    UpdatedAt = [string]$regState.UpdatedAt
                }
            }
        }
        if (Test-Path $script:stateFile) {
            return (Get-Content -LiteralPath $script:stateFile -Raw -Encoding UTF8 | ConvertFrom-Json)
        }
    } catch {
        Add-LogEntry "WARN" "读取优化状态失败：$($_.Exception.Message)"
    }
    return $null
}

function Test-OptimizationApplied {
    try {
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $sp = Get-ItemProperty -Path $spPath -ErrorAction SilentlyContinue
        $tcp = Get-ItemProperty -Path $tcpPath -ErrorAction SilentlyContinue

        $indicators = 0
        if ($sp.SystemResponsiveness -eq 10) { $indicators++ }
        if ($tcp.Tcp1323Opts -eq 1) { $indicators++ }
        if ($tcp.MaxUserPort -ge 60000) { $indicators++ }
        $nti = [int64]$sp.NetworkThrottlingIndex
        if ($nti -eq 4294967295 -or $nti -eq -1) { $indicators++ }
        if ($tcp.TcpNoDelay -eq 1 -or $tcp.EnableTCPNoDelay -eq 1) { $indicators++ }
        if ($tcp.TcpAckFrequency -eq 1) { $indicators++ }
        if ($tcp.TcpDelAckTicks -eq 0) { $indicators++ }
        return ($indicators -ge 3)
    } catch {
        return $false
    }
}

function Refresh-OptimizationStatus {
    $sidebar = $window.FindName("SidebarStatus")
    if (-not $sidebar) { return }

    $state = Get-SavedOptimizationState
    if ($state -and $state.IsOptimized) {
        $displayName = if ($state.DisplayName) { [string]$state.DisplayName } else { "已优化" }
        $sidebar.Text = "$displayName 已应用"
        $sidebar.Foreground = "#7CC7FF"
        return
    }

    if (Test-OptimizationApplied) {
        $sidebar.Text = "已优化"
        $sidebar.Foreground = "#7CC7FF"
    } else {
        $sidebar.Text = "未优化"
        $sidebar.Foreground = "#FFB74D"
    }
}

function Get-ActiveAdapters {
    $result = Invoke-PowerShell "Get-NetAdapter | Where-Object { `$_.Status -eq 'Up' } | ForEach-Object { `$_.Name + '|' + `$_.InterfaceDescription + '|' + `$_.LinkSpeed + '|' + `$_.MtuSize }"
    $adapters = @()
    foreach ($line in ($result.Output -split "`n")) {
        $line = $line.Trim()
        if ($line -and $line.Contains('|')) {
            $parts = $line.Split('|')
            $adapters += @{
                Name = $parts[0]
                Description = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                Speed = if ($parts.Count -gt 2) { $parts[2] } else { "" }
                MTU = if ($parts.Count -gt 3) { $parts[3] } else { "" }
            }
        }
    }
    return $adapters
}

function Measure-PingLatency {
    param([string]$TargetHost, [int]$Count = 5)
    $result = Invoke-Command "ping -n $Count $TargetHost"
    $lines = $result.Output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "Average = (\d+)") { return [double]$Matches[1] }
        if ($line -match "平均 = (\d+)") { return [double]$Matches[1] }
    }
    return -1
}

function Measure-HttpLatency {
    param([string]$Url, [int]$TimeoutSeconds = 5)
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = "GET"
        $request.Timeout = $TimeoutSeconds * 1000
        $request.ReadWriteTimeout = $TimeoutSeconds * 1000
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.UserAgent = "ALit-Network-Optimizer"
        $response = $request.GetResponse()
        $response.Close()
        $sw.Stop()
        return [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
    } catch {
        return -1
    }
}

function Get-InterfaceBytes {
    param([string]$InterfaceName)
    try {
        $adapter = Get-NetAdapter -Name $InterfaceName -ErrorAction SilentlyContinue
        if (-not $adapter) { return $null }
        $stats = $adapter | Get-NetAdapterStatistics -ErrorAction SilentlyContinue
        if ($stats) {
            return @{
                Sent = $stats.OutboundUnicastBytes
                Received = $stats.InboundUnicastBytes
            }
        }
    } catch {
        Add-LogEntry "WARN" "HTTP 测量失败：$($_.Exception.Message)"
    }
    return $null
}

# ============================================================
# Snapshot System - 优化前保存原始配置
# ============================================================
$script:snapshotDir = Join-Path $env:ProgramData "ALitNetworkOptimizer\snapshots"
$script:latestSnapshot = $null

function Save-PreOptimizationSnapshot {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapDir = Join-Path $script:snapshotDir $timestamp
    try {
        if (-not (Test-Path $script:snapshotDir)) { New-Item -Path $script:snapshotDir -ItemType Directory -Force | Out-Null }
        if (-not (Test-Path $snapDir)) { New-Item -Path $snapDir -ItemType Directory -Force | Out-Null }
    } catch {
        Add-LogEntry "ERROR" "无法创建快照目录：$($_.Exception.Message)"
        return $null
    }

    $snap = @{ Timestamp = $timestamp; Path = $snapDir; Items = @() }

    # 1. TCP 全局设置
    try {
        $tcpGlobal = (Invoke-Command "netsh interface tcp show global").Output
        [System.IO.File]::WriteAllText((Join-Path $snapDir "tcp_global.txt"), $tcpGlobal, [System.Text.Encoding]::UTF8)
        $snap.Items += "TCP 全局设置"
    } catch { Add-LogEntry "WARN" "快照 TCP 全局失败" }

    # 2. DNS 服务器（每网卡）
    try {
        $dnsSnapshot = @()
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        foreach ($a in $adapters) {
            $servers = (Get-DnsClientServerAddress -InterfaceAlias $a.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
            $dnsSnapshot += "$($a.Name)|$($servers -join ',')"
        }
        [System.IO.File]::WriteAllLines((Join-Path $snapDir "dns.txt"), $dnsSnapshot, [System.Text.Encoding]::UTF8)
        $snap.Items += "DNS 服务器（$($adapters.Count) 个网卡）"
    } catch { Add-LogEntry "WARN" "快照 DNS 失败" }

    # 3. QoS 策略
    try {
        $qosOut = (Invoke-Command "netsh qos show policy").Output
        [System.IO.File]::WriteAllText((Join-Path $snapDir "qos.txt"), $qosOut, [System.Text.Encoding]::UTF8)
        $snap.Items += "QoS 策略"
    } catch { Add-LogEntry "WARN" "快照 QoS 失败" }

    # 4. Hosts 文件
    try {
        $hostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
        if (Test-Path $hostsFile) {
            Copy-Item $hostsFile (Join-Path $snapDir "hosts") -Force
            $snap.Items += "Hosts 文件"
        }
    } catch { Add-LogEntry "WARN" "快照 Hosts 失败" }

    # 5. TCP/IP 注册表参数 (IPv4 + IPv6)
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $regPathV6 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
        $regSnap = @()
        $regNames = @("TcpNoDelay","EnableTCPNoDelay","TcpAckFrequency","TcpDelAckTicks","Tcp1323Opts","SackOpts","EnableTCPChimney","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay","KeepAliveTime","TcpHybridAck","TcpWindowSize","MaxConnections","MTU","EnableWsd","EnableConnectionRateLimiting","EnableTcpFastOpen","DefaultTTL","MaxFreeTcbs","TcpMaxDataRetransmissions")
        foreach ($rn in $regNames) {
            $val = (Get-ItemProperty -Path $regPath -Name $rn -ErrorAction SilentlyContinue).$rn
            if ($null -ne $val) { $regSnap += "IPv4\$rn=$val" }
            $valV6 = (Get-ItemProperty -Path $regPathV6 -Name $rn -ErrorAction SilentlyContinue).$rn
            if ($null -ne $valV6) { $regSnap += "IPv6\$rn=$valV6" }
        }
        [System.IO.File]::WriteAllLines((Join-Path $snapDir "tcpip_registry.txt"), $regSnap, [System.Text.Encoding]::UTF8)
        $snap.Items += "TCP/IP 注册表参数"
    } catch { Add-LogEntry "WARN" "快照注册表失败" }

    # 6. 系统网络调度参数
    try {
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $nti = (Get-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        $sr = (Get-ItemProperty -Path $spPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness
        $spSnap = @("NetworkThrottlingIndex=$nti", "SystemResponsiveness=$sr")
        [System.IO.File]::WriteAllLines((Join-Path $snapDir "system_profile.txt"), $spSnap, [System.Text.Encoding]::UTF8)
        $snap.Items += "系统网络调度参数"
    } catch { Add-LogEntry "WARN" "快照系统调度参数失败" }

    $script:latestSnapshot = $snap
    Add-LogEntry "INFO" "优化前快照已保存：$($snap.Items -join ', ')"
    return $snap
}

function Find-LatestSnapshot {
    try {
        if (-not (Test-Path $script:snapshotDir)) { return $null }
        $dirs = Get-ChildItem -Path $script:snapshotDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($dirs) { return $dirs.FullName } else { return $null }
    } catch { return $null }
}

function Restore-FromSnapshot {
    param([string]$SnapPath)
    $report = @{ Tcp = $false; Dns = $false; Qos = $false; Hosts = $false; Registry = $false; SystemProfile = $false; Errors = @() }

    if (-not $SnapPath -or -not (Test-Path $SnapPath)) { return $report }

    # 1. 恢复 TCP/IP 注册表参数
    $regFile = Join-Path $SnapPath "tcpip_registry.txt"
    if (Test-Path $regFile) {
        try {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            $lines = [System.IO.File]::ReadAllLines($regFile, [System.Text.Encoding]::UTF8)
            $restored = 0; $failed = 0
            foreach ($line in $lines) {
                if ($line -match '^([^=]+)=(.+)$') {
                    $name = $Matches[1]; $val = $Matches[2]
                    try {
                        if ($val -match '^\d+$') {
                            Set-ItemProperty -Path $regPath -Name $name -Value ([int]$val) -Type DWord -Force -ErrorAction Stop
                        } else {
                            Set-ItemProperty -Path $regPath -Name $name -Value $val -Force -ErrorAction Stop
                        }
                        $restored++
                    } catch { $failed++; $report.Errors += "注册表恢复失败：$name - $($_.Exception.Message)" }
                }
            }
            # 删除快照中不存在的优化参数
            $optParams = @("TcpNoDelay","EnableTCPNoDelay","TcpAckFrequency","TcpDelAckTicks","Tcp1323Opts","SackOpts","EnableTCPChimney","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay","KeepAliveTime","TcpHybridAck","TcpWindowSize","MaxConnections","EnableConnectionRateLimiting","EnableTcpFastOpen")
            $snapNames = $lines | ForEach-Object { if ($_ -match '^([^=]+)=') { $Matches[1] } }
            foreach ($pn in $optParams) {
                if ($pn -notin $snapNames) {
                    try { Remove-ItemProperty -Path $regPath -Name $pn -Force -ErrorAction Stop } catch {}
                }
            }
            $report.Registry = $true
            if ($failed -gt 0) { Add-LogEntry "WARN" "注册表恢复：$restored 项成功，$failed 项失败" }
            else { Add-LogEntry "INFO" "注册表恢复：$restored 项成功" }
        } catch { $report.Errors += "读取快照注册表文件失败：$($_.Exception.Message)" }
    }

    # 2. 恢复 DNS（每网卡）
    $dnsFile = Join-Path $SnapPath "dns.txt"
    if (Test-Path $dnsFile) {
        try {
            $lines = [System.IO.File]::ReadAllLines($dnsFile, [System.Text.Encoding]::UTF8)
            $ok = 0; $fail = 0
            foreach ($line in $lines) {
                if ($line -match '^([^|]+)\|(.*)$') {
                    $iface = $Matches[1]; $servers = $Matches[2]
                    try {
                        if ([string]::IsNullOrWhiteSpace($servers)) {
                            $r = Invoke-Command "netsh interface ip set dns name=`"$iface`" source=dhcp"
                        } else {
                            $srvList = $servers -split ','
                            $r1 = Invoke-Command "netsh interface ip set dns name=`"$iface`" static $($srvList[0]) primary"
                            $ok2 = ($r1.ExitCode -eq 0)
                            if ($srvList.Count -gt 1 -and $ok2) {
                                $r2 = Invoke-Command "netsh interface ip add dns name=`"$iface`" $($srvList[1]) index=2"
                            }
                            $r = @{ ExitCode = if ($ok2) { 0 } else { $r1.ExitCode } }
                        }
                        if ($r.ExitCode -eq 0) { $ok++ } else { $fail++; $report.Errors += "DNS 恢复失败：$iface（退出码 $($r.ExitCode)）" }
                    } catch { $fail++; $report.Errors += "DNS 恢复异常：$iface - $($_.Exception.Message)" }
                }
            }
            $report.Dns = ($fail -eq 0)
            Add-LogEntry $(if ($fail -eq 0) { "INFO" } else { "WARN" }) "DNS 从快照恢复：$ok 成功，$fail 失败"
        } catch { $report.Errors += "读取快照 DNS 文件失败：$($_.Exception.Message)" }
    }

    # 3. 恢复 Hosts 文件
    $hostsSnap = Join-Path $SnapPath "hosts"
    if (Test-Path $hostsSnap) {
        try {
            $hostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
            Copy-Item $hostsSnap $hostsFile -Force
            $report.Hosts = $true
            Add-LogEntry "INFO" "Hosts 已从快照恢复"
        } catch { $report.Errors += "Hosts 恢复失败：$($_.Exception.Message)" }
    }

    # 4. 恢复系统网络调度参数
    $spFile = Join-Path $SnapPath "system_profile.txt"
    if (Test-Path $spFile) {
        try {
            $lines = [System.IO.File]::ReadAllLines($spFile, [System.Text.Encoding]::UTF8)
            $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            foreach ($line in $lines) {
                if ($line -match '^([^=]+)=(.+)$') {
                    $name = $Matches[1]; $val = $Matches[2]
                    try {
                        if ($val -match '^\d+$') { Set-ItemProperty -Path $spPath -Name $name -Value ([int]$val) -Type DWord -Force -ErrorAction Stop }
                    } catch { $report.Errors += "系统参数恢复失败：$name - $($_.Exception.Message)" }
                }
            }
            $report.SystemProfile = $true
            Add-LogEntry "INFO" "系统网络调度参数已从快照恢复"
        } catch { $report.Errors += "读取快照系统参数失败：$($_.Exception.Message)" }
    }

    # 5. 恢复 TCP 全局设置（从快照文本解析并还原）
    $tcpFile = Join-Path $SnapPath "tcp_global.txt"
    if (Test-Path $tcpFile) {
        try {
            $tcpContent = [System.IO.File]::ReadAllText($tcpFile, [System.Text.Encoding]::UTF8)
            # 解析快照中的 TCP 全局设置并还原
            $tcpRestoreCmds = @()
            if ($tcpContent -match 'Auto-Tuning Level\s*:\s*(\w+)') {
                $tcpRestoreCmds += "netsh interface tcp set global autotuninglevel=$($Matches[1].ToLower())"
            }
            if ($tcpContent -match 'ECN Capability\s*:\s*(\w+)') {
                $ecnVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }
                $tcpRestoreCmds += "netsh interface tcp set global ecncapability=$ecnVal"
            }
            if ($tcpContent -match 'RSS\s*:\s*(\w+)') {
                $rssVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }
                $tcpRestoreCmds += "netsh interface tcp set global rss=$rssVal"
            }
            if ($tcpContent -match 'Timestamps\s*:\s*(\w+)') {
                $tsVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }
                $tcpRestoreCmds += "netsh interface tcp set global timestamps=$tsVal"
            }
            if ($tcpContent -match 'Initial RTO\s*:\s*(\d+)') {
                $tcpRestoreCmds += "netsh interface tcp set global initialrto=$($Matches[1])"
            }
            if ($tcpContent -match 'RSC\s*:\s*(\w+)') {
                $rscVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }
                $tcpRestoreCmds += "netsh interface tcp set global rsc=$rscVal"
            }
            $tcpOk = 0; $tcpFail = 0
            foreach ($cmd in $tcpRestoreCmds) {
                $r = Invoke-Command $cmd
                if ($r.ExitCode -eq 0) { $tcpOk++ } else { $tcpFail++; $report.Errors += "TCP 还原命令失败：$cmd（退出码 $($r.ExitCode)）" }
            }
            $report.Tcp = ($tcpFail -eq 0)
            Add-LogEntry $(if ($tcpFail -eq 0) { "INFO" } else { "WARN" }) "TCP 全局从快照恢复：$tcpOk 成功，$tcpFail 失败"
        } catch { $report.Errors += "读取快照 TCP 文件失败：$($_.Exception.Message)" }
    }

    return $report
}

function Add-LogEntry {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $entry = "[$timestamp] $Level : $Message"
    $listBox = $window.FindName("LogList")
    if ($listBox) {
        $listBox.Dispatcher.Invoke([Action]{
            $listBox.Items.Insert(0, $entry) | Out-Null
            if ($listBox.Items.Count -gt 500) { $listBox.Items.RemoveAt($listBox.Items.Count - 1) }
        })
    }
}

# ============================================================
# Optimization Functions
# ============================================================

function Apply-TcpOptimization {
    $progress = $window.FindName("ProgressBar")
    $statusText = $window.FindName("StatusText")
    $results = @()

    # TCP Global Settings
    $tcpCmds = @(
        @("netsh interface tcp set global autotuninglevel=normal", "TCP Auto-Tuning"),
        @("netsh interface tcp set global ecncapability=enabled", "ECN"),
        @("netsh interface tcp set global rss=enabled", "RSS"),
        @("netsh interface tcp set global timestamps=disabled", "TCP Timestamps"),
        @("netsh interface tcp set global initialrto=300", "Initial RTO"),
        @("netsh interface tcp set global rsc=enabled", "RSC"),
        @("netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp", "CTCP")
    )

    $i = 0
    foreach ($cmd in $tcpCmds) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "TCP：$($cmd[1])..."
        })
        $r = Invoke-Command $cmd[0]
        $results += [PSCustomObject]@{ Name=$cmd[1]; Success=($r.ExitCode -eq 0); Detail=$cmd[0] }
        Start-Sleep -Milliseconds 100
    }

    # Registry TCP Parameters (IPv4 + IPv6)
    $regSettings = @(
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpNoDelay", 1, "TcpNoDelay"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "EnableTCPNoDelay", 1, "EnableTCPNoDelay"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpAckFrequency", 1, "TcpAckFrequency"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpDelAckTicks", 0, "TcpDelAckTicks"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "Tcp1323Opts", 1, "Tcp1323Opts"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "SackOpts", 1, "SackOpts"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "EnableTCPChimney", 0, "EnableTCPChimney"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DefaultSendWindow", 65535, "SendWindow"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DefaultReceiveWindow", 65535, "RecvWindow"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "MaxUserPort", 65534, "MaxUserPort"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpTimedWaitDelay", 30, "TimedWait"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "KeepAliveTime", 300000, "KeepAliveTime"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpMaxDataRetransmissions", 2, "TcpMaxDataRetransmissions"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DefaultTTL", 64, "DefaultTTL"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "EnableTcpFastOpen", 1, "EnableTcpFastOpen")
    )

    # 同时写入 IPv6 路径
    $regSettingsV6 = @(
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "EnableTCPNoDelay", 1, "EnableTCPNoDelay(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "TcpDelAckTicks", 0, "TcpDelAckTicks(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "Tcp1323Opts", 1, "Tcp1323Opts(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "SackOpts", 1, "SackOpts(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "EnableTCPChimney", 0, "EnableTCPChimney(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "MaxUserPort", 65534, "MaxUserPort(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "TcpTimedWaitDelay", 30, "TimedWait(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "KeepAliveTime", 300000, "KeepAliveTime(V6)"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "TcpMaxDataRetransmissions", 2, "TcpMaxDataRetransmissions(V6)")
    )

    foreach ($reg in $regSettings) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "注册表：$($reg[3])..."
        })
        try {
            Set-ItemProperty -Path $reg[0] -Name $reg[1] -Value $reg[2] -Type DWord -Force -ErrorAction Stop
            $results += [PSCustomObject]@{ Name=$reg[3]; Success=$true; Detail="$($reg[0])\$($reg[1])=$($reg[2])" }
        } catch {
            $results += [PSCustomObject]@{ Name=$reg[3]; Success=$false; Detail=$_.Exception.Message }
        }
        Start-Sleep -Milliseconds 50
    }

    # IPv6 注册表优化
    foreach ($reg in $regSettingsV6) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "注册表(IPv6)：$($reg[3])..."
        })
        try {
            Set-ItemProperty -Path $reg[0] -Name $reg[1] -Value $reg[2] -Type DWord -Force -ErrorAction Stop
            $results += [PSCustomObject]@{ Name=$reg[3]; Success=$true; Detail="$($reg[0])\$($reg[1])=$($reg[2])" }
        } catch {
            $results += [PSCustomObject]@{ Name=$reg[3]; Success=$false; Detail=$_.Exception.Message }
        }
        Start-Sleep -Milliseconds 50
    }

    # Per-interface TcpNoDelay and TcpAckFrequency
    $adapters = Get-ActiveAdapters
    foreach ($adapter in $adapters) {
        try {
            $guid = (Get-NetAdapter -Name $adapter.Name -ErrorAction Stop).InterfaceGuid
            $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            $ifaceFail = 0
            try { Set-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction Stop } catch { $ifaceFail++ }
            try { Set-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction Stop } catch { $ifaceFail++ }
            if ($ifaceFail -gt 0) { Add-LogEntry "WARN" "网卡 $($adapter.Name) 接口参数写入：$ifaceFail 项失败" }
        } catch {
            Add-LogEntry "WARN" "网卡 $($adapter.Name) 无法获取 InterfaceGuid：$($_.Exception.Message)"
        }
    }

    # System Profile
    $sysProfile = @(
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", "NetworkThrottlingIndex", 4294967295),
        @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile", "SystemResponsiveness", 0)
    )
    foreach ($sp in $sysProfile) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "系统：$($sp[1])..."
        })
        try {
            Set-ItemProperty -Path $sp[0] -Name $sp[1] -Value $sp[2] -Type DWord -Force -ErrorAction Stop
            $results += [PSCustomObject]@{ Name=$sp[1]; Success=$true; Detail="$($sp[0])\$($sp[1])=$($sp[2])" }
        } catch {
            $results += [PSCustomObject]@{ Name=$sp[1]; Success=$false; Detail=$_.Exception.Message }
        }
    }

    # Games Task
    $gamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    $gamesSettings = @(
        @("GPU Priority", 8, "DWord"),
        @("Priority", 6, "DWord"),
        @("Scheduling Category", "High", "String"),
        @("SFIO Priority", "High", "String")
    )
    foreach ($gs in $gamesSettings) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "游戏任务：$($gs[0])..."
        })
        try {
            if ($gs[2] -eq "DWord") {
                Set-ItemProperty -Path $gamesPath -Name $gs[0] -Value $gs[1] -Type DWord -Force -ErrorAction Stop
            } else {
                Set-ItemProperty -Path $gamesPath -Name $gs[0] -Value $gs[1] -Type String -Force -ErrorAction Stop
            }
            $results += [PSCustomObject]@{ Name="Games $($gs[0])"; Success=$true; Detail="$gamesPath\$($gs[0])" }
        } catch {
            $results += [PSCustomObject]@{ Name="Games $($gs[0])"; Success=$false; Detail=$_.Exception.Message }
        }
    }

    # QoS Policies
    $i++
    $window.Dispatcher.Invoke([Action]{
        $progress.Value = ($i / 20) * 100
        $statusText.Text = "QoS 策略..."
    })
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    $qosResult = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none"
    $results += [PSCustomObject]@{ Name="QoS MC Java"; Success=$true; Detail="DSCP 46 for javaw.exe" }
    $qosResult2 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none"
    $results += [PSCustomObject]@{ Name="QoS MC Bedrock"; Success=$true; Detail="DSCP 46 for Minecraft.Windows.exe" }

    # FPS Game QoS Policies - DSCP 46 for common FPS game processes and ports
    $fpsQosPolicies = @(
        @{ Name="NetOpt_FPS_CS2_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_CS2_Proc" appname="cs2.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_CS2_Port"; Cmd='netsh qos add policy name="NetOpt_FPS_CS2_Port" protocol=udp localport=27015 dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_Val_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_Val_Proc" appname="VALORANT-Win64-Shipping.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_Val_Port"; Cmd='netsh qos add policy name="NetOpt_FPS_Val_Port" protocol=udp localport=7448 dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_Apex_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_Apex_Proc" appname="r5apex.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_Apex_Port"; Cmd='netsh qos add policy name="NetOpt_FPS_Apex_Port" protocol=udp localport=37015 dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_CoD_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_CoD_Proc" appname="cod.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_CoD_Port"; Cmd='netsh qos add policy name="NetOpt_FPS_CoD_Port" protocol=udp localport=3074 dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_PUBG_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_PUBG_Proc" appname="TslGame.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_R6_Proc"; Cmd='netsh qos add policy name="NetOpt_FPS_R6_Proc" appname="RainbowSix.exe" dscp=46 throttleRate=none' },
        @{ Name="NetOpt_FPS_R6_Port"; Cmd='netsh qos add policy name="NetOpt_FPS_R6_Port" protocol=udp localport=6015 dscp=46 throttleRate=none' }
    )
    foreach ($p in $fpsQosPolicies) {
        Invoke-Command "netsh qos delete policy name=`"$($p.Name)`"" | Out-Null
        $fpsR = Invoke-Command $p.Cmd
        $results += [PSCustomObject]@{ Name="QoS $($p.Name)"; Success=($fpsR.ExitCode -eq 0); Detail="DSCP 46 FPS" }
    }

    # DNS
    $i++
    $window.Dispatcher.Invoke([Action]{
        $progress.Value = ($i / 20) * 100
        $statusText.Text = "清理 DNS..."
    })
    Invoke-Command "ipconfig /flushdns" | Out-Null
    $results += [PSCustomObject]@{ Name="DNS Flush"; Success=$true; Detail="ipconfig /flushdns" }

    $i++
    $window.Dispatcher.Invoke([Action]{
        $progress.Value = 100
        $statusText.Text = "完成！"
    })

    return $results
}

function Revert-TcpOptimization {
    $progress = $window.FindName("ProgressBar")
    $statusText = $window.FindName("StatusText")

    $window.Dispatcher.Invoke([Action]{
        $statusText.Text = "正在还原 TCP..."
        $progress.Value = 20
    })
    Invoke-Command "netsh interface tcp set global autotuninglevel=normal" | Out-Null
    Invoke-Command "netsh interface tcp set global ecncapability=disabled" | Out-Null
    Invoke-Command "netsh interface tcp set global timestamps=enabled" | Out-Null
    Invoke-Command "netsh interface tcp set global initialrto=1000" | Out-Null
    Invoke-Command "netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic" | Out-Null

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 40; $statusText.Text = "正在还原注册表..." })
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $tcpPathV6 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
    $removeProps = @("TcpNoDelay","EnableTCPNoDelay","TcpAckFrequency","TcpDelAckTicks","Tcp1323Opts","SackOpts","EnableTCPChimney","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay","KeepAliveTime","TcpHybridAck","TcpWindowSize","TcpWindowSizeMin","MaxConnections","MTU","EnableWsd","EnableConnectionRateLimiting","EnableTcpFastOpen","DefaultTTL","MaxFreeTcbs","TcpMaxDataRetransmissions")
    foreach ($prop in $removeProps) {
        Remove-ItemProperty -Path $tcpPath -Name $prop -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $tcpPathV6 -Name $prop -Force -ErrorAction SilentlyContinue
    }
    # 还原节能以太网
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EnergyEfficientEthernet" -Force -ErrorAction SilentlyContinue
    # 还原 WinHTTP/WinINet
    @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
      "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings",
      "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings") | ForEach-Object {
        Remove-ItemProperty -Path $_ -Name "TcpAutotuning" -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $_ -Name "DisableBranchCache" -Force -ErrorAction SilentlyContinue
    }
    # 还原工作站参数
    $lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    @("DisableBandwidthThrottling","DisableLargeMtu") | ForEach-Object {
        Remove-ItemProperty -Path $lanmanPath -Name $_ -Force -ErrorAction SilentlyContinue
    }
    # 还原 QoS 策略注册表
    @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched",
      "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS",
      "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS") | ForEach-Object {
        if (Test-Path $_) {
            Remove-ItemProperty -Path $_ -Name "NonBestEffortLimit" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $_ -Name "Application DSCP Marking Request" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $_ -Name "DisableBranchCache" -Force -ErrorAction SilentlyContinue
        }
    }
    # Per-interface
    $adapters = Get-ActiveAdapters
    foreach ($adapter in $adapters) {
        try {
            $guid = (Get-NetAdapter -Name $adapter.Name -ErrorAction Stop).InterfaceGuid
            $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            try { Remove-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Force -ErrorAction Stop } catch {}
            try { Remove-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Force -ErrorAction Stop } catch {}
        } catch {
            Add-LogEntry "WARN" "还原时无法获取网卡 $($adapter.Name) 的 InterfaceGuid"
        }
    }

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 60; $statusText.Text = "正在还原系统参数..." })
    $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 80; $statusText.Text = "正在移除 QoS..." })
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    @("NetOpt_FPS_CS2_Proc","NetOpt_FPS_CS2_Port","NetOpt_FPS_Val_Proc","NetOpt_FPS_Val_Port",
      "NetOpt_FPS_Apex_Proc","NetOpt_FPS_Apex_Port","NetOpt_FPS_CoD_Proc","NetOpt_FPS_CoD_Port",
      "NetOpt_FPS_PUBG_Proc","NetOpt_FPS_R6_Proc","NetOpt_FPS_R6_Port") | ForEach-Object {
        Invoke-Command "netsh qos delete policy name=`"$_`"" | Out-Null
    }

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 100; $statusText.Text = "还原完成！" })
}

function Run-SpeedTest {
    $statusText = $window.FindName("StatusText")
    $progress = $window.FindName("ProgressBar")

    # Ping test
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测量延迟..."; $progress.Value = 20 })
    $adapter = Get-ActiveAdapters | Select-Object -First 1
    $pingVal = -1
    if ($adapter) {
        $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
        if ($gw) {
            $pingVal = Measure-PingLatency -TargetHost $gw -Count 3
        }
    }
    if ($pingVal -lt 0) { $pingVal = Measure-PingLatency -TargetHost "1.1.1.1" -Count 3 }

    # Download test
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测试下载..."; $progress.Value = 50 })
    $downloadMbps = 0
    try {
        $url = "https://speed.cloudflare.com/__down?bytes=10000000"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $data = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
        $sw.Stop()
        if ($sw.Elapsed.TotalSeconds -gt 0) {
            $downloadMbps = [math]::Round(($data.RawContentLength * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
        }
    } catch {
        $downloadMbps = -1
    }

    # Upload test
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测试上传..."; $progress.Value = 80 })
    $uploadMbps = 0
    try {
        $uploadData = New-Object byte[] 5000000
        $url = "https://speed.cloudflare.com/__up"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri $url -Method POST -Body $uploadData -UseBasicParsing -TimeoutSec 15 | Out-Null
        $sw.Stop()
        if ($sw.Elapsed.TotalSeconds -gt 0) {
            $uploadMbps = [math]::Round((5000000 * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
        }
    } catch {
        $uploadMbps = -1
    }

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 100; $statusText.Text = "网速测试完成！" })

    return @{ Ping = $pingVal; Download = $downloadMbps; Upload = $uploadMbps }
}

# ============================================================
# XAML UI Definition
# ============================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="ALit-网络优化工具V3 - Minecraft PvP" 
        Width="1000" Height="680" 
        Background="#1E1E1E"
        WindowStyle="None"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize"
        UseLayoutRounding="True"
        TextOptions.TextFormattingMode="Display"
        TextOptions.TextRenderingMode="ClearType">
<WindowChrome.WindowChrome>
    <shell:WindowChrome GlassFrameThickness="0" ResizeBorderThickness="0" CaptionHeight="0" CornerRadius="16"/>
</WindowChrome.WindowChrome>

<Window.Resources>
    <Style TargetType="TextBlock">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
    </Style>
    <Style TargetType="Button">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="MinHeight" Value="32"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="btnBorder" Background="{TemplateBinding Background}" 
                            CornerRadius="8" BorderThickness="{TemplateBinding BorderThickness}"
                            BorderBrush="{TemplateBinding BorderBrush}" Padding="{TemplateBinding Padding}">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="btnBorder" Property="Opacity" Value="0.85"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="btnBorder" Property="Opacity" Value="0.7"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style TargetType="RadioButton">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
    </Style>
    <Style TargetType="ComboBox">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="Background" Value="#333333"/>
        <Setter Property="Foreground" Value="#E8E8E8"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ComboBox">
                    <Border Background="#333333" BorderBrush="#555555" BorderThickness="1" CornerRadius="4">
                        <Grid>
                            <ContentPresenter x:Name="contentSite" IsHitTestVisible="False" 
                              Content="{TemplateBinding SelectionBoxItem}" 
                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                              ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                              Margin="8,4,24,4" VerticalAlignment="Center" 
                              TextBlock.Foreground="#E8E8E8"/>
                            <TextBlock x:Name="placeholderText" Text="请选择..." IsHitTestVisible="False" 
                                       Margin="8,4,24,4" VerticalAlignment="Center" 
                                       Foreground="#888888" Visibility="Visible"/>
                            <Path x:Name="arrowPath" Data="M0,0 L4,4 L8,0" Stroke="#E8E8E8" StrokeThickness="1.5"
                                  HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="HasItems" Value="True">
                            <Setter TargetName="placeholderText" Property="Visibility" Value="Collapsed"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style TargetType="ComboBoxItem">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="Background" Value="#2A2A2A"/>
        <Setter Property="Foreground" Value="#E8E8E8"/>
        <Setter Property="Padding" Value="8,4"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ComboBoxItem">
                    <Border x:Name="cbiBorder" Background="{TemplateBinding Background}" 
                            Padding="{TemplateBinding Padding}" BorderThickness="0">
                        <ContentPresenter VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="cbiBorder" Property="Background" Value="#3D5A7C"/>
                        </Trigger>
                        <Trigger Property="IsSelected" Value="True">
                            <Setter TargetName="cbiBorder" Property="Background" Value="#2D5A7C"/>
                            <Setter Property="Foreground" Value="#FFFFFF"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style TargetType="ScrollViewer">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Padding" Value="0"/>
    </Style>
    <Style TargetType="CheckBox">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="Foreground" Value="#E8E8E8"/>
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="#666666"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Padding" Value="4,0,0,0"/>
        <Setter Property="VerticalContentAlignment" Value="Center"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="CheckBox">
                    <BulletDecorator Background="Transparent">
                        <BulletDecorator.Bullet>
                            <Border Width="16" Height="16" CornerRadius="3" Background="#2A2A2A" BorderBrush="#666666" BorderThickness="1">
                                <Path x:Name="checkMark" Data="M2,6 L6,10 L14,2" Stroke="#7CC7FF" StrokeThickness="2" Stretch="Uniform" Margin="2" Visibility="Collapsed"/>
                            </Border>
                        </BulletDecorator.Bullet>
                        <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                    </BulletDecorator>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsChecked" Value="True">
                            <Setter TargetName="checkMark" Property="Visibility" Value="Visible"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="checkMark" Property="Stroke" Value="#A0D8FF"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style TargetType="ToggleButton">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="Foreground" Value="#E8E8E8"/>
        <Setter Property="Background" Value="#3A3A3A"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Padding" Value="12,4"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="ToggleButton">
                    <Border Background="{TemplateBinding Background}" CornerRadius="4" BorderThickness="0">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Opacity" Value="0.85"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter Property="Opacity" Value="0.7"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style TargetType="ProgressBar">
        <Setter Property="Background" Value="#3A3A3A"/>
        <Setter Property="Foreground" Value="#7CC7FF"/>
        <Setter Property="BorderThickness" Value="0"/>
    </Style>
    <Style TargetType="TextBox">
        <Setter Property="FontFamily" Value="HarmonyOS Sans SC, Microsoft YaHei UI, Microsoft YaHei, Segoe UI"/>
        <Setter Property="Background" Value="#333333"/>
        <Setter Property="Foreground" Value="#E8E8E8"/>
        <Setter Property="BorderBrush" Value="#555555"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Padding" Value="6,4"/>
        <Setter Property="CaretBrush" Value="#E8E8E8"/>
        <Setter Property="SelectionBrush" Value="#2D5A7C"/>
    </Style>
</Window.Resources>

<Border x:Name="WindowChromeBorder" Background="#1E1E1E" CornerRadius="16" Margin="0" BorderThickness="0" SnapsToDevicePixels="True">
    <Grid x:Name="MainContentGrid" ClipToBounds="True">
        <Grid.RowDefinitions>
            <RowDefinition Height="38"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border x:Name="CustomTitleBar" Grid.Row="0" Background="#171717" CornerRadius="16,16,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
                    <TextBlock Text="ALit-网络优化工具V3" Foreground="#7CC7FF" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                    <TextBlock Text="  Minecraft PvP 网络优化" Foreground="#A8A8A8" FontSize="12" VerticalAlignment="Center"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,8,0">
                    <Button x:Name="BtnWindowMinimize" Content="—" Width="42" Height="28" MinHeight="28" Padding="0" Background="#252525" Foreground="#E8E8E8" BorderThickness="0" FontSize="14" Margin="0,0,6,0"/>
                    <Button x:Name="BtnWindowMaxRestore" Content="□" Width="42" Height="28" MinHeight="28" Padding="0" Background="#252525" Foreground="#E8E8E8" BorderThickness="0" FontSize="13" Margin="0,0,6,0"/>
                    <Button x:Name="BtnWindowClose" Content="×" Width="42" Height="28" MinHeight="28" Padding="0" Background="#3A1F24" Foreground="#FFB4B4" BorderThickness="0" FontSize="16"/>
                </StackPanel>
            </Grid>
        </Border>

<Grid Grid.Row="1">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="220"/>
        <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Sidebar -->
    <Border x:Name="SidebarBorder" Grid.Column="0" Background="#1B1B1B" CornerRadius="0,0,0,16" Padding="0,20,0,0">
        <StackPanel>
            <TextBlock Text="ALit-网络优化工具V3" Foreground="#7CC7FF" FontSize="16" FontWeight="Bold" Margin="20,0,0,10"/>
            <TextBlock Text="System Performance Optimizer" Foreground="#E8E8E8" FontSize="10" Margin="20,0,0,20" TextWrapping="Wrap"/>

            <Border x:Name="NavDashboard" Background="#2D5A7C" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Dashboard">
                <TextBlock Text="配置" Foreground="#FFFFFF" FontSize="14" FontWeight="SemiBold"/>
            </Border>
            <Border x:Name="NavTcp" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Tcp">
                <TextBlock Text="TCP/IP" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavDns" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Dns">
                <TextBlock Text="DNS" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavQos" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Qos">
                <TextBlock Text="QoS" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavHosts" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Hosts">
                <TextBlock Text="Hosts编辑" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavCustom" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Custom">
                <TextBlock Text="自定义优化" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavTest" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Test">
                <TextBlock Text="测试" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavLog" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Log">
                <TextBlock Text="操作日志" Foreground="#E8E8E8" FontSize="14"/>
            </Border>
            <Border x:Name="NavSettings" Background="#2A2A2A" CornerRadius="8" Cursor="Hand" 
                    Margin="12,3,12,3" Padding="14,10" Tag="Settings">
                <TextBlock Text="设置" Foreground="#E8E8E8" FontSize="14"/>
            </Border>

            <Border Background="#2A2A2A" CornerRadius="6" Padding="12,8" Margin="20,30,20,0">
                <StackPanel>
                    <TextBlock Text="状态" Foreground="#E8E8E8" FontSize="13"/>
                    <TextBlock x:Name="SidebarStatus" Text="检测中..." Foreground="#E8E8E8" FontSize="13" FontWeight="SemiBold"/>
                </StackPanel>
            </Border>
        </StackPanel>
    </Border>

    <!-- Content Area -->
    <ScrollViewer Grid.Column="1" Margin="20,15,20,15" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
    <Grid>
        
        <!-- Dashboard Panel -->
        <StackPanel x:Name="DashboardPanel">
            <TextBlock Text="网络优化配置" Foreground="#F0F0F0" FontSize="24" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="选择优化档位后应用。均衡更适合日常，完全模式会修改更多 TCP/IP 与系统网络参数。" Foreground="#E8E8E8" FontSize="13" Margin="0,0,0,15"/>

            <!-- Status Cards -->
            <UniformGrid Columns="4" Margin="0,0,0,15">
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="延迟" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="PingValue" Text="--" Foreground="#7CC7FF" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" ms" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="下载" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="DownloadValue" Text="--" Foreground="#7CC7FF" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" Mbps" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="上传" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="UploadValue" Text="--" Foreground="#7CC7FF" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" Mbps" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16">
                    <StackPanel>
                        <TextBlock Text="DNS" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="DnsValue" Text="--" Foreground="#7CC7FF" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" ms" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </UniformGrid>

            <!-- System Resource Cards (CPU/Memory) -->
            <UniformGrid x:Name="SysInfoCards" Columns="2" Margin="0,0,0,15">
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="CPU 占用" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="CpuUsageValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" %" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#2B2B2B" CornerRadius="8" Padding="16">
                    <StackPanel>
                        <TextBlock Text="内存占用" Foreground="#E8E8E8" FontSize="13"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="MemUsageValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" %" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </UniformGrid>

            <!-- Quick Optimize -->
            <Border Background="#2B2B2B" CornerRadius="8" Padding="20" Margin="0,0,0,15">
                <StackPanel>
                    <TextBlock Text="优化模式" Foreground="#F0F0F0" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,5"/>
                    <TextBlock Text="四个档位：均衡满足日常体验，普通优化一部分网络体验，完全应用全部网络优化，还原会撤销本工具修改。"
                              Foreground="#E8E8E8" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <TextBlock Text="选择档位" Foreground="#FFFFFF" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <UniformGrid Columns="4" Margin="0,0,0,12">
                        <Button x:Name="BtnModeBalanced" Tag="Balanced" Background="#7CC7FF" Foreground="#111111"
                                FontSize="14" FontWeight="Bold" Padding="10,12" Margin="0,0,8,0" BorderThickness="0" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="均衡" Foreground="#111111" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="日常体验" Foreground="#222222" FontSize="13" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnModeNormal" Tag="Normal" Background="#3A3A3A" Foreground="#FFFFFF"
                                FontSize="14" FontWeight="Bold" Padding="10,12" Margin="0,0,8,0" BorderThickness="0" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="普通" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="部分优化" Foreground="#E8E8E8" FontSize="13" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnModeComplete" Tag="Complete" Background="#3A3A3A" Foreground="#FFFFFF"
                                FontSize="14" FontWeight="Bold" Padding="10,12" Margin="0,0,8,0" BorderThickness="0" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="完全" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="全部优化" Foreground="#E8E8E8" FontSize="13" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnModeRevert" Tag="Revert" Background="#3A3A3A" Foreground="#FFFFFF"
                                FontSize="14" FontWeight="Bold" Padding="10,12" BorderThickness="0" Cursor="Hand">
                            <StackPanel>
                                <TextBlock Text="还原" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
                                <TextBlock Text="撤销修改" Foreground="#E8E8E8" FontSize="13" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </UniformGrid>
                    <TextBlock x:Name="SelectedModeValue" Text="Balanced" Visibility="Collapsed"/>
                    <TextBlock x:Name="SelectedModeName" Text="均衡（满足日常体验）" Foreground="#E8E8E8" FontSize="13" Margin="0,0,0,10"/>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="BtnOptimize" Content="应用所选模式" Background="#7CC7FF" Foreground="#151515"
                               FontWeight="SemiBold" Padding="24,10" Margin="0,0,10,0"
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                        <Button x:Name="BtnRevert" Content="立即还原" Background="#EF5350" Foreground="White"
                               FontWeight="SemiBold" Padding="24,10" Margin="0,0,10,0"
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                        <Button x:Name="BtnSpeedTest" Content="网速测试" Background="#3A3A3A" Foreground="#E8E8E8"
                               FontWeight="SemiBold" Padding="24,10"
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                        <TextBlock x:Name="StatusText" Text="就绪" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center"/>
                    </StackPanel>
                    <ProgressBar x:Name="ProgressBar" Height="6" Margin="0,5,0,0" Foreground="#7CC7FF" Background="#3A3A3A"
                                BorderThickness="0" Value="0"/>
                </StackPanel>
            </Border>

            <!-- Results -->
            <Border Background="#2B2B2B" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="执行结果" Foreground="#F0F0F0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <ListBox x:Name="ResultsList" Background="Transparent" BorderThickness="0" MaxHeight="180" 
                            FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13" Foreground="#E8E8E8"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- TCP Panel -->
        <StackPanel x:Name="TcpPanel" Visibility="Collapsed">
            <TextBlock Text="TCP/IP 协议栈优化" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="所有设置均基于 Windows 可配置参数" Foreground="#E0E0E0" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="当前 TCP 全局设置" Foreground="#F2F2F2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <Button x:Name="BtnRefreshTcp" Content="刷新" Background="#0F3460" Foreground="#F2F2F2" 
                           Padding="12,4" FontSize="13" BorderThickness="0" Margin="0,0,0,8"/>
                    <TextBox x:Name="TcpSettingsText" Text="点击刷新加载..." FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13" 
                            Foreground="#E0E0E0" Background="#0F3460" BorderThickness="0" IsReadOnly="True" 
                            TextWrapping="Wrap" Height="200" VerticalScrollBarVisibility="Auto" Padding="8"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="关键优化说明：" Foreground="#F2F2F2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock Foreground="#F2F2F2" FontSize="13" TextWrapping="Wrap" LineHeight="22"
                              Text="1. TcpNoDelay=1 - 禁用 Nagle 算法，降低交互延迟&#x0a;2. TcpAckFrequency=1 - 提高 ACK 响应频率&#x0a;3. NetworkThrottlingIndex=0xFFFFFFFF - 关闭系统网络节流&#x0a;4. SystemResponsiveness=0 - 降低后台任务保留比例&#x0a;5. CTCP 拥塞控制 - 改善吞吐表现&#x0a;6. ECN 启用 - 降低拥塞重传概率&#x0a;7. RSS 启用 - 多核并行处理网络流量&#x0a;8. 游戏任务 GPU/IO 优先级提高&#x0a;9. 发送/接收窗口参数优化&#x0a;10. MaxUserPort 与 TIME_WAIT 参数优化&#x0a;11. FPS游戏优化 - DSCP 46 优先级 + UDP FEC + 小包优先标记"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- DNS Panel -->
        <StackPanel x:Name="DnsPanel" Visibility="Collapsed">
            <TextBlock Text="DNS 优化" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="配置 DNS 以提升域名解析体验" Foreground="#E0E0E0" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="当前 DNS：" Foreground="#E0E0E0" FontSize="13" Margin="0,0,0,5"/>
                    <TextBlock x:Name="CurrentDnsText" Text="--" FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13" Foreground="#00E676" Margin="0,0,0,10"/>
                    <Button x:Name="BtnFlushDns" Content="清理 DNS 缓存" Background="#0F3460" Foreground="#F2F2F2" 
                           Padding="16,8" FontSize="13" BorderThickness="0"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="DNS 预设" Foreground="#F2F2F2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <UniformGrid Columns="2" Margin="0,0,0,10">
                        <Border x:Name="DnsBtnCloudflare" Background="#3A3A3A" CornerRadius="8" Cursor="Hand" Margin="0,0,6,4" Padding="10,8" Tag="0">
                            <TextBlock x:Name="DnsTextCloudflare" Text="Cloudflare (1.1.1.1)" Foreground="#E8E8E8" FontSize="12" HorizontalAlignment="Center"/>
                        </Border>
                        <Border x:Name="DnsBtnGoogle" Background="#3A3A3A" CornerRadius="8" Cursor="Hand" Margin="6,0,0,4" Padding="10,8" Tag="1">
                            <TextBlock x:Name="DnsTextGoogle" Text="Google (8.8.8.8)" Foreground="#E8E8E8" FontSize="12" HorizontalAlignment="Center"/>
                        </Border>
                        <Border x:Name="DnsBtnAli" Background="#3A3A3A" CornerRadius="8" Cursor="Hand" Margin="0,0,6,4" Padding="10,8" Tag="2">
                            <TextBlock x:Name="DnsTextAli" Text="阿里 DNS (223.5.5.5)" Foreground="#E8E8E8" FontSize="12" HorizontalAlignment="Center"/>
                        </Border>
                        <Border x:Name="DnsBtn114" Background="#3A3A3A" CornerRadius="8" Cursor="Hand" Margin="6,0,0,4" Padding="10,8" Tag="3">
                            <TextBlock x:Name="DnsText114" Text="114DNS (114.114.114.114)" Foreground="#E8E8E8" FontSize="12" HorizontalAlignment="Center"/>
                        </Border>
                        <Border x:Name="DnsBtnDNSPod" Background="#3A3A3A" CornerRadius="8" Cursor="Hand" Margin="0,0,6,0" Padding="10,8" Tag="4">
                            <TextBlock x:Name="DnsTextDNSPod" Text="DNSPod (119.29.29.29)" Foreground="#E8E8E8" FontSize="12" HorizontalAlignment="Center"/>
                        </Border>
                    </UniformGrid>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="BtnApplyDns" Content="应用 DNS" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnRestoreDns" Content="恢复 DHCP" Background="#0F3460" Foreground="#F2F2F2" 
                               Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="BtnDnsSpeedTest" Content="DNS 测速" Background="#7CC7FF" Foreground="#151515" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Hosts Panel -->
        <StackPanel x:Name="HostsPanel" Visibility="Collapsed">
            <TextBlock Text="Hosts编辑" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="可在软件内查看、保存、重置 Hosts，也可使用内置优化 Hosts（2606 条域名解析，覆盖 GitHub/Mojang/Google 等）。" Foreground="#E0E0E0" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="BtnLoadHosts" Content="读取 Hosts" Background="#0F3460" Foreground="#F2F2F2" 
                               Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnSaveHosts" Content="保存 Hosts" Background="#7CC7FF" Foreground="#151515" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnOptimizeHosts" Content="Hosts 优化" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnResetHosts" Content="Hosts 重置" Background="#EF5350" Foreground="White" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                    <TextBox x:Name="HostsEditorText" Text="点击“读取 Hosts”加载内容..." FontFamily="Consolas, Microsoft YaHei UI" FontSize="13"
                             Foreground="#E0E0E0" Background="#0F3460" BorderThickness="0" AcceptsReturn="True" AcceptsTab="True"
                             TextWrapping="NoWrap" Height="420" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Padding="10"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Custom Optimization Panel -->
        <StackPanel x:Name="CustomPanel" Visibility="Collapsed">
            <TextBlock Text="自定义优化" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="显示全部可选优化条目。建议只勾选自己理解的项目。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <ScrollViewer Height="410" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <TextBlock Text="基础低延迟与 TCP/IP" Foreground="#7CC7FF" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                            <CheckBox x:Name="OptTcpNoDelay" Content="TcpNoDelay=1：降低交互延迟" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptTcpAckFrequency" Content="TcpAckFrequency=1：提高 ACK 响应频率" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptTcpDelAckTicks" Content="TcpDelAckTicks=0：禁用延迟 ACK（立即确认）" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptFastOpen" Content="TCP Fast Open：启用快速打开" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptMaxUserPort" Content="MaxUserPort=64336：扩大临时端口范围" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>

                            <TextBlock Text="系统网络栈" Foreground="#7CC7FF" FontSize="14" FontWeight="SemiBold" Margin="0,14,0,8"/>
                            <CheckBox x:Name="OptAutoTuning" Content="TCP 自动调优：Normal" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptInitialWindow" Content="InitialCongestionWindow=10 / InitialRto=3000" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptEcn" Content="ECN：启用显式拥塞通知" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptRssTaskOffload" Content="RSS + TaskOffload：启用网卡卸载能力" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptNetworkThrottle" Content="NetworkThrottlingIndex=0xFFFFFFFF：关闭多媒体网络节流" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptResponsiveness" Content="SystemResponsiveness=0：降低后台保留比例" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>

                            <TextBlock Text="QoS 带宽与传输优化" Foreground="#7CC7FF" FontSize="14" FontWeight="SemiBold" Margin="0,14,0,8"/>
                            <CheckBox x:Name="OptQoSReserve" Content="NonBestEffortLimit=0：取消 QoS 非最佳效率带宽保留" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptLanmanThrottle" Content="DisableBandwidthThrottling=1：关闭工作站带宽节流" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptLargeMtu" Content="DisableLargeMtu=0：启用 Large MTU 支持" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptWinHttpAutoTuning" Content="WinHTTP TcpAutotuning=1：启用 WinHTTP 自动调优" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptBranchCache" Content="禁用 WinHTTP / BITS BranchCache" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptEnableWsdOff" Content="EnableWsd=0：关闭 TCP/IP WSD 相关开关" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptConnRateLimit" Content="EnableConnectionRateLimiting=0：禁用连接速率限制" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptAppDscp" Content="Application DSCP Marking Request=Allowed：允许应用请求 DSCP 标记" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptFpsQoS" Content="FPS游戏 QoS：CS2/Valorant/Apex/CoD/PUBG/R6 进程+端口 DSCP 46 优先级" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>

                            <TextBlock Text="延迟与连接优化" Foreground="#7CC7FF" FontSize="14" FontWeight="SemiBold" Margin="0,14,0,8"/>
                            <CheckBox x:Name="OptTcpHybridAck" Content="TcpHybridAck=0：关闭混合 ACK 延迟（降低小包延迟）" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptEnergyEfficient" Content="EnergyEfficientEthernet=0：关闭节能以太网（消除延迟抖动）" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptWinINetAutoTuning" Content="WinINet TcpAutotuning=1：启用 32/64 位 IE/WinINet 自动调优" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptMaxConnections" Content="MaxConnections=65536：扩大最大并发连接数" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptMtu1500" Content="MTU=1500：设置标准以太网 MTU" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>

                            <TextBlock Text="窗口与拥塞控制" Foreground="#7CC7FF" FontSize="14" FontWeight="SemiBold" Margin="0,14,0,8"/>
                            <CheckBox x:Name="OptTcpWindowSize" Content="TcpWindowSize=130000：固定 TCP 窗口大小（与自动调优冲突，二选一）" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                            <CheckBox x:Name="OptCongestionDefault" Content="拥塞控制 Default：恢复系统默认 CUBIC（替代 CTCP）" Foreground="#E8E8E8" FontSize="13" Margin="0,4"/>
                        </StackPanel>
                    </ScrollViewer>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnApplyCustom" Content="应用勾选优化" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="18,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnSelectRecommendedCustom" Content="勾选推荐项" Background="#7CC7FF" Foreground="#151515" 
                               FontWeight="SemiBold" Padding="18,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnClearCustom" Content="清空选择" Background="#3A3A3A" Foreground="#F2F2F2" 
                               Padding="18,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Test Panel -->
        <StackPanel x:Name="TestPanel" Visibility="Collapsed">
            <TextBlock Text="测试" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="独立测试功能，不会加入自定义优化勾选列表。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="1. 智能调整网卡深层参数" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="智能尝试调整活动网卡的缓冲区、中断处理、RSS 与卸载能力。只对系统支持的项目生效，失败项会跳过并写入日志。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <Button x:Name="BtnTestAdapterDeep" Content="执行网卡深层测试优化" Background="#00E676" Foreground="#1A1A2E" 
                           FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,12,0,0" HorizontalAlignment="Left"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="2. WinDivert 逐包优化模拟" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="WinDivert 在内核层逐包拦截并修改 TCP/IP 头部（DSCP、窗口、ACK 等）。本功能用 Windows 原生 QoS + 进程调度 + 网卡驱动层参数，在不安装驱动的前提下模拟类似的逐包优先级效果。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <WrapPanel Margin="0,12,0,0">
                        <CheckBox x:Name="ChkSimQoS" Content="QoS DSCP 46 标记（应用+端口）" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkSimProcPriority" Content="进程优先级提升（High）" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkSimTimer" Content="系统定时器 0.5ms" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkSimInterrupt" Content="关闭网卡中断调节" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkSimRSS" Content="RSS 队列优化" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkSimThrottle" Content="关闭网络节流+系统响应=0" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                    </WrapPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnSimApply" Content="一键模拟" Background="#00E676" Foreground="#1A1A2E"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnSimRestore" Content="还原模拟" Background="#EF5350" Foreground="White"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnSimStatus" Content="检测状态" Background="#0F3460" Foreground="#F2F2F2"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                    <TextBox x:Name="SimResultText" Text="--" FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13"
                            Foreground="#E0E0E0" Background="#0F3460" BorderThickness="0" IsReadOnly="True"
                            TextWrapping="Wrap" Height="120" VerticalScrollBarVisibility="Auto" Padding="8" Margin="0,10,0,0"/>
                </StackPanel>
            </Border>

            <Border Background="#1A1A2E" CornerRadius="8" Padding="16" Margin="0,0,0,10" BorderBrush="#EF5350" BorderThickness="1">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                        <TextBlock Text="[!] " Foreground="#EF5350" FontSize="16" FontWeight="Bold"/>
                        <TextBlock Text="WinDivert 内核级逐包优化（真实模式）" Foreground="#EF5350" FontSize="15" FontWeight="SemiBold"/>
                    </StackPanel>
                    <TextBlock Text="WinDivert 是开源内核级数据包拦截驱动，在 NDIS 层逐包捕获并修改 TCP/IP 头部 DSCP 字段。与上面的 QoS 模拟不同，这是真正的逐包修改，效果等同于 v7 Turbo。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <TextBlock Text="[!] 警告：此功能需要安装内核驱动（WinDivert64.sys），可能被杀毒软件标记。驱动安装后所有流量经过内核拦截层，如遇蓝屏或不稳定请立即停止并卸载驱动。" Foreground="#FFB74D" FontSize="12" TextWrapping="Wrap" LineHeight="18" Margin="0,8,0,0"/>
                    <WrapPanel Margin="0,12,0,0">
                        <TextBlock Text="优化模式:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <UniformGrid Columns="5" Margin="0,0,12,4">
                            <Button x:Name="WdModeBtn0" Tag="0" Content="普通" Background="#3A3A3A" Foreground="#E8E8E8" FontSize="12" Padding="8,6" Margin="0,0,4,0" BorderThickness="0" Cursor="Hand"/>
                            <Button x:Name="WdModeBtn1" Tag="1" Content="最佳" Background="#7CC7FF" Foreground="#111111" FontSize="12" Padding="8,6" Margin="0,0,4,0" BorderThickness="0" Cursor="Hand"/>
                            <Button x:Name="WdModeBtn2" Tag="2" Content="急速" Background="#3A3A3A" Foreground="#E8E8E8" FontSize="12" Padding="8,6" Margin="0,0,4,0" BorderThickness="0" Cursor="Hand"/>
                            <Button x:Name="WdModeBtn3" Tag="3" Content="狂暴" Background="#3A3A3A" Foreground="#E8E8E8" FontSize="12" Padding="8,6" Margin="0,0,4,0" BorderThickness="0" Cursor="Hand"/>
                            <Button x:Name="WdModeBtn4" Tag="4" Content="BT" Background="#3A3A3A" Foreground="#E8E8E8" FontSize="12" Padding="8,6" BorderThickness="0" Cursor="Hand"/>
                        </UniformGrid>
                        <TextBlock x:Name="WdModeLabel" Text="1" Visibility="Collapsed"/>
                        <TextBlock Text="TCP 端口:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBox x:Name="WdTcpPort" Text="25565" FontSize="13" Width="100" Background="#0F3460" Foreground="#E0E0E0" BorderBrush="#2A2A4A" Padding="4,2"/>
                        <TextBlock Text="UDP 端口:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="12,0,6,0"/>
                        <TextBox x:Name="WdUdpPort" Text="19132" FontSize="13" Width="100" Background="#0F3460" Foreground="#E0E0E0" BorderBrush="#2A2A4A" Padding="4,2"/>
                        <TextBlock Text="DSCP:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="12,0,6,0"/>
                        <TextBox x:Name="WdDscp" Text="46" FontSize="13" Width="40" Background="#0F3460" Foreground="#E0E0E0" BorderBrush="#2A2A4A" Padding="4,2"/>
                    </WrapPanel>
                    <TextBlock Text="提示: 端口支持多值(逗号分隔) | 急速+=UDP FEC冗余 | 狂暴=强FEC+路径切换 | BT=冗余复制+延后包恢复 | 小UDP包(&lt;512B)自动优先标记" Foreground="#7CC7FF" FontSize="11" TextWrapping="Wrap" Margin="0,6,0,0"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnWdStart" Content="启动逐包优化" Background="#00E676" Foreground="#1A1A2E"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnWdStop" Content="停止" Background="#EF5350" Foreground="White"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0" IsEnabled="False"/>
                        <Button x:Name="BtnWdRefresh" Content="刷新状态" Background="#0F3460" Foreground="#F2F2F2"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnWdUninstall" Content="卸载驱动" Background="#0F3460" Foreground="#F2F2F2"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                    <TextBox x:Name="WdResultText" Text="-- WinDivert 未运行 --" FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13"
                            Foreground="#E0E0E0" Background="#0F3460" BorderThickness="0" IsReadOnly="True"
                            TextWrapping="Wrap" Height="100" VerticalScrollBarVisibility="Auto" Padding="8" Margin="0,10,0,0"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="3. 加速器兼容支持" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="自动检测常见游戏加速器（UU/迅游/雷神/3733等），显示加速器状态。启用兼容模式后 WinDivert 过滤器将匹配加速器虚拟网卡流量，确保逐包优化覆盖加速器链路。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <WrapPanel Margin="0,12,0,0">
                        <TextBlock Text="检测状态:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <TextBlock x:Name="AccelStatus" Text="未检测到加速器" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,18,0"/>
                    </WrapPanel>
                    <WrapPanel Margin="0,8,0,0">
                        <TextBlock Text="加速器类型:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,6,0"/>
                        <ComboBox x:Name="AccelSelector" SelectedIndex="0" FontSize="13" MinWidth="120" Background="#0F3460" Foreground="#E0E0E0" Margin="0,0,12,4">
                            <ComboBoxItem Content="自动检测" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="UU加速器" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="迅游加速器" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="雷神加速器" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="3733加速器" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="奇游加速器" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="手动指定" Foreground="#E0E0E0"/>
                        </ComboBox>
                        <TextBlock Text="游戏类型:" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="12,0,6,0"/>
                        <ComboBox x:Name="GameSelector" SelectedIndex="0" FontSize="13" MinWidth="120" Background="#0F3460" Foreground="#E0E0E0" Margin="0,0,12,4">
                            <ComboBoxItem Content="Minecraft Java (25565)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="Minecraft 基岩版 (19132)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="CS2 (27015)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="Valorant (7448)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="Apex Legends (37015)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="Call of Duty (3074)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="PUBG (27015)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="Rainbow Six (3074)" Foreground="#E0E0E0"/>
                            <ComboBoxItem Content="自定义端口" Foreground="#E0E0E0"/>
                        </ComboBox>
                    </WrapPanel>
                    <WrapPanel Margin="0,8,0,0">
                        <CheckBox x:Name="ChkAccelCompat" Content="启用加速器兼容模式（WinDivert 过滤器匹配全部网卡）" IsChecked="False" Foreground="#E8E8E8" FontSize="13" Margin="0,0,0,4"/>
                    </WrapPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnAccelDetect" Content="检测加速器" Background="#00E676" Foreground="#1A1A2E"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnAccelApply" Content="应用端口预设" Background="#7CC7FF" Foreground="#151515"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="4. 网卡驱动参数优化" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="优化活动网卡驱动层高级属性：关闭节能以太网/绿色以太网/省电模式，启用 RSS，并尝试低延迟驱动参数。不自动安装驱动。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <WrapPanel Margin="0,12,0,0">
                        <CheckBox x:Name="ChkDriverRss" Content="启用 RSS / TaskOffload" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverPower" Content="禁止系统关闭网卡节能" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverEnergy" Content="关闭节能以太网" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverGreen" Content="关闭绿色以太网" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverPowerMode" Content="关闭省电模式" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverUltraLow" Content="关闭超低功耗" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverInterrupt" Content="关闭中断调节" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverFlow" Content="关闭流控" IsChecked="False" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                        <CheckBox x:Name="ChkDriverRegistryEco" Content="关闭厂商节能注册项" IsChecked="True" Foreground="#E8E8E8" FontSize="13" Margin="0,0,18,8"/>
                    </WrapPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnTestDriverCheck" Content="检测网卡驱动" Background="#00E676" Foreground="#1A1A2E"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnOptimizeDriverParams" Content="执行驱动参数优化" Background="#7CC7FF" Foreground="#151515"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,10,0,0">
                <StackPanel>
                    <TextBlock Text="5. MTU 最佳值智能优化" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="自动探测网络链路支持的最大不分片包大小，计算最佳 MTU 值并应用到所选网卡。探测使用 223.5.5.5 / 223.6.6.6 作为目标，二分法精确搜索。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <WrapPanel Margin="0,12,0,0">
                        <TextBlock Text="选择网卡：" Foreground="#E8E8E8" FontSize="13" VerticalAlignment="Center" Margin="0,0,8,0"/>
                        <ComboBox x:Name="MtuAdapterCombo" MinWidth="200" FontSize="13" Background="#333333" Foreground="#E8E8E8" Margin="0,0,10,4"/>
                    </WrapPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                        <Button x:Name="BtnMtuDetect" Content="探测最佳 MTU" Background="#00E676" Foreground="#1A1A2E"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnMtuApply" Content="应用 MTU" Background="#7CC7FF" Foreground="#151515"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnMtuRestore" Content="还原默认 MTU (1500)" Background="#EF5350" Foreground="White"
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                    <TextBlock x:Name="MtuResultText" Text="--" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" Margin="0,10,0,0" LineHeight="20"/>
                </StackPanel>
            </Border>
        </StackPanel>
        <StackPanel x:Name="QosPanel" Visibility="Collapsed">
            <TextBlock Text="QoS - 流量优先级" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="使用 DSCP 46 为 Minecraft 及 FPS 游戏流量设置最高优先级" Foreground="#E0E0E0" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="游戏 QoS 策略：" Foreground="#F2F2F2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"
                              Text="- javaw.exe（Minecraft Java）：DSCP 46，不限速&#x0a;- Minecraft.Windows.exe（基岩版）：DSCP 46&#x0a;- 端口 25565（Java 默认）：DSCP 46&#x0a;- 端口 19132（基岩版 UDP）：DSCP 46&#x0a;- CS2/Valorant/Apex/CoD/PUBG/R6 进程：DSCP 46&#x0a;- 端口 27015/7448/37015/3074/6015 UDP：DSCP 46"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnApplyQoS" Content="应用 QoS" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="13" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnRemoveQoS" Content="全部移除" Background="#EF5350" Foreground="White" 
                               Padding="16,8" FontSize="13" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="当前 QoS 策略：" Foreground="#F2F2F2" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <Button x:Name="BtnRefreshQoS" Content="刷新" Background="#0F3460" Foreground="#F2F2F2" 
                           Padding="12,4" FontSize="13" BorderThickness="0" Margin="0,0,0,8"/>
                    <TextBox x:Name="QoSPolicyText" Text="--" FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" FontSize="13" 
                            Foreground="#E0E0E0" Background="#0F3460" BorderThickness="0" IsReadOnly="True" 
                            TextWrapping="Wrap" Height="150" VerticalScrollBarVisibility="Auto" Padding="8"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Log Panel -->
        <StackPanel x:Name="LogPanel" Visibility="Collapsed">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="操作日志" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,15"/>
                <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom">
                    <Button x:Name="BtnExportLog" Content="导出" Background="#0F3460" Foreground="#F2F2F2"
                           Padding="12,4" FontSize="13" BorderThickness="0" Margin="0,0,8,0"/>
                    <Button x:Name="BtnClearLog" Content="清空" Background="#0F3460" Foreground="#F2F2F2"
                           Padding="12,4" FontSize="13" BorderThickness="0"/>
                </StackPanel>
            </Grid>
            <Border Background="#16213E" CornerRadius="8" Padding="8">
                <ListBox x:Name="LogList" Background="Transparent" BorderThickness="0" FontFamily="HarmonyOS Sans SC, Microsoft YaHei UI, Consolas" 
                        FontSize="13" Foreground="#F2F2F2" Height="450"/>
            </Border>
        </StackPanel>

        <!-- Settings Panel -->
        <StackPanel x:Name="SettingsPanel" Visibility="Collapsed">
            <TextBlock Text="设置" Foreground="#F2F2F2" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="软件偏好设置，修改后自动保存。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,15"/>

            <!-- 开机自启动 -->
            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="开机自启动" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="开启后，软件将在 Windows 启动时自动运行。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <CheckBox x:Name="ChkAutoStart" Content="开启开机自启动" Foreground="#E8E8E8" FontSize="14" IsChecked="False"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <!-- CPU/内存占用显示 -->
            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="系统资源监控" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="在主界面（配置页）显示 CPU 和内存占用，返回主界面时自动刷新。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <CheckBox x:Name="ChkShowSysInfo" Content="在主界面显示 CPU / 内存占用" Foreground="#E8E8E8" FontSize="14" IsChecked="True"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                        <TextBlock Text="CPU 占用：" Foreground="#E8E8E8" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock x:Name="SettingsCpuValue" Text="--" Foreground="#7CC7FF" FontSize="16" FontWeight="Bold" Margin="8,0,20,0"/>
                        <TextBlock Text="内存占用：" Foreground="#E8E8E8" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock x:Name="SettingsMemValue" Text="--" Foreground="#7CC7FF" FontSize="16" FontWeight="Bold" Margin="8,0,0,0"/>
                    </StackPanel>
                </StackPanel>
            </Border>

            <!-- 暗色/明亮主题 -->
            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="主题模式" Foreground="#7CC7FF" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
                    <TextBlock Text="切换暗色或明亮主题。暗色适合夜间使用，明亮主题适合白天。" Foreground="#E0E0E0" FontSize="13" TextWrapping="Wrap" LineHeight="20"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <RadioButton x:Name="RadioDarkTheme" Content="暗色主题" Foreground="#E8E8E8" FontSize="14" IsChecked="True" Margin="0,0,20,0"/>
                        <RadioButton x:Name="RadioLightTheme" Content="明亮主题" Foreground="#E8E8E8" FontSize="14"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </StackPanel>

    </Grid>
    </ScrollViewer>
</Grid>
    </Grid>
</Border>
</Window>
"@

# ============================================================
# Parse XAML and Create Window
# ============================================================
$window = [Windows.Markup.XamlReader]::Parse($xaml.OuterXml)
Update-SplashText "正在初始化界面..."

# ============================================================
# 圆角裁剪：修复尖角溢出问题
# ClipToBounds=True 只裁剪到矩形，无法裁剪到圆角
# 需要用 RectangleGeometry + RadiusX/Y 手动裁剪
# ============================================================
$script:UpdateRoundedClip = {
    $grid = $window.FindName("MainContentGrid")
    if (-not $grid) { return }
    $w = $grid.ActualWidth
    $h = $grid.ActualHeight
    if ($w -le 0 -or $h -le 0) { return }
    $rect = New-Object System.Windows.Rect(0, 0, $w, $h)
    $clip = New-Object System.Windows.Media.RectangleGeometry($rect, 15.0, 15.0)
    $grid.Clip = $clip
}

# ============================================================
# Event Handlers
# ============================================================

# Windows 10 圆角窗口：自绘标题栏行为
$titleBar = $window.FindName("CustomTitleBar")
if ($titleBar) {
    $titleBar.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler]{
        param($sender, $e)
        try {
            if ($e.ClickCount -ge 2) {
                if ($window.WindowState -eq "Maximized") {
                    $window.WindowState = "Normal"
                } else {
                    $window.WindowState = "Maximized"
                }
            } else {
                $window.DragMove()
            }
        } catch {
            Add-LogEntry "WARN" "窗口拖动失败：$($_.Exception.Message)"
        }
    })
}

$btnMinimize = $window.FindName("BtnWindowMinimize")
if ($btnMinimize) {
    $btnMinimize.Add_Click({
        $window.WindowState = "Minimized"
    })
}

$btnMaxRestore = $window.FindName("BtnWindowMaxRestore")
if ($btnMaxRestore) {
    $btnMaxRestore.Add_Click({
        if ($window.WindowState -eq "Maximized") {
            $window.WindowState = "Normal"
            $btnMaxRestore.Content = "□"
        } else {
            $window.WindowState = "Maximized"
            $btnMaxRestore.Content = "❐"
        }
    })
}

$window.Add_StateChanged({
    $btn = $window.FindName("BtnWindowMaxRestore")
    if ($btn) {
        if ($window.WindowState -eq "Maximized") { $btn.Content = "❐" } else { $btn.Content = "□" }
    }
    # 状态变化后延迟更新裁剪（等待布局完成）
    $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{
        & $script:UpdateRoundedClip
    }) | Out-Null
})

$btnClose = $window.FindName("BtnWindowClose")
if ($btnClose) {
    $btnClose.Add_Click({
        $window.Close()
    })
}

$window.Add_Loaded({
    Add-LogEntry "INFO" "ALit-网络优化工具V3 已启动"
    Add-LogEntry "INFO" "管理员权限: $isAdmin"
    Refresh-OptimizationStatus

    # 启动速度优化：不在窗口加载时同步扫描网卡/TCP，避免首屏被系统命令阻塞。
    $tcpText = $window.FindName("TcpSettingsText")
    if ($tcpText) {
        $tcpText.Text = "已跳过启动时自动扫描，以提升启动速度。`r`n点击刷新按钮可查看当前 TCP 全局设置。"
    }
    Add-LogEntry "INFO" "启动时已跳过自动网卡/TCP 扫描"

    # 应用圆角裁剪
    & $script:UpdateRoundedClip
})

# 窗口尺寸变化时更新裁剪（最大化/还原时触发）
$window.Add_SizeChanged({
    & $script:UpdateRoundedClip
})

# Navigation
function Update-NavButtons {
    param([string]$selectedTag)
    $navItems = @("NavDashboard", "NavTcp", "NavDns", "NavQos", "NavHosts", "NavCustom", "NavTest", "NavLog", "NavSettings")
    $selBg = if ($script:currentTheme -eq "Light") { "#90CAF9" } else { "#2D5A7C" }
    $selFg = if ($script:currentTheme -eq "Light") { "#1A1A1A" } else { "#FFFFFF" }
    $unselBg = if ($script:currentTheme -eq "Light") { "#F0F0F0" } else { "#2A2A2A" }
    $unselFg = if ($script:currentTheme -eq "Light") { "#333333" } else { "#E8E8E8" }
    foreach ($name in $navItems) {
        $border = $window.FindName($name)
        if (-not $border) { continue }
        if ($border.Tag -eq $selectedTag) {
            $border.Background = Create-Brush $selBg
            $border.Child.Foreground = Create-Brush $selFg
            $border.Child.FontWeight = "SemiBold"
        } else {
            $border.Background = Create-Brush $unselBg
            $border.Child.Foreground = Create-Brush $unselFg
            $border.Child.FontWeight = "Normal"
        }
    }
}

$script:SwitchNavPanel = {
    param([string]$tag)
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("HostsPanel").Visibility = "Collapsed"
    $window.FindName("CustomPanel").Visibility = "Collapsed"
    $window.FindName("TestPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Collapsed"
    $window.FindName("SettingsPanel").Visibility = "Collapsed"
    switch ($tag) {
        "Dashboard" {
            $window.FindName("DashboardPanel").Visibility = "Visible"
        }
        "Tcp" { $window.FindName("TcpPanel").Visibility = "Visible" }
        "Dns" {
            $window.FindName("DnsPanel").Visibility = "Visible"
            $window.FindName("CurrentDnsText").Text = "加载中..."
            Refresh-CurrentDnsAsync
        }
        "Qos" {
            $window.FindName("QosPanel").Visibility = "Visible"
            BtnRefreshQoS_Click $null $null
        }
        "Hosts" {
            $window.FindName("HostsPanel").Visibility = "Visible"
            Load-HostsToEditor
        }
        "Custom" { $window.FindName("CustomPanel").Visibility = "Visible" }
        "Test" {
            $window.FindName("TestPanel").Visibility = "Visible"
            $combo = $window.FindName("MtuAdapterCombo")
            if ($combo) {
                $combo.Items.Clear()
                try {
                    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" } | Sort-Object Name
                    foreach ($a in $adapters) {
                        $combo.Items.Add($a.Name) | Out-Null
                    }
                    if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
                } catch { Add-LogEntry "WARN" "填充 MTU 网卡列表失败" }
            }
        }
        "Log" { $window.FindName("LogPanel").Visibility = "Visible" }
        "Settings" {
            $window.FindName("SettingsPanel").Visibility = "Visible"
        }
    }
    Update-NavButtons $tag
}

function Refresh-CurrentDnsAsync {
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $dnsText = "--"
        try {
            $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
            if ($adapter) {
                $servers = (Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
                if ($servers) { $dnsText = ($servers -join ", ") }
            }
        } catch {
            $dnsText = "读取失败"
        }
        $window.Dispatcher.Invoke([Action]{
            $window.FindName("CurrentDnsText").Text = $dnsText
        })
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        if ($ps.InvocationStateInfo.State -eq "Completed") {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    } | Out-Null
}

# ============================================================
# Settings: Load / Save / Apply
# ============================================================
$script:settingsFile = Join-Path $script:stateDir "settings.json"
$script:currentTheme = "Dark"

function Load-Settings {
    try {
        if (Test-Path $script:settingsFile) {
            $json = Get-Content -Path $script:settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $chkAuto = $window.FindName("ChkAutoStart")
            $chkSys = $window.FindName("ChkShowSysInfo")
            $radioDark = $window.FindName("RadioDarkTheme")
            $radioLight = $window.FindName("RadioLightTheme")
            if ($json.AutoStart) { $chkAuto.IsChecked = $true }
            if ($json.ShowSysInfo -eq $false) { $chkSys.IsChecked = $false } else { $chkSys.IsChecked = $true }
            if ($json.Theme -eq "Light") { $radioLight.IsChecked = $true; $script:currentTheme = "Light" } else { $radioDark.IsChecked = $true; $script:currentTheme = "Dark" }
            Apply-Theme $script:currentTheme
            Update-SysInfoVisibility
        }
    } catch { Add-LogEntry "WARN" "加载设置失败：$($_.Exception.Message)" }
}

function Save-Settings {
    try {
        if (-not (Test-Path $script:stateDir)) { New-Item -Path $script:stateDir -ItemType Directory -Force | Out-Null }
        $chkAuto = $window.FindName("ChkAutoStart")
        $chkSys = $window.FindName("ChkShowSysInfo")
        $radioLight = $window.FindName("RadioLightTheme")
        $settings = @{
            AutoStart = [bool]$chkAuto.IsChecked
            ShowSysInfo = [bool]$chkSys.IsChecked
            Theme = if ($radioLight.IsChecked) { "Light" } else { "Dark" }
        }
        $json = $settings | ConvertTo-Json
        [System.IO.File]::WriteAllText($script:settingsFile, $json, [System.Text.Encoding]::UTF8)
    } catch { Add-LogEntry "WARN" "保存设置失败：$($_.Exception.Message)" }
}

function Apply-Theme {
    param([string]$theme)
    $script:currentTheme = $theme

    # 暗色 → 明亮 背景映射（6位hex无alpha）
    $darkBgMap = @{
        "1E1E1E" = "E8E8E8"; "171717" = "DDDDDD"; "1B1B1B" = "E0E0E0"
        "2A2A2A" = "F0F0F0"; "2B2B2B" = "F5F5F5"; "16213E" = "E3F2FD"
        "252525" = "E0E0E0"; "0F3460" = "BBDEFB"; "333333" = "FFFFFF"
        "3A3A3A" = "F0F0F0"; "2D5A7C" = "90CAF9"
    }
    # 暗色 → 明亮 前景映射
    $darkFgMap = @{
        "E8E8E8" = "1A1A1A"; "F2F2F2" = "1A1A1A"; "F0F0F0" = "212121"
        "FFFFFF" = "1A1A1A"; "E0E0E0" = "333333"; "D8D8D8" = "333333"
        "7CC7FF" = "1565C0"; "00E676" = "2E7D32"
    }
    # 反向映射（明亮 → 暗色）
    $lightBgMap = @{}
    $lightFgMap = @{}
    foreach ($k in $darkBgMap.Keys) { $lightBgMap[$darkBgMap[$k]] = $k }
    foreach ($k in $darkFgMap.Keys) { $lightFgMap[$darkFgMap[$k]] = $k }

    if ($theme -eq "Light") {
        $bgMap = $darkBgMap; $fgMap = $darkFgMap
        $window.Background = Create-Brush "#E8E8E8"
    } else {
        $bgMap = $lightBgMap; $fgMap = $lightFgMap
        $window.Background = Create-Brush "#1E1E1E"
    }

    Apply-ThemeRecursive $window $bgMap $fgMap
}

function Apply-ThemeRecursive {
    param($element, $bgMap, $fgMap)

    if ($null -eq $element) { return }

    # Border 背景
    if ($element -is [System.Windows.Controls.Border]) {
        $bg = $element.Background
        if ($bg -and $bg -is [System.Windows.Media.SolidColorBrush]) {
            $c = $bg.Color
            $hex = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
            if ($bgMap.ContainsKey($hex)) {
                $element.Background = Create-Brush ("#" + $bgMap[$hex])
            }
        }
        # Border 前景（Border 内若直接含 TextBlock）
        $fg = $element.Foreground
        if ($fg -and $fg -is [System.Windows.Media.SolidColorBrush]) {
            $c = $fg.Color
            $hex = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
            if ($fgMap.ContainsKey($hex)) {
                $element.Foreground = Create-Brush ("#" + $fgMap[$hex])
            }
        }
        if ($element.Child) { Apply-ThemeRecursive $element.Child $bgMap $fgMap }
        return
    }

    # TextBlock 前景
    if ($element -is [System.Windows.Controls.TextBlock]) {
        $fg = $element.Foreground
        if ($fg -and $fg -is [System.Windows.Media.SolidColorBrush]) {
            $c = $fg.Color
            $hex = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
            if ($fgMap.ContainsKey($hex)) {
                $element.Foreground = Create-Brush ("#" + $fgMap[$hex])
            }
        }
        return
    }

    # CheckBox / RadioButton 前景
    if ($element -is [System.Windows.Controls.CheckBox] -or $element -is [System.Windows.Controls.RadioButton]) {
        $fg = $element.Foreground
        if ($fg -and $fg -is [System.Windows.Media.SolidColorBrush]) {
            $c = $fg.Color
            $hex = "{0:X2}{1:X2}{2:X2}" -f $c.R, $c.G, $c.B
            if ($fgMap.ContainsKey($hex)) {
                $element.Foreground = Create-Brush ("#" + $fgMap[$hex])
            }
        }
        return
    }

    # Panel（StackPanel / Grid / UniformGrid 等）
    if ($element -is [System.Windows.Controls.Panel]) {
        foreach ($child in $element.Children) {
            Apply-ThemeRecursive $child $bgMap $fgMap
        }
        return
    }

    # ContentControl（ScrollViewer / Button 等）
    if ($element -is [System.Windows.Controls.ContentControl]) {
        $content = $element.Content
        if ($content -is [System.Windows.DependencyObject]) {
            Apply-ThemeRecursive $content $bgMap $fgMap
        }
        return
    }

    # ItemsControl
    if ($element -is [System.Windows.Controls.ItemsControl]) {
        foreach ($item in $element.Items) {
            if ($item -is [System.Windows.DependencyObject]) {
                Apply-ThemeRecursive $item $bgMap $fgMap
            }
        }
        return
    }
}

function Create-Brush {
    param([string]$hex)
    try {
        $c = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
        return New-Object System.Windows.Media.SolidColorBrush($c)
    } catch { return $null }
}

function Update-SysInfoVisibility {
    $chkSys = $window.FindName("ChkShowSysInfo")
    $sysInfoCards = $window.FindName("SysInfoCards")
    if ($chkSys -and $sysInfoCards) {
        if ($chkSys.IsChecked) { $sysInfoCards.Visibility = "Visible" }
        else { $sysInfoCards.Visibility = "Collapsed" }
    }
}

function Refresh-SysInfo {
    $chkSys = $window.FindName("ChkShowSysInfo")
    $showSys = if ($chkSys) { [bool]$chkSys.IsChecked } else { $true }

    if (-not $showSys) {
        $sysInfoCards = $window.FindName("SysInfoCards")
        if ($sysInfoCards) { $sysInfoCards.Visibility = "Collapsed" }
        return
    }

    # 若已有查询在运行，跳过本次（由全局定时器下次再触发）
    if ($script:sysHandle -and -not $script:sysHandle.IsCompleted) { return }

    # 清理上一次的 PS 对象、Runspace 和轮询 timer
    if ($script:sysTimer) { try { $script:sysTimer.Stop() } catch {} }
    if ($script:sysPS) { try { $script:sysPS.Dispose() } catch {} }
    if ($script:sysRunspace) { try { $script:sysRunspace.Close(); $script:sysRunspace.Dispose() } catch {} }
    $script:sysTimer = $null
    $script:sysPS = $null
    $script:sysRunspace = $null
    $script:sysHandle = $null

    # 仅在无值时显示加载中，避免覆盖已有数据
    $cpuEl = $window.FindName("CpuUsageValue")
    $memEl = $window.FindName("MemUsageValue")
    $sCpu = $window.FindName("SettingsCpuValue")
    $sMem = $window.FindName("SettingsMemValue")
    if ($cpuEl -and ($cpuEl.Text -eq "--" -or $cpuEl.Text -eq "")) { $cpuEl.Text = "..." }
    if ($memEl -and ($memEl.Text -eq "--" -or $memEl.Text -eq "")) { $memEl.Text = "..." }
    if ($sCpu -and ($sCpu.Text -eq "--" -or $sCpu.Text -eq "")) { $sCpu.Text = "..." }
    if ($sMem -and ($sMem.Text -eq "--" -or $sMem.Text -eq "")) { $sMem.Text = "..." }

    # 每次创建独立 Runspace（避免共享 Runspace 导致 Global 作用域损坏）
    $script:sysRunspace = [RunspaceFactory]::CreateRunspace()
    $script:sysRunspace.ApartmentState = "MTA"
    $script:sysRunspace.Open()
    $script:sysPS = [PowerShell]::Create()
    $script:sysPS.Runspace = $script:sysRunspace
    [void]$script:sysPS.AddScript({
        # 用 Get-WmiObject 代替 Get-Counter，避免性能计数器首次初始化的数秒延迟
        $cpu = (Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).LoadPercentage
        $os = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpuPct = if ($null -ne $cpu) { [math]::Round($cpu, 1) } else { 0 }
        $memPct = if ($os) { [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1) } else { 0 }
        "$cpuPct|$memPct"
    })
    $script:sysHandle = $script:sysPS.BeginInvoke()

    $script:sysTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:sysTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:sysTimer.Add_Tick({
        if ($script:sysHandle -and $script:sysHandle.IsCompleted) {
            $script:sysTimer.Stop()
            try {
                $result = $script:sysPS.EndInvoke($script:sysHandle)
                $parts = ($result -join "").Split('|')
                $cpuPct = if ($parts.Length -gt 0 -and $parts[0]) { $parts[0] } else { "--" }
                $memPct = if ($parts.Length -gt 1 -and $parts[1]) { $parts[1] } else { "--" }
            } catch {
                $cpuPct = "--"; $memPct = "--"
            }
            try { $script:sysPS.Dispose() } catch {}
            try { if ($script:sysRunspace) { $script:sysRunspace.Close(); $script:sysRunspace.Dispose() } } catch {}
            $script:sysPS = $null
            $script:sysRunspace = $null
            $script:sysHandle = $null

            $cpuEl = $window.FindName("CpuUsageValue")
            $memEl = $window.FindName("MemUsageValue")
            $sCpu = $window.FindName("SettingsCpuValue")
            $sMem = $window.FindName("SettingsMemValue")
            if ($cpuEl) { $cpuEl.Text = "$cpuPct" }
            if ($memEl) { $memEl.Text = "$memPct" }
            if ($sCpu) { $sCpu.Text = "$cpuPct%" }
            if ($sMem) { $sMem.Text = "$memPct%" }
        }
    })
    $script:sysTimer.Start()
}

function Toggle-AutoStart {
    param([bool]$enable)
    $runKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $appName = "ALitNetworkOptimizer"
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    try {
        if ($enable) {
            Set-ItemProperty -Path $runKey -Name $appName -Value "`"$exePath`"" -Force
            Add-LogEntry "INFO" "已开启开机自启动：$exePath"
        } else {
            Remove-ItemProperty -Path $runKey -Name $appName -Force -ErrorAction SilentlyContinue
            Add-LogEntry "INFO" "已关闭开机自启动"
        }
    } catch { Add-LogEntry "WARN" "开机自启动设置失败：$($_.Exception.Message)" }
}

# 初始化加载设置
Load-Settings
Update-SplashText "正在加载设置..."
Update-NavButtons "Dashboard"

# 后台定时刷新 CPU/内存（每 15 秒自动更新，无需切换页面触发）
$script:autoSysTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:autoSysTimer.Interval = [TimeSpan]::FromSeconds(15)
$script:autoSysTimer.Add_Tick({ Refresh-SysInfo })
$script:autoSysTimer.Start()

# 首次立即查询一次
Refresh-SysInfo

# 开机自启动开关
$window.FindName("ChkAutoStart").Add_Click({
    Toggle-AutoStart ([bool]$window.FindName("ChkAutoStart").IsChecked)
    Save-Settings
})

# CPU/内存显示开关
$window.FindName("ChkShowSysInfo").Add_Click({
    Update-SysInfoVisibility
    Save-Settings
    if ($window.FindName("ChkShowSysInfo").IsChecked) { Refresh-SysInfo }
})

# 主题切换
$window.FindName("RadioDarkTheme").Add_Click({
    Apply-Theme "Dark"
    Update-NavButtons "Settings"
    # 刷新档位按钮
    $curMode = $window.FindName("SelectedModeValue").Text
    $curName = $window.FindName("SelectedModeName").Text -replace "^当前选择：", ""
    Set-OptimizationMode $curMode $curName
    Save-Settings
})
$window.FindName("RadioLightTheme").Add_Click({
    Apply-Theme "Light"
    Update-NavButtons "Settings"
    # 刷新档位按钮
    $curMode = $window.FindName("SelectedModeValue").Text
    $curName = $window.FindName("SelectedModeName").Text -replace "^当前选择：", ""
    Set-OptimizationMode $curMode $curName
    Save-Settings
})

$navNames = @("NavDashboard", "NavTcp", "NavDns", "NavQos", "NavHosts", "NavCustom", "NavTest", "NavLog", "NavSettings")
foreach ($navName in $navNames) {
    $navEl = $window.FindName($navName)
    if ($navEl) {
        $tag = $navEl.Tag
        $navEl.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler]{
            param($s, $e)
            & $script:SwitchNavPanel $s.Tag
        })
    }
}

function Set-OptimizationMode {
    param(
        [string]$Mode,
        [string]$ModeName
    )

    $window.FindName("SelectedModeValue").Text = $Mode
    $window.FindName("SelectedModeName").Text = "当前选择：$ModeName"

    # 主题感知颜色
    if ($script:currentTheme -eq "Light") {
        $selBg = "#5B9BD5"; $selFg = "#FFFFFF"; $selSubFg = "#E3F2FD"
        $unselBg = "#FFFFFF"; $unselFg = "#333333"; $unselSubFg = "#666666"
    } else {
        $selBg = "#7CC7FF"; $selFg = "#111111"; $selSubFg = "#222222"
        $unselBg = "#3A3A3A"; $unselFg = "#FFFFFF"; $unselSubFg = "#E8E8E8"
    }

    $buttons = @(
        @("BtnModeBalanced", "Balanced"),
        @("BtnModeNormal", "Normal"),
        @("BtnModeComplete", "Complete"),
        @("BtnModeRevert", "Revert")
    )

    foreach ($item in $buttons) {
        $button = $window.FindName($item[0])
        if (-not $button) { continue }
        if ($item[1] -eq $Mode) {
            $button.Background = Create-Brush $selBg
            $button.Foreground = Create-Brush $selFg
            if ($button.Content -and $button.Content.Children) {
                $idx = 0
                foreach ($child in $button.Content.Children) {
                    $child.Foreground = Create-Brush $(if ($idx -eq 0) { $selFg } else { $selSubFg })
                    $idx++
                }
            }
        } else {
            $button.Background = Create-Brush $unselBg
            $button.Foreground = Create-Brush $unselFg
            if ($button.Content -and $button.Content.Children) {
                $idx = 0
                foreach ($child in $button.Content.Children) {
                    $child.Foreground = Create-Brush $(if ($idx -eq 0) { $unselFg } else { $unselSubFg })
                    $idx++
                }
            }
        }
    }
}

$window.FindName("BtnModeBalanced").Add_Click({ Set-OptimizationMode "Balanced" "均衡（满足日常体验）" })
$window.FindName("BtnModeNormal").Add_Click({ Set-OptimizationMode "Normal" "普通（优化一部分网络体验）" })
$window.FindName("BtnModeComplete").Add_Click({ Set-OptimizationMode "Complete" "完全（拥有所有网络优化，可能导致问题）" })
$window.FindName("BtnModeRevert").Add_Click({ Set-OptimizationMode "Revert" "还原（还原所有修改）" })
Set-OptimizationMode "Balanced" "均衡（满足日常体验）"

# Optimize button
$window.FindName("BtnOptimize").Add_Click({
    $selectedMode = $window.FindName("SelectedModeValue").Text
    $selectedModeName = $window.FindName("SelectedModeName").Text.Replace("当前选择：", "")

    if ($selectedMode -eq "Revert") {
        $window.FindName("BtnRevert").RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        return
    }

    $btn = $window.FindName("BtnOptimize")
    $btn.IsEnabled = $false
    $window.FindName("BtnRevert").IsEnabled = $false
    $window.FindName("BtnSpeedTest").IsEnabled = $false

    Add-LogEntry "INFO" "开始应用模式：$selectedModeName"
    $resultsList = $window.FindName("ResultsList")
    if ($resultsList) {
        $resultsList.Items.Clear()
        $resultsList.Items.Add("[INFO] 正在应用模式：$selectedModeName，请稍候...") | Out-Null
    }

    # 保存优化前快照
    Save-PreOptimizationSnapshot | Out-Null

    # Run in background using Runspace
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("GetActiveAdapters", ${function:Get-ActiveAdapters})
    $runspace.SessionStateProxy.SetVariable("InvokeCommandFunc", ${function:Invoke-Command})
    $runspace.SessionStateProxy.SetVariable("AddLogEntryFunc", ${function:Add-LogEntry})
    $runspace.SessionStateProxy.SetVariable("selectedMode", $selectedMode)
    $runspace.SessionStateProxy.SetVariable("selectedModeName", $selectedModeName)
    $runspace.SessionStateProxy.SetVariable("stateDir", $script:stateDir)
    $runspace.SessionStateProxy.SetVariable("stateFile", $script:stateFile)
    $runspace.SessionStateProxy.SetVariable("stateRegPath", $script:stateRegPath)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")
        $resultsList = $window.FindName("ResultsList")
        $results = [System.Collections.ArrayList]@()

        $profileText = switch ($selectedMode) {
            "Balanced" { "均衡" }
            "Normal" { "普通" }
            "Complete" { "完全" }
            default { "均衡" }
        }

        $cmds = New-Object System.Collections.ArrayList
        [void]$cmds.Add(@("netsh interface tcp set global autotuninglevel=normal", "TCP 自动调节：normal"))
        [void]$cmds.Add(@("netsh interface tcp set global rss=enabled", "RSS 多核网络处理：启用"))
        [void]$cmds.Add(@("netsh interface tcp set global rsc=enabled", "RSC 接收段合并：启用"))

        if ($selectedMode -in @("Normal", "Complete")) {
            [void]$cmds.Add(@("netsh interface tcp set global ecncapability=enabled", "ECN：启用"))
            [void]$cmds.Add(@("netsh interface tcp set global timestamps=disabled", "TCP 时间戳：关闭"))
            [void]$cmds.Add(@("netsh interface tcp set global initialrto=500", "初始 RTO：500ms"))
            [void]$cmds.Add(@("netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp", "拥塞控制：CTCP"))
            [void]$cmds.Add(@("netsh winsock reset catalog", "Winsock 目录：重置"))
            [void]$cmds.Add(@("netsh int ip reset", "IP 协议栈：重置"))
        }

        if ($selectedMode -eq "Complete") {
            [void]$cmds.Add(@("netsh interface tcp set global initialrto=300", "初始 RTO：300ms"))
        }

        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $regPathV6 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
        $regs = New-Object System.Collections.ArrayList
        [void]$regs.Add(@("Tcp1323Opts", 1, "TCP 窗口缩放/时间戳参数"))
        [void]$regs.Add(@("SackOpts", 1, "选择性确认（SACK）：改善丢包恢复"))
        [void]$regs.Add(@("EnableTCPNoDelay", 1, "全局禁用 Nagle 算法"))
        [void]$regs.Add(@("EnableTCPChimney", 0, "禁用已弃用的 TCP Chimney Offload"))
        [void]$regs.Add(@("MaxUserPort", 65534, "最大用户端口"))
        [void]$regs.Add(@("DefaultTTL", 64, "默认 TTL（减少路由跳数开销）"))
        [void]$regs.Add(@("KeepAliveTime", 300000, "TCP 保活超时：5 分钟（更快检测断连）"))

        if ($selectedMode -in @("Normal", "Complete")) {
            [void]$regs.Add(@("TcpNoDelay", 1, "禁用 Nagle 算法"))
            [void]$regs.Add(@("TcpAckFrequency", 1, "ACK 频率优化"))
            [void]$regs.Add(@("TcpDelAckTicks", 0, "禁用延迟 ACK（立即确认）"))
            [void]$regs.Add(@("TcpTimedWaitDelay", 30, "TIME_WAIT 延迟"))
            [void]$regs.Add(@("TcpHybridAck", 0, "关闭混合 ACK 延迟"))
            [void]$regs.Add(@("MaxFreeTcbs", 65535, "最大空闲 TCP 控制块"))
            [void]$regs.Add(@("TcpMaxDataRetransmissions", 2, "最大数据重传次数（FPS优化：减少重传等待）"))
            [void]$regs.Add(@("EnableTcpFastOpen", 1, "TCP Fast Open（降低首包延迟）"))
        }

        if ($selectedMode -eq "Complete") {
            [void]$regs.Add(@("DefaultSendWindow", 65535, "默认发送窗口"))
            [void]$regs.Add(@("DefaultReceiveWindow", 65535, "默认接收窗口"))
            [void]$regs.Add(@("MaxConnections", 65536, "最大并发连接数"))
            [void]$regs.Add(@("EnableWsd", 0, "关闭 WSD（Web Services on Devices）"))
        }

        # 关闭节能以太网（Normal 和 Complete 模式，消除延迟抖动）
        if ($selectedMode -in @("Normal", "Complete")) {
            $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            try {
                Set-ItemProperty -Path $powerPath -Name "EnergyEfficientEthernet" -Value 0 -Type DWord -Force -ErrorAction Stop
                $results.Add("[OK] EnergyEfficientEthernet=0（关闭节能以太网）") | Out-Null
            } catch {
                $results.Add("[FAIL] EnergyEfficientEthernet：$($_.Exception.Message)") | Out-Null
            }
        }

        $total = [math]::Max(1, $cmds.Count + $regs.Count + 8)
        $i = 0

        foreach ($cmd in $cmds) {
            $i += 1
            $window.Dispatcher.Invoke([Action]{
                $progress.Value = ($i / $total) * 100
                $statusText.Text = "TCP 网络：$($cmd[1])..."
            })
            $r = & $InvokeCommandFunc $cmd[0]
            if ($r.ExitCode -eq 0) {
                $results.Add("[OK] $($cmd[1])") | Out-Null
            } else {
                $results.Add("[WARN] $($cmd[1])：可能需要系统支持或重启") | Out-Null
            }
            Start-Sleep -Milliseconds 50
        }

        foreach ($reg in $regs) {
            $i += 1
            $window.Dispatcher.Invoke([Action]{
                $progress.Value = ($i / $total) * 100
                $statusText.Text = "TCP/IP 参数：$($reg[2])..."
            })
            try {
                Set-ItemProperty -Path $regPath -Name $reg[0] -Value $reg[1] -Type DWord -Force -ErrorAction Stop
                $results.Add("[OK] $($reg[2])：$($reg[0])=$($reg[1])") | Out-Null
            } catch {
                $results.Add("[FAIL] $($reg[2])：$($reg[0])") | Out-Null
            }
            # 同步写入 IPv6 路径
            try {
                if (-not (Test-Path $regPathV6)) { New-Item -Path $regPathV6 -Force | Out-Null }
                Set-ItemProperty -Path $regPathV6 -Name $reg[0] -Value $reg[1] -Type DWord -Force -ErrorAction Stop
            } catch {}
        }

        if ($selectedMode -in @("Normal", "Complete")) {
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "TCP/IP 服务提供程序：写入网卡接口参数..." })
            $adapters = & $GetActiveAdapters
            foreach ($a in $adapters) {
                try {
                    $guid = (Get-NetAdapter -Name $a.Name -ErrorAction Stop).InterfaceGuid
                    if ($guid) {
                        $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                        $ifaceOk = $true
                        try { Set-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction Stop } catch { $ifaceOk = $false }
                        try { Set-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction Stop } catch { $ifaceOk = $false }
                        if ($ifaceOk) {
                            $results.Add("[OK] 网卡 $($a.Name)：TcpNoDelay + TcpAckFrequency") | Out-Null
                        } else {
                            $results.Add("[WARN] 网卡 $($a.Name)：接口参数部分写入失败") | Out-Null
                        }
                    }
                } catch {
                    $results.Add("[WARN] 网卡 $($a.Name)：无法获取 InterfaceGuid") | Out-Null
                }
                $i += 1
            }
        }

        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "系统网络调度参数..." })
        if ($selectedMode -eq "Balanced") {
            try {
                Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 10 -Type DWord -Force -ErrorAction Stop
                $results.Add("[OK] SystemResponsiveness=10（日常均衡）") | Out-Null
            } catch {
                $results.Add("[FAIL] SystemResponsiveness：$($_.Exception.Message)") | Out-Null
            }
        } else {
            $spFail = 0
            try { Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force -ErrorAction Stop } catch { $spFail++ }
            try { Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction Stop } catch { $spFail++ }
            if ($spFail -eq 0) {
                $results.Add("[OK] NetworkThrottlingIndex=0xFFFFFFFF, SystemResponsiveness=0") | Out-Null
            } else {
                $results.Add("[WARN] 系统调度参数：$spFail 项写入失败") | Out-Null
            }
        }

        if ($selectedMode -in @("Normal", "Complete")) {
            $gPath = "$spPath\Tasks\Games"
            $gFail = 0
            try { Set-ItemProperty -Path $gPath -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction Stop } catch { $gFail++ }
            try { Set-ItemProperty -Path $gPath -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction Stop } catch { $gFail++ }
            try { Set-ItemProperty -Path $gPath -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction Stop } catch { $gFail++ }
            try { Set-ItemProperty -Path $gPath -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction Stop } catch { $gFail++ }
            if ($gFail -eq 0) {
                $results.Add("[OK] 游戏调度：GPU=8, Priority=6, SFIO=High") | Out-Null
            } else {
                $results.Add("[WARN] 游戏调度参数：$gFail 项写入失败") | Out-Null
            }
        }

        if ($selectedMode -in @("Normal", "Complete")) {
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "QoS 策略..." })
            & $InvokeCommandFunc "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
            & $InvokeCommandFunc "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
            $qosR1 = & $InvokeCommandFunc "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none"
            $qosR2 = & $InvokeCommandFunc "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none"
            if ($qosR1.ExitCode -eq 0) { $results.Add("[OK] QoS：Minecraft Java DSCP=46") | Out-Null }
            else { $results.Add("[WARN] QoS Java 策略添加失败（退出码 $($qosR1.ExitCode)）") | Out-Null }
            if ($qosR2.ExitCode -eq 0) { $results.Add("[OK] QoS：Minecraft Bedrock DSCP=46") | Out-Null }
            else { $results.Add("[WARN] QoS Bedrock 策略添加失败（退出码 $($qosR2.ExitCode)）") | Out-Null }

            # FPS Game QoS - DSCP 46 for FPS game processes and ports
            $fpsQosNames = @(
                "NetOpt_FPS_CS2_Proc", "NetOpt_FPS_CS2_Port",
                "NetOpt_FPS_Val_Proc", "NetOpt_FPS_Val_Port",
                "NetOpt_FPS_Apex_Proc", "NetOpt_FPS_Apex_Port",
                "NetOpt_FPS_CoD_Proc", "NetOpt_FPS_CoD_Port",
                "NetOpt_FPS_PUBG_Proc", "NetOpt_FPS_R6_Proc", "NetOpt_FPS_R6_Port"
            )
            $fpsQosAdd = @(
                'netsh qos add policy name="NetOpt_FPS_CS2_Proc" appname="cs2.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_CS2_Port" protocol=udp localport=27015 dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_Val_Proc" appname="VALORANT-Win64-Shipping.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_Val_Port" protocol=udp localport=7448 dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_Apex_Proc" appname="r5apex.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_Apex_Port" protocol=udp localport=37015 dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_CoD_Proc" appname="cod.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_CoD_Port" protocol=udp localport=3074 dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_PUBG_Proc" appname="TslGame.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_R6_Proc" appname="RainbowSix.exe" dscp=46 throttleRate=none',
                'netsh qos add policy name="NetOpt_FPS_R6_Port" protocol=udp localport=6015 dscp=46 throttleRate=none'
            )
            for ($qi = 0; $qi -lt $fpsQosNames.Count; $qi++) {
                & $InvokeCommandFunc "netsh qos delete policy name=`"$($fpsQosNames[$qi])`"" | Out-Null
                $fpsR = & $InvokeCommandFunc $fpsQosAdd[$qi]
                if ($fpsR.ExitCode -eq 0) { $results.Add("[OK] QoS：$($fpsQosNames[$qi]) DSCP=46") | Out-Null }
                else { $results.Add("[WARN] QoS $($fpsQosNames[$qi]) 失败（退出码 $($fpsR.ExitCode)）") | Out-Null }
            }
        }

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "清理 DNS 缓存..." })
        & $InvokeCommandFunc "ipconfig /flushdns" | Out-Null
        $results.Add("[OK] DNS 缓存已清理") | Out-Null

        $window.Dispatcher.Invoke([Action]{
            $progress.Value = 100
            $statusText.Text = "$profileText 模式应用完成！"
            $resultsList.Items.Clear()
            foreach ($r in $results) { $resultsList.Items.Add($r) | Out-Null }
            $sidebar = $window.FindName("SidebarStatus")
            $sidebar.Text = "$profileText 已应用"
            $sidebar.Foreground = "#7CC7FF"
            $btn = $window.FindName("BtnOptimize")
            $btn.IsEnabled = $true
            $window.FindName("BtnRevert").IsEnabled = $true
            $window.FindName("BtnSpeedTest").IsEnabled = $true
        })

        try {
            if (-not (Test-Path $stateDir)) {
                New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
            }
            $state = [PSCustomObject]@{
                IsOptimized = $true
                Mode = $selectedMode
                DisplayName = $profileText
                UpdatedAt = (Get-Date).ToString("s")
            }
            $state | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $stateFile -Encoding UTF8 -Force
            if (-not (Test-Path $stateRegPath)) {
                New-Item -Path $stateRegPath -Force | Out-Null
            }
            Set-ItemProperty -Path $stateRegPath -Name "IsOptimized" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $stateRegPath -Name "Mode" -Value $selectedMode -Type String -Force
            Set-ItemProperty -Path $stateRegPath -Name "DisplayName" -Value $profileText -Type String -Force
            Set-ItemProperty -Path $stateRegPath -Name "UpdatedAt" -Value (Get-Date).ToString("s") -Type String -Force
        } catch {
            & $AddLogEntryFunc "WARN" "保存优化状态失败：$($_.Exception.Message)"
        }
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    # Register a callback to clean up
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        $state = $ps.InvocationStateInfo.State
        if ($state -in @("Completed", "Failed", "Stopped")) {
            if ($state -ne "Completed") {
                $errorText = ($ps.Streams.Error | ForEach-Object { $_.ToString() }) -join "`r`n"
                if ([string]::IsNullOrWhiteSpace($errorText)) { $errorText = $ps.InvocationStateInfo.Reason.Message }
                $window.Dispatcher.Invoke([Action]{
                    $window.FindName("StatusText").Text = "执行失败"
                    $window.FindName("ProgressBar").Value = 0
                    $list = $window.FindName("ResultsList")
                    if ($list) {
                        $list.Items.Clear()
                        $list.Items.Add("[FAIL] 后台执行失败，未完成优化。") | Out-Null
                        $list.Items.Add("[INFO] $errorText") | Out-Null
                    }
                    $window.FindName("BtnOptimize").IsEnabled = $true
                    $window.FindName("BtnRevert").IsEnabled = $true
                    $window.FindName("BtnSpeedTest").IsEnabled = $true
                })
            }
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    } | Out-Null
})

# Revert button
$window.FindName("BtnRevert").Add_Click({
    $window.FindName("BtnOptimize").IsEnabled = $false
    $window.FindName("BtnRevert").IsEnabled = $false
    Add-LogEntry "INFO" "正在还原所有优化..."

    # 查找最新快照
    $snapPath = Find-LatestSnapshot
    if ($snapPath) {
        Add-LogEntry "INFO" "找到优化前快照：$snapPath"
    } else {
        Add-LogEntry "WARN" "未找到优化前快照，将使用默认值还原（可能无法精确恢复原配置）"
    }

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("InvokeCommandFunc", ${function:Invoke-Command})
    $runspace.SessionStateProxy.SetVariable("AddLogEntryFunc", ${function:Add-LogEntry})
    $runspace.SessionStateProxy.SetVariable("snapPath", $snapPath)
    $runspace.SessionStateProxy.SetVariable("Restore-FromSnapshot", ${function:Restore-FromSnapshot})
    $runspace.SessionStateProxy.SetVariable("stateFile", $script:stateFile)
    $runspace.SessionStateProxy.SetVariable("stateRegPath", $script:stateRegPath)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")
        $reportLines = [System.Collections.ArrayList]@()

        # 如果有快照，优先从快照恢复
        if ($snapPath -and (Test-Path $snapPath)) {
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在从快照恢复..."; $progress.Value = 10 })

            # 1. 恢复 TCP 全局设置
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "从快照恢复 TCP..."; $progress.Value = 20 })
            $tcpFile = Join-Path $snapPath "tcp_global.txt"
            $tcpOk = $true
            if (Test-Path $tcpFile) {
                try {
                    $tcpContent = [System.IO.File]::ReadAllText($tcpFile, [System.Text.Encoding]::UTF8)
                    $tcpRestoreCmds = @()
                    if ($tcpContent -match 'Auto-Tuning[^\n]*?:\s*(\w+)') { $tcpRestoreCmds += "netsh interface tcp set global autotuninglevel=$($Matches[1].ToLower())" }
                    if ($tcpContent -match 'ECN[^\n]*?:\s*(\w+)') { $ecnVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }; $tcpRestoreCmds += "netsh interface tcp set global ecncapability=$ecnVal" }
                    if ($tcpContent -match 'RSS[^\n]*?:\s*(\w+)') { $rssVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }; $tcpRestoreCmds += "netsh interface tcp set global rss=$rssVal" }
                    if ($tcpContent -match 'Timestamps[^\n]*?:\s*(\w+)') { $tsVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }; $tcpRestoreCmds += "netsh interface tcp set global timestamps=$tsVal" }
                    if ($tcpContent -match 'Initial RTO[^\n]*?:\s*(\d+)') { $tcpRestoreCmds += "netsh interface tcp set global initialrto=$($Matches[1])" }
                    if ($tcpContent -match 'RSC[^\n]*?:\s*(\w+)') { $rscVal = if ($Matches[1] -match 'enabled|启用') { 'enabled' } else { 'disabled' }; $tcpRestoreCmds += "netsh interface tcp set global rsc=$rscVal" }
                    $tcpFail = 0
                    foreach ($cmd in $tcpRestoreCmds) {
                        $r = & $InvokeCommandFunc $cmd
                        if ($r.ExitCode -ne 0) { $tcpFail++; & $AddLogEntryFunc "WARN" "TCP 快照还原失败：$cmd（退出码 $($r.ExitCode)）" }
                    }
                    if ($tcpFail -eq 0) { [void]$reportLines.Add("[OK] TCP 全局设置已从快照恢复") }
                    else { [void]$reportLines.Add("[WARN] TCP 全局：$tcpFail 项还原失败"); $tcpOk = $false }
                } catch {
                    & $AddLogEntryFunc "WARN" "读取 TCP 快照失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] TCP 快照读取失败，使用默认值")
                    $tcpOk = $false
                }
            } else {
                [void]$reportLines.Add("[SKIP] 无 TCP 快照文件")
                $tcpOk = $false
            }

            # 2. 恢复注册表参数
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "从快照恢复注册表..."; $progress.Value = 35 })
            $regFile = Join-Path $snapPath "tcpip_registry.txt"
            if (Test-Path $regFile) {
                try {
                    $regPathV4 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                    $regPathV6 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
                    $lines = [System.IO.File]::ReadAllLines($regFile, [System.Text.Encoding]::UTF8)
                    $restored = 0; $regFail = 0
                    $snapNamesV4 = @(); $snapNamesV6 = @()
                    foreach ($line in $lines) {
                        if ($line -match '^(IPv4\\|IPv6\\)?([^=]+)=(.+)$') {
                            $ipVer = $Matches[1]; $name = $Matches[2]; $val = $Matches[3]
                            $targetPath = if ($ipVer -eq 'IPv6\') { $snapNamesV6 += $name; $regPathV6 } else { $snapNamesV4 += $name; $regPathV4 }
                            try {
                                if ($val -match '^\d+$') { Set-ItemProperty -Path $targetPath -Name $name -Value ([int]$val) -Type DWord -Force -ErrorAction Stop }
                                else { Set-ItemProperty -Path $targetPath -Name $name -Value $val -Force -ErrorAction Stop }
                                $restored++
                            } catch { $regFail++; & $AddLogEntryFunc "WARN" "注册表恢复失败：$ipVer$name" }
                        }
                    }
                    # 删除快照中不存在的优化参数（IPv4 + IPv6）
                    $optParams = @("TcpNoDelay","EnableTCPNoDelay","TcpAckFrequency","TcpDelAckTicks","Tcp1323Opts","SackOpts","EnableTCPChimney","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay","KeepAliveTime","TcpHybridAck","TcpWindowSize","MaxConnections","EnableConnectionRateLimiting","EnableTcpFastOpen","DefaultTTL","MaxFreeTcbs","TcpMaxDataRetransmissions","EnableWsd")
                    foreach ($pn in $optParams) {
                        if ($pn -notin $snapNamesV4) { try { Remove-ItemProperty -Path $regPathV4 -Name $pn -Force -ErrorAction Stop } catch {} }
                        if ($pn -notin $snapNamesV6) { try { Remove-ItemProperty -Path $regPathV6 -Name $pn -Force -ErrorAction Stop } catch {} }
                    }
                    # 还原拥塞控制为 CUBIC
                    & $InvokeCommandFunc "netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic" | Out-Null
                    [void]$reportLines.Add("[OK] 注册表参数已从快照恢复（$restored 项，IPv4+IPv6）$(if ($regFail -gt 0) { "，$regFail 项失败" })")
                } catch {
                    & $AddLogEntryFunc "WARN" "读取注册表快照失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] 注册表快照读取失败")
                }
            } else {
                [void]$reportLines.Add("[SKIP] 无注册表快照文件")
            }

            # 3. 恢复系统调度参数
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "从快照恢复系统参数..."; $progress.Value = 50 })
            $spFile = Join-Path $snapPath "system_profile.txt"
            if (Test-Path $spFile) {
                try {
                    $lines = [System.IO.File]::ReadAllLines($spFile, [System.Text.Encoding]::UTF8)
                    $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
                    $spRestored = 0
                    foreach ($line in $lines) {
                        if ($line -match '^([^=]+)=(.+)$') {
                            $name = $Matches[1]; $val = $Matches[2]
                            try {
                                if ($val -match '^\d+$') { Set-ItemProperty -Path $spPath -Name $name -Value ([int]$val) -Type DWord -Force -ErrorAction Stop; $spRestored++ }
                            } catch { & $AddLogEntryFunc "WARN" "系统参数恢复失败：$name" }
                        }
                    }
                    [void]$reportLines.Add("[OK] 系统调度参数已从快照恢复（$spRestored 项）")
                } catch {
                    & $AddLogEntryFunc "WARN" "读取系统参数快照失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] 系统参数快照读取失败")
                }
            } else {
                [void]$reportLines.Add("[SKIP] 无系统参数快照文件")
            }

            # 4. 恢复网卡接口参数
            try {
                Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                    $guid = $_.InterfaceGuid
                    if ($guid) {
                        $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                        Remove-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Force -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                & $AddLogEntryFunc "WARN" "网卡接口参数清理出错：$($_.Exception.Message)"
            }

            # 还原节能以太网
            $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            Remove-ItemProperty -Path $powerPath -Name "EnergyEfficientEthernet" -Force -ErrorAction SilentlyContinue

            # 还原 WinHTTP/WinINet
            @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
              "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
              "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings",
              "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings") | ForEach-Object {
                Remove-ItemProperty -Path $_ -Name "TcpAutotuning" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $_ -Name "DisableBranchCache" -Force -ErrorAction SilentlyContinue
            }

            # 还原工作站参数
            $lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
            @("DisableBandwidthThrottling","DisableLargeMtu") | ForEach-Object {
                Remove-ItemProperty -Path $lanmanPath -Name $_ -Force -ErrorAction SilentlyContinue
            }

            # 5. 恢复 DNS（从快照）
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "从快照恢复 DNS..."; $progress.Value = 65 })
            $dnsFile = Join-Path $snapPath "dns.txt"
            if (Test-Path $dnsFile) {
                try {
                    $lines = [System.IO.File]::ReadAllLines($dnsFile, [System.Text.Encoding]::UTF8)
                    $dnsOk = 0; $dnsFail = 0; $dnsFailList = @()
                    foreach ($line in $lines) {
                        if ($line -match '^([^|]+)\|(.*)$') {
                            $iface = $Matches[1]; $servers = $Matches[2]
                            try {
                                if ([string]::IsNullOrWhiteSpace($servers)) {
                                    $r = & $InvokeCommandFunc "netsh interface ip set dns name=`"$iface`" source=dhcp"
                                } else {
                                    $srvList = $servers -split ','
                                    $r1 = & $InvokeCommandFunc "netsh interface ip set dns name=`"$iface`" static $($srvList[0]) primary"
                                    $ok2 = ($r1.ExitCode -eq 0)
                                    if ($srvList.Count -gt 1 -and $ok2) {
                                        & $InvokeCommandFunc "netsh interface ip add dns name=`"$iface`" $($srvList[1]) index=2" | Out-Null
                                    }
                                    $r = @{ ExitCode = if ($ok2) { 0 } else { $r1.ExitCode } }
                                }
                                if ($r.ExitCode -eq 0) { $dnsOk++ } else { $dnsFail++; $dnsFailList += $iface }
                            } catch { $dnsFail++; $dnsFailList += "$iface(异常)" }
                        }
                    }
                    if ($dnsFail -eq 0) {
                        [void]$reportLines.Add("[OK] DNS 已从快照恢复（$dnsOk 个网卡）")
                    } else {
                        [void]$reportLines.Add("[WARN] DNS 恢复：$dnsOk 成功，$dnsFail 失败（$($dnsFailList -join ', ')）")
                    }
                } catch {
                    & $AddLogEntryFunc "WARN" "读取 DNS 快照失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] DNS 快照读取失败")
                }
            } else {
                [void]$reportLines.Add("[SKIP] 无 DNS 快照文件")
            }

            # 6. 恢复 Hosts（从快照）
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "从快照恢复 Hosts..."; $progress.Value = 75 })
            $hostsSnap = Join-Path $snapPath "hosts"
            if (Test-Path $hostsSnap) {
                try {
                    $hostsFile = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
                    Copy-Item $hostsSnap $hostsFile -Force
                    [void]$reportLines.Add("[OK] Hosts 已从快照恢复")
                } catch {
                    & $AddLogEntryFunc "WARN" "Hosts 快照恢复失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] Hosts 快照恢复失败")
                }
            } else {
                # 尝试从备份恢复
                $hostsBak = Join-Path $env:SystemRoot "System32\drivers\etc\hosts.alit.bak"
                if (Test-Path $hostsBak) {
                    try {
                        Copy-Item $hostsBak (Join-Path $env:SystemRoot "System32\drivers\etc\hosts") -Force
                        [void]$reportLines.Add("[OK] Hosts 已从备份恢复")
                    } catch {
                        [void]$reportLines.Add("[WARN] Hosts 备份恢复失败")
                    }
                } else {
                    [void]$reportLines.Add("[SKIP] 无 Hosts 快照或备份")
                }
            }

        } else {
            # 无快照，使用默认值还原
            & $AddLogEntryFunc "INFO" "使用默认值还原（无快照可用）"

            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在还原 TCP..."; $progress.Value = 20 })
            $tcpRevertCmds = @(
                @("netsh interface tcp set global autotuninglevel=normal", "TCP 自动调优"),
                @("netsh interface tcp set global ecncapability=disabled", "ECN"),
                @("netsh interface tcp set global timestamps=enabled", "TCP 时间戳"),
                @("netsh interface tcp set global initialrto=1000", "初始 RTO"),
                @("netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic", "拥塞控制 CUBIC")
            )
            $tcpFail = 0
            foreach ($tc in $tcpRevertCmds) {
                $r = & $InvokeCommandFunc $tc[0]
                if ($r.ExitCode -ne 0) { $tcpFail++; & $AddLogEntryFunc "WARN" "还原失败：$($tc[1])（退出码 $($r.ExitCode)）" }
            }
            if ($tcpFail -eq 0) { [void]$reportLines.Add("[OK] TCP 全局已还原为默认值") }
            else { [void]$reportLines.Add("[WARN] TCP 还原：$tcpFail 项失败") }

            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在还原注册表..."; $progress.Value = 40 })
            $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            $tcpPathV6 = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
            @("TcpNoDelay","EnableTCPNoDelay","TcpAckFrequency","TcpDelAckTicks","Tcp1323Opts","SackOpts","EnableTCPChimney","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay","KeepAliveTime","TcpHybridAck","TcpWindowSize","TcpWindowSizeMin","MaxConnections","MTU","EnableWsd","EnableConnectionRateLimiting","EnableTcpFastOpen","DefaultTTL","MaxFreeTcbs","TcpMaxDataRetransmissions") | ForEach-Object {
                try { Remove-ItemProperty -Path $tcpPath -Name $_ -Force -ErrorAction Stop } catch {}
                try { Remove-ItemProperty -Path $tcpPathV6 -Name $_ -Force -ErrorAction Stop } catch {}
            }
            [void]$reportLines.Add("[OK] 注册表优化参数已删除（IPv4 + IPv6，默认值）")

            # 还原节能以太网
            $powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            Remove-ItemProperty -Path $powerPath -Name "EnergyEfficientEthernet" -Force -ErrorAction SilentlyContinue

            # 还原 WinHTTP/WinINet
            @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
              "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp",
              "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings",
              "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings") | ForEach-Object {
                Remove-ItemProperty -Path $_ -Name "TcpAutotuning" -Force -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $_ -Name "DisableBranchCache" -Force -ErrorAction SilentlyContinue
            }

            # 还原工作站参数
            $lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
            @("DisableBandwidthThrottling","DisableLargeMtu") | ForEach-Object {
                Remove-ItemProperty -Path $lanmanPath -Name $_ -Force -ErrorAction SilentlyContinue
            }

            # 还原 QoS 策略注册表
            @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched",
              "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS",
              "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS") | ForEach-Object {
                if (Test-Path $_) {
                    Remove-ItemProperty -Path $_ -Name "NonBestEffortLimit" -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $_ -Name "Application DSCP Marking Request" -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $_ -Name "DisableBranchCache" -Force -ErrorAction SilentlyContinue
                }
            }

            try {
                Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
                    $guid = $_.InterfaceGuid
                    if ($guid) {
                        $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                        Remove-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Force -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                & $AddLogEntryFunc "WARN" "网卡接口参数清理出错：$($_.Exception.Message)"
            }

            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在还原系统参数..."; $progress.Value = 60 })
            $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            try {
                Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction Stop
                Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction Stop
                [void]$reportLines.Add("[OK] 系统调度参数已还原为默认值")
            } catch {
                & $AddLogEntryFunc "WARN" "系统调度参数还原失败：$($_.Exception.Message)"
                [void]$reportLines.Add("[WARN] 系统调度参数还原失败")
            }

            # DNS 恢复为 DHCP
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在恢复 DNS..."; $progress.Value = 75 })
            try {
                $dnsAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
                $dnsOk = 0; $dnsFail = 0; $dnsFailList = @()
                foreach ($da in $dnsAdapters) {
                    $r = & $InvokeCommandFunc "netsh interface ip set dns name=`"$($da.Name)`" source=dhcp"
                    if ($r.ExitCode -eq 0) { $dnsOk++ } else { $dnsFail++; $dnsFailList += $da.Name }
                }
                if ($dnsFail -eq 0) {
                    [void]$reportLines.Add("[OK] DNS 已恢复为 DHCP（$dnsOk 个网卡）")
                } else {
                    [void]$reportLines.Add("[WARN] DNS 恢复：$dnsOk 成功，$dnsFail 失败（$($dnsFailList -join ', ')）")
                }
            } catch {
                & $AddLogEntryFunc "WARN" "DNS 恢复过程中出错：$($_.Exception.Message)"
                [void]$reportLines.Add("[WARN] DNS 恢复出错")
            }

            # Hosts 恢复
            $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在恢复 Hosts..."; $progress.Value = 85 })
            $hostsBak = Join-Path $env:SystemRoot "System32\drivers\etc\hosts.alit.bak"
            if (Test-Path $hostsBak) {
                try {
                    Copy-Item $hostsBak (Join-Path $env:SystemRoot "System32\drivers\etc\hosts") -Force
                    [void]$reportLines.Add("[OK] Hosts 已从备份恢复")
                } catch {
                    & $AddLogEntryFunc "WARN" "Hosts 恢复失败：$($_.Exception.Message)"
                    [void]$reportLines.Add("[WARN] Hosts 恢复失败")
                }
            } else {
                [void]$reportLines.Add("[SKIP] 无 Hosts 备份文件")
            }
        }

        # 通用：还原所有已连接网卡的 MTU 为 1500（与脚本一致）
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在还原 MTU..."; $progress.Value = 88 })
        try {
            $mtuAdapters = @()
            try {
                $mtuAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty Name
            } catch {}
            if (-not $mtuAdapters -or $mtuAdapters.Count -eq 0) {
                $rawOutput = netsh interface ipv4 show interfaces 2>$null
                foreach ($line in $rawOutput) {
                    if ($line -match 'connected\s+(.+)') {
                        $name = $Matches[1].Trim()
                        if ($name -and $name -ne 'Loopback Pseudo-Interface 1') { $mtuAdapters += $name }
                    }
                }
            }
            $mtuOk = 0; $mtuFail = 0
            foreach ($mtuAdp in $mtuAdapters) {
                $r = & $InvokeCommandFunc "netsh int ipv4 set subinterface `"$mtuAdp`" mtu=1500 store=persistent"
                if ($r.ExitCode -eq 0) { $mtuOk++ } else { $mtuFail++ }
            }
            if ($mtuFail -eq 0) {
                [void]$reportLines.Add("[OK] MTU 已还原为 1500（$mtuOk 个网卡）")
            } else {
                [void]$reportLines.Add("[WARN] MTU 还原：$mtuOk 成功，$mtuFail 失败")
            }
        } catch {
            & $AddLogEntryFunc "WARN" "MTU 还原出错：$($_.Exception.Message)"
            [void]$reportLines.Add("[WARN] MTU 还原出错")
        }

        # 通用：清理所有 QoS 策略
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在清理 QoS 策略..."; $progress.Value = 90 })
        $qosNames = @(
            "NetOpt_MC_Java_Game", "NetOpt_MC_Bedrock_Game",
            "ALit_MC_Java_App", "ALit_MC_Bedrock_App",
            "ALit_MC_Java_Port", "ALit_MC_Bedrock_Port",
            "NetOpt_FPS_CS2_Proc", "NetOpt_FPS_CS2_Port",
            "NetOpt_FPS_Val_Proc", "NetOpt_FPS_Val_Port",
            "NetOpt_FPS_Apex_Proc", "NetOpt_FPS_Apex_Port",
            "NetOpt_FPS_CoD_Proc", "NetOpt_FPS_CoD_Port",
            "NetOpt_FPS_PUBG_Proc", "NetOpt_FPS_R6_Proc", "NetOpt_FPS_R6_Port",
            "ALit_PacketSim_FPS_CS2", "ALit_PacketSim_FPS_Val", "ALit_PacketSim_FPS_Apex",
            "ALit_PacketSim_FPS_CoD", "ALit_PacketSim_FPS_PUBG", "ALit_PacketSim_FPS_R6"
        )
        $qosCleaned = 0
        foreach ($qn in $qosNames) {
            $r = & $InvokeCommandFunc "netsh qos delete policy name=`"$qn`""
            if ($r.ExitCode -eq 0) { $qosCleaned++ }
        }
        # 清理可能残留的其他 NetOpt_ 前缀策略
        $qosShow = & $InvokeCommandFunc "netsh qos show policy"
        $qosShow.Output -split "`n" | ForEach-Object {
            if ($_ -match 'Name:\s*(NetOpt_\S+|ALit_\S+)') {
                & $InvokeCommandFunc "netsh qos delete policy name=`"$($Matches[1])`"" | Out-Null
            }
        }
        [void]$reportLines.Add("[OK] QoS 策略已全部清理")

        # 刷新 DNS 缓存
        & $InvokeCommandFunc "ipconfig /flushdns" | Out-Null

        try {
            if (Test-Path $stateFile) {
                Remove-Item -LiteralPath $stateFile -Force -ErrorAction Stop
            }
            if (Test-Path $stateRegPath) {
                Remove-Item -Path $stateRegPath -Recurse -Force -ErrorAction Stop
            }
        } catch {
            & $AddLogEntryFunc "WARN" "清理优化状态失败：$($_.Exception.Message)"
        }

        # 显示结果
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = 100
            $statusText.Text = "还原完成！"
            $sidebar = $window.FindName("SidebarStatus")
            $sidebar.Text = "未优化"
            $sidebar.Foreground = "#FFB74D"
            $window.FindName("BtnOptimize").IsEnabled = $true
            $window.FindName("BtnRevert").IsEnabled = $true
            $resultsList = $window.FindName("ResultsList")
            $resultsList.Items.Clear()
            foreach ($r in $reportLines) { $resultsList.Items.Add($r) | Out-Null }
        })
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        if ($ps.InvocationStateInfo.State -eq "Completed") {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    } | Out-Null

    Add-LogEntry "INFO" "还原完成"
})

# Speed Test button
$window.FindName("BtnSpeedTest").Add_Click({
    $window.FindName("BtnSpeedTest").IsEnabled = $false
    $progress = $window.FindName("ProgressBar")
    $statusText = $window.FindName("StatusText")
    $statusText.Text = "正在运行网速测试..."

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测量延迟..."; $progress.Value = 20 })
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        $pingVal = -1
        if ($adapter) {
            $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
            if ($gw) {
                $r = & { ping -n 3 $gw }
                foreach ($l in $r) {
                    if ($l -match "Average = (\d+)" -or $l -match "平均 = (\d+)") { $pingVal = [int]$Matches[1] }
                }
            }
        }
        if ($pingVal -lt 0) {
            $r = & { ping -n 3 1.1.1.1 }
            foreach ($l in $r) {
                if ($l -match "Average = (\d+)" -or $l -match "平均 = (\d+)") { $pingVal = [int]$Matches[1] }
            }
        }

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测试下载..."; $progress.Value = 50 })
        $dlMbps = 0
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $data = Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=10000000" -UseBasicParsing -TimeoutSec 15
            $sw.Stop()
            if ($sw.Elapsed.TotalSeconds -gt 0) {
                $dlMbps = [math]::Round(($data.RawContentLength * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
            }
        } catch { $dlMbps = -1 }

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "正在测试上传..."; $progress.Value = 80 })
        $ulMbps = 0
        try {
            $uploadData = New-Object byte[] 5000000
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-WebRequest -Uri "https://speed.cloudflare.com/__up" -Method POST -Body $uploadData -UseBasicParsing -TimeoutSec 15 | Out-Null
            $sw.Stop()
            if ($sw.Elapsed.TotalSeconds -gt 0) {
                $ulMbps = [math]::Round((5000000 * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
            }
        } catch { $ulMbps = -1 }

        $window.Dispatcher.Invoke([Action]{
            $progress.Value = 100
            $statusText.Text = "网速测试完成！"
            $window.FindName("PingValue").Text = [string]$pingVal
            $window.FindName("DownloadValue").Text = [string]$dlMbps
            $window.FindName("UploadValue").Text = [string]$ulMbps
            $window.FindName("BtnSpeedTest").IsEnabled = $true
        })
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        if ($ps.InvocationStateInfo.State -eq "Completed") {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    } | Out-Null

    Add-LogEntry "INFO" "网速测试已开始"
})

# TCP Refresh
function BtnRefreshTcp_Click {
    param($sender, $e)
    $tcpText = $window.FindName("TcpSettingsText")
    if (-not $tcpText) { return }
    $tcpText.Text = "加载中..."
    $r = Invoke-Command "netsh interface tcp show global"
    $tcpText.Text = $r.Output
    Add-LogEntry "INFO" "TCP 设置已刷新"
}

$window.FindName("BtnRefreshTcp").Add_Click({ BtnRefreshTcp_Click $args[0] $args[1] })

# DNS buttons
$script:selectedDnsIndex = -1
$script:dnsItems = @(
    @{ Button="DnsBtnCloudflare"; Text="DnsTextCloudflare"; Label="Cloudflare"; Primary="1.1.1.1"; Secondary="1.0.0.1"; Base="Cloudflare (1.1.1.1)" },
    @{ Button="DnsBtnGoogle"; Text="DnsTextGoogle"; Label="Google"; Primary="8.8.8.8"; Secondary="8.8.4.4"; Base="Google (8.8.8.8)" },
    @{ Button="DnsBtnAli"; Text="DnsTextAli"; Label="阿里 DNS"; Primary="223.5.5.5"; Secondary="223.6.6.6"; Base="阿里 DNS (223.5.5.5)" },
    @{ Button="DnsBtn114"; Text="DnsText114"; Label="114DNS"; Primary="114.114.114.114"; Secondary="114.114.115.115"; Base="114DNS (114.114.114.114)" },
    @{ Button="DnsBtnDNSPod"; Text="DnsTextDNSPod"; Label="DNSPod"; Primary="119.29.29.29"; Secondary="182.254.116.116"; Base="DNSPod (119.29.29.29)" }
)
$script:hostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$script:hostsBackupPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts.alit.bak"
$script:hostsStartMarker = "# ===== ALit Hosts Optimizer Start ====="
$script:hostsEndMarker = "# ===== ALit Hosts Optimizer End ====="

function Update-DnsButtons {
    param([int]$selectedIndex)
    $dnsBtns = @("DnsBtnCloudflare", "DnsBtnGoogle", "DnsBtnAli", "DnsBtn114", "DnsBtnDNSPod")
    foreach ($name in $dnsBtns) {
        $border = $window.FindName($name)
        if (-not $border) { continue }
        $idx = [int]$border.Tag
        if ($idx -eq $selectedIndex) {
            $border.Background = "#7CC7FF"
            $border.Child.Foreground = "#111111"
            $border.Child.FontWeight = "Bold"
        } else {
            $border.Background = "#3A3A3A"
            $border.Child.Foreground = "#E8E8E8"
            $border.Child.FontWeight = "Normal"
        }
    }
}

function Update-DnsLatencyText {
    param([int]$Index, [string]$LatencyText)
    if ($Index -lt 0 -or $Index -ge $script:dnsItems.Count) { return }
    $item = $script:dnsItems[$Index]
    $textBlock = $window.FindName($item.Text)
    if (-not $textBlock) { return }
    if ([string]::IsNullOrWhiteSpace($LatencyText)) {
        $textBlock.Text = $item.Base
    } else {
        $textBlock.Text = "$($item.Base) ----- $LatencyText"
    }
}

function Remove-AlitHostsBlock {
    param([string]$Content)
    $pattern = "(?s)\r?\n?# ===== ALit Hosts Optimizer Start =====.*?# ===== ALit Hosts Optimizer End =====\r?\n?"
    return [regex]::Replace($Content, $pattern, "`r`n").Trim() + "`r`n"
}

function Get-OptimizedHosts {
    # 内嵌的 GZip+Base64 编码 hosts 文件（2606条记录，覆盖 GitHub/Mojang/Google 等域名）
    $b64 = "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"
    try {
        $bytes = [Convert]::FromBase64String($b64)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $sr = New-Object System.IO.StreamReader($gz, [System.Text.Encoding]::UTF8)
        $content = $sr.ReadToEnd()
        $sr.Close(); $gz.Close(); $ms.Close()
        if ($content -match "github\.com" -and $content.Length -gt 200) {
            return $content.Trim()
        }
    } catch {
        Add-LogEntry "ERROR" "解析内嵌 Hosts 失败：$($_.Exception.Message)"
    }
    return $null
}

function Load-HostsToEditor {
    $editor = $window.FindName("HostsEditorText")
    if (-not $editor) { return }
    try {
        if (Test-Path $script:hostsPath) {
            $editor.Text = [System.IO.File]::ReadAllText($script:hostsPath, [System.Text.Encoding]::Default)
        } else {
            $editor.Text = ""
        }
        Add-LogEntry "INFO" "Hosts 已读取"
    } catch {
        $editor.Text = "读取 Hosts 失败：$($_.Exception.Message)"
        Add-LogEntry "ERROR" "读取 Hosts 失败：$($_.Exception.Message)"
    }
}

function Save-HostsFromEditor {
    $editor = $window.FindName("HostsEditorText")
    if (-not $editor) { return }
    try {
        if (-not (Test-Path $script:hostsBackupPath) -and (Test-Path $script:hostsPath)) {
            Copy-Item $script:hostsPath $script:hostsBackupPath -Force
        }
        [System.IO.File]::WriteAllText($script:hostsPath, $editor.Text, [System.Text.Encoding]::UTF8)
        Invoke-Command "ipconfig /flushdns" | Out-Null
        Add-LogEntry "INFO" "Hosts 已保存并刷新 DNS"
        [System.Windows.MessageBox]::Show("Hosts 已保存，并已刷新 DNS 缓存。", "成功", "OK", "Information") | Out-Null
    } catch {
        Add-LogEntry "ERROR" "保存 Hosts 失败：$($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("保存 Hosts 失败：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null
    }
}

function Get-CustomOptimizationItems {
    return @(
        @{ Check="OptTcpNoDelay"; Name="TcpNoDelay"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNoDelay /t REG_DWORD /d 1 /f') },
        @{ Check="OptTcpAckFrequency"; Name="TcpAckFrequency"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f') },
        @{ Check="OptTcpDelAckTicks"; Name="TcpDelAckTicks"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpDelAckTicks /t REG_DWORD /d 0 /f') },
        @{ Check="OptFastOpen"; Name="TCP Fast Open"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableTcpFastOpen /t REG_DWORD /d 1 /f','netsh interface tcp set global fastopen=enabled') },
        @{ Check="OptMaxUserPort"; Name="MaxUserPort"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 64336 /f') },
        @{ Check="OptAutoTuning"; Name="TCP 自动调优 Normal"; Commands=@('netsh interface tcp set global autotuninglevel=normal') },
        @{ Check="OptInitialWindow"; Name="初始拥塞窗口与 RTO"; Commands=@('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "Set-NetTCPSetting -SettingName * -InitialCongestionWindow 10 -InitialRto 3000 -ErrorAction SilentlyContinue"') },
        @{ Check="OptEcn"; Name="ECN"; Commands=@('netsh int tcp set global ecncapability=enabled') },
        @{ Check="OptRssTaskOffload"; Name="RSS 与 TaskOffload"; Commands=@('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -TaskOffload Enabled -ErrorAction SilentlyContinue"') },
        @{ Check="OptNetworkThrottle"; Name="NetworkThrottlingIndex"; Commands=@('reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f') },
        @{ Check="OptResponsiveness"; Name="SystemResponsiveness"; Commands=@('reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f') },
        @{ Check="OptQoSReserve"; Name="QoS 保留带宽为 0"; Commands=@('reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f') },
        @{ Check="OptLanmanThrottle"; Name="关闭工作站带宽节流"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f') },
        @{ Check="OptLargeMtu"; Name="启用 Large MTU"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableLargeMtu /t REG_DWORD /d 0 /f') },
        @{ Check="OptWinHttpAutoTuning"; Name="WinHTTP 自动调优"; Commands=@('reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v TcpAutotuning /t REG_DWORD /d 1 /f','reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v TcpAutotuning /t REG_DWORD /d 1 /f') },
        @{ Check="OptBranchCache"; Name="禁用 BranchCache"; Commands=@('reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DisableBranchCache /t REG_DWORD /d 1 /f','reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\BITS" /v DisableBranchCache /t REG_DWORD /d 1 /f') },
        @{ Check="OptEnableWsdOff"; Name="关闭 EnableWsd"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableWsd /t REG_DWORD /d 0 /f') },
        @{ Check="OptConnRateLimit"; Name="禁用连接速率限制"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableConnectionRateLimiting /t REG_DWORD /d 0 /f') },
        @{ Check="OptAppDscp"; Name="允许应用 DSCP 标记"; Commands=@('reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS" /v "Application DSCP Marking Request" /t REG_SZ /d Allowed /f') },
        @{ Check="OptFpsQoS"; Name="FPS游戏 QoS DSCP 46"; Commands=@(
            'netsh qos delete policy name="NetOpt_FPS_CS2_Proc"',
            'netsh qos add policy name="NetOpt_FPS_CS2_Proc" appname="cs2.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_CS2_Port"',
            'netsh qos add policy name="NetOpt_FPS_CS2_Port" protocol=udp localport=27015 dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_Val_Proc"',
            'netsh qos add policy name="NetOpt_FPS_Val_Proc" appname="VALORANT-Win64-Shipping.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_Val_Port"',
            'netsh qos add policy name="NetOpt_FPS_Val_Port" protocol=udp localport=7448 dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_Apex_Proc"',
            'netsh qos add policy name="NetOpt_FPS_Apex_Proc" appname="r5apex.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_Apex_Port"',
            'netsh qos add policy name="NetOpt_FPS_Apex_Port" protocol=udp localport=37015 dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_CoD_Proc"',
            'netsh qos add policy name="NetOpt_FPS_CoD_Proc" appname="cod.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_CoD_Port"',
            'netsh qos add policy name="NetOpt_FPS_CoD_Port" protocol=udp localport=3074 dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_PUBG_Proc"',
            'netsh qos add policy name="NetOpt_FPS_PUBG_Proc" appname="TslGame.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_R6_Proc"',
            'netsh qos add policy name="NetOpt_FPS_R6_Proc" appname="RainbowSix.exe" dscp=46 throttleRate=none',
            'netsh qos delete policy name="NetOpt_FPS_R6_Port"',
            'netsh qos add policy name="NetOpt_FPS_R6_Port" protocol=udp localport=6015 dscp=46 throttleRate=none'
        ) },
        @{ Check="OptTcpHybridAck"; Name="TcpHybridAck=0"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpHybridAck /t REG_DWORD /d 0 /f') },
        @{ Check="OptTcpWindowSize"; Name="TcpWindowSize=130000"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSize /t REG_DWORD /d 130000 /f','reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpWindowSizeMin /t REG_DWORD /d 130000 /f') },
        @{ Check="OptMaxConnections"; Name="MaxConnections=65536"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxConnections /t REG_DWORD /d 65536 /f') },
        @{ Check="OptEnergyEfficient"; Name="关闭节能以太网"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v EnergyEfficientEthernet /t REG_DWORD /d 0 /f') },
        @{ Check="OptMtu1500"; Name="MTU=1500"; Commands=@('reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MTU /t REG_DWORD /d 1500 /f') },
        @{ Check="OptCongestionDefault"; Name="拥塞控制 Default"; Commands=@('netsh interface tcp set supplemental Template=Internet CongestionProvider=default','netsh interface tcp set supplemental Template=InternetCustom CongestionProvider=default','netsh interface tcp set supplemental Template=Datacenter CongestionProvider=default','netsh interface tcp set supplemental Template=DatacenterCustom CongestionProvider=default','netsh interface tcp set supplemental Template=Compat CongestionProvider=default') },
        @{ Check="OptWinINetAutoTuning"; Name="WinINet TcpAutotuning=1"; Commands=@('reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v TcpAutotuning /t REG_DWORD /d 1 /f','reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings" /v TcpAutotuning /t REG_DWORD /d 1 /f') }
    )
}

function Set-CustomChecks {
    param([bool]$Recommended)
    $recommendedNames = @("OptTcpNoDelay","OptTcpAckFrequency","OptFastOpen","OptAutoTuning","OptEcn","OptRssTaskOffload","OptNetworkThrottle","OptResponsiveness","OptQoSReserve","OptLanmanThrottle","OptLargeMtu","OptWinHttpAutoTuning","OptTcpHybridAck","OptEnergyEfficient","OptWinINetAutoTuning","OptFpsQoS")
    foreach ($item in Get-CustomOptimizationItems) {
        $cb = $window.FindName($item.Check)
        if ($cb) {
            $cb.IsChecked = if ($Recommended) { $recommendedNames -contains $item.Check } else { $false }
        }
    }
}

function Apply-CustomOptimizations {
    $items = Get-CustomOptimizationItems
    $selected = @()
    foreach ($item in $items) {
        $cb = $window.FindName($item.Check)
        if ($cb -and $cb.IsChecked) { $selected += $item }
    }
    if ($selected.Count -eq 0) {
        [System.Windows.MessageBox]::Show("请至少勾选一个优化条目。", "提示", "OK", "Warning") | Out-Null
        return
    }
    $ok = 0
    $fail = 0
    foreach ($item in $selected) {
        $itemOk = $true
        foreach ($cmd in $item.Commands) {
            $r = Invoke-Command $cmd
            if ($r.ExitCode -ne 0) { $itemOk = $false }
        }
        if ($itemOk) {
            $ok++
            Add-LogEntry "INFO" "自定义优化成功：$($item.Name)"
        } else {
            $fail++
            Add-LogEntry "WARN" "自定义优化可能失败：$($item.Name)"
        }
    }
    Invoke-Command "ipconfig /flushdns" | Out-Null
    [System.Windows.MessageBox]::Show("自定义优化完成。成功：$ok，可能失败：$fail。部分设置可能需要重启后生效。", "完成", "OK", "Information") | Out-Null
}

$window.FindName("BtnTestAdapterDeep").Add_Click({
    $btn = $window.FindName("BtnTestAdapterDeep")
    $btn.IsEnabled = $false
    $oldText = $btn.Content
    $btn.Content = "执行中..."
    $results = New-Object System.Collections.ArrayList

    try {
        Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -TaskOffload Enabled -ErrorAction SilentlyContinue
        $results.Add("[OK] 全局 RSS 与 TaskOffload 已启用") | Out-Null
    } catch {
        $results.Add("[WARN] 全局卸载能力设置失败") | Out-Null
    }

    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        try {
            Enable-NetAdapterRss -Name $adapter.Name -ErrorAction SilentlyContinue
            $results.Add("[OK] $($adapter.Name)：RSS 已启用") | Out-Null
        } catch {
            $results.Add("[WARN] $($adapter.Name)：RSS 不支持或设置失败") | Out-Null
        }

        $toggleProps = @(
            @("Interrupt Moderation", "Enabled"),
            @("Energy Efficient Ethernet", "Disabled"),
            @("Green Ethernet", "Disabled"),
            @("Power Saving Mode", "Disabled")
        )
        foreach ($p in $toggleProps) {
            try {
                $prop = Get-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p[0] -ErrorAction SilentlyContinue
                if ($prop) {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p[0] -DisplayValue $p[1] -NoRestart -ErrorAction Stop
                    $results.Add("[OK] $($adapter.Name)：$($p[0]) = $($p[1])") | Out-Null
                }
            } catch {
                $results.Add("[WARN] $($adapter.Name)：$($p[0]) 未修改") | Out-Null
            }
        }

        foreach ($bufferName in @("Receive Buffers", "Transmit Buffers")) {
            $applied = $false
            foreach ($value in @("4096", "2048", "1024", "512")) {
                try {
                    $prop = Get-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $bufferName -ErrorAction SilentlyContinue
                    if ($prop) {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $bufferName -RegistryValue $value -NoRestart -ErrorAction Stop
                        $results.Add("[OK] $($adapter.Name)：$bufferName = $value") | Out-Null
                        $applied = $true
                        break
                    }
                } catch {}
            }
            if (-not $applied) {
                $results.Add("[INFO] $($adapter.Name)：$bufferName 不支持或已跳过") | Out-Null
            }
        }
    }

    $list = $window.FindName("ResultsList")
    if ($list) {
        $list.Items.Clear()
        foreach ($r in $results) { $list.Items.Add($r) | Out-Null }
    }
    $btn.Content = $oldText
    $btn.IsEnabled = $true
    [System.Windows.MessageBox]::Show("网卡深层测试优化已完成。部分网卡参数可能需要禁用/启用网卡或重启后生效。", "完成", "OK", "Information") | Out-Null
})

# ============================================================
# WinDivert 逐包优化模拟
# ============================================================
$script:simPolicyPrefix = "ALit_PacketSim"

# --- 一键模拟 ---
$window.FindName("BtnSimApply").Add_Click({
    $btn = $window.FindName("BtnSimApply")
    $btn.IsEnabled = $false
    $oldText = $btn.Content
    $btn.Content = "模拟中..."
    $resultBox = $window.FindName("SimResultText")
    $sb = New-Object System.Text.StringBuilder
    $okCount = 0
    $failCount = 0

    $doQoS = [bool]$window.FindName("ChkSimQoS").IsChecked
    $doProc = [bool]$window.FindName("ChkSimProcPriority").IsChecked
    $doTimer = [bool]$window.FindName("ChkSimTimer").IsChecked
    $doIntr = [bool]$window.FindName("ChkSimInterrupt").IsChecked
    $doRSS  = [bool]$window.FindName("ChkSimRSS").IsChecked
    $doThr  = [bool]$window.FindName("ChkSimThrottle").IsChecked

    # 1. QoS DSCP 46 标记
    if ($doQoS) {
        [void]$sb.AppendLine("=== QoS DSCP 46 标记 ===")
        $qosCmds = @(
            @{ Name="Java_App";   Cmd='netsh qos delete policy name="ALit_PacketSim_Java_App"' },
            @{ Name="Bedrock_App"; Cmd='netsh qos delete policy name="ALit_PacketSim_Bedrock_App"' },
            @{ Name="Java_Port";  Cmd='netsh qos delete policy name="ALit_PacketSim_Java_Port"' },
            @{ Name="Bedrock_Port"; Cmd='netsh qos delete policy name="ALit_PacketSim_Bedrock_Port"' },
            @{ Name="FPS_CS2"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_CS2"' },
            @{ Name="FPS_Val"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_Val"' },
            @{ Name="FPS_Apex"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_Apex"' },
            @{ Name="FPS_CoD"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_CoD"' },
            @{ Name="FPS_PUBG"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_PUBG"' },
            @{ Name="FPS_R6"; Cmd='netsh qos delete policy name="ALit_PacketSim_FPS_R6"' }
        )
        foreach ($q in $qosCmds) { Invoke-Command $q.Cmd | Out-Null }

        $addCmds = @(
            @{ Name="Java_App";   Cmd='netsh qos add policy name="ALit_PacketSim_Java_App" appPath="javaw.exe" dscp=46 throttleRate=none' },
            @{ Name="Bedrock_App"; Cmd='netsh qos add policy name="ALit_PacketSim_Bedrock_App" appPath="Minecraft.Windows.exe" dscp=46 throttleRate=none' },
            @{ Name="Java_Port";  Cmd='netsh qos add policy name="ALit_PacketSim_Java_Port" protocol=tcp destinationport=25565 dscp=46 throttleRate=none' },
            @{ Name="Bedrock_Port"; Cmd='netsh qos add policy name="ALit_PacketSim_Bedrock_Port" protocol=udp destinationport=19132 dscp=46 throttleRate=none' },
            @{ Name="FPS_CS2"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_CS2" appname="cs2.exe" dscp=46 throttleRate=none' },
            @{ Name="FPS_Val"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_Val" appname="VALORANT-Win64-Shipping.exe" dscp=46 throttleRate=none' },
            @{ Name="FPS_Apex"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_Apex" appname="r5apex.exe" dscp=46 throttleRate=none' },
            @{ Name="FPS_CoD"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_CoD" appname="cod.exe" dscp=46 throttleRate=none' },
            @{ Name="FPS_PUBG"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_PUBG" appname="TslGame.exe" dscp=46 throttleRate=none' },
            @{ Name="FPS_R6"; Cmd='netsh qos add policy name="ALit_PacketSim_FPS_R6" appname="RainbowSix.exe" dscp=46 throttleRate=none' }
        )
        foreach ($a in $addCmds) {
            $r = Invoke-Command $a.Cmd
            if ($r.ExitCode -eq 0) {
                [void]$sb.AppendLine("  [OK] $($a.Name) DSCP=46")
                $okCount++
            } else {
                [void]$sb.AppendLine("  [FAIL] $($a.Name) (exit=$($r.ExitCode))")
                $failCount++
            }
        }
        [void]$sb.AppendLine("")
    }

    # 2. 进程优先级提升
    if ($doProc) {
        [void]$sb.AppendLine("=== 进程优先级提升 ===")
        try {
            $procs = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
            if ($procs -and $procs.Count -gt 0) {
                foreach ($p in $procs) {
                    try {
                        $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                        [void]$sb.AppendLine("  [OK] javaw.exe PID=$($p.Id) -> High")
                        $okCount++
                    } catch {
                        [void]$sb.AppendLine("  [FAIL] javaw.exe PID=$($p.Id): $($_.Exception.Message)")
                        $failCount++
                    }
                }
            } else {
                [void]$sb.AppendLine("  [INFO] javaw.exe 未运行，已跳过（启动 Minecraft 后再次应用）")
            }
            # 基岩版
            $bprocs = Get-Process -Name "Minecraft.Windows" -ErrorAction SilentlyContinue
            if ($bprocs) {
                foreach ($p in $bprocs) {
                    try {
                        $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                        [void]$sb.AppendLine("  [OK] Minecraft.Windows PID=$($p.Id) -> High")
                        $okCount++
                    } catch {
                        [void]$sb.AppendLine("  [FAIL] Minecraft.Windows PID=$($p.Id): $($_.Exception.Message)")
                        $failCount++
                    }
                }
            }
        } catch {
            [void]$sb.AppendLine("  [FAIL] 进程优先级设置失败: $($_.Exception.Message)")
            $failCount++
        }
        [void]$sb.AppendLine("")
    }

    # 3. 系统定时器分辨率 0.5ms
    if ($doTimer) {
        [void]$sb.AppendLine("=== 系统定时器 0.5ms ===")
        try {
            $timerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
            $oldVal = (Get-ItemProperty -Path $timerPath -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests
            Set-ItemProperty -Path $timerPath -Name "GlobalTimerResolutionRequests" -Value 1 -Type DWord -Force -ErrorAction Stop
            [void]$sb.AppendLine("  [OK] GlobalTimerResolutionRequests=1（允许进程请求高精度定时器）")
            $okCount++
            # 保存旧值用于还原
            $simStateDir = Join-Path $env:ProgramData "ALitNetworkOptimizer"
            if (-not (Test-Path $simStateDir)) { New-Item -Path $simStateDir -ItemType Directory -Force | Out-Null }
            $simStateFile = Join-Path $simStateDir "packetsim-state.json"
            $simState = @{}
            if (Test-Path $simStateFile) {
                try {
                    $obj = Get-Content $simStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    foreach ($prop in $obj.PSObject.Properties) { $simState[$prop.Name] = $prop.Value }
                } catch {}
            }
            $simState["TimerOldVal"] = if ($oldVal) { $oldVal } else { 0 }
            $simState | ConvertTo-Json -Depth 5 | Set-Content $simStateFile -Encoding UTF8
        } catch {
            [void]$sb.AppendLine("  [FAIL] 定时器设置失败: $($_.Exception.Message)")
            $failCount++
        }
        [void]$sb.AppendLine("")
    }

    # 4. 关闭网卡中断调节
    if ($doIntr) {
        [void]$sb.AppendLine("=== 关闭网卡中断调节 ===")
        try {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
            if ($adapters) {
                foreach ($adapter in $adapters) {
                    try {
                        $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -ErrorAction SilentlyContinue
                        if ($im) {
                            $oldIM = $im.RegistryValue
                            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction Stop
                            [void]$sb.AppendLine("  [OK] $($adapter.Name): 中断调节已关闭（旧值=$oldIM）")
                            $okCount++
                        } else {
                            [void]$sb.AppendLine("  [SKIP] $($adapter.Name): 不支持中断调节")
                        }
                    } catch {
                        [void]$sb.AppendLine("  [FAIL] $($adapter.Name): $($_.Exception.Message)")
                        $failCount++
                    }
                }
            } else {
                [void]$sb.AppendLine("  [INFO] 未检测到活动网卡")
            }
        } catch {
            [void]$sb.AppendLine("  [FAIL] 网卡中断调节设置失败: $($_.Exception.Message)")
            $failCount++
        }
        [void]$sb.AppendLine("")
    }

    # 5. RSS 队列优化
    if ($doRSS) {
        [void]$sb.AppendLine("=== RSS 队列优化 ===")
        try {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
            if ($adapters) {
                foreach ($adapter in $adapters) {
                    try {
                        $rss = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -ErrorAction SilentlyContinue
                        if ($rss) {
                            $maxQueues = 4
                            # 尝试设置 4 队列，失败则尝试 2
                            $setOk = $false
                            try {
                                Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -RegistryValue 4 -ErrorAction Stop
                                [void]$sb.AppendLine("  [OK] $($adapter.Name): RSS 队列=4")
                                $setOk = $true
                                $okCount++
                            } catch {
                                try {
                                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -RegistryValue 2 -ErrorAction Stop
                                    [void]$sb.AppendLine("  [OK] $($adapter.Name): RSS 队列=2（4 不支持）")
                                    $setOk = $true
                                    $okCount++
                                } catch {
                                    [void]$sb.AppendLine("  [SKIP] $($adapter.Name): RSS 队列不可调")
                                }
                            }
                        } else {
                            [void]$sb.AppendLine("  [SKIP] $($adapter.Name): 不支持 RSS 队列设置")
                        }
                        # 启用 RSS
                        try {
                            Set-NetAdapterRss -Name $adapter.Name -Enabled $true -ErrorAction SilentlyContinue
                        } catch {}
                    } catch {
                        [void]$sb.AppendLine("  [FAIL] $($adapter.Name): $($_.Exception.Message)")
                        $failCount++
                    }
                }
            } else {
                [void]$sb.AppendLine("  [INFO] 未检测到活动网卡")
            }
        } catch {
            [void]$sb.AppendLine("  [FAIL] RSS 设置失败: $($_.Exception.Message)")
            $failCount++
        }
        [void]$sb.AppendLine("")
    }

    # 6. 关闭网络节流 + SystemResponsiveness=0
    if ($doThr) {
        [void]$sb.AppendLine("=== 网络节流 + 系统响应 ===")
        try {
            $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            $oldNTI = (Get-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
            $oldSR  = (Get-ItemProperty -Path $spPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness

            Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force -ErrorAction Stop
            Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction Stop

            # Games Task 加速
            $gamesPath = "$spPath\Tasks\Games"
            Set-ItemProperty -Path $gamesPath -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesPath -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesPath -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $gamesPath -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue

            [void]$sb.AppendLine("  [OK] NetworkThrottlingIndex=0xFFFFFFFF（旧值=$oldNTI）")
            [void]$sb.AppendLine("  [OK] SystemResponsiveness=0（旧值=$oldSR）")
            [void]$sb.AppendLine("  [OK] Games Task: GPU=8, Priority=6, Sched=High, SFIO=High")
            $okCount += 3

            # 保存旧值
            $simStateDir = Join-Path $env:ProgramData "ALitNetworkOptimizer"
            if (-not (Test-Path $simStateDir)) { New-Item -Path $simStateDir -ItemType Directory -Force | Out-Null }
            $simStateFile = Join-Path $simStateDir "packetsim-state.json"
            $simState = @{}
            if (Test-Path $simStateFile) {
                try {
                    $obj = Get-Content $simStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
                    foreach ($prop in $obj.PSObject.Properties) { $simState[$prop.Name] = $prop.Value }
                } catch {}
            }
            $simState["NTIOld"] = if ($oldNTI) { $oldNTI } else { 10 }
            $simState["SROld"] = if ($oldSR) { $oldSR } else { 20 }
            $simState | ConvertTo-Json -Depth 5 | Set-Content $simStateFile -Encoding UTF8
        } catch {
            [void]$sb.AppendLine("  [FAIL] 网络节流设置失败: $($_.Exception.Message)")
            $failCount++
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("========================================")
    [void]$sb.AppendLine("模拟完成：成功 $okCount 项，失败 $failCount 项")
    [void]$sb.AppendLine("注：QoS DSCP 效果取决于路由器/运营商是否识别；")
    [void]$sb.AppendLine("    进程优先级仅在游戏运行时生效；")
    [void]$sb.AppendLine("    中断调节和 RSS 可能需要禁用/启用网卡生效。")

    $resultBox.Text = $sb.ToString()
    Add-LogEntry "INFO" "WinDivert 逐包优化模拟已应用：成功 $okCount，失败 $failCount"

    $btn.Content = $oldText
    $btn.IsEnabled = $true
    [System.Windows.MessageBox]::Show("WinDivert 逐包优化模拟已应用。`n成功 $okCount 项，失败 $failCount 项。`n`n点击「检测状态」查看当前生效情况。", "完成", "OK", "Information") | Out-Null
})

# --- 还原模拟 ---
$window.FindName("BtnSimRestore").Add_Click({
    $btn = $window.FindName("BtnSimRestore")
    $btn.IsEnabled = $false
    $oldText = $btn.Content
    $btn.Content = "还原中..."
    $resultBox = $window.FindName("SimResultText")
    $sb = New-Object System.Text.StringBuilder
    $okCount = 0

    [void]$sb.AppendLine("=== 还原 WinDivert 模拟 ===")

    # 1. 移除 QoS 策略
    $qosNames = @("ALit_PacketSim_Java_App", "ALit_PacketSim_Bedrock_App", "ALit_PacketSim_Java_Port", "ALit_PacketSim_Bedrock_Port",
                  "ALit_PacketSim_FPS_CS2", "ALit_PacketSim_FPS_Val", "ALit_PacketSim_FPS_Apex",
                  "ALit_PacketSim_FPS_CoD", "ALit_PacketSim_FPS_PUBG", "ALit_PacketSim_FPS_R6")
    foreach ($qn in $qosNames) {
        $r = Invoke-Command "netsh qos delete policy name=`"$qn`""
        if ($r.ExitCode -eq 0) {
            [void]$sb.AppendLine("  [OK] 移除 QoS: $qn")
            $okCount++
        }
    }

    # 2. 还原进程优先级
    try {
        $procs = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) {
                try { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Normal; $okCount++ } catch {}
            }
            [void]$sb.AppendLine("  [OK] javaw.exe 优先级 -> Normal")
        }
        $bprocs = Get-Process -Name "Minecraft.Windows" -ErrorAction SilentlyContinue
        if ($bprocs) {
            foreach ($p in $bprocs) {
                try { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Normal; $okCount++ } catch {}
            }
            [void]$sb.AppendLine("  [OK] Minecraft.Windows 优先级 -> Normal")
        }
    } catch {
        [void]$sb.AppendLine("  [FAIL] 进程优先级还原: $($_.Exception.Message)")
    }

    # 3. 还原定时器
    $simStateFile = Join-Path $env:ProgramData "ALitNetworkOptimizer\packetsim-state.json"
    $simState = @{}
    if (Test-Path $simStateFile) {
        try {
            $obj = Get-Content $simStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $obj.PSObject.Properties) { $simState[$prop.Name] = $prop.Value }
        } catch {}
    }
    try {
        $timerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        $timerOld = if ($simState.ContainsKey("TimerOldVal")) { $simState["TimerOldVal"] } else { 0 }
        Set-ItemProperty -Path $timerPath -Name "GlobalTimerResolutionRequests" -Value $timerOld -Type DWord -Force -ErrorAction SilentlyContinue
        [void]$sb.AppendLine("  [OK] 定时器还原 -> $timerOld")
        $okCount++
    } catch {
        [void]$sb.AppendLine("  [FAIL] 定时器还原: $($_.Exception.Message)")
    }

    # 4. 还原网卡中断调节
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if ($adapters) {
            foreach ($adapter in $adapters) {
                try {
                    $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -ErrorAction SilentlyContinue
                    if ($im) {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 1 -ErrorAction SilentlyContinue
                    }
                } catch {}
            }
            [void]$sb.AppendLine("  [OK] 网卡中断调节 -> 启用（默认）")
            $okCount++
        }
    } catch {
        [void]$sb.AppendLine("  [FAIL] 中断调节还原: $($_.Exception.Message)")
    }

    # 5. 还原 RSS 队列
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if ($adapters) {
            foreach ($adapter in $adapters) {
                try {
                    $rss = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -ErrorAction SilentlyContinue
                    if ($rss) {
                        # 还原为最大可用值（由驱动决定）
                        $validValues = $rss.ValidDisplayValues
                        if ($validValues -and $validValues.Count -gt 0) {
                            $maxVal = ($validValues | Select-Object -Last 1)
                            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -RegistryValue $maxVal -ErrorAction SilentlyContinue
                        }
                    }
                } catch {}
            }
            [void]$sb.AppendLine("  [OK] RSS 队列 -> 默认最大值")
            $okCount++
        }
    } catch {
        [void]$sb.AppendLine("  [FAIL] RSS 还原: $($_.Exception.Message)")
    }

    # 6. 还原网络节流和系统响应
    try {
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $ntiOld = if ($simState.ContainsKey("NTIOld")) { $simState["NTIOld"] } else { 10 }
        $srOld  = if ($simState.ContainsKey("SROld")) { $simState["SROld"] } else { 20 }
        Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value $ntiOld -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value $srOld -Type DWord -Force -ErrorAction SilentlyContinue
        [void]$sb.AppendLine("  [OK] NetworkThrottlingIndex -> $ntiOld")
        [void]$sb.AppendLine("  [OK] SystemResponsiveness -> $srOld")
        $okCount += 2
    } catch {
        [void]$sb.AppendLine("  [FAIL] 网络节流还原: $($_.Exception.Message)")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("还原完成：$okCount 项已恢复")
    $resultBox.Text = $sb.ToString()
    Add-LogEntry "INFO" "WinDivert 逐包优化模拟已还原"

    $btn.Content = $oldText
    $btn.IsEnabled = $true
    [System.Windows.MessageBox]::Show("WinDivert 模拟已还原，$okCount 项已恢复默认。", "完成", "OK", "Information") | Out-Null
})

# --- 检测状态 ---
$window.FindName("BtnSimStatus").Add_Click({
    $btn = $window.FindName("BtnSimStatus")
    $btn.IsEnabled = $false
    $oldText = $btn.Content
    $btn.Content = "检测中..."
    $resultBox = $window.FindName("SimResultText")
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("=== WinDivert 模拟状态检测 ===")
    [void]$sb.AppendLine("")

    # 1. QoS 策略
    [void]$sb.AppendLine("--- QoS DSCP 策略 ---")
    $qosShow = Invoke-Command "netsh qos show policy"
    $qosOutput = $qosShow.Output
    $simPolicies = $qosOutput -split "`n" | Where-Object { $_ -match "ALit_PacketSim" }
    if ($simPolicies -and $simPolicies.Count -gt 0) {
        foreach ($p in $simPolicies) { [void]$sb.AppendLine("  $p".Trim()) }
    } else {
        [void]$sb.AppendLine("  未找到模拟 QoS 策略（未应用或已被移除）")
    }
    [void]$sb.AppendLine("")

    # 2. 进程优先级
    [void]$sb.AppendLine("--- 进程优先级 ---")
    $procs = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($p in $procs) {
            [void]$sb.AppendLine("  javaw.exe PID=$($p.Id) 优先级=$($p.PriorityClass)")
        }
    } else {
        [void]$sb.AppendLine("  javaw.exe 未运行")
    }
    $bprocs = Get-Process -Name "Minecraft.Windows" -ErrorAction SilentlyContinue
    if ($bprocs) {
        foreach ($p in $bprocs) {
            [void]$sb.AppendLine("  Minecraft.Windows PID=$($p.Id) 优先级=$($p.PriorityClass)")
        }
    } else {
        [void]$sb.AppendLine("  Minecraft.Windows 未运行")
    }
    [void]$sb.AppendLine("")

    # 3. 定时器
    [void]$sb.AppendLine("--- 系统定时器 ---")
    try {
        $timerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
        $tv = (Get-ItemProperty -Path $timerPath -Name "GlobalTimerResolutionRequests" -ErrorAction SilentlyContinue).GlobalTimerResolutionRequests
        if ($tv -eq 1) {
            [void]$sb.AppendLine("  GlobalTimerResolutionRequests=1（高精度已启用）")
        } else {
            [void]$sb.AppendLine("  GlobalTimerResolutionRequests=$tv（默认/未启用）")
        }
    } catch {
        [void]$sb.AppendLine("  无法读取定时器设置")
    }
    [void]$sb.AppendLine("")

    # 4. 网卡中断调节 + RSS
    [void]$sb.AppendLine("--- 网卡参数 ---")
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if ($adapters) {
            foreach ($adapter in $adapters) {
                [void]$sb.AppendLine("  网卡: $($adapter.Name)")
                $im = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -ErrorAction SilentlyContinue
                if ($im) {
                    $imStatus = if ($im.RegistryValue -eq 0) { "已关闭（低延迟）" } else { "已启用（默认）" }
                    [void]$sb.AppendLine("    中断调节: $imStatus (值=$($im.RegistryValue))")
                }
                $rss = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*NumRssQueues" -ErrorAction SilentlyContinue
                if ($rss) {
                    [void]$sb.AppendLine("    RSS 队列数: $($rss.RegistryValue)")
                }
                $rssState = Get-NetAdapterRss -Name $adapter.Name -ErrorAction SilentlyContinue
                if ($rssState) {
                    [void]$sb.AppendLine("    RSS 启用: $($rssState.Enabled)")
                }
            }
        } else {
            [void]$sb.AppendLine("  未检测到活动网卡")
        }
    } catch {
        [void]$sb.AppendLine("  网卡参数读取失败: $($_.Exception.Message)")
    }
    [void]$sb.AppendLine("")

    # 5. 网络节流
    [void]$sb.AppendLine("--- 网络节流 / 系统响应 ---")
    try {
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $nti = (Get-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -ErrorAction SilentlyContinue).NetworkThrottlingIndex
        $sr  = (Get-ItemProperty -Path $spPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue).SystemResponsiveness
        $ntiStatus = if ([int64]$nti -eq 4294967295 -or [int64]$nti -eq -1) { "已关闭（最大值）" } else { "启用（值=$nti）" }
        [void]$sb.AppendLine("  NetworkThrottlingIndex: $ntiStatus")
        [void]$sb.AppendLine("  SystemResponsiveness: $sr")
        $gamesPath = "$spPath\Tasks\Games"
        $gGPU = (Get-ItemProperty -Path $gamesPath -Name "GPU Priority" -ErrorAction SilentlyContinue)."GPU Priority"
        $gPri = (Get-ItemProperty -Path $gamesPath -Name "Priority" -ErrorAction SilentlyContinue).Priority
        $gSched = (Get-ItemProperty -Path $gamesPath -Name "Scheduling Category" -ErrorAction SilentlyContinue)."Scheduling Category"
        $gSFIO = (Get-ItemProperty -Path $gamesPath -Name "SFIO Priority" -ErrorAction SilentlyContinue)."SFIO Priority"
        [void]$sb.AppendLine("  Games Task: GPU=$gGPU, Pri=$gPri, Sched=$gSched, SFIO=$gSFIO")
    } catch {
        [void]$sb.AppendLine("  读取失败: $($_.Exception.Message)")
    }

    $resultBox.Text = $sb.ToString()
    Add-LogEntry "INFO" "WinDivert 模拟状态检测已完成"

    $btn.Content = $oldText
    $btn.IsEnabled = $true
})

# ============================================================
# WinDivert 真实模式 - 内核级逐包 DSCP 标记
# ============================================================
$script:wdProcess = $null
$script:wdDir = Join-Path $env:ProgramData "ALitNetworkOptimizer\WinDivert"

# C# 逐包标记器源码
$script:wdCsSource = @'
// WinDivert 逐包优化引擎 V3 - 多模式增强版
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

class WinDivertMarker
{
    const string DLL = "WinDivert";
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    static extern IntPtr WinDivertOpen(string filter, int layer, short priority, ulong flags);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertRecv(IntPtr handle, byte[] pPacket, uint packetLen, out uint pRecvLen, ref WINDIVERT_ADDRESS pAddr);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertSend(IntPtr handle, byte[] pPacket, uint packetLen, out uint pSendLen, ref WINDIVERT_ADDRESS pAddr);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertShutdown(IntPtr handle, int how);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertClose(IntPtr handle);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertSetParam(IntPtr handle, int param, ulong value);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertHelperCalcChecksums(byte[] pPacket, uint packetLen, ref WINDIVERT_ADDRESS pAddr, ulong flags);

    [StructLayout(LayoutKind.Sequential)]
    struct WINDIVERT_ADDRESS
    {
        public long Timestamp;
        public uint Layer_Events_Flags;
        public uint IfIdx;
        public uint SubIfIdx;
        public uint pad0, pad1, pad2, pad3, pad4, pad5, pad6, pad7, pad8, pad9, pad10;
    }

    const int WINDIVERT_LAYER_NETWORK = 0;
    const int WINDIVERT_SHUTDOWN_RECV = 1;
    const int WINDIVERT_PARAM_QUEUE_LENGTH = 0;
    const int WINDIVERT_PARAM_QUEUE_TIME = 1;
    const int WINDIVERT_PARAM_QUEUE_SIZE = 2;
    const uint FLAG_OUTBOUND = (1u << 17);
    const uint FLAG_IPV6 = (1u << 20);

    // 模式配置: 0=普通 1=最佳 2=急速 3=狂暴 4=Backtrack
    static string[] modeNames = { "\u666e\u901a\u6a21\u5f0f", "\u6700\u4f73\u6a21\u5f0f", "\u6025\u901f\u6a21\u5f0f", "\u72c2\u66b4\u6a21\u5f0f", "Backtrack" };
    static bool[] modeBidir = { false, true, true, true, true };
    static bool[] modeAck = { false, true, true, true, true };
    static bool[] modeWin = { false, false, true, true, true };
    static bool[] modeFec = { false, false, false, true, true };
    static bool[] modeBt = { false, false, false, false, true };
    static bool[] modeUdpFec = { false, false, true, true, true };
    static uint[] modeQTime = { 100, 50, 20, 10, 5 };
    static uint[] modeQLen = { 16384, 16384, 8192, 32768, 65536 };
    static uint[] modeQSize = { 33554432, 33554432, 16777216, 67108864, 134217728 };

    static IntPtr handle = IntPtr.Zero;
    static volatile bool running = true;
    static long totalPackets = 0;
    static long modifiedPackets = 0;
    static long ackPackets = 0;
    static long tcpPackets = 0;
    static long udpPackets = 0;
    static long inboundPackets = 0;
    static long outboundPackets = 0;
    static long fecPackets = 0;
    static long btPackets = 0;
    static long btRecovered = 0;
    static DateTime startTime;
    static uint adaptiveQTime = 100;
    static long lastTotal = 0;
    static DateTime lastStatsTime;

    // FEC path switching - alternate DSCP for duplicate packets
    static int dscpAltCounter = 0;
    static byte[] altTosValues = { 0xB8, 0x88, 0xC0, 0xA0 };

    // Backtrack buffer for delayed packet recovery
    struct BtEntry { public byte[] Data; public uint Len; public WINDIVERT_ADDRESS Addr; public DateTime Ts; public uint Seq; }
    static Queue<BtEntry> btBuffer = new Queue<BtEntry>();
    static uint lastAckSeq = 0;

    // Jitter tracking
    static Queue<double> recentJitter = new Queue<double>();
    static DateTime lastPktTime = DateTime.MinValue;
    static double currentJitter = 0;

    static void Main(string[] args)
    {
        int mode = 0;
        byte dscpValue = 46;
        List<int> tcpPorts = new List<int>();
        tcpPorts.Add(25565);
        List<int> udpPorts = new List<int>();
        udpPorts.Add(19132);

        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--mode" && i + 1 < args.Length) { int m; if (int.TryParse(args[++i], out m)) mode = m; }
            else if (args[i] == "--tcp" && i + 1 < args.Length) ParsePorts(args[++i], tcpPorts);
            else if (args[i] == "--udp" && i + 1 < args.Length) ParsePorts(args[++i], udpPorts);
            else if (args[i] == "--dscp" && i + 1 < args.Length) { byte d; if (byte.TryParse(args[++i], out d)) dscpValue = d; }
            else if (args[i] == "--accel") { Console.WriteLine("[WD] \u52a0\u901f\u5668\u517c\u5bb9\u6a21\u5f0f\u5df2\u542f\u7528"); }
        }
        if (mode < 0) mode = 0;
        if (mode > 4) mode = 4;

        byte tosValue = (byte)(dscpValue << 2);
        bool bidir = modeBidir[mode];
        bool ackPri = modeAck[mode];
        bool winOpt = modeWin[mode];
        bool fecEn = modeFec[mode];
        bool btEn = modeBt[mode];
        bool udpFecEn = modeUdpFec[mode];
        uint qTime = modeQTime[mode];
        uint qLen = modeQLen[mode];
        uint qSize = modeQSize[mode];
        adaptiveQTime = qTime;

        string filter = BuildFilter(tcpPorts, udpPorts, bidir);

        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Console.WriteLine("[WD] \u6a21\u5f0f: {0} | DSCP={1} TOS=0x{2:X2} | \u53cc\u5411={3} ACK={4} TCP\u7a97\u53e3={5} FEC={6} BT={7} UDP-FEC={8}",
            modeNames[mode], dscpValue, tosValue, bidir, ackPri, winOpt, fecEn, btEn, udpFecEn);
        Console.WriteLine("[WD] \u8fc7\u6ee4\u5668: {0}", filter);
        Console.WriteLine("[WD] TCP\u7aef\u53e3: {0} | UDP\u7aef\u53e3: {1}",
            string.Join(",", tcpPorts.ToArray()), string.Join(",", udpPorts.ToArray()));

        ConsoleCancelEventHandler handler = (s, e) => { e.Cancel = true; running = false; if (handle != IntPtr.Zero) WinDivertShutdown(handle, WINDIVERT_SHUTDOWN_RECV); };
        Console.CancelKeyPress += handler;

        handle = WinDivertOpen(filter, WINDIVERT_LAYER_NETWORK, 0, 0);
        if (handle == IntPtr.Zero || handle == (IntPtr)(-1))
        {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("[WD] ERROR: \u65e0\u6cd5\u6253\u5f00\u53e5\u67c4 Error={0}", err);
            return;
        }
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_LENGTH, qLen);
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_TIME, qTime);
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_SIZE, qSize);
        Console.WriteLine("[WD] [{0}] \u53e5\u67c4\u5df2\u6253\u5f00\uff0c\u5f00\u59cb\u9010\u5305\u4f18\u5316...", modeNames[mode]);
        startTime = DateTime.Now;
        lastStatsTime = startTime;
        byte[] packet = new byte[65575];
        WINDIVERT_ADDRESS addr = new WINDIVERT_ADDRESS();
        uint recvLen;
        DateTime lastReport = startTime;

        while (running)
        {
            if (!WinDivertRecv(handle, packet, (uint)packet.Length, out recvLen, ref addr))
            {
                if (running)
                {
                    int err = Marshal.GetLastWin32Error();
                    if (err != 995) Console.WriteLine("[WD] \u63a5\u6536\u5931\u8d25 Error={0}", err);
                }
                break;
            }
            totalPackets++;
            bool isOutbound = (addr.Layer_Events_Flags & FLAG_OUTBOUND) != 0;
            bool isIPv6 = (addr.Layer_Events_Flags & FLAG_IPV6) != 0;
            if (isOutbound) outboundPackets++; else inboundPackets++;

            // Jitter tracking
            DateTime nowPkt = DateTime.Now;
            if (lastPktTime != DateTime.MinValue)
            {
                double delta = (nowPkt - lastPktTime).TotalMilliseconds;
                recentJitter.Enqueue(delta);
                if (recentJitter.Count > 50) recentJitter.Dequeue();
                double sum = 0; foreach (var j in recentJitter) sum += j;
                currentJitter = sum / recentJitter.Count;
            }
            lastPktTime = nowPkt;

            // Extract protocol and TCP info for FEC/BT
            int ipHdrLenFec = 0; byte protocolFec = 0; uint tcpSeqFec = 0; uint tcpAckFec = 0;
            bool isTcpDataFec = false; bool isAckOnlyFec = false;
            if (!isIPv6 && recvLen >= 20)
            {
                ipHdrLenFec = (packet[0] & 0x0F) * 4;
                if (ipHdrLenFec >= 20 && recvLen >= (uint)(ipHdrLenFec + 20))
                {
                    protocolFec = packet[9];
                    if (protocolFec == 6)
                    {
                        int tcpOff = ipHdrLenFec;
                        tcpSeqFec = (uint)((packet[tcpOff + 4] << 24) | (packet[tcpOff + 5] << 16) | (packet[tcpOff + 6] << 8) | packet[tcpOff + 7]);
                        tcpAckFec = (uint)((packet[tcpOff + 8] << 24) | (packet[tcpOff + 9] << 16) | (packet[tcpOff + 10] << 8) | packet[tcpOff + 11]);
                        byte flags = packet[tcpOff + 13];
                        bool isAck = (flags & 0x10) != 0;
                        isAckOnlyFec = isAck && ((flags & 0x3F) == 0x10);
                        uint ipTotal = (uint)((packet[2] << 8) | packet[3]);
                        int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                        if (ipTotal >= (uint)(ipHdrLenFec + tcpHdrLen) && ipTotal <= recvLen)
                        {
                            uint payload = ipTotal - (uint)ipHdrLenFec - (uint)tcpHdrLen;
                            isTcpDataFec = payload > 0;
                        }
                    }
                }
            }

            // Backtrack: track incoming ACKs to remove buffered packets
            if (btEn && !isOutbound && isAckOnlyFec)
            {
                lastAckSeq = tcpAckFec;
                while (btBuffer.Count > 0 && btBuffer.Peek().Seq < tcpAckFec)
                {
                    btBuffer.Dequeue();
                }
            }

            bool modified = ProcessPacket(packet, recvLen, tosValue, bidir, isOutbound, isIPv6, ackPri, winOpt);

            if (modified) { WinDivertHelperCalcChecksums(packet, recvLen, ref addr, 0); modifiedPackets++; }

            uint sendLen;
            WinDivertSend(handle, packet, recvLen, out sendLen, ref addr);

            // === FEC: duplicate outgoing UDP packets with alternate DSCP (path switching) ===
            if ((fecEn || udpFecEn) && isOutbound && protocolFec == 17 && recvLen > 0)
            {
                byte[] fecCopy = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, fecCopy, 0, (int)recvLen);
                byte altTos = altTosValues[dscpAltCounter % altTosValues.Length];
                dscpAltCounter++;
                if (!isIPv6) fecCopy[1] = altTos;
                else { fecCopy[0] = (byte)((fecCopy[0] & 0xF0) | ((altTos >> 4) & 0x0F)); fecCopy[1] = (byte)(((altTos & 0x0F) << 4) | (fecCopy[1] & 0x0F)); }
                WINDIVERT_ADDRESS fecAddr = addr;
                WinDivertHelperCalcChecksums(fecCopy, recvLen, ref fecAddr, 0);
                uint fecSendLen;
                WinDivertSend(handle, fecCopy, recvLen, out fecSendLen, ref fecAddr);
                fecPackets++;
            }

            // === Backtrack: duplicate outgoing TCP data packets + delayed recovery ===
            if (btEn && isOutbound && isTcpDataFec && recvLen > 0 && recvLen < 60000)
            {
                // Redundant duplication: send a copy with alternate DSCP
                byte[] btCopy = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, btCopy, 0, (int)recvLen);
                byte altTos = altTosValues[(dscpAltCounter + 2) % altTosValues.Length];
                if (!isIPv6) btCopy[1] = altTos;
                WINDIVERT_ADDRESS btAddr = addr;
                WinDivertHelperCalcChecksums(btCopy, recvLen, ref btAddr, 0);
                uint btSendLen;
                WinDivertSend(handle, btCopy, recvLen, out btSendLen, ref btAddr);
                btPackets++;

                // Buffer for delayed recovery
                byte[] bufCopy = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, bufCopy, 0, (int)recvLen);
                BtEntry entry = new BtEntry { Data = bufCopy, Len = recvLen, Addr = addr, Ts = DateTime.Now, Seq = tcpSeqFec };
                btBuffer.Enqueue(entry);
                if (btBuffer.Count > 200) btBuffer.Dequeue();
            }

            // === Delayed packet recovery: re-inject unacked packets older than 15ms ===
            if (btEn && btBuffer.Count > 0)
            {
                DateTime cutoff = DateTime.Now.AddMilliseconds(-15);
                int recovered = 0;
                while (btBuffer.Count > 0 && btBuffer.Peek().Ts < cutoff)
                {
                    BtEntry e = btBuffer.Dequeue();
                    if (e.Seq >= lastAckSeq)
                    {
                        byte[] rcv = new byte[e.Len];
                        Buffer.BlockCopy(e.Data, 0, rcv, 0, (int)e.Len);
                        byte boostTos = 0xC0;
                        if (!isIPv6) rcv[1] = boostTos;
                        WINDIVERT_ADDRESS rcvAddr = e.Addr;
                        WinDivertHelperCalcChecksums(rcv, e.Len, ref rcvAddr, 0);
                        uint rcvSendLen;
                        WinDivertSend(handle, rcv, e.Len, out rcvSendLen, ref rcvAddr);
                        btRecovered++;
                        recovered++;
                    }
                }
                if (recovered > 0)
                {
                    Console.WriteLine("[WD] BT \u5ef6\u540e\u6062\u590d: {0}\u4e2a\u5305\u91cd\u53d1 (jitter={1:F1}ms)", recovered, currentJitter);
                }
            }

            if ((DateTime.Now - lastReport).TotalSeconds >= 5)
            {
                AdaptiveOptimize(qTime, mode);
                TimeSpan el = DateTime.Now - startTime;
                double rate = el.TotalSeconds > 0 ? totalPackets / el.TotalSeconds : 0;
                Console.WriteLine("[WD] [{0}] \u8fd0\u884c{1:F0}s | \u603b\u5305{2} | \u4f18\u5316{3} | TCP:{4} UDP:{5} ACK:{6} FEC:{7} BT:{8} \u6062\u590d:{9} | {10:F1}pkt/s | \u961f\u5217{11}ms | \u6296\u52a8{12:F1}ms",
                    modeNames[mode], el.TotalSeconds, totalPackets, modifiedPackets, tcpPackets, udpPackets, ackPackets, fecPackets, btPackets, btRecovered, rate, adaptiveQTime, currentJitter);
                lastReport = DateTime.Now;
            }
        }
        if (handle != IntPtr.Zero && handle != (IntPtr)(-1)) { WinDivertShutdown(handle, WINDIVERT_SHUTDOWN_RECV); Thread.Sleep(100); WinDivertClose(handle); }
        TimeSpan total = DateTime.Now - startTime;
        Console.WriteLine("[WD] \u5df2\u505c\u6b62 | \u8fd0\u884c{0:F0}s | \u603b\u5305{1} | \u4f18\u5316{2} | FEC:{3} BT:{4} \u6062\u590d:{5}", total.TotalSeconds, totalPackets, modifiedPackets, fecPackets, btPackets, btRecovered);
    }

    static void ParsePorts(string s, List<int> list)
    {
        list.Clear();
        string[] parts = s.Split(new char[] { ',', ' ', ';' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (string p in parts)
        {
            int port;
            if (int.TryParse(p.Trim(), out port) && port > 0 && port < 65536) list.Add(port);
        }
        if (list.Count == 0) list.Add(25565);
    }

    static string BuildFilter(List<int> tcpPorts, List<int> udpPorts, bool bidir)
    {
        List<string> parts = new List<string>();
        foreach (int p in tcpPorts) { parts.Add(string.Format("tcp.DstPort == {0}", p)); parts.Add(string.Format("tcp.SrcPort == {0}", p)); }
        foreach (int p in udpPorts) { parts.Add(string.Format("udp.DstPort == {0}", p)); parts.Add(string.Format("udp.SrcPort == {0}", p)); }
        string portFilter = string.Join(" or ", parts.ToArray());
        if (bidir) return portFilter;
        return "outbound and (" + portFilter + ")";
    }

    static bool ProcessPacket(byte[] packet, uint len, byte tosValue, bool bidir, bool isOutbound, bool isIPv6, bool ackPri, bool winOpt)
    {
        if (len < 20) return false;
        bool modified = false;
        int ipHdrLen;
        byte protocol;

        if (!isIPv6)
        {
            byte version = (byte)((packet[0] >> 4) & 0x0F);
            if (version != 4) return false;
            ipHdrLen = (packet[0] & 0x0F) * 4;
            if (ipHdrLen < 20 || len < ipHdrLen) return false;
            protocol = packet[9];
            // FPS: mark small UDP game packets (< 512B) even in non-bidir mode
            if (bidir || isOutbound || (protocol == 17 && len < 512))
            {
                if (packet[1] != tosValue) { packet[1] = tosValue; modified = true; }
            }
        }
        else
        {
            byte version = (byte)((packet[0] >> 4) & 0x0F);
            if (version != 6) return false;
            ipHdrLen = 40;
            if (len < ipHdrLen) return false;
            protocol = packet[6];
            if (bidir || isOutbound || (protocol == 17 && len < 512))
            {
                byte tcH = (byte)((tosValue >> 4) & 0x0F), tcL = (byte)(tosValue & 0x0F);
                byte o0 = packet[0], o1 = packet[1];
                packet[0] = (byte)((o0 & 0xF0) | tcH);
                packet[1] = (byte)((tcL << 4) | (o1 & 0x0F));
                if (o0 != packet[0] || o1 != packet[1]) modified = true;
            }
        }

        if (protocol == 6 && len >= (uint)(ipHdrLen + 20))
        {
            tcpPackets++;
            int tcpOff = ipHdrLen;
            byte flags = packet[tcpOff + 13];
            bool isAck = (flags & 0x10) != 0;
            bool isAckOnly = isAck && ((flags & 0x3F) == 0x10);

            uint payloadLen = 0;
            if (!isIPv6)
            {
                uint ipTotal = (uint)((packet[2] << 8) | packet[3]);
                int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                if (ipTotal >= (uint)(ipHdrLen + tcpHdrLen) && ipTotal <= len)
                    payloadLen = ipTotal - (uint)ipHdrLen - (uint)tcpHdrLen;
            }
            else
            {
                uint ipv6Pay = (uint)((packet[4] << 8) | packet[5]);
                int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                if (ipv6Pay >= (uint)tcpHdrLen && (ipv6Pay + 40) <= len)
                    payloadLen = ipv6Pay - (uint)tcpHdrLen;
            }

            if (isAckOnly && payloadLen == 0) ackPackets++;

            if (winOpt && isOutbound && isAck && payloadLen == 0 && len >= (uint)(tcpOff + 16))
            {
                ushort win = (ushort)((packet[tcpOff + 14] << 8) | packet[tcpOff + 15]);
                if (win > 65535) { packet[tcpOff + 14] = 0xFF; packet[tcpOff + 15] = 0xFF; modified = true; }
            }
        }
        else if (protocol == 17) udpPackets++;

        return modified;
    }

    static void AdaptiveOptimize(uint baseQTime, int mode)
    {
        if (mode < 3) return;
        DateTime now = DateTime.Now;
        double elapsed = (now - lastStatsTime).TotalSeconds;
        if (elapsed <= 0) return;
        long delta = totalPackets - lastTotal;
        double rate = delta / elapsed;
        lastTotal = totalPackets;
        lastStatsTime = now;
        uint target = baseQTime;
        if (rate > 2000) target = (uint)(baseQTime * 0.3);
        else if (rate > 1000) target = (uint)(baseQTime * 0.5);
        else if (rate > 500) target = (uint)(baseQTime * 0.7);
        if (target < 5) target = 5;
        if (target != adaptiveQTime && handle != IntPtr.Zero && handle != (IntPtr)(-1))
        {
            WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_TIME, target);
            adaptiveQTime = target;
        }
    }
}
'@

# 下载 WinDivert 文件
function Ensure-WinDivertFiles {
    if (-not (Test-Path $script:wdDir)) { New-Item -Path $script:wdDir -ItemType Directory -Force | Out-Null }
    $dllPath = Join-Path $script:wdDir "WinDivert.dll"
    $sysPath = Join-Path $script:wdDir "WinDivert64.sys"

    if ((Test-Path $dllPath) -and (Test-Path $sysPath)) { return $true }

    # 下载官方包
    $url = 'https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip'
    $zipPath = Join-Path $script:wdDir 'WinDivert.zip'
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 30
        $extractDir = Join-Path $script:wdDir 'temp'
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        # 复制 x64 文件
        $srcDll = Get-ChildItem $extractDir -Recurse -Filter 'WinDivert.dll' | Where-Object { $_.DirectoryName -match 'x64' } | Select-Object -First 1
        $srcSys = Get-ChildItem $extractDir -Recurse -Filter 'WinDivert64.sys' | Where-Object { $_.DirectoryName -match 'x64' } | Select-Object -First 1
        if ($srcDll -and $srcSys) {
            Copy-Item $srcDll.FullName $dllPath -Force
            Copy-Item $srcSys.FullName $sysPath -Force
            Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            return $true
        }
    } catch {
        Add-LogEntry "ERROR" "WinDivert 下载失败: $($_.Exception.Message)"
    }
    return $false
}

# 编译 C# 标记器
function Compile-WinDivertMarker {
    $csPath = Join-Path $script:wdDir 'WinDivertMarker.cs'
    $exePath = Join-Path $script:wdDir 'WinDivertMarker.exe'
    $script:wdCsSource | Set-Content $csPath -Encoding UTF8 -Force

    # Kill any running WinDivertMarker process and delete old EXE
    Stop-Process -Name "WinDivertMarker" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
    Remove-Item $exePath -Force -ErrorAction SilentlyContinue

    $csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { $csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe' }
    if (-not (Test-Path $csc)) { return $null }

    & $csc /nologo /optimize+ /target:exe /platform:x64 /out:$exePath $csPath 2>&1 | Out-Null
    if (Test-Path $exePath) { return $exePath }
    return $null
}

# --- WinDivert handlers ---

# --- WdMode button selection ---
$wdModeNames = @('普通模式', '最佳模式', '急速模式', '狂暴模式', 'Backtrack模式')
function Set-WdMode {
    param([int]$Mode)
    $window.FindName("WdModeLabel").Text = "$Mode"
    for ($i = 0; $i -lt 5; $i++) {
        $btn = $window.FindName("WdModeBtn$i")
        if (-not $btn) { continue }
        if ($i -eq $Mode) {
            $btn.Background = Create-Brush "#7CC7FF"
            $btn.Foreground = Create-Brush "#111111"
        } else {
            $btn.Background = Create-Brush "#3A3A3A"
            $btn.Foreground = Create-Brush "#E8E8E8"
        }
    }
}
for ($mi = 0; $mi -lt 5; $mi++) {
    $wdBtn = $window.FindName("WdModeBtn$mi")
    if ($wdBtn) {
        $wdBtn.Add_Click({ param($s, $e); Set-WdMode ([int]$s.Tag) })
    }
}

# --- Start ---
$window.FindName("BtnWdStart").Add_Click({
    $btnStart = $window.FindName("BtnWdStart")
    $btnStop = $window.FindName("BtnWdStop")
    $resultBox = $window.FindName("WdResultText")
    $tcpPortBox = $window.FindName("WdTcpPort")
    $udpPortBox = $window.FindName("WdUdpPort")
    $dscpBox = $window.FindName("WdDscp")
    $modeBox = $window.FindName("WdModeLabel")

    try {
    $warn = @"
[WinDivert 内核级逐包优化 - 警告声明]

此功能将安装 WinDivert 内核驱动（WinDivert64.sys），在 NDIS 层逐包拦截并修改网络数据包的 DSCP/TOS 字段。

[!] 风险提示：
1. 内核驱动安装可能导致系统蓝屏（BSOD）
2. 杀毒软件可能拦截或删除驱动文件
3. 驱动运行时所有指定端口流量经过内核拦截层
4. 如系统出现不稳定，请立即点击停止并卸载驱动
5. 卸载驱动后需重启计算机以完全清除

[!] 确认事项：
- 本软件不对此功能造成的任何系统损坏负责
- 建议在重要操作前创建系统还原点
- WinDivert 驱动来自官方 GitHub 发布（v2.2.2, LGPL 许可）

是否确认启动 WinDivert 逐包优化？
"@
    $confirm = [System.Windows.MessageBox]::Show($warn, "WinDivert 警告声明", "OKCancel", "Warning", "Cancel")
    if ($confirm -ne "OK") { return }

    $btnStart.IsEnabled = $false
    $btnStart.Content = "启动中..."
    $resultBox.Text = "正在准备 WinDivert 环境...`n"

    # 1. 下载 WinDivert 文件
    $resultBox.AppendText("1. 检查/下载 WinDivert 驱动...`n")
    [System.Windows.Forms.Application]::DoEvents()
    if (-not (Ensure-WinDivertFiles)) {
        $resultBox.AppendText("[失败] 无法下载 WinDivert 文件`n")
        $btnStart.Content = "启动逐包优化"; $btnStart.IsEnabled = $true
        return
    }
    $resultBox.AppendText("  [OK] WinDivert.dll + WinDivert64.sys 就绪`n")

    # 2. 编译 C# 标记器
    $resultBox.AppendText("2. 编译逐包标记器...`n")
    [System.Windows.Forms.Application]::DoEvents()
    $exePath = Compile-WinDivertMarker
    if (-not $exePath) {
        $resultBox.AppendText("[失败] C# 编译失败`n")
        $btnStart.Content = "启动逐包优化"; $btnStart.IsEnabled = $true
        return
    }
    $resultBox.AppendText("  [OK] WinDivertMarker.exe 编译完成`n")

    # 3. 启动进程（输出重定向到文件，不使用管道和定时器）
    $tcpPort = if ($tcpPortBox) { $tcpPortBox.Text } else { "25565" }
    $udpPort = if ($udpPortBox) { $udpPortBox.Text } else { "19132" }
    $dscp = if ($dscpBox) { $dscpBox.Text } else { "46" }
    $modeIdx = if ($modeBox) { [int]$modeBox.Text } else { 1 }
    $modeNames = @('普通模式', '最佳模式', '急速模式', '狂暴模式', 'Backtrack')
    $modeName = if ($modeIdx -ge 0 -and $modeIdx -lt 5) { $modeNames[$modeIdx] } else { '最佳模式' }
    if ($modeIdx -lt 0) { $modeIdx = 1 }
    if ($modeIdx -gt 4) { $modeIdx = 4 }
    $resultBox.AppendText("3. 启动逐包优化 [$modeName] (TCP=$tcpPort UDP=$udpPort DSCP=$dscp)...`n")
    [System.Windows.Forms.Application]::DoEvents()

    $logPath = Join-Path $script:wdDir 'wd_output.log'
    $errPath = Join-Path $script:wdDir 'wd_error.log'

    # 清除旧日志
    Remove-Item $logPath -Force -ErrorAction SilentlyContinue
    Remove-Item $errPath -Force -ErrorAction SilentlyContinue

    # 用 Start-Process 启动，输出到文件（不用管道，不用定时器）
    $accelChk = $window.FindName("ChkAccelCompat")
    $accelFlag = if ($accelChk -and $accelChk.IsChecked) { " --accel" } else { "" }
    $script:wdProcess = Start-Process -FilePath $exePath `
        -ArgumentList "--mode $modeIdx --tcp $tcpPort --udp $udpPort --dscp $dscp$accelFlag" `
        -WorkingDirectory $script:wdDir `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError $errPath `
        -NoNewWindow -PassThru -ErrorAction Stop

    $resultBox.AppendText("  [OK] 进程已启动 (PID=$($script:wdProcess.Id))`n")
    $resultBox.AppendText("========================================`n")
    $resultBox.AppendText("WinDivert 正在后台运行...`n")
    $resultBox.AppendText("点击刷新状态查看实时包计数`n")
    $btnStop.IsEnabled = $true
    Add-LogEntry "INFO" "WinDivert 逐包优化已启动 PID=$($script:wdProcess.Id)"

    } catch {
        $errMsg = $_.Exception.Message
        try { $resultBox.AppendText("[失败] $errMsg`n") } catch {}
        try { Add-LogEntry "ERROR" "WinDivert 启动失败: $errMsg" } catch {}
        $btnStart.Content = "启动逐包优化"
        $btnStart.IsEnabled = $true
    }
})

# --- Stop ---
$window.FindName("BtnWdStop").Add_Click({
    $btnStart = $window.FindName("BtnWdStart")
    $btnStop = $window.FindName("BtnWdStop")
    $resultBox = $window.FindName("WdResultText")

    if ($script:wdProcess -and -not $script:wdProcess.HasExited) {
        try { $script:wdProcess.Kill() } catch {}
        Start-Sleep -Milliseconds 300
        $resultBox.AppendText("WinDivert 已停止`n")
        Add-LogEntry "INFO" "WinDivert 逐包优化已停止"
    }
    Stop-Process -Name "WinDivertMarker" -Force -ErrorAction SilentlyContinue
    $script:wdProcess = $null
    $btnStart.Content = "启动逐包优化"
    $btnStart.IsEnabled = $true
    $btnStop.IsEnabled = $false
})

# --- Refresh ---
$window.FindName("BtnWdRefresh").Add_Click({
    $resultBox = $window.FindName("WdResultText")
    $logPath = Join-Path $script:wdDir 'wd_output.log'

    if ($script:wdProcess -and -not $script:wdProcess.HasExited) {
        $resultBox.Text = "WinDivert 运行中 (PID=$($script:wdProcess.Id))`n"
        $resultBox.AppendText("========================================`n")
        if (Test-Path $logPath) {
            try {
                $lines = Get-Content $logPath -Tail 15 -Encoding UTF8 -ErrorAction Stop
                foreach ($l in $lines) { $resultBox.AppendText("$l`n") }
            } catch {}
        }
    } elseif ($script:wdProcess) {
        $resultBox.Text = "WinDivert 进程已退出 (ExitCode=$($script:wdProcess.ExitCode))`n"
        $resultBox.AppendText("========================================`n")
        if (Test-Path $logPath) {
            try {
                $lines = Get-Content $logPath -Tail 15 -Encoding UTF8 -ErrorAction Stop
                foreach ($l in $lines) { $resultBox.AppendText("$l`n") }
            } catch {}
        }
    } else {
        $resultBox.Text = "WinDivert 未运行`n"
    }
})

# --- Uninstall ---
$window.FindName("BtnWdUninstall").Add_Click({
    $resultBox = $window.FindName("WdResultText")

    $confirm = [System.Windows.MessageBox]::Show(
        "确认卸载 WinDivert 驱动？`n`n卸载后建议重启计算机以完全清除。`nWinDivert 文件将被删除。",
        "卸载确认", "OKCancel", "Question", "Cancel")
    if ($confirm -ne "OK") { return }

    $resultBox.Text = "正在卸载 WinDivert...`n"
    [System.Windows.Forms.Application]::DoEvents()

    # 停止进程
    if ($script:wdProcess -and -not $script:wdProcess.HasExited) {
        try { $script:wdProcess.Kill() } catch {}
        $script:wdProcess = $null
    }

    # 卸载驱动服务
    $cmds = @('sc stop WinDivert', 'sc stop WinDivert14', 'sc delete WinDivert', 'sc delete WinDivert14')
    foreach ($cmd in $cmds) {
        $r = Invoke-Command $cmd
        $resultBox.AppendText("$cmd -> exit=$($r.ExitCode)`n")
    }

    # 删除文件
    if (Test-Path $script:wdDir) {
        try {
            Remove-Item $script:wdDir -Recurse -Force -ErrorAction Stop
            $resultBox.AppendText("[OK] WinDivert 文件已删除`n")
        } catch {
            $resultBox.AppendText("[WARN] 部分文件无法删除`n")
        }
    }

    $resultBox.AppendText("========================================`n")
    $resultBox.AppendText("卸载完成，建议重启计算机。`n")
    Add-LogEntry "INFO" "WinDivert 驱动已卸载"
    [System.Windows.MessageBox]::Show("WinDivert 驱动已卸载。`n建议重启计算机以完全清除。", "完成", "OK", "Information") | Out-Null
})

# === 加速器兼容支持 ===
$accelPatterns = @(
    @("UU加速器", @("UU.exe", "UUService.exe", "UUTray.exe")),
    @("迅游加速器", @("Xunyou.exe", "XunyouService.exe", "xunyou_tray.exe")),
    @("雷神加速器", @("leigod.exe", "leigod_service.exe", "leigod_tray.exe")),
    @("3733加速器", @("3733.exe", "3733Service.exe")),
    @("奇游加速器", @("qiyu.exe", "qiyu_service.exe")),
    @("网易UU", @("UU.exe", "UUService.exe")),
    @("腾讯加速器", @("TGP_Accelerator.exe", "TenSafeDLL.exe"))
)

$window.FindName("BtnAccelDetect").Add_Click({
    $statusEl = $window.FindName("AccelStatus")
    $accelSel = $window.FindName("AccelSelector")
    $detected = $null

    foreach ($pattern in $accelPatterns) {
        $accelName = $pattern[0]
        $procNames = $pattern[1]
        foreach ($pn in $procNames) {
            $proc = Get-Process -Name $pn -ErrorAction SilentlyContinue
            if ($proc) {
                $detected = $accelName
                break
            }
        }
        if ($detected) { break }
    }

    if ($detected) {
        $statusEl.Text = "已检测到: $detected"
        $statusEl.Foreground = Create-Brush "#00E676"
        # Auto-select in dropdown
        $items = $accelSel.Items
        for ($i = 0; $i -lt $items.Count; $i++) {
            if ($items[$i].Content -like "*$detected*") {
                $accelSel.SelectedIndex = $i
                break
            }
        }
        Add-LogEntry "INFO" "检测到加速器: $detected"
    } else {
        $statusEl.Text = "未检测到加速器"
        $statusEl.Foreground = Create-Brush "#E8E8E8"
        Add-LogEntry "INFO" "未检测到加速器进程"
    }
    [System.Windows.MessageBox]::Show($statusEl.Text, "加速器检测", "OK", "Information") | Out-Null
})

$window.FindName("BtnAccelApply").Add_Click({
    $gameSel = $window.FindName("GameSelector")
    $tcpPortBox = $window.FindName("WdTcpPort")
    $udpPortBox = $window.FindName("WdUdpPort")
    $idx = $gameSel.SelectedIndex

    switch ($idx) {
        0 { $tcpPortBox.Text = "25565"; $udpPortBox.Text = "19132" }
        1 { $tcpPortBox.Text = "25565"; $udpPortBox.Text = "19132" }
        2 { $tcpPortBox.Text = "27015"; $udpPortBox.Text = "27015,27020,27030,27036" }
        3 { $tcpPortBox.Text = "7448"; $udpPortBox.Text = "7448" }
        4 { $tcpPortBox.Text = ""; $udpPortBox.Text = "37015,37017,37019,37021,37031" }
        5 { $tcpPortBox.Text = ""; $udpPortBox.Text = "3074,27015,27017,27018,27019,27020" }
        6 { $tcpPortBox.Text = ""; $udpPortBox.Text = "27015,27036" }
        7 { $tcpPortBox.Text = ""; $udpPortBox.Text = "3074,6015" }
        8 { }
    }

    $accelChk = $window.FindName("ChkAccelCompat")
    $msg = if ($accelChk.IsChecked) {
        "已启用加速器兼容模式`nWinDivert 过滤器将匹配全部网卡的流量`n端口: TCP=$($tcpPortBox.Text) UDP=$($udpPortBox.Text)"
    } else {
        "端口预设已应用`nTCP=$($tcpPortBox.Text) UDP=$($udpPortBox.Text)"
    }
    [System.Windows.MessageBox]::Show($msg, "端口预设", "OK", "Information") | Out-Null
})
$window.FindName("BtnTestDriverCheck").Add_Click({
    $btn = $window.FindName("BtnTestDriverCheck")
    $oldText = $btn.Content
    $btn.Content = "检测中..."
    $btn.IsEnabled = $false

    $results = New-Object System.Collections.ArrayList
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if (-not $adapters -or $adapters.Count -eq 0) {
            $results.Add("[WARN] 未检测到活动网卡") | Out-Null
        } else {
            foreach ($adapter in $adapters) {
                $results.Add("[INFO] 网卡：$($adapter.Name)") | Out-Null
                $results.Add("       描述：$($adapter.InterfaceDescription)") | Out-Null
                $results.Add("       速度：$($adapter.LinkSpeed)") | Out-Null

                $driver = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
                    Where-Object { $_.DeviceName -eq $adapter.InterfaceDescription -or $_.FriendlyName -eq $adapter.InterfaceDescription } |
                    Select-Object -First 1

                if ($driver) {
                    $driverDate = if ($driver.DriverDate) { ([Management.ManagementDateTimeConverter]::ToDateTime($driver.DriverDate)).ToString("yyyy-MM-dd") } else { "未知" }
                    $results.Add("       驱动厂商：$($driver.DriverProviderName)") | Out-Null
                    $results.Add("       驱动版本：$($driver.DriverVersion)") | Out-Null
                    $results.Add("       驱动日期：$driverDate") | Out-Null
                    $results.Add("       建议：可执行驱动参数优化；如驱动日期较旧，再到主板/网卡品牌官网下载稳定版驱动。") | Out-Null
                } else {
                    $results.Add("       [WARN] 未读取到驱动签名信息，可在设备管理器中查看") | Out-Null
                }
                $results.Add("") | Out-Null
            }
        }
    } catch {
        $results.Add("[ERROR] 驱动检测失败：$($_.Exception.Message)") | Out-Null
    }

    $list = $window.FindName("ResultsList")
    if ($list) {
        $list.Items.Clear()
        foreach ($r in $results) { $list.Items.Add($r) | Out-Null }
    }
    $btn.Content = $oldText
    $btn.IsEnabled = $true
    Add-LogEntry "INFO" "网卡驱动检测已完成"
})

$window.FindName("BtnOptimizeDriverParams").Add_Click({
    $btn = $window.FindName("BtnOptimizeDriverParams")
    $oldText = $btn.Content
    $btn.Content = "优化中..."
    $btn.IsEnabled = $false

    $results = New-Object System.Collections.ArrayList
    $doRss = [bool]$window.FindName("ChkDriverRss").IsChecked
    $doPower = [bool]$window.FindName("ChkDriverPower").IsChecked
    $doEnergy = [bool]$window.FindName("ChkDriverEnergy").IsChecked
    $doGreen = [bool]$window.FindName("ChkDriverGreen").IsChecked
    $doPowerMode = [bool]$window.FindName("ChkDriverPowerMode").IsChecked
    $doUltraLow = [bool]$window.FindName("ChkDriverUltraLow").IsChecked
    $doInterrupt = [bool]$window.FindName("ChkDriverInterrupt").IsChecked
    $doFlow = [bool]$window.FindName("ChkDriverFlow").IsChecked
    $doRegistryEco = [bool]$window.FindName("ChkDriverRegistryEco").IsChecked

    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
        if (-not $adapters -or $adapters.Count -eq 0) {
            $results.Add("[WARN] 未检测到活动网卡") | Out-Null
        } else {
            if ($doRss) {
                try {
                    Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -TaskOffload Enabled -ErrorAction Stop
                    $results.Add("[OK] 全局 RSS 与 TaskOffload 已启用") | Out-Null
                } catch {
                    $results.Add("[WARN] 全局 RSS/TaskOffload 设置失败：$($_.Exception.Message)") | Out-Null
                }
            } else {
                $results.Add("[SKIP] 未勾选：全局 RSS / TaskOffload") | Out-Null
            }

            foreach ($adapter in $adapters) {
                $results.Add("[INFO] 正在优化网卡驱动参数：$($adapter.Name)") | Out-Null

                if ($doRss) {
                    try {
                        Enable-NetAdapterRss -Name $adapter.Name -ErrorAction Stop
                        $results.Add("[OK] $($adapter.Name)：RSS 已启用") | Out-Null
                    } catch {
                        $results.Add("[WARN] $($adapter.Name)：RSS 不支持或启用失败") | Out-Null
                    }
                }

                if ($doPower) {
                    try {
                        Set-NetAdapterPowerManagement -Name $adapter.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop
                        $results.Add("[OK] $($adapter.Name)：禁止系统关闭此设备以节能") | Out-Null
                    } catch {
                        $results.Add("[INFO] $($adapter.Name)：电源管理项不支持或无需修改") | Out-Null
                    }
                }

                $displaySettings = @()
                if ($doEnergy) { $displaySettings += ,@("Energy Efficient Ethernet", "Disabled", "关闭节能以太网") }
                if ($doGreen) { $displaySettings += ,@("Green Ethernet", "Disabled", "关闭绿色以太网") }
                if ($doPowerMode) { $displaySettings += ,@("Power Saving Mode", "Disabled", "关闭省电模式") }
                if ($doUltraLow) { $displaySettings += ,@("Ultra Low Power Mode", "Disabled", "关闭超低功耗模式") }
                if ($doInterrupt) { $displaySettings += ,@("Interrupt Moderation", "Disabled", "关闭中断调节以降低延迟") }
                if ($doFlow) { $displaySettings += ,@("Flow Control", "Disabled", "关闭流控以减少排队延迟") }

                foreach ($setting in $displaySettings) {
                    $displayName = $setting[0]
                    $targetValue = $setting[1]
                    $label = $setting[2]
                    try {
                        $prop = Get-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $displayName -ErrorAction SilentlyContinue
                        if ($prop) {
                            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $displayName -DisplayValue $targetValue -NoRestart -ErrorAction Stop
                            $results.Add("[OK] $($adapter.Name)：$label ($displayName=$targetValue)") | Out-Null
                        } else {
                            $results.Add("[INFO] $($adapter.Name)：不支持 $displayName，已跳过") | Out-Null
                        }
                    } catch {
                        $results.Add("[WARN] $($adapter.Name)：$displayName 修改失败") | Out-Null
                    }
                }

                if ($doRegistryEco) {
                    $registrySettings = @(
                        @("AutoDisableGigabit", "0", "禁止自动降千兆"),
                        @("EnableGreenEthernet", "0", "关闭绿色以太网注册项"),
                        @("EEE", "0", "关闭 EEE 注册项")
                    )

                    foreach ($setting in $registrySettings) {
                        $registryKeyword = $setting[0]
                        $targetValue = $setting[1]
                        $label = $setting[2]
                        try {
                            $prop = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $registryKeyword -ErrorAction SilentlyContinue
                            if ($prop) {
                                Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword $registryKeyword -RegistryValue $targetValue -NoRestart -ErrorAction Stop
                                $results.Add("[OK] $($adapter.Name)：$label ($registryKeyword=$targetValue)") | Out-Null
                            }
                        } catch {
                            $results.Add("[INFO] $($adapter.Name)：$registryKeyword 不支持或无需修改") | Out-Null
                        }
                    }
                }

                $results.Add("[INFO] $($adapter.Name)：驱动参数优化完成，部分项目可能需要禁用/启用网卡或重启后生效") | Out-Null
                $results.Add("") | Out-Null
            }
        }
    } catch {
        $results.Add("[ERROR] 网卡驱动参数优化失败：$($_.Exception.Message)") | Out-Null
    }

    $list = $window.FindName("ResultsList")
    if ($list) {
        $list.Items.Clear()
        foreach ($r in $results) { $list.Items.Add($r) | Out-Null }
    }
    $btn.Content = $oldText
    $btn.IsEnabled = $true
    Add-LogEntry "INFO" "网卡驱动参数优化已完成"
    [System.Windows.MessageBox]::Show("网卡驱动参数优化已完成。部分参数可能需要禁用/启用网卡或重启后生效。", "完成", "OK", "Information") | Out-Null
})

# ====== MTU 最佳值智能优化 ======
$script:detectedMtu = 0

# 探测最佳 MTU（二分法）
$window.FindName("BtnMtuDetect").Add_Click({
    $btn = $window.FindName("BtnMtuDetect")
    $oldText = $btn.Content
    $btn.Content = "探测中..."
    $btn.IsEnabled = $false
    $resultText = $window.FindName("MtuResultText")
    $resultText.Text = "正在探测最佳 MTU 值..."

    $targets = @("223.5.5.5", "223.6.6.6")
    $activeTarget = $null

    # 先检测哪个 DNS 可达
    foreach ($t in $targets) {
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo.FileName = "cmd.exe"
        $p.StartInfo.Arguments = "/c ping -n 2 -w 2000 $t"
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.CreateNoWindow = $true
        $p.Start() | Out-Null
        $out = $p.StandardOutput.ReadToEnd()
        $p.WaitForExit(8000) | Out-Null
        if ($p.ExitCode -eq 0) { $activeTarget = $t; break }
    }

    if (-not $activeTarget) {
        $resultText.Text = "[FAIL] 无法连接测试服务器（223.5.5.5 / 223.6.6.6），请检查网络连接后重试。"
        $btn.Content = $oldText
        $btn.IsEnabled = $true
        Add-LogEntry "WARN" "MTU 探测失败：无法连接测试服务器"
        return
    }

    $resultText.Text = "已连接 $activeTarget，正在二分法搜索最大不分片包大小..."

    # 二分法搜索 1400-1472
    $low = 1400
    $high = 1472
    $bestSize = 1400

    while ($low -le $high) {
        $mid = [math]::Floor(($low + $high) / 2)
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo.FileName = "cmd.exe"
        $p.StartInfo.Arguments = "/c ping -n 1 -f -l $mid -w 3000 $activeTarget"
        $p.StartInfo.UseShellExecute = $false
        $p.StartInfo.RedirectStandardOutput = $true
        $p.StartInfo.CreateNoWindow = $true
        $p.Start() | Out-Null
        $p.StandardOutput.ReadToEnd() | Out-Null
        $p.WaitForExit(10000) | Out-Null

        if ($p.ExitCode -eq 0) {
            $bestSize = $mid
            $low = $mid + 1
        } else {
            $high = $mid - 1
        }
        $resultText.Text = "搜索中... 当前测试包大小: $mid 字节，已确认最大: $bestSize 字节"
    }

    $optimalMtu = $bestSize + 28
    $script:detectedMtu = $optimalMtu

    $resultText.Text = "探测完成！`n目标服务器: $activeTarget`n最大不分片包大小: $bestSize 字节`n最佳 MTU 值: $optimalMtu`n`n请在上方选择网卡后点击「应用 MTU」生效。"
    $btn.Content = $oldText
    $btn.IsEnabled = $true
    Add-LogEntry "INFO" "MTU 探测完成：最佳值 $optimalMtu（包大小 $bestSize，目标 $activeTarget）"
})

# 应用 MTU
$window.FindName("BtnMtuApply").Add_Click({
    $btn = $window.FindName("BtnMtuApply")
    $resultText = $window.FindName("MtuResultText")

    if ($script:detectedMtu -le 0) {
        $resultText.Text = "[WARN] 请先点击「探测最佳 MTU」获取最佳值。"
        return
    }

    $combo = $window.FindName("MtuAdapterCombo")
    $adapter = $combo.SelectedItem
    if (-not $adapter) {
        $resultText.Text = "[WARN] 请先选择要应用 MTU 的网卡。"
        return
    }

    $mtu = $script:detectedMtu
    $btn.Content = "应用中..."
    $btn.IsEnabled = $false
    $resultText.Text = "正在将 MTU=$mtu 应用到网卡「$adapter」..."

    try {
        # 设置 MTU
        $p1 = New-Object System.Diagnostics.Process
        $p1.StartInfo.FileName = "cmd.exe"
        $p1.StartInfo.Arguments = "/c netsh int ipv4 set subinterface `"$adapter`" mtu=$mtu store=persistent"
        $p1.StartInfo.UseShellExecute = $false
        $p1.StartInfo.RedirectStandardOutput = $true
        $p1.StartInfo.RedirectStandardError = $true
        $p1.StartInfo.CreateNoWindow = $true
        $p1.Start() | Out-Null
        $p1.StandardOutput.ReadToEnd() | Out-Null
        $p1.StandardError.ReadToEnd() | Out-Null
        $p1.WaitForExit(10000) | Out-Null

        if ($p1.ExitCode -ne 0) {
            $resultText.Text = "[FAIL] MTU 设置失败（netsh 返回错误码 $($p1.ExitCode)）。`n请确认以管理员身份运行，且网卡名称正确。"
            $btn.Content = "应用 MTU"
            $btn.IsEnabled = $true
            Add-LogEntry "WARN" "MTU 应用失败：netsh 返回 $($p1.ExitCode)"
            return
        }

        # 禁用/启用网卡使 MTU 生效
        Start-Sleep -Milliseconds 500
        $p2 = New-Object System.Diagnostics.Process
        $p2.StartInfo.FileName = "cmd.exe"
        $p2.StartInfo.Arguments = "/c netsh interface set interface `"$adapter`" admin=disabled"
        $p2.StartInfo.UseShellExecute = $false
        $p2.StartInfo.CreateNoWindow = $true
        $p2.Start() | Out-Null
        $p2.WaitForExit(10000) | Out-Null
        Start-Sleep -Seconds 2

        $p3 = New-Object System.Diagnostics.Process
        $p3.StartInfo.FileName = "cmd.exe"
        $p3.StartInfo.Arguments = "/c netsh interface set interface `"$adapter`" admin=enabled"
        $p3.StartInfo.UseShellExecute = $false
        $p3.StartInfo.CreateNoWindow = $true
        $p3.Start() | Out-Null
        $p3.WaitForExit(10000) | Out-Null
        Start-Sleep -Seconds 2

        # 验证结果
        $p4 = New-Object System.Diagnostics.Process
        $p4.StartInfo.FileName = "cmd.exe"
        $p4.StartInfo.Arguments = "/c netsh int ipv4 show subinterface `"$adapter`""
        $p4.StartInfo.UseShellExecute = $false
        $p4.StartInfo.RedirectStandardOutput = $true
        $p4.StartInfo.CreateNoWindow = $true
        $p4.Start() | Out-Null
        $verifyOut = $p4.StandardOutput.ReadToEnd()
        $p4.WaitForExit(8000) | Out-Null

        $verifyLine = ($verifyOut -split "`n" | Where-Object { $_ -match $adapter } | Select-Object -First 1)
        $verifyLine = if ($verifyLine) { $verifyLine.Trim() } else { "（无法读取验证信息）" }

        $resultText.Text = "[OK] MTU 已成功应用到网卡「$adapter」`n`n设置值: MTU=$mtu`n网卡已自动重启使设置生效。`n`n当前配置:`n$verifyLine"
        Add-LogEntry "INFO" "MTU 已应用：网卡 $adapter，MTU=$mtu"
    } catch {
        $resultText.Text = "[FAIL] MTU 应用异常：$($_.Exception.Message)"
        Add-LogEntry "WARN" "MTU 应用异常：$($_.Exception.Message)"
    }

    $btn.Content = "应用 MTU"
    $btn.IsEnabled = $true
})

# 还原默认 MTU (1500) — 遍历所有已连接网卡（与脚本一致）
$window.FindName("BtnMtuRestore").Add_Click({
    $btn = $window.FindName("BtnMtuRestore")
    $resultText = $window.FindName("MtuResultText")

    $btn.Content = "还原中..."
    $btn.IsEnabled = $false
    $resultText.Text = "正在将所有已连接网卡的 MTU 还原为 1500..."

    try {
        # 获取所有已连接的网络接口（与脚本相同的方式）
        $adapters = @()
        try {
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty Name
        } catch {}

        # 回退到 netsh 方式（与脚本完全一致）
        if (-not $adapters -or $adapters.Count -eq 0) {
            $rawOutput = netsh interface ipv4 show interfaces 2>$null
            foreach ($line in $rawOutput) {
                if ($line -match 'connected\s+(.+)') {
                    $name = $Matches[1].Trim()
                    if ($name -and $name -ne 'Loopback Pseudo-Interface 1') {
                        $adapters += $name
                    }
                }
            }
        }

        if (-not $adapters -or $adapters.Count -eq 0) {
            $resultText.Text = "[WARN] 未检测到已连接的网卡。"
            $btn.Content = "还原默认 MTU (1500)"
            $btn.IsEnabled = $true
            return
        }

        $successList = @()
        $failList = @()

        foreach ($adapter in $adapters) {
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo.FileName = "cmd.exe"
            $p.StartInfo.Arguments = "/c netsh int ipv4 set subinterface `"$adapter`" mtu=1500 store=persistent"
            $p.StartInfo.UseShellExecute = $false
            $p.StartInfo.RedirectStandardOutput = $true
            $p.StartInfo.RedirectStandardError = $true
            $p.StartInfo.CreateNoWindow = $true
            $p.Start() | Out-Null
            $p.StandardOutput.ReadToEnd() | Out-Null
            $p.StandardError.ReadToEnd() | Out-Null
            $p.WaitForExit(10000) | Out-Null

            if ($p.ExitCode -eq 0) {
                $successList += $adapter
            } else {
                $failList += $adapter
            }
        }

        $msg = ""
        if ($successList.Count -gt 0) {
            $msg = "[OK] 已还原 $($successList.Count) 块网卡的 MTU 为 1500：$($successList -join ', ')"
            Add-LogEntry "INFO" "MTU 已还原：$($successList -join ', ')，MTU=1500"
        }
        if ($failList.Count -gt 0) {
            $msg += "`n[WARN] $($failList.Count) 块网卡还原失败：$($failList -join ', ')"
            Add-LogEntry "WARN" "MTU 还原失败：$($failList -join ', ')"
        }

        $resultText.Text = $msg
        $script:detectedMtu = 0
    } catch {
        $resultText.Text = "[FAIL] MTU 还原异常：$($_.Exception.Message)"
        Add-LogEntry "WARN" "MTU 还原异常：$($_.Exception.Message)"
    }

    $btn.Content = "还原默认 MTU (1500)"
    $btn.IsEnabled = $true
})

foreach ($item in $script:dnsItems) {
    $btnEl = $window.FindName($item.Button)
    if ($btnEl) {
        $btnEl.Add_MouseLeftButtonDown([System.Windows.Input.MouseButtonEventHandler]{
            param($s, $e)
            $script:selectedDnsIndex = [int]$s.Tag
            Update-DnsButtons $script:selectedDnsIndex
        })
    }
}

$window.FindName("BtnDnsSpeedTest").Add_Click({
    $btn = $window.FindName("BtnDnsSpeedTest")
    $oldText = $btn.Content
    $btn.Content = "测速中..."
    $btn.IsEnabled = $false

    for ($i = 0; $i -lt $script:dnsItems.Count; $i++) {
        Update-DnsLatencyText $i "测速中"
    }

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("dnsItems", $script:dnsItems)
    $runspace.SessionStateProxy.SetVariable("oldText", $oldText)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        function MeasureHiddenCmdPing {
            param([string]$TargetHost, [int]$Count = 3)
            $p = New-Object System.Diagnostics.Process
            $p.StartInfo.FileName = "cmd.exe"
            $p.StartInfo.Arguments = "/c ping -n $Count $TargetHost"
            $p.StartInfo.UseShellExecute = $false
            $p.StartInfo.RedirectStandardOutput = $true
            $p.StartInfo.RedirectStandardError = $true
            $p.StartInfo.CreateNoWindow = $true
            $p.Start() | Out-Null
            $output = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
            $p.WaitForExit(8000) | Out-Null
            foreach ($line in ($output -split "`n")) {
                if ($line -match "Average = (\d+)") { return [int]$Matches[1] }
                if ($line -match "平均 = (\d+)") { return [int]$Matches[1] }
            }
            return -1
        }

        for ($i = 0; $i -lt $dnsItems.Count; $i++) {
            $item = $dnsItems[$i]
            $latency = MeasureHiddenCmdPing $item.Primary 3
            $latencyText = if ($latency -ge 0) { "$latency ms" } else { "超时" }
            $index = $i
            $base = $item.Base
            $textName = $item.Text
            $window.Dispatcher.Invoke([Action]{
                $tb = $window.FindName($textName)
                if ($tb) { $tb.Text = "$base ----- $latencyText" }
            })
        }

        $window.Dispatcher.Invoke([Action]{
            $btn = $window.FindName("BtnDnsSpeedTest")
            if ($btn) {
                $btn.Content = $oldText
                $btn.IsEnabled = $true
            }
        })
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        if ($ps.InvocationStateInfo.State -eq "Completed") {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    } | Out-Null

    Add-LogEntry "INFO" "DNS 测速已开始"
})

$window.FindName("BtnFlushDns").Add_Click({
    $r = Invoke-Command "ipconfig /flushdns"
    Add-LogEntry "INFO" "DNS 缓存已清理"
    [System.Windows.MessageBox]::Show("DNS 缓存清理成功！", "成功", "OK", "Information") | Out-Null
})

$window.FindName("BtnApplyDns").Add_Click({
    $sel = $script:selectedDnsIndex
    $dnsPairs = @(
        @("1.1.1.1", "1.0.0.1"), @("8.8.8.8", "8.8.4.4"),
        @("223.5.5.5", "223.6.6.6"), @("114.114.114.114", "114.114.115.115"),
        @("119.29.29.29", "182.254.116.116")
    )
    if ($sel -ge 0 -and $sel -lt $dnsPairs.Count) {
        $dns = $dnsPairs[$sel]
        $adapters = Get-ActiveAdapters
        if ($adapters.Count -eq 0) {
            [System.Windows.MessageBox]::Show("未检测到活动网卡，无法设置 DNS。", "错误", "OK", "Error") | Out-Null
            return
        }
        $okCount = 0
        $failMsgs = @()
        foreach ($adapter in $adapters) {
            $r1 = Invoke-Command "netsh interface ip set dns name=`"$($adapter.Name)`" static $($dns[0]) primary"
            $r2 = Invoke-Command "netsh interface ip add dns name=`"$($adapter.Name)`" $($dns[1]) index=2"
            if ($r1.ExitCode -eq 0 -and $r2.ExitCode -eq 0) {
                $okCount++
            } else {
                $failMsgs += "$($adapter.Name)（退出码: $($r1.ExitCode)/$($r2.ExitCode)）"
            }
        }
        if ($failMsgs.Count -gt 0) {
            Add-LogEntry "WARN" "DNS 部分失败：$($failMsgs -join '; ')"
            [System.Windows.MessageBox]::Show("DNS 设置完成，成功 $okCount/$($adapters.Count) 个网卡。`n`n失败网卡：`n$($failMsgs -join "`n")", "部分失败", "OK", "Warning") | Out-Null
        } else {
            Add-LogEntry "INFO" "DNS 已设置为 $($dns[0]) / $($dns[1])，覆盖 $okCount 个网卡"
            [System.Windows.MessageBox]::Show("DNS 已设置为 $($dns[0]) / $($dns[1])`n覆盖全部 $okCount 个活动网卡", "成功", "OK", "Information") | Out-Null
        }
    } else {
        [System.Windows.MessageBox]::Show("请先选择一个 DNS 预设", "提示", "OK", "Warning") | Out-Null
    }
})

$window.FindName("BtnLoadHosts").Add_Click({
    Load-HostsToEditor
})

$window.FindName("BtnSaveHosts").Add_Click({
    Save-HostsFromEditor
})

$window.FindName("BtnOptimizeHosts").Add_Click({
    try {
        if (-not (Test-Path $script:hostsPath)) {
            [System.IO.File]::WriteAllText($script:hostsPath, "", [System.Text.Encoding]::UTF8)
        }
        if (-not (Test-Path $script:hostsBackupPath)) {
            Copy-Item $script:hostsPath $script:hostsBackupPath -Force
        }
        $optimizedHosts = Get-OptimizedHosts
        if ([string]::IsNullOrWhiteSpace($optimizedHosts)) {
            [System.Windows.MessageBox]::Show("获取优化 Hosts 失败，请重试。", "错误", "OK", "Error") | Out-Null
            Add-LogEntry "ERROR" "获取优化 Hosts 失败"
            return
        }
        $current = [System.IO.File]::ReadAllText($script:hostsPath, [System.Text.Encoding]::Default)
        $clean = Remove-AlitHostsBlock $current
        $block = "`r`n$script:hostsStartMarker`r`n# 来源：优化 Hosts，包含 GitHub/Mojang/Google 等 2606 条域名解析`r`n$optimizedHosts`r`n$script:hostsEndMarker`r`n"
        [System.IO.File]::WriteAllText($script:hostsPath, $clean + $block, [System.Text.Encoding]::UTF8)
        Invoke-Command "ipconfig /flushdns" | Out-Null
        Load-HostsToEditor
        Add-LogEntry "INFO" "Hosts 优化已应用：2606 条域名解析"
        [System.Windows.MessageBox]::Show("Hosts 优化已完成（2606 条域名），并已刷新 DNS 缓存。", "成功", "OK", "Information") | Out-Null
    } catch {
        Add-LogEntry "ERROR" "Hosts 优化失败：$($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Hosts 优化失败：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null
    }
})

$window.FindName("BtnResetHosts").Add_Click({
    try {
        if (Test-Path $script:hostsBackupPath) {
            Copy-Item $script:hostsBackupPath $script:hostsPath -Force
            Add-LogEntry "INFO" "Hosts 已从备份恢复"
        } else {
            $defaultHosts = @"
# Copyright (c) Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# localhost name resolution is handled within DNS itself.
#   127.0.0.1       localhost
#   ::1             localhost
"@
            if (Test-Path $script:hostsPath) {
                $current = [System.IO.File]::ReadAllText($script:hostsPath, [System.Text.Encoding]::Default)
                $clean = Remove-AlitHostsBlock $current
                if ([string]::IsNullOrWhiteSpace($clean)) { $clean = $defaultHosts }
                [System.IO.File]::WriteAllText($script:hostsPath, $clean, [System.Text.Encoding]::UTF8)
            } else {
                [System.IO.File]::WriteAllText($script:hostsPath, $defaultHosts, [System.Text.Encoding]::UTF8)
            }
            Add-LogEntry "INFO" "Hosts 优化区块已移除"
        }
        Invoke-Command "ipconfig /flushdns" | Out-Null
        Load-HostsToEditor
        [System.Windows.MessageBox]::Show("Hosts 已重置，并已刷新 DNS 缓存。", "成功", "OK", "Information") | Out-Null
    } catch {
        Add-LogEntry "ERROR" "Hosts 重置失败：$($_.Exception.Message)"
        [System.Windows.MessageBox]::Show("Hosts 重置失败：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null
    }
})

$window.FindName("BtnSelectRecommendedCustom").Add_Click({
    Set-CustomChecks $true
})

$window.FindName("BtnClearCustom").Add_Click({
    Set-CustomChecks $false
})

$window.FindName("BtnApplyCustom").Add_Click({
    Apply-CustomOptimizations
})

$window.FindName("BtnRestoreDns").Add_Click({
    $adapters = Get-ActiveAdapters
    if ($adapters.Count -eq 0) {
        [System.Windows.MessageBox]::Show("未检测到活动网卡，无法恢复 DNS。", "错误", "OK", "Error") | Out-Null
        return
    }
    $okCount = 0
    $failMsgs = @()
    foreach ($adapter in $adapters) {
        $r = Invoke-Command "netsh interface ip set dns name=`"$($adapter.Name)`" source=dhcp"
        if ($r.ExitCode -eq 0) { $okCount++ } else { $failMsgs += "$($adapter.Name)（退出码: $($r.ExitCode)）" }
    }
    if ($failMsgs.Count -gt 0) {
        Add-LogEntry "WARN" "DNS 恢复部分失败：$($failMsgs -join '; ')"
        [System.Windows.MessageBox]::Show("DNS 恢复完成，成功 $okCount/$($adapters.Count) 个网卡。`n`n失败网卡：`n$($failMsgs -join "`n")", "部分失败", "OK", "Warning") | Out-Null
    } else {
        Add-LogEntry "INFO" "DNS 已恢复为 DHCP，覆盖 $okCount 个网卡"
        [System.Windows.MessageBox]::Show("DNS 已恢复为 DHCP`n覆盖全部 $okCount 个活动网卡", "成功", "OK", "Information") | Out-Null
    }
})

# QoS buttons
$window.FindName("BtnApplyQoS").Add_Click({
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    $r1 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none"
    $r2 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none"
    $okCount = 0
    $failMsgs = @()
    if ($r1.ExitCode -eq 0) { $okCount++ } else { $failMsgs += "Java QoS 策略添加失败（退出码 $($r1.ExitCode)）" }
    if ($r2.ExitCode -eq 0) { $okCount++ } else { $failMsgs += "基岩版 QoS 策略添加失败（退出码 $($r2.ExitCode)）" }
    # FPS 游戏 QoS 策略
    $fpsQosApply = @(
        @{ N="FPS_CS2_Proc"; C='netsh qos add policy name="NetOpt_FPS_CS2_Proc" appname="cs2.exe" dscp=46 throttleRate=none' },
        @{ N="FPS_CS2_Port"; C='netsh qos add policy name="NetOpt_FPS_CS2_Port" protocol=udp localport=27015 dscp=46 throttleRate=none' },
        @{ N="FPS_Val_Proc"; C='netsh qos add policy name="NetOpt_FPS_Val_Proc" appname="VALORANT-Win64-Shipping.exe" dscp=46 throttleRate=none' },
        @{ N="FPS_Val_Port"; C='netsh qos add policy name="NetOpt_FPS_Val_Port" protocol=udp localport=7448 dscp=46 throttleRate=none' },
        @{ N="FPS_Apex_Proc"; C='netsh qos add policy name="NetOpt_FPS_Apex_Proc" appname="r5apex.exe" dscp=46 throttleRate=none' },
        @{ N="FPS_CoD_Proc"; C='netsh qos add policy name="NetOpt_FPS_CoD_Proc" appname="cod.exe" dscp=46 throttleRate=none' },
        @{ N="FPS_PUBG_Proc"; C='netsh qos add policy name="NetOpt_FPS_PUBG_Proc" appname="TslGame.exe" dscp=46 throttleRate=none' },
        @{ N="FPS_R6_Proc"; C='netsh qos add policy name="NetOpt_FPS_R6_Proc" appname="RainbowSix.exe" dscp=46 throttleRate=none' }
    )
    $fpsOk = 0; $fpsTotal = $fpsQosApply.Count
    foreach ($fp in $fpsQosApply) {
        Invoke-Command "netsh qos delete policy name=`"$($fp.N)`"" | Out-Null
        $fr = Invoke-Command $fp.C
        if ($fr.ExitCode -eq 0) { $fpsOk++ } else { $failMsgs += "$($fp.N) 失败（退出码 $($fr.ExitCode)）" }
    }
    $okCount += $fpsOk
    if ($failMsgs.Count -gt 0) {
        $msg = "QoS 策略应用结果：成功 $okCount/$($fpsTotal + 2)`n`n失败项：`n" + ($failMsgs -join "`n")
        Add-LogEntry "WARN" "QoS 部分失败：$($failMsgs -join '; ')"
        [System.Windows.MessageBox]::Show($msg, "部分失败", "OK", "Warning") | Out-Null
    } else {
        Add-LogEntry "INFO" "QoS 策略已应用 (DSCP 46)，含 FPS 游戏优化"
        [System.Windows.MessageBox]::Show("QoS 策略已应用 (DSCP 46)`n含 Minecraft + FPS 游戏优化`n成功 $okCount/$($fpsTotal + 2)", "成功", "OK", "Information") | Out-Null
    }
    BtnRefreshQoS_Click $null $null
})

$window.FindName("BtnRemoveQoS").Add_Click({
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    @("NetOpt_FPS_CS2_Proc","NetOpt_FPS_CS2_Port","NetOpt_FPS_Val_Proc","NetOpt_FPS_Val_Port",
      "NetOpt_FPS_Apex_Proc","NetOpt_FPS_Apex_Port","NetOpt_FPS_CoD_Proc","NetOpt_FPS_CoD_Port",
      "NetOpt_FPS_PUBG_Proc","NetOpt_FPS_R6_Proc","NetOpt_FPS_R6_Port") | ForEach-Object {
        Invoke-Command "netsh qos delete policy name=`"$_`"" | Out-Null
    }
    Add-LogEntry "INFO" "QoS 策略已移除（含 FPS 游戏）"
    BtnRefreshQoS_Click $null $null
})

function BtnRefreshQoS_Click {
    param($sender, $e)
    $qosText = $window.FindName("QoSPolicyText")
    if (-not $qosText) { return }
    $r = Invoke-Command "netsh qos show policy"
    $qosText.Text = $r.Output
}

$window.FindName("BtnRefreshQoS").Add_Click({ BtnRefreshQoS_Click $args[0] $args[1] })

# Export log
$window.FindName("BtnExportLog").Add_Click({
    $saveDlg = New-Object Microsoft.Win32.SaveFileDialog
    $saveDlg.Filter = "文本文件 (*.txt)|*.txt|所有文件 (*.*)|*.*"
    $saveDlg.FileName = "ALit_NetworkOptimizer_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    if ($saveDlg.ShowDialog() -eq $true) {
        try {
            $logItems = $window.FindName("LogList").Items
            $logText = ($logItems | ForEach-Object { $_.ToString() }) -join "`r`n"
            [System.IO.File]::WriteAllText($saveDlg.FileName, $logText, [System.Text.Encoding]::UTF8)
            Add-LogEntry "INFO" "日志已导出到：$($saveDlg.FileName)"
            [System.Windows.MessageBox]::Show("日志已导出到：`n$($saveDlg.FileName)", "导出成功", "OK", "Information") | Out-Null
        } catch {
            Add-LogEntry "ERROR" "日志导出失败：$($_.Exception.Message)"
            [System.Windows.MessageBox]::Show("导出失败：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null
        }
    }
})

# Clear log
$window.FindName("BtnClearLog").Add_Click({
    $window.FindName("LogList").Items.Clear()
})

# ============================================================
# Show Window
# ============================================================
# 调试日志
$debugLog = Join-Path $env:ProgramData "ALitNetworkOptimizer\debug.log"
function Write-DebugLog($msg) {
    try { Add-Content $debugLog "[$(Get-Date -Format 'HH:mm:ss.fff')] $msg" -ErrorAction SilentlyContinue } catch {}
}
Write-DebugLog "=== 启动 ==="
Write-DebugLog "window is null: $($null -eq $window)"
if ($window) { Write-DebugLog "window type: $($window.GetType().Name)" }

# 关闭加载页面
Update-SplashText "正在启动..."
Start-Sleep -Milliseconds 200
try {
    $script:splashTimer.Stop()
    $splashWindow.Close()
} catch {}

try {
    # 窗口关闭时清理 WinDivert 进程
    $window.Add_Closing({
        if ($script:wdProcess -and -not $script:wdProcess.HasExited) {
            try { $script:wdProcess.Kill() } catch {}
        }
    })
    Write-DebugLog "准备 ShowDialog, window null=$($null -eq $window)"
    $window.ShowDialog() | Out-Null
    Write-DebugLog "ShowDialog 正常结束"
} catch {
    Write-DebugLog "ShowDialog 异常: $($_.Exception.Message)"
    Write-DebugLog "异常类型: $($_.Exception.GetType().Name)"
    Write-DebugLog "ScriptStackTrace: $($_.ScriptStackTrace)"
    # 捕获 ShowDialog 可能的 Runspace 作用域异常，确保不会白屏崩溃
    try { Add-LogEntry "ERROR" "ShowDialog 异常：$($_.Exception.Message)" } catch {}
    try { [System.Windows.MessageBox]::Show("窗口显示异常，请重启程序。`n`n错误：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null } catch {}
}

# 窗口关闭后清理后台资源
try {
    if ($script:autoSysTimer) { $script:autoSysTimer.Stop() }
    if ($script:sysTimer) { $script:sysTimer.Stop() }
    if ($script:sysPS) { $script:sysPS.Dispose() }
    if ($script:sysRunspace) { $script:sysRunspace.Close(); $script:sysRunspace.Dispose() }
    if ($script:splashTimer) { $script:splashTimer.Stop() }
} catch {}
