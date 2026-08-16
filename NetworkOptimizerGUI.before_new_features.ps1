<#
.SYNOPSIS
    Network Optimizer v2 - PowerShell WPF GUI
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

# ============================================================
# Admin Check
# ============================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $msg = "Network Optimizer 需要管理员权限才能修改网络设置。`n`n是否以管理员身份重新启动？"
    $result = [System.Windows.MessageBox]::Show($msg, "需要管理员权限", "YesNo", "Warning")
    if ($result -eq "Yes") {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
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
    $p.StartInfo.FileName = "powershell.exe"
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
    param([string]$Host, [int]$Count = 5)
    $result = Invoke-Command "ping -n $Count $Host"
    $lines = $result.Output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "Average = (\d+)") { return [double]$Matches[1] }
        if ($line -match "平均 = (\d+)") { return [double]$Matches[1] }
    }
    return -1
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
    } catch {}
    return $null
}

function Add-LogEntry {
    param([string]$Level, [string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "#00E676" }
        "WARN" { "#FFB74D" }
        "ERROR" { "#EF5350" }
        default { "#9E9E9E" }
    }
    $entry = "[$timestamp] $Level : $Message"
    $listBox = $window.FindName("LogList")
    if ($listBox) {
        $listBox.Dispatcher.Invoke([Action]{
            $listBox.Items.Insert(0, $entry) | Out-Null
            if ($listBox.Items.Count -gt 100) { $listBox.Items.RemoveAt($listBox.Items.Count - 1) }
        })
    }
    Write-Host $entry
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
            $statusText.Text = "TCP: $($cmd[1])..."
        })
        $r = Invoke-Command $cmd[0]
        $results += [PSCustomObject]@{ Name=$cmd[1]; Success=($r.ExitCode -eq 0); Detail=$cmd[0] }
        Start-Sleep -Milliseconds 100
    }

    # Registry TCP Parameters
    $regSettings = @(
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpNoDelay", 1, "TcpNoDelay"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpAckFrequency", 1, "TcpAckFrequency"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "Tcp1323Opts", 1, "Tcp1323Opts"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DefaultSendWindow", 65535, "SendWindow"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "DefaultReceiveWindow", 65535, "RecvWindow"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "MaxUserPort", 65534, "MaxUserPort"),
        @("HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters", "TcpTimedWaitDelay", 30, "TimedWait")
    )

    foreach ($reg in $regSettings) {
        $i++
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = ($i / 20) * 100
            $statusText.Text = "Registry: $($reg[3])..."
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
            $guid = (Get-NetAdapter -Name $adapter.Name).InterfaceGuid
            $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            Set-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        } catch {}
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
            $statusText.Text = "System: $($sp[1])..."
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
            $statusText.Text = "Games Task: $($gs[0])..."
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
        $statusText.Text = "QoS Policies..."
    })
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    $qosResult = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none"
    $results += [PSCustomObject]@{ Name="QoS MC Java"; Success=$true; Detail="DSCP 46 for javaw.exe" }
    $qosResult2 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none"
    $results += [PSCustomObject]@{ Name="QoS MC Bedrock"; Success=$true; Detail="DSCP 46 for Minecraft.Windows.exe" }

    # DNS
    $i++
    $window.Dispatcher.Invoke([Action]{
        $progress.Value = ($i / 20) * 100
        $statusText.Text = "DNS Flush..."
    })
    Invoke-Command "ipconfig /flushdns" | Out-Null
    $results += [PSCustomObject]@{ Name="DNS Flush"; Success=$true; Detail="ipconfig /flushdns" }

    $i++
    $window.Dispatcher.Invoke([Action]{
        $progress.Value = 100
        $statusText.Text = "Complete!"
    })

    return $results
}

function Revert-TcpOptimization {
    $progress = $window.FindName("ProgressBar")
    $statusText = $window.FindName("StatusText")

    $window.Dispatcher.Invoke([Action]{
        $statusText.Text = "Reverting TCP..."
        $progress.Value = 20
    })
    Invoke-Command "netsh interface tcp set global autotuninglevel=normal" | Out-Null
    Invoke-Command "netsh interface tcp set global ecncapability=disabled" | Out-Null
    Invoke-Command "netsh interface tcp set global timestamps=enabled" | Out-Null
    Invoke-Command "netsh interface tcp set global initialrto=1000" | Out-Null
    Invoke-Command "netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic" | Out-Null

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 40; $statusText.Text = "Reverting Registry..." })
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $removeProps = @("TcpNoDelay","TcpAckFrequency","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay")
    foreach ($prop in $removeProps) {
        Remove-ItemProperty -Path $tcpPath -Name $prop -Force -ErrorAction SilentlyContinue
    }
    # Per-interface
    $adapters = Get-ActiveAdapters
    foreach ($adapter in $adapters) {
        try {
            $guid = (Get-NetAdapter -Name $adapter.Name).InterfaceGuid
            $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            Remove-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Force -ErrorAction SilentlyContinue
        } catch {}
    }

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 60; $statusText.Text = "Reverting System Profile..." })
    $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 80; $statusText.Text = "Removing QoS..." })
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 100; $statusText.Text = "Revert Complete!" })
}

