import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/screens/login_screen.dart';
import '../models/compliance_report_model.dart';
import '../services/cidan_api_service.dart';
import '../widgets/dashed_border_painter.dart';
import 'compliance_dashboard_screen.dart';

enum UploadProcessStep { initial, completed }

class UploadDocumentScreen extends StatefulWidget {
  final String email;

  const UploadDocumentScreen({super.key, required this.email});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  // Existing Rules state
  final List<Map<String, String>> _existingRulesFiles = [];
  bool _existingRulesExpanded = true;

  // New Rule Input state
  bool _newRuleExpanded = true;
  int _newRuleInputMode = 0; // 0 = Endpoint (URL), 1 = Upload Document
  final List<TextEditingController> _endpointControllers = [
    TextEditingController(text: ''),
  ];
  final List<Map<String, String>> _newRuleFiles = [];
  String _newCircularFileName = '';
  String _newCircularFileSize = '';

  // File selection state
  bool _hasSelectedFile = false;
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

  final List<String> _videoStatusSteps = const [
    'Uploading circular...',
    'Extracting obligations...',
    'Mapping to your existing rules...',
    'Backtesting in sandbox...',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentReports();
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
    for (final controller in _endpointControllers) {
      controller.dispose();
    }
    _videoController?.removeListener(_handleVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  static const int _maxAllowedFiles = 10;

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return Icons.image_rounded;
    } else {
      return Icons.description_rounded;
    }
  }

