# ALit-网络优化器V3 打包脚本
# 用法: powershell -ExecutionPolicy Bypass -File build.ps1 [-Obfuscate]

param(
    [switch]$Obfuscate
)

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

if ($Obfuscate) {
    Write-Host "正在混淆源码 (Gzip+Base64)..." -ForegroundColor Cyan
    $obfuscatedPath = Join-Path $env:TEMP "alit_obf_build.ps1"

    $sourceContent = Get-Content $srcScript -Raw
    $bytes = [Text.Encoding]::UTF8.GetBytes($sourceContent)
    $ms = New-Object System.IO.MemoryStream
    $gz = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress)
    $gz.Write($bytes, 0, $bytes.Length)
    $gz.Close()
    $ms.Close()
    $b64 = [Convert]::ToBase64String($ms.ToArray())

    $chunkSize = 30000
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("#Requires -Version 5.1")
    [void]$sb.AppendLine("`$c=[string]::Empty")
    for ($i = 0; $i -lt $b64.Length; $i += $chunkSize) {
        $end = [Math]::Min($i + $chunkSize, $b64.Length)
        $chunk = $b64.Substring($i, $end - $i)
        [void]$sb.AppendLine("`$c+='$chunk'")
    }
    [void]$sb.AppendLine("`$d=[Convert]::FromBase64String(`$c)")
    [void]$sb.AppendLine("`$m=[IO.MemoryStream]::new(`$d)")
    [void]$sb.AppendLine("`$g=[IO.Compression.GZipStream]::new(`$m,[IO.Compression.CompressionMode]::Decompress)")
    [void]$sb.AppendLine("`$r=[IO.StreamReader]::new(`$g,[Text.Encoding]::UTF8)")
    [void]$sb.AppendLine("`$s=`$r.ReadToEnd()")
    [void]$sb.AppendLine("`$r.Dispose();`$g.Dispose();`$m.Dispose()")
    [void]$sb.AppendLine("Invoke-Expression `$s")

    [System.IO.File]::WriteAllText($obfuscatedPath, $sb.ToString(), [Text.Encoding]::UTF8)
    $buildScript = $obfuscatedPath
    Write-Host "混淆完成" -ForegroundColor Green
}

# ps2exe 打包
Write-Host "正在打包 EXE..." -ForegroundColor Cyan

$ps2exeArgs = @{
    InputFile  = $buildScript
    OutputFile = $outputExe
    NoConsole  = $true
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

# 清理临时文件
if ($Obfuscate -and (Test-Path $obfuscatedPath)) {
    Remove-Item $obfuscatedPath -Force -ErrorAction SilentlyContinue
}
