import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light/light.dart';
import 'app_timer_service.dart';
import '../models/app_timer_model.dart';

// Top-level entry point callback untuk background isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AppTimerTaskHandler());
}

class AppTimerTaskHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<int>? _lightSubscription;
  Light? _light;
  int _currentLux = -1;
  int _continuousDarkSeconds = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Inisialisasi notifikasi lokal di dalam isolate background
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);

    _initLightSensor();
  }

  void _initLightSensor() {
    try {
      _light = Light();
      _lightSubscription = _light?.lightSensorStream.listen((int lux) {
        _currentLux = lux;
      }, onError: (e) {
        debugPrint('EyeGuard: Error in light sensor stream: $e');
      });
    } catch (e) {
      debugPrint('EyeGuard: Failed to initialize light sensor: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    try {
      debugPrint('=== EYEGUARD TICK START ===');
      
      // Load SharedPreferences & sync dengan disk
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final bool lightMonitoringEnabled = prefs.getBool('light_monitoring_enabled') ?? true;
      final int luxThreshold = prefs.getInt('light_threshold_lux') ?? 20;

      final timers = await AppTimerService().getTimers();
      final bool hasActiveTimers = timers.any((t) => t.isActive);

      // Jika keduanya tidak aktif, skip
      if (!lightMonitoringEnabled && !hasActiveTimers) {
        debugPrint('EyeGuard: Both light monitoring and app timers are disabled. Skipping.');
        return;
      }

      DateTime now = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(now);

      // Ambil events untuk deteksi foreground app (dibutuhkan oleh timer & monitoring cahaya per-app)
      DateTime start = now.subtract(const Duration(hours: 2));
      List<EventUsageInfo> events = await UsageStats.queryEvents(start, now);
      String? activePackage = _getActiveApp(events);

      // Kecualikan Digital Wellbeing dari deteksi aplikasi aktif (foreground)
      if (activePackage == 'com.google.android.apps.wellbeing' ||
          activePackage == 'com.samsung.android.forest') {
        activePackage = null;
      }

      debugPrint('EyeGuard: Active Foreground Package detected: "$activePackage"');

      // -----------------------------------------------------------------
      // LOGIKA MONITORING CAHAYA
      // -----------------------------------------------------------------
      if (lightMonitoringEnabled) {
        // Simpan nilai Lux real-time ke SharedPreferences agar bisa dibaca tab UI
        await prefs.setInt('live_lux_value', _currentLux);

        if (_currentLux != -1 && activePackage != null && activePackage.isNotEmpty) {
          if (_currentLux < luxThreshold) {
            _continuousDarkSeconds += 2; // onRepeatEvent terpanggil setiap 2 detik

            // Akumulasi total detik gelap harian
            int darkSecs = prefs.getInt('dark_seconds_$todayStr') ?? 0;
            await prefs.setInt('dark_seconds_$todayStr', darkSecs + 2);

            // Akumulasi detik gelap per-aplikasi jika ada aplikasi aktif di foreground
            int appDarkSecs = prefs.getInt('dark_seconds_${todayStr}_$activePackage') ?? 0;
            await prefs.setInt('dark_seconds_${todayStr}_$activePackage', appDarkSecs + 2);

            final int notificationIntervalMinutes = prefs.getInt('light_notification_interval_minutes') ?? 5;
            final int intervalSeconds = notificationIntervalMinutes * 60;

            debugPrint('EyeGuard: Continuous dark seconds: $_continuousDarkSeconds/$intervalSeconds. Current Lux: $_currentLux');

            // Logika peringatan berulang setiap intervalSeconds terlampaui
            if (_continuousDarkSeconds > 0 && _continuousDarkSeconds % intervalSeconds == 0) {
              final int elapsedMinutes = _continuousDarkSeconds ~/ 60;
              await _showNotification(
                id: 200,
                title: 'Pencahayaan Kurang! ⚠️',
                body: 'Anda telah menggunakan HP di tempat gelap selama $elapsedMinutes menit. Harap pindah ke tempat lebih terang.',
              );
            }
          } else {
            // Kembali ke kondisi terang
            _continuousDarkSeconds = 0;
          }

          // SAMPLING DATA MENTAH SETIAP 5 MENIT
          final String? lastSampleTimeStr = prefs.getString('last_light_sample_time');
          bool shouldSample = false;
          if (lastSampleTimeStr == null) {
            shouldSample = true;
          } else {
            DateTime lastSample = DateTime.parse(lastSampleTimeStr);
            if (now.difference(lastSample).inMinutes >= 5) {
              shouldSample = true;
            }
          }

          if (shouldSample) {
            final String? rawReadings = prefs.getString('buffered_light_readings');
            List<dynamic> readingsList = [];
            if (rawReadings != null && rawReadings.isNotEmpty) {
              try {
                readingsList = jsonDecode(rawReadings);
              } catch (e) {
                debugPrint('Error decoding buffered light readings: $e');
              }
            }
            readingsList.add({
              'lux': _currentLux,
              'timestamp': now.toUtc().toIso8601String(),
            });
            await prefs.setString('buffered_light_readings', jsonEncode(readingsList));
            await prefs.setString('last_light_sample_time', now.toIso8601String());
            debugPrint('EyeGuard: Lux sample saved: $_currentLux Lux');
          }
        } else {
          // HP terkunci, layar mati, atau sedang berada di launcher utama tanpa aplikasi aktif
          _continuousDarkSeconds = 0;
        }
      } else {
        _continuousDarkSeconds = 0;
      }

      // -----------------------------------------------------------------
      // LOGIKA APP TIMER
      // -----------------------------------------------------------------
      if (hasActiveTimers && activePackage != null && activePackage.isNotEmpty) {
        AppTimerModel? targetTimer;
        for (var t in timers) {
          if (t.packageName == activePackage && t.isActive) {
            targetTimer = t;
            break;
          }
        }

        if (targetTimer != null) {
          debugPrint('EyeGuard: MATCH FOUND! Monitoring "$activePackage" with limit ${targetTimer.limitMinutes} min.');

          DateTime todayStart = DateTime(now.year, now.month, now.day);
          List<EventUsageInfo> allTodayEvents = await UsageStats.queryEvents(todayStart, now);
          allTodayEvents.sort((a, b) {
            int tA = int.tryParse(a.timeStamp ?? '0') ?? 0;
            int tB = int.tryParse(b.timeStamp ?? '0') ?? 0;
            return tA.compareTo(tB);
          });

          int totalTimeMs = _calculateUsageForPackageMs(
            events: allTodayEvents,
            packageName: activePackage,
            startMs: todayStart.millisecondsSinceEpoch,
            endMs: now.millisecondsSinceEpoch,
          );

          int usedMinutes = totalTimeMs ~/ 60000;
          debugPrint('EyeGuard: Total Used Time (event-based): $usedMinutes minutes. Limit: ${targetTimer.limitMinutes} minutes.');

          int remainingTime = targetTimer.limitMinutes - usedMinutes;
          debugPrint('EyeGuard: Remaining Time: $remainingTime minutes.');

          if (remainingTime <= 0) {
            debugPrint('EyeGuard: LIMIT EXCEEDED! Triggering minimize and block overlay.');
            await FlutterForegroundTask.saveData(key: 'blocked_package', value: targetTimer.packageName);
            await FlutterForegroundTask.saveData(key: 'blocked_app_name', value: targetTimer.appName);

            FlutterForegroundTask.minimizeApp();
            FlutterForegroundTask.launchApp();

            await _showNotification(
              id: 100,
              title: 'Waktu Habis!',
              body: 'Batas penggunaan aplikasi ${targetTimer.appName} hari ini telah tercapai.',
            );
          } else {
            bool updateNeeded = false;
            bool warning5Sent = targetTimer.warning5MinSent;
            bool warning1Sent = targetTimer.warning1MinSent;
            String lastDate = targetTimer.lastCheckedDate;

            if (lastDate != todayStr) {
              warning5Sent = false;
              warning1Sent = false;
              lastDate = todayStr;
              updateNeeded = true;
            }

            if (remainingTime <= 1 && !warning1Sent) {
              await _showNotification(
                id: 101,
                title: 'Sisa Waktu 1 Menit!',
                body: 'Penggunaan aplikasi ${targetTimer.appName} tersisa 1 menit lagi.',
              );
              warning1Sent = true;
              updateNeeded = true;
            } else if (remainingTime <= 5 && !warning5Sent && remainingTime > 1) {
              await _showNotification(
                id: 105,
                title: 'Sisa Waktu 5 Menit!',
                body: 'Penggunaan aplikasi ${targetTimer.appName} tersisa 5 menit lagi.',
              );
              warning5Sent = true;
              updateNeeded = true;
            }

            if (updateNeeded) {
              final updated = targetTimer.copyWith(
                warning5MinSent: warning5Sent,
                warning1MinSent: warning1Sent,
                lastCheckedDate: todayStr,
              );
              await AppTimerService().saveTimer(updated);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error di background loop AppTimer: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _lightSubscription?.cancel();
  }

  @override
  void onNotificationPressed() {
    // Handler ketika notifikasi persisten diklik
  }

  String? _getActiveApp(List<EventUsageInfo> events) {
    events.sort((a, b) {
      int tA = int.tryParse(a.timeStamp ?? '0') ?? 0;
      int tB = int.tryParse(b.timeStamp ?? '0') ?? 0;
      return tA.compareTo(tB);
    });

    String? lastForeground;
    for (var event in events) {
      if (event.eventType == '1') { // MOVE_TO_FOREGROUND
        lastForeground = event.packageName;
      } else if (event.eventType == '2' && lastForeground == event.packageName) { // MOVE_TO_BACKGROUND
        lastForeground = null;
      }
    }
    return lastForeground;
  }

  /// Menghitung total waktu penggunaan (ms) untuk satu package dari daftar events.
  ///
  /// Menggunakan pendekatan event-based yang sama dengan AppUsageService.getUsageForPeriod()
  /// untuk menghindari bug double-counting jika mengkombinasikan queryUsageStats + queryEvents.
  ///
  /// Heuristik:
  /// - Jika event pertama untuk package adalah PAUSE, app sudah aktif sejak startMs
  /// - Jika masih aktif saat endMs, hitung hingga endMs
  int _calculateUsageForPackageMs({
    required List<EventUsageInfo> events,
    required String packageName,
    required int startMs,
    required int endMs,
  }) {
    int totalDurationMs = 0;
    int? lastResumedMs;
    bool firstEventSeen = false;

    for (var event in events) {
      if (event.packageName != packageName) continue;

      int eventTimeMs = int.tryParse(event.timeStamp ?? '0') ?? 0;
      if (eventTimeMs < startMs || eventTimeMs > endMs) continue;

      String type = event.eventType ?? '';

      // Heuristik: jika event pertama adalah PAUSE, berarti app sudah aktif sejak startMs
      if (!firstEventSeen) {
        firstEventSeen = true;
        if (type == '2') {
          lastResumedMs = startMs;
        }
      }

      if (type == '1') {
        // MOVE_TO_FOREGROUND
        lastResumedMs = eventTimeMs;
      } else if (type == '2') {
        // MOVE_TO_BACKGROUND
        if (lastResumedMs != null) {
          int duration = eventTimeMs - lastResumedMs;
          if (duration > 0) totalDurationMs += duration;
          lastResumedMs = null;
        }
      }
    }

    // Jika masih aktif di foreground saat endMs, hitung hingga endMs
    if (lastResumedMs != null) {
      int duration = endMs - lastResumedMs;
      if (duration > 0) totalDurationMs += duration;
    }

    return totalDurationMs;
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'app_timer_warning_channel',
      'Peringatan Batas Waktu',
      channelDescription: 'Pengingat waktu penggunaan aplikasi dari EyeGuard',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }
}

class BackgroundTimerManager {
  static final BackgroundTimerManager _instance = BackgroundTimerManager._internal();
  factory BackgroundTimerManager() => _instance;
  BackgroundTimerManager._internal();

  /// Inisialisasi awal Foreground Task
  void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'eyeguard_timer_service_channel',
        channelName: 'Pemantauan EyeGuard',
        channelDescription: 'Menjaga kesehatan mata Anda dengan mengawasi batas waktu aplikasi.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000), // Periksa setiap 2 detik sekali
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Memulai Foreground Service
  Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'EyeGuard Memantau Waktu Aplikasi',
      notificationText: 'Fitur App Timer aktif di background.',
      callback: startCallback,
    );
    return result.success;
  }

  /// Menghentikan Foreground Service
  Future<bool> stopService() async {
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      return result.success;
    }
    return true;
  }

  /// Sinkronisasi status service secara otomatis berdasarkan keberadaan timer aktif atau monitoring cahaya
  Future<void> syncServiceState() async {
    final timers = await AppTimerService().getTimers();
    final bool hasActiveTimers = timers.any((t) => t.isActive);

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final bool isLightMonitoringEnabled = prefs.getBool('light_monitoring_enabled') ?? true;

    if (hasActiveTimers || isLightMonitoringEnabled) {
      initService();
      await startService();
    } else {
      await stopService();
    }
  }
}
