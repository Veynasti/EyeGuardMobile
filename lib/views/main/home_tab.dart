import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../controllers/app_usage_controller.dart';
import '../../utils/duration_formatter.dart';

class HomeTab extends StatelessWidget {
  final AppUsageController controller;
  final VoidCallback onViewStatsSelected;

  const HomeTab({
    super.key,
    required this.controller,
    required this.onViewStatsSelected,
  });

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

  // _formatDuration dipindahkan ke lib/utils/duration_formatter.dart

  @override
  Widget build(BuildContext context) {
    final userName = _getUserName(controller.apiService.token);
    final todayUsage = controller.todayUsage;
    final totalMinutes = todayUsage?.totalMinutes ?? 0;
    
    // Target harian: 4 jam (240 menit)
    const targetMinutes = 240;
    final double percentage = (totalMinutes / targetMinutes).clamp(0.0, 1.0);

    // Format tanggal
    final String formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () => controller.loadAllData(),
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1E293B),
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
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              // Refresh button
              IconButton(
                onPressed: () => controller.loadAllData(),
                icon: const Icon(Icons.sync_rounded, color: Color(0xFF10B981)),
                tooltip: 'Sinkronisasi Ulang',
              )
            ],
          ),
          const SizedBox(height: 28),

          // Main Screen Time Gauge Card
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
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
                Text(
                  'SCREEN TIME HARI INI',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Circular Gauge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 16,
                        backgroundColor: const Color(0xFF334155).withOpacity(0.5),
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
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Target: ${formatDuration(targetMinutes)}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                
                const SizedBox(height: 28),
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
                      size: 18,
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
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF38BDF8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Top 3 Apps Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paling Sering Digunakan',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: onViewStatsSelected,
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
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Color(0xFF475569), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada data penggunaan hari ini.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
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
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    // Icon Circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: app.iconBytes != null ? Colors.transparent : appColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: app.iconBytes != null
                            ? null
                            : Border.all(
                                color: appColor.withOpacity(0.3),
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
                                    color: Colors.white,
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
                                  color: const Color(0xFFE2E8F0),
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
                              backgroundColor: const Color(0xFF334155),
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
