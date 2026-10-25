import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';

enum UserRole {
  bankUser(
    label: AppStrings.bankUser,
    icon: Icons.person_rounded,
  ),
  adminStaff(
    label: AppStrings.adminStaff,
    icon: Icons.badge_outlined,
  );

  final String label;
  final IconData icon;

  const UserRole({
    required this.label,
    required this.icon,
  });
}
