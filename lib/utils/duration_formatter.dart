// Utilitas pemformatan durasi waktu terpusat.
// Menggantikan method _formatDuration() yang terduplikasi di AppTimerTab
// dan UsageStatsTab.

/// Format menit menjadi string singkat, contoh: "1j 30m", "45 mnt", "0 mnt".
/// Digunakan di UsageStatsTab dan display statistik.
String formatDuration(int minutes) {
  if (minutes <= 0) return '0 mnt';
  if (minutes < 60) return '$minutes mnt';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '${hours}j';
  return '${hours}j ${remainingMinutes}m';
}

/// Format menit menjadi string panjang, contoh: "1 jam 30 menit", "45 menit".
/// Digunakan di AppTimerTab untuk label batas waktu.
String formatDurationLong(int minutes) {
  if (minutes == 0) return '0 menit (Blokir langsung)';
  int h = minutes ~/ 60;
  int m = minutes % 60;
  String res = '';
  if (h > 0) res += '$h jam ';
  if (m > 0) res += '$m menit';
  return res.trim();
}
