import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
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
  // ۱. لینک تبلیغاتی اختصاصی شما (جایگذاری شده):
  final String adDirectLink = "https://asiafilm.org/4/052064ca4ffd0916d363a8d4ca962a64";

  // ۲. پک کانفیگ‌های V2Ray شما (جایگذاری شده به صورت Base64):
  final String initialBase64Configs =
      "dHJvamFuOi8vamNURzlXU1dNSkFtUjRydjEweHB3d0BmYXN0bHkyLmR1bm5leGEuaXI6NDQzP3R5cGU9d3Mmc2VjdXJpdHk9dGxzJnBhdGg9JTJGVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVImaG9zdD1jb3B5X2F6X2NoYW5uZWxfTlVGaUxURVJfMTdpLmdsb2JhbC5zc2wuZmFzdGx5Lm5ldC4mc25pPWNkbi5ha2FtYWkuc3RlYW1zdGF0aWMuY29tJnBpblNIQTI1Nj1jZDZlODM4YjliZmUzMWNhYjhiM2Q1Yzg1OGIwZDYyMjNmZTg0ZWNlMjM2YzFmZGIyODFiZTkzYzMwMmUxZTZlJnBjcz1jZDZlODM4YjliZmUzMWNhYjhiM2Q1Yzg1OGIwZDYyMjNmZTg0ZWNlMjM2YzFmZGIyODFiZTkzYzMwMmUxZTZlIyU0MFZwbl9TaGllbGQlMjAlN0MlMjAlRjAlOUYlOTQlQTUlMjA1ODMKCnRyb2phbjovL2pjVEc5V1NXTUpBbVI0cnYxMHhwd3dAMTk5LjIzMi43OC4xNTk6NDQzP3R5cGU9d3Mmc2VjdXJpdHk9dGxzJnBhdGg9JTJGVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVImaG9zdD1jb3B5X2F6X2NoYW5uZWxfTlVGaUxURVJfN2kuZ2xvYmFsLnNzbC5mYXN0bHkubmV0LiZzbmk9Y2RuLmFrYW1haS5zdGVhbXN0YXRpYy5jb20mcGluU0hBMjU2PWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUmcGNzPWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUjJTQwVnBuX1NoaWVsZCUyMCU3QyUyMCVGMCU5RiU5NCVBNSUyMDEyNgoKdHJvamFuOi8vamNURzlXU1dNSkFtUjRydjEweHB3d0AxOTkuMjMyLjc4LjE1OTo0NDM/dHlwZT13cyZzZWN1cml0eT10bHMmcGF0aD0lMkZURUxFR1JBTS0lNDBTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVItVEVMRUdSQU0tJTQwTlVGaUxURVImaG9zdD1jb3B5X2F6X2NoYW5uZWxfTlVGaUxURVJfNmkuZ2xvYmFsLnNzbC5mYXN0bHkubmV0LiZzbmk9Y2RuLmFrYW1haS5zdGVhbXN0YXRpYy5jb20mcGluU0hBMjU2PWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUmcGNzPWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUjJTQwVnBuX1NoaWVsZCUyMCU3QyUyMCVGMCU5RiU5NCVBNSUyMDc5NAoKdHJvamFuOi8vamNURzlXU1dNSkFtUjRydjEweHB3d0AxOTkuMjMyLjc4LjE1OTo0NDM/dHlwZT13cyZzZWN1cml0eT10bHMmcGF0aD0lMkZURUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUiZob3N0PWNvcHlfYXpfY2hhbm5lbF9OVUZpTFRFUl8xMGkuZ2xvYmFsLnNzbC5mYXN0bHkubmV0LiZzbmk9Y2RuLmFrYW1haS5zdGVhbXN0YXRpYy5jb20mcGluU0hBMjU2PWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUmcGNzPWNkNmU4MzhiOWJmZTMxY2FiOGIzZDVjODU4YjBkNjIyM2ZlODRlY2UyMzZjMWZkYjI4MWJlOTNjMzAyZTFlNmUjJTQwVnBuX1NoaWVsZCUyMCU3QyUyMCVGMCU5RiU5NCVBNSUyMDM1MQoKdHJvamFuOi8vamNURzlXU1dNSkFtUjRydjEweHB3d0AxOTkuMjMyLjc4LjE1OTo0NDM/dHlwZT13cyZzZWN1cml0eT10bHMmcGF0aD0lMkZURUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUi1URUxFR1JBTS0lNDBOVUZpTFRFUiZob3N0PWNvcHlfYXpfY2hhbm5lbF9OVUZpTFRFUl84aS5nbG9iYWwuc3NsLmZhc3RseS5uZXQuJnNuaT1jZG4uYWthbWFpLnN0ZWFtc3RhdGljLmNvbSZwaW5TSEEyNTY9Y2Q2ZTgzOGI5YmZlMzFjYWI4YjNkNWM4NThiMGQ2MjIzZmU4NGVjZTIzNmMxZmRiMjgxYmU5M2MzMDJlMWU2ZSZwY3M9Y2Q2ZTgzOGI5YmZlMzFjYWI4YjNkNWM4NThiMGQ2MjIzZmU4NGVjZTIzNmMxZmRiMjgxYmU5M2MzMDJlMWU2ZSMlNDBWcG5fU2hpZWxkJTIwJTdDJTIwJUYwJTlGJTk0JUE1JTIwOTY4";

  // ۳. لینک آپدیت خودکار سرورها از گیت‌هاب (در صورت نیاز در آینده):
  final String remoteServersUrl = "https://raw.githubusercontent.com/username/neon-vpn/main/servers.txt";

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
  int _remainingSeconds = 3600; // ۱ ساعت زمان اولیه رایگان
  Timer? _usageTimer;
  int _ping = 0;

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
    _loadConfigsFromInput(initialBase64Configs);
    _initVpn();
    _fetchRemoteServers();
  }

  Future<void> _initVpn() async {
    await _flutterV2ray.initializeV2Ray();
  }

  // استخراج هوشمند کانفیگ‌ها (هم لینک معمولی و هم کدهای Base64)
  void _loadConfigsFromInput(String rawInput) {
    String decodedText = rawInput.trim();
    if (!decodedText.contains("://")) {
      try {
        decodedText = utf8.decode(base64.decode(decodedText.replaceAll('\n', '').replaceAll(' ', '')));
      } catch (_) {}
    }

    final lines = LineSplitter.split(decodedText)
        .map((e) => e.trim())
        .where((e) =>
            e.startsWith("vless://") ||
            e.startsWith("vmess://") ||
            e.startsWith("trojan://") ||
            e.startsWith("ss://"))
        .toList();

    if (lines.isNotEmpty) {
      setState(() {
        _serverList = lines;
        _selectedServerIndex = 0;
      });
    }
  }

  Future<void> _fetchRemoteServers() async {
    try {
      final response = await http.get(Uri.parse(remoteServersUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        _loadConfigsFromInput(response.body);
      }
    } catch (_) {}
  }

  Future<void> _toggleVpn() async {
    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() => _isConnected = false);
      return;
    }

    if (_remainingSeconds <= 0) {
      _showAdRewardDialog();
      return;
    }

    if (_serverList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("هیچ سروری یافت نشد! از دکمه بالای صفحه کانفیگ وارد کنید.")),
      );
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final String activeConfig = _serverList[_selectedServerIndex];
      final V2RayURL parser = FlutterV2ray.parseFromURL(activeConfig);
      _ping = await _flutterV2ray.getServerDelay(config: parser.getFullConfiguration());

      if (await _flutterV2ray.requestPermission()) {
        await _flutterV2ray.startV2Ray(
          remark: parser.remark,
          config: parser.getFullConfiguration(),
          blockedApps: _iranianAppsBypass,
        );
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        _startCountdown();
      } else {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطا در اتصال به این سرور! سرور بعدی را از لیست انتخاب کنید.")),
      );
    }
  }

  void _startCountdown() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _flutterV2ray.stopV2Ray();
        timer.cancel();
        setState(() => _isConnected = false);
        _showAdRewardDialog();
      }
    });
  }

  // پنجره افزودن کانفیگ جدید در داخل برنامه
  void _showUpdateConfigDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        title: const Text("افزودن کانفیگ یا سابسکریپشن جدید", textAlign: TextAlign.right, style: TextStyle(fontSize: 16, color: Color(0xFF00F5D4))),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "کد Base64 یا لینک vless / trojan را اینجا پیست کنید...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("لغو")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _loadConfigsFromInput(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ ${_serverList.length} سرور با موفقیت بارگذاری شد!")),
                );
              }
            },
            child: const Text("ذخیره سرورها"),
          ),
        ],
      ),
    );
  }

  // سیستم نمایش تبلیغ و پاداش زمان (+۲ ساعت)
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // لیست انتخاب سرور (از بین ۵ سرور استخراج‌شده شما)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const SizedBox(width: 6),
                        Text(_ping > 0 ? "$_ping ms" : "Auto Ping", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        dropdownColor: const Color(0xFF161F30),
                        value: _selectedServerIndex,
                        items: List.generate(_serverList.length, (index) {
                          return DropdownMenuItem<int>(
                            value: index,
                            child: Text(
                              "⚡ سرور پرسرعت شماره ${index + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

              // دکمه مرکزی اتصال
              GestureDetector(
                onTap: _isConnecting ? null : _toggleVpn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 190,
                  height: 190,
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
                        size: 64,
                        color: _isConnected ? const Color(0xFF00F5D4) : Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isConnecting ? "در حال اتصال..." : (_isConnected ? "متصل شد" : "اتصال سریع"),
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

              // بخش تایمر و دکمه تبلیغات
              Container(
                padding: const EdgeInsets.all(20),
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
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
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

              // کارت‌های نمایش سرعت لحظه‌ای
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
