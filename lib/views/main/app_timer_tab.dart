import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../controllers/app_timer_controller.dart';
import '../../models/app_timer_model.dart';
import '../../services/app_timer_service.dart';
import '../../utils/duration_formatter.dart';

class AppTimerTab extends StatefulWidget {
  final AppTimerController controller;

  const AppTimerTab({super.key, required this.controller});

  @override
  State<AppTimerTab> createState() => _AppTimerTabState();
}

class _AppTimerTabState extends State<AppTimerTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    // Dengarkan perubahan dari controller agar UI rebuild
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      debugPrint('Gagal meminta izin notifikasi: $e');
    }
  }

  List<AppInfo> get _filteredApps {
    final apps = widget.controller.installedApps;
    if (_searchQuery.isEmpty) return apps;
    return apps
        .where((app) => app.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Future<void> _showTimePickerDialog(AppInfo app, AppTimerModel? existingTimer) async {
    // Cek izin overlay terlebih dahulu sebelum mengizinkan penambahan timer
    final timerService = AppTimerService();
    bool hasOverlay = await timerService.checkOverlayPermission();
    if (!hasOverlay) {
      _showOverlayPermissionDialog(timerService);
      return;
    }

    int initialHours = 0;
    int initialMinutes = 30;

    if (existingTimer != null) {
      initialHours = existingTimer.limitMinutes ~/ 60;
      initialMinutes = existingTimer.limitMinutes % 60;
    }

    int selectedHours = initialHours;
    int selectedMinutes = initialMinutes;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              app.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        app.icon!,
                        width: 32,
                        height: 32,
                      ),
                    )
                  : const Icon(Icons.android, color: Color(0xFF10B981)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  existingTimer != null ? 'Edit Timer' : 'Tambah Timer',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setel batas waktu harian untuk ${app.name}:',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hours Selector
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Jam',
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF10B981)),
                            onPressed: () {
                              if (selectedHours < 23) {
                                setDialogState(() => selectedHours++);
                              }
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              selectedHours.toString().padLeft(2, '0'),
                              style: GoogleFonts.outfit(
                                color: theme.colorScheme.onSurface,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF10B981)),
                            onPressed: () {
                              if (selectedHours > 0) {
                                setDialogState(() => selectedHours--);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Text(
                        ':',
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurface,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Minutes Selector
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Menit',
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF10B981)),
                            onPressed: () {
                              if (selectedMinutes < 59) {
                                setDialogState(() => selectedMinutes++);
                              }
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              selectedMinutes.toString().padLeft(2, '0'),
                              style: GoogleFonts.outfit(
                                color: theme.colorScheme.onSurface,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF10B981)),
                            onPressed: () {
                              if (selectedMinutes > 0) {
                                setDialogState(() => selectedMinutes--);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (existingTimer != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await widget.controller.deleteTimer(app.packageName);
                },
                child: Text(
                  'Hapus',
                  style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                int totalMinutes = (selectedHours * 60) + selectedMinutes;
                if (totalMinutes == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Batas waktu minimal harus lebih dari 0.',
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                await widget.controller.saveTimer(
                  packageName: app.packageName,
                  appName: app.name,
                  limitMinutes: totalMinutes,
                  isActive: existingTimer?.isActive ?? true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Simpan',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOverlayPermissionDialog(AppTimerService timerService) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          title: Text(
            'Izin Overlay Diperlukan',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Untuk menampilkan modal pemblokiran layar ketika batas waktu aplikasi habis, EyeGuard memerlukan izin untuk ditampilkan di atas aplikasi lain.',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await timerService.requestOverlayPermission();
                Future.delayed(const Duration(seconds: 2), () {
                  widget.controller.loadData();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Buka Pengaturan',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
        ),
      );
    }

    final filtered = _filteredApps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Section Header
          Text(
            'Batas Waktu Aplikasi',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tetapkan batas harian agar tidak berlebihan menggunakan aplikasi.',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                hintStyle: GoogleFonts.outfit(color: theme.colorScheme.outline),
                prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.outline),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Aplikasi Pihak Ketiga',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (ctrl.isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    // Capture messenger sebelum await agar tidak ada async gap issue
                    final messenger = ScaffoldMessenger.of(context);
                    await ctrl.refresh();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Daftar aplikasi berhasil diperbarui',
                            style: GoogleFonts.outfit(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1),
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: 'Sinkronisasi Aplikasi',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refresh,
              color: const Color(0xFF10B981),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Text(
                              'Tidak ada aplikasi ditemukan.',
                              style: GoogleFonts.outfit(color: theme.colorScheme.outline),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (context, index) {
                        final app = filtered[index];
                        final timer = ctrl.getTimerForPackage(app.packageName);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: timer != null && timer.isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : (isDark
                                      ? Colors.transparent
                                      : Colors.black.withValues(alpha: 0.04)),
                              width: 1,
                            ),
                            boxShadow: isDark
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
                              // App Icon
                              app.icon != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        app.icon!,
                                        width: 48,
                                        height: 48,
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.android, color: Color(0xFF10B981)),
                                    ),
                              const SizedBox(width: 16),
                              // App Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timer != null
                                          ? 'Batas: ${formatDurationLong(timer.limitMinutes)}'
                                          : 'Tanpa batas waktu',
                                      style: GoogleFonts.outfit(
                                        color: timer != null && timer.isActive
                                            ? const Color(0xFF10B981)
                                            : theme.colorScheme.outline,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action: Switch + Edit atau Add Time
                              if (timer != null) ...[
                                Switch(
                                  value: timer.isActive,
                                  activeThumbColor: const Color(0xFF10B981),
                                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  inactiveThumbColor: const Color(0xFF64748B),
                                  inactiveTrackColor: isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.06),
                                  onChanged: (val) => ctrl.toggleTimerActive(timer, val),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF06B6D4)),
                                  onPressed: () => _showTimePickerDialog(app, timer),
                                ),
                              ] else ...[
                                ElevatedButton(
                                  onPressed: () => _showTimePickerDialog(app, null),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    foregroundColor: const Color(0xFF10B981),
                                    elevation: 0,
                                    side: const BorderSide(color: Color(0xFF10B981), width: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Tambah',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
