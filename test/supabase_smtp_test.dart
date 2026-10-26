// ignore_for_file: avoid_print
import 'dart:io';
import 'package:cidan/core/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Supabase and SMTP Full Flow Integration Test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null; // Enable live HTTP connections in test

    // 1. Initialize Supabase
    await SupabaseService().initialize();
    expect(SupabaseService().isConnected, isTrue);

    // 2. Generate, Save, and Email OTP
    const testEmail = 'unknownhacker3d@gmail.com';
    final sendResult = await SupabaseService().sendAndSaveOtp(testEmail);
    expect(sendResult['success'], isTrue);
    expect(sendResult['otp'], isNotNull);
    final otp = sendResult['otp'] as String;

    // 3. Verify in Supabase
    final verified = await SupabaseService().verifyOtp(testEmail, otp);
    expect(verified, isTrue);

    // 4. Verify History is recorded in Supabase
    final history = await SupabaseService().getUserHistory(testEmail);
    expect(history.isNotEmpty, isTrue);

    print('✅ SUCCESS: Supabase Connected!');
    print('✅ SUCCESS: Live OTP Generated & Saved ($otp)!');
    print('✅ SUCCESS: Live Email Dispatched via SMTP!');
    print('✅ SUCCESS: OTP Verified & History Audit Logged (${history.length} records)!');
  });
}
