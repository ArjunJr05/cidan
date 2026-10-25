import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/cidan_upload_animation_banner.dart';
import '../widgets/dashed_border_painter.dart';

class UploadDocumentScreen extends StatefulWidget {
  final String email;

  const UploadDocumentScreen({super.key, required this.email});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  // File selection state
  bool _hasSelectedFile = false;
  String _fileName = 'RBI_Circular_Guidelines.pdf';
  String _fileSize = '2.4 MB';
  String _fileExtension = 'pdf';
  bool _isPickingFile = false;

  UploadProcessStep _currentStep = UploadProcessStep.initial;
  double _uploadProgress = 0.0;
  int _analysisStepIndex = 0;
  bool _isCancelled = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.asset(AppAssets.loadingVideo);
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('VideoPlayer initialization: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  final List<String> _analysisSteps = const [
    'Reading document content',
    'Identifying regulatory sections',
    'Extracting obligations',
    'Mapping to compliance rules',
  ];

  final List<String> _insightSteps = const [
    'Document analysis completed',
    'Extracting obligations',
    'Mapping to existing rules',
    'Generating recommendations',
  ];

  Future<void> _handleChooseFile() async {
    if (_isPickingFile) return;

    try {
      setState(() => _isPickingFile = true);

      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc'],
      );

      if (!mounted) return;

      if (file != null) {
        // In file_picker v13+, lengthSync() and length() replace the deprecated size getter
        final fileSizeInBytes = file.lengthSync() ?? (await file.length()) ?? 0;
        if (!mounted) return;

        // Check 50 MB size limit (50 * 1024 * 1024 bytes)
        if (fileSizeInBytes > 52428800) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: const Text(
                'File exceeds 50 MB limit. Please select a smaller document.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
            ),
          );
          return;
        }

        final ext = (file.extension ?? file.name.split('.').last).toLowerCase();

        setState(() {
          _hasSelectedFile = true;
          _fileName = file.name;
          _fileSize = _formatFileSize(fileSizeInBytes);
          _fileExtension = ext;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected: ${file.name}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // When newly added native plugins run under Hot Reload, native channels aren't linked yet.
      // We gracefully fallback to sample document so the user can continue testing uninterrupted.
      final isUnimplemented =
          e is UnimplementedError ||
          e.toString().contains('UnimplementedError') ||
          e.toString().contains('MissingPluginException');

      if (isUnimplemented) {
        setState(() {
          _hasSelectedFile = true;
          _fileName = 'RBI_Circular_Guidelines.pdf';
          _fileSize = '2.4 MB';
          _fileExtension = 'pdf';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'Sample circular selected. Note: Stop and restart the app ("flutter run") to link the phone storage picker.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Unable to pick file: $e',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingFile = false);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _handleRemoveFile() {
    setState(() {
      _hasSelectedFile = false;
    });
  }

  void _cancelUpload() {
    if (_isVideoInitialized && _videoController != null) {
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
    }
    setState(() {
      _isCancelled = true;
      _currentStep = UploadProcessStep.initial;
      _uploadProgress = 0.0;
      _analysisStepIndex = 0;
    });
  }

  Future<void> _startUploadAndAnalysis() async {
    if (!_hasSelectedFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text(
            'Please choose a regulatory document first.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
        ),
      );
      return;
    }

    _isCancelled = false;

    // Start video playback when uploading starts
    if (_isVideoInitialized && _videoController != null) {
      _videoController!.seekTo(Duration.zero);
      _videoController!.play();
    }

    // 1. Uploading Stage (15% -> 35% -> 50% -> 75% -> 100%)
    setState(() {
      _currentStep = UploadProcessStep.uploading;
      _uploadProgress = 0.15;
      _analysisStepIndex = 0;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isCancelled) return;
    setState(() => _uploadProgress = 0.35);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isCancelled) return;
    setState(() => _uploadProgress = 0.50);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isCancelled) return;
    setState(() => _uploadProgress = 0.75);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isCancelled) return;
    setState(() => _uploadProgress = 1.0);

    // 2. Upload Completed Stage (100% with 3 green checks)
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || _isCancelled) return;
    setState(() => _currentStep = UploadProcessStep.uploadCompleted);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _isCancelled) return;

    // 3. Analyzing Document Stage (4 lines with animated checkmarks)
    setState(() {
      _currentStep = UploadProcessStep.analyzing;
      _analysisStepIndex = 0;
    });

