import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

abstract final class ClinicBrand {
  static const name = 'Clinic Solution';
  static const copyright = '© 2026 ORBYTEZA TECH LLP. All rights reserved.';
}

/// A care cross cradled by a C-shaped orbit. Vector artwork at every size.
class ClinicLogo extends StatelessWidget {
  const ClinicLogo({super.key, this.size = 40, this.inverse = false});
  final double size;
  final bool inverse;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Clinic Solution logo',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: ClinicLogoPainter(inverse: inverse)),
    ),
  );
}

class ClinicLogoPainter extends CustomPainter {
  const ClinicLogoPainter({this.inverse = false});
  final bool inverse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(26),
      ),
      Paint()..color = inverse ? Colors.white : AppColors.primary,
    );
    final foreground = inverse ? AppColors.primary : Colors.white;
    canvas.drawArc(
      const Rect.fromLTWH(20, 20, 60, 60),
      math.pi / 4,
      math.pi * 1.5,
      false,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    final cross = Paint()..color = foreground;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(45, 34, 10, 32),
        const Radius.circular(3),
      ),
      cross,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 45, 32, 10),
        const Radius.circular(3),
      ),
      cross,
    );
    canvas.drawCircle(
      const Offset(80, 50),
      5,
      Paint()..color = inverse ? AppColors.primary : const Color(0xFFBCEDE0),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ClinicLogoPainter oldDelegate) =>
      inverse != oldDelegate.inverse;
}

/// Outside the route navigator, so nested screens do not repeat the footer.
class BrandedAppFrame extends StatelessWidget {
  const BrandedAppFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final showFooter = media.viewInsets.bottom == 0 && media.size.height >= 400;
    return Column(
      children: [
        Expanded(child: child),
        if (showFooter)
          Material(
            color: AppColors.canvas,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    ClinicBrand.copyright,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
