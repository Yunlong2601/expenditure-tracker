import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'kitty.dart';
import 'l10n.dart';
import 'theme.dart';

/// The cat's face in a soft round frame, as used in headers and chat.
class CatAvatar extends StatelessWidget {
  const CatAvatar({
    super.key,
    this.size = 56,
    this.mood = CatMood.happy,
    this.star = true,
  });
  final double size;
  final CatMood mood;

  /// The cat hugs its little star, as in every wireframe avatar.
  final bool star;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0xFFFFF6DA), Color(0xFFFCE6B8)]),
    ),
    padding: EdgeInsets.all(size * 0.08),
    child: CustomPaint(painter: CatPainter(mood: mood, paw: false, star: star)),
  );
}

/// The cat on its own, waving, at any size.
class CatFigure extends StatefulWidget {
  const CatFigure({super.key, this.size = 120, this.mood = CatMood.happy, this.outfit});
  final double size;
  final CatMood mood;

  /// What she has on, earned in her room.
  final String? outfit;

  /// Off in widget tests, so pumpAndSettle can settle. (A hop still plays:
  /// it ends by itself.)
  static bool animate = true;

  /// Counts hops; every cat on screen hops when it goes up.
  static final hops = ValueNotifier<int>(0);

  /// Makes the cat hop for joy, as when a task is ticked. Not with Reduce
  /// Motion on.
  static void hop() => hops.value++;

  @override
  State<CatFigure> createState() => _CatFigureState();
}

class _CatFigureState extends State<CatFigure> with TickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
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
    CatFigure.hops.addListener(_onHop);
  }

  void _onHop() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _hop.forward(from: 0);
  }

  @override
  void dispose() {
    CatFigure.hops.removeListener(_onHop);
    _c.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: Listenable.merge([_c, _hop]),
      builder: (_, _) {
        final v = _c.value;
        final blink = v > 0.92 ? math.sin((v - 0.92) / 0.08 * math.pi) : 0.0;
        final wave = math.sin(v * math.pi * 4) * 0.25;
        // Up and back down in one arc, with a little squash on landing.
        final h = _hop.value;
        final up = 4 * h * (1 - h);
        final squash = h > 0.85 ? math.sin((h - 0.85) / 0.15 * math.pi) * 0.06 : 0.0;
        return Transform.translate(
          offset: Offset(0, -widget.size * 0.14 * up),
          child: Transform.scale(
            scaleX: 1 + squash,
            scaleY: 1 - squash,
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              painter: CatPainter(blink: blink, wave: wave, mood: widget.mood, outfit: widget.outfit),
            ),
          ),
        );
      },
    ),
  );
}

/// A cozy little room drawn behind the cat: a window, a plant, a wall
/// calendar showing today's date, and a desk. Drawn for this app.
class RoomScene extends StatelessWidget {
  const RoomScene({
    super.key,
    this.height = 260,
    this.catSize = 150,
    this.items = const {},
    this.outfit,
    this.child,
  });
  final double height, catSize;

  /// What she has earned for the room, by [RoomItem.id].
  final Set<String> items;

  /// What Mochi has on.
  final String? outfit;
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
              DateTime.now().day,
              dark,
              items,
              calm: context.calm,
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.95),
            child: CatFigure(size: catSize, outfit: outfit),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Where each earned thing goes in a room [w] wide and [h] tall.
Rect roomItemSpot(String id, double w, double h) => switch (id) {
  'rug' => Rect.fromCenter(center: Offset(w * 0.5, h * 0.93), width: w * 0.66, height: h * 0.12),
  'cushion' => Rect.fromCenter(center: Offset(w * 0.5, h * 0.9), width: w * 0.38, height: h * 0.12),
  'lights' => Rect.fromLTWH(w * 0.44, h * 0.34, w * 0.54, h * 0.12),
  'poster' => Rect.fromLTWH(w * 0.47, h * 0.1, w * 0.16, h * 0.22),
  'shelf' => Rect.fromLTWH(w * 0.08, h * 0.53, w * 0.3, h * 0.13),
  'fish' => Rect.fromLTWH(w * 0.63, h * 0.62 - w * 0.12, w * 0.12, w * 0.12),
  'lamp' => Rect.fromLTWH(w * 0.76, h * 0.62 - w * 0.15, w * 0.1, w * 0.15),
  _ => Rect.zero,
};

