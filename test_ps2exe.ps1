Add-Type -AssemblyName PresentationFramework
$log = "C:\Users\Administrator\Desktop\78\test_log.txt"

# 测试1: New-Item 创建目录
try {
    $p = "C:\ProgramData\ALitTestDir"
    if (-not (Test-Path $p)) {
        New-Item -Path $p -ItemType Directory -Force | Out-Null
    }
    [System.Windows.MessageBox]::Show("New-Item OK: $p", "Test1", "OK", "Information") | Out-Null
} catch {
    [System.Windows.MessageBox]::Show("New-Item FAIL: $($_.Exception.Message)", "Test1", "OK", "Error") | Out-Null
}

# 测试2: Set-Content 写入文件
try {
    Set-Content -Path $log -Value "test content" -Encoding UTF8 -Force
    [System.Windows.MessageBox]::Show("Set-Content OK: $log", "Test2", "OK", "Information") | Out-Null
} catch {
    [System.Windows.MessageBox]::Show("Set-Content FAIL: $($_.Exception.Message)", "Test2", "OK", "Error") | Out-Null
}

# 测试3: Join-Path
try {
    $jp = Join-Path "C:\ProgramData" "ALitNetworkOptimizer"
    [System.Windows.MessageBox]::Show("Join-Path result: $jp", "Test3", "OK", "Information") | Out-Null
} catch {
    [System.Windows.MessageBox]::Show("Join-Path FAIL: $($_.Exception.Message)", "Test3", "OK", "Error") | Out-Null
}

# 测试4: .NET Directory.CreateDirectory
try {
    $p2 = "C:\ProgramData\ALitTestDir2"
    [System.IO.Directory]::CreateDirectory($p2) | Out-Null
    [System.Windows.MessageBox]::Show(".NET CreateDirectory OK: $p2", "Test4", "OK", "Information") | Out-Null
} catch {
    [System.Windows.MessageBox]::Show(".NET CreateDirectory FAIL: $($_.Exception.Message)", "Test4", "OK", "Error") | Out-Null
}

# 测试5: .NET File.WriteAllText
try {
    [System.IO.File]::WriteAllText("C:\Users\Administrator\Desktop\78\test_dotnet.txt", "hello", [Text.Encoding]::UTF8)
    [System.Windows.MessageBox]::Show(".NET WriteAllText OK", "Test5", "OK", "Information") | Out-Null
} catch {
    [System.Windows.MessageBox]::Show(".NET WriteAllText FAIL: $($_.Exception.Message)", "Test5", "OK", "Error") | Out-Null
}
