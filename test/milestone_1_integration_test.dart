import 'package:flutter_test/flutter_test.dart';
import 'package:cidan/cidan.dart';
import 'package:cidan/features/compliance/services/api_integration_adapter.dart';
import 'package:cidan/features/compliance/services/nosql_integration_adapter.dart';
import 'package:cidan/features/compliance/services/sql_integration_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1: Models & Serialization Tests', () {
    test('1. BankModel toJson & fromJson', () {
      final now = DateTime.now();
      final bank = BankModel(
        id: 'bank-001',
        name: 'Apex Global Bank',
        bankCode: 'AGB-9021',
        createdAt: now,
      );

      final json = bank.toJson();
      expect(json['id'], equals('bank-001'));
      expect(json['name'], equals('Apex Global Bank'));
      expect(json['bank_code'], equals('AGB-9021'));

      final parsed = BankModel.fromJson(json);
      expect(parsed.id, equals('bank-001'));
      expect(parsed.name, equals('Apex Global Bank'));
      expect(parsed.bankCode, equals('AGB-9021'));
    });

    test('2. BankIntegrationModel & IntegrationSourceModel', () {
      final now = DateTime.now();
      final source = IntegrationSourceModel(
        id: 'src-01',
        integrationId: 'intg-01',
        sourceType: 'ORACLE',
        configMetadata: {
          'host': 'oracle.internal',
          'port': 1521,
          'database_name': 'core_bank',
        },
        credentialRef: 'vault://tokens/oracle-ro',
        createdAt: now,
      );

      final json = source.toJson();
      expect(json['source_type'], equals('ORACLE'));
      expect(json['credential_ref'], equals('vault://tokens/oracle-ro'));

      final parsedSource = IntegrationSourceModel.fromJson(json);
      expect(parsedSource.sourceType, equals('ORACLE'));
      expect(parsedSource.configMetadata['port'], equals(1521));

      final intg = BankIntegrationModel(
        id: 'intg-01',
        bankId: 'bank-01',
        name: 'Production Gateway',
        environment: 'PRODUCTION',
        integrationType: 'SQL',
        status: 'ACTIVE',
        createdAt: now,
        sources: [parsedSource],
      );

      expect(intg.sources.length, equals(1));
      expect(intg.sources.first.sourceType, equals('ORACLE'));
    });

    test('3. ConnectionVerificationResult success & failure states', () {
      final success = ConnectionVerificationResult(
        id: 'verif-01',
        sourceId: 'src-01',
        verificationStatus: 'SUCCESS',
        responseTimeMs: 42,
        sampleData: {'rules_count': 5},
        verifiedAt: DateTime.now(),
      );
      expect(success.isSuccess, isTrue);

      final failure = ConnectionVerificationResult(
        id: 'verif-02',
        sourceId: 'src-01',
        verificationStatus: 'FAILED',
        responseTimeMs: 120,
        errorMessage: 'Network timeout',
        verifiedAt: DateTime.now(),
      );
      expect(failure.isSuccess, isFalse);
      expect(failure.errorMessage, contains('timeout'));
    });

    test('4. ExistingRuleModel & RegulatoryDocumentModel serialization', () {
      final rule = ExistingRuleModel(
        id: 'r-01',
        bankId: 'bank-01',
        sourceType: 'FILE',
        ruleCode: 'RULE-KYC-01',
        ruleTitle: 'Customer Due Diligence',
        ruleContent: 'Mandatory PAN verification for deposits > 50,000 INR',
        fileFormat: 'PDF',
        createdAt: DateTime.now(),
      );

      final rJson = rule.toJson();
      expect(rJson['rule_code'], equals('RULE-KYC-01'));
      final parsedRule = ExistingRuleModel.fromJson(rJson);
      expect(parsedRule.ruleTitle, equals('Customer Due Diligence'));

      final doc = RegulatoryDocumentModel(
        id: 'doc-01',
        bankId: 'bank-01',
        documentName: 'RBI_Master_Direction_2026.pdf',
        issuingAuthority: 'RBI',
        circularNumber: 'RBI/2026-27/84',
        fileFormat: 'PDF',
        createdAt: DateTime.now(),
      );

      final dJson = doc.toJson();
      expect(dJson['issuing_authority'], equals('RBI'));
      final parsedDoc = RegulatoryDocumentModel.fromJson(dJson);
      expect(parsedDoc.circularNumber, equals('RBI/2026-27/84'));
    });
  });

  group('Milestone 1: Integration Adapter Factory Tests', () {
    test('1. Resolves ApiIntegrationAdapter for REST and GraphQL', () {
      final restAdapter = IntegrationAdapterFactory.getAdapter('REST_API');
      expect(restAdapter, isA<ApiIntegrationAdapter>());

      final gqlAdapter = IntegrationAdapterFactory.getAdapter('GRAPHQL');
      expect(gqlAdapter, isA<ApiIntegrationAdapter>());
    });

    test('2. Resolves SqlIntegrationAdapter for SQL sources', () {
      final oracle = IntegrationAdapterFactory.getAdapter('ORACLE');
      expect(oracle, isA<SqlIntegrationAdapter>());

      final postgres = IntegrationAdapterFactory.getAdapter('POSTGRESQL');
      expect(postgres, isA<SqlIntegrationAdapter>());

      final mysql = IntegrationAdapterFactory.getAdapter('MYSQL');
      expect(mysql, isA<SqlIntegrationAdapter>());

      final mssql = IntegrationAdapterFactory.getAdapter('MSSQL');
      expect(mssql, isA<SqlIntegrationAdapter>());
    });

    test('3. Resolves NoSqlIntegrationAdapter for NoSQL sources', () {
      final mongo = IntegrationAdapterFactory.getAdapter('MONGODB');
      expect(mongo, isA<NoSqlIntegrationAdapter>());

      final cassandra = IntegrationAdapterFactory.getAdapter('CASSANDRA');
      expect(cassandra, isA<NoSqlIntegrationAdapter>());

      final dynamo = IntegrationAdapterFactory.getAdapter('DYNAMODB');
      expect(dynamo, isA<NoSqlIntegrationAdapter>());

      final redis = IntegrationAdapterFactory.getAdapter('REDIS');
      expect(redis, isA<NoSqlIntegrationAdapter>());
    });

    test('4. Normalizes SQL raw records into ExistingRuleModel', () {
      final adapter = SqlIntegrationAdapter();
      final normalized = adapter.normalizeRules([
        {
          'rule_code': 'ACC-01',
          'rule_title': 'Minimum Account Balance',
          'rule_content': 'Maintain 5,000 INR average monthly balance',
        }
      ], bankId: 'b-01', sourceId: 's-01');

      expect(normalized.length, equals(1));
      expect(normalized.first.ruleCode, equals('ACC-01'));
      expect(normalized.first.sourceType, equals('INTEGRATION'));
      expect(normalized.first.fileFormat, equals('SQL'));
    });
  });

  group('Milestone 1: SupabaseService In-Memory Store & Persistence', () {
    final svc = SupabaseService();

    test('1. getOrCreateBank stores and retrieves bank', () async {
      final bank = await svc.getOrCreateBank(
        name: 'State Bank of India',
        bankCode: 'SBI-001',
      );
      expect(bank.bankCode, equals('SBI-001'));

      final sameBank = await svc.getOrCreateBank(
        name: 'State Bank of India',
        bankCode: 'SBI-001',
      );
      expect(sameBank.id, equals(bank.id));
    });

    test('2. Saves and queries BankIntegration and IntegrationSources', () async {
      final intg = BankIntegrationModel(
        id: 'test-intg-1',
        bankId: 'bank-test',
        name: 'UAT Integration',
        environment: 'UAT',
        integrationType: 'SQL',
        createdAt: DateTime.now(),
      );
      await svc.saveBankIntegration(intg);

      final src = IntegrationSourceModel(
        id: 'test-src-1',
        integrationId: 'test-intg-1',
        sourceType: 'ORACLE',
        configMetadata: {'host': 'test.bank.internal'},
        createdAt: DateTime.now(),
      );
      await svc.saveIntegrationSource(src);

      final sources = await svc.getIntegrationSources('test-intg-1');
      expect(sources.length, equals(1));
      expect(sources.first.sourceType, equals('ORACLE'));
    });

    test('3. Records and queries ConnectionVerifications audit trail', () async {
      final verif = ConnectionVerificationResult(
        id: 'v-test-1',
        sourceId: 'test-src-1',
        verificationStatus: 'SUCCESS',
        responseTimeMs: 38,
        verifiedAt: DateTime.now(),
      );
      await svc.recordConnectionVerification(verif);

      final history = await svc.getConnectionVerifications('test-src-1');
      expect(history.length, greaterThanOrEqualTo(1));
      expect(history.first.verificationStatus, equals('SUCCESS'));
    });

    test('4. Saves and queries ExistingRules & RegulatoryDocuments', () async {
      final rule = ExistingRuleModel(
        id: 'rule-test-1',
        bankId: 'bank-test',
        sourceType: 'FILE',
        ruleCode: 'RULE-AML-01',
        ruleTitle: 'Suspicious Transaction Reporting',
        ruleContent: 'File STR within 7 days of confirmation',
        createdAt: DateTime.now(),
      );
      await svc.saveExistingRules([rule]);

      final rules = await svc.getExistingRules(bankId: 'bank-test');
      expect(rules.any((r) => r.ruleCode == 'RULE-AML-01'), isTrue);

      final doc = RegulatoryDocumentModel(
        id: 'doc-test-1',
        bankId: 'bank-test',
        documentName: 'RBI_Circular_Digital_Lending.pdf',
        issuingAuthority: 'RBI',
        circularNumber: 'RBI/2026/DL-01',
        fileFormat: 'PDF',
        createdAt: DateTime.now(),
      );
      await svc.saveRegulatoryDocument(doc);

      final docs = await svc.getRegulatoryDocuments(bankId: 'bank-test');
      expect(docs.any((d) => d.circularNumber == 'RBI/2026/DL-01'), isTrue);
    });
  });
}
