import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kitty.dart';
import 'l10n.dart';

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
              weekdayShort(DateTime.now()),
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
      label: tr('Open $label', '打开$label'),
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

/// What the cat is doing in a header scene.
enum SceneKind {
  /// Reading a green book by the window (Me).
  reading,

  /// Studying at a desk with books and a big plant (Dashboard).
  studying,

  /// Writing notes, with a little sign and a mug (Records).
  writing,
}

/// The soft illustrated corner at the top right of Me, Dashboard and
/// Records, as in the wireframes: a bit of the cat's room that fades into
/// the page on the left. Drawn for this app with our own cat.
class SceneArt extends StatelessWidget {
  const SceneArt({
    super.key,
    required this.kind,
    this.width = 200,
    this.height = 150,
  });
  final SceneKind kind;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          colors: [Color(0x00000000), Color(0xFF000000)],
          stops: [0, 0.28],
        ).createShader(r),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: _ScenePainter(kind, dark, zh)),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.kind, this.dark, this.zh);
  final SceneKind kind;
  final bool dark, zh;

  static const _ink = Color(0xFF4A3B33);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // The room is drawn in a box of fixed shape at the bottom; anything
    // taller (the status bar on a phone) is more wall and window above it.
    final h = math.min(size.height, w * 0.74);
    final lift = size.height - h;
    final clip = RRect.fromRectAndCorners(
      Offset.zero & size,
      bottomLeft: const Radius.circular(40),
    );
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF2E2C27), const Color(0xFF26251F)]
              : [const Color(0xFFF8F0E4), const Color(0xFFF3E7D6)],
        ).createShader(Offset.zero & size),
    );

    // Window with a curtain, running up behind the status bar.
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, -8, w * 0.34, lift + h * 0.48 + 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      win,
      Paint()..color = dark ? const Color(0xFF3A4A5A) : const Color(0xFFDCEBF3),
    );
    canvas.drawRRect(
      win,
      Paint()
        ..color = dark ? const Color(0xFF4A4740) : const Color(0xFFEADFCD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final curtain = Path()
      ..moveTo(w * 0.2, 0)
      ..lineTo(w * 0.33, 0)
      ..quadraticBezierTo(w * 0.27, lift + h * 0.25, w * 0.31, lift + h * 0.52)
      ..lineTo(w * 0.2, lift + h * 0.52)
      ..close();
    canvas.drawPath(
      curtain,
      Paint()..color = dark ? const Color(0xFF4B463C) : const Color(0xFFFFF9EF),
    );

    canvas.translate(0, lift);
    switch (kind) {
      case SceneKind.reading:
        _frame(canvas, Rect.fromLTWH(w * 0.76, h * 0.06, w * 0.16, h * 0.2));
        _tulip(canvas, Offset(w * 0.84, h * 0.2), h * 0.05);
      case SceneKind.studying:
        _frame(canvas, Rect.fromLTWH(w * 0.78, h * 0.04, w * 0.15, h * 0.18));
        _hills(canvas, Rect.fromLTWH(w * 0.79, h * 0.06, w * 0.13, h * 0.14));
      case SceneKind.writing:
        _sign(canvas, Rect.fromLTWH(w * 0.8, h * 0.08, w * 0.17, h * 0.34));
        _plant(canvas, Offset(w * 0.12, h * 0.62), h * 0.2);
    }

    // Table top.
    final table = Rect.fromLTWH(0, h * 0.8, w, h * 0.2);
    canvas.drawRect(
      table,
      Paint()..color = dark ? const Color(0xFF4A3F33) : const Color(0xFFEFD8B8),
    );
    canvas.drawLine(
      Offset(0, table.top),
      Offset(w, table.top),
      Paint()
        ..color = dark ? const Color(0xFF5A4C3D) : const Color(0xFFE2C59C)
        ..strokeWidth = 2,
    );

    if (kind == SceneKind.studying) {
      _plant(canvas, Offset(w * 0.93, h * 0.82), h * 0.42);
    }

    // The cat.
    final cat = h * 0.74;
    final catLeft = w * 0.62 - cat / 2;
    canvas.save();
    canvas.translate(catLeft, h * 0.12);
    const CatPainter(paw: false).paint(canvas, Size(cat, cat));
    canvas.restore();
    final u = cat / 100;
    final cx = catLeft + 50 * u, base = h * 0.12 + 88 * u;

    switch (kind) {
      case SceneKind.reading:
        _book(canvas, Offset(cx, base), 30 * u, const Color(0xFF8DB580));
      case SceneKind.studying:
        _book(canvas, Offset(cx, base), 30 * u, const Color(0xFF9CC293));
        _openBook(canvas, Rect.fromLTWH(w * 0.08, h * 0.83, w * 0.26, h * 0.1));
      case SceneKind.writing:
        _paper(canvas, Offset(cx, base), 28 * u);
        _mug(canvas, Offset(w * 0.93, h * 0.82), h * 0.1);
    }
    canvas.restore();
  }

  void _frame(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFFBF4));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFDCC6A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _tulip(Canvas canvas, Offset c, double s) {
    canvas.drawLine(
      c,
      c + Offset(0, s * 1.6),
      Paint()
        ..color = const Color(0xFF7FA36F)
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 1.4, height: s * 1.6),
      Paint()..color = const Color(0xFFF2A2A8),
    );
  }

  void _hills(Canvas canvas, Rect r) {
    canvas.drawPath(
      Path()
        ..moveTo(r.left, r.bottom)
        ..quadraticBezierTo(r.left + r.width * 0.3, r.top, r.center.dx, r.center.dy + 2)
        ..quadraticBezierTo(r.right - r.width * 0.2, r.top + 2, r.right, r.bottom)
        ..close(),
      Paint()..color = const Color(0xFFA8CBA0),
    );
  }

  void _sign(Canvas canvas, Rect r) {
    canvas.drawLine(
      Offset(r.center.dx, 0),
      Offset(r.center.dx, r.top),
      Paint()
        ..color = const Color(0xFFBFA888)
        ..strokeWidth = 1.4,
    );
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFFBF4));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFDCC6A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: zh ? '记录\n让生活\n更清晰' : 'Write\nit\ndown',
        style: const TextStyle(
          color: _ink,
          fontSize: 7.5,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r.width - 4);
    tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.top + 4));
    _heart(canvas, Offset(r.center.dx, r.bottom - 5), 2.4);
  }

  void _heart(Canvas canvas, Offset c, double s) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + s)
        ..cubicTo(c.dx - s * 2, c.dy - s * 0.4, c.dx - s * 0.8, c.dy - s * 1.8, c.dx, c.dy - s * 0.6)
        ..cubicTo(c.dx + s * 0.8, c.dy - s * 1.8, c.dx + s * 2, c.dy - s * 0.4, c.dx, c.dy + s),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _plant(Canvas canvas, Offset base, double s) {
    final leaf = Paint()..color = const Color(0xFF8DB580);
    final darkLeaf = Paint()..color = const Color(0xFF6E9A63);
    for (final (a, len, p) in [
      (-1.95, 1.0, leaf),
      (-1.45, 1.1, darkLeaf),
      (-1.0, 0.9, leaf),
      (-2.45, 0.8, darkLeaf),
      (-0.6, 0.7, darkLeaf),
    ]) {
      final tip = base + Offset(math.cos(a), math.sin(a)) * s * len;
      final mid = Offset.lerp(base, tip, 0.5)!;
      final n = Offset(-(tip - base).dy, (tip - base).dx) * 0.25;
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
        Rect.fromCenter(center: base, width: s * 0.42, height: s * 0.3),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF1E6D6),
    );
  }

  /// An open book held up in front of the cat's chin.
  void _book(Canvas canvas, Offset c, double s, Color cover) {
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    for (final dir in [-1.0, 1.0]) {
      final page = Path()
        ..moveTo(c.dx, c.dy - s * 0.38)
        ..lineTo(c.dx + dir * s, c.dy - s * 0.48)
        ..lineTo(c.dx + dir * s * 0.98, c.dy + s * 0.3)
        ..lineTo(c.dx, c.dy + s * 0.36)
        ..close();
      canvas.drawPath(page, Paint()..color = cover);
      canvas.drawPath(page, line);
    }
    canvas.drawLine(
      Offset(c.dx, c.dy - s * 0.38),
      Offset(c.dx, c.dy + s * 0.36),
      line,
    );
  }

  void _openBook(Canvas canvas, Rect r) {
    final pages = Paint()..color = const Color(0xFFFFFBF2);
    final line = Paint()
      ..color = const Color(0xFFB9A27F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final p = Path()
      ..moveTo(r.left, r.top + r.height * 0.3)
      ..quadraticBezierTo(r.left + r.width * 0.25, r.top, r.center.dx, r.top + r.height * 0.25)
      ..quadraticBezierTo(r.right - r.width * 0.25, r.top, r.right, r.top + r.height * 0.3)
      ..lineTo(r.right, r.bottom)
      ..quadraticBezierTo(r.right - r.width * 0.25, r.bottom - r.height * 0.3, r.center.dx, r.bottom - r.height * 0.05)
      ..quadraticBezierTo(r.left + r.width * 0.25, r.bottom - r.height * 0.3, r.left, r.bottom)
      ..close();
    canvas.drawPath(p, pages);
    canvas.drawPath(p, line);
    canvas.drawLine(
      Offset(r.center.dx, r.top + r.height * 0.25),
      Offset(r.center.dx, r.bottom - r.height * 0.05),
      line,
    );
  }

  /// A sheet of paper and a pencil on the table.
  void _paper(Canvas canvas, Offset c, double s) {
    final sheet = Path()
      ..moveTo(c.dx - s, c.dy - s * 0.1)
      ..lineTo(c.dx + s * 0.8, c.dy - s * 0.25)
      ..lineTo(c.dx + s, c.dy + s * 0.45)
      ..lineTo(c.dx - s * 0.85, c.dy + s * 0.6)
      ..close();
    canvas.drawPath(sheet, Paint()..color = Colors.white);
    canvas.drawPath(
      sheet,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(c.dx - s * 0.1, c.dy - s * 0.9),
      Offset(c.dx + s * 0.35, c.dy + s * 0.15),
      Paint()
        ..color = const Color(0xFFF2C36B)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _mug(Canvas canvas, Offset base, double s) {
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(base.dx - s * 0.6, base.dy - s * 1.1, s * 1.2, s * 1.1),
      bottomLeft: Radius.circular(s * 0.35),
      bottomRight: Radius.circular(s * 0.35),
    );
    canvas.drawRRect(body, Paint()..color = Colors.white);
    final line = Paint()
      ..color = const Color(0xFFCDB89A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(body, line);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(base.dx + s * 0.62, base.dy - s * 0.6),
        width: s * 0.55,
        height: s * 0.5,
      ),
      -math.pi / 2,
      math.pi,
      false,
      line,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.kind != kind || old.dark != dark || old.zh != zh;
}
