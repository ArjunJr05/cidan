/// Complete model representing CIDAN Virtusa Agent Workflow Analysis Output
class ComplianceReportModel {
  final String workflowId;
  final String stage;
  final String? error;
  final List<ObligationItem> obligations;
  final List<FindingItem> findings;
  final List<dynamic> proposals;
  final List<TestCaseItem> tests;
  final ReportSummary report;
  final ReportFiles? reportFiles;
  final Map<String, dynamic> rawJson;

  const ComplianceReportModel({
    required this.workflowId,
    required this.stage,
    this.error,
    required this.obligations,
    required this.findings,
    required this.proposals,
    required this.tests,
    required this.report,
    this.reportFiles,
    this.rawJson = const {},
  });

  factory ComplianceReportModel.fromJson(Map<String, dynamic> json) {
    final rawObligations = json['obligations'] as List? ?? [];
    final rawFindings = json['findings'] as List? ?? [];
    final rawProposals = json['proposals'] as List? ?? [];
    final rawTests = json['tests'] as List? ?? [];
    final rawReport = json['report'] as Map<String, dynamic>? ?? {};
    final rawFiles = json['report_files'] as Map<String, dynamic>?;

    return ComplianceReportModel(
      workflowId: json['workflow_id']?.toString() ?? '7d19481b-2d2b-4bb4-96b8-35eaf0693df1',
      stage: json['stage']?.toString() ?? 'awaiting_human_review',
      error: json['error']?.toString(),
      obligations: rawObligations.map((e) => ObligationItem.fromJson(e as Map<String, dynamic>)).toList(),
      findings: rawFindings.map((e) => FindingItem.fromJson(e as Map<String, dynamic>)).toList(),
      proposals: rawProposals,
      tests: rawTests.map((e) => TestCaseItem.fromJson(e as Map<String, dynamic>)).toList(),
      report: ReportSummary.fromJson(rawReport),
      reportFiles: rawFiles != null ? ReportFiles.fromJson(rawFiles) : null,
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson.isNotEmpty ? rawJson : sampleJsonMap;

  /// Default mock payload provided directly by the backend for verified offline/fallback usage
  static ComplianceReportModel defaultSample() {
    return ComplianceReportModel.fromJson(sampleJsonMap);
  }

  static const Map<String, dynamic> sampleJsonMap = {
    "workflow_id": "7d19481b-2d2b-4bb4-96b8-35eaf0693df1",
    "stage": "awaiting_human_review",
    "error": null,
    "obligations": [
      {
        "obligation_id": "OBL-001",
        "clause_id": "not_specified",
        "text": "Apply the illustrative control framework to the described loan applications.",
        "applicability": "Synthetic demo applications described in the circular.",
        "product_type": "personal loan",
        "amount_threshold": null,
        "currency": null,
        "effective_date": "not_specified",
        "responsible_function": "bank",
        "required_action": "Apply the illustrative control framework.",
        "deadline_or_frequency": "not_specified",
        "exceptions": [],
        "source": {
          "document_id": "44b779e11de57f3100f206973232b84cf4c35534457b9b52948f5154ecdf87e7",
          "filename": "CIDAN_Synthetic_RBI_Style_Loan_Approval_Circular_8_pages.pdf",
          "document_type": "circular",
          "page": 3,
          "excerpt": "Applies in this fictional scenario to new personal-loan and consumer-credit applications.",
          "chunk_id": "5a7176c897136cf1ca2162d383225feda2d521c537b161ce3716f17fc49c05c2"
        },
        "supporting_excerpt": "Applies in this fictional scenario to new personal-loan and consumer-credit applications.",
        "confidence": 0.8,
        "ambiguities": [
          "Illustrative source language requires human confirmation."
        ],
        "source_label": "synthetic_demo_source",
        "status": "needs_review"
      }
    ],
    "findings": [
      {
        "obligation_id": "OBL-001",
        "status": "requires_human_review",
        "matching_policy_provision": null,
        "circular_citation": {
          "document_id": "44b779e11de57f3100f206973232b84cf4c35534457b9b52948f5154ecdf87e7",
          "filename": "CIDAN_Synthetic_RBI_Style_Loan_Approval_Circular_8_pages.pdf",
          "document_type": "circular",
          "page": 3,
          "excerpt": "Applies in this fictional scenario to new personal-loan and consumer-credit applications.",
          "chunk_id": "5a7176c897136cf1ca2162d383225feda2d521c537b161ce3716f17fc49c05c2"
        },
        "policy_citations": [],
        "reasoning": "The retrieved handbook evidence is insufficient to confirm policy coverage.",
        "missing_or_inconsistent": "Coverage cannot be determined from the retrieved passages.",
        "operational_impact": "A reviewer should check the full handbook before drawing conclusions.",
        "recommended_action": "Review the cited circular and relevant handbook sections.",
        "confidence": 0.4,
        "evidence_limitations": [
          "The finding is based on retrieved passages, not a complete legal review."
        ]
      }
    ],
    "proposals": [],
    "tests": [],
    "report": {
      "report_id": "CIDAN-20261026105955000000",
      "generated_at_utc": "2026-10-26T05:29:55.000000+00:00",
      "source_status": "synthetic_demo_source",
      "disclaimer": "Synthetic demo only; not an official RBI circular or legal advice.",
      "narrative": {
        "executive_summary": "Extracted 1 obligations and generated 1 policy findings. 0 draft rules were generated; 0 of 0 synthetic tests passed.",
        "operational_impact": "1 policy findings require or recommend human review. This report does not determine legal compliance or production readiness.",
        "recommended_human_review_actions": [
          "Review the cited circular and relevant handbook sections."
        ],
        "evidence_limitations": [
          "The finding is based on retrieved passages, not a complete legal review.",
          "Illustrative source language requires human confirmation."
        ],
        "deployment_readiness_assessment": "Not assessed for production deployment; human review is required."
      },
      "metrics": {
        "obligations_extracted": 1,
        "policy_findings": 1,
        "policy_mapping_status_counts": {
          "requires_human_review": 1
        },
        "draft_rules_generated": 0,
        "tests_total": 0,
        "tests_passed": 0,
        "tests_failed": 0,
        "tests_skipped": 0,
        "tests_invalid": 0,
        "test_pass_rate": null
      },
      "proposed_rules": [],
      "tests": [],
      "approval_required": true
    },
    "report_files": {
      "json": "/var/data/outputs/reports/7d19481b-2d2b-4bb4-96b8-35eaf0693df1/validation_report.json",
      "markdown": "/var/data/outputs/reports/7d19481b-2d2b-4bb4-96b8-35eaf0693df1/validation_report.md"
    }
  };
}

class ObligationItem {
  final String obligationId;
  final String clauseId;
  final String text;
  final String applicability;
  final String productType;
  final String? amountThreshold;
  final String? currency;
  final String effectiveDate;
  final String responsibleFunction;
  final String requiredAction;
  final String deadlineOrFrequency;
  final List<dynamic> exceptions;
  final DocumentSource? source;
  final String supportingExcerpt;
  final double confidence;
  final List<String> ambiguities;
  final String sourceLabel;
  final String status;

  const ObligationItem({
    required this.obligationId,
    required this.clauseId,
    required this.text,
    required this.applicability,
    required this.productType,
    this.amountThreshold,
    this.currency,
    required this.effectiveDate,
    required this.responsibleFunction,
    required this.requiredAction,
    required this.deadlineOrFrequency,
    required this.exceptions,
    this.source,
    required this.supportingExcerpt,
    required this.confidence,
    required this.ambiguities,
    required this.sourceLabel,
    required this.status,
  });

  factory ObligationItem.fromJson(Map<String, dynamic> json) {
    return ObligationItem(
      obligationId: json['obligation_id']?.toString() ?? 'OBL-001',
      clauseId: json['clause_id']?.toString() ?? 'not_specified',
      text: json['text']?.toString() ?? '',
      applicability: json['applicability']?.toString() ?? '',
      productType: json['product_type']?.toString() ?? 'Banking / Loan',
      amountThreshold: json['amount_threshold']?.toString(),
      currency: json['currency']?.toString(),
      effectiveDate: json['effective_date']?.toString() ?? 'not_specified',
      responsibleFunction: json['responsible_function']?.toString() ?? 'Bank',
      requiredAction: json['required_action']?.toString() ?? '',
      deadlineOrFrequency: json['deadline_or_frequency']?.toString() ?? 'not_specified',
      exceptions: json['exceptions'] as List? ?? [],
      source: json['source'] != null ? DocumentSource.fromJson(json['source'] as Map<String, dynamic>) : null,
      supportingExcerpt: json['supporting_excerpt']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      ambiguities: (json['ambiguities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sourceLabel: json['source_label']?.toString() ?? '',
      status: json['status']?.toString() ?? 'needs_review',
    );
  }
}

class FindingItem {
  final String obligationId;
  final String status;
  final String? matchingPolicyProvision;
  final DocumentSource? circularCitation;
  final List<dynamic> policyCitations;
  final String reasoning;
  final String missingOrInconsistent;
  final String operationalImpact;
  final String recommendedAction;
  final double confidence;
  final List<String> evidenceLimitations;

  const FindingItem({
    required this.obligationId,
    required this.status,
    this.matchingPolicyProvision,
    this.circularCitation,
    required this.policyCitations,
    required this.reasoning,
    required this.missingOrInconsistent,
    required this.operationalImpact,
    required this.recommendedAction,
    required this.confidence,
    required this.evidenceLimitations,
  });

  factory FindingItem.fromJson(Map<String, dynamic> json) {
    return FindingItem(
      obligationId: json['obligation_id']?.toString() ?? 'OBL-001',
      status: json['status']?.toString() ?? 'requires_human_review',
      matchingPolicyProvision: json['matching_policy_provision']?.toString(),
      circularCitation: json['circular_citation'] != null
          ? DocumentSource.fromJson(json['circular_citation'] as Map<String, dynamic>)
          : null,
      policyCitations: json['policy_citations'] as List? ?? [],
      reasoning: json['reasoning']?.toString() ?? '',
      missingOrInconsistent: json['missing_or_inconsistent']?.toString() ?? '',
      operationalImpact: json['operational_impact']?.toString() ?? '',
      recommendedAction: json['recommended_action']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.4,
      evidenceLimitations: (json['evidence_limitations'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class DocumentSource {
  final String documentId;
  final String filename;
  final String documentType;
  final int page;
  final String excerpt;
  final String chunkId;

  const DocumentSource({
    required this.documentId,
    required this.filename,
    required this.documentType,
    required this.page,
    required this.excerpt,
    required this.chunkId,
  });

  factory DocumentSource.fromJson(Map<String, dynamic> json) {
    return DocumentSource(
      documentId: json['document_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      documentType: json['document_type']?.toString() ?? 'circular',
      page: (json['page'] as num?)?.toInt() ?? 1,
      excerpt: json['excerpt']?.toString() ?? '',
      chunkId: json['chunk_id']?.toString() ?? '',
    );
  }
}

class ReportSummary {
  final String reportId;
  final String generatedAtUtc;
  final String sourceStatus;
  final String disclaimer;
  final Narrative narrative;
  final ReportMetrics metrics;
  final bool approvalRequired;

  const ReportSummary({
    required this.reportId,
    required this.generatedAtUtc,
    required this.sourceStatus,
    required this.disclaimer,
    required this.narrative,
    required this.metrics,
    required this.approvalRequired,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      reportId: json['report_id']?.toString() ?? 'CIDAN-20261026105955000000',
      generatedAtUtc: json['generated_at_utc']?.toString() ?? '',
      sourceStatus: json['source_status']?.toString() ?? 'synthetic_demo_source',
      disclaimer: json['disclaimer']?.toString() ?? '',
      narrative: Narrative.fromJson(json['narrative'] as Map<String, dynamic>? ?? {}),
      metrics: ReportMetrics.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
      approvalRequired: json['approval_required'] == true,
    );
  }
}

class Narrative {
  final String executiveSummary;
  final String operationalImpact;
  final List<String> recommendedHumanReviewActions;
  final List<String> evidenceLimitations;
  final String deploymentReadinessAssessment;

  const Narrative({
    required this.executiveSummary,
    required this.operationalImpact,
    required this.recommendedHumanReviewActions,
    required this.evidenceLimitations,
    required this.deploymentReadinessAssessment,
  });

  factory Narrative.fromJson(Map<String, dynamic> json) {
    return Narrative(
      executiveSummary: json['executive_summary']?.toString() ?? '',
      operationalImpact: json['operational_impact']?.toString() ?? '',
      recommendedHumanReviewActions: (json['recommended_human_review_actions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      evidenceLimitations:
          (json['evidence_limitations'] as List?)?.map((e) => e.toString()).toList() ?? [],
      deploymentReadinessAssessment: json['deployment_readiness_assessment']?.toString() ?? '',
    );
  }
}

class ReportMetrics {
  final int obligationsExtracted;
  final int policyFindings;
  final int requiresHumanReviewCount;
  final int draftRulesGenerated;
  final int testsTotal;
  final int testsPassed;
  final int testsFailed;
  final int testsSkipped;
  final int testsInvalid;
  final double? testPassRate;

  const ReportMetrics({
    required this.obligationsExtracted,
    required this.policyFindings,
    required this.requiresHumanReviewCount,
    required this.draftRulesGenerated,
    required this.testsTotal,
    required this.testsPassed,
    required this.testsFailed,
    required this.testsSkipped,
    required this.testsInvalid,
    this.testPassRate,
  });

  factory ReportMetrics.fromJson(Map<String, dynamic> json) {
    final mappingCounts = json['policy_mapping_status_counts'] as Map<String, dynamic>? ?? {};
    return ReportMetrics(
      obligationsExtracted: (json['obligations_extracted'] as num?)?.toInt() ?? 1,
      policyFindings: (json['policy_findings'] as num?)?.toInt() ?? 1,
      requiresHumanReviewCount: (mappingCounts['requires_human_review'] as num?)?.toInt() ?? 1,
      draftRulesGenerated: (json['draft_rules_generated'] as num?)?.toInt() ?? 0,
      testsTotal: (json['tests_total'] as num?)?.toInt() ?? 0,
      testsPassed: (json['tests_passed'] as num?)?.toInt() ?? 0,
      testsFailed: (json['tests_failed'] as num?)?.toInt() ?? 0,
      testsSkipped: (json['tests_skipped'] as num?)?.toInt() ?? 0,
      testsInvalid: (json['tests_invalid'] as num?)?.toInt() ?? 0,
      testPassRate: (json['test_pass_rate'] as num?)?.toDouble(),
    );
  }
}

class TestCaseItem {
  final String id;
  final String name;
  final String status;
  final String? resultDetails;

  const TestCaseItem({
    required this.id,
    required this.name,
    required this.status,
    this.resultDetails,
  });

  factory TestCaseItem.fromJson(Map<String, dynamic> json) {
    return TestCaseItem(
      id: json['id']?.toString() ?? 'TC-001',
      name: json['name']?.toString() ?? 'Loan Eligibility Verification',
      status: json['status']?.toString() ?? 'passed',
      resultDetails: json['result_details']?.toString(),
    );
  }
}

class ReportFiles {
  final String jsonPath;
  final String markdownPath;

  const ReportFiles({
    required this.jsonPath,
    required this.markdownPath,
  });

  factory ReportFiles.fromJson(Map<String, dynamic> json) {
    return ReportFiles(
      jsonPath: json['json']?.toString() ?? '',
      markdownPath: json['markdown']?.toString() ?? '',
    );
  }
}
