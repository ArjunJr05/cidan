// ignore_for_file: avoid_print
import 'dart:io';
import 'package:cidan/cidan.dart';
import 'package:cidan/core/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Supabase Live Real Project & SMTP Integration Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      HttpOverrides.global = null; // Enable live HTTP connections in test
      await SupabaseService().initialize();
    });

    test('1. Supabase Live Connection & Client Status', () {
      expect(SupabaseService().isConnected, isTrue);
      expect(SupabaseService().client, isNotNull);
      print('✅ SUCCESS: Connected to live Supabase project!');
    });

    test(
      '2. Live OTP Generation, Verification & User Audit History',
      () async {
        // Confirm client has no hardcoded SMTP passwords (security verification)
        expect(SupabaseConfig.smtpPassword.isEmpty, isTrue);
        expect(SupabaseConfig.isSmtpConfigured, isFalse);

        const testEmail = 'unknownhacker3d@gmail.com';
        final sendResult = await SupabaseService().sendAndSaveOtp(testEmail);
        expect(sendResult['success'], isTrue);
        expect(sendResult['otp'], isNotNull);
        final otp = sendResult['otp'] as String;

        final verified = await SupabaseService().verifyOtp(testEmail, otp);
        expect(verified, isTrue);

        final history = await SupabaseService().getUserHistory(testEmail);
        expect(history.isNotEmpty, isTrue);

        print('✅ SUCCESS: Live OTP Generated, Verified & Audited ($otp)!');
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test('3. Live Bank & Multi-Tenant Integration Persistence', () async {
      final bank = await SupabaseService().getOrCreateBank(
        name: 'Apex Global Bank',
        bankCode: 'AGB-9021',
      );
      expect(bank.bankCode, equals('AGB-9021'));

      final intgId = SupabaseService.generateUuid();
      final intg = BankIntegrationModel(
        id: intgId,
        bankId: bank.id,
        name: 'Live Core Gateway',
        environment: 'PRODUCTION',
        integrationType: 'SQL',
        status: 'ACTIVE',
        createdAt: DateTime.now(),
      );
      await SupabaseService().saveBankIntegration(intg);

      final src = IntegrationSourceModel(
        id: SupabaseService.generateUuid(),
        integrationId: intg.id,
        sourceType: 'ORACLE',
        configMetadata: {'host': 'oracle.apexbank.internal', 'port': 1521},
        credentialRef: 'vault://tokens/live-oracle-ro',
        createdAt: DateTime.now(),
      );
      await SupabaseService().saveIntegrationSource(src);

      final sources = await SupabaseService().getIntegrationSources(intg.id);
      expect(sources.any((s) => s.id == src.id), isTrue);

      print('✅ SUCCESS: Bank & Integration Sources Persisted!');
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('4. Live Existing Rules & Circular Documents Persistence', () async {
      final now = DateTime.now();
      final bank = await SupabaseService().getOrCreateBank(
        name: 'Apex Global Bank',
        bankCode: 'AGB-9021',
      );
      final rule = ExistingRuleModel(
        id: SupabaseService.generateUuid(),
        bankId: bank.id,
        sourceType: 'FILE',
        ruleCode: 'RULE-KYC-LIVE',
        ruleTitle: 'Live KYC Policy',
        ruleContent: 'Mandatory Aadhaar/PAN for deposits above 50K',
        fileFormat: 'PDF',
        createdAt: now,
      );
      await SupabaseService().saveExistingRules([rule]);

      final doc = RegulatoryDocumentModel(
        id: SupabaseService.generateUuid(),
        bankId: bank.id,
        documentName: 'RBI_Circular_Live.pdf',
        issuingAuthority: 'RBI',
        circularNumber: 'RBI/2026/LIVE-01',
        fileFormat: 'PDF',
        createdAt: now,
      );
      await SupabaseService().saveRegulatoryDocument(doc);

      print('✅ SUCCESS: Existing Rules & Circular Documents Persisted!');
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
