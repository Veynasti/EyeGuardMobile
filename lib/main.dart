import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'views/auth/login_view.dart';
import 'views/main/permissions_onboarding_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  /// Akses ke state MyApp dari widget anak manapun melalui context.
  // ignore: library_private_types_in_public_api
  static _MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>()!;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ApiService _apiService = ApiService();
  ThemeMode _themeMode = ThemeMode.system; // Default: ikuti sistem HP

  static const String _themePrefKey = 'app_theme_mode';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  /// Memuat preferensi tema dari SharedPreferences.
  /// Jika belum pernah disimpan (instalasi pertama), gunakan ThemeMode.system.
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    if (savedTheme != null && mounted) {
      setState(() {
        _themeMode = _stringToThemeMode(savedTheme);
      });
    }
  }

  /// Mengubah tema aplikasi secara real-time dan menyimpannya ke SharedPreferences.
  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, _themeModeToString(mode));
  }

  ThemeMode get themeMode => _themeMode;

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  ThemeMode _stringToThemeMode(String str) {
    switch (str) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeGuard Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,

      // Tema Terang
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFFFFFFFF),
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF1F5F9),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF10B981),
          unselectedItemColor: Color(0xFF94A3B8),
        ),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),

      // Tema Gelap
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF10B981),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF1E293B),
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Color(0xFF10B981),
          unselectedItemColor: Color(0xFF64748B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),

      home: AnimatedBuilder(
        animation: _apiService,
        builder: (context, _) {
          if (_apiService.token == null) {
            return LoginView(apiService: _apiService);
          } else {
            return PermissionsOnboardingWrapper(apiService: _apiService);
          }
        },
      ),
    );
  }
}
