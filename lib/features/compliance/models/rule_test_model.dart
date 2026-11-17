class RuleTestCase {
  final String id;
  final String suiteId;
  final String bankId;
  final String ruleId;
  final String testType;
  final String scenarioName;
  final Map<String, dynamic> inputData;
  final Map<String, dynamic> expectedResult;
  final bool isAiGenerated;
  final bool isMandatory;
  final DateTime? createdAt;

  const RuleTestCase({
    required this.id,
    required this.suiteId,
    required this.bankId,
    required this.ruleId,
    required this.testType,
    required this.scenarioName,
    required this.inputData,
    required this.expectedResult,
    this.isAiGenerated = false,
    this.isMandatory = true,
    this.createdAt,
  });

  factory RuleTestCase.fromJson(Map<String, dynamic> json) {
    return RuleTestCase(
      id: json['id'] as String? ?? '',
      suiteId: json['suite_id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      testType: json['test_type'] as String? ?? 'POSITIVE',
      scenarioName: json['scenario_name'] as String? ?? '',
      inputData: json['input_data'] as Map<String, dynamic>? ?? {},
      expectedResult: json['expected_result'] as Map<String, dynamic>? ?? {},
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      isMandatory: json['is_mandatory'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

class TestCaseResult {
  final String id;
  final String runId;
  final String testCaseId;
  final String testType;
  final String scenarioName;
  final String status;
  final Map<String, dynamic> actualOutput;
  final Map<String, dynamic> expectedOutput;
  final int executionDurationMs;
  final String? errorMessage;

  const TestCaseResult({
    required this.id,
    required this.runId,
    required this.testCaseId,
    required this.testType,
    required this.scenarioName,
    required this.status,
    required this.actualOutput,
    required this.expectedOutput,
    this.executionDurationMs = 0,
    this.errorMessage,
  });

  factory TestCaseResult.fromJson(Map<String, dynamic> json) {
    return TestCaseResult(
      id: json['id'] as String? ?? '',
      runId: json['run_id'] as String? ?? '',
      testCaseId: json['test_case_id'] as String? ?? '',
      testType: json['test_type'] as String? ?? 'POSITIVE',
      scenarioName: json['scenario_name'] as String? ?? '',
      status: json['status'] as String? ?? 'PASS',
      actualOutput: json['actual_output'] as Map<String, dynamic>? ?? {},
      expectedOutput: json['expected_output'] as Map<String, dynamic>? ?? {},
      executionDurationMs: json['execution_duration_ms'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
    );
  }
}

class RuleTestRun {
  final String id;
  final String suiteId;
  final String bankId;
  final String ruleId;
  final String ruleVersion;
  final int totalTestCases;
  final int passedTests;
  final int failedTests;
  final double passPercentage;
  final int executionDurationMs;
  final String status;
  final String startedBy;
  final List<TestCaseResult> results;
  final DateTime? createdAt;

  const RuleTestRun({
    required this.id,
    required this.suiteId,
    required this.bankId,
    required this.ruleId,
    required this.ruleVersion,
    this.totalTestCases = 0,
    this.passedTests = 0,
    this.failedTests = 0,
    this.passPercentage = 0.0,
    this.executionDurationMs = 0,
    required this.status,
    required this.startedBy,
    this.results = const [],
    this.createdAt,
  });

  factory RuleTestRun.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    final resList = rawResults
        .whereType<Map<String, dynamic>>()
        .map((r) => TestCaseResult.fromJson(r))
        .toList();

    return RuleTestRun(
      id: json['id'] as String? ?? '',
      suiteId: json['suite_id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      ruleVersion: json['rule_version'] as String? ?? '1.0',
      totalTestCases: json['total_test_cases'] as int? ?? 0,
      passedTests: json['passed_tests'] as int? ?? 0,
      failedTests: json['failed_tests'] as int? ?? 0,
      passPercentage: (json['pass_percentage'] as num?)?.toDouble() ?? 0.0,
      executionDurationMs: json['execution_duration_ms'] as int? ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      startedBy: json['started_by'] as String? ?? '',
      results: resList,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

class RuleTestSuite {
  final String id;
  final String bankId;
  final String ruleId;
  final String ruleVersion;
  final String suiteName;
  final String description;
  final List<RuleTestCase> testCases;
  final String createdBy;
  final DateTime? createdAt;

  const RuleTestSuite({
    required this.id,
    required this.bankId,
    required this.ruleId,
    required this.ruleVersion,
    required this.suiteName,
    this.description = '',
    this.testCases = const [],
    required this.createdBy,
    this.createdAt,
  });

  factory RuleTestSuite.fromJson(Map<String, dynamic> json) {
    final rawCases = json['test_cases'] as List<dynamic>? ?? [];
    final cases = rawCases
        .whereType<Map<String, dynamic>>()
        .map((c) => RuleTestCase.fromJson(c))
        .toList();

    return RuleTestSuite(
      id: json['id'] as String? ?? '',
      bankId: json['bank_id'] as String? ?? '',
      ruleId: json['rule_id'] as String? ?? '',
      ruleVersion: json['rule_version'] as String? ?? '1.0',
      suiteName: json['suite_name'] as String? ?? 'Test Suite',
      description: json['description'] as String? ?? '',
      testCases: cases,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
