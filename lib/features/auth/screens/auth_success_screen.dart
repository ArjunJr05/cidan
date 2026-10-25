import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/bottom_wave_painter.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class AuthSuccessScreen extends StatelessWidget {
  final String email;

  const AuthSuccessScreen({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: CustomPaint(
              painter: BottomWavePainter(primaryColor: AppColors.primary),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Success Icon Badge
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.success.withAlpha(60),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withAlpha(40),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 56,
                            color: AppColors.success,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'Verification Successful',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontFamily: 'Poppins',
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Welcome to CIDAN Regulatory Compliance AI platform.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // User Info Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Authenticated Bank Account',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      CustomButton(
                        label: 'Log Out / Re-test Flow',
                        icon: Icons.logout_rounded,
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
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