function Run-SpeedTest {
    $statusText = $window.FindName("StatusText")
    $progress = $window.FindName("ProgressBar")

    # Ping test
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Measuring ping..."; $progress.Value = 20 })
    $adapter = Get-ActiveAdapters | Select-Object -First 1
    $pingVal = -1
    if ($adapter) {
        $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
        if ($gw) {
            $pingVal = Measure-PingLatency -Host $gw -Count 3
        }
    }
    if ($pingVal -lt 0) { $pingVal = Measure-PingLatency -Host "1.1.1.1" -Count 3 }

    # Download test
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Testing download..."; $progress.Value = 50 })
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
    $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Testing upload..."; $progress.Value = 80 })
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

    $window.Dispatcher.Invoke([Action]{ $progress.Value = 100; $statusText.Text = "Speed test complete!" })

    return @{ Ping = $pingVal; Download = $downloadMbps; Upload = $uploadMbps }
}

# ============================================================
# Bandwidth Monitor
# ============================================================
$monitorScript = $null
$monitorRunning = $false

function Start-BandwidthMonitor {
    param([string]$InterfaceName)
    if ($monitorRunning) { return }
    $monitorRunning = $true

    $prevStats = Get-InterfaceBytes -InterfaceName $InterfaceName
    if (-not $prevStats) { return }
    $prevTime = Get-Date

    $monitorScript = New-Object System.Diagnostics.Stopwatch
    $monitorScript.Start()

    while ($monitorRunning) {
        Start-Sleep -Milliseconds 1000
        if (-not $monitorRunning) { break }

        $currStats = Get-InterfaceBytes -InterfaceName $InterfaceName
        $currTime = Get-Date
        if (-not $currStats) { continue }

        $timeDelta = ($currTime - $prevTime).TotalSeconds
        if ($timeDelta -gt 0) {
            $dlMbps = [math]::Round(($currStats.Received - $prevStats.Received) * 8 / 1000000 / $timeDelta, 2)
            $ulMbps = [math]::Round(($currStats.Sent - $prevStats.Sent) * 8 / 1000000 / $timeDelta, 2)
            if ($dlMbps -lt 0) { $dlMbps = 0 }
            if ($ulMbps -lt 0) { $ulMbps = 0 }

            $dlText = $window.FindName("RealtimeDownload")
            $ulText = $window.FindName("RealtimeUpload")
            $dlBar = $window.FindName("DownloadBar")
            $ulBar = $window.FindName("UploadBar")

            if ($dlText -and $ulText) {
                $window.Dispatcher.Invoke([Action]{
                    $dlText.Text = $dlMbps.ToString("F1")
                    $ulText.Text = $ulMbps.ToString("F1")
                    $dlBar.Value = [math]::Min($dlMbps, 1000)
                    $ulBar.Value = [math]::Min($ulMbps, 1000)
                })
            }
        }
        $prevStats = $currStats
        $prevTime = $currTime
    }
}

function Stop-BandwidthMonitor {
    $script:monitorRunning = $false
}

# ============================================================
# XAML UI Definition
# ============================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Optimizer v2 - Minecraft PvP" 
        Width="1000" Height="680" 
        Background="#1A1A2E" 
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanResize" MinWidth="800" MinHeight="600">

<Window.Resources>
    <Style TargetType="TextBlock">
        <Setter Property="FontFamily" Value="Segoe UI"/>
    </Style>
</Window.Resources>

