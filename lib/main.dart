import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:io';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';

// IO 動作定義：與下拉選單的中文一一對應
enum IoCommand {
  barrierOpen,
  barrierClose,
  keypadReboot,
  cardReaderReboot,
  ledReboot,
  cameraReboot,
  lprReboot,
  pcReboot,
  emergencyOn,
  emergencyOff,
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carpark Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '出入口控制'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- State values ---
  String? _selectedGate;
  String? _selectedIoCtrl;
  String? _selectedSite;

  List<String> _gates = [];
  final List<String> _ioOptions = [
    '柵欄機開門',
    '柵欄機關門',
    '密碼機重開',
    '刷卡機重開',
    'LED重開',
    '攝影機重開',
    'LPR重開',
    '電腦重開',
    '開啟緊急模式',
    '關閉緊急模式',
  ];
  List<String> _sites = [];

  // 將下拉顯示文字 -> 對應的裝置/站點資訊（後續控制會用到）
  final Map<String, Map<String, dynamic>> _gateLookup = {};

  // 繳費機清單對應（顯示文字 -> 裝置/站點資訊）
  final Map<String, Map<String, dynamic>> _apmLookup = {};

  // Password controllers
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _currentPwdController = TextEditingController();

  // --- IO 控制對應與入口 ---
  IoCommand? _labelToIoCommand(String? label) {
    if (label == null) return null;
    switch (label) {
      case '柵欄機開門':
        return IoCommand.barrierOpen;
      case '柵欄機關門':
        return IoCommand.barrierClose;
      case '密碼機重開':
        return IoCommand.keypadReboot;
      case '刷卡機重開':
        return IoCommand.cardReaderReboot;
      case 'LED重開':
        return IoCommand.ledReboot;
      case '攝影機重開':
        return IoCommand.cameraReboot;
      case 'LPR重開':
        return IoCommand.lprReboot;
      case '電腦重開':
        return IoCommand.pcReboot;
      case '開啟緊急模式':
        return IoCommand.emergencyOn;
      case '關閉緊急模式':
        return IoCommand.emergencyOff;
    }
    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _onConfirmPressed() async {
    if (_selectedGate == null || _selectedGate!.isEmpty) {
      _showSnack('請先選擇出入口');
      return;
    }
    if (_selectedIoCtrl == null || _selectedIoCtrl!.isEmpty) {
      _showSnack('請先選擇 IO 板控制動作');
      return;
    }
    final meta = _gateLookup[_selectedGate!];
    if (meta == null) {
      _showSnack('找不到出入口對應資訊，請重新載入');
      return;
    }
    final cmd = _labelToIoCommand(_selectedIoCtrl);
    if (cmd == null) {
      _showSnack('未知的控制動作');
      return;
    }

    // 顯示 Double Check 對話框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('請再次確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('即將執行以下操作：'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('出入口：', style: TextStyle(fontWeight: FontWeight.w700)),
                  Expanded(child: Text(_selectedGate!)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('控制項目：', style: TextStyle(fontWeight: FontWeight.w700)),
                  Expanded(child: Text(_selectedIoCtrl!)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('確定執行'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _executeIoCommand(cmd, meta);
    }
  }

  Future<void> _executeIoCommand(IoCommand cmd, Map<String, dynamic> meta) async {
    switch (cmd) {
      case IoCommand.barrierOpen:
        await _handleBarrierOpen(meta);
        break;
      case IoCommand.barrierClose:
        await _handleBarrierClose(meta);
        break;
      case IoCommand.keypadReboot:
        await _handleKeypadReboot(meta);
        break;
      case IoCommand.cardReaderReboot:
        await _handleCardReaderReboot(meta);
        break;
      case IoCommand.ledReboot:
        await _handleLedReboot(meta);
        break;
      case IoCommand.cameraReboot:
        await _handleCameraReboot(meta);
        break;
      case IoCommand.lprReboot:
        await _handleLprReboot(meta);
        break;
      case IoCommand.pcReboot:
        await _handlePcReboot(meta);
        break;
      case IoCommand.emergencyOn:
        await _handleEmergencyOn(meta);
        break;
      case IoCommand.emergencyOff:
        await _handleEmergencyOff(meta);
        break;
    }
  }

  // ---- 以下為各功能的 Handler（先做骨架，之後逐一填實作） ----
  Future<void> _handleBarrierOpen(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;

    // 取 device_ip
    final deviceIp = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();

    // 解析 configs，期望有 { lpr: { port: <number> } }
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null; // 若解析失敗
    }

    int? port;
    if (cfgMap != null) {
      final lpr = cfgMap['lpr'];
      if (lpr is Map) {
        final p = lpr['port'];
        if (p != null) port = int.tryParse(p.toString());
      } else {
        // 後備：有些資料可能直接把 port 放在根
        final p = cfgMap['port'];
        if (p != null) port = int.tryParse(p.toString());
      }
    }

    if (deviceIp.isEmpty || port == null) {
      _showSnack('無法取得裝置 IP 或連接埠，請檢查 device_ip / configs.lpr.port');
      debugPrint('[IO] 柵欄機開門 失敗：deviceIp="$deviceIp" port=$port, device=${device['device_name']} siteIp=$siteIp');
      return;
    }

    final url = 'http://$deviceIp:$port/BarrierOpen';
    debugPrint('[IO] 柵欄機開門 → POST $url (siteIp=$siteIp, device=${device['device_name']})');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      // 若對方不需要 body，可以不送內容；這裡送空 JSON 作為通用預設
      req.add(utf8.encode('{}'));
      final resp = await req.close();
      final code = resp.statusCode;
      final respBody = await resp.transform(utf8.decoder).join();

      if (code >= 200 && code < 300) {
        _showSnack('柵欄機開門成功');
        debugPrint('[IO] 柵欄機開門 成功：$code, body=$respBody');
      } else {
        _showSnack('柵欄機開門失敗（$code）');
        debugPrint('[IO] 柵欄機開門 失敗：HTTP $code, body=$respBody');
      }
    } catch (e, st) {
      _showSnack('柵欄機開門失敗：$e');
      debugPrint('[IO] 柵欄機開門 例外：$e\n$st');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleBarrierClose(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;

    // 取 device_ip
    final deviceIp = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();

    // 解析 configs，期望有 { lpr: { port: <number> } }
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null; // 若解析失敗
    }

    int? port;
    if (cfgMap != null) {
      final lpr = cfgMap['lpr'];
      if (lpr is Map) {
        final p = lpr['port'];
        if (p != null) port = int.tryParse(p.toString());
      } else {
        // 後備：有些資料可能直接把 port 放在根
        final p = cfgMap['port'];
        if (p != null) port = int.tryParse(p.toString());
      }
    }

    if (deviceIp.isEmpty || port == null) {
      _showSnack('無法取得裝置 IP 或連接埠，請檢查 device_ip / configs.lpr.port');
      debugPrint('[IO] 柵欄機關門 失敗：deviceIp="$deviceIp" port=$port, device=${device['device_name']} siteIp=$siteIp');
      return;
    }

    final url = 'http://$deviceIp:$port/BarrierClose';
    debugPrint('[IO] 柵欄機關門 → POST $url (siteIp=$siteIp, device=${device['device_name']})');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode('{}'));
      final resp = await req.close();
      final code = resp.statusCode;
      final respBody = await resp.transform(utf8.decoder).join();

      if (code >= 200 && code < 300) {
        _showSnack('柵欄機關門成功');
        debugPrint('[IO] 柵欄機關門 成功：$code, body=$respBody');
      } else {
        _showSnack('柵欄機關門失敗（$code）');
        debugPrint('[IO] 柵欄機關門 失敗：HTTP $code, body=$respBody');
      }
    } catch (e, st) {
      _showSnack('柵欄機關門失敗：$e');
      debugPrint('[IO] 柵欄機關門 例外：$e\n$st');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleKeypadReboot(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] 密碼機重開 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    final ok = await _sendMcuPulse(device, 4);
    if (ok) {
      _showSnack('密碼機重開成功');
    } else {
      _showSnack('密碼機重開失敗');
    }
  }

  Future<void> _handleCardReaderReboot(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] 刷卡機重開 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    final ok = await _sendMcuPulse(device, 5);
    if (ok) {
      _showSnack('刷卡機重開成功');
    } else {
      _showSnack('刷卡機重開失敗');
    }
  }

