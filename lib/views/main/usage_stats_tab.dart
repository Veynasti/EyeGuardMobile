import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/app_usage_controller.dart';
import '../../models/app_usage_model.dart';
import '../../utils/duration_formatter.dart';

class UsageStatsTab extends StatefulWidget {
  final AppUsageController controller;

  const UsageStatsTab({super.key, required this.controller});

  @override
  State<UsageStatsTab> createState() => _UsageStatsTabState();
}

class _UsageStatsTabState extends State<UsageStatsTab> {
  bool _isWeeklySelected = false;

  // _formatDuration dipindahkan ke lib/utils/duration_formatter.dart

  String _getIndonesianDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Sen';
      case DateTime.tuesday: return 'Sel';
      case DateTime.wednesday: return 'Rab';
      case DateTime.thursday: return 'Kam';
      case DateTime.friday: return 'Jum';
      case DateTime.saturday: return 'Sab';
      case DateTime.sunday: return 'Min';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayUsage = widget.controller.todayUsage;
    final weeklyUsage = widget.controller.weeklyUsage;

    // Hitung data untuk tab hari ini
    final int todayTotalMinutes = todayUsage?.totalMinutes ?? 0;
    final List<AppUsageInfo> todayApps = todayUsage?.apps ?? [];

    // Hitung data untuk tab mingguan (agregasi)
    int weeklyTotalMinutes = 0;
    Map<String, AppUsageInfo> aggregatedApps = {};
    for (var day in weeklyUsage) {
      weeklyTotalMinutes += day.totalMinutes;
      for (var app in day.apps) {
        if (aggregatedApps.containsKey(app.packageName)) {
          final existing = aggregatedApps[app.packageName]!;
          aggregatedApps[app.packageName] = AppUsageInfo(
            packageName: app.packageName,
            appName: app.appName,
            durationMinutes: existing.durationMinutes + app.durationMinutes,
            lastUsed: app.lastUsed.isAfter(existing.lastUsed) ? app.lastUsed : existing.lastUsed,
            iconBytes: app.iconBytes,
          );
        } else {
          aggregatedApps[app.packageName] = AppUsageInfo(
            packageName: app.packageName,
            appName: app.appName,
            durationMinutes: app.durationMinutes,
            lastUsed: app.lastUsed,
            iconBytes: app.iconBytes,
          );
        }
      }
    }
    final List<AppUsageInfo> weeklyApps = aggregatedApps.values.toList();
    weeklyApps.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

    // Nilai ringkasan saat ini berdasarkan pilihan toggle
    final int displayTotalMinutes = _isWeeklySelected ? weeklyTotalMinutes : todayTotalMinutes;
    final List<AppUsageInfo> displayApps = _isWeeklySelected ? weeklyApps : todayApps;
    final int displayAppCount = displayApps.length;
    final AppUsageInfo? mostUsedApp = displayApps.isNotEmpty ? displayApps.first : null;
    final String displayMostUsedApp = mostUsedApp != null ? mostUsedApp.appName : '-';
    final Uint8List? mostUsedAppIconBytes = mostUsedApp?.iconBytes;

    return RefreshIndicator(
      onRefresh: () => widget.controller.loadAllData(),
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1E293B),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          // Period Selector Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isWeeklySelected = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isWeeklySelected ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Hari Ini',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: !_isWeeklySelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isWeeklySelected = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isWeeklySelected ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Minggu Ini',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: _isWeeklySelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Weekly Chart (Hanya tampil jika tab Minggu Ini dipilih)
          if (_isWeeklySelected) ...[
            Text(
              'Statistik Mingguan',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.only(top: 16, right: 16, left: 0, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: weeklyUsage.isEmpty
                  ? Center(
                      child: Text(
                        'Memuat data chart...',
                        style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _calculateMaxY(weeklyUsage),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF1E293B),
                            tooltipBorder: BorderSide(color: Colors.white.withOpacity(0.1)),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final dayData = weeklyUsage[groupIndex];
                              return BarTooltipItem(
                                '${_getIndonesianDayName(dayData.date)}\n',
                                GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: formatDuration(rod.toY.toInt()),
                                    style: const TextStyle(
                                      color: Color(0xFF06B6D4),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < weeklyUsage.length) {
                                  final dayData = weeklyUsage[index];
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: Text(
                                      _getIndonesianDayName(dayData.date),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(weeklyUsage.length, (index) {
                          final dayData = weeklyUsage[index];
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: dayData.totalMinutes.toDouble(),
                                color: const Color(0xFF06B6D4),
                                width: 14,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ],

          // Summary Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'TOTAL WAKTU LAYAR',
                  value: formatDuration(displayTotalMinutes),
                  icon: Icons.hourglass_empty_rounded,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: _isWeeklySelected ? 'RATA-RATA HARIAN' : 'APLIKASI DIBUKA',
                  value: _isWeeklySelected
                      ? formatDuration(weeklyUsage.isNotEmpty ? weeklyTotalMinutes ~/ weeklyUsage.length : 0)
                      : '$displayAppCount Aplikasi',
                  icon: _isWeeklySelected ? Icons.analytics_rounded : Icons.apps_rounded,
                  iconColor: const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            title: 'APLIKASI TERLAMA',
            value: displayMostUsedApp,
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            isFullWidth: true,
            iconBytes: mostUsedAppIconBytes,
          ),
          const SizedBox(height: 28),

          // App List Section
          Text(
            _isWeeklySelected ? 'Penggunaan Aplikasi Minggu Ini' : 'Penggunaan Aplikasi Hari Ini',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (displayApps.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Center(
                child: Text(
                  'Tidak ada data statistik.',
                  style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                ),
              ),
            )
          ] else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayApps.length,
              itemBuilder: (context, index) {
                final app = displayApps[index];
                final double percentage = displayTotalMinutes > 0
                    ? (app.durationMinutes / displayTotalMinutes)
                    : 0.0;
                
                final int hash = app.packageName.codeUnits.fold(0, (prev, elem) => prev + elem);
                final List<Color> colors = [
                  const Color(0xFF3B82F6),
                  const Color(0xFF10B981),
                  const Color(0xFFF59E0B),
                  const Color(0xFFEC4899),
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEF4444),
                ];
                final Color appColor = colors[hash % colors.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: app.iconBytes != null ? Colors.transparent : appColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: app.iconBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.memory(
                                  app.iconBytes!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Center(
                                child: Text(
                                  app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(
                                    color: appColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
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
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  formatDuration(app.durationMinutes),
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFE2E8F0),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 4,
                                backgroundColor: const Color(0xFF1E293B),
                                valueColor: AlwaysStoppedAnimation<Color>(appColor),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          ],
        ],
      ),
    );
  }

  double _calculateMaxY(List<DailyUsageData> usage) {
    double max = 60.0; // default minimum
    for (var u in usage) {
      if (u.totalMinutes > max) {
        max = u.totalMinutes.toDouble();
      }
    }
    return max * 1.25; // add 25% padding
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool isFullWidth = false,
    Uint8List? iconBytes,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: iconBytes != null ? EdgeInsets.zero : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBytes != null ? Colors.transparent : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      iconBytes,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(icon, color: iconColor, size: 20),
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
                    letterSpacing: 1.0,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