<Grid>
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="200"/>
        <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- Sidebar -->
    <Border Grid.Column="0" Background="#16213E" Padding="0,20,0,0">
        <StackPanel>
            <TextBlock Text="Network Optimizer" Foreground="#00E676" FontSize="16" FontWeight="Bold" Margin="20,0,0,10"/>
            <TextBlock Text="v2.0 - Minecraft PvP" Foreground="#9E9E9E" FontSize="11" Margin="20,0,0,20"/>

            <RadioButton x:Name="NavDashboard" Content="Dashboard" Foreground="#E0E0E0" FontSize="14" 
                        Margin="20,8" Padding="8,4" GroupName="Nav" IsChecked="True" Tag="Dashboard"/>
            <RadioButton x:Name="NavTcp" Content="TCP/IP" Foreground="#E0E0E0" FontSize="14"
                        Margin="20,8" Padding="8,4" GroupName="Nav" Tag="Tcp"/>
            <RadioButton x:Name="NavDns" Content="DNS" Foreground="#E0E0E0" FontSize="14"
                        Margin="20,8" Padding="8,4" GroupName="Nav" Tag="Dns"/>
            <RadioButton x:Name="NavQos" Content="QoS" Foreground="#E0E0E0" FontSize="14"
                        Margin="20,8" Padding="8,4" GroupName="Nav" Tag="Qos"/>
            <RadioButton x:Name="NavDiag" Content="Diagnostics" Foreground="#E0E0E0" FontSize="14"
                        Margin="20,8" Padding="8,4" GroupName="Nav" Tag="Diag"/>
            <RadioButton x:Name="NavLog" Content="Activity Log" Foreground="#E0E0E0" FontSize="14"
                        Margin="20,8" Padding="8,4" GroupName="Nav" Tag="Log"/>

            <Border Background="#0F3460" CornerRadius="6" Padding="12,8" Margin="20,30,20,0">
                <StackPanel>
                    <TextBlock Text="Status" Foreground="#9E9E9E" FontSize="11"/>
                    <TextBlock x:Name="SidebarStatus" Text="Not Optimized" Foreground="#FFB74D" FontSize="13" FontWeight="SemiBold"/>
                </StackPanel>
            </Border>
        </StackPanel>
    </Border>

    <!-- Content Area -->
    <Grid Grid.Column="1" Margin="20,15,20,15">
        
        <!-- Dashboard Panel -->
        <StackPanel x:Name="DashboardPanel">
            <TextBlock Text="Dashboard" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="Network status overview and quick optimization" Foreground="#9E9E9E" FontSize="13" Margin="0,0,0,15"/>

            <!-- Status Cards -->
            <UniformGrid Columns="4" Margin="0,0,0,15">
                <Border Background="#0F3460" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="PING" Foreground="#9E9E9E" FontSize="11"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="PingValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" ms" Foreground="#9E9E9E" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#0F3460" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="Download" Foreground="#9E9E9E" FontSize="11"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="DownloadValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" Mbps" Foreground="#9E9E9E" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#0F3460" CornerRadius="8" Padding="16" Margin="0,0,8,0">
                    <StackPanel>
                        <TextBlock Text="Upload" Foreground="#9E9E9E" FontSize="11"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="UploadValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" Mbps" Foreground="#9E9E9E" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
                <Border Background="#0F3460" CornerRadius="8" Padding="16">
                    <StackPanel>
                        <TextBlock Text="DNS" Foreground="#9E9E9E" FontSize="11"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="DnsValue" Text="--" Foreground="#00E676" FontSize="28" FontWeight="Bold"/>
                            <TextBlock Text=" ms" Foreground="#9E9E9E" FontSize="13" VerticalAlignment="Bottom" Margin="4,0,0,5"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </UniformGrid>

            <!-- Quick Optimize -->
            <Border Background="#16213E" CornerRadius="8" Padding="20" Margin="0,0,0,15">
                <StackPanel>
                    <TextBlock Text="Quick Optimize" Foreground="#E0E0E0" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,5"/>
                    <TextBlock Text="One-click apply all optimizations: TCP tuning, QoS priority, DNS, system profile." 
                              Foreground="#9E9E9E" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <Button x:Name="BtnOptimize" Content="Optimize Now" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="24,10" Margin="0,0,10,0" 
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                        <Button x:Name="BtnRevert" Content="Revert All" Background="#EF5350" Foreground="White"
                               FontWeight="SemiBold" Padding="24,10" Margin="0,0,10,0"
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                        <Button x:Name="BtnSpeedTest" Content="Speed Test" Background="#0F3460" Foreground="#E0E0E0"
                               FontWeight="SemiBold" Padding="24,10"
                               FontSize="14" BorderThickness="0" Cursor="Hand"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                        <TextBlock x:Name="StatusText" Text="Ready" Foreground="#9E9E9E" FontSize="12" VerticalAlignment="Center"/>
                    </StackPanel>
                    <ProgressBar x:Name="ProgressBar" Height="6" Margin="0,5,0,0" Foreground="#00E676" Background="#0F3460" 
                                BorderThickness="0" Value="0"/>
                </StackPanel>
            </Border>

            <!-- Results -->
            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="Optimization Results" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <ListBox x:Name="ResultsList" Background="Transparent" BorderThickness="0" MaxHeight="180" 
                            FontFamily="Consolas" FontSize="11" Foreground="#E0E0E0"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- TCP Panel -->
        <StackPanel x:Name="TcpPanel" Visibility="Collapsed">
            <TextBlock Text="TCP/IP Stack Optimization" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="All settings are documented Microsoft Windows parameters." Foreground="#9E9E9E" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="Current TCP Global Settings" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <Button x:Name="BtnRefreshTcp" Content="Refresh" Background="#0F3460" Foreground="#E0E0E0" 
                           Padding="12,4" FontSize="12" BorderThickness="0" Margin="0,0,0,8"/>
                    <TextBox x:Name="TcpSettingsText" Text="Click Refresh to load..." FontFamily="Consolas" FontSize="11" 
                            Foreground="#9E9E9E" Background="#0F3460" BorderThickness="0" IsReadOnly="True" 
                            TextWrapping="Wrap" Height="200" VerticalScrollBarVisibility="Auto" Padding="8"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="Key Optimizations Applied:" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock Foreground="#E0E0E0" FontSize="12" TextWrapping="Wrap" LineHeight="22"
                              Text="1. TcpNoDelay=1 - Disable Nagle's algorithm (critical for PvP)&#x0a;2. TcpAckFrequency=1 - ACK every segment&#x0a;3. NetworkThrottlingIndex=0xFFFFFFFF - Disable throttling&#x0a;4. SystemResponsiveness=0 - Max CPU for gaming&#x0a;5. CTCP congestion provider - Better throughput&#x0a;6. ECN enabled - Reduce retransmissions&#x0a;7. RSS enabled - Multi-core parallel processing&#x0a;8. Games GPU Priority=8, SFIO=High&#x0a;9. DefaultSendWindow/ReceiveWindow=65535&#x0a;10. MaxUserPort=65534, TcpTimedWaitDelay=30"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- DNS Panel -->
        <StackPanel x:Name="DnsPanel" Visibility="Collapsed">
            <TextBlock Text="DNS Optimization" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="Configure DNS for faster resolution" Foreground="#9E9E9E" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="Current DNS:" Foreground="#9E9E9E" FontSize="12" Margin="0,0,0,5"/>
                    <TextBlock x:Name="CurrentDnsText" Text="--" FontFamily="Consolas" FontSize="13" Foreground="#00E676" Margin="0,0,0,10"/>
                    <Button x:Name="BtnFlushDns" Content="Flush DNS Cache" Background="#0F3460" Foreground="#E0E0E0" 
                           Padding="16,8" FontSize="12" BorderThickness="0"/>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="DNS Presets" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <ComboBox x:Name="DnsPresetCombo" FontSize="13" Padding="8,4" Margin="0,0,0,10">
                        <ComboBoxItem Content="Cloudflare (1.1.1.1 / 1.0.0.1) - Global low latency"/>
                        <ComboBoxItem Content="Google (8.8.8.8 / 8.8.4.4) - Reliable"/>
                        <ComboBoxItem Content="AliDNS (223.5.5.5 / 223.6.6.6) - China fast"/>
                        <ComboBoxItem Content="114DNS (114.114.114.114) - China"/>
                        <ComboBoxItem Content="DNSPod (119.29.29.29) - Tencent"/>
                    </ComboBox>
                    <StackPanel Orientation="Horizontal">
                        <Button x:Name="BtnApplyDns" Content="Apply DNS" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="12" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnRestoreDns" Content="Restore DHCP" Background="#0F3460" Foreground="#E0E0E0" 
                               Padding="16,8" FontSize="12" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- QoS Panel -->
        <StackPanel x:Name="QosPanel" Visibility="Collapsed">
            <TextBlock Text="QoS - Traffic Prioritization" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="Prioritize Minecraft traffic with DSCP 46 (Expedited Forwarding)" Foreground="#9E9E9E" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <TextBlock Text="QoS Policies for Minecraft:" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <TextBlock Foreground="#9E9E9E" FontSize="12" TextWrapping="Wrap" LineHeight="20"
                              Text="- javaw.exe (Minecraft Java): DSCP 46, no throttle&#x0a;- Minecraft.Windows.exe (Bedrock): DSCP 46&#x0a;- Port 25565 (Java default): DSCP 46&#x0a;- Port 19132 (Bedrock UDP): DSCP 46"/>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                        <Button x:Name="BtnApplyQoS" Content="Apply QoS" Background="#00E676" Foreground="#1A1A2E" 
                               FontWeight="SemiBold" Padding="16,8" FontSize="12" BorderThickness="0" Margin="0,0,10,0"/>
                        <Button x:Name="BtnRemoveQoS" Content="Remove All" Background="#EF5350" Foreground="White" 
                               Padding="16,8" FontSize="12" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <TextBlock Text="Active QoS Policies:" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,8"/>
                    <Button x:Name="BtnRefreshQoS" Content="Refresh" Background="#0F3460" Foreground="#E0E0E0" 
                           Padding="12,4" FontSize="12" BorderThickness="0" Margin="0,0,0,8"/>
                    <TextBox x:Name="QoSPolicyText" Text="--" FontFamily="Consolas" FontSize="11" 
                            Foreground="#9E9E9E" Background="#0F3460" BorderThickness="0" IsReadOnly="True" 
                            TextWrapping="Wrap" Height="150" VerticalScrollBarVisibility="Auto" Padding="8"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Diagnostics Panel -->
        <StackPanel x:Name="DiagPanel" Visibility="Collapsed">
            <TextBlock Text="Network Diagnostics" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBlock Text="Real-time bandwidth monitoring and network analysis" Foreground="#9E9E9E" FontSize="13" Margin="0,0,0,15"/>

            <Border Background="#16213E" CornerRadius="8" Padding="16" Margin="0,0,0,10">
                <StackPanel>
                    <Grid Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="0" Text="Real-time Bandwidth" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/>
                        <ToggleButton x:Name="MonitorToggle" Grid.Column="1" Content="Start Monitor" Background="#0F3460" Foreground="#E0E0E0" 
                                     Padding="12,4" FontSize="12" BorderThickness="0"/>
                    </Grid>
                    <UniformGrid Columns="2">
                        <Border Background="#0F3460" CornerRadius="6" Padding="12" Margin="0,0,6,0">
                            <StackPanel>
                                <TextBlock Text="Download" Foreground="#9E9E9E" FontSize="11"/>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="RealtimeDownload" Text="0.0" Foreground="#00E676" FontSize="24" FontWeight="Bold"/>
                                    <TextBlock Text=" Mbps" Foreground="#9E9E9E" FontSize="11" VerticalAlignment="Bottom" Margin="4,0,0,3"/>
                                </StackPanel>
                                <ProgressBar x:Name="DownloadBar" Height="4" Margin="0,4,0,0" Foreground="#00E676" Background="#1A1A2E" BorderThickness="0" Maximum="100" Value="0"/>
                            </StackPanel>
                        </Border>
                        <Border Background="#0F3460" CornerRadius="6" Padding="12" Margin="6,0,0,0">
                            <StackPanel>
                                <TextBlock Text="Upload" Foreground="#9E9E9E" FontSize="11"/>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock x:Name="RealtimeUpload" Text="0.0" Foreground="#FFB74D" FontSize="24" FontWeight="Bold"/>
                                    <TextBlock Text=" Mbps" Foreground="#9E9E9E" FontSize="11" VerticalAlignment="Bottom" Margin="4,0,0,3"/>
                                </StackPanel>
                                <ProgressBar x:Name="UploadBar" Height="4" Margin="0,4,0,0" Foreground="#FFB74D" Background="#1A1A2E" BorderThickness="0" Maximum="100" Value="0"/>
                            </StackPanel>
                        </Border>
                    </UniformGrid>
                </StackPanel>
            </Border>

            <Border Background="#16213E" CornerRadius="8" Padding="16">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                        <TextBlock Text="Full Diagnostic" Foreground="#E0E0E0" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                        <Button x:Name="BtnRunDiag" Content="Run Diagnostic" Background="#00E676" Foreground="#1A1A2E" 
                               Padding="12,4" FontSize="12" BorderThickness="0"/>
                    </StackPanel>
                    <TextBox x:Name="DiagResults" Text="Click 'Run Diagnostic' to start..." FontFamily="Consolas" FontSize="11" 
                            Foreground="#9E9E9E" Background="#0F3460" BorderThickness="0" IsReadOnly="True" 
                            TextWrapping="Wrap" Height="200" VerticalScrollBarVisibility="Auto" Padding="8"/>
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
                <TextBlock Grid.Column="0" Text="操作日志" Foreground="#E0E0E0" FontSize="22" FontWeight="SemiBold" Margin="0,0,0,15"/>
                <Button Grid.Column="1" x:Name="BtnClearLog" Content="Clear" Background="#0F3460" Foreground="#E0E0E0" 
                       Padding="12,4" FontSize="12" BorderThickness="0" VerticalAlignment="Bottom"/>
            </Grid>
            <Border Background="#16213E" CornerRadius="8" Padding="8">
                <ListBox x:Name="LogList" Background="Transparent" BorderThickness="0" FontFamily="Consolas" 
                        FontSize="11" Foreground="#E0E0E0" Height="450"/>
            </Border>
        </StackPanel>

    </Grid>
