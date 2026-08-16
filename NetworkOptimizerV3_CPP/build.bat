@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1

cd /d "d:\网络优化器v2\NetworkOptimizerV3_CPP"

cl.exe /nologo /MT /EHsc /O2 /W3 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN ^
    /I "." ^
    /D "WIN32_LEAN_AND_MEAN" ^
    main.cpp CommandRunner.cpp TcpOptimizer.cpp DnsOptimizer.cpp QoSManager.cpp ^
    AdapterOptimizer.cpp NetworkDiagnostics.cpp NetworkOptimizationEngine.cpp ProfileManager.cpp ^
    /link /OUT:"ALit-网络优化器V3.exe" ^
    comctl32.lib dwmapi.lib gdiplus.lib iphlpapi.lib ws2_32.lib winhttp.lib crypt32.lib uxtheme.lib msimg32.lib ^
    shell32.lib ole32.lib user32.lib gdi32.lib advapi32.lib shlwapi.lib winmm.lib

if %ERRORLEVEL% EQU 0 (
    echo BUILD SUCCESS
    copy /Y "ALit-网络优化器V3.exe" "C:\Users\Administrator\Desktop\78\ALit-网络优化器V3.exe" >nul 2>&1
    echo Copied to desktop 78 folder
) else (
    echo BUILD FAILED with error %ERRORLEVEL%
)
