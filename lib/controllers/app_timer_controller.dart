import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_timer_model.dart';
import '../services/app_timer_service.dart';
import '../services/app_info_cache.dart';
import '../services/background_timer_manager.dart';

/// Controller untuk fitur App Timer.
///
/// Memisahkan business logic dari UI (AppTimerTab), mengikuti pola
/// yang sama dengan AppUsageController. State dikelola di sini dan
/// di-notify ke listener (widget) via ChangeNotifier.
class AppTimerController extends ChangeNotifier {
  final AppTimerService _timerService = AppTimerService();
  final BackgroundTimerManager _backgroundManager = BackgroundTimerManager();
  final AppInfoCache _cache = AppInfoCache.instance;

  List<AppInfo> _installedApps = [];
  List<AppTimerModel> _timers = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;

  // ── Getters ──────────────────────────────────────────────────────────────

  List<AppInfo> get installedApps => _installedApps;
  List<AppTimerModel> get timers => _timers;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

  /// Kembalikan timer untuk package tertentu, atau null jika tidak ada.
  AppTimerModel? getTimerForPackage(String packageName) {
    for (var timer in _timers) {
      if (timer.packageName == packageName) return timer;
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  AppTimerController() {
    loadData();
  }

  // ── Public Methods ────────────────────────────────────────────────────────

  /// Memuat daftar aplikasi dan timer yang tersimpan.
  /// Menggunakan AppInfoCache agar tidak re-query installed apps
  /// jika data sudah tersedia.
  Future<void> loadData() async {
    if (_cache.isInitialized) {
      // Cache sudah ada, langsung pakai — hanya update timer dari storage
      _installedApps = _cache.apps;
      _isLoading = false;
      notifyListeners();
      await _reloadTimers();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _cache.initialize();
      _installedApps = _cache.apps;
      await _reloadTimers();
    } catch (e) {
      _errorMessage = 'Gagal memuat data: $e';
      debugPrint('AppTimerController: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Paksa refresh daftar aplikasi (misalnya setelah user install app baru).
  Future<void> refresh() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _cache.refresh();
      _installedApps = _cache.apps;
      await _reloadTimers();
    } catch (e) {
      debugPrint('AppTimerController refresh: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Simpan atau update timer untuk suatu aplikasi.
  Future<void> saveTimer({
    required String packageName,
    required String appName,
    required int limitMinutes,
    bool isActive = true,
  }) async {
    final timer = AppTimerModel(
      packageName: packageName,
      appName: appName,
      limitMinutes: limitMinutes,
      isActive: isActive,
    );
    await _timerService.saveTimer(timer);
    await _backgroundManager.syncServiceState();
    await _reloadTimers();
  }

  /// Hapus timer berdasarkan package name.
  Future<void> deleteTimer(String packageName) async {
    await _timerService.deleteTimer(packageName);
    await _backgroundManager.syncServiceState();
    await _reloadTimers();
  }

  /// Toggle aktif/nonaktif timer.
  Future<void> toggleTimerActive(AppTimerModel timer, bool value) async {
    final updated = timer.copyWith(isActive: value);
    await _timerService.saveTimer(updated);
    await _backgroundManager.syncServiceState();
    await _reloadTimers();
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Reload hanya data timer dari storage (tanpa re-query installed apps).
  Future<void> _reloadTimers() async {
    try {
      _timers = await _timerService.getTimers();
    } catch (e) {
      debugPrint('AppTimerController: Gagal memuat timer: $e');
    }
    notifyListeners();
  }
}
