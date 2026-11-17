import 'dart:convert';

/// Represents an existing ingested banking rule or policy constraint.
class ExistingRuleModel {
  final String id;
  final String bankId;
  final String sourceType; // 'FILE' or 'INTEGRATION'
  final String? sourceId;
  final String ruleCode;
  final String ruleTitle;
  final String ruleContent;
  final String? fileFormat; // 'PDF', 'DOCX', 'XLSX', 'JSON', 'XML', 'SQL', 'YAML'
  final String? filePath;
  final int version;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ExistingRuleModel({
    required this.id,
    required this.bankId,
    required this.sourceType,
    this.sourceId,
    required this.ruleCode,
    required this.ruleTitle,
    required this.ruleContent,
    this.fileFormat,
    this.filePath,
    this.version = 1,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ExistingRuleModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['metadata'] != null) {
      if (json['metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['metadata']);
      } else if (json['metadata'] is String) {
        try {
          meta = jsonDecode(json['metadata']);
        } catch (_) {}
      }
    }

    return ExistingRuleModel(
      id: json['id']?.toString() ?? '',
      bankId: json['bank_id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'FILE',
      sourceId: json['source_id']?.toString(),
      ruleCode: json['rule_code']?.toString() ?? '',
      ruleTitle: json['rule_title']?.toString() ?? '',
      ruleContent: json['rule_content']?.toString() ?? '',
      fileFormat: json['file_format']?.toString(),
      filePath: json['file_path']?.toString(),
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      metadata: meta,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_id': bankId,
        'source_type': sourceType,
        'source_id': sourceId,
        'rule_code': ruleCode,
        'rule_title': ruleTitle,
        'rule_content': ruleContent,
        'file_format': fileFormat,
        'file_path': filePath,
        'version': version,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
      };
}
