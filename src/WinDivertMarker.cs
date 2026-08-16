// WinDivert 逐包优化引擎 V3 - 多模式增强版
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

class WinDivertMarker
{
    const string DLL = "WinDivert";
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
    static extern IntPtr WinDivertOpen(string filter, int layer, short priority, ulong flags);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertRecv(IntPtr handle, byte[] pPacket, uint packetLen, out uint pRecvLen, ref WINDIVERT_ADDRESS pAddr);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertSend(IntPtr handle, byte[] pPacket, uint packetLen, out uint pSendLen, ref WINDIVERT_ADDRESS pAddr);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertShutdown(IntPtr handle, int how);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertClose(IntPtr handle);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertSetParam(IntPtr handle, int param, ulong value);
    [DllImport(DLL, CallingConvention = CallingConvention.Cdecl)]
    static extern bool WinDivertHelperCalcChecksums(byte[] pPacket, uint packetLen, ref WINDIVERT_ADDRESS pAddr, ulong flags);

    [StructLayout(LayoutKind.Sequential)]
    struct WINDIVERT_ADDRESS
    {
        public long Timestamp;
        public uint Layer_Events_Flags;
        public uint IfIdx;
        public uint SubIfIdx;
        public uint pad0, pad1, pad2, pad3, pad4, pad5, pad6, pad7, pad8, pad9, pad10;
    }

    const int WINDIVERT_LAYER_NETWORK = 0;
    const int WINDIVERT_SHUTDOWN_RECV = 1;
    const int WINDIVERT_PARAM_QUEUE_LENGTH = 0;
    const int WINDIVERT_PARAM_QUEUE_TIME = 1;
    const int WINDIVERT_PARAM_QUEUE_SIZE = 2;
    const uint FLAG_OUTBOUND = (1u << 17);
    const uint FLAG_IPV6 = (1u << 20);

    // 模式配置: 0=普通 1=最佳 2=急速 3=狂暴 4=Backtrack
    static string[] modeNames = { "\u666e\u901a\u6a21\u5f0f", "\u6700\u4f73\u6a21\u5f0f", "\u6025\u901f\u6a21\u5f0f", "\u72c2\u66b4\u6a21\u5f0f", "Backtrack", "FPS\u7cbe\u786e" };
    static bool[] modeBidir = { false, true, true, true, true, true };
    static bool[] modeAck = { false, true, true, true, true, true };
    static bool[] modeWin = { false, false, true, true, true, true };
    static bool[] modeFec = { false, false, false, true, true, true };
    static bool[] modeBt = { false, false, false, false, true, true };
    static bool[] modeUdpFec = { false, false, true, true, true, true };
    static bool[] modeTripleFec = { false, false, false, false, false, true };
    static bool[] modeUdpBt = { false, false, false, false, false, true };
    static uint[] modeBtDelay = { 15, 15, 15, 15, 15, 5 };
    static uint[] modeQTime = { 100, 50, 20, 10, 5, 1 };
    static uint[] modeQLen = { 16384, 16384, 8192, 32768, 65536, 4096 };
    static uint[] modeQSize = { 33554432, 33554432, 16777216, 67108864, 134217728, 4194304 };

    static IntPtr handle = IntPtr.Zero;
    static volatile bool running = true;
    static long totalPackets = 0;
    static long modifiedPackets = 0;
    static long ackPackets = 0;
    static long tcpPackets = 0;
    static long udpPackets = 0;
    static long inboundPackets = 0;
    static long outboundPackets = 0;
    static long fecPackets = 0;
    static long btPackets = 0;
    static long btRecovered = 0;
    static DateTime startTime;
    static uint adaptiveQTime = 100;
    static long lastTotal = 0;
    static DateTime lastStatsTime;
    static int currentMode = 0;
    static uint currentBaseQTime = 100;

    // FEC path switching - alternate DSCP for duplicate packets
    static int dscpAltCounter = 0;
    static byte[] altTosValues = { 0xB8, 0x88, 0xC0, 0xA0 };

    // Backtrack buffer for delayed packet recovery
    struct BtEntry { public byte[] Data; public uint Len; public WINDIVERT_ADDRESS Addr; public DateTime Ts; public uint Seq; }
    static Queue<BtEntry> btBuffer = new Queue<BtEntry>();
    static uint lastAckSeq = 0;

