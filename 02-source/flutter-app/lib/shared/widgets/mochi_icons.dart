import 'package:flutter/material.dart';

class MochiVectorIcon extends StatelessWidget {
  final String type;
  final double size;
  final Color? color;

  const MochiVectorIcon(this.type, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).primaryColor;
    return CustomPaint(
      size: Size(size, size),
      painter: _MochiIconPainter(type: type, color: themeColor),
    );
  }
}

class _MochiIconPainter extends CustomPainter {
  final String type;
  final Color color;

  _MochiIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (type) {
      case 'home':
        final path = Path()
          ..moveTo(w * 0.15, h * 0.42)
          ..lineTo(w * 0.5, h * 0.15)
          ..lineTo(w * 0.85, h * 0.42)
          ..lineTo(w * 0.85, h * 0.85)
          ..lineTo(w * 0.15, h * 0.85)
          ..close();
        canvas.drawPath(path, paint);
        final door = Path()
          ..moveTo(w * 0.38, h * 0.85)
          ..lineTo(w * 0.38, h * 0.55)
          ..lineTo(w * 0.62, h * 0.55)
          ..lineTo(w * 0.62, h * 0.85);
        canvas.drawPath(door, paint);
        break;

      case 'plan':
      case 'calendar':
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.7, h * 0.65),
          Radius.circular(w * 0.1),
        );
        canvas.drawRRect(rect, paint);
        canvas.drawLine(Offset(w * 0.15, h * 0.38), Offset(w * 0.85, h * 0.38), paint);
        canvas.drawLine(Offset(w * 0.35, h * 0.1), Offset(w * 0.35, h * 0.25), paint);
        canvas.drawLine(Offset(w * 0.65, h * 0.1), Offset(w * 0.65, h * 0.25), paint);
        break;

      case 'timer':
        canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.35, paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.5, h * 0.35), paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.55), Offset(w * 0.65, h * 0.55), paint);
        canvas.drawLine(Offset(w * 0.4, h * 0.12), Offset(w * 0.6, h * 0.12), paint);
        break;

      case 'robot':
        // Head
        final headRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.6, h * 0.5),
          Radius.circular(w * 0.12),
        );
        canvas.drawRRect(headRect, paint);
        // Antenna
        canvas.drawLine(Offset(w * 0.5, h * 0.25), Offset(w * 0.5, h * 0.12), paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.1), w * 0.05, fillPaint);
        // Eyes
        canvas.drawCircle(Offset(w * 0.38, h * 0.45), w * 0.05, fillPaint);
        canvas.drawCircle(Offset(w * 0.62, h * 0.45), w * 0.05, fillPaint);
        // Smile
        final mouth = Path()
          ..moveTo(w * 0.38, h * 0.58)
          ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.62, h * 0.58);
        canvas.drawPath(mouth, paint);
        break;

      case 'star':
        final starPath = Path();
        final cx = w * 0.5;
        final cy = h * 0.5;
        final outerR = w * 0.4;
        final innerR = w * 0.18;
        for (int i = 0; i < 10; i++) {
          final r = i.isEven ? outerR : innerR;
          // 10-point star
          final x = cx + r * (i == 0 || i == 5 ? (i == 0 ? 0 : 0) : (i == 1 ? 0.587 : (i == 2 ? 0.951 : (i == 3 ? 0.587 : (i == 4 ? 0.309 : (i == 6 ? -0.309 : (i == 7 ? -0.587 : (i == 8 ? -0.951 : -0.587))))))));
          final y = cy + r * (i == 0 ? -1 : (i == 1 ? -0.309 : (i == 2 ? 0.309 : (i == 3 ? 0.809 : (i == 4 ? 1 : (i == 5 ? 1 : (i == 6 ? 0.809 : (i == 7 ? 0.309 : (i == 8 ? -0.309 : -0.809)))))))));
          if (i == 0) {
            starPath.moveTo(x, y);
          } else {
            starPath.lineTo(x, y);
          }
        }
        starPath.close();
        canvas.drawPath(starPath, fillPaint);
        break;

      case 'flashcard':
        final r1 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.15, h * 0.25, w * 0.55, h * 0.6),
          Radius.circular(w * 0.08),
        );
        final r2 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.3, h * 0.15, w * 0.55, h * 0.6),
          Radius.circular(w * 0.08),
        );
        canvas.drawRRect(r2, paint);
        canvas.drawRRect(r1, fillPaint);
        break;

      case 'shop':
        final bag = Path()
          ..moveTo(w * 0.2, h * 0.35)
          ..lineTo(w * 0.8, h * 0.35)
          ..lineTo(w * 0.75, h * 0.85)
          ..lineTo(w * 0.25, h * 0.85)
          ..close();
        canvas.drawPath(bag, paint);
        final handle = Path()
          ..moveTo(w * 0.35, h * 0.35)
          ..cubicTo(w * 0.35, h * 0.15, w * 0.65, h * 0.15, w * 0.65, h * 0.35);
        canvas.drawPath(handle, paint);
        break;

      case 'chat':
        final bubble = Path()
          ..moveTo(w * 0.2, h * 0.25)
          ..lineTo(w * 0.8, h * 0.25)
          ..quadraticBezierTo(w * 0.88, h * 0.25, w * 0.88, h * 0.35)
          ..lineTo(w * 0.88, h * 0.65)
          ..quadraticBezierTo(w * 0.88, h * 0.75, w * 0.8, h * 0.75)
          ..lineTo(w * 0.45, h * 0.75)
          ..lineTo(w * 0.3, h * 0.9)
          ..lineTo(w * 0.3, h * 0.75)
          ..lineTo(w * 0.2, h * 0.75)
          ..quadraticBezierTo(w * 0.12, h * 0.75, w * 0.12, h * 0.65)
          ..lineTo(w * 0.12, h * 0.35)
          ..quadraticBezierTo(w * 0.12, h * 0.25, w * 0.2, h * 0.25)
          ..close();
        canvas.drawPath(bubble, paint);
        break;

      default:
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.35, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MochiIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