  Future<void> _handleLedReboot(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] LED重開 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    // 立即回饋（不等待 30 秒）
    _showSnack('LED重開：請等待30秒');
    _sendMcuPulse(device, 6, onDuration: const Duration(seconds: 30)).then((ok) {
      if (!mounted) return;
      if (ok) {
        _showSnack('LED重開完成');
      } else {
        _showSnack('LED重開失敗');
      }
    });
  }

  Future<void> _handleCameraReboot(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] 攝影機重開 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    // 立即回饋（不等待 30 秒）
    _showSnack('攝影機重開：請等待30秒');
    _sendMcuPulse(device, 7, onDuration: const Duration(seconds: 30)).then((ok) {
      if (!mounted) return;
      if (ok) {
        _showSnack('攝影機重開完成');
      } else {
        _showSnack('攝影機重開失敗');
      }
    });
  }
  // 透過 MCU 送出單一 TCP 指令（無脈衝）
  Future<bool> _sendMcuCommand(Map<String, dynamic> device, String command) async {
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null;
    }

    if (cfgMap == null || cfgMap['mcu'] == null || cfgMap['mcu'] is! Map) {
      _showSnack('找不到 MCU 設定（configs.mcu）');
      return false;
    }

    final mcu = cfgMap['mcu'] as Map;
    final mcuIp = (mcu['ip'] ?? '').toString().trim();
    final portRaw = mcu['port'];
    final mcuPort = portRaw == null ? null : int.tryParse(portRaw.toString());

    if (mcuIp.isEmpty || mcuPort == null) {
      _showSnack('MCU IP/Port 缺失，請檢查 configs.mcu.ip / configs.mcu.port');
      return false;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(mcuIp, mcuPort, timeout: const Duration(seconds: 3));
      try { socket.setOption(SocketOption.tcpNoDelay, true); } catch (_) {}

      socket.add(utf8.encode(command));
      await Future.delayed(const Duration(milliseconds: 150));
      await socket.flush();
      return true;
    } catch (e, st) {
      debugPrint('[MCU] CMD "$command" 失敗：$e\n$st');
      _showSnack('MCU 連線失敗：$e');
      return false;
    } finally {
      try { await socket?.close(); } catch (_) {}
    }
  }
  // 透過 MCU (configs.mcu.ip/port) 以 TCP 送出 on/off 脈衝
  Future<bool> _sendMcuPulse(Map<String, dynamic> device, int relay, {Duration onDuration = const Duration(seconds: 1)}) async {
    // 解析 configs：可能是 Map 或 JSON 字串
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null;
    }

    if (cfgMap == null || cfgMap['mcu'] == null || cfgMap['mcu'] is! Map) {
      _showSnack('找不到 MCU 設定（configs.mcu）');
      return false;
    }

    final mcu = cfgMap['mcu'] as Map;
    final mcuIp = (mcu['ip'] ?? '').toString().trim();
    final portRaw = mcu['port'];
    final mcuPort = portRaw == null ? null : int.tryParse(portRaw.toString());

    if (mcuIp.isEmpty || mcuPort == null) {
      _showSnack('MCU IP/Port 缺失，請檢查 configs.mcu.ip / configs.mcu.port');
      return false;
    }

    final cmdOn = 'AT+relay_${relay}=1';
    final cmdOff = 'AT+relay_${relay}=0';

    Socket? socket;
    try {
      socket = await Socket.connect(mcuIp, mcuPort, timeout: const Duration(seconds: 3));
      // 盡量降低延遲
      try { socket.setOption(SocketOption.tcpNoDelay, true); } catch (_) {}

      socket.add(utf8.encode(cmdOn));
      await Future.delayed(onDuration);
      socket.add(utf8.encode(cmdOff));
      // 給對方一點時間接收
      await Future.delayed(const Duration(milliseconds: 150));
      await socket.flush();
      return true;
    } catch (e, st) {
      debugPrint('[MCU] Pulse r$relay 失敗：$e\n$st');
      _showSnack('MCU 連線失敗：$e');
      return false;
    } finally {
      try { await socket?.close(); } catch (_) {}
    }
  }
  // ---- 以下為各功能的 Handler（先做骨架，之後逐一填實作） ----

  Future<void> _handleLprReboot(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;

    // 取 device_ip
    final deviceIp = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();

    // 解析 configs，期望有 { lpr: { port: <number> } }
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null; // 若解析失敗
    }

    int? port;
    if (cfgMap != null) {
      final lpr = cfgMap['lpr'];
      if (lpr is Map) {
        final p = lpr['port'];
        if (p != null) port = int.tryParse(p.toString());
      } else {
        final p = cfgMap['port'];
        if (p != null) port = int.tryParse(p.toString());
      }
    }

    if (deviceIp.isEmpty || port == null) {
      _showSnack('無法取得裝置 IP 或連接埠（LPR），請檢查 device_ip / configs.lpr.port');
      debugPrint('[IO] LPR重開 失敗：deviceIp="$deviceIp" port=$port, device=${device['device_name']} siteIp=$siteIp');
      return;
    }

    final url = 'http://$deviceIp:$port/Restart';
    debugPrint('[IO] LPR重開 → POST $url (siteIp=$siteIp, device=${device['device_name']})');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode('{}'));
      final resp = await req.close();
      final code = resp.statusCode;
      final respBody = await resp.transform(utf8.decoder).join();

      if (code >= 200 && code < 300) {
        _showSnack('LPR重開成功');
        debugPrint('[IO] LPR重開 成功：$code, body=$respBody');
      } else {
        _showSnack('LPR重開失敗（$code）');
        debugPrint('[IO] LPR重開 失敗：HTTP $code, body=$respBody');
      }
    } catch (e, st) {
      _showSnack('LPR重開失敗：$e');
      debugPrint('[IO] LPR重開 例外：$e\n$st');
    } finally {
      client.close(force: true);
    }
  }

  // 以 SSH 對遠端電腦執行 sudo reboot；host 優先使用 configs.lpr.ip
  Future<bool> _sshSudoReboot(Map<String, dynamic> device) async {
    // 解析 configs：Map 或 JSON 字串
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null;
    }

    Map pc = const {};
    if (cfgMap != null && cfgMap!['pc'] is Map) {
      pc = cfgMap!['pc'] as Map;
    }
    Map lpr = const {};
    if (cfgMap != null && cfgMap!['lpr'] is Map) {
      lpr = cfgMap!['lpr'] as Map;
    }

    // 優先使用 LPR IP，其次 pc.ip，再退回 device.device_ip/ip
    final hostFromLpr = (lpr['ip'] ?? '').toString().trim();
    final hostFallback = (pc['ip'] ?? device['device_ip'] ?? device['ip'] ?? '').toString().trim();
    final host = hostFromLpr.isNotEmpty ? hostFromLpr : hostFallback;

    final portRaw = pc['ssh_port'] ?? pc['port'];
    final port = portRaw == null ? 22 : (int.tryParse(portRaw.toString()) ?? 22);
    // 取得 SSH 使用者：優先 pc.user/pc.username → 退而求其次 lpr.user → 預設使用 root（可直接執行 reboot）
    String username = (pc['user'] ?? pc['username'] ?? lpr['user'] ?? 'root').toString().trim();

    // SSH 登入/ sudo 密碼：若未提供，使用預設 "ingensys"
    final sshPassword = (pc['ssh_password'] ?? pc['password'] ?? 'ingensys').toString();
    final sudoPassword = (pc['sudo_password'] ?? 'ingensys').toString();

    if (host.isEmpty) {
      _showSnack('PC IP 未設定（請於 configs.lpr.ip / configs.pc.ip / device_ip）');
      return false;
    }
    if (username.isEmpty) {
      _showSnack('PC 使用者未設定（請於 configs.pc.user）');
      return false;
    }

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 5));
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => sshPassword,
      );

      // 使用 PTY 以提高 sudo -S 相容性；不指定 term 以避免版本差異
      final isRoot = username == 'root';
      final sudoPasswordEsc = sudoPassword.replaceAll("'", "'\\''");
      final cmd = isRoot
          ? '/sbin/reboot'
          : "echo '${sudoPasswordEsc}' | sudo -S /sbin/reboot";
      final session = await client.execute(
        cmd,
        pty: const SSHPtyConfig(width: 80, height: 24),
      );
      final stdoutStr = await utf8.decodeStream(session.stdout);
      final stderrStr = await utf8.decodeStream(session.stderr);
      await session.done;
      debugPrint('[SSH] reboot stdout: ' + stdoutStr);
      if (stderrStr.isNotEmpty) debugPrint('[SSH] reboot stderr: ' + stderrStr);
      return true; // 多數情況對端會立即重啟而中斷，視為成功
    } catch (e, st) {
      debugPrint('[SSH] Reboot 失敗 (${host}:${port})：$e\n$st');
      _showSnack('電腦重開(SSH)失敗：${host}:${port} — $e');
      return false;
    } finally {
      try { client?.close(); } catch (_) {}
    }
  }

  // 以 SSH 在 APM/繳費機上執行指令；若非 root，會以 sudo -S 提權
  Future<bool> _sshRunCommandOnApm(Map<String, dynamic> device, String command) async {
    // 解析 configs：Map 或 JSON 字串
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null;
    }

    Map pc = const {};
    if (cfgMap != null && cfgMap!['pc'] is Map) {
      pc = cfgMap!['pc'] as Map;
    }
    Map lpr = const {};
    if (cfgMap != null && cfgMap!['lpr'] is Map) {
      lpr = cfgMap!['lpr'] as Map;
    }

    // APM 目標主機：優先 device.device_ip/ip，其次 pc.ip，再次 lpr.ip
    final hostPrimary = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();
    final hostFallback1 = (pc['ip'] ?? '').toString().trim();
    final hostFallback2 = (lpr['ip'] ?? '').toString().trim();
    final host = hostPrimary.isNotEmpty ? hostPrimary : (hostFallback1.isNotEmpty ? hostFallback1 : hostFallback2);

    final portRaw = pc['ssh_port'] ?? pc['port'];
    final port = portRaw == null ? 22 : (int.tryParse(portRaw.toString()) ?? 22);

    // 取得 SSH 使用者：優先 pc.user/pc.username → 退而求其次 lpr.user → 預設使用 root
    String username = (pc['user'] ?? pc['username'] ?? lpr['user'] ?? 'root').toString().trim();

    // SSH 登入/ sudo 密碼：若未提供，使用預設 "ingensys"
    final sshPassword = (pc['ssh_password'] ?? pc['password'] ?? 'ingensys').toString();
    final sudoPassword = (pc['sudo_password'] ?? 'ingensys').toString();

    if (host.isEmpty) {
      _showSnack('APM IP 未設定（請檢查 device.device_ip 或 configs.pc.ip）');
      return false;
    }

    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 5));
      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => sshPassword,
      );

      final isRoot = username == 'root';
      final sudoPasswordEsc = sudoPassword.replaceAll("'", "'\\''");
      final cmd = isRoot ? command : "echo '${sudoPasswordEsc}' | sudo -S ${command}";

      final session = await client.execute(
        cmd,
        pty: const SSHPtyConfig(width: 80, height: 24),
      );
      final stdoutStr = await utf8.decodeStream(session.stdout);
      final stderrStr = await utf8.decodeStream(session.stderr);
      await session.done;
      debugPrint('[SSH/APM] cmd: ' + command);
      if (stdoutStr.isNotEmpty) debugPrint('[SSH/APM] stdout: ' + stdoutStr);
      if (stderrStr.isNotEmpty) debugPrint('[SSH/APM] stderr: ' + stderrStr);
      return true;
    } catch (e, st) {
      debugPrint('[SSH/APM] 執行失敗 (${host}:${port})：$e\n$st');
      _showSnack('繳費機指令失敗：${host}:${port} — $e');
      return false;
    } finally {
      try { client?.close(); } catch (_) {}
    }
  }

  Future<void> _handleApmRestartWeb() async {
    if (_selectedSite == null || _selectedSite!.isEmpty) {
      _showSnack('請先選擇繳費機');
      return;
    }
    final meta = _apmLookup[_selectedSite!];
    if (meta == null) {
      _showSnack('找不到繳費機對應資訊，請重新載入');
      return;
    }

    // Double check dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('請再次確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('即將執行以下操作：'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('繳費機：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text(_selectedSite!)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('控制項目：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text('重開網頁')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('確定執行')),
        ],
      ),
    );
    if (confirmed != true) return;

    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    _showSnack('準備透過 SSH 重開網頁…');

    final ok = await _sshRunCommandOnApm(device, 'systemctl restart pms.service');
    if (ok) {
      _showSnack('已送出重開網頁指令（SSH）');
    } else {
      _showSnack('重開網頁（SSH）失敗，請檢查 IP/帳號/密碼或網路連線');
    }
  }

  Future<void> _handleApmToggleInvoice() async {
    if (_selectedSite == null || _selectedSite!.isEmpty) {
      _showSnack('請先選擇繳費機');
      return;
    }
    final meta = _apmLookup[_selectedSite!];
    if (meta == null) {
      _showSnack('找不到繳費機對應資訊，請重新載入');
      return;
    }

    // Double check dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('請再次確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('即將執行以下操作：'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('繳費機：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text(_selectedSite!)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('控制項目：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text('切換發票')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('確定執行')),
        ],
      ),
    );
    if (confirmed != true) return;

    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;

    // 準備目標主機與連接埠
    final host = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();
    // 解析 configs 以取得 APM 的 port（根層 port）
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null;
    }
    int? port;
    if (cfgMap != null) {
      final p = cfgMap['port'];
      if (p != null) port = int.tryParse(p.toString());
    }

    if (host.isEmpty || port == null) {
      _showSnack('切換發票失敗：缺少 device_ip 或 configs.port');
      return;
    }

    final url = 'http://$host:$port/device_control';
    _showSnack('準備透過 HTTP 切換發票…');
    debugPrint('[APM/Invoice] POST $url');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final body = jsonEncode({
        'operation': 'switch_printer',
        'test_print': true,
      });
      req.add(utf8.encode(body));

      final resp = await req.close();
      final code = resp.statusCode;
      final respText = await resp.transform(utf8.decoder).join();

      // 預設回傳
      bool indicator = false;
      String message = 'HTTP $code';
      try {
        final data = jsonDecode(respText);
        indicator = (data is Map && data['indicator'] == true);
        final msg = (data is Map) ? data['message'] : null;
        if (msg != null) message = msg.toString();
      } catch (_) {
        // 不是 JSON 就保留預設 message
      }

      if (indicator) {
        _showSnack('切換發票成功：' + message);
        debugPrint('[APM/Invoice] success: $message');
      } else {
        _showSnack('切換發票失敗：' + message);
        debugPrint('[APM/Invoice] fail: code=$code resp=$respText');
      }
    } catch (e, st) {
      _showSnack('切換發票失敗：$e');
      debugPrint('[APM/Invoice] exception: $e\n$st');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleApmRebootPc() async {
    if (_selectedSite == null || _selectedSite!.isEmpty) {
      _showSnack('請先選擇繳費機');
      return;
    }
    final meta = _apmLookup[_selectedSite!];
    if (meta == null) {
      _showSnack('找不到繳費機對應資訊，請重新載入');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('請再次確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('即將執行以下操作：'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('繳費機：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text(_selectedSite!)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('控制項目：', style: TextStyle(fontWeight: FontWeight.w700)),
                Expanded(child: Text('重啟電腦')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('確定執行')),
        ],
      ),
    );
    if (confirmed != true) return;

    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    _showSnack('準備透過 SSH 重啟電腦…');

    final ok = await _sshRunCommandOnApm(device, '/sbin/reboot');
    if (ok) {
      _showSnack('已送出重啟電腦指令（SSH）');
    } else {
      _showSnack('重啟電腦（SSH）失敗，請檢查 IP/帳號/密碼或網路連線');
    }
  }

  Future<void> _handlePcReboot(Map<String, dynamic> meta) async {
    /*
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;

    // 取 device_ip
    final deviceIp = (device['device_ip'] ?? device['ip'] ?? '').toString().trim();

    // 解析 configs 以取得 LPR 的 port
    dynamic cfg = device['configs'];
    Map<String, dynamic>? cfgMap;
    try {
      if (cfg is Map<String, dynamic>) {
        cfgMap = cfg;
      } else if (cfg is String && cfg.isNotEmpty) {
        cfgMap = jsonDecode(cfg) as Map<String, dynamic>;
      }
    } catch (_) {
      cfgMap = null; // 若解析失敗
    }

    int? port;
    if (cfgMap != null) {
      final lpr = cfgMap['lpr'];
      if (lpr is Map) {
        final p = lpr['port'];
        if (p != null) port = int.tryParse(p.toString());
      } else {
        // 後備：有些資料可能直接把 port 放在根
        final p = cfgMap['port'];
        if (p != null) port = int.tryParse(p.toString());
      }
    }

    if (deviceIp.isEmpty || port == null) {
      _showSnack('無法取得裝置 IP 或連接埠（PC 重開），請檢查 device_ip / configs.lpr.port');
      debugPrint('[IO] 電腦重開 失敗：deviceIp="$deviceIp" port=$port, device=${device['device_name']} siteIp=$siteIp');
      return;
    }

    final url = 'http://$deviceIp:$port/Reboot';
    debugPrint('[IO] 電腦重開 → POST $url (siteIp=$siteIp, device=${device['device_name']})');

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode('{}'));
      final resp = await req.close();
      final code = resp.statusCode;
      final respBody = await resp.transform(utf8.decoder).join();

      if (code >= 200 && code < 300) {
        _showSnack('電腦重開成功');
        debugPrint('[IO] 電腦重開 成功：$code, body=$respBody');
      } else {
        _showSnack('電腦重開失敗（$code）');
        debugPrint('[IO] 電腦重開 失敗：HTTP $code, body=$respBody');
      }
    } catch (e, st) {
      _showSnack('電腦重開失敗：$e');
      debugPrint('[IO] 電腦重開 例外：$e\n$st');
    } finally {
      client.close(force: true);
    }
    */
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    _showSnack('準備透過 SSH 重開遠端電腦…');

    final ok = await _sshSudoReboot(device);
    if (ok) {
      _showSnack('電腦重開指令已送出（SSH）');
      debugPrint('[IO] 電腦重開（SSH）已送出');
    } else {
      _showSnack('電腦重開（SSH）失敗，請檢查 IP/帳號/密碼或網路連線');
      debugPrint('[IO] 電腦重開（SSH）失敗');
    }
  }

  Future<void> _handleEmergencyOn(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] 開啟緊急模式 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    final ok = await _sendMcuCommand(device, 'AT+mcu_mode=1');
    if (ok) {
      _showSnack('已開啟緊急模式');
    } else {
      _showSnack('開啟緊急模式失敗');
    }
  }

  Future<void> _handleEmergencyOff(Map<String, dynamic> meta) async {
    final siteIp = (meta['site_ip'] ?? '').toString();
    final device = (meta['device'] ?? const {}) as Map<String, dynamic>;
    debugPrint('[IO] 關閉緊急模式 → 使用 MCU TCP (siteIp=$siteIp, device=${device['device_name']})');

    final ok = await _sendMcuCommand(device, 'AT+mcu_mode=0');
    if (ok) {
      _showSnack('已關閉緊急模式');
    } else {
      _showSnack('關閉緊急模式失敗');
    }
  }

  // 呼叫時機：initState() 裡呼叫 _fetchSiteList();
  Future<void> _fetchSiteList() async {
    // 共用連線設定（central 與各 site 相同帳密/參數）
    const dbPort = 5455; // 依你的設定
    const dbName = 'pms_db';
    const dbUser = 'pms_user';
    const dbPass = 'car%2.0nexun!';
    bool centralLoaded = false;

    // Step 1: 連到中央 DB 取站點清單（short_name, site_ip）
    final central = await Connection.open(
      Endpoint(
        host: '10.0.0.241',
        port: dbPort,
        database: dbName,
        username: dbUser,
        password: dbPass,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    final List<Map<String, String>> sites = [];
    try {
      final centralRes = await central.execute(
        'SELECT short_name, host(site_ip) AS site_ip FROM local.site_list ORDER BY site_code ASC;'
      );
      for (final row in centralRes) {
        final m = row.toColumnMap();
        final shortName = (m['short_name'] ?? '').toString();
        //final siteIp = (m['site_ip'] ?? '').toString();
        //if (shortName.isEmpty || siteIp.isEmpty) continue;
        var siteIp = (m['site_ip'] ?? '').toString().trim();
        final slashIdx = siteIp.indexOf('/');
        if (slashIdx != -1) siteIp = siteIp.substring(0, slashIdx);
        sites.add({'short_name': shortName, 'site_ip': siteIp});
      }
      centralLoaded = true; // 成功執行中央查詢
    } catch (e, st) {
      debugPrint('Central DB query error: $e\n$st');
    } finally {
      await central.close();
    }
    if (centralLoaded) {
      _showSnack('已成功取得10.0.0.241資料內容');
    }

    // Step 2: 逐站點連線撈 config.device (type = barrier)
    final List<String> allSitesShortNames = [];
    final List<String> gateLabels = [];
    final Map<String, Map<String, dynamic>> gateLookupTmp = {};
    // --- For APM devices ---
    final List<String> apmLabels = [];
    final Map<String, Map<String, dynamic>> apmLookupTmp = {};

    for (final s in sites) {
      final shortName = s['short_name']!;
      final siteIp = s['site_ip']!;
      allSitesShortNames.add(shortName);

      Connection? siteConn;
      try {
        try {
          siteConn = await Connection.open(
            Endpoint(
              host: siteIp,
              port: dbPort,
              database: dbName,
              username: dbUser,
              password: dbPass,
            ),
            settings: ConnectionSettings(sslMode: SslMode.disable),
          );
        } catch (e) {
          debugPrint('Open site DB $siteIp failed: $e');
          continue;
        }

        // 取出該站所有 barrier（柵欄機）
        try {
          final devRes = await siteConn.execute(
            "SELECT * FROM config.device WHERE type = 'barrier' ORDER BY device_name;"
          );
          for (final row in devRes) {
            final dm = row.toColumnMap();
            final deviceName = (dm['device_name'] ?? '').toString();
            if (deviceName.isEmpty) continue;
            final label = '$shortName$deviceName';
            gateLabels.add(label);
            // 存放後續控制需要的欄位（站點 IP、站名、原始 device 資料）
            gateLookupTmp[label] = {
              'site_short_name': shortName,
              'site_ip': siteIp,
              'device': dm,
            };
            debugPrint('[Gate] $label => $dm');
          }
        } catch (e, st) {
          debugPrint('Query devices from $siteIp error: $e\n$st');
        }

        // 取出該站所有 APM（繳費機）
        try {
          final apmRes = await siteConn.execute(
            "SELECT * FROM config.device WHERE type = 'apm' ORDER BY device_name;"
          );
          for (final row in apmRes) {
            final dm = row.toColumnMap();
            final deviceName = (dm['device_name'] ?? '').toString();
            if (deviceName.isEmpty) continue;
            final label = '$shortName$deviceName';
            apmLabels.add(label);
            apmLookupTmp[label] = {
              'site_short_name': shortName,
              'site_ip': siteIp,
              'device': dm,
            };
            debugPrint('[APM] $label => $dm');
          }
        } catch (e, st) {
          debugPrint('Query APM from $siteIp error: $e\n$st');
        }
        await siteConn.close();
      } catch (e, st) {
        // This catch is just in case, but open already handled above.
        debugPrint('Unexpected error for site $siteIp: $e\n$st');
        continue;
      }
    }

    // Step 3: 更新到畫面狀態
    setState(() {
      _sites = apmLabels; // 繳費機下拉顯示：{short_name}{device_name}
      _gates = gateLabels;         // 出入口改為：{short_name}{device_name}
      _gateLookup
        ..clear()
        ..addAll(gateLookupTmp);
      _apmLookup
        ..clear()
        ..addAll(apmLookupTmp);
      if (_selectedGate != null && !_gates.contains(_selectedGate)) {
        _selectedGate = null;
      }
      if (_selectedSite != null && !_sites.contains(_selectedSite)) {
        _selectedSite = null;
      }
    });
    _showSnack('已成功從資料庫取得資料並載入應用程式');
  }

  @override
  void initState() {
    super.initState();
    _fetchSiteList();
  }

  @override
  void dispose() {
    _newPwdController.dispose();
    _currentPwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 出入口控制 =====
              Center(
                child: Text(
                  '出入口控制',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '選擇出入口：',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField2<String>(
                      value: _selectedGate,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _gates
                          .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedGate = v),
                      hint: const Text('請選擇'),
                      dropdownStyleData: const DropdownStyleData(
                        maxHeight: 360, // 約 10 筆，其餘可滾動
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'IO板控制：',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: DropdownButtonFormField2<String>(
                      value: _selectedIoCtrl,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _ioOptions
                          .map((x) => DropdownMenuItem<String>(value: x, child: Text(x)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedIoCtrl = v),
                      hint: const Text('請選擇'),
                      dropdownStyleData: const DropdownStyleData(
                        maxHeight: 360,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onConfirmPressed,
                  child: const Text('確定'),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // ===== 繳費機控制 =====
              Center(
                child: Text(
                  '繳費機控制',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '選擇繳費機：',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField2<String>(
                      value: _selectedSite,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _sites
                          .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSite = v),
                      hint: const Text('請選擇'),
                      dropdownStyleData: const DropdownStyleData(
                        maxHeight: 360,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApmToggleInvoice,
                      child: const Text('切換發票'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApmRebootPc,
                      child: const Text('重啟電腦'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApmRestartWeb,
                      child: const Text('重開網頁'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用說明：',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '1.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontSize: 18),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '先選擇場地再使用功能',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '2.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontSize: 18),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '重開網頁選取場地任何一台繳費機即可',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // ===== 更改密碼機密碼 =====
              Center(
                child: Text(
                  '更改密碼機密碼',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // 輸入更改密碼： [TextField] [更改密碼]
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    child: const Text(
                      '輸入更改密碼：',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _newPwdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: '僅限數字',
                        hintStyle: const TextStyle(color: Colors.black38),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      debugPrint('更改密碼: newPwd=${_newPwdController.text}');
                    },
                    child: const Text('更改密碼'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 現有密碼： [TextField] [獲取密碼]
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    child: const Text(
                      '現有密碼：',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _currentPwdController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      // 這裡先用範例假資料，之後可接 API 後替換
                      setState(() {
                        _currentPwdController.text = '123456';
                      });
                      debugPrint('獲取密碼');
                    },
                    child: const Text('獲取密碼'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

