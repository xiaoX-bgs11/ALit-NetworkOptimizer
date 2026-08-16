$log = "C:\Users\Administrator\Desktop\78\test_result.txt"
$result = @()

# 测试 New-Item
try {
    $p = "C:\ProgramData\ALitTestDir"
    if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    $result += "New-Item: OK ($p)"
} catch { $result += "New-Item: FAIL - $($_.Exception.Message)" }

# 测试 Set-Content
try {
    Set-Content -Path $log -Value "test" -Encoding UTF8 -Force
    $result += "Set-Content: OK"
} catch { $result += "Set-Content: FAIL - $($_.Exception.Message)" }

# 测试 .NET Directory.CreateDirectory
try {
    [System.IO.Directory]::CreateDirectory("C:\ProgramData\ALitTestDir2") | Out-Null
    $result += ".NET CreateDirectory: OK"
} catch { $result += ".NET CreateDirectory: FAIL - $($_.Exception.Message)" }

# 测试 .NET File.WriteAllText
try {
    [System.IO.File]::WriteAllText("C:\Users\Administrator\Desktop\78\test_dotnet.txt", "hello", [Text.Encoding]::UTF8)
    $result += ".NET WriteAllText: OK"
} catch { $result += ".NET WriteAllText: FAIL - $($_.Exception.Message)" }

# 测试 Join-Path
try {
    $jp = Join-Path "C:\ProgramData" "ALitNetworkOptimizer"
    $result += "Join-Path: $jp"
} catch { $result += "Join-Path: FAIL - $($_.Exception.Message)" }

# 输出结果
$result | ForEach-Object { Write-Host $_ }

# 也写入注册表
try {
    Set-ItemProperty -Path "HKCU:\Software\ALitTest" -Name "Result" -Value ($result -join "|") -Force
} catch {}

Read-Host "Press Enter to exit"
