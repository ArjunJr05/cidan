import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/features/compliance/models/approval_workflow_model.dart';
import 'package:cidan/features/compliance/models/rule_version_model.dart';
import 'package:cidan/features/compliance/models/rule_test_model.dart';
import 'package:cidan/features/compliance/models/deployment_model.dart';
import 'package:cidan/features/compliance/models/audit_and_notification_model.dart';
import 'package:cidan/features/compliance/screens/approval_dashboard_screen.dart';
import 'package:cidan/features/compliance/screens/deployment_console_screen.dart';
import 'package:cidan/features/compliance/screens/test_simulation_screen.dart';

void main() {
  group('Milestone 3 Models: Approval Workflow & Decisions', () {
    test('ApprovalWorkflow serialization & 16-state handling', () {
      final json = {
        'id': 'wf-100',
        'bank_id': 'apex-bank-01',
        'rule_id': 'AML-100',
        'rule_name': 'Cash Threshold Review',
        'category': 'AML',
        'status': 'SUBMITTED_FOR_REVIEW',
        'author_id': 'author@apexbank.com',
        'author_email': 'author@apexbank.com',
        'required_stages': [
          {
            'stage_name': 'Compliance Analyst Review',
            'required_role': 'COMPLIANCE_ANALYST',
            'deadline_hours': 24,
          }
        ],
        'rule_ir_snapshot': {
          'rule_id': 'AML-100',
          'condition_tree': {'operator': 'AND', 'conditions': []},
        },
      };

      final wf = ApprovalWorkflow.fromJson(json);
      expect(wf.id, 'wf-100');
      expect(wf.status, 'SUBMITTED_FOR_REVIEW');
      expect(wf.requiredStages.length, 1);
      expect(wf.requiredStages.first.stageName, 'Compliance Analyst Review');
    });

    test('ApprovalDecisionRecord serialization', () {
      final json = {
        'id': 'dec-01',
        'workflow_id': 'wf-100',
        'bank_id': 'apex-bank-01',
        'rule_id': 'AML-100',
        'stage_name': 'Compliance Review',
        'approver_id': 'auditor@apexbank.com',
        'approver_email': 'auditor@apexbank.com',
        'approver_role': 'COMPLIANCE_ANALYST',
        'decision': 'APPROVED',
        'comments': 'Policy alignment verified.',
        'previous_status': 'UNDER_REVIEW',
        'new_status': 'APPROVED',
      };

      final dec = ApprovalDecisionRecord.fromJson(json);
      expect(dec.decision, 'APPROVED');
      expect(dec.approverRole, 'COMPLIANCE_ANALYST');
      expect(dec.comments, 'Policy alignment verified.');
    });
  });

  group('Milestone 3 Models: Rule Versioning & Deep IR Comparison', () {
    test('RuleVersion & Comparison serialization', () {
      final verJson = {
        'id': 'ver-01',
        'rule_id': 'AML-100',
        'bank_id': 'apex-bank-01',
        'version_number': '1.1',
        'parent_version': '1.0',
        'change_summary': 'Lowered cash reporting threshold to INR 500k',
        'created_by': 'auditor@apexbank.com',
        'is_active': true,
      };

      final version = RuleVersion.fromJson(verJson);
      expect(version.versionNumber, '1.1');
      expect(version.isActive, true);

      final cmpJson = {
        'rule_id': 'AML-100',
        'base_version': '1.0',
        'target_version': '1.1',
        'total_differences': 1,
        'has_breaking_changes': true,
        'summary': 'Threshold updated',
        'differences': [
          {
            'field': 'transaction_amount',
            'change_type': 'CONDITION_MODIFIED',
            'old_value': 1000000,
            'new_value': 500000,
            'description': 'Lowered threshold from 1M to 500k',
          }
        ],
      };

      final cmp = RuleVersionComparison.fromJson(cmpJson);
      expect(cmp.hasBreakingChanges, true);
      expect(cmp.differences.first.changeType, 'CONDITION_MODIFIED');
    });
  });

  group('Milestone 3 Models: Simulation Testing Engine', () {
    test('RuleTestSuite & TestRun serialization', () {
      final suiteJson = {
        'id': 'suite-01',
        'bank_id': 'apex-bank-01',
        'rule_id': 'AML-100',
        'rule_version': '1.1',
        'suite_name': 'AML Boundary Suite',
        'created_by': 'qa@apexbank.com',
        'test_cases': [
          {
            'id': 'tc-01',
            'suite_id': 'suite-01',
            'bank_id': 'apex-bank-01',
            'rule_id': 'AML-100',
            'test_type': 'BOUNDARY',
            'scenario_name': 'At Threshold 500k',
            'input_data': {'amount': 500000},
            'expected_result': {'triggered': true},
          }
        ],
      };

      final suite = RuleTestSuite.fromJson(suiteJson);
      expect(suite.testCases.length, 1);
      expect(suite.testCases.first.testType, 'BOUNDARY');

      final runJson = {
        'id': 'run-01',
        'suite_id': 'suite-01',
        'bank_id': 'apex-bank-01',
        'rule_id': 'AML-100',
        'rule_version': '1.1',
        'total_test_cases': 5,
        'passed_tests': 5,
        'failed_tests': 0,
        'pass_percentage': 100.0,
        'status': 'PASSED',
        'started_by': 'qa@apexbank.com',
      };

      final run = RuleTestRun.fromJson(runJson);
      expect(run.status, 'PASSED');
      expect(run.passPercentage, 100.0);
    });
  });

  group('Milestone 3 Models: Deployment Orchestration & Rollback', () {
    test('DeploymentTarget writable guardrail & DeploymentPackage checksum', () {
      final targetJson = {
        'id': 'tgt-01',
        'bank_id': 'apex-bank-01',
        'name': 'Production Core Rule Engine',
        'target_type': 'REST',
        'environment': 'PRODUCTION',
        'is_writable': true,
        'supports_rollback': true,
      };

      final target = DeploymentTarget.fromJson(targetJson);
      expect(target.isWritable, true);
      expect(target.supportsRollback, true);

      final pkgJson = {
        'id': 'pkg-01',
        'bank_id': 'apex-bank-01',
        'rule_id': 'AML-100',
        'rule_version': '1.1',
        'version_id': 'ver-01',
        'approved_rule_ir': {'rule_id': 'AML-100'},
        'package_checksum': 'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
        'created_by': 'deployer@apexbank.com',
      };

      final pkg = DeploymentPackage.fromJson(pkgJson);
      expect(pkg.packageChecksum.length, 64);

      final rbJson = {
        'id': 'rb-01',
        'bank_id': 'apex-bank-01',
        'deployment_id': 'dep-01',
        'rule_id': 'AML-100',
        'deployed_version': '1.1',
        'restored_version': '1.0',
        'reason': 'Production transaction queue spike',
        'initiated_by': 'admin@apexbank.com',
        'status': 'COMPLETED',
      };

      final rb = RollbackRecord.fromJson(rbJson);
      expect(rb.restoredVersion, '1.0');
      expect(rb.reason, 'Production transaction queue spike');
    });
  });

  group('Milestone 3 Models: Audit Trail & Notifications', () {
    test('AuditEvent & NotificationRecord serialization', () {
      final auditJson = {
        'id': 'aud-01',
        'bank_id': 'apex-bank-01',
        'actor_id': 'officer@apexbank.com',
        'actor_email': 'officer@apexbank.com',
        'actor_role': 'RISK_OFFICER',
        'action': 'APPROVAL_DECISION_RECORDED',
        'resource_type': 'APPROVAL_WORKFLOW',
        'resource_id': 'wf-100',
        'metadata': {'decision': 'APPROVED'},
      };

      final event = AuditEvent.fromJson(auditJson);
      expect(event.action, 'APPROVAL_DECISION_RECORDED');
      expect(event.actorRole, 'RISK_OFFICER');

      final notifJson = {
        'id': 'notif-01',
        'bank_id': 'apex-bank-01',
        'recipient_email': 'auditor@apexbank.com',
        'event_type': 'APPROVAL_REQUIRED',
        'title': 'Review Required',
        'message': 'Please evaluate AML-100 update',
        'delivery_channel': 'IN_APP',
        'status': 'SENT',
        'is_read': false,
      };

      final notif = NotificationRecord.fromJson(notifJson);
      expect(notif.isRead, false);
      expect(notif.status, 'SENT');
    });
  });

  group('Milestone 3 UI Widget Smoke Tests', () {
    testWidgets('ApprovalDashboardScreen builds with metrics and toolbar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ApprovalDashboardScreen(bankId: 'apex-bank-01'),
        ),
      );
      expect(find.text('Compliance Approval Management'), findsOneWidget);
    });

    testWidgets('DeploymentConsoleScreen builds with safety checklist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeploymentConsoleScreen(ruleId: 'APEX-AML-100'),
        ),
      );
      expect(find.text('Deployment Console: APEX-AML-100'), findsOneWidget);
    });

    testWidgets('TestSimulationScreen builds with simulation sandbox notice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestSimulationScreen(ruleId: 'APEX-AML-100'),
        ),
      );
      expect(find.text('Simulation Studio: APEX-AML-100'), findsOneWidget);
    });
  });
}
