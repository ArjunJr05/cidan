class ApprovalStageConfig {
  final String stageName;
  final String requiredRole;
  final bool isMandatory;
  final String? assignedEmail;
  final int deadlineHours;

  const ApprovalStageConfig({
    required this.stageName,
    required this.requiredRole,
    this.isMandatory = true,
    this.assignedEmail,
    this.deadlineHours = 48,
  });

  factory ApprovalStageConfig.fromJson(Map<String, dynamic> json) {
    return ApprovalStageConfig(
      stageName: json['stage_name'] as String? ?? 'Review Stage',
      requiredRole: json['required_role'] as String? ?? 'COMPLIANCE_ANALYST',
      isMandatory: json['is_mandatory'] as bool? ?? true,
      assignedEmail: json['assigned_email'] as String?,
      deadlineHours: json['deadline_hours'] as int? ?? 48,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage_name': stageName,
      'required_role': requiredRole,
      'is_mandatory': isMandatory,
      'assigned_email': assignedEmail,
      'deadline_hours': deadlineHours,
    };
  }
}

class ApprovalDecisionRecord {
  final String id;
  final String workflowId;
  final String bankId;
  final String ruleId;
  final String? deltaId;
  final String stageName;
  final String approverId;
  final String approverEmail;
  final String approverRole;
  final String decision;
  final String comments;
  final String previousStatus;
  final String newStatus;
  final DateTime? decidedAt;

  const ApprovalDecisionRecord({
    required this.id,
    required this.workflowId,
    required this.bankId,
    required this.ruleId,
    this.deltaId,
    required this.stageName,
    required this.approverId,
    required this.approverEmail,
    required this.approverRole,
    required this.decision,
    this.comments = '',
    required this.previousStatus,
    required this.newStatus,
    this.decidedAt,
  });

  factory ApprovalDecisionRecord.fromJson(Map<String, dynamic> json) {
    return ApprovalDecisionRecord(
      id: json['id'] as String? ?? '',
      workflowId: json['workflow_id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      deltaId: json['delta_id'] as String?,
      stageName: json['stage_name'] as String? ?? 'Stage',
      approverId: json['approver_id'] as String? ?? '',
      approverEmail: json['approver_email'] as String? ?? '',
      approverRole: json['approver_role'] as String? ?? 'COMPLIANCE_ANALYST',
      decision: json['decision'] as String? ?? 'APPROVED',
      comments: json['comments'] as String? ?? '',
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      decidedAt: json['decided_at'] != null ? DateTime.tryParse(json['decided_at'] as String) : null,
    );
  }
}

class ApprovalWorkflow {
  final String id;
  final String bankId;
  final String? deltaId;
  final String ruleId;
  final String ruleName;
  final String category;
  final String? circularReference;
  final String authorId;
  final String authorEmail;
  String status;
  int currentStageIndex;
  final List<ApprovalStageConfig> requiredStages;
  final Map<String, dynamic> ruleIrSnapshot;
  final DateTime? deadline;
  final String? rejectionReason;
  final String? changeRequestNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ApprovalWorkflow({
    required this.id,
    required this.bankId,
    this.deltaId,
    required this.ruleId,
    required this.ruleName,
    this.category = 'GENERAL',
    this.circularReference,
    required this.authorId,
    required this.authorEmail,
    required this.status,
    this.currentStageIndex = 0,
    this.requiredStages = const [],
    this.ruleIrSnapshot = const {},
    this.deadline,
    this.rejectionReason,
    this.changeRequestNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory ApprovalWorkflow.fromJson(Map<String, dynamic> json) {
    final rawStages = json['required_stages'] as List<dynamic>? ?? [];
    final stages = rawStages
        .whereType<Map<String, dynamic>>()
        .map((s) => ApprovalStageConfig.fromJson(s))
        .toList();

    return ApprovalWorkflow(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      deltaId: json['delta_id'] as String?,
      ruleId: json['rule_id'] as String? ?? '',
      ruleName: json['rule_name'] as String? ?? 'Untitled Rule',
      category: json['category'] as String? ?? 'GENERAL',
      circularReference: json['circular_reference'] as String?,
      authorId: json['author_id'] as String? ?? '',
      authorEmail: json['author_email'] as String? ?? '',
      status: json['status'] as String? ?? 'DRAFT',
      currentStageIndex: json['current_stage_index'] as int? ?? 0,
      requiredStages: stages,
      ruleIrSnapshot: json['rule_ir_snapshot'] as Map<String, dynamic>? ?? {},
      deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
      rejectionReason: json['rejection_reason'] as String?,
      changeRequestNotes: json['change_request_notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}
