import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/rule_test_model.dart';
import '../services/cidan_api_service.dart';
import 'deployment_console_screen.dart';

class TestSimulationScreen extends StatefulWidget {
  final String ruleId;
  const TestSimulationScreen({super.key, this.ruleId = 'APEX-AML-100'});

  @override
  State<TestSimulationScreen> createState() => _TestSimulationScreenState();
}

class _TestSimulationScreenState extends State<TestSimulationScreen> {
  final CidanApiService _api = CidanApiService();
  bool _isLoading = true;
  bool _isRunning = false;
  List<RuleTestSuite> _suites = [];
  RuleTestSuite? _selectedSuite;
  RuleTestRun? _latestRun;

  @override
  void initState() {
    super.initState();
    _loadSuites();
  }

  Future<void> _loadSuites() async {
    setState(() => _isLoading = true);
    final suites = await _api.getTestSuites(ruleId: widget.ruleId);
    RuleTestRun? latestRun;

    if (suites.isNotEmpty) {
      final runs = await _api.getTestRuns(suiteId: suites.first.id);
      if (runs.isNotEmpty) latestRun = runs.first;
    }

    if (mounted) {
      setState(() {
        _suites = suites;
        if (_suites.isNotEmpty) _selectedSuite = _suites.first;
        _latestRun = latestRun;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGenerateCases() async {
    setState(() => _isLoading = true);
    // Create or use current suite
    var suite = _selectedSuite;
    suite ??= await _api.createTestSuite(
      ruleId: widget.ruleId,
      ruleVersion: '1.0',
      suiteName: '${widget.ruleId} Boundary & Regression Suite',
    );

    if (suite != null) {
      final generated = await _api.generateTestCases({
        'rule_id': widget.ruleId,
        'condition_tree': {
          'operator': 'AND',
          'conditions': [
            {'field': 'transaction_amount', 'operator': 'gte', 'value': 500000.0},
            {'field': 'is_international', 'operator': 'eq', 'value': true},
          ],
        },
      });

      for (final tc in generated) {
        await _api.addTestCase(
          suiteId: suite.id,
          testType: tc.testType,
          scenarioName: tc.scenarioName,
          inputData: tc.inputData,
          expectedResult: tc.expectedResult,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${generated.length} boundary & regression test cases!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadSuites();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRunTests() async {
    if (_selectedSuite == null) return;
    setState(() => _isRunning = true);
    final run = await _api.runTestSuite(_selectedSuite!.id);
    if (mounted) {
      setState(() {
        _latestRun = run;
        _isRunning = false;
      });
      if (run != null) {
        final isPassed = run.status == 'PASSED';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPassed
                ? 'All ${run.totalTestCases} tests PASSED! Rule is eligible for deployment.'
                : 'Tests failed (${run.failedTests} errors). Deployment is blocked by safety gates.'),
            backgroundColor: isPassed ? AppColors.success : AppColors.error,
          ),
        );
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
          'Simulation Studio: ${widget.ruleId}',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadSuites,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Sandbox Notice
                  _buildEnvironmentNotice(),
                  const SizedBox(height: 20),

                  // Section 2: Controls & Suite Selection
                  _buildSuiteControls(),
                  const SizedBox(height: 20),

                  // Section 3: Test Run Results Dashboard
                  if (_latestRun != null) ...[
                    _buildResultsDashboard(_latestRun!),
                    const SizedBox(height: 20),
                  ],

                  // Section 4: Test Cases & Assertions List
                  _buildTestCasesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEnvironmentNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Isolated Simulation Sandbox Active',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 13),
                ),
                Text(
                  'Simulation tests run against synthetic memory state. Zero impact on live production banking accounts or customer data.',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuiteControls() {
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
                  _selectedSuite?.suiteName ?? 'No Test Suite Configured',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate Boundary Cases'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                onPressed: _handleGenerateCases,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: _isRunning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_isRunning ? 'Simulating...' : 'Execute Suite'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _isRunning ? null : _handleRunTests,
              ),
            ],
          ),
          if (_selectedSuite != null) ...[
            const SizedBox(height: 8),
            Text(
              'Rule Version: ${_selectedSuite!.ruleVersion} • Cases: ${_selectedSuite!.testCases.length} • Created by: ${_selectedSuite!.createdBy}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsDashboard(RuleTestRun run) {
    final isPassed = run.status == 'PASSED';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPassed ? AppColors.success.withValues(alpha: 0.5) : AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPassed ? Icons.check_circle : Icons.error_outline, color: isPassed ? AppColors.success : AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Latest Run Results: ${run.status}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPassed ? AppColors.success : AppColors.error),
              ),
              const Spacer(),
              if (isPassed)
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Proceed to Deployment Console'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeploymentConsoleScreen(ruleId: widget.ruleId),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip('Pass Rate', '${run.passPercentage}%', isPassed ? AppColors.success : AppColors.error),
              const SizedBox(width: 12),
              _buildStatChip('Total Cases', run.totalTestCases.toString(), AppColors.textPrimary),
              const SizedBox(width: 12),
              _buildStatChip('Passed', run.passedTests.toString(), AppColors.success),
              const SizedBox(width: 12),
              _buildStatChip('Failed', run.failedTests.toString(), run.failedTests > 0 ? AppColors.error : AppColors.textSecondary),
              const SizedBox(width: 12),
              _buildStatChip('Duration', '${run.executionDurationMs} ms', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTestCasesList() {
    final cases = _selectedSuite?.testCases ?? [];
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
          Text('Test Scenarios & Assertions (${cases.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          if (cases.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No test cases in this suite. Click "Generate Boundary Cases" above to auto-create them.', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cases.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final tc = cases[idx];
                final result = _latestRun?.results.firstWhere(
                  (r) => r.testCaseId == tc.id,
                  orElse: () => TestCaseResult(
                    id: '',
                    runId: '',
                    testCaseId: tc.id,
                    testType: tc.testType,
                    scenarioName: tc.scenarioName,
                    status: 'PENDING',
                    actualOutput: {},
                    expectedOutput: tc.expectedResult,
                  ),
                );

                final isPassed = result?.status == 'PASS';
                final isFailed = result?.status == 'FAIL';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getTestTypeColor(tc.testType).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tc.testType,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getTestTypeColor(tc.testType)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tc.scenarioName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Input: ${tc.inputData}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          if (result?.errorMessage != null) ...[
                            const SizedBox(height: 4),
                            Text('Error: ${result!.errorMessage}', style: const TextStyle(fontSize: 11, color: AppColors.error)),
                          ],
                        ],
                      ),
                    ),
                    if (result?.status != 'PENDING') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPassed ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result!.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? AppColors.success : (isFailed ? AppColors.error : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getTestTypeColor(String type) {
    switch (type) {
      case 'BOUNDARY':
        return const Color(0xFFF59E0B);
      case 'POSITIVE':
        return AppColors.success;
      case 'NEGATIVE':
        return const Color(0xFF6B7280);
      case 'REGRESSION':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}
