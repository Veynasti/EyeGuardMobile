class AppTimerModel {
  final String packageName;
  final String appName;
  final int limitMinutes;
  final bool isActive;
  final bool warning5MinSent;
  final bool warning1MinSent;
  final String lastCheckedDate; // Format: 'YYYY-MM-DD'

  AppTimerModel({
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    this.isActive = true,
    this.warning5MinSent = false,
    this.warning1MinSent = false,
    this.lastCheckedDate = '',
  });

  AppTimerModel copyWith({
    String? packageName,
    String? appName,
    int? limitMinutes,
    bool? isActive,
    bool? warning5MinSent,
    bool? warning1MinSent,
    String? lastCheckedDate,
  }) {
    return AppTimerModel(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      isActive: isActive ?? this.isActive,
      warning5MinSent: warning5MinSent ?? this.warning5MinSent,
      warning1MinSent: warning1MinSent ?? this.warning1MinSent,
      lastCheckedDate: lastCheckedDate ?? this.lastCheckedDate,
    );
  }

  factory AppTimerModel.fromJson(Map<String, dynamic> json) {
    return AppTimerModel(
      packageName: json['packageName'] ?? '',
      appName: json['appName'] ?? '',
      limitMinutes: json['limitMinutes'] ?? 0,
      isActive: json['isActive'] ?? true,
      warning5MinSent: json['warning5MinSent'] ?? false,
      warning1MinSent: json['warning1MinSent'] ?? false,
      lastCheckedDate: json['lastCheckedDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'limitMinutes': limitMinutes,
      'isActive': isActive,
      'warning5MinSent': warning5MinSent,
      'warning1MinSent': warning1MinSent,
      'lastCheckedDate': lastCheckedDate,
    };
  }
}