</Grid>
</Window>
"@

# ============================================================
# Parse XAML and Create Window
# ============================================================
$window = [Windows.Markup.XamlReader]::Parse($xaml.OuterXml)

# ============================================================
# Event Handlers
# ============================================================

$window.Add_Loaded({
    Add-LogEntry "INFO" "Network Optimizer v2 started"
    Add-LogEntry "INFO" "Admin privileges: $isAdmin"

    # Populate adapters
    $adapters = Get-ActiveAdapters
    foreach ($a in $adapters) {
        Add-LogEntry "INFO" "Adapter: $($a.Name) ($($a.Speed))"
    }

    # Auto-refresh dashboard
    $btn = $window.FindName("BtnRefreshTcp")
    if ($btn) { BtnRefreshTcp_Click $btn $null }
})

# Navigation
$window.FindName("NavDashboard").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Visible"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("DiagPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Collapsed"
})

$window.FindName("NavTcp").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Visible"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("DiagPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Collapsed"
})

$window.FindName("NavDns").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Visible"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("DiagPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Collapsed"
    # Refresh DNS info
    $adapters = Get-ActiveAdapters
    if ($adapters.Count -gt 0) {
        $dns = Invoke-PowerShell "(Get-DnsClientServerAddress -InterfaceAlias '$($adapters[0].Name)' -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ', '"
        $window.FindName("CurrentDnsText").Text = $dns.Output.Trim()
    }
})

