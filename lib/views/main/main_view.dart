import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../controllers/app_usage_controller.dart';
import '../../controllers/app_timer_controller.dart';
import '../../services/api_service.dart';
import '../../services/background_timer_manager.dart';
import 'home_tab.dart';
import 'usage_stats_tab.dart';
import 'profile_tab.dart';
import 'app_timer_tab.dart';
import 'app_block_view.dart';
import 'light_monitor_tab.dart';

class MainView extends StatefulWidget {
  final ApiService apiService;

  const MainView({Key? key, required this.apiService}) : super(key: key);

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> with WidgetsBindingObserver {
  late AppUsageController _usageController;
  late AppTimerController _timerController;
  int _currentIndex = 0;
  static const _platform = MethodChannel('com.example.eye_guard_mobile/app_timer');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _usageController = AppUsageController(apiService: widget.apiService);
    _timerController = AppTimerController();
    // Jalankan pengecekan izin dan load data saat widget diinisialisasi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _usageController.loadAllData();
      _checkIntent();
      _checkBlockedApp();
      _initBackgroundService();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIntent();
      _checkBlockedApp();
    }
  }

  Future<void> _initBackgroundService() async {
    try {
      final manager = BackgroundTimerManager();
      manager.initService();
      await manager.syncServiceState();
    } catch (e) {
      debugPrint('Gagal inisialisasi background service: $e');
    }
  }

  Future<void> _checkIntent() async {
    try {
      final Map<dynamic, dynamic>? extras = await _platform.invokeMethod('getIntentExtras');
      if (extras != null && extras['route'] == 'app_block') {
        final blockedPackage = extras['blockedPackage'] as String?;
        final blockedAppName = extras['blockedAppName'] as String?;
        if (blockedPackage != null && blockedAppName != null) {
          _showBlockScreen(blockedAppName, blockedPackage);
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca intent extras: $e');
    }
  }

  Future<void> _checkBlockedApp() async {
    try {
      final String? blockedPackage = await FlutterForegroundTask.getData<String>(key: 'blocked_package');
      final String? blockedAppName = await FlutterForegroundTask.getData<String>(key: 'blocked_app_name');
      
      if (blockedPackage != null && blockedAppName != null) {
        // Hapus data agar tidak kepicu berulang kali
        await FlutterForegroundTask.removeData(key: 'blocked_package');
        await FlutterForegroundTask.removeData(key: 'blocked_app_name');
        
        _showBlockScreen(blockedAppName, blockedPackage);
      }
    } catch (e) {
      debugPrint('Gagal membaca data blokir dari storage: $e');
    }
  }

  void _showBlockScreen(String appName, String packageName) {
    // Cek apakah AppBlockView sudah terbuka agar tidak double push
    bool isAlreadyShowingBlock = false;
    Navigator.of(context).popUntil((route) {
      if (route.settings.name == 'app_block_view') {
        isAlreadyShowingBlock = true;
      }
      return true; // Don't actually pop anything
    });

    if (!isAlreadyShowingBlock) {
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'app_block_view'),
          builder: (context) => AppBlockView(
            appName: appName,
            packageName: packageName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _usageController,
      builder: (context, _) {
        // Tampilkan loading screen jika data sedang dimuat pertama kali
        if (_usageController.isLoading && _usageController.todayUsage == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Mengambil data penggunaan...',
                    style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                  )
                ],
              ),
            ),
          );
        }

        final List<Widget> tabs = [
          HomeTab(
            controller: _usageController,
            onViewStatsSelected: () {
              setState(() {
                _currentIndex = 3; // Pindah ke tab statistik (sekarang index 3)
              });
            },
          ),
          AppTimerTab(controller: _timerController),
          LightMonitorTab(apiService: widget.apiService, controller: _usageController),
          UsageStatsTab(controller: _usageController),
          ProfileTab(apiService: widget.apiService),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              _currentIndex == 0
                  ? 'EyeGuard'
                  : _currentIndex == 1
                      ? 'App Timer'
                      : _currentIndex == 2
                          ? 'Monitoring Cahaya'
                          : _currentIndex == 3
                              ? 'Statistik Penggunaan'
                              : 'Profil Pengguna',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              if (_currentIndex < tabs.length - 1) // Tampilkan indicator sync di tab selain Profil
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: _usageController.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                            ),
                          )
                        : const Icon(
                            Icons.cloud_done_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                  ),
                ),
            ],
          ),
          body: tabs[_currentIndex],
          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: const Color(0xFF1E293B),
              selectedItemColor: const Color(0xFF10B981),
              unselectedItemColor: const Color(0xFF64748B),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.timer_outlined),
                  activeIcon: Icon(Icons.timer_rounded),
                  label: 'Timer',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.wb_sunny_outlined),
                  activeIcon: Icon(Icons.wb_sunny_rounded),
                  label: 'Cahaya',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Statistik',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
