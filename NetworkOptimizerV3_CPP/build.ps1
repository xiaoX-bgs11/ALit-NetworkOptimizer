$vcvars = "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvarsall.bat"

# Run vcvarsall and capture env
$envOutput = & "$env:COMSPEC" /c "`"$vcvars`" x64 && echo ===ENVSTART=== && set" 2>&1

$inEnv = $false
foreach ($line in $envOutput) {
    if ($line -match "===ENVSTART===") { $inEnv = $true; continue }
    if ($inEnv -and $line -match "^([^=]+)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

Write-Host "INCLUDE=$env:INCLUDE"
Write-Host "LIB=$env:LIB"

# Use short path to avoid encoding issues
$projectDir = "d:\网络优化器v2\NetworkOptimizerV3_CPP"

# Get short path
$fso = New-Object -ComObject Scripting.FileSystemObject
$shortPath = $fso.GetFolder($projectDir).ShortPath
Write-Host "Short path: $shortPath"

Set-Location $shortPath

# Compile
$sourceFiles = @(
    "main.cpp",
    "CommandRunner.cpp",
    "TcpOptimizer.cpp",
    "DnsOptimizer.cpp",
    "QoSManager.cpp",
    "AdapterOptimizer.cpp",
    "NetworkDiagnostics.cpp",
    "NetworkOptimizationEngine.cpp",
    "ProfileManager.cpp"
)

$libs = "comctl32.lib dwmapi.lib gdiplus.lib iphlpapi.lib ws2_32.lib winhttp.lib crypt32.lib uxtheme.lib msimg32.lib shell32.lib ole32.lib user32.lib gdi32.lib advapi32.lib shlwapi.lib winmm.lib"

$outExe = "ALit-NetworkOptimizerV3.exe"

Write-Host "Compiling in: $(Get-Location)"
& cl.exe /nologo /MT /EHsc /O2 /W3 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /I "." $sourceFiles /link /OUT:"$outExe" $libs

if ($LASTEXITCODE -eq 0) {
    Write-Host "BUILD SUCCESS: $outExe"
    $destDir = $fso.GetFolder("C:\Users\Administrator\Desktop\78").ShortPath
    Copy-Item -Path (Join-Path $shortPath $outExe) -Destination (Join-Path $destDir "ALit-NetworkOptimizerV3.exe") -Force
    Write-Host "Copied to desktop 78 folder"
} else {
    Write-Host "BUILD FAILED with exit code $LASTEXITCODE"
}
