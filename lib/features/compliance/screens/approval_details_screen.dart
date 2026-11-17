import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/approval_workflow_model.dart';
import '../services/cidan_api_service.dart';
import 'test_simulation_screen.dart';

class ApprovalDetailsScreen extends StatefulWidget {
  final String workflowId;
  const ApprovalDetailsScreen({super.key, required this.workflowId});

  @override
  State<ApprovalDetailsScreen> createState() => _ApprovalDetailsScreenState();
}

class _ApprovalDetailsScreenState extends State<ApprovalDetailsScreen> {
  final CidanApiService _api = CidanApiService();
  bool _isLoading = true;
  ApprovalWorkflow? _workflow;
  List<ApprovalDecisionRecord> _decisions = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await _api.getApprovalWorkflowDetail(widget.workflowId);
    if (mounted) {
      setState(() {
        if (result != null) {
          _workflow = result['workflow'] as ApprovalWorkflow?;
          _decisions = result['decisions'] as List<ApprovalDecisionRecord>? ?? [];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDecision(String action) async {
    final commentsController = TextEditingController();
    String selectedRole = 'COMPLIANCE_ANALYST';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isReject = action == 'REJECTED';
            final isChangeReq = action == 'CHANGES_REQUESTED';
            final title = isReject
                ? 'Reject Rule Change'
                : (isChangeReq ? 'Request Changes' : 'Approve Rule Change');
            final color = isReject ? AppColors.error : (isChangeReq ? AppColors.warning : AppColors.success);

            return AlertDialog(
              title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Your Reviewer Role:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'COMPLIANCE_ANALYST', child: Text('Compliance Analyst')),
                        DropdownMenuItem(value: 'COMPLIANCE_MANAGER', child: Text('Compliance Manager')),
                        DropdownMenuItem(value: 'RISK_OFFICER', child: Text('Risk Officer')),
                        DropdownMenuItem(value: 'TECHNICAL_APPROVER', child: Text('Technical Approver')),
                        DropdownMenuItem(value: 'DEPLOYMENT_ADMIN', child: Text('Deployment Administrator')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isReject ? 'Rejection Justification (Required):' : 'Reviewer Comments / Instructions:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isReject ? 'Enter detailed policy reasons for rejection...' : 'Add audit notes...',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () {
                    if (isReject && commentsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rejection requires explicit comments.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(action.replaceAll('_', ' '), style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final ok = await _api.executeApprovalAction(
        workflowId: widget.workflowId,
        action: action,
        comments: commentsController.text.trim(),
        role: selectedRole,
        rejectionReason: action == 'REJECTED' ? commentsController.text.trim() : null,
        changeRequestNotes: action == 'CHANGES_REQUESTED' ? commentsController.text.trim() : null,
      );

      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Workflow transitioned to $action successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDetail();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action failed. Check separation of duties or valid state transition.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_workflow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workflow Details')),
        body: const Center(child: Text('Approval workflow record not found.')),
      );
    }

    final wf = _workflow!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Workflow: ${wf.ruleId}',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadDetail,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            _buildHeaderBanner(wf),
            const SizedBox(height: 20),

            // Multi-Stage Visual Pipeline
            _buildPipelineStepper(wf),
            const SizedBox(height: 20),

            // Rule Details & Snapshot
            _buildRuleDetailsSection(wf),
            const SizedBox(height: 20),

            // Approval Decision History
            _buildDecisionHistory(),
            const SizedBox(height: 30),

            // Reviewer Action Buttons
            _buildActionButtons(wf),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(ApprovalWorkflow wf) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  wf.ruleName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  wf.status.replaceAll('_', ' '),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Rule ID: ${wf.ruleId}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Author: ${wf.authorEmail}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              if (wf.circularReference != null) ...[
                const Icon(Icons.receipt_long, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(wf.circularReference!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
          if (wf.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Rejection Reason: ${wf.rejectionReason}',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineStepper(ApprovalWorkflow wf) {
    final stages = wf.requiredStages;
    if (stages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Pipeline Stages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(stages.length, (idx) {
                final stage = stages[idx];
                final isCompleted = idx < wf.currentStageIndex || wf.status == 'APPROVED';
                final isCurrent = idx == wf.currentStageIndex && wf.status != 'APPROVED';

                final color = isCompleted
                    ? AppColors.success
                    : (isCurrent ? AppColors.primary : AppColors.textMuted);

                return Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            isCompleted ? Icons.check : (isCurrent ? Icons.circle : Icons.circle_outlined),
                            size: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stage.stageName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          stage.requiredRole,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (idx < stages.length - 1)
                      Container(
                        width: 40,
                        height: 2,
                        color: isCompleted ? AppColors.success : AppColors.border,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleDetailsSection(ApprovalWorkflow wf) {
    final condTree = wf.ruleIrSnapshot['condition_tree'] as Map<String, dynamic>? ?? {};
    final conditions = condTree['conditions'] as List<dynamic>? ?? [];
    final actions = wf.ruleIrSnapshot['actions'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proposed Rule IR Specification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Text('Logic Operator: ${condTree['operator'] ?? 'AND'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Conditions:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          ...conditions.map((c) {
            final cmap = c as Map<String, dynamic>? ?? {};
            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '• ${cmap['field']} ${cmap['operator']} ${cmap['value']}',
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            );
          }),
          const SizedBox(height: 10),
          const Text('Actions:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          ...actions.map((a) {
            final amap = a as Map<String, dynamic>? ?? {};
            return Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                '• ${amap['action_type']} -> target: ${amap['target']}',
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppColors.primary),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDecisionHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Approval Audit Trail & Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (_decisions.isEmpty)
            const Text('No decisions recorded yet. Initial submission pending review.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _decisions.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final d = _decisions[idx];
                final isApprove = d.decision == 'APPROVED';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: (isApprove ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                      child: Icon(
                        isApprove ? Icons.check : Icons.close,
                        size: 14,
                        color: isApprove ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(d.stageName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(d.approverRole, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                              ),
                              const Spacer(),
                              if (d.decidedAt != null)
                                Text(
                                  '${d.decidedAt!.hour.toString().padLeft(2, '0')}:${d.decidedAt!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('By: ${d.approverEmail}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          if (d.comments.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('"${d.comments}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ApprovalWorkflow wf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          if (['READY_FOR_TESTING', 'TEST_FAILED', 'TEST_PASSED'].contains(wf.status)) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.science_outlined, size: 16),
              label: const Text('Open Test Simulation Studio'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestSimulationScreen(ruleId: wf.ruleId),
                  ),
                );
              },
            ),
          ],
          if (['SUBMITTED_FOR_REVIEW', 'UNDER_REVIEW', 'RESUBMITTED'].contains(wf.status)) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note, size: 16),
              label: const Text('Request Changes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
              onPressed: () => _handleDecision('CHANGES_REQUESTED'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: () => _handleDecision('REJECTED'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Approve Step'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => _handleDecision('APPROVED'),
            ),
          ],
          if (wf.status == 'CHANGES_REQUESTED') ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Resubmit Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => _handleDecision('RESUBMITTED'),
            ),
          ],
        ],
      ),
    );
  }
}
