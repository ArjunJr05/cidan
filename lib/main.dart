import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_strings.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/compliance/screens/upload_document_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase service (safe: handles missing/unconfigured keys gracefully)
  await SupabaseService().initialize();

  // Check persistent session in SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('cidan_is_logged_in') ?? false;
  final userEmail = prefs.getString('cidan_user_email') ?? '';

  // Set system UI overlay style for seamless transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(CidanApp(
    isLoggedIn: isLoggedIn && userEmail.isNotEmpty,
    userEmail: userEmail,
  ));
}

class CidanApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userEmail;

  const CidanApp({
    super.key,
    this.isLoggedIn = false,
    this.userEmail = '',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppStrings.appName} - ${AppStrings.appTagline}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn
          ? UploadDocumentScreen(email: userEmail)
          : const LoginScreen(),
    );
  }
}
