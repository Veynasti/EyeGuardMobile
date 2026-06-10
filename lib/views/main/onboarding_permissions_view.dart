import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class OnboardingPermissionsView extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPermissionsView({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingPermissionsView> createState() => _OnboardingPermissionsViewState();
}

class _OnboardingPermissionsViewState extends State<OnboardingPermissionsView> with WidgetsBindingObserver {
  bool _usageGranted = false;
  bool _overlayGranted = false;
  bool _notificationsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _checking = true;
    });

    try {
      final usage = await UsageStats.checkUsagePermission() ?? false;
      final overlay = await FlutterForegroundTask.canDrawOverlays;
      final notificationStatus = await FlutterForegroundTask.checkNotificationPermission();
      final notifications = notificationStatus == NotificationPermission.granted;

      if (mounted) {
        setState(() {
          _usageGranted = usage;
          _overlayGranted = overlay;
          _notificationsGranted = notifications;
          _checking = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _requestUsagePermission() async {
    await UsageStats.grantUsagePermission();
    // Re-check after returning (done via lifecycle observer, but we do a backup check here)
    Future.delayed(const Duration(milliseconds: 500), _checkAllPermissions);
  }

  Future<void> _requestOverlayPermission() async {
    await FlutterForegroundTask.openSystemAlertWindowSettings();
    Future.delayed(const Duration(milliseconds: 500), _checkAllPermissions);
  }

  Future<void> _requestNotificationPermission() async {
    await FlutterForegroundTask.requestNotificationPermission();
    Future.delayed(const Duration(milliseconds: 500), _checkAllPermissions);
  }

  bool get _allGranted => _usageGranted && _overlayGranted && _notificationsGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [


          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        // Logo & Welcome Section
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 48,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Konfigurasi Izin Akses',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'EyeGuard membutuhkan beberapa izin penting untuk memantau kesehatan mata Anda dan membatasi screen time secara efektif.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // List of Permissions
                        _buildPermissionCard(
                          title: 'Akses Data Penggunaan',
                          description: 'Mengukur screen time harian Anda serta melacak aplikasi yang paling sering digunakan.',
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF10B981),
                          isGranted: _usageGranted,
                          onTap: _requestUsagePermission,
                        ),
                        const SizedBox(height: 16),
                        _buildPermissionCard(
                          title: 'Tampilkan di Atas Aplikasi Lain',
                          description: 'Menampilkan layar pemblokiran ketika batas waktu aplikasi yang Anda tentukan telah habis.',
                          icon: Icons.layers_rounded,
                          color: const Color(0xFF06B6D4),
                          isGranted: _overlayGranted,
                          onTap: _requestOverlayPermission,
                        ),
                        const SizedBox(height: 16),
                        _buildPermissionCard(
                          title: 'Izin Notifikasi',
                          description: 'Mengirimkan pengingat kesehatan mata secara berkala dan menjaga kestabilan sistem pemantau.',
                          icon: Icons.notifications_active_rounded,
                          color: const Color(0xFF8B5CF6),
                          isGranted: _notificationsGranted,
                          onTap: _requestNotificationPermission,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_allGranted) ...[
                        Text(
                          'Harap aktifkan semua izin di atas untuk melanjutkan.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFEF4444).withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton(
                        onPressed: _allGranted ? widget.onComplete : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.25),
                          disabledForegroundColor: Colors.white.withOpacity(0.35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Lanjutkan ke Beranda',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_checking)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  width: 32,
                  height: 32,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: isGranted
            ? [
                BoxShadow(
                  color: color.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted ? color.withOpacity(0.1) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isGranted ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isGranted ? color : const Color(0xFF64748B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Details & Action
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Text Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 14,
                            color: isGranted ? const Color(0xFF10B981) : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isGranted ? 'Aktif' : 'Belum Aktif',
                            style: GoogleFonts.outfit(
                              color: isGranted ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Request Button
                    if (!isGranted)
                      ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: color,
                          elevation: 0,
                          side: BorderSide(color: color.withOpacity(0.5), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Aktifkan',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
