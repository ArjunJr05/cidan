import '../models/bank_integration_model.dart';
import '../models/existing_rule_model.dart';
import 'cidan_api_service.dart';
import 'integration_adapter_interface.dart';

/// Adapter for SQL Database sources (PostgreSQL, MySQL, Oracle, Microsoft SQL Server).
/// Note: Flutter clients never connect directly to database ports (e.g. 1521, 5432, 3306, 1433);
/// all queries are securely routed via backend proxies with credential isolation.
class SqlIntegrationAdapter implements IntegrationAdapter {
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
        final row = rawData[i];
        if (row is Map) {
          normalized.add(ExistingRuleModel(
            id: 'rule-sql-$sourceId-$i-${DateTime.now().millisecondsSinceEpoch}',
            bankId: bankId,
            sourceType: 'INTEGRATION',
            sourceId: sourceId,
            ruleCode: row['rule_code']?.toString() ??
                row['policy_code']?.toString() ??
                row['id']?.toString() ??
                'SQL-RULE-$i',
            ruleTitle: row['rule_title']?.toString() ??
                row['policy_name']?.toString() ??
                'Database Rule #$i',
            ruleContent: row['rule_content']?.toString() ??
                row['condition_clause']?.toString() ??
                row.toString(),
            fileFormat: 'SQL',
            metadata: Map<String, dynamic>.from(row),
            createdAt: DateTime.now(),
          ));
        }
      }
    }
    return normalized;
  }
}
