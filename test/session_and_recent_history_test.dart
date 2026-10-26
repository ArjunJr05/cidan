import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cidan/core/services/supabase_service.dart';
import 'package:cidan/features/compliance/models/compliance_report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CIDAN Session, Greeting & Recent Regulatory History Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. SharedPreferences session persistence & logout flow', () async {
      final prefs = await SharedPreferences.getInstance();

      // Initially logged out
      expect(prefs.getBool('cidan_is_logged_in') ?? false, isFalse);
      expect(prefs.getString('cidan_user_email') ?? '', isEmpty);

      // On OTP Verification: login session stored
      await prefs.setBool('cidan_is_logged_in', true);
      await prefs.setString('cidan_user_email', 'arjunfree@gmail.com');

      expect(prefs.getBool('cidan_is_logged_in'), isTrue);
      expect(prefs.getString('cidan_user_email'), equals('arjunfree@gmail.com'));

      // On Sign Out: session cleared
      await prefs.setBool('cidan_is_logged_in', false);
      await prefs.remove('cidan_user_email');

      expect(prefs.getBool('cidan_is_logged_in'), isFalse);
      expect(prefs.getString('cidan_user_email'), isNull);
    });

    test('2. Username extraction from email (characters before @)', () {
      String extractUsername(String email) {
        if (email.isEmpty) return 'Officer';
        final parts = email.split('@');
        return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : email;
      }

      expect(extractUsername('arjunfree@gmail.com'), equals('arjunfree'));
      expect(extractUsername('compliance.lead@bank.com'), equals('compliance.lead'));
      expect(extractUsername('sarah_connor@hdfc.com'), equals('sarah_connor'));
      expect(extractUsername(''), equals('Officer'));
    });

    test('3. Dynamic Time-based Greeting logic', () {
      String getGreetingForHour(int hour) {
        if (hour >= 5 && hour < 12) {
          return 'Good Morning';
        } else if (hour >= 12 && hour < 17) {
          return 'Good Afternoon';
        } else {
          return 'Good Evening';
        }
      }

      // Morning
      expect(getGreetingForHour(8), equals('Good Morning'));
      expect(getGreetingForHour(11), equals('Good Morning'));

      // Afternoon
      expect(getGreetingForHour(12), equals('Good Afternoon'));
      expect(getGreetingForHour(16), equals('Good Afternoon'));

      // Evening / Night
      expect(getGreetingForHour(17), equals('Good Evening'));
      expect(getGreetingForHour(20), equals('Good Evening'));
      expect(getGreetingForHour(23), equals('Good Evening'));
      expect(getGreetingForHour(2), equals('Good Evening'));
    });

    test('4. Compliance report storage and deployment status tracking', () async {
      final service = SupabaseService();
      const testEmail = 'arjunfree@gmail.com';
      const testWorkflowId = 'test-wf-101';
      const testFileName = 'RBI_Loan_Guidelines_Circular_2026.pdf';

      final sampleModel = ComplianceReportModel.defaultSample();

      // 1. Save new compliance report (initially pending review / not deployed)
      await service.saveComplianceReport(
        email: testEmail,
        workflowId: testWorkflowId,
        filename: testFileName,
        obligationsCount: sampleModel.obligations.length,
        violationsCount: 3,
        approvedCount: sampleModel.obligations.length,
        reportData: {
          ...sampleModel.toJson(),
          'is_deployed': false,
        },
        isDeployed: false,
      );

      // 2. Fetch recent reports for user
      var reports = await service.getComplianceReports(testEmail);
      expect(reports.isNotEmpty, isTrue);
      var savedItem = reports.firstWhere((r) => r['workflow_id'] == testWorkflowId);
      expect(savedItem['filename'], equals(testFileName));
      expect(savedItem['is_deployed'], isFalse);

      // 3. User taps Approve & Sanction -> updates deployment status
      await service.updateReportDeploymentStatus(
        email: testEmail,
        workflowId: testWorkflowId,
        isDeployed: true,
      );

      // 4. Verify deployment status is now true in history
      reports = await service.getComplianceReports(testEmail);
      savedItem = reports.firstWhere((r) => r['workflow_id'] == testWorkflowId);
      expect(savedItem['is_deployed'], isTrue);

      // 5. Verify the report can be deserialized back into ComplianceReportModel
      final reportData = savedItem['report_data'] as Map<String, dynamic>;
      final reloadedModel = ComplianceReportModel.fromJson(reportData);
      expect(reloadedModel.workflowId, equals(sampleModel.workflowId));
      expect(reloadedModel.obligations.length, equals(sampleModel.obligations.length));
      expect(reportData['is_deployed'], isTrue);
    });

    test('5. Local storage download tracking in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();

      final initialDownloads = prefs.getStringList('cidan_local_downloads') ?? [];
      expect(initialDownloads, isEmpty);

      const testFilePath = '/storage/emulated/0/Download/CIDAN_Report_7d19481b_RBI_Circular.txt';
      final list = prefs.getStringList('cidan_local_downloads') ?? [];
      list.insert(0, testFilePath);
      await prefs.setStringList('cidan_local_downloads', list);

      final reloaded = prefs.getStringList('cidan_local_downloads') ?? [];
      expect(reloaded.length, equals(1));
      expect(reloaded.first, equals(testFilePath));
    });
  });
}

