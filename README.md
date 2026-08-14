# Network Optimizer v2

Minecraft PvP 网络优化器 & 本地网络优化工具，基于 C++ 和 WinUI 3 构建。

所有优化均使用 Microsoft 官方文档记载的 Windows 网络参数，无任何"玄学"代码。

## 功能概述

### TCP/IP 协议栈优化
- **TcpNoDelay = 1**：禁用 Nagle 算法，消除小数据包延迟合并（PvP 最关键优化）
- **TcpAckFrequency = 1**：每收到一个 TCP 段立即发送 ACK，加速拥塞窗口更新
- **TCP Auto-Tuning**：设置为 normal，允许动态调整接收窗口
- **ECN**：启用显式拥塞通知，减少丢包重传
- **RSS**：启用接收端缩放，多核并行处理网络中断
- **CTCP 拥塞控制**：Compound TCP，高延迟链路下更好的吞吐量
- **Initial RTO = 300ms**：降低初始重传超时，加快连接建立

### 系统级优化
- **NetworkThrottlingIndex = 0xFFFFFFFF**：禁用多媒体类调度器的网络限流
- **SystemResponsiveness = 0**：将最大 CPU 资源分配给游戏
- **Games Task 优先级提升**：GPU Priority=8, Priority=6, Scheduling=High, SFIO=High

### QoS 流量优先级
- 为 Minecraft Java（javaw.exe）创建 DSCP 46 (EF) 策略
- 为 Minecraft 基岩版（Minecraft.Windows.exe）创建 DSCP 46 策略
- 为端口 25565（Java 默认）和 19132（基岩版 UDP）创建端口级 QoS 策略
- 为 FPS 游戏进程（CS2/Valorant/Apex/CoD/PUBG/R6）创建 DSCP 46 策略
- 为 FPS 游戏端口（27015/7448/37015/3074/6015 UDP）创建端口级 QoS 策略

### FPS 游戏子弹命中优化
- **WinDivert UDP FEC**：急速模式即启用 UDP 前向纠错冗余复制，提升抗丢包能力
- **小 UDP 包优先标记**：< 512B 的 UDP 游戏数据包在所有模式自动 DSCP 标记
- **TCP Fast Open**：降低首包延迟
- **TcpMaxDataRetransmissions = 2**：减少重传等待时间
- **DefaultTTL = 64**：标准跳数优化
- 支持 CS2、Valorant、Apex Legends、Call of Duty、PUBG、Rainbow Six Siege 端口预设

### DNS 优化
- 支持 Cloudflare、Google、AliDNS、114DNS、DNSPod 等预设
- DNS 基准测试（自动选择最低延迟的 DNS）
- 一键刷新 DNS 缓存

### 网络适配器优化
- 禁用适配器电源管理（防止休眠中断连接）
- 增大接收/发送缓冲区至 2048
- 启用 RSS（接收端缩放）
- 禁用 LSO（Large Send Offload）降低小包延迟
- 禁用中断节流（Interrupt Moderation）降低延迟
- MTU 优化

### 网络诊断
- 实时带宽监控（上传/下载速率）
- ICMP Ping 延迟测量（原生 IcmpSendEcho）
- 抖动（Jitter）和丢包率测量
- MTU 最优值检测（二分搜索 + DF 标志）
- 下载/上传速度测试（Cloudflare 测速端点）

## 构建要求

### 必需环境
- **Visual Studio 2022**（Community/Professional/Enterprise 均可）
  - 安装时勾选工作负载：**使用 C++ 的桌面开发**
  - 在"单个组件"中勾选：**Windows 11 SDK (10.0.22621+)** 或 **Windows 10 SDK (10.0.19041+)**
- **Windows App SDK 1.6+**（通过 NuGet 自动还原）
- Windows 10 19041+ 或 Windows 11

### NuGet 包（自动还原）
| 包名 | 版本 | 用途 |
|------|------|------|
| Microsoft.WindowsAppSDK | 1.6.250108002 | WinUI 3 框架 |
| Microsoft.Windows.CppWinRT | 2.0.240405.15 | C++/WinRT 支持 |
| Microsoft.Windows.ImplementationLibrary | 1.0.240803.1 | WIL 辅助库 |

## 构建步骤

1. **安装 Visual Studio 2022**
   - 下载：https://visualstudio.microsoft.com/zh-hans/vs/
   - 勾选"使用 C++ 的桌面开发"工作负载
   - 确保包含 Windows 10/11 SDK

2. **打开项目**
   ```
   用 Visual Studio 2022 打开 NetworkOptimizer.sln
   ```

3. **还原 NuGet 包**
   - 右键解决方案 → 还原 NuGet 包
   - 等待包下载完成

