import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/supabase_service.dart';
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
  String _otpValue = '';
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

  void _resendOtp() async {
    _startTimer();
    _otpKey.currentState?.setOtp('');
    setState(() {
      _otpValue = '';
      _errorMessage = null;
    });

    final res = await SupabaseService().sendAndSaveOtp(widget.email);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                res['emailSent'] == true
                    ? 'A new OTP has been sent to ${widget.email}.'
                    : 'A new 6-digit OTP code has been generated.',
                style: const TextStyle(
                  fontFamily: 'packages/cidan/Poppins',
                  color: Colors.white,
                  fontSize: 13,
                ),
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

    final isValid = await SupabaseService().verifyOtp(widget.email, _otpValue);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (!isValid) {
      setState(() {
        _errorMessage = 'Invalid or expired OTP code. Please check and try again.';
      });
      return;
    }

    // Save session in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cidan_is_logged_in', true);
    await prefs.setString('cidan_user_email', widget.email);

    if (!mounted) return;

    // Navigate directly to the Upload Regulatory Document screen and clear backstack
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            UploadDocumentScreen(email: widget.email),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 0;
    final isCompact = size.height < 720;
    final isTall = size.height > 850;

    final formPaddingV = isCompact ? 10.0 : (isTall ? 16.0 : 13.0);
    final buttonHeight = (size.height * 0.06).clamp(46.0, 52.0);
    const overlapHeight = 24.0;
    final timerText = '00:${_countdown.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;

            final cardHeight = isKeyboardOpen
                ? (availableHeight * 0.82).clamp(320.0, 460.0)
                : (size.height * (isCompact ? 0.58 : (isTall ? 0.53 : 0.55)))
                      .clamp(370.0, 480.0);

            final heroHeight = isKeyboardOpen
                ? (availableHeight - cardHeight + overlapHeight).clamp(
                    50.0,
                    240.0,
                  )
                : (availableHeight - cardHeight + overlapHeight);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Top Hero Image: spans from top beneath the status bar to the curved card
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight,
                  child: Image.asset(
                    AppAssets.otpIllustration,
                    package: 'cidan',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.4),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),

                // 2. Overlapping Curved Container with OTP Controls (Pinned to bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 20,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      24,
                      isKeyboardOpen ? 10 : formPaddingV,
                      24,
                      isKeyboardOpen ? 8 : (isCompact ? 12 : 18),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: SingleChildScrollView(
                            physics: isKeyboardOpen
                                ? const BouncingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top grey indicator pill handle
                                Center(
                                  child: Container(
                                    width: 48,
                                    height: 4.5,
                                    margin: EdgeInsets.only(
                                      bottom: isKeyboardOpen ? 6 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),

                                // Subtitle with highlighted user email
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppStrings.verifyEmailSubtitle,
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        color: const Color(0xFF64748B),
                                        fontSize: isCompact ? 12.0 : 13.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.email,
                                      style: TextStyle(
                                        fontFamily: 'packages/cidan/Poppins',
                                        fontSize: isCompact ? 14 : 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),

                                SizedBox(height: isKeyboardOpen ? 10 : 16),

                                // 6-digit OTP Input Row
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                                          fontFamily: 'packages/cidan/Poppins',
                                          color: AppColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),

                                SizedBox(height: isKeyboardOpen ? 10 : 14),

                                // Resend OTP Countdown / Action
                                Center(
                                  child: _countdown > 0
                                      ? RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontFamily: 'packages/cidan/Poppins',
                                              color: const Color(0xFF64748B),
                                              fontSize: isCompact ? 12 : 13,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text:
                                                    '${AppStrings.resendOtpIn} ',
                                              ),
                                              TextSpan(
                                                text: timerText,
                                                style: const TextStyle(
                                                  fontFamily: 'packages/cidan/Poppins',
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
                                            size: 16,
                                            color: Color(0xFF4F46E5),
                                          ),
                                          label: const Text(
                                            AppStrings.resendOtpNow,
                                            style: TextStyle(
                                              fontFamily: 'packages/cidan/Poppins',
                                              color: Color(0xFF4F46E5),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                ),

                                SizedBox(height: isKeyboardOpen ? 10 : 16),

                                // Verify OTP Button
                                CustomButton(
                                  label: AppStrings.verifyOtp,
                                  isLoading: _isVerifying,
                                  height: buttonHeight,
                                  onPressed: _handleVerifyOtp,
                                ),

                                SizedBox(height: isKeyboardOpen ? 8 : 12),

                                // Security Expiration Notice Card
                                const SecurityNoticeCard(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
