class VersionDiffItem {
  final String field;
  final String changeType;
  final dynamic oldValue;
  final dynamic newValue;
  final String description;

  const VersionDiffItem({
    required this.field,
    required this.changeType,
    required this.oldValue,
    required this.newValue,
    required this.description,
  });

  factory VersionDiffItem.fromJson(Map<String, dynamic> json) {
    return VersionDiffItem(
      field: json['field'] as String? ?? '',
      changeType: json['change_type'] as String? ?? 'MODIFIED',
      oldValue: json['old_value'],
      newValue: json['new_value'],
      description: json['description'] as String? ?? '',
    );
  }
}

class RuleVersionComparison {
  final String ruleId;
  final String baseVersion;
  final String targetVersion;
  final int totalDifferences;
  final List<VersionDiffItem> differences;
  final bool hasBreakingChanges;
  final String summary;

  const RuleVersionComparison({
    required this.ruleId,
    required this.baseVersion,
    required this.targetVersion,
    required this.totalDifferences,
    required this.differences,
    required this.hasBreakingChanges,
    required this.summary,
  });

  factory RuleVersionComparison.fromJson(Map<String, dynamic> json) {
    final rawDiffs = json['differences'] as List<dynamic>? ?? [];
    final diffs = rawDiffs
        .whereType<Map<String, dynamic>>()
        .map((d) => VersionDiffItem.fromJson(d))
        .toList();

    return RuleVersionComparison(
      ruleId: json['rule_id'] as String? ?? '',
      baseVersion: json['base_version'] as String? ?? '1.0',
      targetVersion: json['target_version'] as String? ?? '1.1',
      totalDifferences: json['total_differences'] as int? ?? 0,
      differences: diffs,
      hasBreakingChanges: json['has_breaking_changes'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
    );
  }
}

class RuleVersion {
  final String id;
  final String ruleId;
  final String bankId;
  final String versionNumber;
  final String? parentVersion;
  final Map<String, dynamic> ruleIrSnapshot;
  final String changeSummary;
  final String changeSource;
  final String? regulatoryReference;
  final String? approvalWorkflowId;
  final String createdBy;
  final bool isActive;
  final DateTime? activationTimestamp;
  final DateTime? createdAt;

  const RuleVersion({
    required this.id,
    required this.ruleId,
    required this.bankId,
    required this.versionNumber,
    this.parentVersion,
    required this.ruleIrSnapshot,
    required this.changeSummary,
    this.changeSource = 'REGULATORY_CIRCULAR',
    this.regulatoryReference,
    this.approvalWorkflowId,
    required this.createdBy,
    this.isActive = false,
    this.activationTimestamp,
    this.createdAt,
  });

  factory RuleVersion.fromJson(Map<String, dynamic> json) {
    return RuleVersion(
      id: json['id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      versionNumber: json['version_number'] as String? ?? '1.0',
      parentVersion: json['parent_version'] as String?,
      ruleIrSnapshot: json['rule_ir_snapshot'] as Map<String, dynamic>? ?? {},
      changeSummary: json['change_summary'] as String? ?? '',
      changeSource: json['change_source'] as String? ?? 'REGULATORY_CIRCULAR',
      regulatoryReference: json['regulatory_reference'] as String?,
      approvalWorkflowId: json['approval_workflow_id'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      activationTimestamp: json['activation_timestamp'] != null
          ? DateTime.tryParse(json['activation_timestamp'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
