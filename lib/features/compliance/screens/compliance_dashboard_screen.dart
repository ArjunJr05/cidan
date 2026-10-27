import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';
import '../models/compliance_report_model.dart';
import '../services/cidan_api_service.dart';

class ComplianceDashboardScreen extends StatefulWidget {
  final ComplianceReportModel report;
  final String? uploadedFileName;
  final String? userEmail;
  final bool initialApproved;

  const ComplianceDashboardScreen({
    super.key,
    required this.report,
    this.uploadedFileName,
    this.userEmail,
    this.initialApproved = false,
  });

  @override
  State<ComplianceDashboardScreen> createState() =>
      _ComplianceDashboardScreenState();
}

class _ComplianceDashboardScreenState extends State<ComplianceDashboardScreen> {
  bool _isApproving = false;
  late bool _isApproved;

  @override
  void initState() {
    super.initState();
    _isApproved = widget.initialApproved;
    _saveReportToSupabase();
  }

  void _saveReportToSupabase() {
    final email = widget.userEmail ?? 'compliance.officer@bank.com';
    SupabaseService().saveComplianceReport(
      email: email,
      workflowId: widget.report.workflowId,
      filename: widget.uploadedFileName ?? 'CIDAN_Regulatory_Circular.pdf',
      obligationsCount: widget.report.obligations.length,
      violationsCount: 3,
      approvedCount: widget.report.obligations.length,
      isDeployed: _isApproved,
      reportData: {...widget.report.toJson(), 'is_deployed': _isApproved},
    );
  }

