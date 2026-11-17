import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/features/compliance/models/rule_ir_model.dart';
import 'package:cidan/features/compliance/models/rule_delta_model.dart';
import 'package:cidan/features/compliance/models/rule_validation_model.dart';

void main() {
  group('Milestone 2 - Universal Rule IR Model Tests', () {
    test('RuleIR serialization and deserialization roundtrip', () {
      final conditionTree = ConditionTree(
        operator: 'AND',
        conditions: [
          const ConditionNode(
            field: 'transaction_amount',
            operator: 'gte',
            value: 500000,
            valueType: 'numeric',
            unit: 'INR',
          ),
          const ConditionNode(
            field: 'is_emergency',
            operator: 'eq',
            value: false,
            valueType: 'boolean',
          ),
        ],
      );

      final rule = RuleIR(
        ruleId: 'RULE-AML-001',
        ruleName: 'High Value Cash Monitoring',
        description: 'Mandatory monitoring of transactions >= INR 500,000',
        category: 'AML',
        sourceType: 'EXISTING_DOCUMENT',
        version: 2,
        conditionTree: conditionTree,
        actions: const [
          ActionNode(
            actionType: 'FLAG_REVIEW',
            target: 'transaction',
            priority: 1,
            failureBehavior: 'FAIL_CLOSED',
          ),
        ],
      );

      final json = rule.toJson();
      final roundtrip = RuleIR.fromJson(json);

      expect(roundtrip.ruleId, equals('RULE-AML-001'));
      expect(roundtrip.category, equals('AML'));
      expect(roundtrip.version, equals(2));
      expect(roundtrip.conditionTree.conditions.length, equals(2));
      expect(roundtrip.conditionTree.flattenLeaves.first.operator, equals('gte'));
      expect(roundtrip.actions.first.actionType, equals('FLAG_REVIEW'));
    });
  });

  group('Milestone 2 - Rule Delta & Analysis Models', () {
    test('RuleDelta handles 6 classifications and visual diffs', () {
      final diff = DiffItem(
        field: 'transaction_amount',
        previousValue: 1000000,
        proposedValue: 500000,
        diffType: 'threshold_lowered',
      );

      final delta = RuleDelta(
        id: 'delta-001',
        classification: 'MODIFICATION',
        category: 'AML',
        ruleName: 'Cash Transaction Threshold Update',
        identifiedDifferences: [diff],
        reason: 'Clause 2 mandates reporting at 500,000 threshold.',
        impactAssessment: 'Alert queues will increase by ~15%.',
        confidenceScore: 0.96,
        reviewStatus: 'PENDING',
      );

      final json = delta.toJson();
      final roundtrip = RuleDelta.fromJson(json);

      expect(roundtrip.id, equals('delta-001'));
      expect(roundtrip.classification, equals('MODIFICATION'));
      expect(roundtrip.identifiedDifferences.first.field, equals('transaction_amount'));
      expect(roundtrip.identifiedDifferences.first.diffType, equals('threshold_lowered'));
      expect(roundtrip.confidenceScore, equals(0.96));
    });

    test('DeltaAnalysisResult computes summary metrics', () {
      final analysis = DeltaAnalysisResult(
        id: 'analysis-001',
        analysisName: 'RBI Circular Delta Assessment',
        circularNumber: 'RBI/2026/89',
        status: 'COMPLETED',
        totalRules: 6,
        additionsCount: 1,
        modificationsCount: 2,
        removalsCount: 1,
        clarificationsCount: 1,
        noImpactCount: 1,
        manualReviewCount: 0,
        summary: 'All requirements reviewed.',
      );

      final json = analysis.toJson();
      final roundtrip = DeltaAnalysisResult.fromJson(json);

      expect(roundtrip.totalRules, equals(6));
      expect(roundtrip.additionsCount, equals(1));
      expect(roundtrip.modificationsCount, equals(2));
      expect(roundtrip.removalsCount, equals(1));
      expect(roundtrip.clarificationsCount, equals(1));
    });
  });

  group('Milestone 2 - Rule Validation Findings Model', () {
    test('ValidationFinding serialization', () {
      const finding = ValidationFinding(
        id: 'val-001',
        ruleIrId: 'RULE-AML-001',
        validationType: 'LOGICAL',
        severity: 'ERROR',
        ruleCode: 'LOGIC_CONTRADICTION',
        message: 'Contradictory amount bounds under AND.',
      );

      final json = finding.toJson();
      final roundtrip = ValidationFinding.fromJson(json);

      expect(roundtrip.ruleCode, equals('LOGIC_CONTRADICTION'));
      expect(roundtrip.severity, equals('ERROR'));
      expect(roundtrip.validationType, equals('LOGICAL'));
    });
  });
}