4. **选择配置**
   - 配置：Release
   - 平台：x64（推荐）或 x86

5. **构建**
   - 按 Ctrl+Shift+B 或 点击 生成 → 生成解决方案

6. **运行**
   - 程序需要管理员权限（app.manifest 已配置 requireAdministrator）
   - UAC 弹窗点击"是"即可

## 命令行模式（无需编译）

如果暂时无法编译 WinUI 3 项目，可直接使用命令行版本：

```
右键 optimize.bat → 以管理员身份运行
```

命令行版本包含与 GUI 相同的核心优化功能。

## 项目架构

```
NetworkOptimizer/
├── NetworkOptimizer.sln              # Visual Studio 解决方案
├── optimize.bat                       # 命令行优化脚本（无需编译）
└── NetworkOptimizer/                  # 项目目录
    ├── NetworkOptimizer.vcxproj       # MSBuild 项目文件
    ├── packages.config                # NuGet 包配置
    ├── app.manifest                   # 应用清单（管理员权限）
    ├── pch.h / pch.cpp                # 预编译头
    ├── Main.cpp                       # 程序入口
    ├── App.xaml / .h / .cpp           # WinUI 3 Application 类
    ├── MainWindow.xaml / .h / .cpp    # 主窗口（导航 + 所有页面）
    └── core/                          # 核心优化引擎
        ├── Types.h                    # 公共类型定义
        ├── CommandRunner.h/.cpp       # 命令执行器（cmd/PowerShell）
        ├── TcpOptimizer.h/.cpp        # TCP/IP 优化（netsh + 注册表）
        ├── DnsOptimizer.h/.cpp        # DNS 优化
        ├── QoSManager.h/.cpp          # QoS 策略管理
        ├── AdapterOptimizer.h/.cpp    # 网络适配器优化
        ├── NetworkDiagnostics.h/.cpp  # 网络诊断（ICMP/带宽/MTU）
        ├── ProfileManager.h/.cpp      # 配置文件管理（JSON）
        └── NetworkOptimizationEngine.h/.cpp  # 主引擎（协调所有模块）
```

## 优化原理说明

### 为什么禁用 Nagle 算法（TcpNoDelay）对 PvP 最重要？

Nagle 算法会将多个小数据包合并为一个大包发送，以减少网络开销。但 Minecraft PvP 场景中，玩家的点击、移动等操作生成的是小数据包，需要立即发送。Nagle 算法会引入最多 40ms 的延迟，禁用后每个操作立即发送，显著提升 PvP 响应速度。

### 为什么设置 TcpAckFrequency = 1？

默认情况下，Windows 每收到 2 个 TCP 段才发送一个 ACK。设为 1 后，每收到一个段就发送 ACK，让服务器更快地更新拥塞窗口，从而更快地提升发送速率。这在交互式场景中可降低延迟。

### 为什么禁用网络限流？

Windows 的多媒体类调度器（MMCSS）默认将网络中断限制为每毫秒 10 个包。这在高带宽场景下会成为瓶颈。设置为 0xFFFFFFFF 完全禁用限流，允许网络中断以全速处理。

### QoS DSCP 46 (EF) 是什么？

DSCP（差分服务代码点）46 对应"加速转发"（Expedited Forwarding），是 IP 层最高优先级标记。配置后，Windows 网络栈会优先处理标记了 DSCP 46 的数据包。为 Minecraft 进程和端口创建 QoS 策略后，游戏数据包将在网络栈中获得最高优先级处理。

## 注意事项

1. **管理员权限**：程序修改系统网络设置，需要管理员权限运行
2. **重启生效**：部分注册表修改需要重启网络适配器或重启电脑才能生效
3. **可还原**：所有优化均可通过"Revert All"按钮或脚本选项 2 完全还原
4. **兼容性**：所有优化均基于 Microsoft 官方文档，不会损坏系统
5. **杀毒软件**：部分杀毒软件可能拦截 QoS 策略修改，需要添加信任

## 技术参考

- TCP/IP 注册表参数：https://learn.microsoft.com/en-us/windows/client-management/troubleshoot-tcpip-connectivity-problems
- netsh interface tcp 命令：https://learn.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-interface-tcp
- QoS 策略：https://learn.microsoft.com/en-us/windows-server/networking/technologies/qos/qos-policy-manage
- Get-NetAdapter cmdlet：https://learn.microsoft.com/en-us/powershell/module/netadapter/get-netadapter
- Network Throttling Index：https://learn.microsoft.com/en-us/windows/win32/api/_multimedia/

## 许可证

本项目仅供学习和个人使用。
