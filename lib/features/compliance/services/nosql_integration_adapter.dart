import '../models/bank_integration_model.dart';
import '../models/existing_rule_model.dart';
import 'cidan_api_service.dart';
import 'integration_adapter_interface.dart';

/// Adapter for NoSQL Database sources (MongoDB, Cassandra, DynamoDB, Redis).
/// Note: Flutter clients never connect directly to NoSQL instances (e.g. 27017, 9042, 6379);
/// all queries and verifications are securely routed via backend proxies with credential isolation.
class NoSqlIntegrationAdapter implements IntegrationAdapter {
  final CidanApiService _apiService = CidanApiService();

  @override
  Future<ConnectionVerificationResult> testConnection(
    IntegrationSourceModel source, {
    String? bankId,
  }) async {
    return await _apiService.verifySourceViaBackend(source, bankId: bankId);
  }

  @override
  Future<Map<String, dynamic>> inspectSchema(
    IntegrationSourceModel source,
  ) async {
    return await _apiService.inspectSchemaViaBackend(source);
  }

  @override
  Future<List<ExistingRuleModel>> fetchRules(
    IntegrationSourceModel source, {
    int limit = 10,
    String? bankId,
  }) async {
    return await _apiService.fetchRulesViaBackend(
      source,
      limit: limit,
      bankId: bankId,
    );
  }

  @override
  List<ExistingRuleModel> normalizeRules(
    dynamic rawData, {
    required String bankId,
    required String sourceId,
  }) {
    final List<ExistingRuleModel> normalized = [];
    if (rawData is List) {
      for (int i = 0; i < rawData.length; i++) {
        final doc = rawData[i];
        if (doc is Map) {
          normalized.add(ExistingRuleModel(
            id: 'rule-nosql-$sourceId-$i-${DateTime.now().millisecondsSinceEpoch}',
            bankId: bankId,
            sourceType: 'INTEGRATION',
            sourceId: sourceId,
            ruleCode: doc['rule_code']?.toString() ??
                doc['_id']?.toString() ??
                doc['partition_key']?.toString() ??
                'NOSQL-RULE-$i',
            ruleTitle: doc['rule_title']?.toString() ??
                doc['title']?.toString() ??
                'NoSQL Policy #$i',
            ruleContent: doc['rule_content']?.toString() ??
                doc['body']?.toString() ??
                doc.toString(),
            fileFormat: 'JSON',
            metadata: Map<String, dynamic>.from(doc),
            createdAt: DateTime.now(),
          ));
        }
      }
    }
    return normalized;
  }
}
