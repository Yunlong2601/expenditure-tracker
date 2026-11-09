import 'package:flutter/material.dart';

import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';

/// What one treat costs, for counting what's left in treats.
const bubbleTea = 4.0;

/// The cat's take on what's left: "That's about 3 bubble teas." Null when
/// nothing is left, since the card already says so kindly.
String? treatsLeft(double left) {
  final name = Prefs.current.catName;
  if (left <= 0.004) return null;
  final n = (left / bubbleTea).floor();
  if (n >= 1) {
    return tr(
      '$name: that’s about ${count(n, 'bubble tea')}.',
      '$name：大概还够买 $n 杯奶茶。',
    );
  }
  if (left >= 1) {
    return tr('$name: enough for a snack.', '$name：还够买个小零食。');
  }
  return tr('$name: just some coins left.', '$name：只剩一点零钱啦。');
}

/// Pictures for a savings goal, guessed from its name and changeable.
const goalPics = [
  '🎧',
  '🎮',
  '🎟️',
  '👟',
  '📚',
  '📱',
  '🚲',
  '🎁',
  '🧸',
  '🎨',
  '⭐',
];

/// A picture for a goal called [name]: headphones for AirPods, a ticket for
/// a concert. A star when nothing fits.
String goalPicFor(String name) {
  final n = name.toLowerCase();
  bool has(String p) => RegExp(p).hasMatch(n);
  if (has(r'headphone|earbud|airpod|earphone|耳机')) return '🎧';
  if (has(r'game|switch|ps5|playstation|xbox|nintendo|游戏')) return '🎮';
  if (has(r'concert|ticket|movie|show|演唱会|门票|电影')) return '🎟️';
  if (has(r'shoe|sneaker|nike|adidas|鞋')) return '👟';
  if (has(r'book|manga|comic|书|漫画')) return '📚';
  if (has(r'phone|ipad|tablet|手机|平板')) return '📱';
  if (has(r'bike|scooter|自行车|单车|滑板')) return '🚲';
  if (has(r'gift|present|birthday|礼物|生日')) return '🎁';
  if (has(r'plush|toy|squishmallow|jellycat|玩偶|公仔|玩具')) return '🧸';
  if (has(r'art|paint|marker|craft|画|颜料')) return '🎨';
  return '⭐';
}

/// A glass jar with coins in it, [fill] from empty (0) to full (1), and a
/// cat sitting on the lid when [mood] is given. [child] sits in the jar.
class Jar extends StatelessWidget {
  const Jar({
    super.key,
    required this.fill,
    this.size = const Size(64, 76),
    this.mood,
    this.catKey,
    this.child,
  });
  final double fill;
  final Size size;
  final CatMood? mood;
  final Key? catKey;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final still = MediaQuery.disableAnimationsOf(context);
    final cat = size.width * 0.62;
    final jar = TweenAnimationBuilder<double>(
      tween: Tween(end: fill.clamp(0.0, 1.0)),
      duration: still ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => CustomPaint(
        size: size,
        painter: JarPainter(fill: v, dark: dark),
        child: child,
      ),
      child: SizedBox.fromSize(
        size: size,
        child: child == null
            ? null
            : Padding(
                // The middle of the jar's body, below the lid.
                padding: EdgeInsets.only(top: size.height * 0.2),
                child: Center(child: child),
              ),
      ),
    );
    if (mood == null) return ExcludeSemantics(child: jar);
    return ExcludeSemantics(
      child: SizedBox(
        width: size.width,
        height: size.height + cat * 0.72,
        child: Stack(
          children: [
            Positioned(left: 0, right: 0, bottom: 0, child: jar),
            Positioned(
              top: 0,
              left: (size.width - cat) / 2,
              width: cat,
              height: cat,
              child: CustomPaint(
                key: catKey,
                painter: CatPainter(mood: mood!, paw: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JarPainter extends CustomPainter {
  const JarPainter({required this.fill, this.dark = false});
  final double fill;
  final bool dark;

  static const _coin = Color(0xFFE8B067);
  static const _coinEdge = Color(0xFFC98E3E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromLTRBR(
      w * 0.05,
      h * 0.2,
      w * 0.95,
      h,
      Radius.circular(w * 0.24),
    );
    final glass = dark ? const Color(0x33FFFFFF) : const Color(0x66FFFFFF);
    final edge = dark ? const Color(0x88FFFFFF) : const Color(0x55000000);
    final lid = dark ? const Color(0xFF8FCBBB) : const Color(0xFF7FB58A);

    // Neck and lid.
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.2,
        h * 0.1,
        w * 0.8,
        h * 0.24,
        Radius.circular(w * 0.06),
      ),
      Paint()..color = glass,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        w * 0.14,
        0,
        w * 0.86,
        h * 0.13,
        Radius.circular(w * 0.07),
      ),
      Paint()..color = lid,
    );

    // The glass, then the coins inside it.
    canvas.drawRRect(body, Paint()..color = glass);
    if (fill > 0) {
      canvas.save();
      canvas.clipRRect(body);
      final inner = body.height - w * 0.08;
      final top = h - w * 0.04 - inner * fill;
      final wave = Path()..moveTo(0, top);
      for (var i = 0; i <= 4; i++) {
        wave.quadraticBezierTo(
          w * (i + 0.5) / 4,
          top + (i.isEven ? -1 : 1) * h * 0.025,
          w * (i + 1) / 4,
          top,
        );
      }
      wave
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(wave, Paint()..color = _coin.withValues(alpha: 0.9));
      // A few coins, drawn only where the jar is full enough to hold them.
      final r = w * 0.09;
      for (final (x, y) in const [
        (0.3, 0.9),
        (0.62, 0.86),
        (0.45, 0.74),
        (0.72, 0.66),
        (0.28, 0.6),
        (0.55, 0.5),
      ]) {
        final c = Offset(w * x, h * y);
        if (c.dy - r < top) continue;
        canvas.drawCircle(c, r, Paint()..color = _coin);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = _coinEdge
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.025,
        );
      }
      canvas.restore();
    }

    // Outline and a shine down the left side.
    canvas.drawRRect(
      body,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(w * 0.18, h * 0.36),
      Offset(w * 0.18, h * 0.62),
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(JarPainter old) => old.fill != fill || old.dark != dark;
}

