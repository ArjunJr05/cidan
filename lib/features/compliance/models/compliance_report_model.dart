/// Complete model representing CIDAN Virtusa Agent Workflow Analysis Output.
class ComplianceReportModel {
  /// Unique identifier of the regulatory compliance workflow run.
  final String workflowId;

  /// Current workflow stage (e.g. awaiting_human_review, completed).
  final String stage;

  /// Optional error message if the workflow encountered an issue.
  final String? error;

  /// List of regulatory obligations extracted from the circular.
  final List<ObligationItem> obligations;

  /// List of policy gap and compliance control findings.
  final List<FindingItem> findings;

  /// Rule delta proposals staged for review.
  final List<dynamic> proposals;

  /// Sandbox verification testcases executed against bank policies.
  final List<TestCaseItem> tests;

  /// Executive summary and audit metadata.
  final ReportSummary report;

  /// Output report file paths on disk.
  final ReportFiles? reportFiles;

  /// Raw JSON payload returned by the Virtusa compliance agent.
  final Map<String, dynamic> rawJson;

  /// Creates a new [ComplianceReportModel] instance.
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

/// Individual regulatory obligation extracted from circular.
class ObligationItem {
  /// Unique obligation identifier (e.g. OBL-001).
  final String obligationId;

  /// Clause or section reference in circular.
  final String clauseId;

  /// Obligation requirement text.
  final String text;

  /// Scope of applicability.
  final String applicability;

  /// Product sector (e.g. Personal Loan & Consumer Credit).
  final String productType;

  /// Optional monetary threshold.
  final String? amountThreshold;

  /// Currency code (e.g. INR).
  final String? currency;

  /// Effective compliance date.
  final String effectiveDate;

  /// Responsible department or function.
  final String responsibleFunction;

  /// Required operational action.
  final String requiredAction;

  /// Deadline or recurrence frequency.
  final String deadlineOrFrequency;

  /// Stated regulatory exceptions.
  final List<dynamic> exceptions;

  /// Source circular citation.
  final DocumentSource? source;

  /// Supporting text excerpt.
  final String supportingExcerpt;

  /// Model extraction confidence score (0.0 to 1.0).
  final double confidence;

  /// Potential semantic ambiguities.
  final List<String> ambiguities;

  /// Source label citation.
  final String sourceLabel;

  /// Obligation audit status.
  final String status;

  /// Creates a new [ObligationItem].
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

/// Compliance gap or policy provision finding item.
class FindingItem {
  /// Reference obligation ID.
  final String obligationId;

  /// Audit finding status.
  final String status;

  /// Matching provision from underwriting handbook if found.
  final String? matchingPolicyProvision;

  /// Circular source citation.
  final DocumentSource? circularCitation;

  /// Internal policy handbook citations.
  final List<dynamic> policyCitations;

  /// Reasoning justifying the finding.
  final String reasoning;

  /// Identified inconsistency or gap description.
  final String missingOrInconsistent;

  /// Estimated operational impact.
  final String operationalImpact;

  /// Recommended remediation action.
  final String recommendedAction;

  /// Model finding confidence score.
  final double confidence;

  /// Limitations in supporting evidence.
  final List<String> evidenceLimitations;

  /// Creates a new [FindingItem].
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

/// Regulatory document citation source reference.
class DocumentSource {
  /// Document unique ID.
  final String documentId;

  /// Name of circular file.
  final String filename;

  /// Type of document (e.g. circular, policy).
  final String documentType;

  /// Page number in circular.
  final int page;

  /// Text excerpt cited.
  final String excerpt;

  /// Chunk ID from vector database.
  final String chunkId;

  /// Creates a new [DocumentSource].
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

/// Summary metadata and aggregated audit results.
class ReportSummary {
  /// Unique compliance report ID.
  final String reportId;

  /// UTC generation timestamp.
  final String generatedAtUtc;

  /// Processing status of the source circular.
  final String sourceStatus;

  /// Regulatory disclaimer note.
  final String disclaimer;

  /// Narrative analysis text.
  final Narrative narrative;

  /// Quantitative compliance audit metrics.
  final ReportMetrics metrics;

  /// Whether executive compliance officer sign-off is needed.
  final bool approvalRequired;

  /// Creates a new [ReportSummary].
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

/// Executive narrative synthesis generated by AI agent.
class Narrative {
  /// Executive summary paragraph.
  final String executiveSummary;

  /// High-level operational impact.
  final String operationalImpact;

  /// Actions recommended for human compliance reviewer.
  final List<String> recommendedHumanReviewActions;

  /// Limitations in provided source evidence.
  final List<String> evidenceLimitations;

  /// Readiness assessment for sanctioning.
  final String deploymentReadinessAssessment;

  /// Creates a new [Narrative].
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

/// Key quantitative audit metrics and test pass counts.
class ReportMetrics {
  /// Total obligations extracted.
  final int obligationsExtracted;

  /// Policy findings discovered.
  final int policyFindings;

  /// Number of findings requiring human review.
  final int requiresHumanReviewCount;

  /// Number of rule deltas generated.
  final int draftRulesGenerated;

  /// Total sandbox backtests executed.
  final int testsTotal;

  /// Backtests passed.
  final int testsPassed;

  /// Backtests failed.
  final int testsFailed;

  /// Backtests skipped.
  final int testsSkipped;

  /// Backtests with invalid syntax.
  final int testsInvalid;

  /// Overall pass rate (0.0 to 1.0).
  final double? testPassRate;

  /// Creates a new [ReportMetrics].
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

/// Sandbox backtest scenario verification item.
class TestCaseItem {
  /// Test case identifier (e.g. TC-001).
  final String id;

  /// Name of test scenario.
  final String name;

  /// Test outcome status (e.g. passed, failed).
  final String status;

  /// Detailed test logs or diagnostic output.
  final String? resultDetails;

  /// Creates a new [TestCaseItem].
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
