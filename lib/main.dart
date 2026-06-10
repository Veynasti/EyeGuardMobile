import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/api_service.dart';
import 'views/auth/login_view.dart';
import 'views/main/permissions_onboarding_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ApiService _apiService = ApiService();

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeGuard Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF10B981), // Emerald
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Dark slate
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF1E293B),
          error: Colors.redAccent,
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
