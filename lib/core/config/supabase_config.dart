/// Supabase and SMTP Configuration Constants
///
/// Loaded with your live Supabase Project and Gmail SMTP credentials.
/// CIDAN connects to your Supabase backend and sends live OTP emails
/// with per-email compliance audit history logging.
class SupabaseConfig {
  SupabaseConfig._();

  // =========================================================================
  // 1. SUPABASE PROJECT CREDENTIALS
  // (Project Ref: vettckrwudnnvoalvjno)
  // =========================================================================
  static const String supabaseUrl = 'https://vettckrwudnnvoalvjno.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZldHRja3J3dWRubnZvYWx2am5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwMDkyNTIsImV4cCI6MjEwODU4NTI1Mn0.rDEb0UWfphz3S4Dt8N1ZkeCx3TIuBt2Gw4WKz1XPW_w';

  /// True if the user has provided valid Supabase credentials
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        !supabaseUrl.contains('YOUR_SUPABASE') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseAnonKey.contains('YOUR_SUPABASE');
  }

  // =========================================================================
  // 2. SMTP EMAIL CREDENTIALS (For sending live 6-digit OTP codes)
  // =========================================================================
  /// SMTP Host for Gmail
  static const String smtpHost = 'smtp.gmail.com';

  /// SMTP Port: 587 (STARTTLS) or 465 (SSL)
  static const int smtpPort = 587;

  /// Sender email address
  static const String smtpUsername = 'unknownhacker3d@gmail.com';

  /// Google App Password
  static const String smtpPassword = 'munr mayy tdfc mzyl';

  /// Sender display name
  static const String senderName = 'CIDAN Regulatory AI';

  /// True if SMTP credentials have been supplied
  static bool get isSmtpConfigured {
    return smtpUsername.isNotEmpty &&
        !smtpUsername.contains('YOUR_SENDER') &&
        smtpPassword.isNotEmpty &&
        !smtpPassword.contains('YOUR_SMTP');
  }

  // =========================================================================
  // 3. TABLE NAMES
  // =========================================================================
  static const String tableOtps = 'auth_otps';
  static const String tableUserHistory = 'user_history';
  static const String tableComplianceReports = 'compliance_reports';
}
