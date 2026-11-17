import 'dart:convert';

/// Represents a registered banking institution or financial enterprise.
class BankModel {
  final String id;
  final String name;
  final String bankCode;
  final DateTime createdAt;

  const BankModel({
    required this.id,
    required this.name,
    required this.bankCode,
    required this.createdAt,
  });

  factory BankModel.fromJson(Map<String, dynamic> json) {
    return BankModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      bankCode: json['bank_code']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bank_code': bankCode,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Represents an integration container for a specific bank and environment.
class BankIntegrationModel {
  final String id;
  final String bankId;
  final String name;
  final String environment; // 'DEVELOPMENT', 'UAT', 'PRODUCTION'
  final String integrationType; // 'REST', 'GRAPHQL', 'SQL', 'NOSQL'
  final String status; // 'ACTIVE', 'PENDING', 'FAILED'
  final DateTime createdAt;
  final List<IntegrationSourceModel> sources;

  const BankIntegrationModel({
    required this.id,
    required this.bankId,
    required this.name,
    required this.environment,
    required this.integrationType,
    this.status = 'PENDING',
    required this.createdAt,
    this.sources = const [],
  });

  factory BankIntegrationModel.fromJson(Map<String, dynamic> json,
      {List<IntegrationSourceModel>? sources}) {
    return BankIntegrationModel(
      id: json['id']?.toString() ?? '',
      bankId: json['bank_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      environment: json['environment']?.toString() ?? 'DEVELOPMENT',
      integrationType: json['integration_type']?.toString() ?? 'REST',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sources: sources ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_id': bankId,
        'name': name,
        'environment': environment,
        'integration_type': integrationType,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  BankIntegrationModel copyWith({
    String? id,
    String? bankId,
    String? name,
    String? environment,
    String? integrationType,
    String? status,
    DateTime? createdAt,
    List<IntegrationSourceModel>? sources,
  }) {
    return BankIntegrationModel(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      name: name ?? this.name,
      environment: environment ?? this.environment,
      integrationType: integrationType ?? this.integrationType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      sources: sources ?? this.sources,
    );
  }
}

/// Represents an individual data or API source within an integration.
class IntegrationSourceModel {
  final String id;
  final String integrationId;
  final String sourceType; // 'POSTGRESQL', 'MYSQL', 'ORACLE', 'MSSQL', 'MONGODB', 'CASSANDRA', 'DYNAMODB', 'REDIS', 'REST_API', 'GRAPHQL'
  final Map<String, dynamic> configMetadata; // host, port, dbName, endpoint, etc.
  final String? credentialRef; // Vault token reference ID (never raw password)
  final Map<String, dynamic> sslConfig;
  final bool isActive;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;

  const IntegrationSourceModel({
    required this.id,
    required this.integrationId,
    required this.sourceType,
    required this.configMetadata,
    this.credentialRef,
    this.sslConfig = const {'enabled': true, 'verify_cert': true},
    this.isActive = true,
    this.lastVerifiedAt,
    required this.createdAt,
  });

  factory IntegrationSourceModel.fromJson(Map<String, dynamic> json) {
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

    return IntegrationSourceModel(
      id: json['id']?.toString() ?? '',
      integrationId: json['integration_id']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'REST_API',
      configMetadata: meta,
      credentialRef: json['credential_ref']?.toString(),
      sslConfig: ssl,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.tryParse(json['last_verified_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'integration_id': integrationId,
        'source_type': sourceType,
        'config_metadata': configMetadata,
        'credential_ref': credentialRef,
        'ssl_config': sslConfig,
        'is_active': isActive,
        'last_verified_at': lastVerifiedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  IntegrationSourceModel copyWith({
    String? id,
    String? integrationId,
    String? sourceType,
    Map<String, dynamic>? configMetadata,
    String? credentialRef,
    Map<String, dynamic>? sslConfig,
    bool? isActive,
    DateTime? lastVerifiedAt,
    DateTime? createdAt,
  }) {
    return IntegrationSourceModel(
      id: id ?? this.id,
      integrationId: integrationId ?? this.integrationId,
      sourceType: sourceType ?? this.sourceType,
      configMetadata: configMetadata ?? this.configMetadata,
      credentialRef: credentialRef ?? this.credentialRef,
      sslConfig: sslConfig ?? this.sslConfig,
      isActive: isActive ?? this.isActive,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Result of a connection verification test.
class ConnectionVerificationResult {
  final String id;
  final String sourceId;
  final String verificationStatus; // 'SUCCESS', 'FAILED'
  final int responseTimeMs;
  final dynamic sampleData;
  final String? errorMessage;
  final DateTime verifiedAt;

  const ConnectionVerificationResult({
    required this.id,
    required this.sourceId,
    required this.verificationStatus,
    required this.responseTimeMs,
    this.sampleData,
    this.errorMessage,
    required this.verifiedAt,
  });

  bool get isSuccess => verificationStatus.toUpperCase() == 'SUCCESS';

  factory ConnectionVerificationResult.fromJson(Map<String, dynamic> json) {
    return ConnectionVerificationResult(
      id: json['id']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      verificationStatus:
          json['verification_status']?.toString() ?? 'FAILED',
      responseTimeMs: json['response_time_ms'] is num
          ? (json['response_time_ms'] as num).toInt()
          : 0,
      sampleData: json['sample_data'],
      errorMessage: json['error_message']?.toString(),
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_id': sourceId,
        'verification_status': verificationStatus,
        'response_time_ms': responseTimeMs,
        'sample_data': sampleData,
        'error_message': errorMessage,
        'verified_at': verifiedAt.toIso8601String(),
      };
}