/// Draws one thing for the room, by [RoomItem.id], to fill [r]: in the room
/// itself and on its card in Mochi's room.
void paintRoomItem(Canvas canvas, String id, Rect r) {
  final l = r.left, t = r.top, w = r.width, h = r.height;
  final edge = Paint()
    ..color = const Color(0x33000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  switch (id) {
    case 'rug':
      canvas.drawOval(r, Paint()..color = const Color(0xFFB9D3C4));
      canvas.drawOval(r.deflate(w * 0.06), Paint()..color = const Color(0xFFE3EFE6));
      canvas.drawOval(
        r.deflate(w * 0.14),
        Paint()
          ..color = const Color(0xFFB9D3C4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, h * 0.06),
      );
    case 'cushion':
      final c = Rect.fromLTWH(l, t + h * 0.25, w, h * 0.75);
      canvas.drawOval(c, Paint()..color = const Color(0xFFE9A7A0));
      canvas.drawOval(
        Rect.fromLTWH(l + w * 0.1, t + h * 0.25, w * 0.8, h * 0.45),
        Paint()..color = const Color(0xFFF2C2BC),
      );
      canvas.drawCircle(Offset(l + w / 2, t + h * 0.5), math.max(1.5, h * 0.06), Paint()..color = const Color(0xFFD98C85));
    case 'lights':
      final from = Offset(l, t + h * 0.15), to = Offset(r.right, t);
      final sag = Offset(l + w / 2, t + h * 0.95);
      final wire = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(sag.dx, sag.dy, to.dx, to.dy);
      canvas.drawPath(
        wire,
        Paint()
          ..color = const Color(0xFF8C7B66)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      const bulbs = [Color(0xFFF6CB7A), Color(0xFFF2A0B6), Color(0xFF8FD3C9), Color(0xFFF4A261)];
      final bulb = math.max(2.5, math.min(w, h * 4) * 0.022);
      for (var i = 1; i < 8; i++) {
        final k = i / 8;
        final p = Offset(
          (1 - k) * (1 - k) * from.dx + 2 * (1 - k) * k * sag.dx + k * k * to.dx,
          (1 - k) * (1 - k) * from.dy + 2 * (1 - k) * k * sag.dy + k * k * to.dy,
        );
        final c = bulbs[i % bulbs.length];
        canvas.drawCircle(p + Offset(0, bulb), bulb * 2.2, Paint()..color = c.withValues(alpha: 0.25));
        canvas.drawCircle(p + Offset(0, bulb), bulb, Paint()..color = c);
      }
    case 'poster':
      final card = RRect.fromRectAndRadius(r, Radius.circular(w * 0.08));
      canvas.drawRRect(card, Paint()..color = const Color(0xFFFFF4DC));
      canvas.drawRRect(card, edge);
      final star = Path();
      final c = r.center, big = math.min(w, h) * 0.36;
      for (var i = 0; i < 10; i++) {
        final rr = i.isEven ? big : big * 0.45;
        final a = -math.pi / 2 + i * math.pi / 5;
        final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(star..close(), Paint()..color = const Color(0xFFF6CB5A));
      // Tape at the top corners.
      final tape = Paint()..color = const Color(0x66C9B79C);
      canvas.drawRect(Rect.fromCenter(center: Offset(l + w * 0.15, t), width: w * 0.3, height: h * 0.08), tape);
      canvas.drawRect(Rect.fromCenter(center: Offset(r.right - w * 0.15, t), width: w * 0.3, height: h * 0.08), tape);
    case 'shelf':
      final plank = Rect.fromLTWH(l, t + h * 0.82, w, h * 0.18);
      canvas.drawRRect(RRect.fromRectAndRadius(plank, const Radius.circular(2)), Paint()..color = const Color(0xFFC9A57A));
      const books = [
        (0.06, 0.72, Color(0xFF8EA7D8)),
        (0.19, 0.6, Color(0xFFEB8A5A)),
        (0.3, 0.78, Color(0xFF7FB58A)),
        (0.43, 0.55, Color(0xFFF6CB7A)),
        (0.54, 0.68, Color(0xFFF2A0B6)),
      ];
      for (final (x, tall, c) in books) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(l + w * x, t + h * (0.82 - tall), w * 0.1, h * tall),
            const Radius.circular(1.5),
          ),
          Paint()..color = c,
        );
      }
      // A tiny pot at the end of the shelf.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(l + w * 0.76, t + h * 0.56, w * 0.14, h * 0.26), const Radius.circular(2)),
        Paint()..color = const Color(0xFFE7A784),
      );
      canvas.drawCircle(Offset(l + w * 0.83, t + h * 0.46), w * 0.07, Paint()..color = const Color(0xFF7FA36F));
    case 'fish':
      final bowl = Rect.fromLTWH(l, t + h * 0.08, w, h * 0.92);
      canvas.drawOval(bowl, Paint()..color = const Color(0xFFCFE8F2));
      canvas.save();
      canvas.clipPath(Path()..addOval(bowl));
      canvas.drawRect(Rect.fromLTWH(l, t + h * 0.4, w, h), Paint()..color = const Color(0xFF9CCFE3));
      canvas.restore();
      canvas.drawOval(bowl, edge);
      canvas.drawLine(Offset(l + w * 0.2, t + h * 0.1), Offset(r.right - w * 0.2, t + h * 0.1), edge..strokeWidth = 2.5);
      final fish = Paint()..color = const Color(0xFFF4A261);
      final body = Rect.fromCenter(center: Offset(l + w * 0.46, t + h * 0.64), width: w * 0.34, height: h * 0.2);
      canvas.drawOval(body, fish);
      canvas.drawPath(
        Path()
          ..moveTo(body.right - w * 0.04, body.center.dy)
          ..lineTo(body.right + w * 0.12, body.top)
          ..lineTo(body.right + w * 0.12, body.bottom)
          ..close(),
        fish,
      );
      canvas.drawCircle(Offset(body.left + w * 0.08, body.center.dy - h * 0.02), math.max(1, w * 0.025), Paint()..color = _roomInk);
    case 'lamp':
      final warm = Paint()..color = const Color(0x33F6CB7A);
      canvas.drawPath(
        Path()
          ..moveTo(l + w * 0.55, t + h * 0.3)
          ..lineTo(l - w * 0.2, r.bottom)
          ..lineTo(r.right + w * 0.4, r.bottom)
          ..close(),
        warm,
      );
      final metal = Paint()
        ..color = const Color(0xFF6FA39B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * 0.1)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(l + w * 0.35, r.bottom - h * 0.04), Offset(l + w * 0.25, t + h * 0.45), metal);
      canvas.drawLine(Offset(l + w * 0.25, t + h * 0.45), Offset(l + w * 0.6, t + h * 0.18), metal);
      canvas.drawOval(
        Rect.fromLTWH(l, r.bottom - h * 0.1, w * 0.7, h * 0.1),
        Paint()..color = const Color(0xFF6FA39B),
      );
      canvas.drawPath(
        Path()
          ..moveTo(l + w * 0.4, t + h * 0.06)
          ..lineTo(l + w * 0.85, t)
          ..lineTo(r.right + w * 0.1, t + h * 0.36)
          ..lineTo(l + w * 0.4, t + h * 0.36)
          ..close(),
        Paint()..color = const Color(0xFF8FC7BE),
      );
  }
}

