import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'feel.dart';

const _ink = Color(0xFF4A1F33);
const _fur = Color(0xFFFFF5F8);
const _blush = Color(0xFFFF8FC0);
const _paw = Color(0xFFFF69B4);

/// The app's cat: paw prints where you tap and a cat that cheers when you log
/// something. Sits above every screen and sheet. Without it (as in tests) the
/// app works the same, just without the cat.
class KittyLayer extends StatefulWidget {
  const KittyLayer({super.key, required this.child});
  final Widget child;

  static _KittyLayerState? _current;

  /// Pops the cat up from the bottom to celebrate a logged expense.
  static void cheer() => _current?._cheer();

  @override
  State<KittyLayer> createState() => _KittyLayerState();
}

class _KittyLayerState extends State<KittyLayer> {
  final _bursts = <(Key, Offset)>[];
  Key? _cheerKey;
  Offset? _downAt;
  var _n = 0;

  @override
  void initState() {
    super.initState();
    KittyLayer._current = this;
  }

  @override
  void dispose() {
    if (KittyLayer._current == this) KittyLayer._current = null;
    super.dispose();
  }

  void _cheer() => setState(() => _cheerKey = ValueKey(_n++));

  void _up(Offset at) {
    final from = _downAt;
    _downAt = null;
    // A tap, not a scroll.
    if (from == null || (at - from).distance > 12) return;
    setState(() => _bursts.add((ValueKey(_n++), at)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => _downAt = e.position,
          onPointerUp: (e) => _up(e.position),
          onPointerCancel: (_) => _downAt = null,
          child: widget.child,
        ),
        for (final (key, at) in _bursts)
          _PawBurst(key: key, at: at, onDone: () => setState(() => _bursts.removeWhere((b) => b.$1 == key))),
        if (_cheerKey != null) _Cheer(key: _cheerKey, onDone: () => setState(() => _cheerKey = null)),
      ],
    );
  }
}

/// Four little paw prints that hop outward from the finger and fade.
class _PawBurst extends StatefulWidget {
  const _PawBurst({super.key, required this.at, required this.onDone});
  final Offset at;
  final VoidCallback onDone;

  @override
  State<_PawBurst> createState() => _PawBurstState();
}

class _PawBurstState extends State<_PawBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))
    ..forward().whenComplete(widget.onDone);
  // Each burst tilts a little differently so repeated taps don't look stamped.
  late final double _spin = math.Random().nextDouble() * math.pi / 2;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: widget.at.dx - 60,
      top: widget.at.dy - 60,
      width: 120,
      height: 120,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _BurstPainter(_c.value, _spin, still)),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.spin, this.still);
  final double t, spin;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fade = (1 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    if (still) {
      paintPaw(canvas, c, 11, 0, _paw.withValues(alpha: fade * 0.9));
      return;
    }
    final out = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 4; i++) {
      final a = spin + i * math.pi / 2;
      final d = 10 + out * 34;
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      final s = 6 + 3 * math.sin(math.pi * math.min(1, t * 1.6));
      paintPaw(canvas, p, s, a + math.pi / 2, _paw.withValues(alpha: fade * 0.9));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// A paw print: a soft pad and four toe beans, toes pointing along [angle].
void paintPaw(Canvas canvas, Offset at, double r, double angle, Color color) {
  final p = Paint()..color = color;
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.35), width: r * 1.5, height: r * 1.2), p);
  for (final (x, y) in [(-0.85, -0.45), (-0.3, -0.95), (0.3, -0.95), (0.85, -0.45)]) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x * r, y * r), width: r * 0.55, height: r * 0.68), p);
  }
  canvas.restore();
}

/// The cat pops up from the bottom, blinks, waves, then ducks back down.
class _Cheer extends StatefulWidget {
  const _Cheer({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Cheer> createState() => _CheerState();
}

class _CheerState extends State<_Cheer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  var _mewed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      // Mew once the cat is fully up.
      if (!_mewed && _c.value > 0.16) {
        _mewed = true;
        Feel.play(Sound.mew);
      }
    });
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      right: 20,
      // Above the "Logged …" message.
      bottom: bottom + 64,
      width: 104,
      height: 104,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            // Up over the first 15%, down over the last 20%.
            final up = t < 0.15
                ? Curves.easeOutBack.transform(t / 0.15)
                : t > 0.8
                ? 1 - Curves.easeIn.transform((t - 0.8) / 0.2)
                : 1.0;
            final blink = t > 0.42 && t < 0.5 ? math.sin((t - 0.42) / 0.08 * math.pi) : 0.0;
            final wave = still ? 0.0 : math.sin(((t - 0.18) / 0.55).clamp(0.0, 1.0) * math.pi * 4) * 0.45;
            final face = CustomPaint(
              painter: CatPainter(blink: blink, wave: wave),
            );
            if (still) return Opacity(opacity: up.clamp(0.0, 1.0), child: face);
            return ClipRect(
              child: Transform.translate(offset: Offset(0, (1 - up) * 110), child: face),
            );
          },
        ),
      ),
    );
  }
}

/// How the cat feels about her pocket money.
enum CatMood { happy, worried, sad, delighted }

