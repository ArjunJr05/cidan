import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// IO implementation of live SMTP email dispatcher using raw TCP sockets.
Future<bool> sendOtpEmailViaSmtp({
  required String recipientEmail,
  required String otpCode,
  required String smtpHost,
  required int smtpPort,
  required String smtpUsername,
  required String smtpPassword,
  required String senderName,
}) async {
  final smtpServer = SmtpServer(
    smtpHost,
    port: smtpPort,
    username: smtpUsername.trim(),
    password: smtpPassword.replaceAll(' ', '').trim(),
    ssl: smtpPort == 465,
    allowInsecure: false,
  );

  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f8fafc; margin: 0; padding: 24px; color: #0f172a; }
    .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .header { background: linear-gradient(135deg, #4A3CC8, #5B4BDB, #8B5CF6); padding: 32px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px; }
    .header p { margin: 6px 0 0; opacity: 0.88; font-size: 13px; }
    .content { padding: 32px 24px; }
    .otp-card { background: #f1f5f9; border: 1.5px dashed #4F46E5; border-radius: 12px; padding: 18px; text-align: center; margin: 24px 0; }
    .otp-code { font-size: 36px; font-weight: 800; color: #4F46E5; letter-spacing: 8px; font-family: monospace; }
    .note { font-size: 13px; color: #64748B; line-height: 1.5; margin: 0; }
    .footer { background: #f8fafc; padding: 16px 24px; text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>CIDAN</h1>
      <p>Banking Regulatory Compliance AI Platform</p>
    </div>
    <div class="content">
      <p style="font-size: 15px; margin-top: 0;">Hello,</p>
      <p style="font-size: 14px; color: #334155; line-height: 1.5;">
        You requested a verification code to access the <strong>CIDAN Banking Regulatory Compliance AI</strong> portal.
      </p>
      <div class="otp-card">
        <div style="font-size: 11px; text-transform: uppercase; font-weight: 600; color: #64748b; margin-bottom: 6px;">Your 6-Digit Verification Code</div>
        <div class="otp-code">$otpCode</div>
      </div>
      <p class="note">
        ⏱️ This code will expire in <strong>5 minutes</strong>.<br>
        🔒 For security reasons, do not share this code with anyone.
      </p>
    </div>
    <div class="footer">
      CIDAN Regulatory Compliance System • Bank-Grade 256-bit Encryption
    </div>
  </div>
</body>
</html>
''';

  final message = Message()
    ..from = Address(smtpUsername, senderName)
    ..recipients.add(recipientEmail)
    ..subject = 'Your CIDAN Security Verification Code: $otpCode'
    ..text = 'Your CIDAN verification code is: $otpCode. It expires in 5 minutes.'
    ..html = htmlContent;

  await send(message, smtpServer);
  debugPrint('📧 [CIDAN SMTP] Sent live OTP email to $recipientEmail');
  return true;
}