const _roomInk = Color(0xFF3B3A36);

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.weekday, this.date, this.dark, this.items, {this.calm = false});
  final String weekday;

  /// Today's day of the month, big on the wall calendar.
  final int date;
  final bool dark;
  final Set<String> items;

  /// The Calm look: cool plain walls, no sun and no big plant.
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final wall = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: switch ((calm, dark)) {
          (true, true) => [const Color(0xFF22272A), const Color(0xFF1C2023)],
          (true, false) => [const Color(0xFFEEF1EF), const Color(0xFFE6EAE7)],
          (false, true) => [const Color(0xFF2B2A25), const Color(0xFF22221E)],
          (false, false) => [const Color(0xFFF7EFE3), const Color(0xFFF4EADB)],
        },
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    // Window with a sun.
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.32, h * 0.42),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      win,
      Paint()..color = dark ? const Color(0xFF34465A) : (calm ? const Color(0xFFD9E6EC) : const Color(0xFFCFE3F2)),
    );
    if (!calm) {
      canvas.drawCircle(
        Offset(w * 0.18, h * 0.3),
        w * 0.03,
        Paint()..color = const Color(0xFFF6CB7A),
      );
    }
    final frame = Paint()
      ..color = calm ? (dark ? const Color(0xFF3A4247) : const Color(0xFFD3D8D5)) : const Color(0xFFE9DCC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(win, frame);
    canvas.drawLine(
      Offset(w * 0.24, h * 0.08),
      Offset(w * 0.24, h * 0.5),
      frame..strokeWidth = 4,
    );

    // A wall calendar with today's date: the weekday on a red strip and
    // the day big underneath, readable at a glance.
    final calRect = Rect.fromLTWH(w * 0.7, h * 0.1, w * 0.16, h * 0.2);
    final cal = RRect.fromRectAndRadius(calRect, const Radius.circular(6));
    canvas.drawRRect(cal, Paint()..color = const Color(0xFFFFF8EE));
    final strip = calRect.height * 0.32;
    canvas.save();
    canvas.clipRRect(cal);
    canvas.drawRect(
      Rect.fromLTWH(calRect.left, calRect.top, calRect.width, strip),
      Paint()..color = const Color(0xFFD9645A),
    );
    canvas.restore();
    canvas.drawRRect(
      cal,
      Paint()
        ..color = const Color(0xFFD9C4A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    void centred(String text, double size, Color color, double top, double bottom) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, height: 1),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      // Shrinks to fit a narrow calendar rather than spilling over its edge.
      final fit = math.min(1.0, (calRect.width - 8) / math.max(1, tp.width));
      canvas.save();
      canvas.translate(calRect.center.dx, (top + bottom) / 2);
      canvas.scale(fit);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    centred(weekday, math.min(12, strip * 0.62), Colors.white, calRect.top, calRect.top + strip);
    centred('$date', math.min(30, (calRect.height - strip) * 0.62), const Color(0xFF5A4A36), calRect.top + strip, calRect.bottom);

    // Desk.
    final desk = Paint()..color = calm ? const Color(0xFFC8B497) : const Color(0xFFE2C49E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, h * 0.62, w * 0.36, h * 0.1),
        const Radius.circular(6),
      ),
      desk,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.66, h * 0.72, w * 0.28, h * 0.28),
      desk..color = calm ? const Color(0xFFB9A585) : const Color(0xFFD9B88E),
    );

    // What she has earned: the rug and cushion on the floor first, so the
    // plant stands in front of them.
    for (final id in ['poster', 'shelf', 'lights', 'rug', 'cushion', 'fish', 'lamp']) {
      if (items.contains(id)) paintRoomItem(canvas, id, roomItemSpot(id, w, h));
    }

    // Plants: a big leafy one on the left (not in Calm), a small pot on the desk.
    if (!calm) _plant(canvas, Offset(w * 0.06, h * 0.98), w * 0.2);
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
      old.weekday != weekday ||
      old.date != date ||
      old.dark != dark ||
      old.calm != calm ||
      !setEquals(old.items, items);
}

/// A small tab stuck to the screen edge with a vertical label, like the
/// Chat and Records handles on Home.
class EdgeTab extends StatelessWidget {
  const EdgeTab({
    super.key,
    required this.label,
    required this.icon,
    required this.left,
    required this.onTap,
  });
  final String label;

  /// Shown instead of the label: words turned on their side are hard to
  /// read, Chinese most of all. Screen readers and a long press say [label].
  final IconData icon;
  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tr('Open $label', '打开$label'),
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          // The tab looks 30 points wide, but a finger gets 48: Apple asks
          // for 44 and Android for 48.
          child: SizedBox(
            width: 48,
            child: Align(
              alignment: left ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: 30,
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                    Icon(icon, size: 18, color: cs.primary),
                    const SizedBox(height: 2),
                    Icon(
                      left ? Icons.chevron_right : Icons.chevron_left,
                      size: 16,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
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