/// A round, original cat face. [blink] closes the eyes (0 open, 1 shut),
/// [wave] tilts the raised paw, and [asleep] draws shut eyes with no paw.
class CatPainter extends CustomPainter {
  const CatPainter({this.blink = 0, this.wave = 0, this.asleep = false, this.mood = CatMood.happy, this.paw = true});
  final double blink, wave;
  final bool asleep;
  final CatMood mood;

  /// Draw the raised paw.
  final bool paw;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()..color = _fur;
    final pink = Paint()..color = _blush;

    // Ears.
    for (final dir in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(50 + dir * 14, 34)
        ..quadraticBezierTo(50 + dir * 30, 6, 50 + dir * 36, 12)
        ..quadraticBezierTo(50 + dir * 40, 30, 50 + dir * 38, 44)
        ..close();
      canvas.drawPath(ear, fur);
      canvas.drawPath(ear, line);
      final inner = Path()
        ..moveTo(50 + dir * 20, 32)
        ..quadraticBezierTo(50 + dir * 30, 16, 50 + dir * 33, 19)
        ..quadraticBezierTo(50 + dir * 35, 30, 50 + dir * 34, 38)
        ..close();
      canvas.drawPath(inner, pink);
    }

    // Head.
    final head = Rect.fromCenter(center: const Offset(50, 58), width: 80, height: 66);
    canvas.drawOval(head, fur);
    canvas.drawOval(head, line);

    // Cheeks.
    pink.color = _blush.withValues(alpha: 0.55);
    canvas.drawOval(Rect.fromCenter(center: const Offset(27, 66), width: 13, height: 8), pink);
    canvas.drawOval(Rect.fromCenter(center: const Offset(73, 66), width: 13, height: 8), pink);

    // Eyes.
    final eye = Paint()..color = _ink;
    for (final x in [36.0, 64.0]) {
      if (mood == CatMood.delighted && !asleep) {
        // Happy closed eyes: little upside-down U's.
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 57), width: 11, height: 9),
          math.pi + 0.2,
          math.pi - 0.4,
          false,
          line,
        );
      } else if (asleep || blink > 0.85) {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, 54), width: 11, height: 8), 0.2, math.pi - 0.4, false, line);
      } else {
        final h = 11 * (1 - blink);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, 55), width: 8, height: h), eye);
        if (blink < 0.4) canvas.drawCircle(Offset(x + 1.5, 52.5), 1.6, Paint()..color = Colors.white);
      }
    }

    // Nose and mouth.
    canvas.drawPath(
      Path()
        ..moveTo(46.5, 63)
        ..lineTo(53.5, 63)
        ..lineTo(50, 67)
        ..close(),
      Paint()..color = _paw,
    );
    final mouth = switch (mood) {
      CatMood.happy || CatMood.delighted =>
        Path()
          ..moveTo(50, 67)
          ..quadraticBezierTo(48, 72, 44, 70.5)
          ..moveTo(50, 67)
          ..quadraticBezierTo(52, 72, 56, 70.5),
      CatMood.worried => Path()..addOval(Rect.fromCenter(center: const Offset(50, 71), width: 5, height: 5.5)),
      CatMood.sad =>
        Path()
          ..moveTo(45, 73)
          ..quadraticBezierTo(50, 68.5, 55, 73),
    };
    canvas.drawPath(mouth, line..strokeWidth = 2);
    if ((mood == CatMood.worried || mood == CatMood.sad) && !asleep) {
      // Brows tipped up in the middle.
      canvas.drawLine(const Offset(30, 45), const Offset(40, 42.5), line);
      canvas.drawLine(const Offset(70, 45), const Offset(60, 42.5), line);
    }
    if (mood == CatMood.sad && !asleep) {
      // One small tear.
      final tear = Path()
        ..moveTo(29, 58)
        ..quadraticBezierTo(26, 63, 29, 64.5)
        ..quadraticBezierTo(32, 63, 29, 58);
      canvas.drawPath(tear, Paint()..color = const Color(0xFF8FD3FF));
    }

    // Whiskers.
    line.strokeWidth = 1.6;
    for (final dir in [-1.0, 1.0]) {
      for (final (y, tilt) in [(62.0, -4.0), (67.0, 0.0), (72.0, 4.0)]) {
        canvas.drawLine(Offset(50 + dir * 22, y), Offset(50 + dir * 40, y + tilt), line);
      }
    }

    if (!asleep && paw) {
      // The waving paw, raised at the lower right.
      canvas.save();
      canvas.translate(84, 82);
      canvas.rotate(wave);
      final paw = Rect.fromCenter(center: const Offset(0, -8), width: 20, height: 22);
      canvas.drawOval(paw, fur);
      canvas.drawOval(paw, line..strokeWidth = 2.4);
      paintPaw(canvas, const Offset(0, -7), 4.2, 0, _blush);
      canvas.restore();
    } else if (asleep) {
      // A few drifting z's.
      final z = TextPainter(
        text: const TextSpan(
          text: 'z z',
          style: TextStyle(color: _blush, fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      z.paint(canvas, const Offset(90, -2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CatPainter old) =>
      old.blink != blink || old.wave != wave || old.asleep != asleep || old.mood != mood || old.paw != paw;
}
