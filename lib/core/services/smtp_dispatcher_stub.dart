import 'package:flutter/foundation.dart';

/// Stub dispatcher for Web/WASM environments where direct SMTP TCP sockets are unavailable.
Future<bool> sendOtpEmailViaSmtp({
  required String recipientEmail,
  required String otpCode,
  required String smtpHost,
  required int smtpPort,
  required String smtpUsername,
  required String smtpPassword,
  required String senderName,
}) async {
  debugPrint(
    'ℹ️ [CIDAN SMTP] Direct SMTP TCP connection not supported on Web/WASM runtime.',
  );
  return false;
}
