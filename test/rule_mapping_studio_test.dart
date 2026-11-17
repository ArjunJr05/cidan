import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/features/compliance/models/rule_delta_model.dart';
import 'package:cidan/features/compliance/screens/rule_mapping_studio_screen.dart';

void main() {
  testWidgets('RuleMappingStudioScreen renders summary KPI header and controls',
      (WidgetTester tester) async {
    final sampleAnalysis = DeltaAnalysisResult(
      id: 'test-analysis-01',
      analysisName: 'RBI Comprehensive Assessment',
      circularNumber: 'RBI/2026/89',
      status: 'COMPLETED',
      totalRules: 4,
      additionsCount: 1,
      modificationsCount: 1,
      removalsCount: 0,
      clarificationsCount: 1,
      noImpactCount: 1,
      manualReviewCount: 0,
      deltas: [
        RuleDelta(
          id: 'delta-1',
          classification: 'MODIFICATION',
          category: 'AML',
          ruleName: 'Cash Reporting Limit',
          identifiedDifferences: [
            const DiffItem(
              field: 'transaction_amount',
              previousValue: 1000000,
              proposedValue: 500000,
              diffType: 'threshold_lowered',
            ),
          ],
          reason: 'Threshold lowered from 1,000,000 to 500,000.',
          impactAssessment: 'High operational impact on monitoring queues.',
          confidenceScore: 0.96,
          evidenceSources: [
            {'text': 'Clause 2: Cash transactions exceeding 500,000 must be reported.'}
          ],
        ),
        RuleDelta(
          id: 'delta-2',
          classification: 'ADDITION',
          category: 'IT_SECURITY',
          ruleName: 'Cloud Key Residency',
          identifiedDifferences: [
            const DiffItem(
              field: 'residency',
              previousValue: 'None',
              proposedValue: 'Domestic HSM',
              diffType: 'scope_expanded',
            ),
          ],
          reason: 'New mandate for domestic cryptographic storage.',
          impactAssessment: 'Infrastructure configuration needed.',
          confidenceScore: 0.92,
        ),
      ],
    );

    // Build the widget in an expanded test screen size
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: RuleMappingStudioScreen(
          initialAnalysis: sampleAnalysis,
          bankId: 'apex-bank-01',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('CIDAN AI Rule Mapping Studio'), findsOneWidget);
    expect(find.textContaining('RBI/2026/89'), findsOneWidget);

    // Verify Metric Pills
    expect(find.text('Total Rules'), findsOneWidget);
    expect(find.text('Additions'), findsOneWidget);
    expect(find.text('Modifications'), findsOneWidget);

    // Verify Search and Filters
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('All Categories'), findsOneWidget);

    // Verify 3 panels exist on wide layout
    expect(find.text('Existing Bank Rules'), findsOneWidget);
    expect(find.text('Regulatory Mandates'), findsOneWidget);
    expect(find.text('Proposed Rule Changes & Diff'), findsOneWidget);

    // Verify Delta Item and Diff Table
    expect(find.text('Cash Reporting Limit'), findsWidgets);
    expect(find.text('Previous Bank'), findsOneWidget);
    expect(find.text('Proposed Circular'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Accept Change'), findsOneWidget);
    expect(find.text('Edit / Customize'), findsOneWidget);
    expect(find.text('Reject Change'), findsOneWidget);
    expect(find.text('Mark Manual Review'), findsOneWidget);
  });
}
