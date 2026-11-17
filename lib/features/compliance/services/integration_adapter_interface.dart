import '../models/bank_integration_model.dart';
import '../models/existing_rule_model.dart';
import 'api_integration_adapter.dart';
import 'nosql_integration_adapter.dart';
import 'sql_integration_adapter.dart';

/// Uniform adapter interface across all bank integration sources
/// (REST, GraphQL, SQL, NoSQL).
abstract class IntegrationAdapter {
  /// Test connectivity, authentication, and endpoint accessibility.
  /// Flutter delegates actual connection tests to the backend adapter
  /// so that no direct database sockets are opened from client devices.
  Future<ConnectionVerificationResult> testConnection(
    IntegrationSourceModel source, {
    String? bankId,
  });

  /// Inspect the target schema, tables, collections, or API paths.
  Future<Map<String, dynamic>> inspectSchema(
    IntegrationSourceModel source,
  );

  /// Fetch a read-only sample of existing rules for validation.
  Future<List<ExistingRuleModel>> fetchRules(
    IntegrationSourceModel source, {
    int limit = 10,
    String? bankId,
  });

  /// Normalize heterogeneous raw payloads (SQL rows, JSON documents,
  /// GraphQL nodes) into standard [ExistingRuleModel] instances.
  List<ExistingRuleModel> normalizeRules(
    dynamic rawData, {
    required String bankId,
    required String sourceId,
  });
}

/// Factory resolving the appropriate [IntegrationAdapter] for a given source type.
class IntegrationAdapterFactory {
  IntegrationAdapterFactory._();

  static IntegrationAdapter getAdapter(String sourceType) {
    final upper = sourceType.toUpperCase();
    if (upper == 'REST_API' || upper == 'REST' || upper == 'GRAPHQL') {
      return ApiIntegrationAdapter();
    } else if (upper == 'MONGODB' ||
        upper == 'CASSANDRA' ||
        upper == 'DYNAMODB' ||
        upper == 'REDIS') {
      return NoSqlIntegrationAdapter();
    } else {
      return SqlIntegrationAdapter();
    }
  }
}
