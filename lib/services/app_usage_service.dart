import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import '../models/app_usage_model.dart';
import '../services/app_info_cache.dart';
import 'api_service.dart';

class AppUsageService {
  /// Cek apakah izin usage access sudah diberikan
  Future<bool> checkPermission() async {
    bool? isGranted = await UsageStats.checkUsagePermission();
    return isGranted ?? false;
  }

  /// Buka halaman Settings untuk memberikan izin
  Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  /// Fallback untuk memformat package name jika nama asli tidak ditemukan
  String _getFallbackAppName(String packageName) {
    List<String> parts = packageName.split('.');
    if (parts.length > 1) {
      String name = parts.last;
      if ((name == 'android' || name == 'mobile' || name == 'app' || name == 'bin') && parts.length > 2) {
        name = parts[parts.length - 2];
      }
      if (name.isNotEmpty) {
        return name[0].toUpperCase() + name.substring(1);
      }
    }
    return packageName;
  }

  /// Ambil data penggunaan untuk range tanggal tertentu menggunakan queryEvents
  Future<DailyUsageData> getUsageForPeriod(DateTime start, DateTime end) async {
    // Pastikan AppInfoCache sudah terinisialisasi sebelum digunakan.
    // initialize() bersifat idempotent — aman dipanggil berkali-kali.
    await AppInfoCache.instance.initialize();
    final appNames = AppInfoCache.instance.appNames;
    final appIcons = AppInfoCache.instance.appIcons;

    // Ambil raw event penggunaan dari Android
    List<EventUsageInfo> events = await UsageStats.queryEvents(start, end);
    
    // Urutkan event secara kronologis (waktu naik)
    events.sort((a, b) {
      int tA = int.tryParse(a.timeStamp ?? '0') ?? 0;
      int tB = int.tryParse(b.timeStamp ?? '0') ?? 0;
      return tA.compareTo(tB);
    });

    Map<String, int> appDurationsMs = {};
    Map<String, int> lastResumedMs = {};
    Map<String, String> firstEventTypeSeen = {};
    
    int startMs = start.millisecondsSinceEpoch;
    int endMs = end.millisecondsSinceEpoch;

    for (var event in events) {
      String pkg = event.packageName ?? '';
      if (pkg.isEmpty) continue;

      // Kecualikan Digital Wellbeing secara eksplisit agar tidak masuk ke perhitungan statistik
      if (pkg == 'com.google.android.apps.wellbeing' || pkg == 'com.samsung.android.forest') {
        continue;
      }

      // Filter: Hanya hitung durasi untuk app yang memiliki nama tampilan yang dikenali (kecuali app kita sendiri)
      if (appNames.isNotEmpty && !appNames.containsKey(pkg) && pkg != 'com.example.eye_guard_mobile') {
        continue;
      }

      int eventTimeMs = int.tryParse(event.timeStamp ?? '0') ?? 0;
      if (eventTimeMs < startMs || eventTimeMs > endMs) continue;

      String type = event.eventType ?? '';
      
      // Heuristik event pertama:
      // Jika event pertama dari aplikasi yang tercatat di window ini adalah PAUSE ("2"),
      // asumsikan aplikasi tersebut sudah berjalan/foreground sejak startMs (awal hari/pencarian)
      if (!firstEventTypeSeen.containsKey(pkg)) {
        firstEventTypeSeen[pkg] = type;
        if (type == '2') {
          lastResumedMs[pkg] = startMs;
        }
      }

      if (type == '1') {
        // App Resumed (Move to Foreground)
        lastResumedMs[pkg] = eventTimeMs;
      } else if (type == '2') {
        // App Paused (Move to Background)
        if (lastResumedMs.containsKey(pkg)) {
          int duration = eventTimeMs - lastResumedMs[pkg]!;
          if (duration > 0) {
            appDurationsMs[pkg] = (appDurationsMs[pkg] ?? 0) + duration;
          }
          lastResumedMs.remove(pkg);
        }
      }
    }

    // Heuristik event terakhir:
    // Jika sampai akhir window (endMs) aplikasi masih dalam status RESUMED (belum ter-pause),
    // hitung durasinya hingga akhir batas window (endMs)
    lastResumedMs.forEach((pkg, resumeTimeMs) {
      int duration = endMs - resumeTimeMs;
      if (duration > 0) {
        appDurationsMs[pkg] = (appDurationsMs[pkg] ?? 0) + duration;
      }
    });

    // Cari waktu terakhir dipakai (last used) secara real-time dari event terakhir
    Map<String, DateTime> lastUsedMap = {};
    for (var event in events.reversed) {
      String pkg = event.packageName ?? '';
      if (pkg.isEmpty) continue;
      if (!lastUsedMap.containsKey(pkg)) {
        int eventTimeMs = int.tryParse(event.timeStamp ?? '0') ?? 0;
        if (eventTimeMs > 0) {
          lastUsedMap[pkg] = DateTime.fromMillisecondsSinceEpoch(eventTimeMs);
        }
      }
    }

    // Format menjadi model AppUsageInfo
    Map<String, AppUsageInfo> aggregatedApps = {};
    appDurationsMs.forEach((pkg, durationMs) {
      // Buang sesi yang terlalu pendek (< 5 detik) sebagai noise
      if (durationMs < 5000) return;
      int durationMinutes = durationMs ~/ 60000;
      // Sesi >= 5 detik tetap ditampilkan minimal 1 menit
      if (durationMinutes < 1) durationMinutes = 1;

      DateTime lastUsed = lastUsedMap[pkg] ?? DateTime.fromMillisecondsSinceEpoch(endMs);
      String appName = appNames[pkg] ?? _getFallbackAppName(pkg);
      final iconBytes = appIcons[pkg];

      aggregatedApps[pkg] = AppUsageInfo(
        packageName: pkg,
        appName: appName,
        durationMinutes: durationMinutes,
        lastUsed: lastUsed,
        iconBytes: iconBytes,
      );
    });

    List<AppUsageInfo> appsList = aggregatedApps.values.toList();
    appsList.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

    // Hitung total dari raw milliseconds (bukan jumlah menit per-app yang sudah dibulatkan)
    // untuk menghindari akumulasi error pembulatan dari banyak aplikasi
    int totalRawMs = appDurationsMs.values.fold(0, (sum, ms) => sum + ms);
    int totalMinutes = totalRawMs ~/ 60000;

    return DailyUsageData(
      date: start,
      totalMinutes: totalMinutes,
      apps: appsList,
    );
  }

