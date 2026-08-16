$log = "C:\Users\Administrator\Desktop\78\test_result.txt"
$result = @()

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$result += "IsAdmin: $isAdmin"
$result += "User: $env:USERNAME"

# 测试在用户目录下创建文件
try {
    Set-Content -Path $log -Value "test content" -Encoding UTF8 -Force
    $result += "Set-Content (Desktop): OK"
} catch { $result += "Set-Content (Desktop): FAIL - $($_.Exception.Message)" }

# 测试在 ProgramData 创建目录
try {
    $p = "C:\ProgramData\ALitTestDir"
    New-Item -Path $p -ItemType Directory -Force | Out-Null
    $result += "New-Item (ProgramData): OK"
} catch { $result += "New-Item (ProgramData): FAIL - $($_.Exception.Message)" }

# 测试 .NET File.WriteAllText
try {
    [System.IO.File]::WriteAllText("C:\Users\Administrator\Desktop\78\test_dotnet.txt", "hello", [Text.Encoding]::UTF8)
    $result += ".NET WriteAllText: OK"
} catch { $result += ".NET WriteAllText: FAIL - $($_.Exception.Message)" }

# 写入结果到桌面
$result | Out-File "C:\Users\Administrator\Desktop\78\test_output.txt" -Encoding UTF8 -Force
