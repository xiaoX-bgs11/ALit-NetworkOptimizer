@echo off
chcp 65001 >nul
title Network Optimizer - Command Line Mode
color 0A

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ============================================
    echo   请以管理员身份运行此脚本
    echo   Please run as Administrator
    echo ============================================
    pause
    exit /b 1
)

:menu
cls
echo ╔══════════════════════════════════════════════════════╗
echo ║          Network Optimizer v2 - CLI Mode            ║
echo ║          Minecraft PvP & Local Network              ║
echo ╚══════════════════════════════════════════════════════╝
echo.
echo  [1] 一键优化 (Quick Optimize - Gaming/PvP)
echo  [2] 一键还原 (Revert All Optimizations)
echo  [3] 仅优化 TCP/IP (TCP/IP Only)
echo  [4] 仅优化 DNS (DNS Only)
echo  [5] 仅配置 QoS (QoS Only)
echo  [6] 网络诊断 (Network Diagnostics)
echo  [7] 刷新 DNS 缓存 (Flush DNS)
echo  [8] 查看当前 TCP 设置 (Show TCP Settings)
echo  [9] 退出 (Exit)
echo.
set /p choice=请选择 (1-9): 

if "%choice%"=="1" goto optimize_all
if "%choice%"=="2" goto revert_all
if "%choice%"=="3" goto tcp_only
if "%choice%"=="4" goto dns_only
if "%choice%"=="5" goto qos_only
if "%choice%"=="6" goto diagnose
if "%choice%"=="7" goto flushdns
if "%choice%"=="8" goto show_tcp
if "%choice%"=="9" exit /b 0
goto menu

:optimize_all
echo.
echo === Applying All Optimizations (Gaming/PvP) ===
echo.

echo [1/5] TCP/IP Stack Optimization...
netsh interface tcp set global autotuninglevel=normal
netsh interface tcp set global ecncapability=enabled
netsh interface tcp set global rss=enabled
netsh interface tcp set global timestamps=disabled
netsh interface tcp set global initialrto=300
netsh interface tcp set global rsc=enabled
netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp
echo   Done.

echo [2/5] Registry TCP Parameters...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNoDelay /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Tcp1323Opts /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultSendWindow /t REG_DWORD /d 65535 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultReceiveWindow /t REG_DWORD /d 65535 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /t REG_DWORD /d 65534 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f >nul

:: Apply TcpNoDelay and TcpAckFrequency to all active interfaces
for /f "tokens=*" %%g in ('powershell -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty InterfaceGuid"') do (
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
)
echo   Done.

echo [3/5] System Profile Optimization...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Priority /t REG_DWORD /d 6 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "High" /f >nul
echo   Done.

echo [4/5] QoS Policies for Minecraft...
netsh qos delete policy name="NetOpt_MC_Java_Game" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Bedrock_Game" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Port_25565" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Port_19132" >nul 2>&1
netsh qos add policy name="NetOpt_MC_Java_Game" appPath="javaw.exe" dscp=46 throttleRate=none >nul 2>&1
netsh qos add policy name="NetOpt_MC_Bedrock_Game" appPath="Minecraft.Windows.exe" dscp=46 throttleRate=none >nul 2>&1
powershell -Command "New-NetQoSPolicy -Name 'NetOpt_MC_Port_25565' -DSCPAction 46 -ThrottleRateAction 0 -PolicyStore ActiveStore -ErrorAction SilentlyContinue" >nul 2>&1
powershell -Command "New-NetQoSPolicy -Name 'NetOpt_MC_Port_19132' -DSCPAction 46 -ThrottleRateAction 0 -PolicyStore ActiveStore -ErrorAction SilentlyContinue" >nul 2>&1
echo   Done.

echo [5/5] DNS & Flush Cache...
ipconfig /flushdns >nul
echo   Done.

echo.
echo ================================================
echo   Optimization Complete!
echo   - TCP/IP stack tuned for low latency
echo   - Nagle's algorithm disabled (TcpNoDelay=1)
echo   - ACK frequency set to 1 (immediate ACKs)
echo   - Network throttling disabled
echo   - QoS priority for Minecraft (DSCP 46)
echo   - DNS cache flushed
echo.
echo   Please RESTART your network adapter or
echo   reboot for all changes to take effect.
echo ================================================
echo.
pause
goto menu

:revert_all
echo.
echo === Reverting All Optimizations ===
echo.
netsh interface tcp set global autotuninglevel=normal
netsh interface tcp set global ecncapability=disabled
netsh interface tcp set global timestamps=enabled
netsh interface tcp set global initialrto=1000
netsh interface tcp set supplemental Template=Internet CongestionProvider=cubic

reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNoDelay /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultSendWindow /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DefaultReceiveWindow /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /f >nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 10 /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f >nul

for /f "tokens=*" %%g in ('powershell -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty InterfaceGuid"') do (
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpNoDelay /f >nul 2>&1
    reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpAckFrequency /f >nul 2>&1
)

netsh qos delete policy name="NetOpt_MC_Java_Game" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Bedrock_Game" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Port_25565" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Port_19132" >nul 2>&1

powershell -Command "Get-NetQoSPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'NetOpt_*' } | Remove-NetQoSPolicy -Confirm:$false" >nul 2>&1

ipconfig /flushdns >nul
echo.
echo All optimizations reverted. Restart network adapter to apply.
echo.
pause
goto menu

:tcp_only
echo.
echo === TCP/IP Optimization Only ===
netsh interface tcp set global autotuninglevel=normal
netsh interface tcp set global ecncapability=enabled
netsh interface tcp set global rss=enabled
netsh interface tcp set global timestamps=disabled
netsh interface tcp set global initialrto=300
netsh interface tcp set supplemental Template=Internet CongestionProvider=ctcp
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpNoDelay /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul
for /f "tokens=*" %%g in ('powershell -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -ExpandProperty InterfaceGuid"') do (
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\%%g" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
)
echo TCP/IP optimization complete.
pause
goto menu

:dns_only
echo.
echo === DNS Optimization ===
echo Available presets:
echo   1. Cloudflare (1.1.1.1 / 1.0.0.1)
echo   2. Google (8.8.8.8 / 8.8.4.4)
echo   3. AliDNS (223.5.5.5 / 223.6.6.6)
echo   4. 114DNS (114.114.114.114 / 114.114.115.115)
echo   5. DNSPod (119.29.29.29 / 182.254.116.116)
set /p dns_choice=Select (1-5): 

set "dns1=" & set "dns2="
if "%dns_choice%"=="1" set "dns1=1.1.1.1" & set "dns2=1.0.0.1"
if "%dns_choice%"=="2" set "dns1=8.8.8.8" & set "dns2=8.8.4.4"
if "%dns_choice%"=="3" set "dns1=223.5.5.5" & set "dns2=223.6.6.6"
if "%dns_choice%"=="4" set "dns1=114.114.114.114" & set "dns2=114.114.115.115"
if "%dns_choice%"=="5" set "dns1=119.29.29.29" & set "dns2=182.254.116.116"

if "%dns1%"=="" echo Invalid choice. & pause & goto menu

for /f "tokens=*" %%i in ('powershell -Command "(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1).Name"') do set "iface=%%i"
echo Setting DNS for interface: %iface%
netsh interface ip set dns name="%iface%" static %dns1% primary
netsh interface ip add dns name="%iface%" %dns2% index=2
ipconfig /flushdns >nul
echo DNS set to %dns1% / %dns2%
pause
goto menu

:qos_only
echo.
echo === QoS Configuration for Minecraft ===
netsh qos delete policy name="NetOpt_MC_Java_Game" >nul 2>&1
netsh qos delete policy name="NetOpt_MC_Bedrock_Game" >nul 2>&1
netsh qos add policy name="NetOpt_MC_Java_Game" appPath="javaw.exe" dscp=46 throttleRate=none >nul 2>&1
netsh qos add policy name="NetOpt_MC_Bedrock_Game" appPath="Minecraft.Windows.exe" dscp=46 throttleRate=none >nul 2>&1
echo QoS policies created for:
echo   - javaw.exe (Minecraft Java) - DSCP 46
echo   - Minecraft.Windows.exe (Bedrock) - DSCP 46
pause
goto menu

:diagnose
echo.
echo === Network Diagnostics ===
echo.
echo [Adapter Info]
powershell -Command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Format-Table Name, InterfaceDescription, LinkSpeed, MtuSize -AutoSize"
echo.
echo [IP Configuration]
ipconfig | findstr /i "IPv4 Default Gateway DNS"
echo.
echo [TCP Global Settings]
netsh interface tcp show global
echo.
echo [Ping Test to Gateway]
for /f "tokens=*" %%g in ('powershell -Command "(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Select-Object -First 1).NextHop"') do ping %%g -n 5
echo.
pause
goto menu

:flushdns
echo.
ipconfig /flushdns
echo.
pause
goto menu

:show_tcp
echo.
netsh interface tcp show global
echo.
pause
goto menu
