import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/rule_version_model.dart';
import '../services/cidan_api_service.dart';

class RuleVersionScreen extends StatefulWidget {
  final String ruleId;
  const RuleVersionScreen({super.key, this.ruleId = 'APEX-AML-100'});

  @override
  State<RuleVersionScreen> createState() => _RuleVersionScreenState();
}

class _RuleVersionScreenState extends State<RuleVersionScreen> {
  final CidanApiService _api = CidanApiService();
  bool _isLoading = true;
  List<RuleVersion> _versions = [];
  RuleVersionComparison? _comparison;
  String? _selectedBaseVersion;
  String? _selectedTargetVersion;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    final list = await _api.getRuleVersions(widget.ruleId);
    if (mounted) {
      setState(() {
        _versions = list;
        if (_versions.length >= 2) {
          _selectedBaseVersion = _versions.last.versionNumber;
          _selectedTargetVersion = _versions.first.versionNumber;
          _compareSelected();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _compareSelected() async {
    if (_selectedBaseVersion == null || _selectedTargetVersion == null) return;
    final cmp = await _api.compareRuleVersions(
      ruleId: widget.ruleId,
      baseVersion: _selectedBaseVersion!,
      targetVersion: _selectedTargetVersion!,
    );
    if (mounted) {
      setState(() => _comparison = cmp);
    }
  }

  Future<void> _showCreateVersionDialog() async {
    final summaryController = TextEditingController();
    String bumpType = 'minor';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Rule Version Snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rule: ${widget.ruleId}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 12),
                const Text('Version Increment Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: bumpType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'minor', child: Text('Minor (e.g. 1.0 -> 1.1 - Threshold/condition update)')),
                    DropdownMenuItem(value: 'major', child: Text('Major (e.g. 1.1 -> 2.0 - Major policy overhaul)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => bumpType = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Change Summary (Required):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: summaryController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe regulatory updates, threshold revisions, or condition additions...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (summaryController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Create Snapshot', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() => _isLoading = true);
      final newVer = await _api.createRuleVersion(
        ruleId: widget.ruleId,
        ruleIrSnapshot: {
          'rule_id': widget.ruleId,
          'version': bumpType == 'major' ? 2 : 1,
          'condition_tree': {'operator': 'AND', 'conditions': []},
        },
        changeSummary: summaryController.text.trim(),
        bumpType: bumpType,
      );
      if (mounted) {
        if (newVer != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Version ${newVer.versionNumber} created successfully!'), backgroundColor: AppColors.success),
          );
          _loadVersions();
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Version Control: ${widget.ruleId}',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create Version Snapshot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: _showCreateVersionDialog,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Version History Timeline
                  _buildVersionTimeline(),
                  const SizedBox(height: 24),

                  // Section 2: Version Comparison Tool
                  _buildComparisonTool(),
                ],
              ),
            ),
    );
  }

  Widget _buildVersionTimeline() {
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
          const Text('Immutable Version History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('All versions are cryptographically traceable and preserved.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (_versions.isEmpty)
            const Text('No historical versions recorded yet.', style: TextStyle(color: AppColors.textMuted))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _versions.length,
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (context, idx) {
                final v = _versions[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: v.isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${v.versionNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: v.isActive ? AppColors.success : AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.changeSummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Author: ${v.createdBy} • Source: ${v.changeSource}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (v.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('ACTIVE PROD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonTool() {
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
          const Text('Semantic Version Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBaseVersion,
                  decoration: const InputDecoration(labelText: 'Base Version', border: OutlineInputBorder()),
                  items: _versions.map((v) => DropdownMenuItem(value: v.versionNumber, child: Text('Version ${v.versionNumber}'))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedBaseVersion = val);
                    _compareSelected();
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, color: AppColors.textSecondary),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedTargetVersion,
                  decoration: const InputDecoration(labelText: 'Target Version', border: OutlineInputBorder()),
                  items: _versions.map((v) => DropdownMenuItem(value: v.versionNumber, child: Text('Version ${v.versionNumber}'))).toList(),
                  onChanged: (val) {
                    setState(() => _selectedTargetVersion = val);
                    _compareSelected();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_comparison != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _comparison!.hasBreakingChanges ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _comparison!.hasBreakingChanges ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: _comparison!.hasBreakingChanges ? AppColors.warning : AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _comparison!.summary,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _comparison!.hasBreakingChanges ? AppColors.warning : AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._comparison!.differences.map((d) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(d.changeType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(d.description, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
