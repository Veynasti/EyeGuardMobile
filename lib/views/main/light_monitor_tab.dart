import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light/light.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/background_timer_manager.dart';
import '../../services/app_usage_service.dart';
import '../../controllers/app_usage_controller.dart';

class LightMonitorTab extends StatefulWidget {
  final ApiService apiService;
  final AppUsageController controller;

  const LightMonitorTab({
    super.key,
    required this.apiService,
    required this.controller,
  });

  @override
  State<LightMonitorTab> createState() => _LightMonitorTabState();
}

class _LightMonitorTabState extends State<LightMonitorTab> {
  // Sensor & State
  StreamSubscription<int>? _lightSubscription;
  int _currentLux = -1;
  bool _isEnabled = true;
  int _threshold = 20;
  int _darkSecondsToday = 0;
  int _totalUsageMinutesToday = 0;
  int _notificationInterval = 5;
  bool _isLoadingStats = false;
  Timer? _updateTimer;
  
  // Historical light readings
  List<Map<String, dynamic>> _lightHistory = [];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startLightListening();
    _syncAndFetchHistory();
    
    // Timer berkala untuk memuat ulang data SharedPreferences secara real-time
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _isEnabled) {
        _loadSettings();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _stopLightListening();
    super.dispose();
  }

  // Load Settings dari SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final int darkSecs = prefs.getInt('dark_seconds_$todayStr') ?? 0;
    
    // Total usage minutes hari ini diambil dari AppUsageController agar akurat
    final int totalMinutes = widget.controller.todayUsage?.totalMinutes ?? 0;
    
    setState(() {
      _isEnabled = prefs.getBool('light_monitoring_enabled') ?? true;
      _threshold = prefs.getInt('light_threshold_lux') ?? 20;
      _notificationInterval = prefs.getInt('light_notification_interval_minutes') ?? 5;
      _darkSecondsToday = darkSecs;
      _totalUsageMinutesToday = totalMinutes;
    });
  }

  // Helper untuk format detik ke menit agar ter-update secara instan
  String _formatToMinutes(int totalSeconds) {
    if (totalSeconds <= 0) return '0 mnt';
    final double minutes = totalSeconds / 60.0;
    if (minutes == minutes.toInt()) {
      return '${minutes.toInt()} mnt';
    }
    return '${minutes.toStringAsFixed(1)} mnt';
  }

  // Simpan Settings ke SharedPreferences & Sync Background Service
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('light_monitoring_enabled', _isEnabled);
    await prefs.setInt('light_threshold_lux', _threshold);
    await prefs.setInt('light_notification_interval_minutes', _notificationInterval);
    
    // Sync status background service
    await BackgroundTimerManager().syncServiceState();
  }

  // Memulai Listener Sensor Cahaya di Foreground
  void _startLightListening() {
    if (!_isEnabled) return;
    try {
      _lightSubscription = Light().lightSensorStream.listen((int lux) {
        setState(() {
          _currentLux = lux;
        });
      }, onError: (e) {
        debugPrint('LightMonitorTab: Error reading sensor: $e');
      });
    } catch (e) {
      debugPrint('LightMonitorTab: Sensor not available: $e');
    }
  }

  // Menghentikan Listener Sensor Cahaya
  void _stopLightListening() {
    _lightSubscription?.cancel();
    _lightSubscription = null;
  }

  // Sinkronisasi data cahaya lokal lalu ambil riwayat dari API
  Future<void> _syncAndFetchHistory() async {
    if (mounted) {
      setState(() {
        _isLoadingStats = true;
      });
    }

    try {
      // Jalankan sinkronisasi data cahaya saja (jauh lebih cepat)
      final appUsageService = AppUsageService();
      await appUsageService.syncLightReadingsOnly(widget.apiService);
    } catch (e) {
      debugPrint('Gagal sinkronisasi data cahaya dari tab: $e');
    }

    // Ambil data terbaru dari API untuk ditampilkan di grafik
    await _fetchHistoryData();
  }

  // Mengambil data riwayat sensor cahaya dari API
  Future<void> _fetchHistoryData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await widget.apiService.getLightStats(date: todayStr);
      
      if (response['status'] == 200 && response['body'] is List) {
        final List<dynamic> bodyList = response['body'];
        setState(() {
          _lightHistory = List<Map<String, dynamic>>.from(bodyList);
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat riwayat cahaya dari API: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  // Mendapatkan klasifikasi kondisi cahaya
  String _getLightCondition() {
    if (_currentLux == -1) return 'Mengkalibrasi...';
    if (_currentLux < _threshold) return 'Sangat Gelap ⚠️';
    if (_currentLux < _threshold * 2) return 'Redup 🌙';
    return 'Terang (Aman) ✨';
  }

  // Mendapatkan warna klasifikasi cahaya
  Color _getLightColor() {
    if (_currentLux == -1) return Colors.grey;
    if (_currentLux < _threshold) return const Color(0xFFEF4444); // Red
    if (_currentLux < _threshold * 2) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF10B981); // Emerald
  }

  @override
  Widget build(BuildContext context) {
    final Color lightColor = _isEnabled ? _getLightColor() : Colors.grey;
    final String lightStatus = _isEnabled ? _getLightCondition() : 'Monitoring Nonaktif';

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSettings();
        await _syncAndFetchHistory();
      },
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1E293B),
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 1. LIVE MONITOR BULB CARD
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B).withOpacity(0.9),
                  const Color(0xFF0F172A).withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Column(
              children: [
                // Glowing circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        lightColor.withOpacity(0.3),
                        lightColor.withOpacity(0.05),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                    border: Border.all(
                      color: lightColor.withOpacity(0.6),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: lightColor.withOpacity(0.25),
                        blurRadius: 25,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isEnabled 
                          ? (_currentLux < _threshold ? Icons.lightbulb_outline_rounded : Icons.lightbulb_rounded)
                          : Icons.lightbulb_outline_rounded,
                      color: lightColor,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Lux Value
                Text(
                  _isEnabled 
                      ? (_currentLux == -1 ? '-- Lux' : '$_currentLux Lux')
                      : 'OFF',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 6),
                
                // Light condition label
                Text(
                  lightStatus,
                  style: GoogleFonts.outfit(
                    color: lightColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. SETTINGS CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Switch Tile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF06B6D4)),
                        const SizedBox(width: 12),
                        Text(
                          'Monitoring Cahaya Aktif',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isEnabled,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) {
                        setState(() {
                          _isEnabled = val;
                          if (val) {
                            _startLightListening();
                          } else {
                            _stopLightListening();
                            _currentLux = -1;
                          }
                        });
                        _saveSettings();
                      },
                    ),
                  ],
                ),
                
                if (_isEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Colors.white10),
                  ),
                  
                  // Threshold Slider Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ambang Batas Lux',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$_threshold Lux',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF06B6D4),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Slider
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: const Color(0xFF334155),
                      thumbColor: const Color(0xFF10B981),
                      overlayColor: const Color(0xFF10B981).withOpacity(0.2),
                      valueIndicatorColor: const Color(0xFF1E293B),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                    ),
                    child: Slider(
                      value: _threshold.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '$_threshold Lux',
                      onChanged: (val) {
                        setState(() {
                          _threshold = val.round();
                        });
                      },
                      onChangeEnd: (val) {
                        _saveSettings();
                      },
                    ),
                  ),
                  
                  // Slider Help Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('10 Lux (Sangat Gelap)', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B))),
                      Text('100 Lux (Cahaya Redup)', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B))),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Colors.white10),
                  ),

                  // Notification Interval Slider Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Durasi Peringatan Gelap',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$_notificationInterval Menit',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF06B6D4),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Slider
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveTrackColor: const Color(0xFF334155),
                      thumbColor: const Color(0xFF10B981),
                      overlayColor: const Color(0xFF10B981).withOpacity(0.2),
                      valueIndicatorColor: const Color(0xFF1E293B),
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                    ),
                    child: Slider(
                      value: _notificationInterval.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$_notificationInterval Menit',
                      onChanged: (val) {
                        setState(() {
                          _notificationInterval = val.round();
                        });
                      },
                      onChangeEnd: (val) {
                        _saveSettings();
                      },
                    ),
                  ),

                  // Slider Help Text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 Menit', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B))),
                      Text('10 Menit', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. STATS CARDS
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'TOTAL WAKTU GELAP',
                  value: _formatToMinutes(_darkSecondsToday),
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'PERSENTASE GELAP',
                  value: _totalUsageMinutesToday > 0 
                      ? '${(((_darkSecondsToday / 60) / _totalUsageMinutesToday) * 100).round()}%'
                      : '0%',
                  icon: Icons.pie_chart_rounded,
                  iconColor: const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. CHART CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Fluktuasi Kecerahan Cahaya',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: _isLoadingStats ? null : _syncAndFetchHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  height: 180,
                  child: _isLoadingStats
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        )
                      : _lightHistory.isEmpty
                          ? _buildDummyChartPlaceholder()
                          : _buildHistoryChart(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card helper untuk statistik harian
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Grafik data nyata menggunakan fl_chart
  Widget _buildHistoryChart() {
    List<FlSpot> spots = [];
    for (int i = 0; i < _lightHistory.length; i++) {
      final double lux = double.tryParse(_lightHistory[i]['lux'].toString()) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), lux));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (val, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(
                    '${val.toInt()}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final int idx = val.toInt();
                if (idx >= 0 && idx < _lightHistory.length && (idx % (_lightHistory.length ~/ 4 + 1) == 0 || idx == _lightHistory.length - 1)) {
                  final String rawTime = _lightHistory[idx]['recorded_at'] ?? '';
                  if (rawTime.isNotEmpty) {
                    try {
                      final DateTime dt = DateTime.parse(rawTime).toLocal();
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          DateFormat('HH:mm').format(dt),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                        ),
                      );
                    } catch (_) {}
                  }
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E293B),
            tooltipBorder: BorderSide(color: Colors.white.withOpacity(0.1)),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  'Lux: ${touchedSpot.y.toInt()}',
                  GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF10B981).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tampilan Grafik Simulasi ketika data historis belum ada di server (menghindari visual kosong)
  Widget _buildDummyChartPlaceholder() {
    final List<FlSpot> dummySpots = [
      const FlSpot(0, 80),
      const FlSpot(1, 65),
      const FlSpot(2, 18),
      const FlSpot(3, 22),
      const FlSpot(4, 95),
      const FlSpot(5, 120),
      const FlSpot(6, 110),
    ];

    return Stack(
      children: [
        Opacity(
          opacity: 0.2,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      switch (val.toInt()) {
                        case 0: return SideTitleWidget(meta: meta, space: 4, child: const Text('08:00', style: TextStyle(fontSize: 8)));
                        case 2: return SideTitleWidget(meta: meta, space: 4, child: const Text('10:00', style: TextStyle(fontSize: 8)));
                        case 4: return SideTitleWidget(meta: meta, space: 4, child: const Text('12:00', style: TextStyle(fontSize: 8)));
                        case 6: return SideTitleWidget(meta: meta, space: 4, child: const Text('14:00', style: TextStyle(fontSize: 8)));
                        default: return const SizedBox();
                      }
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: dummySpots,
                  isCurved: true,
                  color: const Color(0xFF64748B),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              'Belum ada data riwayat.\nData akan muncul setelah sinkronisasi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
