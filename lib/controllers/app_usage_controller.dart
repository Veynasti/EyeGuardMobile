import 'package:flutter/foundation.dart';
import '../models/app_usage_model.dart';
import '../services/app_usage_service.dart';
import '../services/app_info_cache.dart';
import '../services/api_service.dart';

class AppUsageController extends ChangeNotifier {
  final AppUsageService _usageService = AppUsageService();
  final ApiService apiService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DailyUsageData? _todayUsage;
  DailyUsageData? get todayUsage => _todayUsage;

  List<DailyUsageData> _weeklyUsage = [];
  List<DailyUsageData> get weeklyUsage => _weeklyUsage;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  AppUsageController({required this.apiService}) {
    checkPermission();
    // Mulai inisialisasi AppInfoCache di background saat controller dibuat,
    // sehingga data sudah siap saat AppTimerController atau AppUsageService membutuhkannya.
    AppInfoCache.instance.initialize();
  }

  /// Cek status permission
  Future<void> checkPermission() async {
    _hasPermission = await _usageService.checkPermission();
    notifyListeners();
  }

  /// Membuka setting untuk memberikan permission
  Future<void> requestPermission() async {
    await _usageService.requestPermission();
    // Tunggu sebentar dan check ulang status permission
    await checkPermission();
  }

  /// Memuat semua data (Hari ini, mingguan, dan sync ke backend)
  Future<void> loadAllData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await checkPermission();
      if (!_hasPermission) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Ambil data hari ini
      _todayUsage = await _usageService.getTodayUsage();
      
      // Ambil data mingguan
      _weeklyUsage = await _usageService.getWeeklyUsage();
      
      _isLoading = false;
      notifyListeners();

      // Jalankan sync ke backend secara async di background
      _syncData();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data statistik: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Fungsi internal untuk sync ke backend
  Future<void> _syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _usageService.syncToBackend(apiService);
    } catch (e) {
      debugPrint('Sync usage data failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
