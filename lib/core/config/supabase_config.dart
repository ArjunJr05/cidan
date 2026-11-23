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
  // 2. SMTP & AUTH DISPATCH CONFIGURATION
  // Security Notice: SMTP credentials and email dispatching are strictly managed
  // server-side by the CIDAN backend. No passwords or secret keys are stored in
  // client source code.
  // =========================================================================
  /// SMTP Host for Gmail
  static const String smtpHost =
      String.fromEnvironment('SMTP_HOST', defaultValue: 'smtp.gmail.com');

  /// SMTP Port: 587 (STARTTLS) or 465 (SSL)
  static const int smtpPort =
      int.fromEnvironment('SMTP_PORT', defaultValue: 587);

  /// Sender email address (configured server-side)
  static const String smtpUsername =
      String.fromEnvironment('SMTP_USER', defaultValue: '');

  /// Google App Password - MOVED TO SERVER-SIDE ENVIRONMENT VARIABLES FOR SECURITY
  static const String smtpPassword = '';

  /// Sender display name
  static const String senderName = 'CIDAN Regulatory AI';

  /// True if SMTP credentials have been supplied at build time via --dart-define
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
  static const String tableBanks = 'banks';
  static const String tableBankIntegrations = 'bank_integrations';
  static const String tableIntegrationSources = 'integration_sources';
  static const String tableConnectionVerifications = 'connection_verifications';
  static const String tableExistingRules = 'existing_rules';
  static const String tableRegulatoryDocuments = 'regulatory_documents';
  static const String tableRuleIR = 'rule_ir';
  static const String tableDeltaAnalyses = 'delta_analyses';
  static const String tableRuleDeltas = 'rule_deltas';
  static const String tableRuleMappings = 'rule_mappings';
  static const String tableRuleValidations = 'rule_validations';
  static const String tableUserSavedIntegrations = 'user_saved_integrations';
}
