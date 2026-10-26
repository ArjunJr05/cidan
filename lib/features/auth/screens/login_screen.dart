import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/validators.dart';
import '../widgets/custom_button.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isLoading = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
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
              'CIDAN Support',
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
              'Need assistance with your banking regulatory compliance login?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '• Ensure you are using your official registered bank email address (@yourbank.com) or official mobile number.\n'
              '• OTP verification codes are valid for 5 minutes.\n'
              '• For IT desk support, contact support@cidan.ai.',
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

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    final text = _emailController.text.trim();
    final validationError = Validators.validateEmailOrPhone(text);
    if (validationError != null) {
      setState(() => _emailError = validationError);
      return;
    }
    setState(() => _emailError = null);

    setState(() => _isLoading = true);

    // Generate & save OTP in Supabase and send via SMTP if configured
    await SupabaseService().sendAndSaveOtp(text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OtpScreen(
              email: text,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 0;
    final isCompact = size.height < 720;
    final isTall = size.height > 850;

    final titleFontSize = (size.height * 0.026).clamp(18.0, 22.0);
    final subtitleFontSize = (size.height * 0.016).clamp(12.0, 13.5);
    final formPaddingV = isCompact ? 10.0 : (isTall ? 16.0 : 13.0);
    final buttonHeight = (size.height * 0.06).clamp(46.0, 52.0);
    const overlapHeight = 24.0;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;

            // When keyboard is open, dynamically position card above keyboard
            final cardHeight = isKeyboardOpen
                ? (availableHeight * 0.74).clamp(280.0, 360.0)
                : (size.height * (isCompact ? 0.45 : 0.41)).clamp(295.0, 370.0);

            final heroHeight = isKeyboardOpen
                ? (availableHeight - cardHeight + overlapHeight).clamp(
                    60.0,
                    240.0,
                  )
                : (availableHeight - cardHeight + overlapHeight);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Top Hero Image: spans from top to beneath the curved card
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight,
                  child: Image.asset(
                    AppAssets.loginIllustration,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),

                // 2. Overlapping Curved Container with Form Controls (Pinned to bottom of available area)
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
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              physics: isKeyboardOpen
                                  ? const BouncingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top grey pill indicator handle
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

                                  // Heading: "Login with your bank email"
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppStrings.loginTitle,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: isKeyboardOpen
                                              ? 18.0
                                              : titleFontSize,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppStrings.loginSubtitle,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: const Color(0xFF64748B),
                                          fontSize: isKeyboardOpen
                                              ? 12.0
                                              : subtitleFontSize,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: isKeyboardOpen ? 8 : 12),

                                  // Email Input Container with rounded purple badge icon
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: _emailError != null
                                                ? AppColors.error
                                                : (_emailFocusNode.hasFocus
                                                      ? const Color(0xFF4F46E5)
                                                      : const Color(
                                                          0xFFE2E8F0,
                                                        )),
                                            width: _emailFocusNode.hasFocus
                                                ? 1.8
                                                : 1.3,
                                          ),
                                          boxShadow: _emailFocusNode.hasFocus
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF4F46E5,
                                                    ).withAlpha(30),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: isCompact ? 36 : 40,
                                              height: isCompact ? 36 : 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.mail_outline_rounded,
                                                color: Color(0xFF4F46E5),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _emailController,
                                                focusNode: _emailFocusNode,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                autocorrect: false,
                                                enableSuggestions: true,
                                                textInputAction:
                                                    TextInputAction.done,
                                                onFieldSubmitted: (_) =>
                                                    _handleSendOtp(),
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: isCompact ? 14 : 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(
                                                    0xFF0F172A,
                                                  ),
                                                ),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  errorBorder: InputBorder.none,
                                                  focusedErrorBorder:
                                                      InputBorder.none,
                                                  filled: false,
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  hintText: 'name@yourbank.com',
                                                  hintStyle: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: const Color(
                                                      0xFF94A3B8,
                                                    ),
                                                    fontSize: isCompact
                                                        ? 14
                                                        : 15,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                                onChanged: (_) {
                                                  if (_emailError != null) {
                                                    setState(
                                                      () => _emailError = null,
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            ValueListenableBuilder<
                                              TextEditingValue
                                            >(
                                              valueListenable: _emailController,
                                              builder: (context, value, _) {
                                                if (value.text.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                return IconButton(
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                    size: 18,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  onPressed: () {
                                                    _emailController.clear();
                                                    setState(
                                                      () => _emailError = null,
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_emailError != null) ...[
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4.0,
                                          ),
                                          child: Text(
                                            _emailError!,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: AppColors.error,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),

                                  SizedBox(height: isKeyboardOpen ? 10 : 14),

                                  // Send OTP Button
                                  CustomButton(
                                    label: AppStrings.sendOtpCode,
                                    isLoading: _isLoading,
                                    height: buttonHeight,
                                    onPressed: _handleSendOtp,
                                  ),

                                  SizedBox(height: isKeyboardOpen ? 8 : 12),

                                  // Security Note
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          AppStrings.encryptionNote,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Color(0xFF64748B),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Help Button positioned directly on top of the image (hidden when keyboard is open)
                if (!isKeyboardOpen)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, right: 18.0),
                        child: Material(
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
