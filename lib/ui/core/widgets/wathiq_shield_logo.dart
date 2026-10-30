import 'package:flutter/material.dart';
import '../theme/wathiq_theme.dart';

/// شعار "وثيق PDF" المكون من درع هندسي مدمج مع زاوية وثيقة مطوية.
class WathiqShieldLogo extends StatelessWidget {
  const WathiqShieldLogo({
    super.key,
    this.size = 36,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = WathiqPalette.of(context);
    return Semantics(
      label: 'شعار وثيق PDF للمعالجة المحلية الآمنة',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: palette.accent, width: 1.5),
        ),
        child: CustomPaint(
          painter: _ShieldDocumentPainter(
            accentColor: palette.accent,
            textColor: palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ShieldDocumentPainter extends CustomPainter {
  const _ShieldDocumentPainter({
    required this.accentColor,
    required this.textColor,
  });

  final Color accentColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shieldPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final docPaint = Paint()
      ..color = textColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final w = size.width;
    final h = size.height;

    final shieldPath = Path()
      ..moveTo(w * 0.5, h * 0.14)
      ..lineTo(w * 0.82, h * 0.26)
      ..lineTo(w * 0.82, h * 0.54)
      ..quadraticBezierTo(w * 0.82, h * 0.78, w * 0.5, h * 0.88)
      ..quadraticBezierTo(w * 0.18, h * 0.78, w * 0.18, h * 0.54)
      ..lineTo(w * 0.18, h * 0.26)
      ..close();

    canvas.drawPath(shieldPath, shieldPaint);

    // زاوية الوثيقة الداخلية المطوية (Identity Motif)
    final docRect = Path()
      ..moveTo(w * 0.36, h * 0.34)
      ..lineTo(w * 0.56, h * 0.34)
      ..lineTo(w * 0.64, h * 0.42)
      ..lineTo(w * 0.64, h * 0.66)
      ..lineTo(w * 0.36, h * 0.66)
      ..close();

    canvas.drawPath(docRect, docPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldDocumentPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.textColor != textColor;
  }
}
