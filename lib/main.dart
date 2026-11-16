import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
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
        scaffoldBackgroundColor: const Color(0xFF070A12),
        primaryColor: const Color(0xFF00F5D4),
      ),
      home: const NeonSplashScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// صفحه اسپلش اسکرین با انیمیشن بالارفتن خطوط بنفش و ساخت کلمه NEON
// ---------------------------------------------------------------------------
class NeonSplashScreen extends StatefulWidget {
  const NeonSplashScreen({super.key});

  @override
  State<NeonSplashScreen> createState() => _NeonSplashScreenState();
}

class _NeonSplashScreenState extends State<NeonSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animUp;
  late Animation<double> _animGlow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _animUp = Tween<double>(begin: 120.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _animGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();

    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const VpnHomeScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animUp.value),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9B5DE5).withOpacity(_animGlow.value * 0.7),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_moon_rounded, size: 68, color: Color(0xFF9B5DE5)),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFF9B5DE5),
                        const Color(0xFFC77DFF),
                        Colors.white.withOpacity(_animGlow.value.clamp(0.2, 1.0)),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      "NEON",
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "SECURE TUNNEL",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 4,
                      color: Colors.white.withOpacity(_animGlow.value * 0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// صفحه اصلی اپلیکیشن VPN
// ---------------------------------------------------------------------------
class VpnHomeScreen extends StatefulWidget {
  const VpnHomeScreen({super.key});

  @override
  State<VpnHomeScreen> createState() => _VpnHomeScreenState();
}

class _VpnHomeScreenState extends State<VpnHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final String adDirectLink = "https://asiafilm.org/4/052064ca4ffd0916d363a8d4ca962a64";

  final List<String> myGithubServerUrls = [
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/main/servers.txt",
    "https://raw.githubusercontent.com/frankalayari2-cmd/neon-vpn/refs/heads/main/servers.txt",
    "https://gcore.jsdelivr.net/gh/frankalayari2-cmd/neon-vpn@main/servers.txt",
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
  int _remainingSeconds = 1800; // پیش‌فرض ۳۰ دقیقه
  Timer? _usageTimer;
  Timer? _autoRefreshTimer;
  int _ping = 0;
  String _statusSubtext = "Ready to connect";

  final List<String> _bypassApps = [
    "com.neonvpn.app",
    "ir.divar",
    "cab.snapp.passenger",
    "ir.nasim",
    "ir.eitaa.messenger",
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

    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!_isConnected && !_isConnecting) {
        _syncServersFromGithub(silent: true);
      }
    });
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remainingSeconds = prefs.getInt('remaining_seconds_v3') ?? 1800;
      final savedAll = prefs.getStringList('auto_cf_servers_v9');
      if (savedAll != null && savedAll.isNotEmpty) {
        _serverList = savedAll;
      }
    });
  }

  Future<void> _saveRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_seconds_v3', _remainingSeconds);
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
          final String cleanLine = "$basePart#Server-${validConfigs.length + 1}";
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

  Future<void> _syncServersFromGithub({bool silent = false}) async {
    if (_isUpdatingServers) return;
    setState(() {
      _isUpdatingServers = true;
      _statusSubtext = "Syncing cloud nodes...";
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
        _statusSubtext = "${fetchedServers.length} Fast Nodes Ready";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('auto_cf_servers_v9', fetchedServers);

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00B4D8),
            content: Text("⚡ Updated ${fetchedServers.length} fast servers!"),
          ),
        );
      }
    } else {
      setState(() {
        _isUpdatingServers = false;
        _statusSubtext = _serverList.isNotEmpty
            ? "${_serverList.length} Cached Nodes Ready"
            : "Tap sync icon to load nodes";
      });
    }
  }

  Future<void> _toggleVpn() async {
    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() {
        _isConnected = false;
        _ping = 0;
        _statusSubtext = "Disconnected";
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
        _statusSubtext = "VPN permission denied";
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusSubtext = "Finding fastest node...";
    });

    int workingIndex = _selectedServerIndex;
    int verifiedPing = 0;
    String workingConfigJson = "";

    final int maxChecks = _serverList.length < 10 ? _serverList.length : 10;
    for (int i = 0; i < maxChecks; i++) {
      final int candidateIndex = (_selectedServerIndex + i) % _serverList.length;
      setState(() {
        _statusSubtext = "Testing Node #${candidateIndex + 1}...";
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
        _statusSubtext = verifiedPing > 0
            ? "Node #${workingIndex + 1} • $verifiedPing ms"
            : "Node #${workingIndex + 1} Active";
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusSubtext = "Connection failed. Retrying...";
      });
      await _syncServersFromGithub(silent: false);
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
    if (_isConnected) {
      await _flutterV2ray.stopV2Ray();
      _usageTimer?.cancel();
      setState(() {
        _isConnected = false;
        _statusSubtext = "Paused for sponsor ad...";
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
        _remainingSeconds += 1800; // افزودن دقیقاً ۳۰ دقیقه (۱۸۰۰ ثانیه)
        _statusSubtext = "+30 Mins Free Time Added!";
      });
      await _saveRemainingTime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("🎉 +30 Mins added to your free session!"),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("⚠️ Ad closed early. Please watch for 15s to unlock free time."),
          ),
        );
      }
    }
  }

  void _showServerPickerModal() {
    if (_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Disconnect first to change server.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 45,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "Select High-Speed Node",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4)),
                ),
              ),
              Flexible(
                child: _serverList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("Loading nodes..."),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _serverList.length,
                        itemBuilder: (context, index) {
                          final bool isSelected = index == _selectedServerIndex;
                          return ListTile(
                            leading: Icon(
                              Icons.flag_circle_rounded,
                              color: isSelected ? const Color(0xFF00F5D4) : Colors.white54,
                              size: 28,
                            ),
                            title: Text(
                              "Neon Cloud Node #${index + 1}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF00F5D4) : Colors.white,
                              ),
                            ),
                            subtitle: const Text("Optimized VLESS / TLS", style: TextStyle(fontSize: 12, color: Colors.white54)),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00F5D4))
                                : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                            onTap: () {
                              setState(() {
                                _selectedServerIndex = index;
                                _ping = 0;
                              });
                              Navigator.pop(context);
                              _toggleVpn();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF00F5D4))),
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

  Widget _buildParallelNeonBars({required bool isLeft}) {
    final List<double> widths = isLeft ? [26, 42, 58, 42, 26] : [26, 42, 58, 42, 26];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: List.generate(widths.length, (i) {
        final Color barColor = _isConnected
            ? (i.isEven ? const Color(0xFF00F5D4) : const Color(0xFF00BBF9))
            : (_isConnecting ? Colors.amber.withOpacity(0.7) : const Color(0xFF1B2438));

        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (i * 70)),
          margin: const EdgeInsets.symmetric(vertical: 5),
          width: widths[i],
          height: 4.5,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: _isConnected
                ? [
                    BoxShadow(
                      color: barColor.withOpacity(0.9),
                      blurRadius: 12,
                      spreadRadius: 1.5,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }

  Widget _buildHorizontalParallelLines() {
    return Column(
      children: List.generate(3, (index) {
        final double widthFactor = index == 0 ? 0.75 : (index == 1 ? 0.55 : 0.35);
        final Color lineColor = _isConnected
            ? (index == 1 ? const Color(0xFF9B5DE5) : const Color(0xFF00F5D4))
            : (_isConnecting ? Colors.amber.withOpacity(0.5) : const Color(0xFF1A2235));

        return AnimatedContainer(
          duration: Duration(milliseconds: 350 + (index * 100)),
          margin: const EdgeInsets.symmetric(vertical: 3.5),
          height: 3,
          width: MediaQuery.of(context).size.width * widthFactor,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: _isConnected
                ? [
                    BoxShadow(
                      color: lineColor.withOpacity(0.85),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildNeonDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E1422),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _isConnected ? const Color(0xFF00F5D4).withOpacity(0.4) : Colors.white10,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isConnected ? const Color(0xFF00F5D4).withOpacity(0.12) : Colors.black54,
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 250,
                      margin: const EdgeInsets.only(bottom: 75),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF141E33), Color(0xFF0B101D)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                          bottomLeft: Radius.circular(48),
                          bottomRight: Radius.circular(48),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: _isConnected ? const Color(0xFF00F5D4) : const Color(0xFF1E293B),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white38, width: 1.4),
                                    ),
                                    child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Sync Nodes",
                                  icon: _isUpdatingServers
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4)),
                                        )
                                      : const Icon(Icons.sync_rounded, color: Color(0xFF00F5D4)),
                                  onPressed: _isUpdatingServers ? null : () => _syncServersFromGithub(silent: false),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0E1422),
                              boxShadow: [
                                BoxShadow(
                                  color: _isConnected
                                      ? const Color(0xFF00F5D4).withOpacity(0.5)
                                      : const Color(0xFF9B5DE5).withOpacity(0.25),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF9B5DE5)],
                              ).createShader(bounds),
                              child: const Icon(Icons.shield_moon_rounded, size: 42, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF9B5DE5)],
                            ).createShader(bounds),
                            child: const Text(
                              "Neon VPN",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildParallelNeonBars(isLeft: true),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: _isConnecting ? null : _toggleVpn,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: 156,
                              height: 156,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0B0F19),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isConnected
                                        ? const Color(0xFF00F5D4).withOpacity(0.6)
                                        : (_isConnecting ? Colors.amber.withOpacity(0.4) : Colors.black87),
                                    blurRadius: 30,
                                    spreadRadius: _isConnected ? 6 : 2,
                                  ),
                                ],
                                border: Border.all(
                                  color: _isConnected
                                      ? const Color(0xFF00F5D4)
                                      : (_isConnecting ? Colors.amber : const Color(0xFF26334D)),
                                  width: 5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 64,
                                    color: _isConnected
                                        ? const Color(0xFF00F5D4)
                                        : (_isConnecting ? Colors.amber : Colors.white70),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isConnecting
                                        ? "WAIT..."
                                        : (_isConnected ? "CONNECTED" : "LET'S GO"),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: _isConnected ? const Color(0xFF00F5D4) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          _buildParallelNeonBars(isLeft: false),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildHorizontalParallelLines(),
                Column(
                  children: [
                    Text(
                      _isConnected ? "Connected" : (_isConnecting ? "Connecting..." : "Not Connected"),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? const Color(0xFF00F5D4) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusSubtext,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0),
                  child: InkWell(
                    onTap: _showServerPickerModal,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141D30),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isConnected ? const Color(0xFF00F5D4).withOpacity(0.5) : Colors.white12,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isConnected ? const Color(0xFF00F5D4).withOpacity(0.2) : Colors.white10,
                            ),
                            child: Icon(
                              Icons.outlined_flag_rounded,
                              color: _isConnected ? const Color(0xFF00F5D4) : Colors.white70,
                              size: 20,
                            ),
                          ),
                          Text(
                            _serverList.isEmpty
                                ? "Connect To Node"
                                : "Connect To Node (#${_selectedServerIndex + 1})",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white38, width: 1.2),
                            ),
                            child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("FREE SESSION TIME", style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(_remainingSeconds),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F5D4),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _openInAppAdScreen,
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                          label: const Text("Add +30 Mins", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNeonDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0E1422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 55, bottom: 35),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF18243E), Color(0xFF0B101D)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF00F5D4), width: 1.5),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0E1422),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F5D4).withOpacity(0.4),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF9B5DE5)],
                    ).createShader(bounds),
                    child: const Icon(Icons.shield_moon_rounded, size: 54, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00F5D4), Color(0xFF00BBF9), Color(0xFF9B5DE5)],
                  ).createShader(bounds),
                  child: const Text(
                    "Neon VPN",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildDrawerItem(
            icon: Icons.home_outlined,
            title: "Home",
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.verified_user_outlined,
            title: "Privacy Policy",
            onTap: () {
              Navigator.pop(context);
              _showInfoDialog(
                "Privacy Policy",
                "Neon VPN strictly follows a zero-log policy. We do not track, store, or share your browsing activity, DNS queries, or connection timestamps.",
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.share_outlined,
            title: "Share To Friends",
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(
                const ClipboardData(
                  text: "Download Neon VPN - Fast, Free & Secure V2Ray VPN: https://github.com/frankalayari2-cmd/neon-vpn/releases",
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF00B4D8),
                  content: Text("✅ Share link copied to clipboard!"),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.person_outline_rounded,
            title: "About Us",
            onTap: () {
              Navigator.pop(context);
              _showInfoDialog(
                "About Neon VPN",
                "Version 2.1.0 (Google Play Edition)\n\nPowered by Xray-Core & Cloudflare Edge Nodes for high-speed, encrypted access worldwide.",
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      leading: Icon(icon, color: const Color(0xFF00F5D4), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      onTap: onTap,
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
        title: const Text("⚠️ Cancel Free Reward?", style: TextStyle(color: Colors.amber, fontSize: 17)),
        content: Text(
          "Please stay on this sponsor page for $_secondsLeft more seconds to unlock +30 minutes of free VPN access.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Exit Anyway", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Continue Watching"),
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
                ? "⚠️ Disable Other VPNs"
                : (!_adLoaded
                    ? "⏳ Loading Sponsor Ad..."
                    : (_secondsLeft > 0 ? "⏱ Wait $_secondsLeft seconds..." : "✅ Reward Unlocked!")),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_secondsLeft == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Claim +30 Mins", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        "Anonymous Proxy Detected",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Please turn off any background VPN or proxy on your phone and tap Retry so the sponsor page can load.",
                        style: TextStyle(color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5D4), foregroundColor: Colors.black),
                        onPressed: () => _controller.reload(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
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
