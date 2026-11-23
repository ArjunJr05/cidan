import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../models/bank_integration_model.dart';
import '../models/user_saved_integration_model.dart';
import '../services/integration_adapter_interface.dart';

/// Modal dialog for configuring Option B: "Connect with CIDAN".
/// Supports enterprise REST, GraphQL, SQL (Postgres, MySQL),
/// and NoSQL (MongoDB, Redis) with real-time Save & Verify.
class ConnectCidanDialog extends StatefulWidget {
  final String userEmail;
  final UserSavedIntegrationModel? initialIntegration;
  final Function(
          BankIntegrationModel integration, IntegrationSourceModel source)
      onSourceVerified;
  final Function(UserSavedIntegrationModel saved)? onSavedIntegration;

  const ConnectCidanDialog({
    super.key,
    required this.userEmail,
    required this.onSourceVerified,
    this.initialIntegration,
    this.onSavedIntegration,
  });

  @override
  State<ConnectCidanDialog> createState() => _ConnectCidanDialogState();
}

class _ConnectCidanDialogState extends State<ConnectCidanDialog> {
  final _formKey = GlobalKey<FormState>();

  // Bank Info controllers
  late final TextEditingController _bankNameController;
  late final TextEditingController _bankCodeController;
  late final TextEditingController _integrationNameController;
  String _selectedEnvironment = 'PRODUCTION'; // DEVELOPMENT, UAT, PRODUCTION

  // Integration Category & Type
  // 0 = REST API, 1 = GraphQL, 2 = SQL Database, 3 = NoSQL Database
  int _categoryIndex = 0;
  String _sqlEngine = 'POSTGRESQL'; // POSTGRESQL, MYSQL
  String _noSqlEngine = 'MONGODB'; // MONGODB, REDIS

  // API Config Controllers
  late final TextEditingController _baseUrlController;
  late final TextEditingController _endpointController;
  String _httpMethod = 'GET';
  late final TextEditingController _apiVersionController;
  String _authType = 'BEARER'; // BEARER, API_KEY, OAUTH2, BASIC, NONE
  late final TextEditingController _authTokenRefController;
  late final TextEditingController _headersController;
  late final TextEditingController _swaggerUrlController;

  // Database Config Controllers
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _dbNameController;
  late final TextEditingController _schemaController;
  late final TextEditingController _tableController;
  late final TextEditingController _serviceAccountController;
  late final TextEditingController _credentialRefController;
  bool _sslEnabled = true;
  bool _verifyCert = true;

  // JSON Quick Auto-Fill Controller & State
  final _jsonImportController = TextEditingController();
  bool _isJsonImportExpanded = false;

  // Verification State
  bool _isVerifying = false;
  ConnectionVerificationResult? _lastResult;
  String? _stepStatus;

  @override
  void initState() {
    super.initState();
    final init = widget.initialIntegration;

    _bankNameController = TextEditingController(
        text: init?.bankName ?? 'Apex Global Bank');
    _bankCodeController =
        TextEditingController(text: init?.bankCode ?? 'apex-bank-01');
    _integrationNameController = TextEditingController(
        text: init?.integrationName ?? 'Core Banking Compliance Gateway');
    _selectedEnvironment = init?.environment ?? 'PRODUCTION';

    if (init != null) {
      final src = init.sourceType.toUpperCase();
      if (src.contains('REST')) {
        _categoryIndex = 0;
      } else if (src.contains('GRAPHQL')) {
        _categoryIndex = 1;
      } else if (src.contains('POSTGRES') ||
          src.contains('MYSQL') ||
          src == 'SQL') {
        _categoryIndex = 2;
        if (src.contains('MYSQL')) _sqlEngine = 'MYSQL';
        if (src.contains('POSTGRES')) _sqlEngine = 'POSTGRESQL';
      } else if (src.contains('MONGO') ||
          src.contains('REDIS') ||
          src == 'NOSQL') {
        _categoryIndex = 3;
        if (src.contains('MONGO')) _noSqlEngine = 'MONGODB';
        if (src.contains('REDIS')) _noSqlEngine = 'REDIS';
      }

      final meta = init.configMetadata;
      _baseUrlController =
          TextEditingController(text: meta['base_url']?.toString() ?? '');
      _endpointController = TextEditingController(
          text: (meta['endpoint'] ?? meta['rules_endpoint'])?.toString() ?? '');
      _httpMethod = meta['http_method']?.toString().toUpperCase() ?? 'GET';
      _apiVersionController =
          TextEditingController(text: meta['api_version']?.toString() ?? 'v1.4');
      _authType = meta['auth_type']?.toString().toUpperCase() ?? 'BEARER';
      _authTokenRefController = TextEditingController(
          text: init.credentialRef ?? meta['token']?.toString() ?? '');
      _headersController = TextEditingController(
          text: meta['headers'] != null
              ? (meta['headers'] is String
                  ? meta['headers'] as String
                  : jsonEncode(meta['headers']))
              : '{"X-Bank-Client": "CIDAN-Agent"}');
      _swaggerUrlController = TextEditingController(
          text: meta['swagger_spec']?.toString() ?? '');

      _hostController =
          TextEditingController(text: meta['host']?.toString() ?? '');
      _portController = TextEditingController(
          text: meta['port']?.toString() ??
              (_categoryIndex == 2
                  ? _getDefaultPortForSql(_sqlEngine)
                  : _getDefaultPortForNoSql(_noSqlEngine)));
      _dbNameController = TextEditingController(
          text: (meta['database_name'] ?? meta['database'])?.toString() ?? '');
      _schemaController = TextEditingController(
          text: meta['schema']?.toString() ?? 'compliance');
      _tableController = TextEditingController(
          text: (meta['table_or_collection'] ?? meta['table'])?.toString() ??
              'active_rules');
      _serviceAccountController = TextEditingController(
          text: (meta['service_account'] ?? meta['username'])?.toString() ??
              'default');
      _credentialRefController = TextEditingController(
          text: init.credentialRef ?? meta['password']?.toString() ?? '');

      _sslEnabled = init.sslConfig['enabled'] == true;
      _verifyCert = init.sslConfig['verify_cert'] == true;
    } else {
      _baseUrlController =
          TextEditingController(text: 'https://api.apexbank.internal/v1');
      _endpointController =
          TextEditingController(text: '/compliance/rules');
      _apiVersionController = TextEditingController(text: 'v1.4');
      _authTokenRefController =
          TextEditingController(text: 'vault://secrets/cidan-api-key');
      _headersController =
          TextEditingController(text: '{"X-Bank-Client": "CIDAN-Agent"}');
      _swaggerUrlController = TextEditingController();

      _hostController =
          TextEditingController(text: 'db-cluster.apexbank.internal');
      _portController = TextEditingController(text: '5432');
      _dbNameController = TextEditingController(text: 'bank_policies');
      _schemaController = TextEditingController(text: 'compliance');
      _tableController = TextEditingController(text: 'active_rules');
      _serviceAccountController =
          TextEditingController(text: 'svc_cidan_readonly');
      _credentialRefController =
          TextEditingController(text: 'vault://tokens/db-read-key-prod');
    }
  }

