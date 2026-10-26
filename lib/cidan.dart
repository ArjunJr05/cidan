import 'package:flutter/material.dart';
import 'main.dart';

export 'main.dart' show CidanApp;
export 'core/constants/app_strings.dart';
export 'core/constants/app_assets.dart';
export 'core/constants/app_colors.dart';
export 'core/theme/app_theme.dart';
export 'core/services/supabase_service.dart';
export 'core/config/supabase_config.dart';
export 'features/compliance/models/compliance_report_model.dart';
export 'features/compliance/services/cidan_api_service.dart';
export 'features/compliance/screens/upload_document_screen.dart';
export 'features/compliance/screens/compliance_dashboard_screen.dart';
export 'features/auth/screens/login_screen.dart';
export 'features/auth/screens/otp_screen.dart';

/// Entry point class for the CIDAN Regulatory Compliance AI Suite.
///
/// Use [Cidan.application()] or the top-level convenience instance [cidan.application()]
/// to easily launch or embed CIDAN into any Flutter project.
///
/// Example:
/// ```dart
/// import 'package:cidan/cidan.dart';
///
/// void main() {
///   runApp(cidan.application());
/// }
/// ```
class Cidan {
  Cidan._();

  /// Returns the complete CIDAN Compliance & Regulatory AI application widget.
  ///
  /// Anyone can call this method to mount CIDAN into their application.
  ///
  /// - [isLoggedIn]: Defaults to `false`. Set to `true` to display the regulatory upload
  ///   dashboard directly.
  /// - [userEmail]: Optional email for pre-authenticated sessions.
  /// - [standalone]: Defaults to `true` (returns [MaterialApp]). When `false`, returns
  ///   an embeddable themed widget that can be pushed onto an existing [Navigator].
  static Widget application({
    Key? key,
    bool isLoggedIn = false,
    String userEmail = '',
    bool standalone = true,
  }) {
    return CidanApp(
      key: key,
      isLoggedIn: isLoggedIn,
      userEmail: userEmail,
      standalone: standalone,
    );
  }
}

/// Global convenience instance enabling `cidan.application()` syntax:
///
/// ```dart
/// import 'package:cidan/cidan.dart';
///
/// void main() {
///   runApp(cidan.application());
/// }
/// ```
const CidanInstance cidan = CidanInstance();

/// Convenience class providing `cidan.application()` syntax.
class CidanInstance {
  const CidanInstance();

  /// Returns the complete CIDAN Compliance & Regulatory AI application widget.
  ///
  /// Anyone can call this method to mount CIDAN into their application.
  Widget application({
    Key? key,
    bool isLoggedIn = false,
    String userEmail = '',
    bool standalone = true,
  }) {
    return Cidan.application(
      key: key,
      isLoggedIn: isLoggedIn,
      userEmail: userEmail,
      standalone: standalone,
    );
  }
}
