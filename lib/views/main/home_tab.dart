import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light/light.dart';
import '../../controllers/app_usage_controller.dart';
import '../../controllers/app_timer_controller.dart';
import '../../services/background_timer_manager.dart';
import '../../utils/duration_formatter.dart';

class HomeTab extends StatefulWidget {
  final AppUsageController controller;
  final AppTimerController timerController;
  final VoidCallback onViewStatsSelected;
  final VoidCallback onViewTimerSelected;
  final VoidCallback onViewLightSelected;

  const HomeTab({
    super.key,
    required this.controller,
    required this.timerController,
    required this.onViewStatsSelected,
    required this.onViewTimerSelected,
    required this.onViewLightSelected,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Sensor & Settings State
  StreamSubscription<int>? _lightSubscription;
  int _currentLux = -1;
  bool _isLightMonitoringEnabled = true;
  int _lightThreshold = 20;
  int _darkSecondsToday = 0;
  Timer? _prefsTimer;

  @override
  void initState() {
    super.initState();
    // Listen to controllers
    widget.controller.addListener(_onUsageControllerUpdate);
    widget.timerController.addListener(_onTimerControllerUpdate);
    
    // Load initial settings and start listening to light sensor
    _loadLightSettings();
    _startLightListening();

    // Periodically reload settings to capture changes from Light tab
    _prefsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isLightMonitoringEnabled) {
        _loadLightSettings();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUsageControllerUpdate);
    widget.timerController.removeListener(_onTimerControllerUpdate);
    _prefsTimer?.cancel();
    _stopLightListening();
    super.dispose();
  }

  void _onUsageControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onTimerControllerUpdate() {
    if (mounted) setState(() {});
  }

  // Load Settings from SharedPreferences
  Future<void> _loadLightSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final int darkSecs = prefs.getInt('dark_seconds_$todayStr') ?? 0;
      
      if (mounted) {
        setState(() {
          _isLightMonitoringEnabled = prefs.getBool('light_monitoring_enabled') ?? true;
          _lightThreshold = prefs.getInt('light_threshold_lux') ?? 20;
          _darkSecondsToday = darkSecs;
        });
      }
    } catch (e) {
      debugPrint('HomeTab load settings error: $e');
    }
  }

  // Start Light Listening
  void _startLightListening() {
    if (!_isLightMonitoringEnabled) return;
    try {
      _lightSubscription = Light().lightSensorStream.listen((int lux) {
        if (mounted) {
          setState(() {
            _currentLux = lux;
          });
        }
      }, onError: (e) {
        debugPrint('HomeTab light sensor stream error: $e');
      });
    } catch (e) {
      debugPrint('HomeTab light sensor not available: $e');
    }
  }

  // Stop Light Listening
  void _stopLightListening() {
    _lightSubscription?.cancel();
    _lightSubscription = null;
  }

  // Toggle Light Monitoring
  Future<void> _toggleLightMonitoring(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('light_monitoring_enabled', val);
      
      setState(() {
        _isLightMonitoringEnabled = val;
        if (val) {
          _startLightListening();
        } else {
          _stopLightListening();
          _currentLux = -1;
        }
      });
      
      // Sync background service status
      await BackgroundTimerManager().syncServiceState();
    } catch (e) {
      debugPrint('HomeTab toggle light monitoring error: $e');
    }
  }

  String _getUserName(String? token) {
    if (token == null || token.isEmpty) return 'Pengguna';
    try {
      final parts = token.split('.');
      if (parts.length < 2) return 'Pengguna';
      String normalizedSource = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalizedSource));
      final payload = jsonDecode(payloadString);
      return payload['name'] ?? payload['email']?.split('@')?.first ?? 'Pengguna';
    } catch (e) {
      return 'Pengguna';
    }
  }

  String _getLightCondition() {
    if (_currentLux == -1) return 'Mengkalibrasi...';
    if (_currentLux < _lightThreshold) return 'Sangat Gelap ⚠️';
    if (_currentLux < _lightThreshold * 2) return 'Redup 🌙';
    return 'Terang (Aman) ✨';
  }

  String _getLightConditionBrief() {
    if (_currentLux == -1) return 'Mengkalibrasi...';
    if (_currentLux < _lightThreshold) return 'Gelap';
    if (_currentLux < _lightThreshold * 2) return 'Redup';
    return 'Terang';
  }

  Color _getLightColor() {
    if (_currentLux == -1) return Colors.grey;
    if (_currentLux < _lightThreshold) return const Color(0xFFEF4444); // Red
    if (_currentLux < _lightThreshold * 2) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF10B981); // Emerald
  }

  String _formatToMinutes(int totalSeconds) {
    if (totalSeconds <= 0) return '0 mnt';
    final double minutes = totalSeconds / 60.0;
    if (minutes == minutes.toInt()) {
      return '${minutes.toInt()} mnt';
    }
    return '${minutes.toStringAsFixed(1)} mnt';
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      widget.controller.loadAllData(),
      widget.timerController.loadData(),
      _loadLightSettings(),
    ]);
  }

  int get activeTimersCount => widget.timerController.timers.where((t) => t.isActive).length;

  String get timerPreviewText {
    final activeTimers = widget.timerController.timers.where((t) => t.isActive).toList();
    if (activeTimers.isEmpty) {
      return 'Tanpa batas waktu';
    }
    if (activeTimers.length <= 2) {
      return activeTimers.map((t) => t.appName).join(', ');
    }
    final names = activeTimers.take(2).map((t) => t.appName).join(', ');
    return '$names, +${activeTimers.length - 2} lainnya';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = _getUserName(widget.controller.apiService.token);
    final todayUsage = widget.controller.todayUsage;
    final totalMinutes = todayUsage?.totalMinutes ?? 0;
    
    // Target harian: 4 jam (240 menit)
    const targetMinutes = 240;
    final double percentage = (totalMinutes / targetMinutes).clamp(0.0, 1.0);

    // Format tanggal
    final String formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    final Color lightColor = _isLightMonitoringEnabled ? _getLightColor() : Colors.grey;

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      color: const Color(0xFF10B981),
      backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          // Greeting & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $userName! 👋',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              // Refresh button
              IconButton(
                onPressed: _refreshAllData,
                icon: const Icon(Icons.sync_rounded, color: Color(0xFF10B981)),
                tooltip: 'Sinkronisasi Ulang',
              )
            ],
          ),
          const SizedBox(height: 24),

          // Main Screen Time Gauge Card (Statistik Utama)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? [
                        const Color(0xFF1E293B).withValues(alpha: 0.9),
                        const Color(0xFF0F172A).withValues(alpha: 0.6),
                      ]
                    : [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            ),
            child: Column(
              children: [
                Text(
                  'SCREEN TIME HARI INI',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                
                // Circular Gauge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 14,
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF334155).withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          totalMinutes > targetMinutes 
                              ? const Color(0xFFEF4444) // Red alert if exceeded
                              : const Color(0xFF10B981) // Emerald
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatDuration(totalMinutes),
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${formatDuration(targetMinutes)}',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      totalMinutes > targetMinutes 
                          ? Icons.warning_amber_rounded 
                          : Icons.info_outline_rounded,
                      color: totalMinutes > targetMinutes 
                          ? const Color(0xFFEF4444) 
                          : const Color(0xFF06B6D4),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        totalMinutes > targetMinutes
                            ? 'Batas penggunaan harian sehat terlewati!'
                            : 'Penggunaan layar Anda masih dalam batas aman.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: totalMinutes > targetMinutes
                              ? (theme.brightness == Brightness.dark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444))
                              : (theme.brightness == Brightness.dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: theme.dividerColor),
                GestureDetector(
                  onTap: widget.onViewStatsSelected,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lihat Analisis Statistik Lengkap',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF06B6D4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF06B6D4),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2-Column Grid Ringkasan Fitur (Cahaya & Timer)
          Row(
            children: [
              // Cahaya Card
              Expanded(
                child: GestureDetector(
                  onTap: widget.onViewLightSelected,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    height: 145,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isLightMonitoringEnabled
                            ? lightColor.withValues(alpha: 0.2)
                            : (theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.04)),
                        width: 1.5,
                      ),
                      boxShadow: theme.brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: lightColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isLightMonitoringEnabled
                                    ? (_currentLux < _lightThreshold ? Icons.lightbulb_outline_rounded : Icons.lightbulb_rounded)
                                    : Icons.lightbulb_outline_rounded,
                                color: lightColor,
                                size: 18,
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 38,
                              child: Transform.scale(
                                scale: 0.75,
                                child: Switch(
                                  value: _isLightMonitoringEnabled,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    _toggleLightMonitoring(val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Sensor Cahaya',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLightMonitoringEnabled
                              ? (_currentLux == -1 ? '-- Lux' : '$_currentLux Lux')
                              : 'OFF',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLightMonitoringEnabled
                              ? '${_getLightConditionBrief()} • ${_formatToMinutes(_darkSecondsToday)}'
                              : 'Nonaktif',
                          style: GoogleFonts.outfit(
                            color: _isLightMonitoringEnabled ? const Color(0xFF06B6D4) : theme.colorScheme.outline,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Timer Card
              Expanded(
                child: GestureDetector(
                  onTap: widget.onViewTimerSelected,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    height: 145,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: activeTimersCount > 0
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : (theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.04)),
                        width: 1.5,
                      ),
                      boxShadow: theme.brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (activeTimersCount > 0 ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.timer_rounded,
                                color: activeTimersCount > 0 ? const Color(0xFF10B981) : Colors.grey,
                                size: 18,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: theme.colorScheme.outline,
                              size: 12,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Batas Aplikasi',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeTimersCount > 0
                              ? '$activeTimersCount Aktif'
                              : 'Nonaktif',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timerPreviewText,
                          style: GoogleFonts.outfit(
                            color: activeTimersCount > 0 ? const Color(0xFF10B981) : theme.colorScheme.outline,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Top 3 Apps Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paling Sering Digunakan',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: widget.onViewStatsSelected,
                child: Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF06B6D4),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF06B6D4),
                      size: 16,
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),

          // Top Apps List
          if (todayUsage == null || todayUsage.apps.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: theme.brightness == Brightness.dark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Color(0xFF475569), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada data penggunaan hari ini.',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          ] else ...[
            ...todayUsage.apps.take(3).map((app) {
              final double appPercentage = totalMinutes > 0 
                  ? (app.durationMinutes / totalMinutes) 
                  : 0.0;
              // Generate standard color using a hash of package name
              final int hash = app.packageName.codeUnits.fold(0, (prev, elem) => prev + elem);
              final List<Color> colors = [
                const Color(0xFF3B82F6), // Blue
                const Color(0xFF10B981), // Emerald
                const Color(0xFFF59E0B), // Amber
                const Color(0xFFEC4899), // Pink
                const Color(0xFF8B5CF6), // Purple
                const Color(0xFFEF4444), // Red
              ];
              final Color appColor = colors[hash % colors.length];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                  boxShadow: theme.brightness == Brightness.dark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: Row(
                  children: [
                    // Icon Circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: app.iconBytes != null ? Colors.transparent : appColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: app.iconBytes != null
                            ? null
                            : Border.all(
                                color: appColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                      ),
                      child: app.iconBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.memory(
                                app.iconBytes!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Center(
                              child: Text(
                                app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                                style: GoogleFonts.outfit(
                                  color: appColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    
                    // App Name & Progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  app.appName,
                                  style: GoogleFonts.outfit(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatDuration(app.durationMinutes),
                                style: GoogleFonts.outfit(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: appPercentage,
                              minHeight: 6,
                              backgroundColor: theme.brightness == Brightness.dark
                                  ? const Color(0xFF334155)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(appColor),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })
          ],
        ],
      ),
    );
  }
}