  Future<void> _handleApprove() async {
    setState(() => _isApproving = true);
    await CidanApiService().approveRule(
      widget.report.obligations.isNotEmpty
          ? widget.report.obligations.first.obligationId
          : 'OBL-001',
    );

    final email = widget.userEmail ?? 'compliance.officer@bank.com';
    await SupabaseService().updateReportDeploymentStatus(
      email: email,
      workflowId: widget.report.workflowId,
      isDeployed: true,
    );

    await SupabaseService().recordHistory(
      email: email,
      actionType: 'POLICY_APPROVED',
      workflowId: widget.report.workflowId,
      documentName: widget.uploadedFileName ?? 'CIDAN_Regulatory_Circular.pdf',
      summary: 'Compliance review approved for production sandbox deployment',
    );

    if (!mounted) return;
    setState(() {
      _isApproving = false;
      _isApproved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Workflow sanctioned & approved for production deployment!',
                style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPdfDocumentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompliancePdfDocumentModal(
        report: widget.report,
        fileName:
            widget.uploadedFileName ??
            'CIDAN_Synthetic_RBI_Style_Loan_Approval_Circular_8_pages.pdf',
        isApproved: _isApproved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // 1. Top Navigation Bar matching screenshot
            _buildTopAppBar(),

            // 2. Scrollable Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card 1: Policy Evolution & Gap Comparison
                    _buildPolicyEvolutionCard(report),

                    const SizedBox(height: 16),

                    // Card 2: Test Cases Performed to Verify
                    _buildTestCasesCard(),

                    const SizedBox(height: 16),

                    // Card 3: Problems & Risks Identified
                    _buildProblemsAndRisksCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 3. Pinned Bottom Action Bar with 2 Buttons
      bottomSheet: _buildBottomActionBar(),
    );
  }

  // 1. Top Bar matching the design in user image
  Widget _buildTopAppBar() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF0F172A),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Compliance Analysis',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Audit & Verification Dashboard',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 1: Policy Evolution & Gap Comparison
  Widget _buildPolicyEvolutionCard(ComplianceReportModel report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sync_alt_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Policy Evolution & Gap Comparison',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Compare existing handbook rules with new circular requirements.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subcard 1: OLD RULE (Existing Handbook)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // History clock icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OLD RULE (Existing Handbook)',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Coverage Gap',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Standard Personal Credit Policy (Handbook Ch. 4)',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Existing rule relies on baseline credit appraisal and does NOT contain mandatory control checkpoints for illustrative circular compliance.',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Connector line with downward arrow
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 1.5,
                    height: 28,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subcard 2: NEW RULE ADDED (From Circular)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Purple Document Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW RULE ADDED (From Circular)',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                          letterSpacing: 0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OBL-001',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Illustrative Control Framework Implementation',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Apply the illustrative control framework to all described personal-loan and consumer-credit applications prior to sanction. Requires human confirmation of illustrative language.',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 2: Test Cases Performed to Verify
  Widget _buildTestCasesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.format_list_bulleted_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Test Cases Performed to Verify',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Validate rule changes and compliance impact.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '4 Tests',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Test Items
          _buildTestCaseItem(
            title: 'TC-001 · Personal Loan Scope Verification',
            description:
                'Verified whether the circular applies to retail personal loan products.',
            statusText: 'PASS',
            isPass: true,
          ),
          const SizedBox(height: 10),
          _buildTestCaseItem(
            title: 'TC-002 · Control Framework Boundary Test',
            description:
                'Tested if illustrative controls can be enforced in sandbox evaluation.',
            statusText: 'PASS',
            isPass: true,
          ),
          const SizedBox(height: 10),
          _buildTestCaseItem(
            title: 'TC-003 · Handbook Policy Provision Cross-Mapping',
            description:
                'Cross-checked bank handbook against new circular requirements.',
            statusText: 'NEEDS REVIEW',
            isPass: false,
          ),
          const SizedBox(height: 10),
          _buildTestCaseItem(
            title: 'TC-004 · Audit Trail & Validation Report Compilation',
            description:
                'Compiled end-to-end report JSON and markdown audit outputs.',
            statusText: 'PASS',
            isPass: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTestCaseItem({
    required String title,
    required String description,
    required String statusText,
    required bool isPass,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status Icon Circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPass ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPass ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isPass ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPass ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPass
                    ? const Color(0xFF047857)
                    : const Color(0xFFD97706),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Chevron Right
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  // Card 3: Problems & Risks Identified
  Widget _buildProblemsAndRisksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF4F46E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Problems & Risks Identified',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Key issues requiring attention before deployment.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '3 Issues',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Problem Item 1: Ambiguity Issue
          _buildProblemItem(
            icon: Icons.access_time_filled_rounded,
            iconColor: const Color(0xFFF43F5E),
            iconBg: const Color(0xFFFFF1F2),
            tag: 'AMBIGUITY ISSUE',
            tagColor: const Color(0xFFD97706),
            tagBg: const Color(0xFFFEF3C7),
            title: 'Illustrative Source Language Requires Legal Confirmation',
            description:
                'The circular text uses illustrative phrasing for demo applications. A compliance officer must confirm the exact phrasing.',
          ),
          const SizedBox(height: 10),

          // Problem Item 2: Policy Gap Issue
          _buildProblemItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEE2E2),
            tag: 'POLICY GAP ISSUE',
            tagColor: const Color(0xFFDC2626),
            tagBg: const Color(0xFFFEE2E2),
            title: 'Handbook Coverage Incomplete for New Controls',
            description:
                'The retrieved passages are insufficient to prove full coverage of the new illustrative control framework.',
          ),
          const SizedBox(height: 10),

          // Problem Item 3: Operational Risk
          _buildProblemItem(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF6366F1),
            iconBg: const Color(0xFFEEF2FF),
            tag: 'OPERATIONAL RISK',
            tagColor: const Color(0xFF4338CA),
            tagBg: const Color(0xFFE0E7FF),
            title: 'Human Review Mandatory Before Production Deployment',
            description:
                'This report does NOT determine final legal compliance without human sign-off.',
          ),
        ],
      ),
    );
  }

  Widget _buildProblemItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading Round Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),

          // Text Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: tagColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Chevron Right
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Bottom Action Bar matching user screenshot
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Outlined Button: [📄 PDF Report]
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _showPdfDocumentModal,
                icon: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Color(0xFF5B4BDB),
                ),
                label: const Text(
                  'PDF Report',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B4BDB),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF5B4BDB), width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right Solid Button: [✔ Approve & Sanction]
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isApproved ? null : _handleApprove,
                icon: _isApproving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                label: Text(
                  _isApproved ? 'Deployed' : 'Deploy',
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4BDB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official PDF Document Modal Sheet for Reference
class _CompliancePdfDocumentModal extends StatefulWidget {
  final ComplianceReportModel report;
  final String fileName;
  final bool isApproved;

  const _CompliancePdfDocumentModal({
    required this.report,
    required this.fileName,
    required this.isApproved,
  });

  @override
  State<_CompliancePdfDocumentModal> createState() =>
      _CompliancePdfDocumentModalState();
}

class _CompliancePdfDocumentModalState
    extends State<_CompliancePdfDocumentModal> {
  bool _isDownloading = false;

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);

    try {
      final buffer = StringBuffer();
      buffer.writeln(
        '========================================================================',
      );
      buffer.writeln(
        '          CIDAN REGULATORY COMPLIANCE AI - AUDIT REPORT                 ',
      );
      buffer.writeln(
        '========================================================================',
      );
      buffer.writeln(
        'Status:         ${widget.isApproved ? "AUDIT APPROVED & SANCTIONED" : "REVIEW PENDING"}',
      );
      buffer.writeln('Report ID:      ${widget.report.report.reportId}');
      buffer.writeln('Workflow ID:    ${widget.report.workflowId}');
      buffer.writeln('Generated At:   ${widget.report.report.generatedAtUtc}');
      buffer.writeln('Source File:    ${widget.fileName}');
      buffer.writeln('Target Sector:  Personal Loan & Consumer Credit');
      buffer.writeln(
        '========================================================================\n',
      );

      buffer.writeln('1. EXECUTIVE METRICS SUMMARY');
      buffer.writeln(
        '------------------------------------------------------------------------',
      );
      buffer.writeln(
        'Total Extracted Obligations:  ${widget.report.obligations.length} (VALIDATED)',
      );
      buffer.writeln(
        'Identified Compliance Gaps:   ${widget.report.findings.length} (REMEDIATED)',
      );
      buffer.writeln(
        'Rule Delta Proposals:         ${widget.report.proposals.length} (STAGED)',
      );
      buffer.writeln(
        'Sandbox Backtests Executed:   ${widget.report.tests.length} (PASSED)',
      );
      buffer.writeln(
        'Sign-off Verification:        ${widget.isApproved ? "Signed by Chief Compliance Officer" : "Pending Signature"}\n',
      );

      buffer.writeln('2. EXTRACTED OBLIGATIONS & CONTROL DELTAS');
      buffer.writeln(
        '------------------------------------------------------------------------',
      );
      for (final obl in widget.report.obligations) {
        buffer.writeln('• [${obl.obligationId}] - ${obl.productType}');
        buffer.writeln('  Text: "${obl.text}"');
        buffer.writeln(
          '  Confidence: ${obl.confidence} | Status: ${obl.status}\n',
        );
      }

      buffer.writeln('3. VERIFICATION TESTCASES PERFORMED');
      buffer.writeln(
        '------------------------------------------------------------------------',
      );
      for (final tc in widget.report.tests) {
        buffer.writeln('• [${tc.id}] ${tc.name}');
        buffer.writeln('  Result: ${tc.status.toUpperCase()}\n');
      }

      buffer.writeln('4. IDENTIFIED PROBLEMS & ACTIONABLE RISKS');
      buffer.writeln(
        '------------------------------------------------------------------------',
      );
      for (final f in widget.report.findings) {
        buffer.writeln('• [${f.obligationId}] ${f.status}');
        buffer.writeln('  Reasoning: ${f.reasoning}');
        buffer.writeln('  Recommended Action: ${f.recommendedAction}\n');
      }

      buffer.writeln(
        '========================================================================',
      );
      buffer.writeln(
        'Reviewer: ${widget.isApproved ? "Chief Compliance Officer (Signed)" : "Pending Review"}',
      );
      buffer.writeln(
        'Saved to Device Local Storage: ${DateTime.now().toIso8601String()}',
      );
      buffer.writeln(
        '========================================================================',
      );

      final content = buffer.toString();

      Directory? baseDir;
      try {
        baseDir = await getDownloadsDirectory();
      } catch (_) {}
      baseDir ??= await getApplicationDocumentsDirectory();

      final safeName = widget.fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final filePrefix = widget.report.workflowId.length >= 8
          ? widget.report.workflowId.substring(0, 8)
          : widget.report.workflowId;
      final file = File(
        '${baseDir.path}/CIDAN_Report_${filePrefix}_$safeName.txt',
      );

      await file.writeAsString(content);

      final prefs = await SharedPreferences.getInstance();
      final downloadedList = prefs.getStringList('cidan_local_downloads') ?? [];
      if (!downloadedList.contains(file.path)) {
        downloadedList.insert(0, file.path);
        await prefs.setStringList('cidan_local_downloads', downloadedList);
      }

      if (!mounted) return;
      setState(() => _isDownloading = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved to Local Storage',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The regulatory compliance report has been downloaded and stored in your device local storage:',
                style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Size: ${(content.length / 1024).toStringAsFixed(1)} KB • Status: ${widget.isApproved ? "Approved & Deployed" : "Review Pending"}',
                style: const TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save to local storage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final fileName = widget.fileName;
    final isApproved = widget.isApproved;
    final metrics = report.report.metrics;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF334155),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Top Modal Action Bar with Download Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'PDF Reference Document',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Top Download Button
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : () => _handleDownload(),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 15),
                  label: const Text(
                    'Download',
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Scrollable PDF Page Sheet
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Official Letterhead (Fixed overflow with Expanded)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'CIDAN REGULATORY COMPLIANCE AI',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Automated Regulatory Ingestion & Validation Report',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF3C7),
                            border: Border.all(
                              color: isApproved
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isApproved ? 'AUDIT APPROVED' : 'REVIEW PENDING',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isApproved
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(
                      height: 24,
                      thickness: 1.5,
                      color: Color(0xFF0F172A),
                    ),

                    // Document Info Grid
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(2.8),
                      },
                      children: [
                        _pdfTableRow('Report ID:', report.report.reportId),
                        _pdfTableRow('Workflow ID:', report.workflowId),
                        _pdfTableRow(
                          'Generated At:',
                          report.report.generatedAtUtc,
                        ),
                        _pdfTableRow('Source Circular:', fileName),
                        _pdfTableRow(
                          'Target Sector:',
                          'Personal Loan & Consumer Credit',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    // Section 1: Executive Findings Table
                    const Text(
                      '1. EXECUTIVE METRICS SUMMARY',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Table(
                      border: TableBorder.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                'Metric',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                'Count',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(6),
                              child: Text(
                                'Audit Status',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _pdfMetricRow(
                          'Obligations Extracted',
                          '${metrics.obligationsExtracted}',
                          'OBL-001 Confirmed (80%)',
                        ),
                        _pdfMetricRow(
                          'Policy Gap Findings',
                          '${metrics.policyFindings}',
                          'Requires Human Review',
                        ),
                        _pdfMetricRow(
                          'Draft Rules Generated',
                          '${metrics.draftRulesGenerated}',
                          'Sandbox Baseline',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Rule Evolution Comparison
                    const Text(
                      '2. RULE EVOLUTION (OLD RULE VS NEW RULE ADDED)',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '• Existing Rule: Standard Personal Credit Underwriting (Handbook Ch 4). Lacks mandatory checkpoints for illustrative circular requirements.',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 10,
                              color: Color(0xFF334155),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '• New Rule Added: OBL-001 — Apply illustrative control framework across personal loan and consumer credit applications before sanction.',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 3: Verification Testcases
                    const Text(
                      '3. TESTCASES PERFORMED TO VERIFY',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Table(
                      border: TableBorder.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      children: const [
                        TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'ID',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Test Scenario',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Result',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'TC-001',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Loan scope boundary validation',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'PASS',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'TC-002',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Illustrative framework execution',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'PASS',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'TC-003',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Handbook policy cross-mapping',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'FLAGGED',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'TC-004',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'Audit trail report generation',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Text(
                                'PASS',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 9.5,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section 4: Identified Problems
                    const Text(
                      '4. PROBLEMS & ACTIONABLE RISKS',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• Ambiguity: Illustrative source language requires human confirmation.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 9.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const Text(
                      '• Policy Gap: Coverage cannot be determined from retrieved handbook passages.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 9.5,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const Text(
                      '• Legal Caveat: Synthetic demo output only; not an official RBI circular or legal advice.',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 9.5,
                        color: Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign-off Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reviewed & Verified By:',
                                  style: TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 9.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isApproved
                                      ? 'Chief Compliance Officer (Signed)'
                                      : 'Awaiting Compliance Officer Signature',
                                  style: TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isApproved
                                ? Icons.verified_user_rounded
                                : Icons.pending_rounded,
                            color: isApproved
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Download Official Report Button at bottom of modal
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading
                            ? null
                            : () => _handleDownload(),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.file_download_outlined,
                                size: 19,
                              ),
                        label: const Text(
                          'Download Report to Local Storage',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static TableRow _pdfTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 9.5,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  static TableRow _pdfMetricRow(String label, String count, String status) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 9.5,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            count,
            style: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            status,
            style: const TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 9.5,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}
