import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Palette
  static const Color primary = Color(0xFF4F46E5); // Vibrant Indigo / Purple
  static const Color primaryHover = Color(0xFF4338CA);
  static const Color primaryLight = Color(0xFFEEF0FF);
  static const Color primarySoft = Color(0xFFF3F2FD);

  // Backgrounds
  static const Color background = Color(0xFFFAFBFD);
  static const Color surface = Colors.white;
  static const Color toggleBackground = Color(0xFFF1F3F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Dark Slate / Navy
  static const Color textSecondary = Color(0xFF64748B); // Slate Grey
  static const Color textMuted = Color(0xFF94A3B8); // Light Grey
  static const Color textLink = Color(0xFF4F46E5);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF4F46E5);
  static const Color borderError = Color(0xFFEF4444);

  // Functional / Status
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5046E5),
      Color(0xFF4338CA),
    ],
  );

  static const LinearGradient backgroundWave = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00FFFFFF),
      Color(0x1A6366F1),
    ],
  );
}
