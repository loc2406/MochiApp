import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/mochi_models.dart';
import 'robot_art_palette.dart';

class RobotMascotWidget extends StatefulWidget {
  final double size;
  final RobotEmotion emotion;
  final Color primaryColor;
  final String equippedAccessory;
  final String equippedClothes;
  final String equippedSpecial;
  final VoidCallback? onTap;

  const RobotMascotWidget({
    super.key,
    this.size = 140,
    this.emotion = RobotEmotion.idle,
    this.primaryColor = RobotArtPalette.green,
    this.equippedAccessory = '',
    this.equippedClothes = '',
    this.equippedSpecial = '',
    this.onTap,
  });

  @override
  State<RobotMascotWidget> createState() => _RobotMascotWidgetState();
}

class _RobotMascotWidgetState extends State<RobotMascotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(
      begin: -4,
      end: 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 0.95, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isThinking = widget.emotion == RobotEmotion.thinking;
          final isCelebrating = widget.emotion == RobotEmotion.celebrate;
          final isSleeping = widget.emotion == RobotEmotion.sleeping;

          double translateY = _bounceAnimation.value;
          if (isCelebrating) translateY *= 2.2;
          if (isSleeping) translateY = 2.0;

          return Transform.translate(
            offset: Offset(0, translateY),
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RobotMascotPainter(
                emotion: widget.emotion,
                primaryColor: widget.primaryColor,
                equippedAccessory: widget.equippedAccessory,
                equippedClothes: widget.equippedClothes,
                equippedSpecial: widget.equippedSpecial,
                eyeScaleY: isSleeping ? 0.05 : _blinkAnimation.value,
                tiltAngle: isThinking
                    ? -0.08
                    : (isCelebrating
                          ? math.sin(_controller.value * 6) * 0.06
                          : 0.0),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RobotMascotPainter extends CustomPainter {
  final RobotEmotion emotion;
  final Color primaryColor;
  final String equippedAccessory;
  final String equippedClothes;
  final String equippedSpecial;
  final double eyeScaleY;
  final double tiltAngle;

  _RobotMascotPainter({
    required this.emotion,
    required this.primaryColor,
    required this.equippedAccessory,
    required this.equippedClothes,
    required this.equippedSpecial,
    required this.eyeScaleY,
    required this.tiltAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltAngle);
    canvas.translate(-center.dx, -center.dy);

    // 1. Soft Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.93),
        width: w * 0.65,
        height: h * 0.12,
      ),
      shadowPaint,
    );

    // 2. Antenna
    final metalPaint = Paint()
      ..color = const Color(0xFF6B82A6)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.28),
      Offset(w * 0.5, h * 0.15),
      metalPaint,
    );

    final bulbPaint = Paint()
      ..color =
          (emotion == RobotEmotion.thinking || emotion == RobotEmotion.focus)
          ? RobotArtPalette.starGold
          : primaryColor;
    canvas.drawCircle(Offset(w * 0.5, h * 0.12), w * 0.06, bulbPaint);

    // 3. Robot Ears / Bolts
    final earPaint = Paint()..color = const Color(0xFF7E97BA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.38, w * 0.08, h * 0.14),
        const Radius.circular(4),
      ),
      earPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.38, w * 0.08, h * 0.14),
        const Radius.circular(4),
      ),
      earPaint,
    );

    // 4. Robot Head Base
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.24, w * 0.6, h * 0.44),
      Radius.circular(w * 0.14),
    );
    final headPaint = Paint()..color = const Color(0xFFF4F8FD);
    canvas.drawRRect(headRect, headPaint);

    // Head Border with primary color accent
    final headBorder = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024;
    canvas.drawRRect(headRect, headBorder);

    // 5. Screen Face
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.27, h * 0.31, w * 0.46, h * 0.3),
      Radius.circular(w * 0.08),
    );
    final screenPaint = Paint()..color = const Color(0xFF16233B);
    canvas.drawRRect(screenRect, screenPaint);

    // 6. Eyes
    final eyePaint = Paint()
      ..color =
          (emotion == RobotEmotion.happy || emotion == RobotEmotion.celebrate)
          ? const Color(0xFF67FFD4)
          : (emotion == RobotEmotion.thinking
                ? const Color(0xFFFFD56B)
                : const Color(0xFF5CE1E6));

    final eyeLeftCenter = Offset(w * 0.38, h * 0.43);
    final eyeRightCenter = Offset(w * 0.62, h * 0.43);
    final eyeRadius = w * 0.045;

    if (emotion == RobotEmotion.happy || emotion == RobotEmotion.celebrate) {
      // Arc / Happy squint eyes
      final leftArc = Path()
        ..addArc(
          Rect.fromCircle(center: eyeLeftCenter, radius: eyeRadius),
          3.14,
          3.14,
        );
      final rightArc = Path()
        ..addArc(
          Rect.fromCircle(center: eyeRightCenter, radius: eyeRadius),
          3.14,
          3.14,
        );
      final arcPaint = Paint()
        ..color = eyePaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(leftArc, arcPaint);
      canvas.drawPath(rightArc, arcPaint);
    } else {
      // Normal blinking circular eyes
      canvas.save();
      canvas.translate(eyeLeftCenter.dx, eyeLeftCenter.dy);
      canvas.scale(1.0, eyeScaleY);
      canvas.drawCircle(Offset.zero, eyeRadius, eyePaint);
      canvas.restore();

      canvas.save();
      canvas.translate(eyeRightCenter.dx, eyeRightCenter.dy);
      canvas.scale(1.0, eyeScaleY);
      canvas.drawCircle(Offset.zero, eyeRadius, eyePaint);
      canvas.restore();
    }

    // 7. Cheeks (blush)
    final blushPaint = Paint()
      ..color = const Color(0xFFFF85A2).withOpacity(0.65);
    canvas.drawCircle(Offset(w * 0.33, h * 0.52), w * 0.025, blushPaint);
    canvas.drawCircle(Offset(w * 0.67, h * 0.52), w * 0.025, blushPaint);

    // 8. Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF5CE1E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    if (emotion == RobotEmotion.celebrate || emotion == RobotEmotion.happy) {
      mouthPath.moveTo(w * 0.44, h * 0.51);
      mouthPath.quadraticBezierTo(w * 0.5, h * 0.57, w * 0.56, h * 0.51);
    } else if (emotion == RobotEmotion.thinking) {
      mouthPath.moveTo(w * 0.46, h * 0.53);
      mouthPath.lineTo(w * 0.54, h * 0.51);
    } else {
      mouthPath.moveTo(w * 0.45, h * 0.52);
      mouthPath.quadraticBezierTo(w * 0.5, h * 0.55, w * 0.55, h * 0.52);
    }
    canvas.drawPath(mouthPath, mouthPaint);

    // 9. Robot Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.66, w * 0.44, h * 0.22),
      Radius.circular(w * 0.08),
    );
    final bodyPaint = Paint()..color = const Color(0xFFE2ECF8);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Screen Core / Battery Heart
    final corePaint = Paint()..color = primaryColor;
    canvas.drawCircle(Offset(w * 0.5, h * 0.76), w * 0.045, corePaint);

    // 10. Accessories Rendering
    _drawAccessories(canvas, w, h);

    canvas.restore();
  }

  void _drawAccessories(Canvas canvas, double w, double h) {
    // Glasses / Sunglasses
    if (equippedAccessory == 'sunglasses') {
      final glassPaint = Paint()..color = const Color(0xFF1E242B);
      final rLeft = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.31, h * 0.38, w * 0.16, h * 0.09),
        const Radius.circular(3),
      );
      final rRight = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.53, h * 0.38, w * 0.16, h * 0.09),
        const Radius.circular(3),
      );
      canvas.drawRRect(rLeft, glassPaint);
      canvas.drawRRect(rRight, glassPaint);
      final bridge = Paint()
        ..color = const Color(0xFF333D47)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(w * 0.47, h * 0.42),
        Offset(w * 0.53, h * 0.42),
        bridge,
      );
    }

    // Beanie or Cap
    if (equippedAccessory == 'beanie' || equippedAccessory == 'cap') {
      final hatPaint = Paint()..color = const Color(0xFFE65100);
      final hat = Path()
        ..moveTo(w * 0.22, h * 0.26)
        ..quadraticBezierTo(w * 0.5, h * 0.08, w * 0.78, h * 0.26)
        ..close();
      canvas.drawPath(hat, hatPaint);
    }

    // Clothes (Tee, Suit, Armor)
    if (equippedClothes == 'tee') {
      final teePaint = Paint()..color = const Color(0xFF1E88E5);
      final teeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.68, w * 0.4, h * 0.19),
        const Radius.circular(6),
      );
      canvas.drawRRect(teeRect, teePaint);
    } else if (equippedClothes == 'suit') {
      final suitPaint = Paint()..color = const Color(0xFF263238);
      final suitRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, h * 0.68, w * 0.4, h * 0.19),
        const Radius.circular(6),
      );
      canvas.drawRRect(suitRect, suitPaint);
      // Red tie
      final tie = Path()
        ..moveTo(w * 0.48, h * 0.69)
        ..lineTo(w * 0.52, h * 0.69)
        ..lineTo(w * 0.53, h * 0.81)
        ..lineTo(w * 0.5, h * 0.84)
        ..lineTo(w * 0.47, h * 0.81)
        ..close();
      canvas.drawPath(tie, Paint()..color = const Color(0xFFD32F2F));
    }
  }

  @override
  bool shouldRepaint(covariant _RobotMascotPainter old) => true;
}
