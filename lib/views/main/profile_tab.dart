import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  final ApiService apiService;

  const ProfileTab({super.key, required this.apiService});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.apiService.getProfile();
      if (result['status'] == 200) {
        setState(() {
          _profileData = result['body'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['body']['error'] ?? 'Gagal memuat data profil';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan koneksi internet';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('d MMMM yyyy', 'id_ID').format(dateTime);
    } catch (_) {
      return '-';
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final nameController = TextEditingController(text: _profileData?['name']);
        final currentPasswordController = TextEditingController();
        final newPasswordController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool isUpdating = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              title: Text(
                'Edit Data Akun',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Input Nama
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                        decoration: _buildInputDecoration(
                          label: 'Nama Lengkap',
                          hint: 'Masukkan nama baru',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Divider(color: theme.dividerColor, height: 24),
                      
                      Text(
                        'Ganti Kata Sandi (Opsional)',
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Input Password Baru
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                        decoration: _buildInputDecoration(
                          label: 'Password Baru',
                          hint: 'Min 8 karakter, A, a, 1',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: theme.colorScheme.outline,
                            ),
                            onPressed: () => setStateDialog(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            if (currentPasswordController.text.isEmpty) {
                              return 'Password saat ini wajib diisi';
                            }
                            final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
                            if (!passwordRegex.hasMatch(val)) {
                              return 'Min 8 karakter (huruf besar, kecil, angka)';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input Password Saat Ini
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                        decoration: _buildInputDecoration(
                          label: 'Password Saat Ini',
                          hint: 'Wajib jika ganti password',
                          icon: Icons.vpn_key_outlined,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: theme.colorScheme.outline,
                            ),
                            onPressed: () => setStateDialog(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        validator: (val) {
                          if (newPasswordController.text.isNotEmpty && (val == null || val.isEmpty)) {
                            return 'Password saat ini diperlukan';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.outline,
                  ),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setStateDialog(() {
                              isUpdating = true;
                              dialogError = null;
                            });
                            try {
                              final res = await widget.apiService.updateProfile(
                                name: nameController.text,
                                currentPassword: currentPasswordController.text.isNotEmpty
                                    ? currentPasswordController.text
                                    : null,
                                newPassword: newPasswordController.text.isNotEmpty
                                    ? newPasswordController.text
                                    : null,
                              );
                              if (res['status'] == 200) {
                                if (!dialogContext.mounted) return;
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Profil berhasil diperbarui',
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
                                _fetchProfile();
                              } else {
                                setStateDialog(() {
                                  dialogError = res['body']['error'] ?? 'Gagal memperbarui profil';
                                  isUpdating = false;
                                });
                              }
                            } catch (e) {
                              setStateDialog(() {
                                dialogError = 'Kesalahan koneksi internet';
                                  isUpdating = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 8),
              Text(
                'Keluar Akun',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun EyeGuard Anda?',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.outline,
              ),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Tutup dialog
                await widget.apiService.clearToken();
                if (!mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Berhasil keluar dari akun.',
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final passwordController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        bool obscurePassword = true;
        bool isDeleting = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Hapus Akun',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Apakah Anda yakin ingin menghapus akun Anda secara permanen? Semua data sensor cahaya, durasi penggunaan aplikasi, statistik harian, dan informasi profil Anda akan terhapus sepenuhnya dari sistem dan tidak dapat dipulihkan.',
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: GoogleFonts.outfit(color: theme.colorScheme.onSurface),
                        decoration: _buildInputDecoration(
                          label: 'Password Anda',
                          hint: 'Masukkan password saat ini',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: theme.colorScheme.outline,
                            ),
                            onPressed: () => setStateDialog(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.outline,
                  ),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setStateDialog(() {
                              isDeleting = true;
                              dialogError = null;
                            });
                            try {
                              final res = await widget.apiService.deleteAccount(passwordController.text);
                              if (res['status'] == 200) {
                                if (!dialogContext.mounted) return;
                                Navigator.of(dialogContext).popUntil((route) => route.isFirst);
                                await widget.apiService.clearToken();
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Akun berhasil dihapus permanen',
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
                              } else {
                                setStateDialog(() {
                                  dialogError = res['body']['error'] ?? 'Gagal menghapus akun';
                                  isDeleting = false;
                                });
                              }
                            } catch (e) {
                              setStateDialog(() {
                                dialogError = 'Kesalahan koneksi internet';
                                isDeleting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Hapus Permanen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        fontSize: 14,
      ),
      hintText: hint,
      hintStyle: GoogleFonts.outfit(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF10B981), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  /// Mengembalikan label teks tema aktif saat ini.
  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Tema Terang';
      case ThemeMode.dark:
        return 'Tema Gelap';
      default:
        return 'Mengikuti Sistem HP';
    }
  }

  /// Menampilkan dialog pemilihan tema yang mengubah UI secara langsung (real-time).
  void _showThemeDialog(BuildContext context) {
    final currentMode = MyApp.of(context).themeMode;
    showDialog(
      context: context,
      builder: (dialogContext) {
        ThemeMode selectedMode = currentMode;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.palette_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Tema Aplikasi',
                    style: GoogleFonts.outfit(
                      color: Theme.of(ctx).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildThemeOptionTile(
                    context: ctx,
                    label: 'Mengikuti Sistem HP',
                    subtitle: 'Otomatis menyesuaikan tema perangkat',
                    icon: Icons.phone_android_rounded,
                    mode: ThemeMode.system,
                    currentMode: selectedMode,
                    onChanged: (val) => setDialogState(() => selectedMode = val!),
                  ),
                  _buildThemeOptionTile(
                    context: ctx,
                    label: 'Tema Terang',
                    subtitle: 'Tampilan putih dan cerah',
                    icon: Icons.wb_sunny_rounded,
                    mode: ThemeMode.light,
                    currentMode: selectedMode,
                    onChanged: (val) => setDialogState(() => selectedMode = val!),
                  ),
                  _buildThemeOptionTile(
                    context: ctx,
                    label: 'Tema Gelap',
                    subtitle: 'Tampilan gelap, nyaman di malam hari',
                    icon: Icons.dark_mode_rounded,
                    mode: ThemeMode.dark,
                    currentMode: selectedMode,
                    onChanged: (val) => setDialogState(() => selectedMode = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Terapkan tema secara real-time tanpa restart
                    MyApp.of(context).setThemeMode(selectedMode);
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Terapkan',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Widget satu baris pilihan tema di dalam dialog.
  Widget _buildThemeOptionTile({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    final bool isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF10B981)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
        ),
      );
    }

    if (_errorMessage != null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: theme.colorScheme.onSurface, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchProfile,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final name = _profileData?['name'] ?? 'Pengguna';
    final email = _profileData?['email'] ?? '-';
    final createdAt = _profileData?['created_at'];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Profile Info Header Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF1E293B).withValues(alpha: 0.9),
                      const Color(0xFF0F172A).withValues(alpha: 0.6),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF1F5F9),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF10B981),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Name
              Text(
                name,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Email
              Text(
                email,
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // Joined Date
              Text(
                'Bergabung sejak: ${_formatDate(createdAt)}',
                style: GoogleFonts.outfit(
                  color: theme.colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Settings Section Header
        Text(
          'Akun & Sistem',
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Settings items container
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              // Edit Profile Tile
              ListTile(
                onTap: _showEditProfileDialog,
                leading: const Icon(Icons.edit_rounded, color: Color(0xFF10B981)),
                title: Text(
                  'Edit Data Akun',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Perbarui nama dan password Anda',
                  style: GoogleFonts.outfit(color: theme.colorScheme.outline, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),

              // Theme Tile
              ListTile(
                onTap: () => _showThemeDialog(context),
                leading: const Icon(Icons.palette_rounded, color: Color(0xFF10B981)),
                title: Text(
                  'Tema Aplikasi',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  _getThemeLabel(MyApp.of(context).themeMode),
                  style: GoogleFonts.outfit(color: theme.colorScheme.outline, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
              ),
              Divider(color: theme.dividerColor, height: 1),

              // Delete Account Tile
              ListTile(
                onTap: _showDeleteAccountDialog,
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                title: Text(
                  'Hapus Akun',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Hapus akun Anda secara permanen',
                  style: GoogleFonts.outfit(color: theme.colorScheme.outline, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // App Version Info Display
        Center(
          child: Text(
            'Versi Aplikasi: v1.0.0 (Android Only)',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.outline,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Logout Button
        ElevatedButton.icon(
          onPressed: _showLogoutConfirmDialog,
          icon: const Icon(Icons.logout_rounded),
          label: Text(
            'Keluar dari Akun',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
