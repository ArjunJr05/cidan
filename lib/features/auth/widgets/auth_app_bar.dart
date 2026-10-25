import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class AuthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onHelpPressed;

  const AuthAppBar({
    super.key,
    this.showBackButton = false,
    this.onBackPressed,
    this.onHelpPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  void _defaultShowHelp(BuildContext context) {
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
              child: const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'CIDAN Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Need assistance with your banking regulatory compliance login?',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              '• Ensure you are using your official registered bank email address (@abcbank.com).\n'
              '• OTP verification codes are valid for 5 minutes.\n'
              '• For internal IT desk queries, contact support@cidan.ai.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: TextButton.icon(
            onPressed: onHelpPressed ?? () => _defaultShowHelp(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            label: const Text(
              AppStrings.help,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
