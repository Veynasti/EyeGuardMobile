import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/app_timer_model.dart';

class AppTimerService {
  static const String _keyTimers = 'app_timers_config';

  // Singleton instance
  static final AppTimerService _instance = AppTimerService._internal();
  factory AppTimerService() => _instance;
  AppTimerService._internal();

  /// Mengambil daftar semua timer dari SharedPreferences
  Future<List<AppTimerModel>> getTimers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Reload agar background isolate selalu membaca data paling segar dari disk
    final String? jsonStr = prefs.getString(_keyTimers);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((item) => AppTimerModel.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Menyimpan atau memperbarui data timer
  Future<void> saveTimer(AppTimerModel timer) async {
    final prefs = await SharedPreferences.getInstance();
    List<AppTimerModel> timers = await getTimers();
    
    // Ganti jika sudah ada, atau tambahkan jika baru
    int index = timers.indexWhere((t) => t.packageName == timer.packageName);
    if (index >= 0) {
      timers[index] = timer;
    } else {
      timers.add(timer);
    }

    await prefs.setString(_keyTimers, jsonEncode(timers.map((t) => t.toJson()).toList()));
  }

  /// Menghapus timer berdasarkan package name
  Future<void> deleteTimer(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    List<AppTimerModel> timers = await getTimers();
    
    timers.removeWhere((t) => t.packageName == packageName);
    await prefs.setString(_keyTimers, jsonEncode(timers.map((t) => t.toJson()).toList()));
  }

  /// Cek apakah izin overlay ("Draw over other apps") diberikan
  Future<bool> checkOverlayPermission() async {
    return await FlutterForegroundTask.canDrawOverlays;
  }

  /// Meminta izin overlay dari pengguna
  Future<bool> requestOverlayPermission() async {
    return await FlutterForegroundTask.openSystemAlertWindowSettings();
  }
}
