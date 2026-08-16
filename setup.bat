@echo off
chcp 65001 >nul
title Network Optimizer v2 - Setup Helper
color 0B

echo ╔══════════════════════════════════════════════════════╗
echo ║     Network Optimizer v2 - 环境检测与设置助手        ║
echo ╚══════════════════════════════════════════════════════╝
echo.

:: Check Windows version
echo [1] 检测 Windows 版本...
ver
echo.

:: Check if Visual Studio is installed
echo [2] 检测 Visual Studio...
set "vsFound=0"
if exist "%ProgramFiles%\Microsoft Visual Studio\2022" (
    echo   Visual Studio 2022 found in Program Files
    set "vsFound=1"
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\2022" (
    echo   Visual Studio 2022 found in Program Files (x86)
    set "vsFound=1"
)
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "tokens=*" %%v in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property displayName 2^>nul') do (
        echo   Found: %%v
        set "vsFound=1"
    )
)
if "%vsFound%"=="0" (
    echo   [WARNING] Visual Studio not found!
    echo   请安装 Visual Studio 2022 并勾选"使用 C++ 的桌面开发"工作负载
    echo   下载地址: https://visualstudio.microsoft.com/zh-hans/vs/
    echo.
    echo   如果暂时无法安装，可直接使用命令行版本:
    echo   右键 optimize.bat → 以管理员身份运行
)
echo.

:: Check Windows SDK
echo [3] 检测 Windows SDK...
if exist "%ProgramFiles(x86)%\Windows Kits\10\Include" (
    dir /b "%ProgramFiles(x86)%\Windows Kits\10\Include" 2>nul | findstr /r "10\." >nul
    if not errorlevel 1 (
        echo   Windows SDK found
    ) else (
        echo   Windows SDK directory exists but no SDK versions found
    )
) else (
    echo   [WARNING] Windows SDK not found
)
echo.

:: Check .NET
echo [4] 检测 .NET...
dotnet --version 2>nul
if errorlevel 1 echo   .NET not found (not required for C++ project)
echo.

:: Check NuGet
echo [5] 检测 NuGet...
nuget help 2>nul | findstr "NuGet Version" 2>nul
if errorlevel 1 (
    echo   NuGet CLI not found (Visual Studio includes built-in NuGet)
)
echo.

:: Check admin
echo [6] 检测管理员权限...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo   [WARNING] 未以管理员身份运行
    echo   构建项目不需要管理员权限，但运行优化程序需要
) else (
    echo   管理员权限: OK
)
echo.

echo ══════════════════════════════════════════════════════
echo  构建步骤:
echo  1. 安装 Visual Studio 2022 (勾选"使用 C++ 的桌面开发")
echo  2. 用 VS 2022 打开 NetworkOptimizer.sln
echo  3. 右键解决方案 → 还原 NuGet 包
echo  4. 选择 Release / x64 配置
echo  5. 按 Ctrl+Shift+B 构建
echo  6. 运行生成的 NetworkOptimizer.exe (需要管理员权限)
echo.
echo  命令行模式 (无需编译):
echo  右键 optimize.bat → 以管理员身份运行
echo ══════════════════════════════════════════════════════
echo.
pause
