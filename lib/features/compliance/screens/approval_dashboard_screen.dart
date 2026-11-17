import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/approval_workflow_model.dart';
import '../services/cidan_api_service.dart';
import 'approval_details_screen.dart';

class ApprovalDashboardScreen extends StatefulWidget {
  final String bankId;
  const ApprovalDashboardScreen({super.key, this.bankId = 'apex-bank-01'});

  @override
  State<ApprovalDashboardScreen> createState() => _ApprovalDashboardScreenState();
}

class _ApprovalDashboardScreenState extends State<ApprovalDashboardScreen> {
  final CidanApiService _api = CidanApiService();
  bool _isLoading = true;
  String? _selectedStatusFilter;
  String _searchQuery = '';
  Map<String, dynamic> _metrics = {};
  List<ApprovalWorkflow> _workflows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await _api.getApprovalWorkflows(status: _selectedStatusFilter);
    if (mounted) {
      setState(() {
        _metrics = result['metrics'] as Map<String, dynamic>? ?? {};
        _workflows = result['workflows'] as List<ApprovalWorkflow>? ?? [];
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
      case 'TEST_PASSED':
      case 'DEPLOYED':
        return AppColors.success;
      case 'REJECTED':
      case 'TEST_FAILED':
      case 'DEPLOYMENT_FAILED':
        return AppColors.error;
      case 'UNDER_REVIEW':
      case 'TESTING_IN_PROGRESS':
      case 'DEPLOYMENT_IN_PROGRESS':
        return const Color(0xFF3B82F6);
      case 'CHANGES_REQUESTED':
      case 'ROLLED_BACK':
        return AppColors.warning;
      case 'READY_FOR_TESTING':
      case 'READY_FOR_DEPLOYMENT':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredWorkflows = _workflows.where((w) {
      final matchesSearch = _searchQuery.isEmpty ||
          w.ruleName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.ruleId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (w.circularReference?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Compliance Approval Management',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            tooltip: 'Refresh Queue',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Dashboard Metrics
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),

                    // Section 2: Search & Filter Toolbar
                    _buildFilterToolbar(),
                    const SizedBox(height: 16),

                    // Section 3: Approval Queue
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Approval Queue (${filteredWorkflows.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_selectedStatusFilter != null)
                          TextButton.icon(
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear Filter'),
                            onPressed: () {
                              setState(() => _selectedStatusFilter = null);
                              _loadData();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (filteredWorkflows.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredWorkflows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildWorkflowCard(filteredWorkflows[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricTile('Total Workflows', _metrics['total'] ?? 0, AppColors.textPrimary, Icons.fact_check),
            _buildMetricTile('Pending / Review', _metrics['pending'] ?? 0, const Color(0xFF3B82F6), Icons.hourglass_top),
            _buildMetricTile('Approved', _metrics['approved'] ?? 0, AppColors.success, Icons.check_circle_outline),
            _buildMetricTile('Changes Requested', _metrics['changes_requested'] ?? 0, AppColors.warning, Icons.edit_note),
            _buildMetricTile('Ready for Testing', _metrics['ready_for_testing'] ?? 0, AppColors.primary, Icons.science_outlined),
            _buildMetricTile('Ready Deploy', _metrics['ready_for_deployment'] ?? 0, const Color(0xFF8B5CF6), Icons.cloud_upload_outlined),
            _buildMetricTile('Deployed', _metrics['deployed'] ?? 0, const Color(0xFF059669), Icons.rocket_launch_outlined),
            _buildMetricTile('Rejected', _metrics['rejected'] ?? 0, AppColors.error, Icons.cancel_outlined),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile(String label, dynamic count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxStyle.metricShadow,
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by rule name, rule ID, or circular reference...',
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusPill('All', null),
                _buildStatusPill('Pending Review', 'SUBMITTED_FOR_REVIEW'),
                _buildStatusPill('Under Review', 'UNDER_REVIEW'),
                _buildStatusPill('Changes Requested', 'CHANGES_REQUESTED'),
                _buildStatusPill('Approved', 'APPROVED'),
                _buildStatusPill('Ready for Testing', 'READY_FOR_TESTING'),
                _buildStatusPill('Ready for Deployment', 'READY_FOR_DEPLOYMENT'),
                _buildStatusPill('Deployed', 'DEPLOYED'),
                _buildStatusPill('Rejected', 'REJECTED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, String? statusVal) {
    final isSelected = _selectedStatusFilter == statusVal;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        onSelected: (_) {
          setState(() => _selectedStatusFilter = statusVal);
          _loadData();
        },
      ),
    );
  }

  Widget _buildWorkflowCard(ApprovalWorkflow wf) {
    final statusColor = _getStatusColor(wf.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxStyle.cardShadow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          wf.ruleId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            wf.category,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wf.ruleName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  wf.status.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Author: ${wf.authorEmail}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (wf.circularReference != null) ...[
                const Icon(Icons.description_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  wf.circularReference!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Review & Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApprovalDetailsScreen(workflowId: wf.id),
                    ),
                  );
                  _loadData();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No approval workflows found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Proposed rule changes submitted from the Rule Mapping Studio will appear here for review.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class BoxStyle {
  static BoxShadow get metricShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 6,
        offset: const Offset(0, 2),
      );
  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );
}
