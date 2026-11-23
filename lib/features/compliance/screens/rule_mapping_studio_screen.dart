import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../models/rule_delta_model.dart';
import '../models/rule_ir_model.dart';
import '../models/rule_validation_model.dart';
import '../services/cidan_api_service.dart';

class RuleMappingStudioScreen extends StatefulWidget {
  final DeltaAnalysisResult? initialAnalysis;
  final String? bankId;

  const RuleMappingStudioScreen({
    super.key,
    this.initialAnalysis,
    this.bankId,
  });

  @override
  State<RuleMappingStudioScreen> createState() =>
      _RuleMappingStudioScreenState();
}

class _RuleMappingStudioScreenState extends State<RuleMappingStudioScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final CidanApiService _apiService = CidanApiService();

  late TabController _tabController;
  DeltaAnalysisResult? _currentAnalysis;
  List<RuleDelta> _allDeltas = [];
  List<RuleIR> _existingRules = [];
  RuleDelta? _selectedDelta;

  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedClassification = 'ALL';
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';

  List<ValidationFinding> _currentValidations = [];
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudioData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudioData() async {
    setState(() => _isLoading = true);

    try {
      if (widget.initialAnalysis != null) {
        _currentAnalysis = widget.initialAnalysis;
        _allDeltas = List.from(_currentAnalysis!.deltas);
      } else {
        final analyses = await _supabaseService.getDeltaAnalyses(
          bankId: widget.bankId ?? 'apex-bank-01',
        );
        if (analyses.isNotEmpty) {
          _currentAnalysis = analyses.first;
          _allDeltas = List.from(_currentAnalysis!.deltas);
        } else {
          // If no saved analysis in DB yet, query backend
          final backendDeltas = await _apiService.getDeltas();
          if (backendDeltas.isNotEmpty) {
            _currentAnalysis = backendDeltas.first;
            _allDeltas = List.from(_currentAnalysis!.deltas);
          } else {
            // Check for user's live uploaded circular document in Supabase
            final uploadedDocs = await _supabaseService.getRegulatoryDocuments(
              bankId: widget.bankId,
            );
            final latestDoc = uploadedDocs.isNotEmpty ? uploadedDocs.first : null;

            final analysisName = latestDoc != null && latestDoc.documentName.isNotEmpty
                ? '${latestDoc.issuingAuthority}: ${latestDoc.documentName}'
                : 'Live Regulatory Compliance Delta Assessment';
            final circularNumber = latestDoc?.circularNumber.isNotEmpty == true
                ? latestDoc!.circularNumber
                : 'CIRC-2026-LIVE';

            // Run live delta analysis
            _currentAnalysis = await _apiService.analyzeDeltas(
              analysisName: analysisName,
              circularNumber: circularNumber,
              circularText:
                  'Clause 1. Mandatory Threshold Update: Banks shall monitor and report all cash transactions exceeding INR 500,000 within 7 days to FIU.\n'
                  'Clause 2. Cloud Cryptographic Security: Banks must maintain master key material within domestic data centers with HSM Level 3 protection.\n'
                  'Clause 3. Cross Border Outward Remittance: Dual compliance officer authorization required for outward wires exceeding USD 25,000.\n'
                  'Clause 4. Clarification on Periodic KYC: Low risk customer re-KYC cycle clarified to be exactly 10 years without adverse media alerts.',
              bankId: widget.bankId ?? 'apex-bank-01',
            );
            if (_currentAnalysis != null) {
              _allDeltas = List.from(_currentAnalysis!.deltas);
              await _supabaseService.saveDeltaAnalysis(_currentAnalysis!);
            }
          }
        }
      }

      // Load existing bank rules
      _existingRules = await _supabaseService.getRuleIRCatalog(
        bankId: widget.bankId ?? 'apex-bank-01',
      );

      // If empty, check for user-uploaded baseline rules in Supabase
      if (_existingRules.isEmpty) {
        final rawUploaded = await _supabaseService.getExistingRules(
          bankId: widget.bankId,
        );
        if (rawUploaded.isNotEmpty) {
          _existingRules = rawUploaded.map((r) {
            return RuleIR(
              id: r.id,
              bankId: r.bankId,
              ruleId: r.ruleCode.isNotEmpty ? r.ruleCode : 'RULE-${r.id.substring(0, 6)}',
              ruleName: r.ruleTitle,
              description: r.ruleContent,
              category: 'GENERAL',
              sourceType: r.sourceType,
              sourceId: r.sourceId,
              version: r.version,
              isActive: true,
              conditionTree: const ConditionTree(
                conditions: [
                  ConditionNode(
                    field: 'policy_compliance_status',
                    operator: '==',
                    value: 'ACTIVE',
                  ),
                ],
              ),
              actions: [
                ActionNode(
                  actionType: 'ENFORCE_POLICY',
                  target: 'CORE_ENGINE',
                  parameters: {'rule_ref': r.ruleCode},
                ),
              ],
            );
          }).toList();
        }
      }

      // If still empty, load standardized baseline bank policy catalog
      if (_existingRules.isEmpty) {
        _existingRules = _getBaselineBankRules();
      }

      if (_allDeltas.isNotEmpty) {
        _selectedDelta = _allDeltas.first;
        await _runValidationForSelectedDelta();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading Rule Mapping Studio: $e');
      if (_existingRules.isEmpty) {
        _existingRules = _getBaselineBankRules();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<RuleIR> _getBaselineBankRules() {
    return [
      const RuleIR(
        ruleId: 'RULE-AML-001',
        ruleName: 'High Value Cash Transaction Threshold',
        description: 'Mandatory reporting to regulatory authority for cash transactions exceeding baseline threshold.',
        category: 'GENERAL',
        sourceType: 'CORE_BANKING',
        version: 1,
        isActive: true,
        conditionTree: ConditionTree(
          conditions: [
            ConditionNode(
              field: 'transaction_amount',
              operator: '>=',
              value: 1000000,
              unit: 'INR',
            ),
          ],
        ),
        actions: [
          ActionNode(actionType: 'REPORT_SUSPICIOUS_TRANSACTION', target: 'FIU_PORTAL', parameters: {'deadline_days': 15}),
        ],
      ),
      const RuleIR(
        ruleId: 'RULE-KYC-002',
        ruleName: 'Periodic Customer Due Diligence (Re-KYC)',
        description: 'Periodic re-verification of customer identity credentials based on baseline customer risk rating.',
        category: 'KYC',
        sourceType: 'POLICY_HANDBOOK',
        version: 1,
        isActive: true,
        conditionTree: ConditionTree(
          conditions: [
            ConditionNode(
              field: 'customer_risk_rating',
              operator: '==',
              value: 'LOW',
            ),
          ],
        ),
        actions: [
          ActionNode(actionType: 'TRIGGER_RE_KYC', target: 'CUSTOMER_PORTAL', parameters: {'cycle_years': 8}),
        ],
      ),
      const RuleIR(
        ruleId: 'RULE-LEND-003',
        ruleName: 'Retail Loan to Value (LTV) Cap',
        description: 'Maximum permissible loan to property value ratio for retail residential mortgage sanctions.',
        category: 'LENDING',
        sourceType: 'CREDIT_POLICY',
        version: 1,
        isActive: true,
        conditionTree: ConditionTree(
          conditions: [
            ConditionNode(
              field: 'loan_to_value_ratio',
              operator: '<=',
              value: 80,
              unit: '%',
            ),
          ],
        ),
        actions: [
          ActionNode(actionType: 'RESTRICT_DISBURSEMENT', target: 'LOAN_LOS', parameters: {'exceed_action': 'REJECT'}),
        ],
      ),
      const RuleIR(
        ruleId: 'RULE-WIRE-004',
        ruleName: 'Cross Border Outward Remittance Verification',
        description: 'Multi-officer verification requirement for high value outbound foreign currency telegraphic transfers.',
        category: 'FOREIGN_EXCHANGE',
        sourceType: 'TREASURY_SYSTEM',
        version: 1,
        isActive: true,
        conditionTree: ConditionTree(
          conditions: [
            ConditionNode(
              field: 'remittance_amount_usd',
              operator: '>=',
              value: 50000,
              unit: 'USD',
            ),
          ],
        ),
        actions: [
          ActionNode(actionType: 'REQUIRE_DUAL_AUTH', target: 'SWIFT_GATEWAY', parameters: {'approvers_required': 2}),
        ],
      ),
    ];
  }

  Future<void> _runValidationForSelectedDelta() async {
    if (_selectedDelta == null) return;
    setState(() => _isValidating = true);

    try {
      final proposedMap = _selectedDelta!.proposedChange.isNotEmpty
          ? _selectedDelta!.proposedChange
          : _selectedDelta!.newRequirementRepresentation ?? {};

      if (proposedMap.isNotEmpty) {
        final findings = await _apiService.validateRule(
          proposedMap,
          deltaId: _selectedDelta!.id,
          bankId: widget.bankId ?? 'apex-bank-01',
        );
        if (mounted) {
          setState(() {
            _currentValidations = findings;
          });
        }
      }
    } catch (e) {
      debugPrint('Validation run error: $e');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  List<RuleDelta> get _filteredDeltas {
    return _allDeltas.where((delta) {
      if (_selectedClassification != 'ALL' &&
          delta.classification != _selectedClassification) {
        return false;
      }
      if (_selectedCategory != 'ALL' &&
          delta.category.toUpperCase() != _selectedCategory.toUpperCase()) {
        return false;
      }
      if (_selectedStatus != 'ALL' &&
          delta.reviewStatus.toUpperCase() != _selectedStatus.toUpperCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = delta.ruleName.toLowerCase().contains(query);
        final matchesReason = delta.reason.toLowerCase().contains(query);
        final matchesCategory = delta.category.toLowerCase().contains(query);
        return matchesName || matchesReason || matchesCategory;
      }
      return true;
    }).toList();
  }

  Future<void> _handleDecision(String decision, {String? notes, Map<String, dynamic>? customIr}) async {
    if (_selectedDelta == null) return;

    final delta = _selectedDelta!;
    setState(() {
      final statusMap = {
        'ACCEPTED': 'ACCEPTED',
        'MODIFIED': 'MODIFIED',
        'REJECTED': 'REJECTED',
        'MANUAL_REVIEW': 'NEEDS_REVIEW',
      };
      delta.reviewStatus = statusMap[decision] ?? 'PENDING';
      if (customIr != null) {
        delta.proposedChange.addAll(customIr);
      }
    });

    // Save to Supabase and FastAPI backend
    await _supabaseService.saveRuleMapping(
      deltaId: delta.id,
      decision: decision,
      customizedRuleIr: customIr,
      userNotes: notes,
      bankId: widget.bankId ?? 'apex-bank-01',
    );

    await _apiService.saveMappingDecision(
      deltaId: delta.id,
      decision: decision,
      customizedRuleIr: customIr,
      userNotes: notes,
      bankId: widget.bankId ?? 'apex-bank-01',
    );

    if (decision == 'ACCEPTED' || decision == 'MODIFIED') {
      await _apiService.createApprovalWorkflow(
        ruleId: delta.previousRuleId ?? delta.id,
        ruleName: delta.ruleName,
        ruleIrSnapshot: customIr ?? (delta.proposedChange.isNotEmpty ? delta.proposedChange : (delta.newRequirementRepresentation ?? {})),
        deltaId: delta.id,
        category: delta.category,
        bankId: widget.bankId ?? 'apex-bank-01',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule change marked as $decision'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCustomizeDialog() {
    if (_selectedDelta == null) return;
    final delta = _selectedDelta!;
    final diffs = delta.identifiedDifferences;

    final thresholdController = TextEditingController(
      text: diffs.isNotEmpty ? diffs.first.proposedValue.toString() : '',
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.tune, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Customize Rule Change',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rule: ${delta.ruleName}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (diffs.isNotEmpty) ...[
                Text(
                  'Adjust Threshold (${diffs.first.field}):',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: thresholdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Compliance Officer Notes:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter justification for threshold tuning or exception...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final customValue = num.tryParse(thresholdController.text.trim());
              final customIr = Map<String, dynamic>.from(delta.proposedChange);
              if (customValue != null && diffs.isNotEmpty) {
                // Update in custom map
                customIr['custom_threshold'] = customValue;
              }
              _handleDecision(
                'MODIFIED',
                notes: notesController.text.trim(),
                customIr: customIr,
              );
            },
            child: const Text('Save & Apply Modification'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CIDAN AI Rule Mapping Studio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              _currentAnalysis != null
                  ? '${_currentAnalysis!.analysisName} (${_currentAnalysis!.circularNumber ?? "Circular"})'
                  : 'Automated Delta Analysis & Universal Rule IR Studio',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Analysis',
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _loadStudioData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: !isWide
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: const Color(0xFF64748B),
                tabs: const [
                  Tab(text: 'Existing Rules'),
                  Tab(text: 'Circular Obligations'),
                  Tab(text: 'Proposed Changes & Diff'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Running AI Delta Analysis & Normalizing Universal Rule IR...',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildSummaryKPIHeader(),
                _buildFilterBar(),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildExistingRulesPanel()),
                            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                            Expanded(flex: 3, child: _buildCircularObligationsPanel()),
                            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                            Expanded(flex: 4, child: _buildProposedDiffPanel()),
                          ],
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildExistingRulesPanel(),
                            _buildCircularObligationsPanel(),
                            _buildProposedDiffPanel(),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // 1. TOP SUMMARY KPI HEADER
  // =========================================================================
  Widget _buildSummaryKPIHeader() {
    final a = _currentAnalysis;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricPill('Total Rules', '${a?.totalRules ?? _allDeltas.length}', const Color(0xFF0F172A), Icons.rule),
            _buildMetricPill('Additions', '${a?.additionsCount ?? _countClassification("ADDITION")}', const Color(0xFF10B981), Icons.add_circle_outline),
            _buildMetricPill('Modifications', '${a?.modificationsCount ?? _countClassification("MODIFICATION")}', const Color(0xFF6366F1), Icons.edit_note),
            _buildMetricPill('Removals', '${a?.removalsCount ?? _countClassification("REMOVAL")}', const Color(0xFFEF4444), Icons.delete_outline),
            _buildMetricPill('Clarifications', '${a?.clarificationsCount ?? _countClassification("CLARIFICATION")}', const Color(0xFF06B6D4), Icons.info_outline),
            _buildMetricPill('No Impact', '${a?.noImpactCount ?? _countClassification("NO_IMPACT")}', const Color(0xFF64748B), Icons.check_circle_outline),
            _buildMetricPill('Manual Review', '${a?.manualReviewCount ?? _countClassification("MANUAL_REVIEW_REQUIRED")}', const Color(0xFFF59E0B), Icons.flag_outlined),
          ],
        ),
      ),
    );
  }

  int _countClassification(String type) {
    return _allDeltas.where((d) => d.classification == type).length;
  }

  Widget _buildMetricPill(String label, String count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. SEARCH & MULTI-FILTER BAR
  // =========================================================================
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 260,
              height: 38,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search rules, obligations, or diff criteria...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Classification Dropdown
            DropdownButton<String>(
              value: _selectedClassification,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Types', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'ADDITION', child: Text('Additions', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'MODIFICATION', child: Text('Modifications', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'REMOVAL', child: Text('Removals', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'CLARIFICATION', child: Text('Clarifications', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'NO_IMPACT', child: Text('No Impact', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'MANUAL_REVIEW_REQUIRED', child: Text('Manual Review', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedClassification = val);
              },
            ),
            const SizedBox(width: 8),
            // Category Dropdown
            DropdownButton<String>(
              value: _selectedCategory,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Categories', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'AML', child: Text('AML', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'KYC', child: Text('KYC', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'CAPITAL_ADEQUACY', child: Text('Capital Adequacy', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'LENDING', child: Text('Lending', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'FOREIGN_EXCHANGE', child: Text('Forex', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'GENERAL', child: Text('General', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(width: 8),
            // Status Dropdown
            DropdownButton<String>(
              value: _selectedStatus,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'PENDING', child: Text('Pending', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'ACCEPTED', child: Text('Accepted', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'MODIFIED', child: Text('Modified', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'REJECTED', child: Text('Rejected', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'NEEDS_REVIEW', child: Text('Needs Review', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatus = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. PANEL 1: EXISTING BANK RULES
  // =========================================================================
  Widget _buildExistingRulesPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.account_balance, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Existing Bank Rules',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_existingRules.length} rules',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _existingRules.isEmpty
                ? const Center(
                    child: Text(
                      'No baseline rules cataloged.\nUpload rules or connect with CIDAN.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: _existingRules.length,
                    itemBuilder: (ctx, idx) {
                      final rule = _existingRules[idx];
                      final isLinked = _selectedDelta?.previousRuleId == rule.id ||
                          _selectedDelta?.previousRuleId == rule.ruleId;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLinked ? const Color(0xFFEEF2FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLinked ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: isLinked ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          title: Row(
                            children: [
                              Text(
                                rule.ruleId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isLinked ? AppColors.primary : const Color(0xFF475569),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  rule.category,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                rule.ruleName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rule.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: rule.conditionTree.flattenLeaves.map((c) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${c.field} ${c.operator} ${c.value} ${c.unit ?? ""}',
                                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF334155)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. PANEL 2: REGULATORY REQUIREMENTS (CIRCULAR OBLIGATIONS)
  // =========================================================================
  Widget _buildCircularObligationsPanel() {
    final filtered = _filteredDeltas;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.gavel, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Regulatory Mandates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${filtered.length} analyzed',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final delta = filtered[idx];
                final isSelected = _selectedDelta?.id == delta.id;
                final classColor = _getClassificationColor(delta.classification);

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDelta = delta);
                    _runValidationForSelectedDelta();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: classColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                delta.classification,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: classColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              delta.reviewStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: delta.reviewStatus == 'ACCEPTED'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          delta.ruleName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          delta.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Confidence: ${(delta.confidenceScore * 100).toInt()}%',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (delta.identifiedDifferences.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${delta.identifiedDifferences.length} diffs',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. PANEL 3: PROPOSED RULE CHANGES & VISUAL DIFF TABLE
  // =========================================================================
  Widget _buildProposedDiffPanel() {
    if (_selectedDelta == null) {
      return const Center(
        child: Text(
          'Select a rule obligation to view visual diff and mapping decisions.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      );
    }

    final delta = _selectedDelta!;
    final classColor = _getClassificationColor(delta.classification);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Proposed Rule Changes & Diff',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: classColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    delta.classification,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: classColor),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    delta.ruleName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  // VISUAL DIFF TABLE
                  const Text(
                    'Visual Parameter & Condition Differences',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  _buildVisualDiffTable(delta),
                  const SizedBox(height: 16),

                  // EXPLAINABLE AI CARD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.psychology, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Explainable AI Assessment',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Why Affected: ${delta.reason}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Operational Impact: ${delta.impactAssessment}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SOURCE EVIDENCE CITATION
                  if (delta.evidenceSources.isNotEmpty) ...[
                    const Text(
                      'Source Regulatory Citation',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              delta.evidenceSources.first['text']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // RULE VALIDATION FINDINGS
                  const Text(
                    'Multi-Tier Rule Validation Findings',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  _buildValidationSection(),
                  const SizedBox(height: 24),

                  // ACTION BUTTONS
                  _buildMappingActionButtons(delta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualDiffTable(RuleDelta delta) {
    if (delta.identifiedDifferences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'No parameter threshold discrepancies detected. Rule matches current standard.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
            children: const [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Field', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Previous Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Proposed Circular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Change Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
              ),
            ],
          ),
          ...delta.identifiedDifferences.map((diff) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(diff.field, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${diff.previousValue}', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), decoration: TextDecoration.lineThrough)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${diff.proposedValue}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(diff.diffType, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildValidationSection() {
    if (_isValidating) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Validating rule integrity...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_currentValidations.isEmpty) {
      return const Text('No validation findings available.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)));
    }

    return Column(
      children: _currentValidations.map((f) {
        final isError = f.severity == 'ERROR';
        final isWarning = f.severity == 'WARNING';
        final color = isError
            ? const Color(0xFFEF4444)
            : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
        final icon = isError
            ? Icons.error_outline
            : (isWarning ? Icons.warning_amber_outlined : Icons.check_circle_outline);

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(76)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${f.ruleCode}: ${f.message}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMappingActionButtons(RuleDelta delta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleDecision('ACCEPTED'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept Change', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showCustomizeDialog,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit / Customize', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleDecision('REJECTED'),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject Change'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleDecision('MANUAL_REVIEW'),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Mark Manual Review'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getClassificationColor(String classification) {
    switch (classification) {
      case 'ADDITION':
        return const Color(0xFF10B981);
      case 'MODIFICATION':
        return const Color(0xFF6366F1);
      case 'REMOVAL':
        return const Color(0xFFEF4444);
      case 'CLARIFICATION':
        return const Color(0xFF06B6D4);
      case 'NO_IMPACT':
        return const Color(0xFF64748B);
      case 'MANUAL_REVIEW_REQUIRED':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }
}