    // UDP Backtrack buffer for FPS mode - delayed re-injection of UDP game packets
    struct UdpBtEntry { public byte[] Data; public uint Len; public WINDIVERT_ADDRESS Addr; public DateTime Ts; }
    static Queue<UdpBtEntry> udpBtBuffer = new Queue<UdpBtEntry>();
    static long udpBtPackets = 0;
    static long udpBtRecovered = 0;

    // Jitter tracking
    static Queue<double> recentJitter = new Queue<double>();
    static DateTime lastPktTime = DateTime.MinValue;
    static double currentJitter = 0;

    static void Main(string[] args)
    {
        int mode = 0;
        byte dscpValue = 46;
        List<int> tcpPorts = new List<int>();
        tcpPorts.Add(25565);
        List<int> udpPorts = new List<int>();
        udpPorts.Add(19132);

        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--mode" && i + 1 < args.Length) { int m; if (int.TryParse(args[++i], out m)) mode = m; }
            else if (args[i] == "--tcp" && i + 1 < args.Length) ParsePorts(args[++i], tcpPorts);
            else if (args[i] == "--udp" && i + 1 < args.Length) ParsePorts(args[++i], udpPorts);
            else if (args[i] == "--dscp" && i + 1 < args.Length) { byte d; if (byte.TryParse(args[++i], out d)) dscpValue = d; }
            else if (args[i] == "--accel") { Console.WriteLine("[WD] \u52a0\u901f\u5668\u517c\u5bb9\u6a21\u5f0f\u5df2\u542f\u7528"); }
        }
        if (mode < 0) mode = 0;
        if (mode > 5) mode = 5;

        byte tosValue = (byte)(dscpValue << 2);
        bool bidir = modeBidir[mode];
        bool ackPri = modeAck[mode];
        bool winOpt = modeWin[mode];
        bool fecEn = modeFec[mode];
        bool btEn = modeBt[mode];
        bool udpFecEn = modeUdpFec[mode];
        bool tripleFecEn = modeTripleFec[mode];
        bool udpBtEn = modeUdpBt[mode];
        uint btDelay = modeBtDelay[mode];
        uint qTime = modeQTime[mode];
        uint qLen = modeQLen[mode];
        uint qSize = modeQSize[mode];
        adaptiveQTime = qTime;

        string filter = BuildFilter(tcpPorts, udpPorts, bidir);

        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Console.WriteLine("[WD] \u6a21\u5f0f: {0} | DSCP={1} TOS=0x{2:X2} | \u53cc\u5411={3} ACK={4} TCP\u7a97\u53e3={5} FEC={6} BT={7} UDP-FEC={8} 3xFEC={9} UDP-BT={10} BT\u5ef6\u8fdf={11}ms",
            modeNames[mode], dscpValue, tosValue, bidir, ackPri, winOpt, fecEn, btEn, udpFecEn, tripleFecEn, udpBtEn, btDelay);
        Console.WriteLine("[WD] \u8fc7\u6ee4\u5668: {0}", filter);
        Console.WriteLine("[WD] TCP\u7aef\u53e3: {0} | UDP\u7aef\u53e3: {1}",
            string.Join(",", tcpPorts.ToArray()), string.Join(",", udpPorts.ToArray()));

        ConsoleCancelEventHandler handler = (s, e) => { e.Cancel = true; running = false; if (handle != IntPtr.Zero) WinDivertShutdown(handle, WINDIVERT_SHUTDOWN_RECV); };
        Console.CancelKeyPress += handler;

