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
  // ۱. لینک تبلیغاتی اختصاصی شما:
  final String adDirectLink = "https://asiafilm.org/4/052064ca4ffd0916d363a8d4ca962a64";

  // ۲. لینک‌های مستقیم و ضد فیلتر فایل servers.txt گیت‌هاب شما (frankalayari2-cmd):
  final List<String> myAdminServerUrls = [
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/refs/heads/main/servers.txt",
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/main/servers.txt",
    "https://fastly.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
    "https://gcore.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
  ];

  // ۳. سرورهای پشتیبان اولیه (برای زمان نصب اولیه در صورت قطعی کامل اینترنت):
  final List<String> _fallbackFastServers = [
    "trojan://jcTG9WSWMJAmR4rv10xpww@fastly2.dunnexa.ir:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_17i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#VIP-1",
    "trojan://jcTG9WSWMJAmR4rv10xpww@199.232.78.159:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_7i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#VIP-2",
    "trojan://jcTG9WSWMJAmR4rv10xpww@199.232.78.159:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_6i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#VIP-3",
  ];

  // ۴. منابع خودکار کمکی روزانه (در کنار سرورهای اختصاصی شما):
  final List<String> _iranOptimizedSources = [
    "https://fastly.jsdelivr.net/gh/yebekhe/TVC@main/subscriptions/xray/normal/reality",
    "https://fastly.jsdelivr.net/gh/barry-far/V2ray-Configs@main/Sub1.txt",
  ];

  List<String> _adminServers = [];
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
  int _ping = 0;
  String _statusMessage = "آماده اتصال فوری";

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
    _adminServers = List.from(_fallbackFastServers);
    _serverList = List.from(_fallbackFastServers);
    _initApp();
  }

  Future<void> _initApp() async {
    await _flutterV2ray.initializeV2Ray();
    await _loadSavedState();
    _syncAllServers(silent: true);
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remainingSeconds = prefs.getInt('remaining_seconds') ?? 3600;
      final savedAdmin = prefs.getStringList('admin_servers_v5');
      final savedAll = prefs.getStringList('all_servers_v5');
      if (savedAdmin != null && savedAdmin.isNotEmpty) {
        _adminServers = savedAdmin;
      }
      if (savedAll != null && savedAll.isNotEmpty) {
        _serverList = savedAll;
      }
    });
  }

  Future<void> _saveRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_seconds', _remainingSeconds);
  }

  List<String> _extractConfigs(String rawInput, {bool filterForAuto = false}) {
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
        final bool passesFilter = !filterForAuto ||
            line.contains("security=reality") ||
            line.contains("type=ws") ||
            line.contains("type=grpc");

        if (passesFilter) {
          try {
            FlutterV2ray.parseFromURL(line);
            validConfigs.add(line);
          } catch (_) {}
        }
      }
      if (validConfigs.length >= 30) break;
    }
    return validConfigs;
  }

  // دریافت آنی سرورهای فایل servers.txt شما + سرورهای کمکی روزانه
  Future<void> _syncAllServers({bool silent = false}) async {
    if (_isUpdatingServers) return;
    setState(() {
      _isUpdatingServers = true;
      if (!silent) _statusMessage = "در حال دریافت سرورهای جدید از گیت‌هاب شما...";
    });

    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    List<String> fetchedAdminServers = [];

    // ۱. تلاش برای دریافت فایل servers.txt شما از لینک اصلی و آینه‌های CDN
    for (final baseUrl in myAdminServerUrls) {
      try {
        final response = await http.get(
          Uri.parse("$baseUrl?t=$timestamp"),
          headers: {"Cache-Control": "no-cache"},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          fetchedAdminServers = _extractConfigs(response.body, filterForAuto: false);
          if (fetchedAdminServers.isNotEmpty) break;
        }
      } catch (_) {
        continue;
      }
    }

    if (fetchedAdminServers.isNotEmpty) {
      _adminServers = fetchedAdminServers;
    } else if (_adminServers.isEmpty) {
      _adminServers = List.from(_fallbackFastServers);
    }

    // ۲. دریافت سرورهای کمکی روزانه
    List<String> extraAutoServers = [];
    for (final url in _iranOptimizedSources) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          extraAutoServers.addAll(_extractConfigs(response.body, filterForAuto: true));
          if (extraAutoServers.length >= 12) break;
        }
      } catch (_) {
        continue;
      }
    }

    final List<String> combined = [
      ..._adminServers,
      ...extraAutoServers.take(12),
    ];

    setState(() {
      _serverList = combined;
      if (_selectedServerIndex >= _serverList.length) {
        _selectedServerIndex = 0;
      }
      _isUpdatingServers = false;
      _statusMessage = fetchedAdminServers.isNotEmpty
          ? "✅ ${fetchedAdminServers.length} سرور اختصاصی شما + سرورهای روزانه آپدیت شد"
          : "✅ لیست سرورها بروزرسانی شد (${_serverList.length} سرور آماده)";
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('admin_servers_v5', _adminServers);
    await prefs.setStringList('all_servers_v5', _serverList);

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text("🚀 ${ _adminServers.length} سرور ویژه از فایل servers.txt شما دریافت شد!"),
        ),
      );
    }
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
      _serverList = List.from(_fallbackFastServers);
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "در حال اتصال فوری به سرور #${_selectedServerIndex + 1}...";
    });

    try {
      final String activeConfig = _serverList[_selectedServerIndex];
      final V2RayURL parser = FlutterV2ray.parseFromURL(activeConfig);

      if (await _flutterV2ray.requestPermission()) {
        await _flutterV2ray.startV2Ray(
          remark: "Neon VPN #${_selectedServerIndex + 1}",
          config: parser.getFullConfiguration(),
          blockedApps: _bypassApps,
        );

        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _statusMessage = "⚡ متصل به سرور #${_selectedServerIndex + 1}";
        });
        _startCountdown();

        _flutterV2ray
            .getServerDelay(config: parser.getFullConfiguration())
            .timeout(const Duration(seconds: 4), onTimeout: () => 0)
            .then((delay) {
          if (mounted && delay > 0) {
            setState(() => _ping = delay);
          }
        });
      } else {
        setState(() {
          _isConnecting = false;
          _statusMessage = "مجوز اتصال VPN داده نشد";
        });
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "خطا در این سرور؛ دکمه تعویض سریع سرور را بزنید";
      });
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

  void _showUpdateConfigDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text("افزودن کانفیگ دستی", textAlign: TextAlign.right, style: TextStyle(fontSize: 15, color: Color(0xFF00F5D4))),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "لینک vless / trojan یا کد Base64 جدید را اینجا پیست کنید...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("بستن", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
            onPressed: () async {
              final extracted = _extractConfigs(controller.text, filterForAuto: false);
              if (extracted.isNotEmpty) {
                setState(() {
                  _serverList = [...extracted, ..._serverList];
                  _selectedServerIndex = 0;
                  _statusMessage = "${extracted.length} سرور دستی در صدر لیست قرار گرفت";
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("افزودن به صدر لیست"),
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
          tooltip: "دریافت آخرین سرورها از فایل servers.txt شما",
          icon: _isUpdatingServers
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4)))
              : const Icon(Icons.sync_rounded, color: Color(0xFF00F5D4)),
          onPressed: _isUpdatingServers ? null : () => _syncAllServers(silent: false),
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
                            Icon(Icons.bolt, color: _isConnected ? Colors.greenAccent : Colors.amber),
                            const SizedBox(width: 4),
                            Text(_ping > 0 ? "$_ping ms" : "Fast", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            dropdownColor: const Color(0xFF161F30),
                            value: _selectedServerIndex < _serverList.length ? _selectedServerIndex : 0,
                            items: List.generate(_serverList.length, (index) {
                              final bool isAdminServer = index < _adminServers.length;
                              return DropdownMenuItem<int>(
                                value: index,
                                child: Text(
                                  isAdminServer
                                      ? "👑 سرور ویژه مدیریت #${index + 1}"
                                      : "⚡ سرور اتوماتیک روزانه #${index + 1}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isAdminServer ? const Color(0xFF00F5D4) : Colors.white,
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
                            _isConnecting ? "در حال اتصال..." : (_isConnected ? "متصل شد" : "اتصال فوری"),
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
                    label: const Text("تعویض فوری به سرور بعدی ⏭️", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
