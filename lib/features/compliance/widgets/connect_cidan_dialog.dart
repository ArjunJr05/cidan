import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../models/bank_integration_model.dart';
import '../services/integration_adapter_interface.dart';

/// Modal dialog for configuring Option B: "Connect with CIDAN".
/// Supports enterprise REST, GraphQL, SQL (Postgres, MySQL, Oracle, MSSQL),
/// and NoSQL (MongoDB, Cassandra, DynamoDB, Redis) with real-time Save & Verify.
class ConnectCidanDialog extends StatefulWidget {
  final String userEmail;
  final Function(BankIntegrationModel integration, IntegrationSourceModel source)
      onSourceVerified;

  const ConnectCidanDialog({
    super.key,
    required this.userEmail,
    required this.onSourceVerified,
  });

  @override
  State<ConnectCidanDialog> createState() => _ConnectCidanDialogState();
}

class _ConnectCidanDialogState extends State<ConnectCidanDialog> {
  final _formKey = GlobalKey<FormState>();

  // Bank Info controllers
  final _bankNameController = TextEditingController(text: 'Apex Global Bank');
  final _bankCodeController = TextEditingController(text: 'AGB-9021');
  final _integrationNameController =
      TextEditingController(text: 'Core Banking Compliance Gateway');
  String _selectedEnvironment = 'PRODUCTION'; // DEVELOPMENT, UAT, PRODUCTION

  // Integration Category & Type
  // 0 = REST API, 1 = GraphQL, 2 = SQL Database, 3 = NoSQL Database
  int _categoryIndex = 0;
  String _sqlEngine = 'POSTGRESQL'; // POSTGRESQL, MYSQL, ORACLE, MSSQL
  String _noSqlEngine = 'MONGODB'; // MONGODB, CASSANDRA, DYNAMODB, REDIS

  // API Config Controllers
  final _baseUrlController = TextEditingController(text: 'https://api.apexbank.internal/v1');
  final _endpointController = TextEditingController(text: '/compliance/rules');
  String _httpMethod = 'GET';
  final _apiVersionController = TextEditingController(text: 'v1.4');
  String _authType = 'BEARER'; // BEARER, API_KEY, OAUTH2, BASIC, NONE
  final _authTokenRefController = TextEditingController(text: 'vault://secrets/cidan-api-key');
  final _headersController = TextEditingController(text: '{"X-Bank-Client": "CIDAN-Agent"}');
  final _swaggerUrlController = TextEditingController();

  // Database Config Controllers
  final _hostController = TextEditingController(text: 'db-cluster.apexbank.internal');
  final _portController = TextEditingController(text: '5432');
  final _dbNameController = TextEditingController(text: 'bank_policies');
  final _schemaController = TextEditingController(text: 'compliance');
  final _tableController = TextEditingController(text: 'active_rules');
  final _serviceAccountController = TextEditingController(text: 'svc_cidan_readonly');
  final _credentialRefController =
      TextEditingController(text: 'vault://tokens/db-read-key-prod');
  bool _sslEnabled = true;
  bool _verifyCert = true;

  // Verification State
  bool _isVerifying = false;
  ConnectionVerificationResult? _lastResult;
  String? _stepStatus;

  @override
  void dispose() {
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
      case 'ORACLE':
        return '1521';
      case 'MYSQL':
        return '3306';
      case 'MSSQL':
        return '1433';
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

  Future<void> _handleSaveAndVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _lastResult = null;
      _stepStatus = '1/5 Validating banking configuration contract...';
    });

    final now = DateTime.now();

    try {
      // Step 1: Register or get Bank record in Supabase
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _stepStatus = '2/5 Registering bank profile in Supabase...');

      final bank = await SupabaseService().getOrCreateBank(
        name: _bankNameController.text.trim(),
        bankCode: _bankCodeController.text.trim(),
      );

      // Step 2: Build Integration Model
      final integrationId = SupabaseService.generateUuid();
      final sourceId = SupabaseService.generateUuid();

      final integrationType = _categoryIndex == 0
          ? 'REST'
          : (_categoryIndex == 1 ? 'GRAPHQL' : (_categoryIndex == 2 ? 'SQL' : 'NOSQL'));

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
      setState(() => _stepStatus = '3/5 Testing connectivity via backend proxy...');
      final adapter = IntegrationAdapterFactory.getAdapter(source.sourceType);

      final result = await adapter.testConnection(source, bankId: bank.id);

      setState(() {
        _stepStatus = '4/5 Logging connection audit trail to Supabase...';
        _lastResult = result;
      });

      // Step 5: Save audit trail
      await SupabaseService().recordConnectionVerification(result);

      if (result.isSuccess) {
        setState(() => _stepStatus = '5/5 Saving verified source configuration...');
        await SupabaseService().saveBankIntegration(
          integration.copyWith(status: 'ACTIVE'),
        );
        await SupabaseService().saveIntegrationSource(
          source.copyWith(lastVerifiedAt: DateTime.now()),
        );

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
            ),
          );
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
                            _buildCategoryTab(1, 'GraphQL', Icons.device_hub_rounded),
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
                            'ORACLE',
                            'MSSQL',
                          ],
                          labels: [
                            'PostgreSQL',
                            'MySQL',
                            'Oracle DB',
                            'MS SQL Server'
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
                            'CASSANDRA',
                            'DYNAMODB',
                            'REDIS',
                          ],
                          labels: [
                            'MongoDB',
                            'Cassandra',
                            'DynamoDB',
                            'Redis Rules'
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
                      _buildSectionHeader('3. Connection & Security Configuration'),
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
                validator: (v) => v == null || v.isEmpty ? 'Base URL required' : null,
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
              child: _buildDropdown(
                label: 'Authentication Type',
                value: _authType,
                items: const [
                  DropdownMenuItem(value: 'BEARER', child: Text('Bearer Token')),
                  DropdownMenuItem(value: 'API_KEY', child: Text('API Key Header')),
                  DropdownMenuItem(value: 'OAUTH2', child: Text('OAuth 2.0 mTLS')),
                  DropdownMenuItem(value: 'NONE', child: Text('None (Public/mTLS)')),
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
          label: 'Secure Credential Reference (Token / Vault Ref - No raw passwords)',
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
                validator: (v) => v == null || v.isEmpty ? 'Host required' : null,
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
                validator: (v) => v == null || v.isEmpty ? 'Port required' : null,
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
          label: 'Secure Credential Reference (Vault Secret URI - No raw secrets)',
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
                        ? 'Connection Verified Successfully (${_lastResult?.responseTimeMs} ms)'
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
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.4),
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
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 12.5,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
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
          ),
        ),
      ],
    );
  }
}
