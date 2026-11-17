class ValidationFinding {
  final String id;
  final String? bankId;
  final String? ruleIrId;
  final String? deltaId;
  final String validationType; // STRUCTURAL, LOGICAL, REGULATORY
  final String severity; // ERROR, WARNING, INFO
  final String ruleCode;
  final String message;
  final Map<String, dynamic> details;

  const ValidationFinding({
    required this.id,
    this.bankId,
    this.ruleIrId,
    this.deltaId,
    required this.validationType,
    required this.severity,
    required this.ruleCode,
    required this.message,
    this.details = const {},
  });

  factory ValidationFinding.fromJson(Map<String, dynamic> json) {
    return ValidationFinding(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String?,
      ruleIrId: json['rule_ir_id'] as String?,
      deltaId: json['delta_id'] as String?,
      validationType: json['validation_type'] as String? ?? 'STRUCTURAL',
      severity: json['severity'] as String? ?? 'INFO',
      ruleCode: json['rule_code'] as String? ?? 'RULE_CODE',
      message: json['message'] as String? ?? '',
      details: json['details'] is Map<String, dynamic>
          ? json['details'] as Map<String, dynamic>
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (bankId != null) 'bank_id': bankId,
      if (ruleIrId != null) 'rule_ir_id': ruleIrId,
      if (deltaId != null) 'delta_id': deltaId,
      'validation_type': validationType,
      'severity': severity,
      'rule_code': ruleCode,
      'message': message,
      'details': details,
    };
  }
}
