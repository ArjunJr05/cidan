class DiffItem {
  final String field;
  final dynamic previousValue;
  final dynamic proposedValue;
  final String diffType;

  const DiffItem({
    required this.field,
    required this.previousValue,
    required this.proposedValue,
    required this.diffType,
  });

  factory DiffItem.fromJson(Map<String, dynamic> json) {
    return DiffItem(
      field: json['field'] as String? ?? '',
      previousValue: json['previous_value'],
      proposedValue: json['proposed_value'],
      diffType: json['diff_type'] as String? ?? 'threshold_changed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'previous_value': previousValue,
      'proposed_value': proposedValue,
      'diff_type': diffType,
    };
  }
}

class RuleDelta {
  final String id;
  final String? analysisId;
  final String? bankId;
  final String classification;
  final String category;
  final String ruleName;
  final String? previousRuleId;
  final String? regulatoryObligationId;
  final Map<String, dynamic>? previousRuleRepresentation;
  final Map<String, dynamic>? newRequirementRepresentation;
  final List<DiffItem> identifiedDifferences;
  final Map<String, dynamic> proposedChange;
  final String reason;
  final String impactAssessment;
  final double confidenceScore;
  final List<Map<String, dynamic>> evidenceSources;
  String reviewStatus;
  final DateTime? createdAt;

  RuleDelta({
    required this.id,
    this.analysisId,
    this.bankId,
    required this.classification,
    this.category = 'GENERAL',
    required this.ruleName,
    this.previousRuleId,
    this.regulatoryObligationId,
    this.previousRuleRepresentation,
    this.newRequirementRepresentation,
    this.identifiedDifferences = const [],
    this.proposedChange = const {},
    required this.reason,
    required this.impactAssessment,
    this.confidenceScore = 0.95,
    this.evidenceSources = const [],
    this.reviewStatus = 'PENDING',
    this.createdAt,
  });

  factory RuleDelta.fromJson(Map<String, dynamic> json) {
    final rawDiffs = json['identified_differences'] as List<dynamic>? ?? [];
    final diffs = rawDiffs
        .whereType<Map<String, dynamic>>()
        .map((d) => DiffItem.fromJson(d))
        .toList();

    final rawSources = json['evidence_sources'] as List<dynamic>? ?? [];
    final sources = rawSources.whereType<Map<String, dynamic>>().toList();

    return RuleDelta(
      id: json['id'] as String? ?? '',
      analysisId: json['analysis_id'] as String?,
      bankId: json['bank_id'] as String?,
      classification: json['classification'] as String? ?? 'NO_IMPACT',
      category: json['category'] as String? ?? 'GENERAL',
      ruleName: json['rule_name'] as String? ?? 'Unnamed Rule Delta',
      previousRuleId: json['previous_rule_id'] as String?,
      regulatoryObligationId: json['regulatory_obligation_id'] as String?,
      previousRuleRepresentation:
          json['previous_rule_representation'] as Map<String, dynamic>?,
      newRequirementRepresentation:
          json['new_requirement_representation'] as Map<String, dynamic>?,
      identifiedDifferences: diffs,
      proposedChange: json['proposed_change'] is Map<String, dynamic>
          ? json['proposed_change'] as Map<String, dynamic>
          : {},
      reason: json['reason'] as String? ?? '',
      impactAssessment: json['impact_assessment'] as String? ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
      evidenceSources: sources,
      reviewStatus: json['review_status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (analysisId != null) 'analysis_id': analysisId,
      if (bankId != null) 'bank_id': bankId,
      'classification': classification,
      'category': category,
      'rule_name': ruleName,
      if (previousRuleId != null) 'previous_rule_id': previousRuleId,
      if (regulatoryObligationId != null)
        'regulatory_obligation_id': regulatoryObligationId,
      if (previousRuleRepresentation != null)
        'previous_rule_representation': previousRuleRepresentation,
      if (newRequirementRepresentation != null)
        'new_requirement_representation': newRequirementRepresentation,
      'identified_differences':
          identifiedDifferences.map((d) => d.toJson()).toList(),
      'proposed_change': proposedChange,
      'reason': reason,
      'impact_assessment': impactAssessment,
      'confidence_score': confidenceScore,
      'evidence_sources': evidenceSources,
      'review_status': reviewStatus,
    };
  }
}

class DeltaAnalysisResult {
  final String id;
  final String? bankId;
  final String analysisName;
  final String? circularId;
  final String? circularNumber;
  final String status;
  final int totalRules;
  final int additionsCount;
  final int modificationsCount;
  final int removalsCount;
  final int clarificationsCount;
  final int noImpactCount;
  final int manualReviewCount;
  final String summary;
  final List<RuleDelta> deltas;

  const DeltaAnalysisResult({
    required this.id,
    this.bankId,
    required this.analysisName,
    this.circularId,
    this.circularNumber,
    this.status = 'COMPLETED',
    this.totalRules = 0,
    this.additionsCount = 0,
    this.modificationsCount = 0,
    this.removalsCount = 0,
    this.clarificationsCount = 0,
    this.noImpactCount = 0,
    this.manualReviewCount = 0,
    this.summary = '',
    this.deltas = const [],
  });

  factory DeltaAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawDeltas = json['deltas'] as List<dynamic>? ?? [];
    final deltasList = rawDeltas
        .whereType<Map<String, dynamic>>()
        .map((d) => RuleDelta.fromJson(d))
        .toList();

    return DeltaAnalysisResult(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String?,
      analysisName: json['analysis_name'] as String? ?? 'Delta Analysis',
      circularId: json['circular_id'] as String?,
      circularNumber: json['circular_number'] as String?,
      status: json['status'] as String? ?? 'COMPLETED',
      totalRules: (json['total_rules'] as num?)?.toInt() ?? 0,
      additionsCount: (json['additions_count'] as num?)?.toInt() ?? 0,
      modificationsCount: (json['modifications_count'] as num?)?.toInt() ?? 0,
      removalsCount: (json['removals_count'] as num?)?.toInt() ?? 0,
      clarificationsCount: (json['clarifications_count'] as num?)?.toInt() ?? 0,
      noImpactCount: (json['no_impact_count'] as num?)?.toInt() ?? 0,
      manualReviewCount: (json['manual_review_count'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      deltas: deltasList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (bankId != null) 'bank_id': bankId,
      'analysis_name': analysisName,
      if (circularId != null) 'circular_id': circularId,
      if (circularNumber != null) 'circular_number': circularNumber,
      'status': status,
      'total_rules': totalRules,
      'additions_count': additionsCount,
      'modifications_count': modificationsCount,
      'removals_count': removalsCount,
      'clarifications_count': clarificationsCount,
      'no_impact_count': noImpactCount,
      'manual_review_count': manualReviewCount,
      'summary': summary,
      'deltas': deltas.map((d) => d.toJson()).toList(),
    };
  }
}
