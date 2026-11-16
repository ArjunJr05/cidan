import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/compliance_report_model.dart';

class CidanApiService {
  static const String baseUrl = 'https://virtusa-agent.onrender.com';
  static const String authToken =
      '0Zh3yr-Srn3juPBBl3IUSgV_2HDz-4WIrmP1uyDC_5E';

  static final CidanApiService _instance = CidanApiService._internal();
  factory CidanApiService() => _instance;
  CidanApiService._internal();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Trigger document analysis workflow on virtusa-agent backend
  Future<ComplianceReportModel> analyzeDocument({
    String? filename,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/workflows/analyze');
      final body = jsonEncode({
        if (filename != null) 'filename': filename,
      });

      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return ComplianceReportModel.fromJson(jsonMap);
      } else {
        return ComplianceReportModel.defaultSample();
      }
    } catch (_) {
      return ComplianceReportModel.defaultSample();
    }
  }

  /// Fetch specific workflow details
  Future<ComplianceReportModel> getWorkflow(String workflowId) async {
    try {
      final uri = Uri.parse('$baseUrl/workflows/$workflowId');
      final response = await http
          .get(uri, headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ComplianceReportModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}

    return ComplianceReportModel.defaultSample();
  }

  /// Approve compliance rule
  Future<bool> approveRule(String ruleId) async {
    try {
      final uri = Uri.parse('$baseUrl/rules/$ruleId/approve');
      final response = await http
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true;
    }
  }
}
