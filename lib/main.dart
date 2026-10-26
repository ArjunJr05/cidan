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

  // Initialize Supabase service
  await SupabaseService().initialize();

  // Check persistent session in SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('cidan_is_logged_in') ?? false;
  final userEmail = prefs.getString('cidan_user_email') ?? '';

  // Set system UI overlay style for transparent status bar
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

/// Root widget for the CIDAN Regulatory Compliance AI Application.
///
/// Can be used as a standalone application via `runApp()` or embedded within an
/// existing Flutter application via `cidan.application()`.
class CidanApp extends StatelessWidget {
  /// Whether the application starts in the authenticated upload state.
  final bool isLoggedIn;

  /// User email for pre-authenticated sessions or deep-linking.
  final String userEmail;

  /// Whether to return a standalone [MaterialApp] (`true`, default) or an embeddable [Theme] (`false`).
  final bool standalone;

  /// Creates a new [CidanApp] widget.
  const CidanApp({
    super.key,
    this.isLoggedIn = false,
    this.userEmail = '',
    this.standalone = true,
  });

  @override
  Widget build(BuildContext context) {
    final home = isLoggedIn
        ? UploadDocumentScreen(email: userEmail)
        : const LoginScreen();

    if (standalone) {
      return MaterialApp(
        title: '${AppStrings.appName} - ${AppStrings.appTagline}',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: home,
      );
    }

    return Theme(
      data: AppTheme.lightTheme,
      child: home,
    );
  }
}