        handle = WinDivertOpen(filter, WINDIVERT_LAYER_NETWORK, 0, 0);
        if (handle == IntPtr.Zero || handle == (IntPtr)(-1))
        {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("[WD] ERROR: \u65e0\u6cd5\u6253\u5f00\u53e5\u67c4 Error={0}", err);
            return;
        }
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_LENGTH, qLen);
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_TIME, qTime);
        WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_SIZE, qSize);
        Console.WriteLine("[WD] [{0}] \u53e5\u67c4\u5df2\u6253\u5f00\uff0c\u5f00\u59cb\u9010\u5305\u4f18\u5316...", modeNames[mode]);
        startTime = DateTime.Now;
        lastStatsTime = startTime;
        currentMode = mode;
        currentBaseQTime = qTime;
        byte[] packet = new byte[65575];
        WINDIVERT_ADDRESS addr = new WINDIVERT_ADDRESS();
        uint recvLen;
        DateTime lastReport = startTime;

        Thread statsThread = new Thread(() => {
            while (running) {
                Thread.Sleep(5000);
                if (!running) break;
                AdaptiveOptimize(currentBaseQTime, currentMode);
                TimeSpan el = DateTime.Now - startTime;
                double rate = el.TotalSeconds > 0 ? totalPackets / el.TotalSeconds : 0;
                Console.WriteLine("[WD] [{0}] 运行{1:F0}s | 总包{2} | 优化{3} | TCP:{4} UDP:{5} ACK:{6} FEC:{7} BT:{8} 恢复:{9} UDP-BT:{10} U恢复:{11} | {12:F1}pkt/s | 队列{13}ms | 抖动{14:F1}ms",
                    modeNames[currentMode], el.TotalSeconds, totalPackets, modifiedPackets, tcpPackets, udpPackets, ackPackets, fecPackets, btPackets, btRecovered, udpBtPackets, udpBtRecovered, rate, adaptiveQTime, currentJitter);
            }
        });
        statsThread.IsBackground = true;
        statsThread.Start();

        while (running)
        {
            if (!WinDivertRecv(handle, packet, (uint)packet.Length, out recvLen, ref addr))
            {
                if (running)
                {
                    int err = Marshal.GetLastWin32Error();
                    if (err != 995) Console.WriteLine("[WD] \u63a5\u6536\u5931\u8d25 Error={0}", err);
                }
                break;
            }
            totalPackets++;
            bool isOutbound = (addr.Layer_Events_Flags & FLAG_OUTBOUND) != 0;
            bool isIPv6 = (addr.Layer_Events_Flags & FLAG_IPV6) != 0;
            if (isOutbound) outboundPackets++; else inboundPackets++;

            // Jitter tracking
            DateTime nowPkt = DateTime.Now;
            if (lastPktTime != DateTime.MinValue)
            {
                double delta = (nowPkt - lastPktTime).TotalMilliseconds;
                recentJitter.Enqueue(delta);
                if (recentJitter.Count > 50) recentJitter.Dequeue();
                double sum = 0; foreach (var j in recentJitter) sum += j;
                currentJitter = sum / recentJitter.Count;
            }
            lastPktTime = nowPkt;

            // Extract protocol and TCP info for FEC/BT
            int ipHdrLenFec = 0; byte protocolFec = 0; uint tcpSeqFec = 0; uint tcpAckFec = 0;
            bool isTcpDataFec = false; bool isAckOnlyFec = false;
            if (!isIPv6 && recvLen >= 20)
            {
                ipHdrLenFec = (packet[0] & 0x0F) * 4;
                if (ipHdrLenFec >= 20 && recvLen >= (uint)(ipHdrLenFec + 20))
                {
                    protocolFec = packet[9];
                    if (protocolFec == 6)
                    {
                        int tcpOff = ipHdrLenFec;
                        tcpSeqFec = (uint)((packet[tcpOff + 4] << 24) | (packet[tcpOff + 5] << 16) | (packet[tcpOff + 6] << 8) | packet[tcpOff + 7]);
                        tcpAckFec = (uint)((packet[tcpOff + 8] << 24) | (packet[tcpOff + 9] << 16) | (packet[tcpOff + 10] << 8) | packet[tcpOff + 11]);
                        byte flags = packet[tcpOff + 13];
                        bool isAck = (flags & 0x10) != 0;
                        isAckOnlyFec = isAck && ((flags & 0x3F) == 0x10);
                        uint ipTotal = (uint)((packet[2] << 8) | packet[3]);
                        int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                        if (ipTotal >= (uint)(ipHdrLenFec + tcpHdrLen) && ipTotal <= recvLen)
                        {
                            uint payload = ipTotal - (uint)ipHdrLenFec - (uint)tcpHdrLen;
                            isTcpDataFec = payload > 0;
                        }
                    }
                }
            }

            // Backtrack: track incoming ACKs to remove buffered packets
            if (btEn && !isOutbound && isAckOnlyFec)
            {
                lastAckSeq = tcpAckFec;
                while (btBuffer.Count > 0 && btBuffer.Peek().Seq < tcpAckFec)
                {
                    btBuffer.Dequeue();
                }
            }

            bool modified = ProcessPacket(packet, recvLen, tosValue, bidir, isOutbound, isIPv6, ackPri, winOpt);

            if (modified) { WinDivertHelperCalcChecksums(packet, recvLen, ref addr, 0); modifiedPackets++; }

            uint sendLen;
            WinDivertSend(handle, packet, recvLen, out sendLen, ref addr);

            // === FEC: duplicate outgoing UDP packets with alternate DSCP (path switching) ===
            if ((fecEn || udpFecEn) && isOutbound && protocolFec == 17 && recvLen > 0)
            {
                int fecCopies = 1;
                if (tripleFecEn) fecCopies = 2;
                if (currentJitter > 20.0) fecCopies++;
                for (int fc = 0; fc < fecCopies; fc++)
                {
                    byte[] fecCopy = new byte[recvLen];
                    Buffer.BlockCopy(packet, 0, fecCopy, 0, (int)recvLen);
                    byte altTos = altTosValues[(dscpAltCounter + fc) % altTosValues.Length];
                    if (!isIPv6) fecCopy[1] = altTos;
                    else { fecCopy[0] = (byte)((fecCopy[0] & 0xF0) | ((altTos >> 4) & 0x0F)); fecCopy[1] = (byte)(((altTos & 0x0F) << 4) | (fecCopy[1] & 0x0F)); }
                    WINDIVERT_ADDRESS fecAddr = addr;
                    WinDivertHelperCalcChecksums(fecCopy, recvLen, ref fecAddr, 0);
                    uint fecSendLen;
                    WinDivertSend(handle, fecCopy, recvLen, out fecSendLen, ref fecAddr);
                    fecPackets++;
                }
                dscpAltCounter += fecCopies;
            }

            // === UDP Backtrack: buffer outgoing small UDP packets for delayed re-injection ===
            if (udpBtEn && isOutbound && protocolFec == 17 && recvLen > 0 && recvLen < 512)
            {
                byte[] udpBuf = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, udpBuf, 0, (int)recvLen);
                UdpBtEntry udpEntry = new UdpBtEntry { Data = udpBuf, Len = recvLen, Addr = addr, Ts = DateTime.Now };
                udpBtBuffer.Enqueue(udpEntry);
                if (udpBtBuffer.Count > 300) udpBtBuffer.Dequeue();
                udpBtPackets++;
            }

            // === UDP BT delayed re-injection: re-send buffered UDP packets older than btDelay ms ===
            if (udpBtEn && udpBtBuffer.Count > 0)
            {
                DateTime udpCutoff = DateTime.Now.AddMilliseconds(-(double)btDelay);
                int udpRecovered = 0;
                while (udpBtBuffer.Count > 0 && udpBtBuffer.Peek().Ts < udpCutoff)
                {
                    UdpBtEntry ue = udpBtBuffer.Dequeue();
                    byte[] udpRcv = new byte[ue.Len];
                    Buffer.BlockCopy(ue.Data, 0, udpRcv, 0, (int)ue.Len);
                    byte udpBoostTos = 0xA0;
                    if (!isIPv6) udpRcv[1] = udpBoostTos;
                    WINDIVERT_ADDRESS udpRcvAddr = ue.Addr;
                    WinDivertHelperCalcChecksums(udpRcv, ue.Len, ref udpRcvAddr, 0);
                    uint udpRcvSendLen;
                    WinDivertSend(handle, udpRcv, ue.Len, out udpRcvSendLen, ref udpRcvAddr);
                    udpBtRecovered++;
                    udpRecovered++;
                }
                if (udpRecovered > 0 && (DateTime.Now - lastReport).TotalSeconds >= 1)
                {
                    Console.WriteLine("[WD] UDP-BT \u5ef6\u540e\u6062\u590d: {0}\u4e2a\u5305\u91cd\u53d1 (jitter={1:F1}ms)", udpRecovered, currentJitter);
                }
            }

            // === Backtrack: duplicate outgoing TCP data packets + delayed recovery ===
            if (btEn && isOutbound && isTcpDataFec && recvLen > 0 && recvLen < 60000)
            {
                // Redundant duplication: send a copy with alternate DSCP
                byte[] btCopy = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, btCopy, 0, (int)recvLen);
                byte altTos = altTosValues[(dscpAltCounter + 2) % altTosValues.Length];
                if (!isIPv6) btCopy[1] = altTos;
                WINDIVERT_ADDRESS btAddr = addr;
                WinDivertHelperCalcChecksums(btCopy, recvLen, ref btAddr, 0);
                uint btSendLen;
                WinDivertSend(handle, btCopy, recvLen, out btSendLen, ref btAddr);
                btPackets++;

                // Buffer for delayed recovery
                byte[] bufCopy = new byte[recvLen];
                Buffer.BlockCopy(packet, 0, bufCopy, 0, (int)recvLen);
                BtEntry entry = new BtEntry { Data = bufCopy, Len = recvLen, Addr = addr, Ts = DateTime.Now, Seq = tcpSeqFec };
                btBuffer.Enqueue(entry);
                if (btBuffer.Count > 200) btBuffer.Dequeue();
            }

            // === Delayed packet recovery: re-inject unacked packets older than btDelay ms ===
            if (btEn && btBuffer.Count > 0)
            {
                DateTime cutoff = DateTime.Now.AddMilliseconds(-(double)btDelay);
                int recovered = 0;
                while (btBuffer.Count > 0 && btBuffer.Peek().Ts < cutoff)
                {
                    BtEntry e = btBuffer.Dequeue();
                    if (e.Seq >= lastAckSeq)
                    {
                        byte[] rcv = new byte[e.Len];
                        Buffer.BlockCopy(e.Data, 0, rcv, 0, (int)e.Len);
                        byte boostTos = 0xC0;
                        if (!isIPv6) rcv[1] = boostTos;
                        WINDIVERT_ADDRESS rcvAddr = e.Addr;
                        WinDivertHelperCalcChecksums(rcv, e.Len, ref rcvAddr, 0);
                        uint rcvSendLen;
                        WinDivertSend(handle, rcv, e.Len, out rcvSendLen, ref rcvAddr);
                        btRecovered++;
                        recovered++;
                    }
                }
                if (recovered > 0)
                {
                    Console.WriteLine("[WD] BT \u5ef6\u540e\u6062\u590d: {0}\u4e2a\u5305\u91cd\u53d1 (jitter={1:F1}ms)", recovered, currentJitter);
                }
            }
        }
        running = false;
        if (handle != IntPtr.Zero && handle != (IntPtr)(-1)) { WinDivertShutdown(handle, WINDIVERT_SHUTDOWN_RECV); Thread.Sleep(100); WinDivertClose(handle); }
        TimeSpan total = DateTime.Now - startTime;
        Console.WriteLine("[WD] \u5df2\u505c\u6b62 | \u8fd0\u884c{0:F0}s | \u603b\u5305{1} | \u4f18\u5316{2} | FEC:{3} BT:{4} \u6062\u590d:{5} UDP-BT:{6} U\u6062\u590d:{7}", total.TotalSeconds, totalPackets, modifiedPackets, fecPackets, btPackets, btRecovered, udpBtPackets, udpBtRecovered);
    }

    static void ParsePorts(string s, List<int> list)
    {
        list.Clear();
        string trimmed = s.Trim();
        if (trimmed == "0" || trimmed.Length == 0) return;
        string[] parts = s.Split(new char[] { ',', ' ', ';' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (string p in parts)
        {
            int port;
            if (int.TryParse(p.Trim(), out port) && port > 0 && port < 65536) list.Add(port);
        }
        if (list.Count == 0) list.Add(25565);
    }

    static string BuildFilter(List<int> tcpPorts, List<int> udpPorts, bool bidir)
    {
        List<string> parts = new List<string>();
        foreach (int p in tcpPorts) { parts.Add(string.Format("tcp.DstPort == {0}", p)); parts.Add(string.Format("tcp.SrcPort == {0}", p)); }
        foreach (int p in udpPorts) { parts.Add(string.Format("udp.DstPort == {0}", p)); parts.Add(string.Format("udp.SrcPort == {0}", p)); }
        if (parts.Count == 0) return bidir ? "true" : "outbound";
        string portFilter = string.Join(" or ", parts.ToArray());
        if (bidir) return portFilter;
        return "outbound and (" + portFilter + ")";
    }

    static bool ProcessPacket(byte[] packet, uint len, byte tosValue, bool bidir, bool isOutbound, bool isIPv6, bool ackPri, bool winOpt)
    {
        if (len < 20) return false;
        bool modified = false;
        int ipHdrLen;
        byte protocol;

        if (!isIPv6)
        {
            byte version = (byte)((packet[0] >> 4) & 0x0F);
            if (version != 4) return false;
            ipHdrLen = (packet[0] & 0x0F) * 4;
            if (ipHdrLen < 20 || len < ipHdrLen) return false;
            protocol = packet[9];
            // FPS: mark small UDP game packets (< 512B) even in non-bidir mode
            if (bidir || isOutbound || (protocol == 17 && len < 512))
            {
                if (packet[1] != tosValue) { packet[1] = tosValue; modified = true; }
            }
        }
        else
        {
            byte version = (byte)((packet[0] >> 4) & 0x0F);
            if (version != 6) return false;
            ipHdrLen = 40;
            if (len < ipHdrLen) return false;
            protocol = packet[6];
            if (bidir || isOutbound || (protocol == 17 && len < 512))
            {
                byte tcH = (byte)((tosValue >> 4) & 0x0F), tcL = (byte)(tosValue & 0x0F);
                byte o0 = packet[0], o1 = packet[1];
                packet[0] = (byte)((o0 & 0xF0) | tcH);
                packet[1] = (byte)((tcL << 4) | (o1 & 0x0F));
                if (o0 != packet[0] || o1 != packet[1]) modified = true;
            }
        }

        if (protocol == 6 && len >= (uint)(ipHdrLen + 20))
        {
            tcpPackets++;
            int tcpOff = ipHdrLen;
            byte flags = packet[tcpOff + 13];
            bool isAck = (flags & 0x10) != 0;
            bool isAckOnly = isAck && ((flags & 0x3F) == 0x10);

            uint payloadLen = 0;
            if (!isIPv6)
            {
                uint ipTotal = (uint)((packet[2] << 8) | packet[3]);
                int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                if (ipTotal >= (uint)(ipHdrLen + tcpHdrLen) && ipTotal <= len)
                    payloadLen = ipTotal - (uint)ipHdrLen - (uint)tcpHdrLen;
            }
            else
            {
                uint ipv6Pay = (uint)((packet[4] << 8) | packet[5]);
                int tcpHdrLen = (packet[tcpOff + 12] >> 4) * 4;
                if (ipv6Pay >= (uint)tcpHdrLen && (ipv6Pay + 40) <= len)
                    payloadLen = ipv6Pay - (uint)tcpHdrLen;
            }

            if (isAckOnly && payloadLen == 0) ackPackets++;

            if (winOpt && isOutbound && isAck && payloadLen == 0 && len >= (uint)(tcpOff + 16))
            {
                ushort win = (ushort)((packet[tcpOff + 14] << 8) | packet[tcpOff + 15]);
                if (win > 65535) { packet[tcpOff + 14] = 0xFF; packet[tcpOff + 15] = 0xFF; modified = true; }
            }
        }
        else if (protocol == 17) udpPackets++;

        return modified;
    }

    static void AdaptiveOptimize(uint baseQTime, int mode)
    {
        if (mode < 2) return;
        DateTime now = DateTime.Now;
        double elapsed = (now - lastStatsTime).TotalSeconds;
        if (elapsed <= 0) return;
        long delta = totalPackets - lastTotal;
        double rate = delta / elapsed;
        lastTotal = totalPackets;
        lastStatsTime = now;
        uint target = baseQTime;
        if (rate > 2000) target = (uint)(baseQTime * 0.3);
        else if (rate > 1000) target = (uint)(baseQTime * 0.5);
        else if (rate > 500) target = (uint)(baseQTime * 0.7);
        uint minQ = (mode >= 5) ? 1u : 5u;
        if (target < minQ) target = minQ;
        if (target != adaptiveQTime && handle != IntPtr.Zero && handle != (IntPtr)(-1))
        {
            WinDivertSetParam(handle, WINDIVERT_PARAM_QUEUE_TIME, target);
            adaptiveQTime = target;
        }
    }
}