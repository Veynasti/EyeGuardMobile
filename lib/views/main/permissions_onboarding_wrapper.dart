import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../services/api_service.dart';
import 'main_view.dart';
import 'onboarding_permissions_view.dart';

class PermissionsOnboardingWrapper extends StatefulWidget {
  final ApiService apiService;

  const PermissionsOnboardingWrapper({super.key, required this.apiService});

  @override
  State<PermissionsOnboardingWrapper> createState() => _PermissionsOnboardingWrapperState();
}

class _PermissionsOnboardingWrapperState extends State<PermissionsOnboardingWrapper> {
  bool _isLoading = true;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      // Selalu cek permission aktual dari sistem — bukan hanya flag.
      // Ini menangani kasus user mencabut izin manual dari Settings.
      final usage = await UsageStats.checkUsagePermission() ?? false;
      final overlay = await FlutterForegroundTask.canDrawOverlays;
      final notificationStatus = await FlutterForegroundTask.checkNotificationPermission();
      final notifications = notificationStatus == NotificationPermission.granted;

      final bool allGranted = usage && overlay && notifications;

      // Sync flag ke SharedPreferences agar konsisten
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_onboarding_completed', allGranted);

      setState(() {
        _onboardingCompleted = allGranted;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_onboarding_completed', true);
      setState(() {
        _onboardingCompleted = true;
      });
    } catch (e) {
      debugPrint('Error saving onboarding completed flag: $e');
      // Even if saving fails, let them proceed
      setState(() {
        _onboardingCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      );
    }

    if (_onboardingCompleted) {
      return MainView(apiService: widget.apiService);
    } else {
      return OnboardingPermissionsView(
        onComplete: _completeOnboarding,
      );
    }
  }
}
