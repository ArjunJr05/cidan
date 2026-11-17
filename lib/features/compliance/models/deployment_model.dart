class DeploymentTarget {
  final String id;
  final String bankId;
  final String name;
  final String targetType;
  final String environment;
  final String? endpointUrl;
  final bool isWritable;
  final bool supportsRollback;
  final List<String> capabilities;
  final String status;

  const DeploymentTarget({
    required this.id,
    required this.bankId,
    required this.name,
    required this.targetType,
    required this.environment,
    this.endpointUrl,
    this.isWritable = false,
    this.supportsRollback = true,
    this.capabilities = const [],
    this.status = 'ACTIVE',
  });

  factory DeploymentTarget.fromJson(Map<String, dynamic> json) {
    return DeploymentTarget(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Deployment Target',
      targetType: json['target_type'] as String? ?? 'REST',
      environment: json['environment'] as String? ?? 'PRODUCTION',
      endpointUrl: json['endpoint_url'] as String?,
      isWritable: json['is_writable'] as bool? ?? false,
      supportsRollback: json['supports_rollback'] as bool? ?? true,
      capabilities: (json['capabilities'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}

class DeploymentPackage {
  final String id;
  final String bankId;
  final String ruleId;
  final String ruleVersion;
  final String versionId;
  final Map<String, dynamic> approvedRuleIr;
  final String? regulatoryReference;
  final List<dynamic> approvalRecords;
  final List<dynamic> validationResults;
  final List<dynamic> testResults;
  final String packageChecksum;
  final String createdBy;
  final DateTime? createdAt;

  const DeploymentPackage({
    required this.id,
    required this.bankId,
    required this.ruleId,
    required this.ruleVersion,
    required this.versionId,
    required this.approvedRuleIr,
    this.regulatoryReference,
    this.approvalRecords = const [],
    this.validationResults = const [],
    this.testResults = const [],
    required this.packageChecksum,
    required this.createdBy,
    this.createdAt,
  });

  factory DeploymentPackage.fromJson(Map<String, dynamic> json) {
    return DeploymentPackage(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      ruleVersion: json['rule_version'] as String? ?? '1.0',
      versionId: json['version_id'] as String? ?? '',
      approvedRuleIr: json['approved_rule_ir'] as Map<String, dynamic>? ?? {},
      regulatoryReference: json['regulatory_reference'] as String?,
      approvalRecords: json['approval_records'] as List<dynamic>? ?? [],
      validationResults: json['validation_results'] as List<dynamic>? ?? [],
      testResults: json['test_results'] as List<dynamic>? ?? [],
      packageChecksum: json['package_checksum'] as String? ?? '',
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

class DeploymentRecord {
  final String id;
  final String bankId;
  final String packageId;
  final String ruleId;
  final String ruleName;
  final String ruleVersion;
  final String targetId;
  final String deploymentMode;
  String status;
  final String? scheduledFor;
  final String deployedBy;
  final Map<String, dynamic> targetResponse;
  final String? postVerificationStatus;
  final String? errorMessage;
  final DateTime? deployedAt;
  final DateTime? createdAt;

  DeploymentRecord({
    required this.id,
    required this.bankId,
    required this.packageId,
    required this.ruleId,
    required this.ruleName,
    required this.ruleVersion,
    required this.targetId,
    required this.deploymentMode,
    required this.status,
    this.scheduledFor,
    required this.deployedBy,
    this.targetResponse = const {},
    this.postVerificationStatus,
    this.errorMessage,
    this.deployedAt,
    this.createdAt,
  });

  factory DeploymentRecord.fromJson(Map<String, dynamic> json) {
    return DeploymentRecord(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      packageId: json['package_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      ruleName: json['rule_name'] as String? ?? '',
      ruleVersion: json['rule_version'] as String? ?? '1.0',
      targetId: json['target_id'] as String? ?? '',
      deploymentMode: json['deployment_mode'] as String? ?? 'MANUAL',
      status: json['status'] as String? ?? 'PREPARING',
      scheduledFor: json['scheduled_for'] as String?,
      deployedBy: json['deployed_by'] as String? ?? '',
      targetResponse: json['target_response'] as Map<String, dynamic>? ?? {},
      postVerificationStatus: json['post_verification_status'] as String?,
      errorMessage: json['error_message'] as String?,
      deployedAt: json['deployed_at'] != null ? DateTime.tryParse(json['deployed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

class RollbackRecord {
  final String id;
  final String bankId;
  final String deploymentId;
  final String ruleId;
  final String deployedVersion;
  final String restoredVersion;
  final String reason;
  final String initiatedBy;
  final String status;
  final Map<String, dynamic> targetVerification;
  final DateTime? rolledBackAt;

  const RollbackRecord({
    required this.id,
    required this.bankId,
    required this.deploymentId,
    required this.ruleId,
    required this.deployedVersion,
    required this.restoredVersion,
    required this.reason,
    required this.initiatedBy,
    required this.status,
    this.targetVerification = const {},
    this.rolledBackAt,
  });

  factory RollbackRecord.fromJson(Map<String, dynamic> json) {
    return RollbackRecord(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      deploymentId: json['deployment_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      deployedVersion: json['deployed_version'] as String? ?? '',
      restoredVersion: json['restored_version'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      initiatedBy: json['initiated_by'] as String? ?? '',
      status: json['status'] as String? ?? 'COMPLETED',
      targetVerification: json['target_verification'] as Map<String, dynamic>? ?? {},
      rolledBackAt: json['rolled_back_at'] != null ? DateTime.tryParse(json['rolled_back_at'] as String) : null,
    );
  }
}
