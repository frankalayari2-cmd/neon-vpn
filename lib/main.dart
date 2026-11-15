import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  // ۱. لینک تبلیغاتی اختصاصی شما:
  final String adDirectLink = "https://asiafilm.org/4/052064ca4ffd0916d363a8d4ca962a64";

  // ۲. منابع خودکار سرورهای روزانه (تمرکز روی پروتکل‌های خلوت و پایدار):
  final List<String> _autoAggregatorSources = [
    "https://fastly.jsdelivr.net/gh/barry-far/V2ray-Configs@main/Sub1.txt",
    "https://fastly.jsdelivr.net/gh/barry-far/V2ray-Configs@main/Sub2.txt",
    "https://fastly.jsdelivr.net/gh/Epodonios/v2ray-configs@main/All_Configs_Sub.txt",
    "https://fastly.jsdelivr.net/gh/mahdibland/V2RayAggregator@master/sub/sub_merge.txt",
  ];

  List<String> _serverList = [
    "trojan://jcTG9WSWMJAmR4rv10xpww@fastly2.dunnexa.ir:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_17i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#Server1",
  ];

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
  int _ping = 0;
  String _statusMessage = "آماده اتصال هوشمند";

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

  Future<void> _initApp() async {
    await _flutterV2ray.initializeV2Ray();
    await _loadSavedState();
    _fetchDailyFreeServers(silent: true);
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remainingSeconds = prefs.getInt('remaining_seconds') ?? 3600;
      final savedServers = prefs.getStringList('saved_servers');
      if (savedServers != null && savedServers.isNotEmpty) {
        _serverList = savedServers;
      }
    });
  }

  Future<void> _saveRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_seconds', _remainingSeconds);
  }

  // تزریق DNSهای ضد تحریم گوگل و کلودفلر برای جلوگیری از باز نشدن سایت‌ها و تلگرام
  String _injectCleanDns(String configJson) {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(configJson);
      jsonMap['dns'] = {
        "servers": ["8.8.8.8", "1.1.1.1", "8.8.4.4"]
      };
      return jsonEncode(jsonMap);
    } catch (_) {
      return configJson;
    }
  }

  // استخراج و بُر زدن تصادفی سرورها برای جلوگیری از اتصال به سرورهای شلوغ اول لیست
  List<String> _extractValidConfigs(String rawInput) {
    String decodedText = rawInput.trim();
    if (!decodedText.contains("://")) {
      try {
        String cleanBase64 = decodedText.replaceAll(RegExp(r'\s+'), '');
        decodedText = utf8.decode(base64.decode(base64.normalize(cleanBase64)), allowMalformed: true);
      } catch (_) {}
    }

    final lines = LineSplitter.split(decodedText).map((e) => e.trim()).toList();
    // بُر زدن کل لیست تا سرورهای خلوت و جدید انتخاب شوند
    lines.shuffle(Random());

    final List<String> validConfigs = [];

    for (final line in lines) {
      // اولویت با پروتکل‌های vless و trojan که کمترین پینگ فیک را دارند
      if (line.startsWith("vless://") ||
          line.startsWith("trojan://") ||
          line.startsWith("vmess://")) {
        try {
          FlutterV2ray.parseFromURL(line);
          validConfigs.add(line);
        } catch (_) {}
      }
      if (validConfigs.length >= 35) break;
    }
    return validConfigs;
  }

  Future<void> _fetchDailyFreeServers({bool silent = false}) async {
    if (_isUpdatingServers) return;
    setState(() {
      _isUpdatingServers = true;
      _statusMessage = "در حال جستجوی سرورهای خلوت و جدید...";
    });

    List<String> fetchedConfigs = [];
    final List<String> sources = List.from(_autoAggregatorSources)..shuffle();

    for (final url in sources) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          fetchedConfigs = _extractValidConfigs(response.body);
          if (fetchedConfigs.length >= 10) {
            break;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (fetchedConfigs.isNotEmpty) {
      setState(() {
        _serverList = fetchedConfigs;
        _selectedServerIndex = 0;
      });
      await _filterAndSortRealServers(silent: silent);
    } else {
      setState(() => _statusMessage = "استفاده از سرورهای ذخیره شده");
    }

    setState(() => _isUpdatingServers = false);
  }

  // حذف سرورهای پینگ فیک و مرتب‌سازی سرورهای واقعی بر اساس سرعت
  Future<void> _filterAndSortRealServers({bool silent = false}) async {
    if (_serverList.isEmpty) return;

    setState(() => _statusMessage = "در حال حذف سرورهای فیک و تست سرعت واقعی...");

    final int testCount = _serverList.length > 20 ? 20 : _serverList.length;
    final List<MapEntry<String, int>> workingServers = [];
    final List<String> untestedServers = [];

    if (_serverList.length > testCount) {
      untestedServers.addAll(_serverList.sublist(testCount));
    }

    final List<Future<void>> tasks = [];
    for (int i = 0; i < testCount; i++) {
      final String config = _serverList[i];
      tasks.add(() async {
        try {
          final parser = FlutterV2ray.parseFromURL(config);
          final delay = await _flutterV2ray
              .getServerDelay(config: parser.getFullConfiguration())
              .timeout(const Duration(seconds: 4), onTimeout: () => -1);

          // فیلتر پینگ فیک: پینگ زیر ۶۵ میلی‌ثانیه معمولاً خطای کلودفلر محلی است و بالای ۱۲۰۰ خیلی کند است
          if (delay >= 65 && delay <= 1200) {
            workingServers.add(MapEntry(config, delay));
          }
        } catch (_) {}
      }());
    }

    await Future.wait(tasks);

    if (workingServers.isNotEmpty) {
      // مرتب‌سازی از سریع‌ترین پینگ به کندترین
      workingServers.sort((a, b) => a.value.compareTo(b.value));
      final List<String> sortedConfigs = workingServers.map((e) => e.key).toList();
      sortedConfigs.addAll(untestedServers);

      setState(() {
        _serverList = sortedConfigs;
        _selectedServerIndex = 0;
        _ping = workingServers.first.value;
        _statusMessage = "✅ ${workingServers.length} سرور پرسرعت بدون پینگ فیک آماده شد!";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_servers', sortedConfigs);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text("🚀 ${workingServers.length} سرور سالم پیدا شد! بهترین پینگ: $_ping ms"),
          ),
        );
      }
    } else {
      setState(() => _statusMessage = "آماده اتصال (${_serverList.length} سرور در لیست)");
    }
  }

  // دکمه تعویض سریع به سرور بعدی در صورت افت سرعت یا باز نشدن سایت‌ها
  Future<void> _switchToNextWorkingServer() async {
    if (_serverList.length <= 1 || _isConnecting) return;

    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() => _isConnected = false);
    }

    setState(() {
      _selectedServerIndex = (_selectedServerIndex + 1) % _serverList.length;
      _statusMessage = "در حال سوئیچ به سرور جایگزین #${_selectedServerIndex + 1}...";
    });

    await _toggleVpn();
  }

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
      await _fetchDailyFreeServers();
      if (_serverList.isEmpty) return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "در حال تست سلامت سرور و اتصال...";
    });

    if (!await _flutterV2ray.requestPermission()) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "مجوز اتصال داده نشد";
      });
      return;
    }

    bool connectedSuccess = false;
    int attempts = 0;
    int currentIndex = _selectedServerIndex;

    while (attempts < 6 && attempts < _serverList.length) {
      try {
        final String activeConfig = _serverList[currentIndex];
        final V2RayURL parser = FlutterV2ray.parseFromURL(activeConfig);
        final String cleanConfigJson = _injectCleanDns(parser.getFullConfiguration());

        final int delay = await _flutterV2ray
            .getServerDelay(config: cleanConfigJson)
            .timeout(const Duration(seconds: 4), onTimeout: () => -1);

        // اتصال فقط به سروری که پینگ واقعی (غیر فیک) می‌دهد
        if (delay >= 65 && delay <= 1400) {
          _ping = delay;
          await _flutterV2ray.startV2Ray(
            remark: "Neon VPN #${currentIndex + 1}",
            config: cleanConfigJson,
            blockedApps: _bypassApps,
          );
          setState(() {
            _selectedServerIndex = currentIndex;
            _isConnected = true;
            _isConnecting = false;
            _statusMessage = "متصل به سرور #${currentIndex + 1} (پینگ واقعی: $delay ms)";
          });
          _startCountdown();
          connectedSuccess = true;
          break;
        }
      } catch (_) {}

      attempts++;
      currentIndex = (currentIndex + 1) % _serverList.length;
      setState(() => _statusMessage = "رد کردن سرور شلوغ... تست سرور بعدی (${attempts + 1}/6)");
    }

    if (!connectedSuccess) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "سرورهای فعلی شلوغ هستند؛ در حال دریافت لیست جدید...";
      });
      await _fetchDailyFreeServers(silent: false);
    }
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

  void _showUpdateConfigDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text("افزودن کانفیگ دستی", textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Color(0xFF00F5D4))),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "لینک vless / trojan یا کد Base64 را اینجا پیست کنید...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("لغو")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
            onPressed: () async {
              final extracted = _extractValidConfigs(controller.text);
              if (extracted.isNotEmpty) {
                setState(() {
                  _serverList = extracted;
                  _selectedServerIndex = 0;
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setStringList('saved_servers', extracted);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("✅ ${extracted.length} سرور سالم بارگذاری شد!")),
                  );
                }
              }
            },
            child: const Text("ذخیره سرورها"),
          ),
        ],
      ),
    );
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
          tooltip: "یافتن سرورهای خلوت جدید",
          icon: _isUpdatingServers
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4)))
              : const Icon(Icons.sync_rounded, color: Color(0xFF00F5D4)),
          onPressed: _isUpdatingServers ? null : () => _fetchDailyFreeServers(silent: false),
        ),
        title: const Text("NEON VPN", style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4))),
        actions: [
          IconButton(
            tooltip: "افزودن کانفیگ دستی",
            icon: const Icon(Icons.paste_rounded, color: Color(0xFF00F5D4)),
            onPressed: _showUpdateConfigDialog,
          ),
        ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                            Icon(Icons.bolt, color: _ping > 0 && _ping < 500 ? Colors.greenAccent : Colors.amber),
                            const SizedBox(width: 4),
                            Text(_ping > 0 ? "$_ping ms" : "Auto", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            dropdownColor: const Color(0xFF161F30),
                            value: _selectedServerIndex < _serverList.length ? _selectedServerIndex : 0,
                            items: List.generate(_serverList.length, (index) {
                              return DropdownMenuItem<int>(
                                value: index,
                                child: Text(
                                  "⚡ سرور گلچین شده #${index + 1}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              );
                            }),
                            onChanged: _isConnected
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() => _selectedServerIndex = val);
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

              // دکمه مرکزی اتصال + دکمه تعویض سریع سرور
              Column(
                children: [
                  GestureDetector(
                    onTap: _isConnecting ? null : _toggleVpn,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
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
                            _isConnecting ? "در حال تست..." : (_isConnected ? "متصل شد" : "اتصال هوشمند"),
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
                  // دکمه نجات‌بخش برای مواقعی که سرور وسط کار قفل می‌شود
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      side: const BorderSide(color: Colors.amberAccent, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isConnecting ? null : _switchToNextWorkingServer,
                    icon: const Icon(Icons.skip_next_rounded, size: 20),
                    label: const Text("سایت باز نمی‌شود؟ تعویض سریع سرور", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              // تایمر اعتبار و دکمه تبلیغات
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
