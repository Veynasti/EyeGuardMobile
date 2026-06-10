import 'dart:typed_data';

class AppUsageInfo {
  final String packageName;
  final String appName;
  final int durationMinutes;
  final DateTime lastUsed;
  final Uint8List? iconBytes;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
    required this.lastUsed,
    this.iconBytes,
  });

}

class DailyUsageData {
  final DateTime date;
  final int totalMinutes;
  final List<AppUsageInfo> apps;

  DailyUsageData({
    required this.date,
    required this.totalMinutes,
    required this.apps,
  });

}
