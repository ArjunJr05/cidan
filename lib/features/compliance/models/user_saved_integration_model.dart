import 'dart:convert';
import 'bank_integration_model.dart';

/// Represents a verified banking integration saved to Supabase with user credentials.
class UserSavedIntegrationModel {
  final String id;
  final String userEmail;
  final String bankName;
  final String bankCode;
  final String integrationName;
  final String environment; // 'DEVELOPMENT', 'UAT', 'PRODUCTION'
  final String sourceType; // 'REST_API', 'GRAPHQL', 'POSTGRESQL', 'MYSQL', 'MONGODB', 'REDIS'
  final Map<String, dynamic> configMetadata;
  final String? credentialRef; // Password, token, or api key
  final Map<String, dynamic> sslConfig;
  final String status; // 'ACTIVE', 'VERIFIED', 'FAILED'
  final bool isSelected; // Active connection chosen for rule extraction
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSavedIntegrationModel({
    required this.id,
    required this.userEmail,
    this.bankName = 'Apex Federal Reserve',
    this.bankCode = 'apex-bank-01',
    required this.integrationName,
    this.environment = 'PRODUCTION',
    required this.sourceType,
    required this.configMetadata,
    this.credentialRef,
    this.sslConfig = const {'enabled': true, 'verify_cert': true},
    this.status = 'ACTIVE',
    this.isSelected = true,
    this.lastVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSavedIntegrationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['config_metadata'] != null) {
      if (json['config_metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['config_metadata']);
      } else if (json['config_metadata'] is String) {
        try {
          meta = jsonDecode(json['config_metadata']);
        } catch (_) {}
      }
    }

    Map<String, dynamic> ssl = {'enabled': true, 'verify_cert': true};
    if (json['ssl_config'] != null) {
      if (json['ssl_config'] is Map) {
        ssl = Map<String, dynamic>.from(json['ssl_config']);
      } else if (json['ssl_config'] is String) {
        try {
          ssl = jsonDecode(json['ssl_config']);
        } catch (_) {}
      }
    }

    return UserSavedIntegrationModel(
      id: json['id']?.toString() ?? '',
      userEmail: json['user_email']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? 'Apex Federal Reserve',
      bankCode: json['bank_code']?.toString() ?? 'apex-bank-01',
      integrationName: json['integration_name']?.toString() ?? 'Banking Source',
      environment: json['environment']?.toString() ?? 'PRODUCTION',
      sourceType: json['source_type']?.toString() ?? 'REST_API',
      configMetadata: meta,
      credentialRef: json['credential_ref']?.toString(),
      sslConfig: ssl,
      status: json['status']?.toString() ?? 'ACTIVE',
      isSelected: json['is_selected'] == true || json['is_selected'] == 1,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_email': userEmail,
        'bank_name': bankName,
        'bank_code': bankCode,
        'integration_name': integrationName,
        'environment': environment,
        'source_type': sourceType,
        'config_metadata': configMetadata,
        'credential_ref': credentialRef,
        'ssl_config': sslConfig,
        'status': status,
        'is_selected': isSelected,
        'last_verified_at': lastVerifiedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UserSavedIntegrationModel copyWith({
    String? id,
    String? userEmail,
    String? bankName,
    String? bankCode,
    String? integrationName,
    String? environment,
    String? sourceType,
    Map<String, dynamic>? configMetadata,
    String? credentialRef,
    Map<String, dynamic>? sslConfig,
    String? status,
    bool? isSelected,
    DateTime? lastVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSavedIntegrationModel(
      id: id ?? this.id,
      userEmail: userEmail ?? this.userEmail,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      integrationName: integrationName ?? this.integrationName,
      environment: environment ?? this.environment,
      sourceType: sourceType ?? this.sourceType,
      configMetadata: configMetadata ?? this.configMetadata,
      credentialRef: credentialRef ?? this.credentialRef,
      sslConfig: sslConfig ?? this.sslConfig,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts to IntegrationSourceModel used by rule extraction adapters
  IntegrationSourceModel toIntegrationSourceModel() {
    return IntegrationSourceModel(
      id: id,
      integrationId: id,
      sourceType: sourceType,
      configMetadata: configMetadata,
      credentialRef: credentialRef,
      sslConfig: sslConfig,
      isActive: isSelected,
      lastVerifiedAt: lastVerifiedAt,
      createdAt: createdAt,
    );
  }

  bool get isDatabase =>
      sourceType != 'REST_API' && sourceType != 'GRAPHQL';

  String get displaySubtitle {
    if (isDatabase) {
      final host = configMetadata['host'] ?? '';
      final port = configMetadata['port']?.toString() ?? '';
      final db = configMetadata['database_name'] ??
          configMetadata['database'] ??
          configMetadata['table_or_collection'] ??
          '';
      return port.isNotEmpty ? '$host:$port ($db)' : host.toString();
    } else {
      final baseUrl = configMetadata['base_url'] ?? '';
      final endpoint = configMetadata['endpoint'] ?? '';
      return '$baseUrl$endpoint';
    }
  }
}