  /// Ambil data penggunaan hari ini (dari pukul 00.00 hari ini hingga sekarang)
  Future<DailyUsageData> getTodayUsage() async {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);
    return getUsageForPeriod(startOfToday, now);
  }

  /// Ambil data penggunaan 7 hari terakhir (untuk chart)
  Future<List<DailyUsageData>> getWeeklyUsage() async {
    List<DailyUsageData> weeklyData = [];
    DateTime now = DateTime.now();

    // Query untuk 7 hari ke belakang (termasuk hari ini)
    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      DateTime start = DateTime(date.year, date.month, date.day);
      DateTime end = i == 0 ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      DailyUsageData dayData = await getUsageForPeriod(start, end);
      weeklyData.add(DailyUsageData(
        date: start,
        totalMinutes: dayData.totalMinutes,
        apps: dayData.apps,
      ));
    }
    return weeklyData;
  }

  /// Sync data ke backend via ApiService untuk 7 hari terakhir (Hybrid Sync).
  ///
  /// Penggunaan aplikasi dikirim via POST /api/usage.
  /// Data sensor cahaya dikirim terpisah via POST /api/light setelah usage sync selesai.
  Future<void> syncToBackend(ApiService apiService) async {
    DateTime now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Ambil buffer light readings hari ini sebelum loop usage,
    // agar tidak di-clear jika usage sync berhasil tetapi light sync gagal.
    List<Map<String, dynamic>>? lightReadingsToday;
    final String? rawReadings = prefs.getString('buffered_light_readings');
    if (rawReadings != null && rawReadings.isNotEmpty) {
      try {
        lightReadingsToday = List<Map<String, dynamic>>.from(jsonDecode(rawReadings));
      } catch (e) {
        debugPrint('Error decoding buffered light readings in sync: $e');
      }
    }

    // Sinkronisasi data penggunaan 7 hari terakhir agar data server lengkap.
    for (int i = 0; i < 7; i++) {
      DateTime date = now.subtract(Duration(days: i));
      DateTime start = DateTime(date.year, date.month, date.day);
      DateTime end = i == 0 ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      DailyUsageData dayData = await getUsageForPeriod(start, end);
      String formattedDate = dayData.date.toIso8601String().split('T')[0];

      // Hanya kirim field yang diproses API (packageName, appName, durationMinutes).
      List<Map<String, dynamic>> appsJson = dayData.apps.map((app) => {
        'packageName': app.packageName,
        'appName': app.appName,
        'durationMinutes': app.durationMinutes,
      }).toList();

      await apiService.syncUsageData(
        date: formattedDate,
        totalUsageMinutes: dayData.totalMinutes,
        apps: appsJson,
      );
    }

    // Kirim data sensor cahaya hari ini ke endpoint POST /api/light.
    if (lightReadingsToday != null && lightReadingsToday.isNotEmpty) {
      await apiService.syncLightReadings(lightReadingsToday);
      // Hapus buffer lokal setelah berhasil terkirim
      await prefs.remove('buffered_light_readings');
    }
  }

  /// Sinkronisasi data cahaya saja ke backend untuk keperluan refresh tab Cahaya.
  /// Menghindari overhead query UsageStats 7 hari terakhir yang lambat.
  Future<void> syncLightReadingsOnly(ApiService apiService) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    List<Map<String, dynamic>>? lightReadingsToday;
    final String? rawReadings = prefs.getString('buffered_light_readings');
    if (rawReadings != null && rawReadings.isNotEmpty) {
      try {
        lightReadingsToday = List<Map<String, dynamic>>.from(jsonDecode(rawReadings));
      } catch (e) {
        debugPrint('Error decoding buffered light readings in sync: $e');
      }
    }

    if (lightReadingsToday != null && lightReadingsToday.isNotEmpty) {
      await apiService.syncLightReadings(lightReadingsToday);
      await prefs.remove('buffered_light_readings');
    }
  }
}