  @override
  void dispose() {
    _jsonImportController.dispose();
    _bankNameController.dispose();
    _bankCodeController.dispose();
    _integrationNameController.dispose();
    _baseUrlController.dispose();
    _endpointController.dispose();
    _apiVersionController.dispose();
    _authTokenRefController.dispose();
    _headersController.dispose();
    _swaggerUrlController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _dbNameController.dispose();
    _schemaController.dispose();
    _tableController.dispose();
    _serviceAccountController.dispose();
    _credentialRefController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(int idx) {
    setState(() {
      _categoryIndex = idx;
      _lastResult = null;
      if (idx == 2) {
        _portController.text = _getDefaultPortForSql(_sqlEngine);
      } else if (idx == 3) {
        _portController.text = _getDefaultPortForNoSql(_noSqlEngine);
      }
    });
  }

  String _getDefaultPortForSql(String engine) {
    switch (engine) {
      case 'MYSQL':
        return '3306';
      case 'POSTGRESQL':
      default:
        return '5432';
    }
  }

  String _getDefaultPortForNoSql(String engine) {
    switch (engine) {
      case 'MONGODB':
        return '27017';
      case 'CASSANDRA':
        return '9042';
      case 'REDIS':
        return '6379';
      case 'DYNAMODB':
      default:
        return '443';
    }
  }

  String get _currentSourceType {
    if (_categoryIndex == 0) return 'REST_API';
    if (_categoryIndex == 1) return 'GRAPHQL';
    if (_categoryIndex == 2) return _sqlEngine;
    return _noSqlEngine;
  }

  void _applyJsonConfig() {
    final rawText = _jsonImportController.text.trim();
    final singleLine = rawText.replaceAll('\r', '').replaceAll('\n', '').trim();
    if (singleLine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please paste a configuration JSON or connection URI first.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Direct PostgreSQL / Database connection URI detection (e.g. from Neon "Copy snippet")
    if (singleLine.startsWith('postgres://') ||
        singleLine.startsWith('postgresql://')) {
      try {
        final uri = Uri.parse(singleLine);
        final userInfo = uri.userInfo;
        String user = '';
        String pass = '';
        if (userInfo.contains(':')) {
          final parts = userInfo.split(':');
          user = Uri.decodeComponent(parts[0]);
          pass = Uri.decodeComponent(parts.sublist(1).join(':'));
        } else {
          user = Uri.decodeComponent(userInfo);
        }

        final db = uri.path.replaceAll('/', '');

        setState(() {
          _categoryIndex = 2; // SQL
          _sqlEngine = 'POSTGRESQL';
          _bankNameController.text = 'Apex Global Bank';
          _bankCodeController.text = 'apex-bank-01';
          _integrationNameController.text = 'Neon PostgreSQL Banking Rules DB';
          _hostController.text = uri.host;
          _portController.text =
              (uri.hasPort && uri.port != 0) ? uri.port.toString() : '5432';
          if (db.isNotEmpty) _dbNameController.text = db;
          _schemaController.text = 'compliance';
          _tableController.text = 'banking_rules';
          if (user.isNotEmpty) _serviceAccountController.text = user;
          if (pass.isNotEmpty) _credentialRefController.text = pass;
          _sslEnabled = true;
          _isJsonImportExpanded = false;
          _lastResult = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✓ Extracted all details from Neon connection string successfully!',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } catch (e) {
        // Fall back to JSON decoding
      }
    }

    // Direct Redis connection URI detection (e.g. from Upstash or Redis Cloud or redis-cli)
    if (singleLine.contains('redis://') || singleLine.contains('rediss://')) {
      try {
        final redisMatch =
            RegExp(r'rediss?://[^\s]+').firstMatch(singleLine);
        if (redisMatch != null) {
          final rawRedisUri = redisMatch.group(0)!;
          final cleanUri = rawRedisUri
              .replaceFirst('rediss://', 'http://')
              .replaceFirst('redis://', 'http://');
          final uri = Uri.parse(cleanUri);
          final userInfo = uri.userInfo;
          String user = 'default';
          String pass = '';
          if (userInfo.contains(':')) {
            final parts = userInfo.split(':');
            user = Uri.decodeComponent(parts[0]);
            pass = Uri.decodeComponent(parts.sublist(1).join(':'));
          } else if (userInfo.isNotEmpty) {
            user = Uri.decodeComponent(userInfo);
          }

          setState(() {
            _categoryIndex = 3; // NoSQL
            _noSqlEngine = 'REDIS';
            _bankNameController.text = 'Apex Global Bank';
            _bankCodeController.text = 'apex-bank-01';
            _integrationNameController.text = 'Upstash Redis Rules Cache';
            _hostController.text = uri.host;
            _portController.text =
                (uri.hasPort && uri.port != 0) ? uri.port.toString() : '6379';
            _dbNameController.text = 'rules_cache';
            _schemaController.text = 'compliance';
            _tableController.text = 'active_rules_cache';
            _serviceAccountController.text =
                user.isNotEmpty ? user : 'default';
            if (pass.isNotEmpty) {
              _credentialRefController.text = pass;
            }
            _sslEnabled = true;
            _isJsonImportExpanded = false;
            _lastResult = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✓ Extracted Redis connection details from connection string!',
                style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
              ),
              backgroundColor: Color(0xFF15803D),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      } catch (e) {
        // Fall back to JSON decoding
      }
    }

    // Direct MongoDB connection URI detection (e.g. from Atlas "Copy connection string")
    if (singleLine.startsWith('mongodb://') ||
        singleLine.startsWith('mongodb+srv://')) {
      try {
        final cleanUri = singleLine
            .replaceFirst('mongodb+srv://', 'http://')
            .replaceFirst('mongodb://', 'http://');
        final uri = Uri.parse(cleanUri);
        final userInfo = uri.userInfo;
        String user = '';
        String pass = '';
        if (userInfo.contains(':')) {
          final parts = userInfo.split(':');
          user = Uri.decodeComponent(parts[0]);
          pass = Uri.decodeComponent(parts.sublist(1).join(':'));
        } else {
          user = Uri.decodeComponent(userInfo);
        }

        final db = uri.path.replaceAll('/', '');

        setState(() {
          _categoryIndex = 3; // NoSQL
          _noSqlEngine = 'MONGODB';
          _bankNameController.text = 'Apex Global Bank';
          _bankCodeController.text = 'apex-bank-01';
          _integrationNameController.text =
              'MongoDB Atlas Compliance Document Store';
          _hostController.text = uri.host;
          _portController.text =
              (uri.hasPort && uri.port != 0) ? uri.port.toString() : '27017';
          _dbNameController.text = db.isNotEmpty ? db : 'cidan_bank';
          _schemaController.text = 'compliance';
          _tableController.text = 'compliance_rules';
          if (user.isNotEmpty) _serviceAccountController.text = user;
          if (pass.isNotEmpty &&
              pass != '<db_password>' &&
              pass != '<password>') {
            _credentialRefController.text = pass;
          }
          _sslEnabled = true;
          _isJsonImportExpanded = false;
          _lastResult = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✓ Extracted MongoDB connection details from connection string!',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } catch (e) {
        // Fall back to JSON decoding
      }
    }

    try {
      final dynamic decoded = jsonDecode(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'Expected a JSON object (key-value dictionary).');
      }

      final Map<String, dynamic> json = decoded;
      final meta = (json['config_metadata'] is Map)
          ? Map<String, dynamic>.from(json['config_metadata'] as Map)
          : ((json['metadata'] is Map)
              ? Map<String, dynamic>.from(json['metadata'] as Map)
              : json);

      // Detect engine / source type
      final rawType = (json['source_type'] ??
              json['sourceType'] ??
              json['engine'] ??
              json['type'] ??
              json['integration_type'] ??
              meta['source_type'] ??
              meta['engine'] ??
              '')
          .toString()
          .toUpperCase()
          .trim();

      int targetCategory = _categoryIndex;
      String? targetSqlEngine;
      String? targetNoSqlEngine;

      if (rawType.contains('REST')) {
        targetCategory = 0;
      } else if (rawType.contains('GRAPHQL')) {
        targetCategory = 1;
      } else if (rawType.contains('POSTGRES') ||
          rawType.contains('MYSQL') ||
          rawType.contains('ORACLE') ||
          rawType.contains('MSSQL') ||
          rawType == 'SQL') {
        targetCategory = 2;
        if (rawType.contains('POSTGRES')) targetSqlEngine = 'POSTGRESQL';
        if (rawType.contains('MYSQL')) targetSqlEngine = 'MYSQL';
        if (rawType.contains('ORACLE')) targetSqlEngine = 'ORACLE';
        if (rawType.contains('MSSQL') || rawType.contains('SQLSERVER')) {
          targetSqlEngine = 'MSSQL';
        }
      } else if (rawType.contains('MONGO') ||
          rawType.contains('CASSANDRA') ||
          rawType.contains('DYNAMO') ||
          rawType.contains('REDIS') ||
          rawType == 'NOSQL') {
        targetCategory = 3;
        if (rawType.contains('MONGO')) targetNoSqlEngine = 'MONGODB';
        if (rawType.contains('CASSANDRA')) targetNoSqlEngine = 'CASSANDRA';
        if (rawType.contains('DYNAMO')) targetNoSqlEngine = 'DYNAMODB';
        if (rawType.contains('REDIS')) targetNoSqlEngine = 'REDIS';
      }

      setState(() {
        _categoryIndex = targetCategory;
        if (targetSqlEngine != null) _sqlEngine = targetSqlEngine;
        if (targetNoSqlEngine != null) _noSqlEngine = targetNoSqlEngine;

        // 1. Bank details
        if (json['bank_name'] != null || json['bankName'] != null) {
          _bankNameController.text =
              (json['bank_name'] ?? json['bankName']).toString();
        }
        if (json['bank_code'] != null ||
            json['bankCode'] != null ||
            json['bank_id'] != null) {
          _bankCodeController.text =
              (json['bank_code'] ?? json['bankCode'] ?? json['bank_id'])
                  .toString();
        }
        if (json['integration_name'] != null ||
            json['integrationName'] != null ||
            json['name'] != null) {
          _integrationNameController.text = (json['integration_name'] ??
                  json['integrationName'] ??
                  json['name'])
              .toString();
        }
        final env =
            (json['environment'] ?? json['env'])?.toString().toUpperCase();
        if (env != null) {
          if (env.contains('DEV')) _selectedEnvironment = 'DEVELOPMENT';
          if (env.contains('UAT') || env.contains('STAG'))
            _selectedEnvironment = 'UAT';
          if (env.contains('PROD')) _selectedEnvironment = 'PRODUCTION';
        }

        // 2. REST & GraphQL Fields
        if (meta['base_url'] != null || meta['baseUrl'] != null) {
          _baseUrlController.text =
              (meta['base_url'] ?? meta['baseUrl']).toString();
        }
        if (meta['endpoint'] != null ||
            meta['rules_endpoint'] != null ||
            meta['rulesEndpoint'] != null) {
          _endpointController.text = (meta['endpoint'] ??
                  meta['rules_endpoint'] ??
                  meta['rulesEndpoint'])
              .toString();
        }
        if (meta['http_method'] != null ||
            meta['httpMethod'] != null ||
            meta['method'] != null) {
          final m =
              (meta['http_method'] ?? meta['httpMethod'] ?? meta['method'])
                  .toString()
                  .toUpperCase();
          if (['GET', 'POST', 'PUT'].contains(m)) _httpMethod = m;
        }
        if (meta['api_version'] != null || meta['apiVersion'] != null) {
          _apiVersionController.text =
              (meta['api_version'] ?? meta['apiVersion']).toString();
        }
        if (meta['auth_type'] != null || meta['authType'] != null) {
          final at =
              (meta['auth_type'] ?? meta['authType']).toString().toUpperCase();
          if (['BEARER', 'API_KEY', 'OAUTH2', 'BASIC', 'NONE'].contains(at)) {
            _authType = at;
          }
        }
        final cred = json['credential_ref'] ??
            json['credentialRef'] ??
            meta['credential_ref'] ??
            meta['credentialRef'] ??
            meta['token'] ??
            meta['password'] ??
            meta['api_key'];
        if (cred != null) {
          _authTokenRefController.text = cred.toString();
          _credentialRefController.text = cred.toString();
        }
        if (meta['headers'] != null) {
          if (meta['headers'] is String) {
            _headersController.text = meta['headers'] as String;
          } else {
            _headersController.text = jsonEncode(meta['headers']);
          }
        }
        if (meta['swagger_spec'] != null ||
            meta['swagger_url'] != null ||
            meta['swaggerUrl'] != null) {
          _swaggerUrlController.text = (meta['swagger_spec'] ??
                  meta['swagger_url'] ??
                  meta['swaggerUrl'])
              .toString();
        }

        // 3. SQL & NoSQL Database Fields
        if (meta['host'] != null || meta['hostname'] != null) {
          _hostController.text = (meta['host'] ?? meta['hostname']).toString();
        }
        if (meta['port'] != null) {
          _portController.text = meta['port'].toString();
        } else if (_categoryIndex == 2) {
          _portController.text = _getDefaultPortForSql(_sqlEngine);
        } else if (_categoryIndex == 3) {
          _portController.text = _getDefaultPortForNoSql(_noSqlEngine);
        }
        if (meta['database_name'] != null ||
            meta['database'] != null ||
            meta['db_name'] != null ||
            meta['dbName'] != null) {
          _dbNameController.text = (meta['database_name'] ??
                  meta['database'] ??
                  meta['db_name'] ??
                  meta['dbName'])
              .toString();
        }
        if (meta['schema'] != null || meta['schemaName'] != null) {
          _schemaController.text =
              (meta['schema'] ?? meta['schemaName']).toString();
        }
        if (meta['table_or_collection'] != null ||
            meta['table'] != null ||
            meta['collection'] != null ||
            meta['collectionName'] != null) {
          _tableController.text = (meta['table_or_collection'] ??
                  meta['table'] ??
                  meta['collection'] ??
                  meta['collectionName'])
              .toString();
        }
        if (meta['service_account'] != null ||
            meta['username'] != null ||
            meta['user'] != null ||
            meta['serviceAccount'] != null) {
          _serviceAccountController.text = (meta['service_account'] ??
                  meta['username'] ??
                  meta['user'] ??
                  meta['serviceAccount'])
              .toString();
        }
        if (meta['ssl_enabled'] != null || meta['ssl'] != null) {
          _sslEnabled = meta['ssl_enabled'] == true || meta['ssl'] == true;
        }

        _isJsonImportExpanded = false;
        _lastResult = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Successfully auto-filled fields for $_currentSourceType!',
            style: const TextStyle(fontFamily: 'packages/cidan/Poppins'),
          ),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid JSON: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleSaveAndVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _lastResult = null;
      _stepStatus = '1/5 Validating banking configuration contract...';
    });

    final now = DateTime.now();

    try {
      // Step 0: Check if exact same integration already exists in Supabase
      final email = widget.userEmail.isNotEmpty
          ? widget.userEmail
          : 'arjundamodaranofficial@gmail.com';
      final existingIntegrations =
          await SupabaseService().getUserSavedIntegrations(email);

      UserSavedIntegrationModel? duplicateMatch;
      final currType = _currentSourceType.toUpperCase().trim();

      for (final existing in existingIntegrations) {
        // Skip if editing the current record
        if (widget.initialIntegration != null &&
            widget.initialIntegration!.id == existing.id) {
          continue;
        }

        final exType = existing.sourceType.toUpperCase().trim();
        if (exType != currType) continue;

        final exMeta = existing.configMetadata;

        if (_categoryIndex == 2 || _categoryIndex == 3) {
          final exHost =
              (exMeta['host'] ?? '').toString().trim().toLowerCase();
          final currHost = _hostController.text.trim().toLowerCase();

          final exPort = (exMeta['port'] ?? '').toString().trim();
          final currPort = _portController.text.trim();

          final exDb =
              (exMeta['database_name'] ?? exMeta['database'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          final currDb = _dbNameController.text.trim().toLowerCase();

          final exTable =
              (exMeta['table_or_collection'] ?? exMeta['table'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          final currTable = _tableController.text.trim().toLowerCase();

          final exUser =
              (exMeta['service_account'] ?? exMeta['username'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          final currUser =
              _serviceAccountController.text.trim().toLowerCase();

          if (exHost == currHost &&
              exPort == currPort &&
              exDb == currDb &&
              exTable == currTable &&
              exUser == currUser) {
            duplicateMatch = existing;
            break;
          }
        } else {
          final exBase =
              (exMeta['base_url'] ?? '').toString().trim().toLowerCase();
          final currBase = _baseUrlController.text.trim().toLowerCase();

          final exEndpoint =
              (exMeta['endpoint'] ?? exMeta['rules_endpoint'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
          final currEndpoint = _endpointController.text.trim().toLowerCase();

          final exMethod = (exMeta['http_method'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
          final currMethod = _httpMethod.trim().toUpperCase();

          if (exBase == currBase &&
              exEndpoint == currEndpoint &&
              exMethod == currMethod) {
            duplicateMatch = existing;
            break;
          }
        }
      }

      if (duplicateMatch != null) {
        setState(() => _isVerifying = false);

        await SupabaseService()
            .setUserIntegrationSelected(email, duplicateMatch.id);
        if (widget.onSavedIntegration != null) {
          widget.onSavedIntegration!(duplicateMatch);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Already connected! "${duplicateMatch.integrationName}" ($currType) is already saved and active in your database.',
                style: const TextStyle(fontFamily: 'packages/cidan/Poppins'),
              ),
              backgroundColor: const Color(0xFF7C3AED),
              duration: const Duration(seconds: 4),
            ),
          );

          // Exit dialog and show upload page
          Navigator.of(context).pop();
        }
        return;
      }

      // Step 1: Register or get Bank record in Supabase
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(
          () => _stepStatus = '2/5 Registering bank profile in Supabase...');

      final bank = await SupabaseService().getOrCreateBank(
        name: _bankNameController.text.trim(),
        bankCode: _bankCodeController.text.trim(),
      );

      // Step 2: Build Integration Model
      final integrationId = SupabaseService.generateUuid();
      final sourceId = SupabaseService.generateUuid();

      final integrationType = _categoryIndex == 0
          ? 'REST'
          : (_categoryIndex == 1
              ? 'GRAPHQL'
              : (_categoryIndex == 2 ? 'SQL' : 'NOSQL'));

      final integration = BankIntegrationModel(
        id: integrationId,
        bankId: bank.id,
        name: _integrationNameController.text.trim(),
        environment: _selectedEnvironment,
        integrationType: integrationType,
        status: 'PENDING',
        createdAt: now,
      );

      // Step 3: Build Source Model
      Map<String, dynamic> metadata = {};
      String? credRef;

      if (_categoryIndex == 0 || _categoryIndex == 1) {
        metadata = {
          'base_url': _baseUrlController.text.trim(),
          'endpoint': _endpointController.text.trim(),
          'http_method': _httpMethod,
          'api_version': _apiVersionController.text.trim(),
          'auth_type': _authType,
          'headers': _headersController.text.trim(),
          'swagger_spec': _swaggerUrlController.text.trim(),
        };
        credRef = _authTokenRefController.text.trim();
      } else {
        metadata = {
          'host': _hostController.text.trim(),
          'port': int.tryParse(_portController.text.trim()) ??
              int.parse(_getDefaultPortForSql(_sqlEngine)),
          'database_name': _dbNameController.text.trim(),
          'schema': _schemaController.text.trim(),
          'table_or_collection': _tableController.text.trim(),
          'service_account': _serviceAccountController.text.trim(),
          'password': _credentialRefController.text.trim(),
        };
        credRef = _credentialRefController.text.trim();
      }

      final source = IntegrationSourceModel(
        id: sourceId,
        integrationId: integrationId,
        sourceType: _currentSourceType,
        configMetadata: metadata,
        credentialRef: credRef,
        sslConfig: {
          'enabled': _sslEnabled,
          'verify_cert': _verifyCert,
        },
        isActive: true,
        createdAt: now,
      );

      // Step 4: Dispatch to backend adapter (Flutter never calls DB directly)
      setState(
          () => _stepStatus = '3/5 Testing connectivity via backend proxy...');
      final adapter = IntegrationAdapterFactory.getAdapter(source.sourceType);

      final result = await adapter.testConnection(
        source,
        bankId: _bankCodeController.text.trim().isNotEmpty
            ? _bankCodeController.text.trim()
            : 'apex-bank-01',
      );

      setState(() {
        _stepStatus = '4/5 Logging connection audit trail to Supabase...';
        _lastResult = result;
      });

      // Step 5: Save audit trail
      await SupabaseService().recordConnectionVerification(result);

      if (result.isSuccess) {
        setState(
            () => _stepStatus = '5/5 Saving verified source configuration...');
        await SupabaseService().saveBankIntegration(
          integration.copyWith(status: 'ACTIVE'),
        );
        await SupabaseService().saveIntegrationSource(
          source.copyWith(lastVerifiedAt: DateTime.now()),
        );

        // Store credentials & configuration in Supabase user_saved_integrations
        final savedUserIntegration = UserSavedIntegrationModel(
          id: widget.initialIntegration?.id ?? SupabaseService.generateUuid(),
          userEmail: widget.userEmail.isNotEmpty
              ? widget.userEmail
              : 'arjundamodaranofficial@gmail.com',
          bankName: _bankNameController.text.trim(),
          bankCode: _bankCodeController.text.trim(),
          integrationName: _integrationNameController.text.trim(),
          environment: _selectedEnvironment,
          sourceType: _currentSourceType,
          configMetadata: metadata,
          credentialRef: credRef,
          sslConfig: {
            'enabled': _sslEnabled,
            'verify_cert': _verifyCert,
          },
          status: 'ACTIVE',
          isSelected: true,
          lastVerifiedAt: DateTime.now(),
          createdAt: widget.initialIntegration?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await SupabaseService().saveUserSavedIntegration(savedUserIntegration);
        if (widget.onSavedIntegration != null) {
          widget.onSavedIntegration!(savedUserIntegration);
        }

        // Notify parent
        widget.onSourceVerified(
          integration.copyWith(status: 'ACTIVE'),
          source.copyWith(lastVerifiedAt: DateTime.now()),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ Integration source "${source.sourceType}" verified & saved successfully (${result.responseTimeMs} ms)',
                style: const TextStyle(fontFamily: 'packages/cidan/Poppins'),
              ),
              backgroundColor: const Color(0xFF15803D),
              duration: const Duration(seconds: 3),
            ),
          );

          // Exit the dialog and return to the upload page
          Navigator.of(context).pop();
        }
      } else {
        await SupabaseService().saveBankIntegration(
          integration.copyWith(status: 'FAILED'),
        );
      }
    } catch (e) {
      setState(() {
        _lastResult = ConnectionVerificationResult(
          id: 'verif-err-${DateTime.now().millisecondsSinceEpoch}',
          sourceId: 'error',
          verificationStatus: 'FAILED',
          responseTimeMs: 0,
          errorMessage: 'Verification failed: ${e.toString()}',
          verifiedAt: DateTime.now(),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _stepStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect with CIDAN',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Enterprise Banking Rules & Database Ingestion Gateway',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B), size: 22),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildJsonImportCard(),
                      const SizedBox(height: 16),
                      _buildSectionHeader('1. Bank & Environment Details'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'Bank Name',
                              controller: _bankNameController,
                              icon: Icons.business_rounded,
                              hint: 'e.g. Apex Global Bank',
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Bank Name required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              label: 'Bank Identifier / Code',
                              controller: _bankCodeController,
                              icon: Icons.tag_rounded,
                              hint: 'e.g. AGB-9021',
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Bank ID required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: 'Integration Name',
                              controller: _integrationNameController,
                              icon: Icons.label_outline_rounded,
                              hint: 'e.g. Core Rules Gateway',
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Name required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Target Environment',
                              value: _selectedEnvironment,
                              items: const [
                                DropdownMenuItem(
                                    value: 'DEVELOPMENT',
                                    child: Text('Development')),
                                DropdownMenuItem(
                                    value: 'UAT', child: Text('UAT (Staging)')),
                                DropdownMenuItem(
                                    value: 'PRODUCTION',
                                    child: Text('Production')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedEnvironment = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      _buildSectionHeader('2. Integration Type & Engine'),
                      const SizedBox(height: 10),

                      // Category Selector: REST / GraphQL / SQL / NoSQL
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildCategoryTab(0, 'REST', Icons.http_rounded),
                            _buildCategoryTab(
                                1, 'GraphQL', Icons.device_hub_rounded),
                            _buildCategoryTab(2, 'SQL', Icons.storage_rounded),
                            _buildCategoryTab(3, 'NoSQL', Icons.layers_rounded),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Engine Sub-selector
                      if (_categoryIndex == 2) ...[
                        _buildEnginePills(
                          current: _sqlEngine,
                          options: [
                            'POSTGRESQL',
                            'MYSQL',
                          ],
                          labels: [
                            'PostgreSQL',
                            'MySQL',
                          ],
                          onSelected: (val) {
                            setState(() {
                              _sqlEngine = val;
                              _portController.text = _getDefaultPortForSql(val);
                            });
                          },
                        ),
                      ] else if (_categoryIndex == 3) ...[
                        _buildEnginePills(
                          current: _noSqlEngine,
                          options: [
                            'MONGODB',
                            'REDIS',
                          ],
                          labels: [
                            'MongoDB Atlas',
                            'Redis',
                          ],
                          onSelected: (val) {
                            setState(() {
                              _noSqlEngine = val;
                              _portController.text =
                                  _getDefaultPortForNoSql(val);
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 20),
                      _buildSectionHeader(
                          '3. Connection & Security Configuration'),
                      const SizedBox(height: 10),

                      // Dynamic Fields based on Type
                      if (_categoryIndex == 0 || _categoryIndex == 1) ...[
                        _buildApiFields(),
                      ] else ...[
                        _buildDatabaseFields(),
                      ],

                      // Live Verification Results Card
                      if (_stepStatus != null || _lastResult != null) ...[
                        const SizedBox(height: 16),
                        _buildVerificationResultCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Modal Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFD),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'Engine: $_currentSourceType',
                    style: const TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _isVerifying
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isVerifying ? null : _handleSaveAndVerify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          elevation: 0,
                        ),
                        icon: _isVerifying
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 16),
                        label: Text(
                          _isVerifying ? 'Verifying...' : 'Save & Verify',
                          style: const TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonImportCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isJsonImportExpanded
              ? const Color(0xFF6366F1).withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: _isJsonImportExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isJsonImportExpanded = !_isJsonImportExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.data_object_rounded,
                      color: Color(0xFF6366F1),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Auto-Fill Fields via JSON',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Paste configuration JSON to populate all form fields automatically',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isJsonImportExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_isJsonImportExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _jsonImportController,
                    maxLines: 6,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText:
                          '{\n  "source_type": "REST",\n  "base_url": "https://cidan-bank-rules.free.beeceptor.com",\n  "endpoint": "/api/v1/compliance/rules"\n}',
                      hintStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _jsonImportController.clear();
                          setState(() => _isJsonImportExpanded = false);
                        },
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          textStyle: const TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _applyJsonConfig,
                        icon: const Icon(Icons.bolt_rounded, size: 15),
                        label: const Text('Auto-Fill All Fields'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTab(int idx, String title, IconData icon) {
    final isSelected = _categoryIndex == idx;
    return Expanded(
      child: InkWell(
        onTap: () => _onCategoryChanged(idx),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnginePills({
    required String current,
    required List<String> options,
    required List<String> labels,
    required Function(String) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final label = labels[i];
        final isSel = current == opt;
        return ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isSel ? Colors.white : const Color(0xFF334155),
            ),
          ),
          selected: isSel,
          selectedColor: const Color(0xFF6366F1),
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSel ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
            ),
          ),
          showCheckmark: false,
          onSelected: (_) => onSelected(opt),
        );
      }),
    );
  }

  Widget _buildApiFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                label: 'Base URL',
                controller: _baseUrlController,
                icon: Icons.link_rounded,
                hint: 'https://api.bank.com/v1',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Base URL required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildTextField(
                label: 'Rules Endpoint',
                controller: _endpointController,
                icon: Icons.alt_route_rounded,
                hint: '/rules/compliance',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdown(
                label: 'HTTP Method',
                value: _httpMethod,
                items: const [
                  DropdownMenuItem(value: 'GET', child: Text('GET')),
                  DropdownMenuItem(value: 'POST', child: Text('POST')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _httpMethod = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildDropdown(
                label: 'Authentication Type',
                value: _authType,
                items: const [
                  DropdownMenuItem(
                      value: 'BEARER', child: Text('Bearer Token')),
                  DropdownMenuItem(
                      value: 'API_KEY', child: Text('API Key Header')),
                  DropdownMenuItem(
                      value: 'OAUTH2', child: Text('OAuth 2.0 mTLS')),
                  DropdownMenuItem(
                      value: 'NONE', child: Text('None (Public/mTLS)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _authType = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label:
              'Secure Credential Reference (Token / Vault Ref - No raw passwords)',
          controller: _authTokenRefController,
          icon: Icons.vpn_key_rounded,
          hint: 'vault://secrets/cidan-api-key',
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label: 'Custom Headers (JSON)',
          controller: _headersController,
          icon: Icons.code_rounded,
          hint: '{"X-Audit-ID": "CIDAN-01"}',
        ),
      ],
    );
  }

  Widget _buildDatabaseFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                label: 'Host Address / Server IP',
                controller: _hostController,
                icon: Icons.dns_rounded,
                hint: 'db.apexbank.internal',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Host required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildTextField(
                label: 'Port',
                controller: _portController,
                icon: Icons.numbers_rounded,
                hint: '5432',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Port required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Database / Keyspace Name',
                controller: _dbNameController,
                icon: Icons.folder_rounded,
                hint: 'bank_policies',
                validator: (v) =>
                    v == null || v.isEmpty ? 'DB Name required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                label: 'Schema / Namespace',
                controller: _schemaController,
                icon: Icons.schema_rounded,
                hint: 'compliance',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'Table or Collection',
                controller: _tableController,
                icon: Icons.table_chart_rounded,
                hint: 'active_rules',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Table/Collection required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                label: 'Service Account (Read-Only)',
                controller: _serviceAccountController,
                icon: Icons.person_outline_rounded,
                hint: 'svc_cidan_read',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Account required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          label:
              'Secure Credential Reference (Vault Secret URI - No raw secrets)',
          controller: _credentialRefController,
          icon: Icons.security_rounded,
          hint: 'vault://credentials/db-ro-token',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _sslEnabled,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (v) => setState(() => _sslEnabled = v ?? true),
                ),
                const Text(
                  'Enforce SSL/TLS Encryption',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _verifyCert,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (v) => setState(() => _verifyCert = v ?? true),
                ),
                const Text(
                  'Verify Server Certificate',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerificationResultCard() {
    final isSuccess = _lastResult?.isSuccess == true;
    final isPending = _isVerifying;

    final bgColor = isPending
        ? const Color(0xFFF1F5F9)
        : (isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2));
    final borderColor = isPending
        ? const Color(0xFFCBD5E1)
        : (isSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA));
    final textColor = isPending
        ? const Color(0xFF334155)
        : (isSuccess ? const Color(0xFF15803D) : const Color(0xFF991B1B));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending
                    ? Icons.sync_rounded
                    : (isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded),
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Text(
                isPending
                    ? 'Backend Verification in Progress'
                    : (isSuccess
                        ? 'Connection Verified Successfully'
                        : 'Verification Failed (${_lastResult?.responseTimeMs} ms)'),
                style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (_stepStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              _stepStatus!,
              style: TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontSize: 11.5,
                color: textColor.withAlpha(200),
              ),
            ),
          ],
          if (_lastResult?.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${_lastResult!.errorMessage}',
              style: const TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF991B1B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'packages/cidan/Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 12.5,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF6366F1), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: value,
          items: items.map((item) {
            if (item.child is Text) {
              final textWidget = item.child as Text;
              return DropdownMenuItem<String>(
                key: item.key,
                value: item.value,
                enabled: item.enabled,
                onTap: item.onTap,
                alignment: item.alignment,
                child: Text(
                  textWidget.data ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textWidget.style ??
                      const TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                ),
              );
            }
            return item;
          }).toList(),
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 12,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }
}
