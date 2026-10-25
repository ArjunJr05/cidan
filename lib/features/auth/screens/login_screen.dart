import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
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
  final _emailController = TextEditingController(text: 'name@yourbank.com');
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
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
              '• Ensure you are using your official registered bank email address (@yourbank.com).\n'
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
    final validationError = Validators.validateEmail(_emailController.text);
    if (validationError != null) {
      setState(() => _emailError = validationError);
      return;
    }
    setState(() => _emailError = null);

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OtpScreen(email: _emailController.text.trim()),
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
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Fixed Non-Scrollable Layout fitting the screen
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Hero Image: takes remaining space
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    AppAssets.loginIllustration,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),

              // Overlapping Curved Container with Form Controls
              Transform.translate(
                offset: const Offset(0, -14),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top grey pill indicator handle
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

                              const SizedBox(height: 18),

                              // Heading: "Login with your bank email"
                              Text(
                                AppStrings.loginTitle,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Subtitle
                              Text(
                                AppStrings.loginSubtitle,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF64748B),
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Email Input Container with rounded purple badge icon
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _emailError != null
                                        ? AppColors.error
                                        : const Color(0xFFE2E8F0),
                                    width: 1.3,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    // Soft light-purple square badge with mail icon
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.mail_outline_rounded,
                                        color: Color(0xFF4F46E5),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autocorrect: false,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          filled: false,
                                          contentPadding: EdgeInsets.zero,
                                          hintText: 'name@yourbank.com',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Color(0xFF94A3B8),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        onChanged: (_) {
                                          if (_emailError != null) {
                                            setState(() => _emailError = null);
                                          }
                                        },
                                      ),
                                    ),
                                    if (_emailController.text.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onPressed: () {
                                          _emailController.clear();
                                          setState(() {});
                                        },
                                      ),
                                  ],
                                ),
                              ),

                              if (_emailError != null) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Text(
                                    _emailError!,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Send OTP Button
                              CustomButton(
                                label: AppStrings.sendOtpCode,
                                isLoading: _isLoading,
                                onPressed: _handleSendOtp,
                              ),

                              const SizedBox(height: 20),

                              // Security Note
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppStrings.encryptionNote,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF64748B),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Help Button positioned directly on top of the image (top right)
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
      ),
    );
  }
}
