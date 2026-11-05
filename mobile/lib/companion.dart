import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'kitty.dart';

/// The cat's face in a soft round frame, as used in headers and chat.
class CatAvatar extends StatelessWidget {
  const CatAvatar({super.key, this.size = 56, this.mood = CatMood.happy});
  final double size;
  final CatMood mood;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0xFFFFF6DA), Color(0xFFFCE6B8)]),
    ),
    padding: EdgeInsets.all(size * 0.08),
    child: CustomPaint(painter: CatPainter(mood: mood, paw: false)),
  );
}

/// The cat on its own, waving, at any size.
class CatFigure extends StatefulWidget {
  const CatFigure({super.key, this.size = 120, this.mood = CatMood.happy});
  final double size;
  final CatMood mood;

  /// Off in widget tests, so pumpAndSettle can settle.
  static bool animate = true;

  @override
  State<CatFigure> createState() => _CatFigureState();
}

class _CatFigureState extends State<CatFigure>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    final still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (!still && CatFigure.animate) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final v = _c.value;
        final blink = v > 0.92 ? math.sin((v - 0.92) / 0.08 * math.pi) : 0.0;
        final wave = math.sin(v * math.pi * 4) * 0.25;
        return CustomPaint(
          painter: CatPainter(blink: blink, wave: wave, mood: widget.mood),
        );
      },
    ),
  );
}

/// A cozy little room drawn behind the cat: a window, a plant, a calendar
/// frame showing the weekday, and a desk. Drawn for this app.
class RoomScene extends StatelessWidget {
  const RoomScene({
    super.key,
    this.height = 260,
    this.catSize = 150,
    this.child,
  });
  final double height, catSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RoomPainter(
              DateFormat('EEE').format(DateTime.now()),
              dark,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.95),
            child: CatFigure(size: catSize),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.weekday, this.dark);
  final String weekday;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [const Color(0xFF2B2A25), const Color(0xFF22221E)]
            : [const Color(0xFFF7EFE3), const Color(0xFFF4EADB)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    // Window with a sun.
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.32, h * 0.42),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      win,
      Paint()..color = dark ? const Color(0xFF34465A) : const Color(0xFFCFE3F2),
    );
    canvas.drawCircle(
      Offset(w * 0.18, h * 0.3),
      w * 0.03,
      Paint()..color = const Color(0xFFF6CB7A),
    );
    final frame = Paint()
      ..color = const Color(0xFFE9DCC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(win, frame);
    canvas.drawLine(
      Offset(w * 0.24, h * 0.08),
      Offset(w * 0.24, h * 0.5),
      frame..strokeWidth = 4,
    );

    // Calendar frame with the weekday.
    final cal = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.7, h * 0.1, w * 0.16, h * 0.2),
      const Radius.circular(6),
    );
    canvas.drawRRect(cal, Paint()..color = const Color(0xFFFFF8EE));
    canvas.drawRRect(
      cal,
      Paint()
        ..color = const Color(0xFFD9C4A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: weekday,
        style: const TextStyle(
          color: Color(0xFF6B5A44),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(cal.center.dx - tp.width / 2, cal.center.dy - tp.height / 2),
    );

    // Desk.
    final desk = Paint()..color = const Color(0xFFE2C49E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.62, w * 0.36, h * 0.1),
        const Radius.circular(6),
      ),
      desk,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.66, h * 0.72, w * 0.28, h * 0.28),
      desk..color = const Color(0xFFD9B88E),
    );

    // Plants: a big leafy one on the left, a small pot on the desk.
    _plant(canvas, Offset(w * 0.06, h * 0.98), w * 0.2);
    _plant(canvas, Offset(w * 0.9, h * 0.62), w * 0.09);
  }

  void _plant(Canvas canvas, Offset base, double s) {
    final leaf = Paint()..color = const Color(0xFF7FA36F);
    final dark = Paint()..color = const Color(0xFF5E8A55);
    for (final (a, len, p) in [
      (-1.9, 1.0, leaf),
      (-1.3, 1.15, dark),
      (-0.8, 0.95, leaf),
      (-2.4, 0.8, dark),
    ]) {
      final tip = base + Offset(math.cos(a), math.sin(a)) * s * len;
      final mid = Offset.lerp(base, tip, 0.5)!;
      final n = Offset(-(tip - base).dy, (tip - base).dx) * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, base.dx, base.dy),
        p,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base, width: s * 0.5, height: s * 0.3),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE7A784),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.weekday != weekday || old.dark != dark;
}

/// A small tab stuck to the screen edge with a vertical label, like the
/// Chat and Records handles on Home.
class EdgeTab extends StatelessWidget {
  const EdgeTab({
    super.key,
    required this.label,
    required this.left,
    required this.onTap,
  });
  final String label;
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Open $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.horizontal(
              left: left ? Radius.zero : const Radius.circular(12),
              right: left ? const Radius.circular(12) : Radius.zero,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                left ? Icons.chevron_right : Icons.chevron_left,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(height: 6),
              RotatedBox(
                quarterTurns: left ? 3 : 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
