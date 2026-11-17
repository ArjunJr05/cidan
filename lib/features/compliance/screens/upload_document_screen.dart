import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/screens/login_screen.dart';
import '../models/bank_integration_model.dart';
import '../models/compliance_report_model.dart';
import '../models/existing_rule_model.dart';
import '../models/regulatory_document_model.dart';
import '../services/cidan_api_service.dart';
import '../widgets/circular_metadata_dialog.dart';
import '../widgets/connect_cidan_dialog.dart';
import '../widgets/dashed_border_painter.dart';
import 'compliance_dashboard_screen.dart';
import 'rule_mapping_studio_screen.dart';

enum UploadProcessStep { initial, completed }

class UploadDocumentScreen extends StatefulWidget {
  final String email;
  final UploadProcessStep initialStep;
  final String? initialFileName;
  final String? initialFileSize;

  const UploadDocumentScreen({
    super.key,
    required this.email,
    this.initialStep = UploadProcessStep.initial,
    this.initialFileName,
    this.initialFileSize,
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  // Existing Rules state
  final List<Map<String, String>> _existingRulesFiles = [];
  bool _existingRulesExpanded = true;
  int _existingRulesInputMode = 0; // 0 = Upload Existing Rules (Option A), 1 = Connect with CIDAN (Option B)
  final List<IntegrationSourceModel> _verifiedSources = [];

  // New Rule Input state
  bool _newRuleExpanded = true;
  final List<Map<String, String>> _newRuleFiles = [];
  String _newCircularFileName = '';
  RegulatoryDocumentModel? _circularMetadata;

  bool get _hasExistingRulesInput =>
      _existingRulesFiles.isNotEmpty || _verifiedSources.isNotEmpty;

  bool get _hasNewRuleInput =>
      _newRuleFiles.isNotEmpty || _newCircularFileName.isNotEmpty;

  bool get _isAnalyzeEnabled => _hasExistingRulesInput && _hasNewRuleInput;

  // File selection state
  bool _isPickingFile = false;
  String _fileName = '';
  String _fileSize = '';

  UploadProcessStep _currentStep = UploadProcessStep.initial;
  bool _isCancelled = false;

  // Video processing state
  VideoPlayerController? _videoController;
  bool _isPlayingVideo = false;
  int _videoStepIndex = 0;
  bool _isPurpleBg = false;
  ComplianceReportModel? _analysisReport;

  // Recent Regulatory Filings History
  List<Map<String, dynamic>> _recentReports = [];
  bool _isLoadingReports = false;
  String _currentBankId = '00000000-0000-0000-0000-000000000001';

  final List<String> _videoStatusSteps = const [
    'Uploading circular...',
    'Extracting obligations...',
    'Mapping to your existing rules...',
    'Backtesting in sandbox...',
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    if (widget.initialFileName != null && widget.initialFileName!.isNotEmpty) {
      _fileName = widget.initialFileName!;
    }
    if (widget.initialFileSize != null && widget.initialFileSize!.isNotEmpty) {
      _fileSize = widget.initialFileSize!;
    }
    _loadRecentReports();
    _initBank();
  }

  Future<void> _initBank() async {
    try {
      final bank = await SupabaseService().getOrCreateBank(
        name: 'Apex Banking Corporation',
        bankCode: 'APEX-01',
      );
      if (mounted) {
        setState(() {
          _currentBankId = bank.id;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await SupabaseService().getComplianceReports(
        widget.email,
      );
      if (mounted) {
        setState(() {
          _recentReports = reports;
          _isLoadingReports = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_handleVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  static const int _maxAllowedFiles = 10;

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return Icons.table_chart_rounded;
    } else if (lower.endsWith('.json') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.sql')) {
      return Icons.code_rounded;
    } else if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return Icons.description_rounded;
    } else if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return Icons.image_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return const Color(0xFFEF4444);
    } else if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return const Color(0xFF10B981);
    } else if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return const Color(0xFF2563EB);
    } else if (lower.endsWith('.json') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.sql')) {
      return const Color(0xFF4F46E5);
    } else if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return const Color(0xFFF59E0B);
    } else {
      return const Color(0xFF64748B);
    }
  }

  Future<dynamic> _pickFilesCompat({List<String>? allowedExtensions}) async {
    try {
      return await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'docx',
          'doc',
          'txt',
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, String>>> _extractFilesFromPickerResult(
    dynamic result,
    int remainingSlots,
    String defaultName,
    double defaultMb,
  ) async {
    final List<dynamic> pickedFiles = <dynamic>[];
    if (result is List) {
      pickedFiles.addAll(result);
    } else if (result != null) {
      try {
        final dynamic legacyFiles = (result as dynamic).files;
        if (legacyFiles is List) {
          pickedFiles.addAll(legacyFiles);
        }
      } catch (_) {}
    }

    final List<Map<String, String>> newFiles = [];
    for (final dynamic file in pickedFiles) {
      if (newFiles.length >= remainingSlots) {
        break;
      }
      String name = defaultName;
      try {
        final dynamic n = (file as dynamic).name;
        if (n != null && n.toString().trim().isNotEmpty) {
          name = n.toString().trim();
        }
      } catch (_) {}

      num sizeBytes = 0;
      try {
        final dynamic s = (file as dynamic).size;
        if (s != null && s is num && s > 0) {
          sizeBytes = s;
        }
      } catch (_) {}

      if (sizeBytes == 0) {
        try {
          final dynamic b = (file as dynamic).bytes;
          if (b != null && b is List) {
            sizeBytes = b.length;
          }
        } catch (_) {}
      }

      final double mb = sizeBytes > 0 ? sizeBytes / (1024 * 1024) : defaultMb;
      final sizeMb = '${mb.toStringAsFixed(1)} MB';
      newFiles.add({'name': name, 'size': sizeMb});
    }
    return newFiles;
  }

  Future<void> _handleChooseExistingFile({bool multiple = true}) async {
    if (_isPickingFile) return;
    if (_existingRulesFiles.length >= _maxAllowedFiles) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Maximum 10 files allowed (PDF, images, or combined). Please remove some files to add more.',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _isPickingFile = true;
    try {
      final dynamic result = await _pickFilesCompat(
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'xlsx',
          'xls',
          'json',
          'xml',
          'sql',
          'yaml',
          'yml',
          'txt',
          'png',
          'jpg',
          'jpeg',
        ],
      );
      if (result == null || !mounted) return;

      final remainingSlots = _maxAllowedFiles - _existingRulesFiles.length;
      final newFiles = await _extractFilesFromPickerResult(
        result,
        remainingSlots,
        'existing_rule.pdf',
        1.5,
      );

      if (newFiles.isNotEmpty && mounted) {
        setState(() {
          _existingRulesFiles.addAll(newFiles);
          if (_fileName.isEmpty) {
            _fileName = newFiles.first['name'] ?? 'existing_rule.pdf';
            _fileSize = newFiles.first['size'] ?? '1.5 MB';
          }
        });

        // Store extracted rule reference into Supabase
        final rules = newFiles.map((f) {
          final n = f['name'] ?? 'rule.pdf';
          final ext = n.contains('.') ? n.split('.').last.toUpperCase() : 'PDF';
          return ExistingRuleModel(
            id: SupabaseService.generateUuid(),
            bankId: _currentBankId,
            sourceType: 'FILE',
            ruleCode: 'RULE-$ext-${n.hashCode.abs() % 10000}',
            ruleTitle: n,
            ruleContent: 'Bank internal policy constraints extracted from $n',
            fileFormat: ext,
            filePath: n,
            version: 1,
            metadata: {'size': f['size'] ?? '1.0 MB'},
            createdAt: DateTime.now(),
          );
        }).toList();
        SupabaseService().saveExistingRules(rules);
      }

      int totalCount = newFiles.length;
      if (result is List) {
        totalCount = result.length;
      } else {
        try {
          final dynamic files = (result as dynamic).files;
          if (files is List) totalCount = files.length;
        } catch (_) {}
      }

      if (totalCount > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Limit applied: maximum 10 files allowed. Extra files were not added.',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error choosing existing files: $e');
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> _handleChooseNewRuleFile({bool multiple = true}) async {
    if (_isPickingFile) return;
    if (_newRuleFiles.length >= _maxAllowedFiles) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Maximum 10 files allowed (PDF, images, or combined). Please remove some files to add more.',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _isPickingFile = true;
    try {
      final dynamic result = await _pickFilesCompat(
        allowedExtensions: [
          'pdf',
          'docx',
          'doc',
          'png',
          'jpg',
          'jpeg',
          'txt',
        ],
      );
      if (result == null || !mounted) return;

      final remainingSlots = _maxAllowedFiles - _newRuleFiles.length;
      final newFiles = await _extractFilesFromPickerResult(
        result,
        remainingSlots,
        'regulatory_document.pdf',
        2.1,
      );

      if (newFiles.isNotEmpty && mounted) {
        setState(() {
          _newRuleFiles.addAll(newFiles);
          _newCircularFileName = _newRuleFiles.first['name'] ?? '';
          if (_fileName.isEmpty) {
            _fileName = _newRuleFiles.first['name'] ?? '';
            _fileSize = _newRuleFiles.first['size'] ?? '';
          }
          if (_circularMetadata == null) {
            final fName =
                _newRuleFiles.first['name'] ?? 'regulatory_document.pdf';
            final fmt = fName.contains('.')
                ? fName.split('.').last.toUpperCase()
                : 'PDF';
            _circularMetadata = RegulatoryDocumentModel(
              id: SupabaseService.generateUuid(),
              bankId: _currentBankId,
              documentName: fName,
              issuingAuthority: 'RBI',
              circularNumber:
                  'RBI/2026-27/CIRCULAR-${DateTime.now().millisecondsSinceEpoch % 1000}',
              effectiveDate: DateTime.now(),
              complianceDeadline:
                  DateTime.now().add(const Duration(days: 90)),
              category: 'KYC & Anti-Money Laundering',
              fileFormat: fmt,
              fileSizeBytes: 2100000,
              version: 1,
              extractionStatus: 'PENDING',
              createdAt: DateTime.now(),
            );
            SupabaseService().saveRegulatoryDocument(_circularMetadata!);
          }
        });
      }

      int totalCount = newFiles.length;
      if (result is List) {
        totalCount = result.length;
      } else {
        try {
          final dynamic files = (result as dynamic).files;
          if (files is List) totalCount = files.length;
        } catch (_) {}
      }

      if (totalCount > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Limit applied: maximum 10 files allowed. Extra files were not added.',
              style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
            ),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error choosing new rule files: $e');
    } finally {
      _isPickingFile = false;
    }
  }

  void _handleRemoveFile() {
    setState(() {
      _fileName = '';
      _fileSize = '';
      _newCircularFileName = '';
      _existingRulesFiles.clear();
      _newRuleFiles.clear();
      _verifiedSources.clear();
      _circularMetadata = null;
      _analysisReport = null;
      _existingRulesInputMode = 0;
      _existingRulesExpanded = true;
      _newRuleExpanded = true;
      _currentStep = UploadProcessStep.initial;
    });
  }

  Future<void> _startUploadAndAnalysis() async {
    if (!_isAnalyzeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide both Existing Rules and New Rule Input before analyzing.',
            style: TextStyle(fontFamily: 'packages/cidan/Poppins'),
          ),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_newRuleFiles.isNotEmpty) {
      _fileName = _newRuleFiles.first['name'] ?? 'new_circular.pdf';
      _fileSize = _newRuleFiles.first['size'] ?? '2.1 MB';
    } else if (_existingRulesFiles.isNotEmpty) {
      _fileName = _existingRulesFiles.first['name'] ?? 'existing_rule.pdf';
      _fileSize = _existingRulesFiles.first['size'] ?? '1.5 MB';
    } else if (_verifiedSources.isNotEmpty) {
      _fileName = '${_verifiedSources.first.sourceType}_Rules_Catalog.json';
      _fileSize = '1.2 MB';
    } else {
      _fileName = 'TNext-SE-2026-J_2625-Rules.pdf';
      _fileSize = '2.4 MB';
    }

    _isCancelled = false;
    setState(() {
      _isPlayingVideo = true;
      _videoStepIndex = 0;
      _isPurpleBg = false;
    });

    // Initiate API analysis on Virtusa Agent backend simultaneously
    CidanApiService().analyzeDocument(filename: _fileName).then((report) {
      if (mounted) {
        _analysisReport = report;
      }
    });

    _videoController?.removeListener(_handleVideoTick);
    _videoController?.dispose();

    try {
      _videoController = VideoPlayerController.asset(
        'assets/videos/cidan_analysis.mp4',
      );
      await _videoController!.initialize();
    } catch (_) {
      try {
        _videoController = VideoPlayerController.asset(
          'assests/videos/cidan_analysis.mp4',
        );
        await _videoController!.initialize();
      } catch (_) {
        try {
          _videoController = VideoPlayerController.asset(
            'assets/videos/cidan_analysis.mp4',
            package: 'cidan',
          );
          await _videoController!.initialize();
        } catch (_) {
          try {
            _videoController = VideoPlayerController.asset(
              'assests/videos/cidan_analysis.mp4',
              package: 'cidan',
            );
            await _videoController!.initialize();
          } catch (_) {}
        }
      }
    }

    if (!mounted || _isCancelled) return;

    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.setLooping(false);
      _videoController!.addListener(_handleVideoTick);
      await _videoController!.play();
    }

    // Safety fallback timer to ensure completed page is reached after video finishes
    Timer(const Duration(milliseconds: 8800), () {
      if (mounted && _isPlayingVideo) {
        _onVideoFinished();
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  void _handleVideoTick() {
    if (!mounted || _videoController == null) return;
    final pos = _videoController!.value.position.inMilliseconds / 1000.0;
    final dur = _videoController!.value.duration.inMilliseconds / 1000.0;

    int nextIndex = 0;
    if (pos < 2.1) {
      nextIndex = 0; // Uploading circular...
    } else if (pos < 4.2) {
      nextIndex = 1; // Extracting obligations...
    } else if (pos < 6.3) {
      nextIndex = 2; // Mapping to your existing rules...
    } else {
      nextIndex = 3; // Backtesting in sandbox...
    }

    final bool isPurple = pos >= 7.0;

    if (nextIndex != _videoStepIndex || isPurple != _isPurpleBg) {
      setState(() {
        _videoStepIndex = nextIndex;
        _isPurpleBg = isPurple;
      });
    }

    // When video completes (pos reached end or isCompleted flag set)
    final isFinished =
        (dur > 0 && pos >= (dur - 0.25)) || _videoController!.value.isCompleted;
    if (isFinished) {
      _videoController!.removeListener(_handleVideoTick);
      _onVideoFinished();
    }
  }

  void _onVideoFinished() {
    _videoController?.pause();
    _videoController?.removeListener(_handleVideoTick);
    setState(() {
      _isPlayingVideo = false;
      _isPurpleBg = false;
      _currentStep = UploadProcessStep.completed;
    });

    // Seamlessly display the Compliance Dashboard with pipeline progress and testcases
    _openComplianceDashboard();
  }

  void _openComplianceDashboard() {
    final report = _analysisReport ?? ComplianceReportModel.defaultSample();
    final file = _fileName.isNotEmpty
        ? _fileName
        : 'CIDAN_Synthetic_RBI_Style_Loan_Approval_Circular_8_pages.pdf';

    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplianceDashboardScreen(
          report: report,
          uploadedFileName: file,
          userEmail: widget.email,
          initialApproved: false,
        ),
      ),
    )
        .then((deployed) {
      _loadRecentReports();
      if (deployed == true && mounted) {
        setState(() {
          _currentStep = UploadProcessStep.completed;
          if (_fileName.isEmpty) {
            _fileName = file;
          }
        });
      }
    });
  }

  void _openReportFromHistory(Map<String, dynamic> item) {
    final reportData = item['report_data'] as Map<String, dynamic>? ?? {};
    final report = ComplianceReportModel.fromJson(
      reportData.isNotEmpty ? reportData : ComplianceReportModel.sampleJsonMap,
    );
    final filename = (item['filename'] as String?) ?? 'Regulatory_Circular.pdf';
    final isDeployed =
        (reportData['is_deployed'] == true) || (item['is_deployed'] == true);

    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplianceDashboardScreen(
          report: report,
          uploadedFileName: filename,
          userEmail: widget.email,
          initialApproved: isDeployed,
        ),
      ),
    )
        .then((deployed) {
      _loadRecentReports();
      if (deployed == true && mounted) {
        setState(() {
          _fileName = filename;
          _fileSize = (item['file_size'] as String?) ?? '2.4 MB';
          _currentStep = UploadProcessStep.completed;
        });
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getUsername() {
    if (widget.email.isEmpty) return 'Officer';
    final parts = widget.email.split('@');
    return parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : widget.email;
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? You will need to verify with OTP upon next login.',
          style: TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 13.5,
            color: Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cidan_is_logged_in', false);
    await prefs.remove('cidan_user_email');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _cancelVideoAndReset() {
    _isCancelled = true;
    _videoController?.pause();
    _videoController?.removeListener(_handleVideoTick);
    setState(() {
      _isPlayingVideo = false;
      _isPurpleBg = false;
      _currentStep = UploadProcessStep.initial;
    });
  }

  void _showAiAssistantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Color(0xFF4F46E5),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CIDAN AI Assistant',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Banking Regulatory Copilot',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'How can I help you with this regulatory filing?',
              style: TextStyle(
                fontFamily: 'packages/cidan/Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            _buildAiFeatureItem(
              Icons.auto_awesome_rounded,
              'Automated Obligation Extraction',
              'Parse circulars into mandatory actionable tasks.',
            ),
            _buildAiFeatureItem(
              Icons.rule_rounded,
              'Compliance Gap Analysis',
              'Cross-check rules against internal bank policies.',
            ),
            _buildAiFeatureItem(
              Icons.history_edu_rounded,
              'Audit Trail Generation',
              'Prepare exportable regulatory readiness reports.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isInitial = _currentStep == UploadProcessStep.initial;

    // Full screen video processing screen
    if (_isPlayingVideo) {
      return _buildFullScreenVideoPlayer(size);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Bottom Decorative Background Wave
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  AppAssets.bottomWaveDecoration,
                  width: double.infinity,
                  height: 130,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      AppAssets.bottomWaveDecoration,
                      package: 'cidan',
                      width: double.infinity,
                      height: 130,
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),

          // 2. Main Page Content with Responsive Layout
          SafeArea(
            top: true,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar: Dynamic Greeting & Sign Out Button
                _buildTopHeaderBar(),
                SizedBox(height: isInitial ? 10 : 6),

                // Top Brand Header & Completed Banner: Shown during completion
                if (!isInitial) ...[
                  SizedBox(
                    key: const ValueKey('completed_banner'),
                    width: double.infinity,
                    height: (size.height * 0.19).clamp(110.0, 150.0),
                    child: Image.asset(
                      AppAssets.verifiedChecklist,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          AppAssets.verifiedChecklist,
                          package: 'cidan',
                          width: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: isInitial ? 0 : 8),
                // Main Interactive Form Content (Scrollable to prevent overflow)
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, isInitial ? 16 : 0, 16, 20),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _buildCurrentContent(size),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating AI Assistant Bot Button (bottom right)
          Positioned(
            bottom: (size.height * 0.016).clamp(12.0, 18.0),
            right: 18,
            child: _buildFloatingAiBotButton(),
          ),
        ],
      ),
    );
  }

  // Full Screen Video Player with Top Status Indicator matching screenshot
  Widget _buildFullScreenVideoPlayer(Size size) {
    // Exact gradient from index.html (gWash: #4A3CC8 at top, #5B4BDB at 0.55, #8B5CF6 at bottom)
    const purpleGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF4A3CC8), // Top-left wash tone
        Color(0xFF5B4BDB), // Middle violet tone
        Color(0xFF8B5CF6), // Bottom-right lavender tone
      ],
      stops: [0.0, 0.55, 1.0],
    );

    final textColor = _isPurpleBg ? Colors.white : const Color(0xFF172033);
    final spinnerColor = _isPurpleBg ? Colors.white : const Color(0xFF5B4BDB);
    final spinnerTrackColor =
        _isPurpleBg ? Colors.white.withAlpha(70) : const Color(0xFFE6E8F5);
    final closeColor = _isPurpleBg ? Colors.white : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: _isPurpleBg ? const Color(0xFF4A3CC8) : Colors.white,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isPurpleBg ? null : Colors.white,
          gradient: _isPurpleBg ? purpleGradient : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Screen Video (BoxFit.cover fills screen edge-to-edge with no top/bottom bars)
            if (_videoController != null &&
                _videoController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0
                        ? _videoController!.value.size.width
                        : 540,
                    height: _videoController!.value.size.height > 0
                        ? _videoController!.value.size.height
                        : 960,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
                ),
              ),

            // 2. Top Status Indicator (Matching user's screenshot with circular progress indicator)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 28.0,
                    left: 24,
                    right: 24,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            spinnerColor,
                          ),
                          backgroundColor: spinnerTrackColor,
                        ),
                      ),
                      const SizedBox(width: 11),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _videoStatusSteps[_videoStepIndex],
                          key: ValueKey<int>(_videoStepIndex),
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Close / Cancel button at top right
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14.0, right: 16.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: closeColor,
                      size: 22,
                    ),
                    onPressed: _cancelVideoAndReset,
                    tooltip: 'Cancel',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Floating AI Assistant Button
  Widget _buildFloatingAiBotButton() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withAlpha(100),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2.2),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _showAiAssistantSheet,
          child: Stack(
            alignment: Alignment.center,
            children: const [
              Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
              Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentContent(Size size) {
    if (_currentStep == UploadProcessStep.completed) {
      return _buildCompletedContent(size);
    }
    return _buildInitialUploadContent(size);
  }

  // Page 1: Initial View matching uploaded mockup
  Widget _buildInitialUploadContent(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Hero Branding & 3D Illustration Section
        _buildHeroHeaderSection(),

        // 2. Card 1: Existing Rules (Collapsible)
        _buildExistingRulesCard(),

        const SizedBox(height: 14),

        // 3. Card 2: New Rule Input (Circular / Update) (Collapsible)
        _buildNewRuleInputCard(),

        const SizedBox(height: 18),

        // 4. Primary CTA: "✨ Analyze & Generate"
        _buildAnalyzeAndGenerateButton(),

        const SizedBox(height: 16),

        // 5. Recent Regulatory History
        _buildRecentRegulatoryHistory(),

        const SizedBox(height: 60),
      ],
    );
  }

