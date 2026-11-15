import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Product-owned loading artwork. The base and eye layers come from the
/// supplied Mochii logo; page/shine details are vector paths, never emoji.
class MochiiLoadingIllustration extends StatefulWidget {
  final double size;
  final bool animate;
  const MochiiLoadingIllustration({
    super.key,
    this.size = 300,
    this.animate = true,
  });

  @override
  State<MochiiLoadingIllustration> createState() =>
      _MochiiLoadingIllustrationState();
}

class _MochiiLoadingIllustrationState extends State<MochiiLoadingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(MochiiLoadingIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncMotion();
  }

  void _syncMotion() {
    _reduceMotion =
        !widget.animate ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Mochii đang đọc sách',
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final phase = _motion.value;
            final wave = math.sin(phase * math.pi * 2);
            var blink = 1.0;
            if (!_reduceMotion) {
              for (final at in [0.18, 0.27]) {
                final distance = (phase - at).abs();
                if (distance < 0.023) {
                  blink = math.min(blink, 0.08 + 0.92 * distance / 0.023);
                }
              }
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: widget.size * 0.04,
                  child: Container(
                    width: widget.size * (0.38 - wave * 0.025),
                    height: widget.size * 0.034,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7DDF2),
                      borderRadius: BorderRadius.circular(200),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -wave * widget.size * 0.022),
                  child: Transform.rotate(
                    angle: wave * 0.028,
                    child: SizedBox(
                      width: widget.size * 0.78,
                      height: widget.size * 0.92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/animations/mochii_reading_base.png',
                            filterQuality: FilterQuality.medium,
                          ),
                          Transform.scale(
                            scaleY: blink,
                            alignment: const Alignment(0, -0.02),
                            child: Image.asset(
                              'assets/animations/mochii_reading_eyes.png',
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          if (!_reduceMotion)
                            CustomPaint(painter: _TurningPagePainter(phase)),
                        ],
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _ShinePainter(_reduceMotion ? 0 : phase),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _TurningPagePainter extends CustomPainter {
  final double phase;
  _TurningPagePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final turn = (phase - 0.36) / 0.4;
    if (turn <= 0 || turn >= 1) return;
    canvas.scale(size.width / 408, size.height / 480);
    final spread = 85 * math.cos(math.pi * turn);
    final page = Path()
      ..moveTo(208, 350)
      ..quadraticBezierTo(208 + spread * 0.5, 305, 208 + spread, 299)
      ..quadraticBezierTo(208 + spread * 0.7, 286, 208, 311)
      ..close();
    canvas.drawPath(page, Paint()..color = const Color(0xFFFFF6D5));
    canvas.drawPath(
      page,
      Paint()
        ..color = const Color(0xFFB997DA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TurningPagePainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _ShinePainter extends CustomPainter {
  final double phase;
  _ShinePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in [
      (0.09, 0.29, 0.0),
      (0.90, 0.17, 0.3),
      (0.91, 0.76, 0.65),
    ]) {
      final strength = 0.7 + 0.3 * math.sin((phase + star.$3) * math.pi * 2);
      final r = size.width * 0.026 * strength;
      final x = size.width * star.$1, y = size.height * star.$2;
      final path = Path()
        ..moveTo(x, y - r)
        ..lineTo(x + r * .30, y - r * .30)
        ..lineTo(x + r, y)
        ..lineTo(x + r * .30, y + r * .30)
        ..lineTo(x, y + r)
        ..lineTo(x - r * .30, y + r * .30)
        ..lineTo(x - r, y)
        ..lineTo(x - r * .30, y - r * .30)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xFFB38CDC).withValues(alpha: strength),
      );
    }
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) => oldDelegate.phase != phase;
}

class MochiiLoadingScreen extends StatelessWidget {
  final String status;
  final bool failed;
  final VoidCallback? onRetry;
  const MochiiLoadingScreen({
    super.key,
    this.status = 'Đang mở dữ liệu học tập…',
    this.failed = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artSize = math.min(
            300.0,
            math.min(constraints.maxWidth * 0.76, constraints.maxHeight * 0.46),
          );
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MochiiLoadingIllustration(size: artSize, animate: !failed),
                  const SizedBox(height: 24),
                  Text(
                    'Mochii',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Học cùng nhau, từng bước nhỏ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (failed && onRetry != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text('Thử lại'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
