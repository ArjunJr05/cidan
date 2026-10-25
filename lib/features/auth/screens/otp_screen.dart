import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../compliance/screens/upload_document_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/security_notice_card.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<OtpInputRowState> _otpKey = GlobalKey<OtpInputRowState>();
  String _otpValue = '284910';
  bool _isVerifying = false;
  String? _errorMessage;

  int _countdown = 28;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _countdown = 28);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _resendOtp() {
    _startTimer();
    _otpKey.currentState?.setOtp('');
    setState(() {
      _otpValue = '';
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: const [
            Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'A new 6-digit OTP has been sent to your bank email.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();

    if (_otpValue.length < 6) {
      setState(() {
        _errorMessage = AppStrings.incompleteOtpError;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() => _isVerifying = false);

    // Navigate directly to the Upload Regulatory Document screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            UploadDocumentScreen(email: widget.email),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'OTP Verification',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Having trouble receiving your verification code?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '• Please check your bank email inbox and spam folder.\n'
              '• The code expires after 5 minutes.\n'
              '• If the countdown ends, click "Resend OTP" to request a new code.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageHeight = (size.height * 0.44).clamp(290.0, 390.0);
    const overlapHeight = 10.0;
    final timerText = '00:${_countdown.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Non-Scrollable Layout fitting the screen
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: size.height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Hero Image (flush to top, left, right)
                  SizedBox(
                    width: double.infinity,
                    height: imageHeight,
                    child: Image.asset(
                      AppAssets.otpIllustration,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),

                  // Lowered Curved Container with Content
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -overlapHeight),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 16,
                              offset: Offset(0, -4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top grey indicator pill handle
                                Center(
                                  child: Container(
                                    width: 48,
                                    height: 4.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Subtitle with highlighted user email
                                Column(
                                  children: [
                                    const Text(
                                      AppStrings.verifyEmailSubtitle,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      widget.email,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // 6-digit OTP Input Row
                                OtpInputRow(
                                  key: _otpKey,
                                  length: 6,
                                  initialValue: _otpValue,
                                  onChanged: (val) {
                                    setState(() {
                                      _otpValue = val;
                                      if (_errorMessage != null) {
                                        _errorMessage = null;
                                      }
                                    });
                                  },
                                  onCompleted: (val) {
                                    setState(() => _otpValue = val);
                                  },
                                ),

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: AppColors.error,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // Resend OTP Countdown / Action
                                Center(
                                  child: _countdown > 0
                                      ? RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF64748B),
                                              fontSize: 13,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text:
                                                    '${AppStrings.resendOtpIn} ',
                                              ),
                                              TextSpan(
                                                text: timerText,
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Color(0xFF4F46E5),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : TextButton.icon(
                                          onPressed: _resendOtp,
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            size: 17,
                                            color: Color(0xFF4F46E5),
                                          ),
                                          label: const Text(
                                            AppStrings.resendOtpNow,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF4F46E5),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 14),

                                // Verify OTP Button
                                CustomButton(
                                  label: AppStrings.verifyOtp,
                                  isLoading: _isVerifying,
                                  height: 52,
                                  onPressed: _handleVerifyOtp,
                                ),

                                const SizedBox(height: 14),

                                // Security Expiration Notice Card
                                const SecurityNoticeCard(),

                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Top Bar over Image: Back Button (Left) & Help Button (Right)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button Pill
                  Material(
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
                          Icons.arrow_back_rounded,
                          color: Color(0xFF0F172A),
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                    ),
                  ),

                  // Help Button Pill
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    shadowColor: Colors.black.withAlpha(25),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showHelpDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 17,
                              color: Color(0xFF0F172A),
                            ),
                            SizedBox(width: 6),
                            Text(
                              AppStrings.help,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
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
          ),
        ],
      ),
    );
  }
}
