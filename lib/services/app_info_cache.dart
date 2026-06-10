import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// Singleton cache terpusat untuk data aplikasi yang terinstall.
///
/// Menggabungkan tiga cache terpisah yang sebelumnya ada di:
/// - AppTimerTab._cachedApps (static)
/// - AppUsageService._cachedAppNames
/// - AppUsageService._cachedAppIcons
///
/// Dengan cache ini, `InstalledApps.getInstalledApps()` hanya dipanggil
/// sekali per sesi aplikasi, kemudian hasilnya dibagikan ke semua konsumer.
class AppInfoCache {
  // Singleton
  static final AppInfoCache _instance = AppInfoCache._internal();
  factory AppInfoCache() => _instance;
  AppInfoCache._internal();

  static AppInfoCache get instance => _instance;

  List<AppInfo>? _apps;
  Map<String, String>? _appNames;
  Map<String, Uint8List>? _appIcons;
  Set<String>? _packageNames;

  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  /// Daftar semua aplikasi (termasuk icon), diurutkan alphabetically.
  /// Digunakan oleh AppTimerTab.
  List<AppInfo> get apps => _apps ?? [];

  /// Map packageName → appName untuk semua app yang bisa diluncurkan.
  /// Digunakan oleh AppUsageService untuk filter dan nama tampilan.
  Map<String, String> get appNames => _appNames ?? {};

  /// Map packageName → icon bytes.
  /// Digunakan oleh AppUsageService untuk icon di statistik.
  Map<String, Uint8List> get appIcons => _appIcons ?? {};

  /// Set semua package name yang dikenali.
  Set<String> get packageNames => _packageNames ?? {};

  bool get isInitialized => _isInitialized;

  /// Inisialisasi cache. Aman dipanggil berkali-kali (idempotent).
  /// Jika sudah diinisialisasi, langsung return tanpa melakukan apapun.
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Jika sedang dalam proses inisialisasi, tunggu sampai selesai
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      // Satu kali query dengan icon untuk semua kebutuhan
      final List<AppInfo> appsWithIcon = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );

      // Kecualikan Digital Wellbeing agar statistik penggunaan selaras dengan sistem
      appsWithIcon.removeWhere(
        (app) => app.packageName == 'com.google.android.apps.wellbeing' ||
                 app.packageName == 'com.samsung.android.forest',
      );

      // Bangun semua map sekaligus dari satu hasil query
      final Map<String, String> names = {};
      final Map<String, Uint8List> icons = {};
      final Set<String> pkgs = {};

      for (var app in appsWithIcon) {
        names[app.packageName] = app.name;
        pkgs.add(app.packageName);
        if (app.icon != null) {
          icons[app.packageName] = app.icon!;
        }
      }

      // Buang package app EyeGuard sendiri hanya dari daftar apps (untuk AppTimerTab)
      // agar tidak bisa dipasangi timer oleh user, namun tetap terhitung di statistik penggunaan.
      final List<AppInfo> appsForTimer = List<AppInfo>.from(appsWithIcon);
      appsForTimer.removeWhere(
        (app) => app.packageName == 'com.example.eye_guard_mobile',
      );

      // Urutkan daftar app untuk AppTimerTab
      final sortedApps = List<AppInfo>.from(appsForTimer)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _apps = sortedApps;
      _appNames = names;
      _appIcons = icons;
      _packageNames = pkgs;
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('AppInfoCache: Gagal memuat daftar installed apps: $e');
      _apps = [];
      _appNames = {};
      _appIcons = {};
      _packageNames = {};
      // Set initialized = true agar tidak retry terus-menerus saat error
      _isInitialized = true;
      _initCompleter!.complete();
    } finally {
      _initCompleter = null;
    }
  }

  /// Paksa refresh cache (misalnya setelah user install/uninstall app).
  Future<void> refresh() async {
    _isInitialized = false;
    _initCompleter = null;
    _apps = null;
    _appNames = null;
    _appIcons = null;
    _packageNames = null;
    await initialize();
  }
}
