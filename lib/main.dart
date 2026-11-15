import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const NeonVpnApp());
}

class NeonVpnApp extends StatelessWidget {
  const NeonVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF00F5D4),
      ),
      home: const VpnHomeScreen(),
    );
  }
}

class VpnHomeScreen extends StatefulWidget {
  const VpnHomeScreen({super.key});

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen> {
  // لینک تبلیغاتی شما:
  final String adDirectLink = "https://asiafilm.org/4/052064ca4ffd0916d363a8d4ca962a64";

  // لینک‌های دریافت خودکار فایل servers.txt از گیت‌هاب شما (به همراه آینه‌های ضد فیلتر):
  final List<String> myGithubServerUrls = [
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/main/servers.txt",
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/refs/heads/main/servers.txt",
    "https://gcore.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
    "https://testingcf.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
    "https://fastly.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
  ];

  List<String> _serverList = [];
  int _selectedServerIndex = 0;

  late final FlutterV2ray _flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      setState(() {
        _v2rayStatus = status;
      });
    },
  );

  V2RayStatus _v2rayStatus = V2RayStatus();
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isUpdatingServers = false;
  int _remainingSeconds = 3600;
  Timer? _usageTimer;
  Timer? _autoRefreshTimer;
  int _ping = 0;
  String _statusMessage = "در حال دریافت خودکار سرورها...";

  final List<String> _bypassApps = [
    "com.neonvpn.app",
    "ir.divar",
    "cab.snapp.passenger",
    "com.sibche.aspardproject.app",
    "ir.nasim",
    "ir.eitaa.messenger",
    "ir.resaneh1.iptv",
  ];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _flutterV2ray.initializeV2Ray();
    await _loadSavedState();
    await _syncServersFromGithub(silent: true);

    // بروزرسانی خودکار لیست سرورها در پس‌زمینه هر ۳۰ دقیقه
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!_isConnected && !_isConnecting) {
        _syncServersFromGithub(silent: true);
      }
    });
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remainingSeconds = prefs.getInt('remaining_seconds') ?? 3600;
      final savedAll = prefs.getStringList('auto_cf_servers_v7');
      if (savedAll != null && savedAll.isNotEmpty) {
        _serverList = savedAll;
      }
    });
  }

  Future<void> _saveRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_seconds', _remainingSeconds);
  }

  List<String> _extractAndCleanConfigs(String rawInput) {
    String decodedText = rawInput.trim();
    if (!decodedText.contains("://")) {
      try {
        String cleanBase64 = decodedText.replaceAll(RegExp(r'\s+'), '');
        decodedText = utf8.decode(base64.decode(base64.normalize(cleanBase64)), allowMalformed: true);
      } catch (_) {}
    }

    final lines = LineSplitter.split(decodedText).map((e) => e.trim()).toList();
    final List<String> validConfigs = [];

    for (final line in lines) {
      if (line.startsWith("vless://") ||
          line.startsWith("trojan://") ||
          line.startsWith("vmess://") ||
          line.startsWith("ss://")) {
        try {
          final String basePart = line.split('#').first.trim();
          final String cleanLine = "$basePart#CF-Server-${validConfigs.length + 1}";
          FlutterV2ray.parseFromURL(cleanLine);
          validConfigs.add(cleanLine);
        } catch (_) {}
      }
      if (validConfigs.length >= 40) break;
    }
    return validConfigs;
  }

  String _buildUnlockedConfigJson(String rawConfigUrl) {
    final V2RayURL parser = FlutterV2ray.parseFromURL(rawConfigUrl);
    final String rawJson = parser.getFullConfiguration();

    try {
      final Map<String, dynamic> config = jsonDecode(rawJson);
      config['dns'] = {
        "servers": ["8.8.8.8", "1.1.1.1", "8.8.4.4"]
      };

      if (config['outbounds'] is List && (config['outbounds'] as List).isNotEmpty) {
        for (var outbound in config['outbounds']) {
          if (outbound is Map && outbound['streamSettings'] is Map) {
            final stream = outbound['streamSettings'];
            if (stream['tlsSettings'] is Map) {
              stream['tlsSettings']['allowInsecure'] = true;
            }
            if (stream['sockopt'] == null) {
              stream['sockopt'] = {"tcpFastOpen": true};
            }
          }
        }
      }
      return jsonEncode(config);
    } catch (_) {
      return rawJson;
    }
  }

  // دریافت خودکار سرورها از فایل servers.txt گیت‌هاب شما
  Future<void> _syncServersFromGithub({bool silent = false}) async {
    if (_isUpdatingServers) return;
    setState(() {
      _isUpdatingServers = true;
      _statusMessage = "در حال بروزرسانی خودکار سرورهای کلودفلر از گیت‌هاب...";
    });

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    List<String> fetchedServers = [];

    for (final baseUrl in myGithubServerUrls) {
      try {
        final response = await http.get(
          Uri.parse("$baseUrl?nocache=$timestamp"),
          headers: {"Cache-Control": "no-cache, no-store, must-revalidate"},
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          final extracted = _extractAndCleanConfigs(response.body);
          if (extracted.length > fetchedServers.length) {
            fetchedServers = extracted;
          }
          if (fetchedServers.length >= 10) break;
        }
      } catch (_) {
        continue;
      }
    }

    if (fetchedServers.isNotEmpty) {
      setState(() {
        _serverList = fetchedServers;
        _selectedServerIndex = 0;
        _isUpdatingServers = false;
        _statusMessage = "✅ ${fetchedServers.length} سرور کلودفلر به صورت خودکار دریافت شد";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('auto_cf_servers_v7', fetchedServers);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text("🚀 ${fetchedServers.length} سرور جدید به صورت خودکار آپدیت شد!"),
          ),
        );
      }
    } else {
      setState(() {
        _isUpdatingServers = false;
        _statusMessage = _serverList.isNotEmpty
            ? "آماده اتصال (${_serverList.length} سرور ذخیره شده)"
            : "در انتظار اتصال اینترنت برای دریافت سرورها...";
      });
    }
  }

  // اتصال ۱۰۰٪ خودکار: تست ترتیبی سرورها تا پیدا کردن اولین سرور پاسخ‌گو
  Future<void> _toggleVpn() async {
    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() {
        _isConnected = false;
        _statusMessage = "اتصال قطع شد";
      });
      return;
    }

    if (_remainingSeconds <= 0) {
      _openInAppAdScreen();
      return;
    }

    if (_serverList.isEmpty) {
      await _syncServersFromGithub(silent: false);
      if (_serverList.isEmpty) return;
    }

    if (!await _flutterV2ray.requestPermission()) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "مجوز اتصال VPN داده نشد";
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "جستجوی خودکار بهترین سرور کلودفلر...";
    });

    int workingIndex = _selectedServerIndex;
    int verifiedPing = 0;
    String workingConfigJson = "";

    // بررسی خودکار تا ۱۰ سرور برای یافتن سروری که روی اینترنت فعلی کاربر پینگ واقعی بدهد
    final int maxChecks = _serverList.length < 10 ? _serverList.length : 10;
    for (int i = 0; i < maxChecks; i++) {
      final int candidateIndex = (_selectedServerIndex + i) % _serverList.length;
      setState(() {
        _statusMessage = "تست خودکار سرور #${candidateIndex + 1}...";
      });

      try {
        final String candidateJson = _buildUnlockedConfigJson(_serverList[candidateIndex]);
        final int delay = await _flutterV2ray
            .getServerDelay(config: candidateJson)
            .timeout(const Duration(seconds: 3), onTimeout: () => -1);

        if (delay > 0 && delay < 1500) {
          workingIndex = candidateIndex;
          verifiedPing = delay;
          workingConfigJson = candidateJson;
          break;
        }
      } catch (_) {}
    }

    // اگر پینگ اولیه مسدود بود، با همان سرور انتخابی مستقیماً تونل را باز کن
    if (workingConfigJson.isEmpty) {
      workingConfigJson = _buildUnlockedConfigJson(_serverList[_selectedServerIndex]);
    }

    try {
      await _flutterV2ray.startV2Ray(
        remark: "Neon VPN #${workingIndex + 1}",
        config: workingConfigJson,
        blockedApps: _bypassApps,
      );

      setState(() {
        _selectedServerIndex = workingIndex;
        _ping = verifiedPing;
        _isConnected = true;
        _isConnecting = false;
        _statusMessage = verifiedPing > 0
            ? "⚡ متصل به سرور #${workingIndex + 1} (پینگ: $verifiedPing ms)"
            : "⚡ متصل به سرور #${workingIndex + 1}";
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "خطا در اتصال؛ در حال دریافت لیست جدید...";
      });
      await _syncServersFromGithub(silent: false);
    }
  }

  Future<void> _switchToNextWorkingServer() async {
    if (_serverList.isEmpty || _isConnecting) return;

    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() => _isConnected = false);
    }

    setState(() {
      _selectedServerIndex = (_selectedServerIndex + 1) % _serverList.length;
      _ping = 0;
    });

    await _toggleVpn();
  }

  void _startCountdown() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds % 10 == 0) _saveRemainingTime();
      } else {
        _flutterV2ray.stopV2Ray();
        timer.cancel();
        setState(() => _isConnected = false);
        _saveRemainingTime();
        _openInAppAdScreen();
      }
    });
  }

  Future<void> _openInAppAdScreen() async {
    bool wasConnected = _isConnected;
    if (wasConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() {
        _isConnected = false;
        _statusMessage = "توقف موقت برای بارگذاری تبلیغ...";
      });
    }

    if (!mounted) return;

    final bool? rewarded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InAppAdScreen(adUrl: adDirectLink),
      ),
    );

    if (rewarded == true) {
      setState(() {
        _remainingSeconds += 7200;
        _statusMessage = "۲ ساعت زمان رایگان اضافه شد!";
      });
      await _saveRemainingTime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("🎉 تبریک! ۲ ساعت به زمان اتصال شما اضافه شد."),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("⚠️ تبلیغ را کامل مشاهده نکردید؛ زمانی اضافه نشد."),
          ),
        );
      }
    }
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: "آپدیت فوری سرورها",
          icon: _isUpdatingServers
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4)))
              : const Icon(Icons.sync_rounded, color: Color(0xFF00F5D4)),
          onPressed: _isUpdatingServers ? null : () => _syncServersFromGithub(silent: false),
        ),
        title: const Text("NEON VPN", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4))),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt, color: _ping > 0 ? Colors.greenAccent : Colors.amber),
                            const SizedBox(width: 4),
                            Text(_ping > 0 ? "$_ping ms" : "Auto", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            dropdownColor: const Color(0xFF161F30),
                            value: _selectedServerIndex < _serverList.length ? _selectedServerIndex : 0,
                            items: _serverList.isEmpty
                                ? [
                                    const DropdownMenuItem<int>(
                                      value: 0,
                                      child: Text("در حال دریافت خودکار سرورها...", style: TextStyle(fontSize: 13)),
                                    )
                                  ]
                                : List.generate(_serverList.length, (index) {
                                    return DropdownMenuItem<int>(
                                      value: index,
                                      child: Text(
                                        "☁️ سرور اتوماتیک کلودفلر #${index + 1} (از ${_serverList.length})",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF00F5D4),
                                        ),
                                      ),
                                    );
                                  }),
                            onChanged: _isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedServerIndex = val;
                                        _ping = 0;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: _isConnecting ? null : _toggleVpn,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 175,
                      height: 175,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF161F30),
                        boxShadow: [
                          BoxShadow(
                            color: _isConnected
                                ? const Color(0xFF00F5D4).withOpacity(0.5)
                                : (_isConnecting ? Colors.amber.withOpacity(0.4) : Colors.blueGrey.withOpacity(0.2)),
                            blurRadius: 35,
                            spreadRadius: 8,
                          ),
                        ],
                        border: Border.all(
                          color: _isConnected ? const Color(0xFF00F5D4) : (_isConnecting ? Colors.amber : Colors.white24),
                          width: 4,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.power_settings_new_rounded,
                            size: 56,
                            color: _isConnected ? const Color(0xFF00F5D4) : Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isConnecting ? "جستجوی خودکار..." : (_isConnected ? "متصل شد" : "اتصال اتوماتیک"),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isConnected ? const Color(0xFF00F5D4) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      side: const BorderSide(color: Colors.amberAccent, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isConnecting ? null : _switchToNextWorkingServer,
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                    label: const Text("تعویض خودکار به سرور بعدی ⏭️", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF161F30), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text("زمان باقی‌مانده اتصال رایگان", style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F5D4),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _openInAppAdScreen,
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text("افزایش زمان رایگان (+۲ ساعت)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSpeedCard("دانلود", "${(_v2rayStatus.downloadSpeed / 1024).toStringAsFixed(1)} KB/s", Icons.arrow_downward_rounded, Colors.greenAccent),
                  _buildSpeedCard("آپلود", "${(_v2rayStatus.uploadSpeed / 1024).toStringAsFixed(1)} KB/s", Icons.arrow_upward_rounded, Colors.cyanAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedCard(String title, String speed, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(speed, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class InAppAdScreen extends StatefulWidget {
  final String adUrl;
  const InAppAdScreen({super.key, required this.adUrl});

  @override
  State<InAppAdScreen> createState() => _InAppAdScreenState();
}

class _InAppAdScreenState extends State<InAppAdScreen> {
  late final WebViewController _controller;
  int _secondsLeft = 15;
  bool _adLoaded = false;
  bool _timerStarted = false;
  bool _hasProxyError = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0F19))
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            try {
              final Object result = await _controller.runJavaScriptReturningResult("document.body.innerText");
              final String bodyText = result.toString();
              if (bodyText.contains("Anonymous Proxy")) {
                setState(() {
                  _hasProxyError = true;
                  _adLoaded = false;
                });
                _countdownTimer?.cancel();
                return;
              }
            } catch (_) {}

            if (!_timerStarted) {
              setState(() {
                _adLoaded = true;
                _hasProxyError = false;
                _timerStarted = true;
              });
              _startAdTimer();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.adUrl));
  }

  void _startAdTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<bool> _handleBackPress() async {
    if (_secondsLeft == 0) {
      Navigator.pop(context, true);
      return false;
    }

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text("⚠️ لغو دریافت زمان رایگان؟", textAlign: TextAlign.right, style: TextStyle(color: Colors.amber, fontSize: 17)),
        content: Text(
          "هنوز $_secondsLeft ثانیه از تماشای تبلیغ باقی مانده است. اگر الان خارج شوید، ۲ ساعت زمان رایگان دریافت نمی‌کنید.",
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("خروج بدون جایزه", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ادامه تماشای تبلیغ"),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.pop(context, false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF161F30),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleBackPress,
          ),
          title: Text(
            _hasProxyError
                ? "⚠️ فیلترشکن دیگر گوشی را خاموش کنید"
                : (!_adLoaded
                    ? "⏳ در حال بارگذاری تبلیغ..."
                    : (_secondsLeft > 0 ? "⏱ $_secondsLeft ثانیه در این صفحه بمانید" : "✅ جایزه آماده دریافت است!")),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_secondsLeft == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("دریافت +۲ ساعت", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _adLoaded ? (15 - _secondsLeft) / 15 : null,
              backgroundColor: Colors.white12,
              color: const Color(0xFF00F5D4),
            ),
          ),
        ),
        body: _hasProxyError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.vpn_lock_rounded, size: 64, color: Colors.amber),
                      const SizedBox(height: 16),
                      const Text(
                        "خطای تشخیص فیلترشکن (Anonymous Proxy)",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "شبکه تبلیغاتی اجازه نمایش تبلیغ با آی‌پی فیلترشکن را نمی‌دهد. لطفاً اگر فیلترشکن دیگری روی گوشی شما روشن است آن را خاموش کنید و دکمه تلاش مجدد را بزنید.",
                        style: TextStyle(color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
                        onPressed: () {
                          setState(() => _hasProxyError = false);
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("تلاش مجدد با اینترنت عادی"),
                      ),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
