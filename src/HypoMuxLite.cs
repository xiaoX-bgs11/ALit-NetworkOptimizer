using System;
using System.Collections.Generic;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32;

class HypoMuxLite
{
    class NicInfo
    {
        public string Name;
        public string IP;
        public int IfIndex;
        public long Connections;
        public long BytesUp;
        public long BytesDown;
    }

    [DllImport("wininet.dll", SetLastError = true)]
    static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);

    static List<NicInfo> nics = new List<NicInfo>();
    static int nextNic = 0;
    static TcpListener httpListener;
    static volatile bool running = false;
    static DateTime startTime;
    static long totalConnections = 0;
    static long totalBytesUp = 0;
    static long totalBytesDown = 0;
    static Thread statsThread;
    static object consoleLock = new object();

    static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "stop")
        {
            RestoreSystemProxy();
            return;
        }

        DetectNics();
        if (nics.Count == 0)
        {
            Console.WriteLine("[HM] 未检测到活动网卡");
            return;
        }

        Console.WriteLine("[HM] HypoMux Lite - 多网卡带宽聚合代理");
        Console.WriteLine("[HM] 基于 HypoMux 核心算法 | 原作者: Hypostasis-Cat");
        Console.WriteLine("[HM] GitHub: https://github.com/Hypostasis-Cat/HypoMux");
        Console.WriteLine("========================================");
        Console.WriteLine("[HM] 检测到 {0} 个活动网卡:", nics.Count);
        for (int i = 0; i < nics.Count; i++)
            Console.WriteLine("[HM]   [{0}] {1} - {2} (IfIndex={3})", i, nics[i].Name, nics[i].IP, nics[i].IfIndex);

        if (nics.Count < 2)
            Console.WriteLine("[HM] 警告: 仅1个网卡，无法带宽聚合。代理仍可运行(全部流量走单网卡)。");

        StartProxy();
    }

    static void DetectNics()
    {
        nics.Clear();
        var allNics = NetworkInterface.GetAllNetworkInterfaces();
        foreach (var nic in allNics)
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

            var ipProps = nic.GetIPProperties();
            foreach (var addr in ipProps.UnicastAddresses)
            {
                if (addr.Address.AddressFamily == AddressFamily.InterNetwork)
                {
                    int ifIndex = 0;
                    try { ifIndex = ipProps.GetIPv4Properties().Index; } catch { }
                    nics.Add(new NicInfo
                    {
                        Name = nic.Name,
                        IP = addr.Address.ToString(),
                        IfIndex = ifIndex
                    });
                    break;
                }
            }
        }
    }

    static void StartProxy()
    {
        running = true;
        startTime = DateTime.Now;

        try
        {
            httpListener = new TcpListener(IPAddress.Loopback, 10801);
            httpListener.Start();
        }
        catch (Exception ex)
        {
            Console.WriteLine("[HM] 代理启动失败: {0}", ex.Message);
            return;
        }

        SetSystemProxy(10801);

        statsThread = new Thread(StatsLoop);
        statsThread.IsBackground = true;
        statsThread.Start();

        Console.WriteLine("[HM] HTTP代理: 127.0.0.1:10801");
        Console.WriteLine("[HM] 系统代理已设置");
        Console.WriteLine("[HM] 按 Enter 停止并恢复...");
        Console.WriteLine("========================================");

        new Thread(AcceptLoop) { IsBackground = true }.Start();

        Console.ReadLine();
        Stop();
    }

    static void AcceptLoop()
    {
        while (running)
        {
            try
            {
                var client = httpListener.AcceptTcpClient();
                new Thread(() => HandleHTTPClient(client)) { IsBackground = true }.Start();
            }
            catch { if (running) continue; else break; }
        }
    }

    static NicInfo SelectNic()
    {
        NicInfo nic;
        lock (nics) { nic = nics[nextNic % nics.Count]; nextNic++; }
        Interlocked.Increment(ref nic.Connections);
        Interlocked.Increment(ref totalConnections);
        return nic;
    }

    static void HandleHTTPClient(TcpClient client)
    {
        var nic = SelectNic();
        try
        {
            client.ReceiveTimeout = 30000;
            client.SendTimeout = 30000;
            var stream = client.GetStream();
            byte[] buf = new byte[8192];
            int totalRead = 0;
            int headerEnd = -1;

            while (totalRead < 65536)
            {
                int n = stream.Read(buf, totalRead, buf.Length - totalRead);
                if (n <= 0) return;
                totalRead += n;
                string s = Encoding.ASCII.GetString(buf, 0, totalRead);
                headerEnd = s.IndexOf("\r\n\r\n");
                if (headerEnd >= 0) break;
                if (totalRead >= buf.Length)
                {
                    buf = new byte[buf.Length * 2];
                }
            }

            if (headerEnd < 0) return;
            string headerStr = Encoding.ASCII.GetString(buf, 0, headerEnd + 4);
            string[] lines = headerStr.Split(new[] { "\r\n" }, StringSplitOptions.None);
            if (lines.Length < 1) return;

            string[] firstLine = lines[0].Split(' ');
            if (firstLine.Length < 3) return;

            string method = firstLine[0].ToUpper();
            string target = firstLine[1];

            string host = null;
            int port = 80;

            if (method == "CONNECT")
            {
                var hp = target.Split(':');
                host = hp[0];
                port = hp.Length > 1 ? int.Parse(hp[1]) : 443;
            }
            else
            {
                try
                {
                    var uri = new Uri(target);
                    host = uri.Host;
                    port = uri.Port;
                }
                catch
                {
                    for (int i = 1; i < lines.Length; i++)
                    {
                        if (lines[i].ToLower().StartsWith("host:"))
                        {
                            var hp = lines[i].Substring(5).Trim().Split(':');
                            host = hp[0];
                            port = hp.Length > 1 ? int.Parse(hp[1]) : 80;
                            break;
                        }
                    }
                }
            }

            if (string.IsNullOrEmpty(host)) return;

            Socket upstream = ConnectBound(host, port, nic);
            if (upstream == null) return;

            try
            {
                if (method == "CONNECT")
                {
                    byte[] resp = Encoding.ASCII.GetBytes("HTTP/1.1 200 Connection Established\r\nProxy-Agent: HypoMuxLite\r\n\r\n");
                    stream.Write(resp, 0, resp.Length);
                }
                else
                {
                    var sb = new StringBuilder();
                    sb.AppendLine(lines[0]);
                    for (int i = 1; i < lines.Length; i++)
                    {
                        string lower = lines[i].ToLower();
                        if (lower.StartsWith("proxy-connection:") || lower.StartsWith("proxy-authorization:"))
                            continue;
                        sb.AppendLine(lines[i]);
                    }
                    sb.AppendLine();
                    byte[] reqBytes = Encoding.ASCII.GetBytes(sb.ToString());
                    upstream.Send(reqBytes);

                    int extraStart = headerEnd + 4;
                    if (totalRead > extraStart)
                        upstream.Send(buf, extraStart, totalRead - extraStart, SocketFlags.None);
                }

                Relay(stream, upstream, nic);
            }
            finally
            {
                try { upstream.Close(); } catch { }
            }
        }
        catch { }
        finally
        {
            try { client.Close(); } catch { }
        }
    }

    static Socket ConnectBound(string host, int port, NicInfo nic)
    {
        try
        {
            IPAddress targetAddr = null;
            IPAddress parsed;
            if (IPAddress.TryParse(host, out parsed))
            {
                targetAddr = parsed.AddressFamily == AddressFamily.InterNetwork ? parsed : null;
            }
            else
            {
                foreach (var a in Dns.GetHostAddresses(host))
                {
                    if (a.AddressFamily == AddressFamily.InterNetwork) { targetAddr = a; break; }
                }
            }
            if (targetAddr == null) return null;

            var socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            socket.ReceiveTimeout = 60000;
            socket.SendTimeout = 60000;

            socket.Bind(new IPEndPoint(IPAddress.Parse(nic.IP), 0));

            if (nic.IfIndex > 0)
            {
                uint ifIndex = (uint)nic.IfIndex;
                byte[] ifIndexBytes = BitConverter.GetBytes(ifIndex);
                if (BitConverter.IsLittleEndian) Array.Reverse(ifIndexBytes);
                socket.SetSocketOption(SocketOptionLevel.IP, (SocketOptionName)31, ifIndexBytes);
            }

            socket.SetSocketOption(SocketOptionLevel.Tcp, SocketOptionName.NoDelay, 1);
            socket.Connect(targetAddr, port);
            return socket;
        }
        catch { return null; }
    }

    static void Relay(NetworkStream clientStream, Socket upstream, NicInfo nic)
    {
        var upstreamStream = new NetworkStream(upstream, ownsSocket: false);
        var t1 = new Thread(() =>
        {
            try
            {
                byte[] b = new byte[65536];
                int n;
                while ((n = clientStream.Read(b, 0, b.Length)) > 0)
                {
                    upstreamStream.Write(b, 0, n);
                    Interlocked.Add(ref nic.BytesUp, n);
                    Interlocked.Add(ref totalBytesUp, n);
                }
            }
            catch { }
            try { upstream.Shutdown(SocketShutdown.Send); } catch { }
        }) { IsBackground = true };
        t1.Start();

        try
        {
            byte[] b = new byte[65536];
            int n;
            while ((n = upstreamStream.Read(b, 0, b.Length)) > 0)
            {
                clientStream.Write(b, 0, n);
                Interlocked.Add(ref nic.BytesDown, n);
                Interlocked.Add(ref totalBytesDown, n);
            }
        }
        catch { }
        try { clientStream.Close(); } catch { }
        t1.Join();
    }

    static void StatsLoop()
    {
        while (running)
        {
            Thread.Sleep(5000);
            TimeSpan el = DateTime.Now - startTime;
            double rateUp = totalBytesUp / el.TotalSeconds / 1024;
            double rateDown = totalBytesDown / el.TotalSeconds / 1024;

            var sb = new StringBuilder();
            sb.AppendFormat("[HM] 运行{0:F0}s | 连接{1} | {2:F1}KB/s ↑ {3:F1}KB/s ↓ | 总 ↑{4:F0}KB ↓{5:F0}KB",
                el.TotalSeconds, totalConnections, rateUp, rateDown,
                totalBytesUp / 1024.0, totalBytesDown / 1024.0);

            foreach (var nic in nics)
            {
                sb.AppendFormat("\n[HM]   {0}({1}): 连接{2} ↑{3:F0}KB ↓{4:F0}KB",
                    nic.Name, nic.IP, nic.Connections,
                    nic.BytesUp / 1024.0, nic.BytesDown / 1024.0);
            }

            lock (consoleLock)
                Console.WriteLine(sb.ToString());
        }
    }

    static void SetSystemProxy(int httpPort)
    {
        try
        {
            using (var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Internet Settings", true))
            {
                key.SetValue("ProxyEnable", 1, RegistryValueKind.DWord);
                key.SetValue("ProxyServer",
                    string.Format("http=127.0.0.1:{0};https=127.0.0.1:{0}", httpPort),
                    RegistryValueKind.String);
                key.SetValue("ProxyOverride",
                    "<local>;localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*",
                    RegistryValueKind.String);
            }
            NotifyProxyChanged();
        }
        catch { }
    }

    static void RestoreSystemProxy()
    {
        try
        {
            using (var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Internet Settings", true))
            {
                key.SetValue("ProxyEnable", 0, RegistryValueKind.DWord);
                key.DeleteValue("ProxyServer", false);
            }
            NotifyProxyChanged();
            Console.WriteLine("[HM] 系统代理已恢复");
        }
        catch { }
    }

    static void NotifyProxyChanged()
    {
        try
        {
            InternetSetOption(IntPtr.Zero, 39, IntPtr.Zero, 0);
            InternetSetOption(IntPtr.Zero, 37, IntPtr.Zero, 0);
        }
        catch { }
    }

    static void Stop()
    {
        running = false;
        try { httpListener.Stop(); } catch { }
        RestoreSystemProxy();
        Console.WriteLine("[HM] 代理已停止");
    }
}