  Color _getFileIconColor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return const Color(0xFFEF4444);
    } else if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return const Color(0xFF10B981);
    } else {
      return const Color(0xFF4F46E5);
    }
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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc', 'txt'],
        allowMultiple: multiple,
        withData: false,
        withReadStream: false,
      );
      if (result == null || !mounted) return;

      final remainingSlots = _maxAllowedFiles - _existingRulesFiles.length;
      bool exceeded = false;

      final List<Map<String, String>> newFiles = [];
      for (final file in result.files) {
        if (newFiles.length >= remainingSlots) {
          exceeded = true;
          break;
        }
        final String name =
            file.name.isNotEmpty ? file.name : 'existing_rule.pdf';
        final int sizeBytes = file.size > 0 ? file.size : 1024 * 500;
        final double mb = sizeBytes > 0 ? sizeBytes / (1024 * 1024) : 1.5;
        final sizeMb = '${mb.toStringAsFixed(1)} MB';
        newFiles.add({'name': name, 'size': sizeMb});
      }

      if (newFiles.isNotEmpty && mounted) {
        setState(() {
          _existingRulesFiles.addAll(newFiles);
          _hasSelectedFile = true;
          if (_fileName.isEmpty) {
            _fileName = newFiles.first['name'] ?? 'existing_rule.pdf';
            _fileSize = newFiles.first['size'] ?? '1.5 MB';
          }
        });
      }

      if (exceeded && mounted) {
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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc', 'txt'],
        allowMultiple: multiple,
        withData: false,
        withReadStream: false,
      );
      if (result == null || !mounted) return;

      final remainingSlots = _maxAllowedFiles - _newRuleFiles.length;
      bool exceeded = false;

      final List<Map<String, String>> newFiles = [];
      for (final file in result.files) {
        if (newFiles.length >= remainingSlots) {
          exceeded = true;
          break;
        }
        final String name =
            file.name.isNotEmpty ? file.name : 'regulatory_document.pdf';
        final int sizeBytes = file.size > 0 ? file.size : 1024 * 500;
        final double mb = sizeBytes > 0 ? sizeBytes / (1024 * 1024) : 2.1;
        final sizeMb = '${mb.toStringAsFixed(1)} MB';
        newFiles.add({'name': name, 'size': sizeMb});
      }

      if (newFiles.isNotEmpty && mounted) {
        setState(() {
          _newRuleFiles.addAll(newFiles);
          _newCircularFileName = _newRuleFiles.first['name'] ?? '';
          _newCircularFileSize = _newRuleFiles.first['size'] ?? '';
          _hasSelectedFile = true;
          if (_fileName.isEmpty) {
            _fileName = _newRuleFiles.first['name'] ?? '';
            _fileSize = _newRuleFiles.first['size'] ?? '';
          }
        });
      }

      if (exceeded && mounted) {
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
      _hasSelectedFile = false;
      _fileName = '';
      _fileSize = '';
      _newCircularFileName = '';
      _newCircularFileSize = '';
      _existingRulesFiles.clear();
      _newRuleFiles.clear();
    });
  }

  Future<void> _startUploadAndAnalysis() async {
    if (!_hasSelectedFile) {
      if (_newRuleFiles.isNotEmpty) {
        _fileName = _newRuleFiles.first['name'] ?? 'new_circular.pdf';
        _fileSize = _newRuleFiles.first['size'] ?? '2.1 MB';
        _hasSelectedFile = true;
      } else if (_newCircularFileName.isNotEmpty) {
        _fileName = _newCircularFileName;
        _fileSize = _newCircularFileSize;
        _hasSelectedFile = true;
      } else if (_existingRulesFiles.isNotEmpty) {
        _fileName = _existingRulesFiles.first['name'] ?? 'existing_rule.pdf';
        _fileSize = _existingRulesFiles.first['size'] ?? '1.5 MB';
        _hasSelectedFile = true;
      } else if (_endpointControllers.isNotEmpty &&
          _endpointControllers.first.text.trim().isNotEmpty) {
        _fileName =
            'Endpoint_Rule_${DateTime.now().millisecondsSinceEpoch % 10000}.pdf';
        _fileSize = '1.8 MB';
        _hasSelectedFile = true;
      } else {
        // Smart fallback to sample circular for instant test run matching mockup
        _fileName = 'TNext-SE-2026-J_2625-Rules.pdf';
        _fileSize = '2.4 MB';
        _hasSelectedFile = true;
      }
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
        .push(
      MaterialPageRoute(
        builder: (_) => ComplianceDashboardScreen(
          report: report,
          uploadedFileName: file,
          userEmail: widget.email,
          initialApproved: false,
        ),
      ),
    )
        .then((_) {
      _loadRecentReports();
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
        .push(
      MaterialPageRoute(
        builder: (_) => ComplianceDashboardScreen(
          report: report,
          uploadedFileName: filename,
          userEmail: widget.email,
          initialApproved: isDeployed,
        ),
      ),
    )
        .then((_) {
      _loadRecentReports();
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

                // Top Brand Header & Completed Banner: Shown during completion
                if (!isInitial) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Row(
                      children: [
                        _buildCidanCubeLogo(),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'CIDAN',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Regulatory Compliance AI',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    key: const ValueKey('completed_banner'),
                    width: double.infinity,
                    height: (size.height * 0.22).clamp(130.0, 180.0),
                    child: Image.asset(
                      AppAssets.verifiedChecklist,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          AppAssets.verifiedChecklist,
                          package: 'cidan',
                          width: double.infinity,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ],

                // Main Interactive Form Content (Scrollable to prevent overflow)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Center(
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

  // 3D Isometric CIDAN Cube Logo
  Widget _buildCidanCubeLogo() {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _CidanCubePainter()),
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

        // 2. Card 2: New Rule Input (Circular / Update) (Collapsible)
        _buildNewRuleInputCard(),

        // 3. Card 1: Existing Rules (Collapsible)
        _buildExistingRulesCard(),

        const SizedBox(height: 14),

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
                          'Upload your current rules, policies, or master circulars',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    'Supported: PDF, PNG, JPG, DOCX, DOC, TXT (Max 10 files, 50 MB each)',
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
                                _hasSelectedFile = false;
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
                                          _existingRulesFiles.removeAt(idx);
                                          if (_existingRulesFiles.isEmpty &&
                                              _newRuleFiles.isEmpty &&
                                              _newCircularFileName.isEmpty) {
                                            _hasSelectedFile = false;
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Card 2: New Rule Input (Circular / Update) (Collapsible with toggle & endpoint fields)
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
                      Icons.link_rounded,
                      color: Colors.white,
                      size: 22,
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
                          'Provide the existing regulatory document or an endpoint',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  // Tab Toggle: Endpoint (URL) vs Upload Document
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        // Tab 0: Endpoint (URL)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _newRuleInputMode = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _newRuleInputMode == 0
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _newRuleInputMode == 0
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withAlpha(50),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 16,
                                    color: _newRuleInputMode == 0
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Endpoint (URL)',
                                    style: TextStyle(
                                      fontFamily: 'packages/cidan/Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _newRuleInputMode == 0
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Tab 1: Upload Document
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _newRuleInputMode = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _newRuleInputMode == 1
                                    ? const Color(0xFF4F46E5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _newRuleInputMode == 1
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5)
                                              .withAlpha(50),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 16,
                                    color: _newRuleInputMode == 1
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Upload Document',
                                    style: TextStyle(
                                      fontFamily: 'packages/cidan/Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _newRuleInputMode == 1
                                          ? Colors.white
                                          : const Color(0xFF64748B),
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

                  if (_newRuleInputMode == 0) ...[
                    // Endpoint URL fields
                    ..._endpointControllers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                style: const TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  hintText:
                                      'Enter endpoint URL (e.g., https://api.bank.gov.in/rules)',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'packages/cidan/Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5),
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_endpointControllers.length > 1) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFFEF4444),
                                ),
                                onPressed: () {
                                  setState(() {
                                    controller.dispose();
                                    _endpointControllers.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    // Add Another Endpoint Button
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _endpointControllers.add(TextEditingController());
                          });
                        },
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
                            horizontal: 18,
                            vertical: 9,
                          ),
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Color(0xFF4F46E5),
                        ),
                        label: const Text(
                          'Add Another Endpoint',
                          style: TextStyle(
                            fontFamily: 'packages/cidan/Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Upload Document for Existing Rules
                    if (_newRuleFiles.isEmpty)
                      InkWell(
                        onTap: () => _handleChooseNewRuleFile(multiple: true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFBFE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.cloud_upload_outlined,
                                size: 30,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Select Regulatory Document(s) or Images',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Choose up to 10 files: PDF, images, or both combined\n(Tip: Pick up to 4 photos per batch for camera gallery)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _handleChooseNewRuleFile(multiple: true),
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
                                    horizontal: 18,
                                    vertical: 8,
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 16,
                                  color: Color(0xFF4F46E5),
                                ),
                                label: const Text(
                                  'Choose File',
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
                      )
                    else ...[
                      // Header Row with count and Clear all
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_newRuleFiles.length}/$_maxAllowedFiles files uploaded',
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
                                _newCircularFileSize = '';
                                if (_existingRulesFiles.isEmpty) {
                                  _hasSelectedFile = false;
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
                      // Scrollable files list to avoid overflow
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: Scrollbar(
                          thumbVisibility: _newRuleFiles.length > 2,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children:
                                  _newRuleFiles.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final file = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getFileIcon(file['name'] ?? ''),
                                        color: _getFileIconColor(
                                            file['name'] ?? ''),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              file['name'] ?? '',
                                              style: const TextStyle(
                                                fontFamily:
                                                    'packages/cidan/Poppins',
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              file['size'] ?? '',
                                              style: const TextStyle(
                                                fontFamily:
                                                    'packages/cidan/Poppins',
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                              ),
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
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            _newRuleFiles.removeAt(idx);
                                            if (_newRuleFiles.isEmpty) {
                                              _newCircularFileName = '';
                                              _newCircularFileSize = '';
                                              if (_existingRulesFiles.isEmpty) {
                                                _hasSelectedFile = false;
                                                _fileName = '';
                                                _fileSize = '';
                                              }
                                            } else {
                                              _newCircularFileName =
                                                  _newRuleFiles.first['name'] ??
                                                      '';
                                              _newCircularFileSize =
                                                  _newRuleFiles.first['size'] ??
                                                      '';
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Action to Add More Files (if under max 10 files)
                      if (_newRuleFiles.length < _maxAllowedFiles)
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _handleChooseNewRuleFile(multiple: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(
                                color: Color(0xFF4F46E5),
                                width: 1.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              backgroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: Color(0xFF4F46E5),
                            ),
                            label: Text(
                              'Choose More Files (${_maxAllowedFiles - _newRuleFiles.length} left)',
                              style: const TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Maximum 10 files limit reached',
                              style: TextStyle(
                                fontFamily: 'packages/cidan/Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
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

  // Primary Action Button: "✨ Analyze & Generate"
  Widget _buildAnalyzeAndGenerateButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF7C3AED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withAlpha(85),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _startUploadAndAnalysis,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Analyze & Generate',
                style: TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
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
            Row(
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
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recent Regulatory History',
                  style: TextStyle(
                    fontFamily: 'packages/cidan/Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
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
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ),
                ],
              ],
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
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
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
                    colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withAlpha(70),
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
                      Text(
                        'View Results',
                        style: TextStyle(
                          fontFamily: 'packages/cidan/Poppins',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                  onPressed: () {
                    setState(() {
                      _hasSelectedFile = false;
                      _fileName = '';
                      _fileSize = '';
                      _currentStep = UploadProcessStep.initial;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(
                      color: Color(0xFF4F46E5),
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

// Custom Painter for 3D Isometric CIDAN Cube Logo
class _CidanCubePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    // Hexagon vertices
    final points = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      points.add(Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)));
    }

    // Top Rhombus Face
    final topPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(points[5].dx, points[5].dy)
      ..lineTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..close();
    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(topPath, topPaint);

    // Left Rhombus Face
    final leftPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
    final leftPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(leftPath, leftPaint);

    // Right Rhombus Face
    final rightPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(points[3].dx, points[3].dy)
      ..lineTo(points[4].dx, points[4].dy)
      ..lineTo(points[5].dx, points[5].dy)
      ..close();
    final rightPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(rightPath, rightPaint);

    // Internal isometric wire line accents
    final linePaint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final centerSmallR = r * 0.45;
    final innerPath = Path()
      ..moveTo(cx, cy - centerSmallR * 0.9)
      ..lineTo(cx + centerSmallR * 0.8, cy - centerSmallR * 0.4)
      ..lineTo(cx + centerSmallR * 0.8, cy + centerSmallR * 0.5)
      ..lineTo(cx, cy + centerSmallR * 0.9)
      ..lineTo(cx - centerSmallR * 0.8, cy + centerSmallR * 0.5)
      ..lineTo(cx - centerSmallR * 0.8, cy - centerSmallR * 0.4)
      ..close();
    canvas.drawPath(innerPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