  // Hero Header Section
  Widget _buildHeroHeaderSection() {
    return Column(
      children: const [
        SizedBox(height: 10),
        // Title
        Text(
          'Regulatory Rule Automation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 4),
        // Subtitle
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Upload existing rules, add new circulars, and validate with AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'packages/cidan/Poppins',
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // Card 1: Existing Rules (Collapsible with dropdown chevron)
  Widget _buildExistingRulesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(
                () => _existingRulesExpanded = !_existingRulesExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                      Icons.layers_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Existing Rules',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload internal policies or connect via CIDAN gateway',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _hasExistingRulesInput
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _hasExistingRulesInput
                          ? (_existingRulesFiles.isNotEmpty
                              ? '✓ ${_existingRulesFiles.length} file(s)'
                              : '✓ ${_verifiedSources.length} source(s)')
                          : 'Required',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _hasExistingRulesInput
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _existingRulesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (_existingRulesExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tab Toggle: Upload Document vs Endpoint (URL)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        // Tab 0: Upload Document
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setState(() => _existingRulesInputMode = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _existingRulesInputMode == 0
                                    ? const Color(0xFF6366F1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _existingRulesInputMode == 0
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1)
                                              .withAlpha(50),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 15,
                                    color: _existingRulesInputMode == 0
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Upload Rules',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _existingRulesInputMode == 0
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Tab 1: Option B: Connect with CIDAN
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setState(() => _existingRulesInputMode = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _existingRulesInputMode == 1
                                    ? const Color(0xFF6366F1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _existingRulesInputMode == 1
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF6366F1)
                                              .withAlpha(50),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance_rounded,
                                    size: 15,
                                    color: _existingRulesInputMode == 1
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Connect CIDAN',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _existingRulesInputMode == 1
                                            ? Colors.white
                                            : const Color(0xFF64748B),
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
                  ),
                  const SizedBox(height: 12),

                  if (_existingRulesInputMode == 0) ...[
                    // Dashed Border Dropzone
                    CustomPaint(
                      painter: DashedBorderPainter(
                        color: const Color(0xFFC7D2FE),
                        strokeWidth: 1.2,
                        gap: 5.0,
                        dashLength: 6.0,
                        borderRadius: 16.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFBFE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        child: Column(
                          children: [
                            // Soft circular cloud with upward arrow
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEEF2FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFF4F46E5),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Drag & Drop files here',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // "or" divider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontFamily: 'packages/cidan/Poppins',
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 34,
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Action Button: Choose File (allows single or multiple files)
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _handleChooseExistingFile(multiple: true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4F46E5),
                                  side: const BorderSide(
                                    color: Color(0xFF4F46E5),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 9,
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 17,
                                  color: Color(0xFF4F46E5),
                                ),
                                label: const Text(
                                  'Choose File',
                                  style: TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Supported: PDF, DOCX, XLSX, JSON, XML, SQL, YAML (Max 10 files, 50 MB each)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Display selected files list (Scrollable to avoid overflow)
                    if (_existingRulesFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_existingRulesFiles.length}/$_maxAllowedFiles files selected',
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _existingRulesFiles.clear();
                                if (_newRuleFiles.isEmpty &&
                                    _newCircularFileName.isEmpty) {
                                  _fileName = '';
                                  _fileSize = '';
                                }
                              });
                            },
                            child: const Text(
                              'Clear all',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: Scrollbar(
                          thumbVisibility: _existingRulesFiles.length > 3,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _existingRulesFiles
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final idx = entry.key;
                                final f = entry.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getFileIcon(f['name'] ?? ''),
                                        size: 14,
                                        color:
                                            _getFileIconColor(f['name'] ?? ''),
                                      ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          f['name'] ?? '',
                                          style: const TextStyle(
                                            fontFamily:
                                                'packages/cidan/Poppins',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${f['size']})',
                                        style: const TextStyle(
                                          fontFamily: 'packages/cidan/Poppins',
                                          fontSize: 10,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _existingRulesFiles.removeAt(idx);
                                            if (_existingRulesFiles.isEmpty &&
                                                _newRuleFiles.isEmpty &&
                                                _newCircularFileName.isEmpty) {
                                              _fileName = '';
                                              _fileSize = '';
                                            }
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Option B: Connect with CIDAN
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Enterprise Integration Gateway',
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Connect to Oracle, Mongo, Postgres, or APIs via CIDAN proxy',
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => ConnectCidanDialog(
                                  userEmail: widget.email,
                                  onSourceVerified: (integration, source) {
                                    setState(() {
                                      _verifiedSources.removeWhere(
                                        (s) =>
                                            s.id == source.id ||
                                            s.sourceType == source.sourceType,
                                      );
                                      _verifiedSources.add(source);
                                    });
                                  },
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add_link_rounded, size: 18),
                            label: const Text(
                              'Connect New Integration Source',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_verifiedSources.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Verified Active Sources (${_verifiedSources.length})',
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _verifiedSources.clear()),
                            child: const Text(
                              'Clear sources',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._verifiedSources.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final src = entry.value;
                        final isDb = src.sourceType != 'REST_API' &&
                            src.sourceType != 'GRAPHQL';
                        final detail = isDb
                            ? '${src.configMetadata["host"] ?? "db"}:${src.configMetadata["port"] ?? ""}'
                            : (src.configMetadata["base_url"] ?? "API Endpoint");

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isDb
                                    ? Icons.storage_rounded
                                    : Icons.http_rounded,
                                size: 18,
                                color: const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          src.sourceType,
                                          style: const TextStyle(
                                            fontFamily: 'packages/cidan/Poppins',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '✓ Verified',
                                            style: TextStyle(
                                              fontFamily:
                                                  'packages/cidan/Poppins',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      detail,
                                      style: const TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _verifiedSources.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Card 2: New Rule Input (Circular / Update) (Collapsible with multi-file dropzone & scrollable list)
  Widget _buildNewRuleInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _newRuleExpanded = !_newRuleExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'New Rule Input (Circular / Update)',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload new regulatory circulars, notices, or amendments',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _hasNewRuleInput
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _hasNewRuleInput
                          ? '✓ ${_newRuleFiles.length} file(s)'
                          : 'Required',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _hasNewRuleInput
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _newRuleExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (_newRuleExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomPaint(
                    painter: DashedBorderPainter(
                      color: const Color(0xFFDDD6FE),
                      strokeWidth: 1.2,
                      gap: 5.0,
                      dashLength: 6.0,
                      borderRadius: 16.0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3E8FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.cloud_upload_outlined,
                                color: Color(0xFF7C3AED),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Drag & Drop new circulars or files here',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 1,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _handleChooseNewRuleFile(multiple: true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(
                                  color: Color(0xFF7C3AED),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 9,
                                ),
                                backgroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.folder_open_rounded,
                                size: 17,
                                color: Color(0xFF7C3AED),
                              ),
                              label: const Text(
                                'Choose File',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supported: PDF, PNG, JPG, DOCX, DOC, TXT (Max 10 files, 50 MB each)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  if (_newRuleFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_newRuleFiles.length}/$_maxAllowedFiles files selected',
                          style: const TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _newRuleFiles.clear();
                              _newCircularFileName = '';
                              if (_existingRulesFiles.isEmpty) {
                                _fileName = '';
                                _fileSize = '';
                              }
                            });
                          },
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: Scrollbar(
                        thumbVisibility: _newRuleFiles.length > 3,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _newRuleFiles.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final f = entry.value;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getFileIcon(f['name'] ?? ''),
                                      size: 14,
                                      color: _getFileIconColor(f['name'] ?? ''),
                                    ),
                                    const SizedBox(width: 5),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 150),
                                      child: Text(
                                        f['name'] ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'packages/cidan/Poppins',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${f['size']})',
                                      style: const TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _newRuleFiles.removeAt(idx);
                                          if (_newRuleFiles.isEmpty) {
                                            _newCircularFileName = '';
                                            if (_existingRulesFiles.isEmpty) {
                                              _fileName = '';
                                              _fileSize = '';
                                            }
                                          } else {
                                            _newCircularFileName =
                                                _newRuleFiles.first['name'] ??
                                                    '';
                                          }
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Regulatory Circular Metadata Summary Card
                  if (_newRuleFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _circularMetadata?.issuingAuthority ?? 'RBI',
                                  style: const TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _circularMetadata?.circularNumber ??
                                      'Regulatory Circular',
                                  style: const TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => CircularMetadataDialog(
                                      fileName: _newRuleFiles.first['name'] ??
                                          'regulatory_circular.pdf',
                                      fileSizeBytes: 2100000,
                                      initialModel: _circularMetadata,
                                      onSave: (saved) {
                                        setState(() => _circularMetadata = saved);
                                        SupabaseService()
                                            .saveRegulatoryDocument(saved);
                                      },
                                    ),
                                  );
                                },
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        size: 14, color: Color(0xFF4F46E5)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Edit Metadata',
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Domain: ${_circularMetadata?.category ?? "KYC & AML"}',
                                style: const TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'Deadline: ${_circularMetadata?.complianceDeadline != null ? "${_circularMetadata!.complianceDeadline!.year}-${_circularMetadata!.complianceDeadline!.month.toString().padLeft(2, "0")}-${_circularMetadata!.complianceDeadline!.day.toString().padLeft(2, "0")}" : "90 days"}',
                                style: const TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                              Text(
                                'Version: v${_circularMetadata?.version ?? 1}.0',
                                style: const TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
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
            ),
          ],
        ],
      ),
    );
  }

  // Primary Action Button: "✨ Analyze & Generate"
  Widget _buildAnalyzeAndGenerateButton() {
    final enabled = _isAnalyzeEnabled;
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [
                      Color(0xFF4F46E5),
                      Color(0xFF6366F1),
                      Color(0xFF7C3AED)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
            border: enabled ? null : Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withAlpha(85),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? _startUploadAndAnalysis : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: enabled ? Colors.white : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analyze & Generate',
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.white : const Color(0xFF94A3B8),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Top Header Bar: Dynamic Time-based Greeting & Sign Out Button
  Widget _buildTopHeaderBar() {
    final greeting = _getGreeting();
    final username = _getUsername();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Greeting and Username (e.g. Good Evening arjunfree)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('👋 ', style: TextStyle(fontSize: 12)),
                          Text(
                            greeting,
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        username,
                        style: const TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle / Right: Rule Mapping Studio Pill Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RuleMappingStudioScreen(
                      bankId: _currentBankId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6.5,
                ),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withAlpha(16),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.compare_arrows_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Rule Mapping Studio',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right: Sign Out Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _handleSignOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.logout_rounded,
                      size: 15,
                      color: Color(0xFFEF4444),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
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

  // Recent Regulatory Filings History Section (displayed below CTA button)
  Widget _buildRecentRegulatoryHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Recent Regulatory History',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (_recentReports.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_recentReports.length}',
                        style: const TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_recentReports.isNotEmpty)
              TextButton(
                onPressed: _openComplianceDashboard,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        if (_isLoadingReports)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          )
        else if (_recentReports.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.feed_outlined, color: Color(0xFF94A3B8), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No regulatory circulars processed yet. Select a document above to run AI compliance analysis.',
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._recentReports
              .take(4)
              .map((reportItem) => _buildRecentHistoryCard(reportItem)),
      ],
    );
  }

  // Individual Recent Regulatory Circular History Card
  Widget _buildRecentHistoryCard(Map<String, dynamic> item) {
    final filename = (item['filename'] as String?) ?? 'Regulatory_Circular.pdf';
    final reportData = item['report_data'] as Map<String, dynamic>? ?? {};
    final isDeployed =
        (reportData['is_deployed'] == true) || (item['is_deployed'] == true);
    final obligationsCount =
        item['obligations_count'] ?? reportData['obligations_count'] ?? 6;
    final violationsCount =
        item['violations_count'] ?? reportData['findings_count'] ?? 3;
    final createdAtStr = item['created_at'] as String?;

    // Format timestamp
    String timeLabel = 'Recently';
    if (createdAtStr != null) {
      final dt = DateTime.tryParse(createdAtStr);
      if (dt != null) {
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          timeLabel =
              diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeLabel = '${diff.inHours}h ago';
        } else {
          timeLabel = '${dt.day}/${dt.month}/${dt.year}';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDeployed ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openReportFromHistory(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // PDF Document Badge Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDeployed
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDeployed
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFC7D2FE),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: isDeployed
                          ? const Color(0xFF059669)
                          : const Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Filename and Obligation details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filename,
                        style: const TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$obligationsCount rules • $violationsCount gaps',
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Deployment Status Pill Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: isDeployed
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDeployed
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFDE68A),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDeployed
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        size: 10.5,
                        color: isDeployed
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        isDeployed ? 'Deployed' : 'Pending',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDeployed
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Completed Document Processed Successfully
  Widget _buildCompletedContent(Size size) {
    final isCompact = size.height < 720;
    final btnHeight = (size.height * 0.058).clamp(44.0, 50.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Document Processed Successfully',
          style: TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: isCompact ? 18 : 21,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),

        Text(
          'The contents have been analyzed and compliance insights are ready.',
          style: TextStyle(
            fontFamily: 'packages/cidan/Poppins',
            fontSize: isCompact ? 12 : 13.5,
            color: const Color(0xFF64748B),
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: isCompact ? 12 : 20),

        // Selected File Card with green checkmark
        _buildFilePreviewCard(showCheckmark: true),

        SizedBox(height: isCompact ? 14 : 22),

        // Action Buttons Row: [ View Results -> ] and [ Upload Another ]
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                height: btnHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withAlpha(70),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _openComplianceDashboard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Flexible(
                        child: Text(
                          'View Results',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: btnHeight,
                child: OutlinedButton(
                  onPressed: _handleRemoveFile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Upload Another',
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilePreviewCard({required bool showCheckmark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5FB)),
      ),
      child: Row(
        children: [
          // Red PDF Badge matching mockup
          const _PdfDocumentBadge(),
          const SizedBox(width: 14),

          // File Name & Size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _fileSize,
                  style: const TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          if (showCheckmark)
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              onPressed: _handleRemoveFile,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

// Red PDF Document badge matching design mockup
class _PdfDocumentBadge extends StatelessWidget {
  const _PdfDocumentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 28,
        height: 34,
        child: CustomPaint(painter: _PdfPagePainter()),
      ),
    );
  }
}

class _PdfPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fold = w * 0.32;

    // Red document body with top-right corner cut
    final path = Path()
      ..moveTo(4, 0)
      ..lineTo(w - fold, 0)
      ..lineTo(w, fold)
      ..lineTo(w, h - 4)
      ..quadraticBezierTo(w, h, w - 4, h)
      ..lineTo(4, h)
      ..quadraticBezierTo(0, h, 0, h - 4)
      ..lineTo(0, 4)
      ..quadraticBezierTo(0, 0, 4, 0)
      ..close();

    final redPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, redPaint);

    // Folded dog-ear flap (slightly darker red)
    final foldPath = Path()
      ..moveTo(w - fold, 0)
      ..lineTo(w - fold, fold)
      ..lineTo(w, fold)
      ..close();
    final foldPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldPaint);

    // "PDF" text centered in white
    const textSpan = TextSpan(
      text: 'PDF',
      style: TextStyle(
        fontFamily: 'packages/cidan/Poppins',
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, h - textPainter.height - 4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