    for (int i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || _isCancelled) return;
      setState(() {
        _analysisStepIndex = i;
      });
    }

    // 4. Processing & Generating Insights Stage
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isCancelled) return;
    setState(() {
      _currentStep = UploadProcessStep.generatingInsights;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _isCancelled) return;

    // Pause video when analysis is fully complete
    if (_isVideoInitialized && _videoController != null) {
      _videoController!.pause();
    }

    // 5. Final Completed Stage: switch top image to Verified Bank Checklist.png!
    setState(() {
      _currentStep = UploadProcessStep.completed;
    });
  }

  void _showResultsModal() {
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
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Compliance Extraction Results',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '4 Actionable Regulatory Items Extracted:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            _buildResultItem(
              'RBI Master Direction Sec 4.2',
              'Capital Adequacy ratio compliance verified (11.5% minimum tier-1).',
            ),
            _buildResultItem(
              'Risk Governance Framework',
              'Mandatory quarterly audit report submission scheduled.',
            ),
            _buildResultItem(
              'KYC / AML Norms 2024',
              'Customer due diligence policy aligned with latest RBI circular.',
            ),
            _buildResultItem(
              'Action Items Generated',
              '3 compliance tasks assigned to Risk & Audit department.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontFamily: 'Poppins',
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

  Widget _buildResultItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
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
    final isCompleted = _currentStep == UploadProcessStep.completed;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Direct Scaffold layout (No overlapping container, clean page)
          SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Banner: Switch between initial hero image, animated HTML-style illustration, and verified checklist
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: isInitial
                        ? SizedBox(
                            key: const ValueKey('initial_banner'),
                            width: double.infinity,
                            height: size.width * (1078 / 1459),
                            child: Image.asset(
                              AppAssets.uploadBanner,
                              width: double.infinity,
                              height: size.width * (1078 / 1459),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
                          )
                        : isCompleted
                        ? SizedBox(
                            key: const ValueKey('completed_banner'),
                            width: double.infinity,
                            height: size.width * (887 / 1774),
                            child: Image.asset(
                              AppAssets.verifiedChecklist,
                              width: double.infinity,
                              height: size.width * (887 / 1774),
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                            ),
                          )
                        : _buildUploadingVideoBanner(size),
                  ),

                  // Content placed directly in Scaffold (No overlapping containers)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildCurrentContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Top-Right Close Button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: Colors.black.withAlpha(25),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingVideoBanner(Size size) {
    if (_isVideoInitialized && _videoController != null) {
      return SizedBox(
        key: const ValueKey('video_banner'),
        width: double.infinity,
        height: size.width * (1078 / 1459),
        child: Container(
          color: const Color(0xFFF1F5F9),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width > 0
                  ? _videoController!.value.size.width
                  : size.width,
              height: _videoController!.value.size.height > 0
                  ? _videoController!.value.size.height
                  : size.width * (1078 / 1459),
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      );
    }

    return CidanUploadAnimationBanner(
      key: const ValueKey('animated_banner'),
      step: _currentStep,
      progress: _uploadProgress,
      analysisStepIndex: _analysisStepIndex,
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentStep) {
      case UploadProcessStep.initial:
        return _buildInitialUploadContent();
      case UploadProcessStep.uploading:
        return _buildUploadingProgressContent();
      case UploadProcessStep.uploadCompleted:
        return _buildUploadCompletedContent();
      case UploadProcessStep.analyzing:
        return _buildAnalyzingContent();
      case UploadProcessStep.generatingInsights:
        return _buildGeneratingInsightsContent();
      case UploadProcessStep.completed:
        return _buildCompletedContent();
    }
  }

  // Page 1: Initial Drag & Drop View (Clean Scaffold, no overlapping handles)
  Widget _buildInitialUploadContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        // Drag & Drop Zone with dashed border
        CustomPaint(
          painter: DashedBorderPainter(
            color: const Color(0xFFC7D2FE),
            strokeWidth: 1.5,
            gap: 5.0,
            dashLength: 7.0,
            borderRadius: 16.0,
          ),
          child: InkWell(
            onTap: _isPickingFile ? null : _handleChooseFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFE),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 42,
                    color: Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Drag & Drop your file here',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isPickingFile ? null : _handleChooseFile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(
                        color: Color(0xFF4F46E5),
                        width: 1.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      backgroundColor: Colors.white,
                    ),
                    icon: _isPickingFile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4F46E5),
                            ),
                          )
                        : const Icon(
                            Icons.folder_open_rounded,
                            size: 19,
                            color: Color(0xFF4F46E5),
                          ),
                    label: Text(
                      _isPickingFile ? 'Opening Storage...' : 'Choose File',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Supported formats: PDF, DOCX, DOC (Max 50 MB)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),

        // ONLY shown after user chooses a file!
        if (_hasSelectedFile) ...[
          const SizedBox(height: 20),
          _buildFilePreviewCard(showCheckmark: false),
          const SizedBox(height: 20),
          // Upload & Process Button
          _buildGradientButton(
            label: 'Upload & Process',
            icon: Icons.cloud_upload_outlined,
            onPressed: _startUploadAndAnalysis,
          ),
        ],
      ],
    );
  }

  // Pages 2 & 3: Uploading File Progress (35% -> 75%)
  Widget _buildUploadingProgressContent() {
    final pct = (_uploadProgress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Uploading file...',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        Text(
          '$_fileName  $_fileSize',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 22),

        // Progress bar with percentage
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFEEF0FA),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '$pct%',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Cancel Button
        Center(
          child: SizedBox(
            width: 130,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _cancelUpload,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_rounded, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Text(
              'Your file is securely uploaded.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Page 4: Upload Completed! (100% + scanning indicators)
  Widget _buildUploadCompletedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload Completed!',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        Text(
          '$_fileName  $_fileSize',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Progress 100%
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 12,
                  backgroundColor: Color(0xFFEEF0FA),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              '100%',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // 3 completed checks
        _buildCheckRow('File uploaded successfully', isDone: true),
        _buildCheckRow('Scanning document', isDone: true),
        _buildCheckRow('Preparing for analysis', isDone: true),
      ],
    );
  }

  // Page 5: Analyzing Document... (4 lines of OCR & Compliance Extraction from HTML animation!)
  Widget _buildAnalyzingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Analyzing Document...',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        const Text(
          'Extracting key information from the circular.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 22),

        // The 4 lines of analysis animation matching CIDAN upload animation.html
        ...List.generate(_analysisSteps.length, (index) {
          final isDone = index < _analysisStepIndex;
          final isCurrent = index == _analysisStepIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                if (isDone)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                else if (isCurrent)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4F46E5),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.8,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _analysisSteps[index],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: isDone || isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isDone || isCurrent
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Page 6: Processing & Generating Insights...
  Widget _buildGeneratingInsightsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Processing & Generating Insights...',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        const Text(
          'Converting regulatory updates into actionable compliance insights.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 22),

        ...List.generate(_insightSteps.length, (index) {
          final isDone = index <= 2;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                if (isDone)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  )
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _insightSteps[index],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Page 9: Completed Document Processed Successfully
  Widget _buildCompletedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Document Processed Successfully',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        const Text(
          'The contents have been analyzed and compliance insights are ready.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Selected File Card with green checkmark (Page 9 style)
        _buildFilePreviewCard(showCheckmark: true),

        const SizedBox(height: 24),

        // Action Buttons Row: [ View Results -> ] and [ Upload Another ]
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
                  onPressed: _showResultsModal,
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
                          fontFamily: 'Poppins',
                          fontSize: 15,
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
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    if (_isVideoInitialized && _videoController != null) {
                      _videoController!.pause();
                      _videoController!.seekTo(Duration.zero);
                    }
                    setState(() {
                      _hasSelectedFile = false; // Reset file selection!
                      _currentStep = UploadProcessStep.initial;
                      _uploadProgress = 0.0;
                      _analysisStepIndex = 0;
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
                  child: const Text(
                    'Upload Another',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
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

  Widget _buildCheckRow(String text, {required bool isDone}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreviewCard({required bool showCheckmark}) {
    Color badgeColor = const Color(0xFFEF4444); // PDF red
    IconData badgeIcon = Icons.picture_as_pdf_rounded;
    String badgeText = 'PDF';

    if (_fileExtension == 'doc' || _fileExtension == 'docx') {
      badgeColor = const Color(0xFF2563EB); // Word blue
      badgeIcon = Icons.description_rounded;
      badgeText = _fileExtension.toUpperCase();
    } else if (_fileExtension != 'pdf') {
      badgeColor = const Color(0xFF64748B);
      badgeIcon = Icons.insert_drive_file_rounded;
      badgeText = _fileExtension.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Dynamic Badge (PDF / DOC / DOCX)
          Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(badgeIcon, size: 16, color: Colors.white),
                Text(
                  badgeText,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // File Name & Size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _fileSize,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
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

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
