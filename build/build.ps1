# ALit-网络优化器V3 打包脚本
# 用法: powershell -ExecutionPolicy Bypass -File build.ps1

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcScript = Join-Path $projectRoot "src\ALit-网络优化器V3.ps1"
$iconPath = Join-Path $projectRoot "app_icon_transparent.ico"
$outputDir = Join-Path $projectRoot "output"
$outputExe = Join-Path $outputDir "ALit-网络优化器V3.exe"

if (-not (Test-Path $srcScript)) {
    Write-Error "源码文件不存在: $srcScript"
    exit 1
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# 安装 ps2exe 模块
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "正在安装 ps2exe 模块..." -ForegroundColor Yellow
    Install-Module -Name ps2exe -Force -Scope CurrentUser -AllowClobber
}

$buildScript = $srcScript

# ps2exe 打包
Write-Host "正在打包 EXE..." -ForegroundColor Cyan

$ps2exeArgs = @{
    InputFile  = $buildScript
    OutputFile = $outputExe
    NoConsole  = $true
    NoError    = $true
    NoVisualStyles = $false
    Title      = "ALit-网络优化器V3"
    Description = "ALit-网络优化工具V3 - Minecraft PvP"
    Company    = "ALit"
    ProductName = "ALit-网络优化工具V3"
    Version    = "3.1.0.0"
}

if (Test-Path $iconPath) {
    $ps2exeArgs.Icon = $iconPath
    Write-Host "使用图标: $iconPath" -ForegroundColor Gray
}

Invoke-PS2EXE @ps2exeArgs

if (Test-Path $outputExe) {
    $size = [math]::Round((Get-Item $outputExe).Length / 1KB, 0)
    Write-Host ""
    Write-Host "打包成功!" -ForegroundColor Green
    Write-Host "输出文件: $outputExe" -ForegroundColor White
    Write-Host "文件大小: ${size} KB" -ForegroundColor White
} else {
    Write-Error "打包失败，EXE未生成"
    exit 1
}
