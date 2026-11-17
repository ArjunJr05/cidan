import '../models/bank_integration_model.dart';
import '../models/existing_rule_model.dart';
import 'cidan_api_service.dart';
import 'integration_adapter_interface.dart';

/// Adapter for REST API and GraphQL integration sources.
class ApiIntegrationAdapter implements IntegrationAdapter {
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
    final rules = await _apiService.fetchRulesViaBackend(
      source,
      limit: limit,
      bankId: bankId,
    );
    return rules;
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
        final item = rawData[i];
        if (item is Map) {
          normalized.add(ExistingRuleModel(
            id: 'rule-api-$sourceId-$i-${DateTime.now().millisecondsSinceEpoch}',
            bankId: bankId,
            sourceType: 'INTEGRATION',
            sourceId: sourceId,
            ruleCode: item['code']?.toString() ??
                item['rule_id']?.toString() ??
                item['id']?.toString() ??
                'RULE-API-$i',
            ruleTitle: item['title']?.toString() ??
                item['name']?.toString() ??
                'External API Rule #$i',
            ruleContent: item['description']?.toString() ??
                item['content']?.toString() ??
                item.toString(),
            fileFormat: 'JSON',
            metadata: Map<String, dynamic>.from(item),
            createdAt: DateTime.now(),
          ));
        }
      }
    }
    return normalized;
  }
}