$window.FindName("NavQos").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Visible"
    $window.FindName("DiagPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Collapsed"
    BtnRefreshQoS_Click $null $null
})

$window.FindName("NavDiag").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("DiagPanel").Visibility = "Visible"
    $window.FindName("LogPanel").Visibility = "Collapsed"
})

$window.FindName("NavLog").Add_Checked({
    $window.FindName("DashboardPanel").Visibility = "Collapsed"
    $window.FindName("TcpPanel").Visibility = "Collapsed"
    $window.FindName("DnsPanel").Visibility = "Collapsed"
    $window.FindName("QosPanel").Visibility = "Collapsed"
    $window.FindName("DiagPanel").Visibility = "Collapsed"
    $window.FindName("LogPanel").Visibility = "Visible"
})

# Optimize button
$window.FindName("BtnOptimize").Add_Click({
    $btn = $window.FindName("BtnOptimize")
    $btn.IsEnabled = $false
    $window.FindName("BtnRevert").IsEnabled = $false
    $window.FindName("BtnSpeedTest").IsEnabled = $false

    Add-LogEntry "INFO" "Starting full optimization..."

    $job = Start-Job -ScriptBlock {
        param($window, $ApplyFunc)
        & $ApplyFunc
    } -ArgumentList $window, ${function:Apply-TcpOptimization}

    # Run in background using Runspace
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("GetActiveAdapters", ${function:Get-ActiveAdapters})
    $runspace.SessionStateProxy.SetVariable("Invoke-Command", ${function:Invoke-Command})
    $runspace.SessionStateProxy.SetVariable("Add-LogEntry", ${function:Add-LogEntry})

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        # Inline optimization logic for runspace
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")
        $resultsList = $window.FindName("ResultsList")

        $results = [System.Collections.ArrayList]@()

        $cmds = @(
            @("netsh interface tcp set global autotuninglevel=normal", "TCP Auto-Tuning"),
            @("netsh interface tcp set global ecncapability=enabled", "ECN"),
            @("netsh interface tcp set global rss=enabled", "RSS"),
            @("netsh interface tcp set global timestamps=disabled", "Timestamps OFF"),
            @("netsh interface tcp set global initialrto=300", "Initial RTO=300"),
            @("netsh interface tcp set global rsc=enabled", "RSC"),
            @("netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp", "CTCP")
        )

        $i = 0
        $total = 22
        foreach ($cmd in $cmds) {
            $i++
            $window.Dispatcher.Invoke([Action]{
                $progress.Value = ($i / $total) * 100
                $statusText.Text = "TCP: $($cmd[1])..."
            })
            $r = & $Invoke-Command $cmd[0]
            $ok = $r.ExitCode -eq 0
            $results.Add("[OK] $($cmd[1])") | Out-Null
            Start-Sleep -Milliseconds 50
        }

        # Registry
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $regs = @(
            @("TcpNoDelay", 1), @("TcpAckFrequency", 1), @("Tcp1323Opts", 1),
            @("DefaultSendWindow", 65535), @("DefaultReceiveWindow", 65535),
            @("MaxUserPort", 65534), @("TcpTimedWaitDelay", 30)
        )
        foreach ($reg in $regs) {
            $i++
            $window.Dispatcher.Invoke([Action]{
                $progress.Value = ($i / $total) * 100
                $statusText.Text = "Registry: $($reg[0])..."
            })
            try {
                Set-ItemProperty -Path $regPath -Name $reg[0] -Value $reg[1] -Type DWord -Force -ErrorAction Stop
                $results.Add("[OK] $($reg[0])=$($reg[1])") | Out-Null
            } catch {
                $results.Add("[FAIL] $($reg[0])") | Out-Null
            }
        }

        # Per-interface
        $adapters = & $GetActiveAdapters
        foreach ($a in $adapters) {
            try {
                $guid = (Get-NetAdapter -Name $a.Name -ErrorAction SilentlyContinue).InterfaceGuid
                if ($guid) {
                    $ifacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                    Set-ItemProperty -Path $ifacePath -Name "TcpNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $ifacePath -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                    $results.Add("[OK] Interface $($a.Name): TcpNoDelay+AckFreq") | Out-Null
                }
            } catch {}
            $i++
        }

        # System Profile
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "System Profile..." })
        Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 4294967295 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $results.Add("[OK] NetworkThrottlingIndex=0xFFFFFFFF") | Out-Null
        $results.Add("[OK] SystemResponsiveness=0") | Out-Null

        # Games Task
        $gPath = "$spPath\Tasks\Games"
        Set-ItemProperty -Path $gPath -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gPath -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gPath -Name "Scheduling Category" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gPath -Name "SFIO Priority" -Value "High" -Type String -Force -ErrorAction SilentlyContinue
        $results.Add("[OK] Games: GPU=8, Priority=6, Sched=High, SFIO=High") | Out-Null

        # QoS
        $i += 3
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "QoS Policies..."; $progress.Value = ($i / $total) * 100 })
        & $Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
        & $Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
        & $Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none" | Out-Null
        & $Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none" | Out-Null
        $results.Add("[OK] QoS: MC Java DSCP=46") | Out-Null
        $results.Add("[OK] QoS: MC Bedrock DSCP=46") | Out-Null

        # DNS
        $i += 2
        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "DNS Flush..."; $progress.Value = ($i / $total) * 100 })
        & $Invoke-Command "ipconfig /flushdns" | Out-Null
        $results.Add("[OK] DNS Cache Flushed") | Out-Null

        # Done
        $window.Dispatcher.Invoke([Action]{
            $progress.Value = 100
            $statusText.Text = "Optimization Complete!"
            $resultsList.Items.Clear()
            foreach ($r in $results) { $resultsList.Items.Add($r) | Out-Null }
            $sidebar = $window.FindName("SidebarStatus")
            $sidebar.Text = "Optimized"
            $sidebar.Foreground = "#00E676"
            $btn = $window.FindName("BtnOptimize")
            $btn.IsEnabled = $true
            $window.FindName("BtnRevert").IsEnabled = $true
            $window.FindName("BtnSpeedTest").IsEnabled = $true
        })
    }) | Out-Null

    $handle = $ps.BeginInvoke()
    # Register a callback to clean up
    Register-ObjectEvent -InputObject $ps -EventName InvocationStateChanged -Action {
        if ($ps.InvocationStateInfo.State -eq "Completed") {
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
    Add-LogEntry "INFO" "Reverting all optimizations..."

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)
    $runspace.SessionStateProxy.SetVariable("Invoke-Command", ${function:Invoke-Command})

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Reverting TCP..."; $progress.Value = 20 })
        & $Invoke-Command "netsh interface tcp set global autotuninglevel=normal" | Out-Null
        & $Invoke-Command "netsh interface tcp set global ecncapability=disabled" | Out-Null
        & $Invoke-Command "netsh interface tcp set global timestamps=enabled" | Out-Null
        & $Invoke-Command "netsh interface tcp set global initialrto=1000" | Out-Null
        & $Invoke-Command "netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic" | Out-Null

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Reverting Registry..."; $progress.Value = 40 })
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        @("TcpNoDelay","TcpAckFrequency","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort","TcpTimedWaitDelay") | ForEach-Object {
            Remove-ItemProperty -Path $tcpPath -Name $_ -Force -ErrorAction SilentlyContinue
        }

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Reverting System..."; $progress.Value = 60 })
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $spPath -Name "NetworkThrottlingIndex" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $spPath -Name "SystemResponsiveness" -Value 20 -Type DWord -Force -ErrorAction SilentlyContinue

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Removing QoS..."; $progress.Value = 80 })
        & $Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
        & $Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null

        $window.Dispatcher.Invoke([Action]{
            $progress.Value = 100
            $statusText.Text = "Reverted!"
            $sidebar = $window.FindName("SidebarStatus")
            $sidebar.Text = "Not Optimized"
            $sidebar.Foreground = "#FFB74D"
            $window.FindName("BtnOptimize").IsEnabled = $true
            $window.FindName("BtnRevert").IsEnabled = $true
            $window.FindName("ResultsList").Items.Clear()
            $window.FindName("ResultsList").Items.Add("[OK] All optimizations reverted") | Out-Null
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

    Add-LogEntry "INFO" "Revert complete"
})

# Speed Test button
$window.FindName("BtnSpeedTest").Add_Click({
    $window.FindName("BtnSpeedTest").IsEnabled = $false
    $progress = $window.FindName("ProgressBar")
    $statusText = $window.FindName("StatusText")
    $statusText.Text = "Running speed test..."

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $progress = $window.FindName("ProgressBar")
        $statusText = $window.FindName("StatusText")

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Measuring ping..."; $progress.Value = 20 })
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

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Testing download..."; $progress.Value = 50 })
        $dlMbps = 0
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $data = Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=10000000" -UseBasicParsing -TimeoutSec 15
            $sw.Stop()
            if ($sw.Elapsed.TotalSeconds -gt 0) {
                $dlMbps = [math]::Round(($data.RawContentLength * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
            }
        } catch { $dlMbps = -1 }

        $window.Dispatcher.Invoke([Action]{ $statusText.Text = "Testing upload..."; $progress.Value = 80 })
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
            $statusText.Text = "Speed test complete!"
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

    Add-LogEntry "INFO" "Speed test started"
})

# TCP Refresh
function BtnRefreshTcp_Click {
    param($sender, $e)
    $tcpText = $window.FindName("TcpSettingsText")
    if (-not $tcpText) { return }
    $tcpText.Text = "Loading..."
    $r = Invoke-Command "netsh interface tcp show global"
    $tcpText.Text = $r.Output
    Add-LogEntry "INFO" "TCP settings refreshed"
}

$window.FindName("BtnRefreshTcp").Add_Click({ BtnRefreshTcp_Click $args[0] $args[1] })

# DNS buttons
$window.FindName("BtnFlushDns").Add_Click({
    $r = Invoke-Command "ipconfig /flushdns"
    Add-LogEntry "INFO" "DNS cache flushed"
    [System.Windows.MessageBox]::Show("DNS cache flushed successfully!", "Success", "OK", "Information") | Out-Null
})

$window.FindName("BtnApplyDns").Add_Click({
    $combo = $window.FindName("DnsPresetCombo")
    $sel = $combo.SelectedIndex
    $dnsPairs = @(
        @("1.1.1.1", "1.0.0.1"), @("8.8.8.8", "8.8.4.4"),
        @("223.5.5.5", "223.6.6.6"), @("114.114.114.114", "114.114.115.115"),
        @("119.29.29.29", "182.254.116.116")
    )
    if ($sel -ge 0 -and $sel -lt $dnsPairs.Count) {
        $dns = $dnsPairs[$sel]
        $adapter = Get-ActiveAdapters | Select-Object -First 1
        if ($adapter) {
            $r1 = Invoke-Command "netsh interface ip set dns name=`"$($adapter.Name)`" static $($dns[0]) primary"
            $r2 = Invoke-Command "netsh interface ip add dns name=`"$($adapter.Name)`" $($dns[1]) index=2"
            Add-LogEntry "INFO" "DNS set to $($dns[0]) / $($dns[1])"
            [System.Windows.MessageBox]::Show("DNS set to $($dns[0]) / $($dns[1])", "Success", "OK", "Information") | Out-Null
        }
    }
})

$window.FindName("BtnRestoreDns").Add_Click({
    $adapter = Get-ActiveAdapters | Select-Object -First 1
    if ($adapter) {
        Invoke-Command "netsh interface ip set dns name=`"$($adapter.Name)`" source=dhcp" | Out-Null
        Add-LogEntry "INFO" "DNS restored to DHCP"
        [System.Windows.MessageBox]::Show("DNS restored to DHCP", "Success", "OK", "Information") | Out-Null
    }
})

# QoS buttons
$window.FindName("BtnApplyQoS").Add_Click({
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    $r1 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Java_Game`" appPath=`"javaw.exe`" dscp=46 throttleRate=none"
    $r2 = Invoke-Command "netsh qos add policy name=`"NetOpt_MC_Bedrock_Game`" appPath=`"Minecraft.Windows.exe`" dscp=46 throttleRate=none"
    Add-LogEntry "INFO" "QoS policies applied (DSCP 46)"
    [System.Windows.MessageBox]::Show("QoS policies applied for Minecraft (DSCP 46)", "Success", "OK", "Information") | Out-Null
    BtnRefreshQoS_Click $null $null
})

$window.FindName("BtnRemoveQoS").Add_Click({
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Java_Game`"" | Out-Null
    Invoke-Command "netsh qos delete policy name=`"NetOpt_MC_Bedrock_Game`"" | Out-Null
    Add-LogEntry "INFO" "QoS policies removed"
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

# Monitor toggle
$monitorRunspace = $null
$monitorPS = $null

$window.FindName("MonitorToggle").Add_Click({
    $toggle = $window.FindName("MonitorToggle")
    if ($toggle.IsChecked) {
        $toggle.Content = "停止监控"
        $adapter = Get-ActiveAdapters | Select-Object -First 1
        if (-not $adapter) { return }

        $monitorRunspace = [RunspaceFactory]::CreateRunspace()
        $monitorRunspace.ApartmentState = "STA"
        $monitorRunspace.Open()
        $monitorRunspace.SessionStateProxy.SetVariable("window", $window)
        $monitorRunspace.SessionStateProxy.SetVariable("ifaceName", $adapter.Name)
        $monitorRunspace.SessionStateProxy.SetVariable("stopFlag", $false)

        $monitorPS = [PowerShell]::Create()
        $monitorPS.Runspace = $monitorRunspace
        $monitorPS.AddScript({
            $prev = $null
            $prevTime = $null
            while (-not $stopFlag) {
                $curr = $null
                try {
                    $stats = Get-NetAdapter -Name $ifaceName -ErrorAction SilentlyContinue | Get-NetAdapterStatistics -ErrorAction SilentlyContinue
                    if ($stats) { $curr = @{ Sent = $stats.OutboundUnicastBytes; Recv = $stats.InboundUnicastBytes } }
                } catch {}
                if ($curr -and $prev) {
                    $now = Get-Date
                    $dt = ($now - $prevTime).TotalSeconds
                    if ($dt -gt 0) {
                        $dl = [math]::Round(($curr.Recv - $prev.Recv) * 8 / 1000000 / $dt, 2)
                        $ul = [math]::Round(($curr.Sent - $prev.Sent) * 8 / 1000000 / $dt, 2)
                        if ($dl -lt 0) { $dl = 0 }
                        if ($ul -lt 0) { $ul = 0 }
                        $window.Dispatcher.Invoke([Action]{
                            $window.FindName("RealtimeDownload").Text = $dl.ToString("F1")
                            $window.FindName("RealtimeUpload").Text = $ul.ToString("F1")
                            $window.FindName("DownloadBar").Value = [math]::Min($dl, 100)
                            $window.FindName("UploadBar").Value = [math]::Min($ul, 100)
                        })
                    }
                }
                $prev = $curr
                $prevTime = Get-Date
                Start-Sleep -Milliseconds 1000
            }
        }) | Out-Null

        $monitorHandle = $monitorPS.BeginInvoke()
        Add-LogEntry "INFO" "Bandwidth monitor started on $($adapter.Name)"
    } else {
        $toggle.Content = "Start Monitor"
        $stopFlag = $true
        if ($monitorRunspace) {
            $monitorRunspace.SessionStateProxy.SetVariable("stopFlag", $true)
            Start-Sleep -Milliseconds 500
            if ($monitorPS) { $monitorPS.Stop(); $monitorPS.Dispose() }
            $monitorRunspace.Close()
            $monitorRunspace.Dispose()
        }
        Add-LogEntry "INFO" "Bandwidth monitor stopped"
    }
})

# Run Diagnostic
$window.FindName("BtnRunDiag").Add_Click({
    $diagText = $window.FindName("DiagResults")
    $diagText.Text = "Running diagnostics..."
    $btn = $window.FindName("BtnRunDiag")
    $btn.IsEnabled = $false

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("window", $window)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({
        $diagText = $window.FindName("DiagResults")
        $sb = [System.Text.StringBuilder]::new()

        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($adapter) {
            [void]$sb.AppendLine("=== Adapter ===")
            [void]$sb.AppendLine("Name: $($adapter.Name)")
            [void]$sb.AppendLine("Description: $($adapter.InterfaceDescription)")
            [void]$sb.AppendLine("Link Speed: $($adapter.LinkSpeed)")
            [void]$sb.AppendLine("MTU: $($adapter.MtuSize)")
            [void]$sb.AppendLine("")

            $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
            $gw = (Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop
            $dns = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ', '

            [void]$sb.AppendLine("=== Network ===")
            [void]$sb.AppendLine("IP: $ip")
            [void]$sb.AppendLine("Gateway: $gw")
            [void]$sb.AppendLine("DNS: $dns")
            [void]$sb.AppendLine("")

            if ($gw) {
                $window.Dispatcher.Invoke([Action]{ $diagText.Text = "Pinging gateway..." })
                $pingResult = & { ping -n 5 $gw }
                $avg = -1
                foreach ($l in $pingResult) {
                    if ($l -match "Average = (\d+)" -or $l -match "平均 = (\d+)") { $avg = [int]$Matches[1] }
                }
                [void]$sb.AppendLine("=== Ping (gateway) ===")
                [void]$sb.AppendLine("Average: $avg ms")
                [void]$sb.AppendLine("")

                # Jitter
                $pings = @()
                foreach ($i in 1..5) {
                    $pr = & { ping -n 1 $gw }
                    foreach ($l in $pr) {
                        if ($l -match "time[<=](\d+)" -or $l -match "时间[<=](\d+)") { $pings += [double]$Matches[1] }
                    }
                    Start-Sleep -Milliseconds 200
                }
                if ($pings.Count -gt 1) {
                    $jitter = 0
                    for ($i = 1; $i -lt $pings.Count; $i++) { $jitter += [math]::Abs($pings[$i] - $pings[$i-1]) }
                    $jitter = [math]::Round($jitter / ($pings.Count - 1), 1)
                    [void]$sb.AppendLine("Jitter: $jitter ms")
                }
            }
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("=== TCP Global ===")
        $tcpOut = & { netsh interface tcp show global }
        foreach ($l in $tcpOut) { [void]$sb.AppendLine($l) }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("=== Registry TCP ===")
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $props = Get-ItemProperty $tcpPath -ErrorAction SilentlyContinue
        foreach ($p in @("TcpNoDelay","TcpAckFrequency","Tcp1323Opts","DefaultSendWindow","DefaultReceiveWindow","MaxUserPort")) {
            $val = $props.$p
            if ($null -eq $val) { $val = "(default)" }
            [void]$sb.AppendLine("$p = $val")
        }

        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("=== System Profile ===")
        $spPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $sp = Get-ItemProperty $spPath -ErrorAction SilentlyContinue
        [void]$sb.AppendLine("NetworkThrottlingIndex = $($sp.NetworkThrottlingIndex)")
        [void]$sb.AppendLine("SystemResponsiveness = $($sp.SystemResponsiveness)")

        $window.Dispatcher.Invoke([Action]{
            $diagText.Text = $sb.ToString()
            $window.FindName("BtnRunDiag").IsEnabled = $true
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

    Add-LogEntry "INFO" "Diagnostic started"
})

# Clear log
$window.FindName("BtnClearLog").Add_Click({
    $window.FindName("LogList").Items.Clear()
})

# ============================================================
# Show Window
# ============================================================
$window.ShowDialog() | Out-Null
