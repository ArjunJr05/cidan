import 'package:flutter/material.dart';

class BottomWavePainter extends CustomPainter {
  final Color primaryColor;

  BottomWavePainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = primaryColor.withAlpha(20)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.5,
    );
    path1.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.8,
      size.width,
      size.height * 0.3,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = primaryColor.withAlpha(28)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.65);
    path2.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.45,
      size.width * 0.7,
      size.height * 0.75,
    );
    path2.quadraticBezierTo(
      size.width * 0.88,
      size.height * 0.9,
      size.width,
      size.height * 0.6,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
