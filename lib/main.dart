import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // ۲. منابع خودکار سرورهای رایگان روزانه (مجهز به CDN ضد فیلتر برای دانلود بدون VPN):
  final List<String> _autoAggregatorSources = [
    "https://fastly.jsdelivr.net/gh/barry-far/V2ray-Configs@main/Sub1.txt",
    "https://fastly.jsdelivr.net/gh/Epodonios/v2ray-configs@main/All_Configs_Sub.txt",
    "https://fastly.jsdelivr.net/gh/mahdibland/V2RayAggregator@master/sub/sub_merge.txt",
    "https://raw.githubusercontent.com/barry-far/V2ray-Configs/main/Sub1.txt",
    "https://raw.githubusercontent.com/yebekhe/TVC/main/subscriptions/xray/normal/mix",
  ];

  // سرورهای پشتیبان اولیه (در صورتی که کاربر در لحظه اول اینترنت بسیار ضعیفی داشته باشد):
  List<String> _serverList = [
    "trojan://jcTG9WSWMJAmR4rv10xpww@fastly2.dunnexa.ir:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_17i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#Server1",
    "trojan://jcTG9WSWMJAmR4rv10xpww@199.232.78.159:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_7i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#Server2",
    "trojan://jcTG9WSWMJAmR4rv10xpww@199.232.78.159:443?type=ws&security=tls&path=%2FTELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER-TELEGRAM-%40NUFiLTER&host=copy_az_channel_NUFiLTER_6i.global.ssl.fastly.net.&sni=cdn.akamai.steamstatic.com#Server3",
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
  String _statusMessage = "آماده اتصال";

  final List<String> _iranianAppsBypass = [
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
    // دریافت خودکار سرورهای جدید روز به محض باز شدن برنامه
    _fetchDailyFreeServers(silent: true);
  }

  // بارگذاری زمان باقی‌مانده و آخرین سرورهای سالم از حافظه گوشی
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

  // اعتبارسنجی و استخراج فقط کانفیگ‌های استاندارد و سالم
  List<String> _extractValidConfigs(String rawInput) {
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
          line.startsWith("vmess://") ||
          line.startsWith("trojan://") ||
          line.startsWith("ss://")) {
        try {
          // بررسی اینکه کانفیگ ساختار سالمی برای هسته V2Ray داشته باشد
          FlutterV2ray.parseFromURL(line);
          validConfigs.add(line);
        } catch (_) {}
      }
      if (validConfigs.length >= 40) break; // گلچین ۴۰ سرور اول برای سرعت بالا
    }
    return validConfigs;
  }

  // دریافت خودکار سرورهای روزانه از منابع عمومی
  Future<void> _fetchDailyFreeServers({bool silent = false}) async {
    if (_isUpdatingServers) return;
    setState(() {
      _isUpdatingServers = true;
      _statusMessage = "در حال دریافت سرورهای جدید روز...";
    });

    List<String> fetchedConfigs = [];

    for (final url in _autoAggregatorSources) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 7));
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          fetchedConfigs = _extractValidConfigs(response.body);
          if (fetchedConfigs.length >= 5) {
            break; // به محض دریافت لیست سالم از اولین منبع، متوقف شود
          }
        }
      } catch (_) {
        continue; // اگر منبع اول فیلتر یا قطع بود، سراغ منبع بعدی برود
      }
    }

    if (fetchedConfigs.isNotEmpty) {
      setState(() {
        _serverList = fetchedConfigs;
        _selectedServerIndex = 0;
        _statusMessage = "${fetchedConfigs.length} سرور جدید روزانه بارگذاری شد";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('saved_servers', fetchedConfigs);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text("✅ ${fetchedConfigs.length} سرور رایگان جدید با موفقیت دریافت شد!"),
          ),
        );
      }
      // تست خودکار پینگ سرورها و انتخاب سریع‌ترین سرور
      await _autoSelectFastestServer();
    } else {
      setState(() => _statusMessage = "استفاده از سرورهای ذخیره شده");
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("خطا در دریافت لیست جدید؛ لطفاً اینترنت خود را بررسی کنید.")),
        );
      }
    }

    setState(() => _isUpdatingServers = false);
  }

  // تست پینگ خودکار بین سرورهای دریافت شده و انتخاب سریع‌ترین سرور سالم
  Future<void> _autoSelectFastestServer() async {
    if (_serverList.isEmpty || _isConnected) return;

    setState(() => _statusMessage = "در حال تست پینگ و یافتن بهترین سرور...");

    final int testCount = _serverList.length > 12 ? 12 : _serverList.length;
    int bestIndex = 0;
    int bestPing = 99999;

    final List<Future<void>> tasks = [];
    for (int i = 0; i < testCount; i++) {
      final int idx = i;
      tasks.add(() async {
        try {
          final parser = FlutterV2ray.parseFromURL(_serverList[idx]);
          final delay = await _flutterV2ray
              .getServerDelay(config: parser.getFullConfiguration())
              .timeout(const Duration(seconds: 4), onTimeout: () => -1);
          if (delay > 0 && delay < bestPing) {
            bestPing = delay;
            bestIndex = idx;
          }
        } catch (_) {}
      }());
    }

    await Future.wait(tasks);

    if (bestPing < 99999) {
      setState(() {
        _selectedServerIndex = bestIndex;
        _ping = bestPing;
        _statusMessage = "بهترین سرور انتخاب شد (پینگ: $bestPing ms)";
      });
    } else {
      setState(() => _statusMessage = "آماده اتصال (${_serverList.length} سرور در لیست)");
    }
  }

  // اتصال هوشمند (اگر سرور انتخابی وصل نشد، خودکار سرورهای بعدی را تست می‌کند)
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
      _showAdRewardDialog();
      return;
    }

    if (_serverList.isEmpty) {
      await _fetchDailyFreeServers();
      if (_serverList.isEmpty) return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "در حال برقراری اتصال امن...";
    });

    if (!await _flutterV2ray.requestPermission()) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "مجوز اتصال داده نشد";
      });
      return;
    }

    // تلاش برای اتصال به سرور انتخابی (و در صورت خرابی، تست خودکار تا ۵ سرور بعدی)
    bool connectedSuccess = false;
    int attempts = 0;
    int currentIndex = _selectedServerIndex;

    while (attempts < 5 && attempts < _serverList.length) {
      try {
        final String activeConfig = _serverList[currentIndex];
        final V2RayURL parser = FlutterV2ray.parseFromURL(activeConfig);
        final int delay = await _flutterV2ray
            .getServerDelay(config: parser.getFullConfiguration())
            .timeout(const Duration(seconds: 4), onTimeout: () => -1);

        if (delay > 0 || attempts == 4) {
          _ping = delay > 0 ? delay : 0;
          await _flutterV2ray.startV2Ray(
            remark: parser.remark.isNotEmpty ? parser.remark : "Neon VPN Server",
            config: parser.getFullConfiguration(),
            blockedApps: _iranianAppsBypass,
          );
          setState(() {
            _selectedServerIndex = currentIndex;
            _isConnected = true;
            _isConnecting = false;
            _statusMessage = "متصل به سرور شماره ${currentIndex + 1}";
          });
          _startCountdown();
          connectedSuccess = true;
          break;
        }
      } catch (_) {}

      attempts++;
      currentIndex = (currentIndex + 1) % _serverList.length;
      setState(() => _statusMessage = "تست خودکار سرور جایگزین (${attempts + 1}/5)...");
    }

    if (!connectedSuccess) {
      setState(() {
        _isConnecting = false;
        _statusMessage = "نیاز به بروزرسانی سرورها (دکمه 🔄 بالا را بزنید)";
      });
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
        _showAdRewardDialog();
      }
    });
  }

  void _showUpdateConfigDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text("افزودن کانفیگ یا لینک سابسکریپشن", textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Color(0xFF00F5D4))),
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

  void _showAdRewardDialog() {
    int adCountdown = 15;
    bool adOpened = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161F30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("🎁 دریافت ۲ ساعت اینترنت آزاد", textAlign: TextAlign.right, style: TextStyle(fontSize: 18, color: Color(0xFF00F5D4))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "برای تأمین هزینه سرورهای پرسرعت، روی دکمه زیر بزنید، صفحه اسپانسر را ۱۵ ثانیه مشاهده کنید و ۲ ساعت زمان رایگان بگیرید.",
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  if (adOpened)
                    Text(
                      adCountdown > 0 ? "لطفاً $adCountdown ثانیه صبر کنید..." : "✅ زمان شما اضافه شد!",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("بستن", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F5D4),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: adOpened
                      ? null
                      : () async {
                          setModalState(() => adOpened = true);
                          await launchUrl(Uri.parse(adDirectLink), mode: LaunchMode.externalApplication);

                          Timer.periodic(const Duration(seconds: 1), (timer) {
                            if (adCountdown > 1) {
                              setModalState(() => adCountdown--);
                            } else {
                              timer.cancel();
                              setState(() => _remainingSeconds += 7200);
                              _saveRemainingTime();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text("🎉 ۲ ساعت به زمان اتصال شما اضافه شد!"),
                                ),
                              );
                            }
                          });
                        },
                  child: const Text("مشاهده تبلیغ (+۲ ساعت)", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
          tooltip: "دریافت خودکار سرورهای جدید روز",
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // باکس انتخاب سرور و وضعیت بروزرسانی خودکار
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
                            Icon(Icons.bolt, color: _ping > 0 && _ping < 400 ? Colors.greenAccent : Colors.amber),
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
                                  "⚡ سرور هوشمند روزانه #${index + 1}",
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
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // دکمه مرکزی نئونی اتصال
              GestureDetector(
                onTap: _isConnecting ? null : _toggleVpn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 185,
                  height: 185,
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
                        size: 60,
                        color: _isConnected ? const Color(0xFF00F5D4) : Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isConnecting ? "در حال تست..." : (_isConnected ? "متصل شد" : "اتصال هوشمند"),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? const Color(0xFF00F5D4) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // تایمر اعتبار و دکمه تبلیغات
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF161F30), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text("زمان باقی‌مانده اتصال رایگان", style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F5D4),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _showAdRewardDialog,
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text("افزایش زمان رایگان (+۲ ساعت)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),

              // نمایش سرعت دانلود و آپلود زنده
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
