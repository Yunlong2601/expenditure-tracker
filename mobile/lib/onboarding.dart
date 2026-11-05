import 'package:flutter/material.dart';

import 'companion.dart';
import 'feel.dart';
import 'kitty.dart';
import 'prefs.dart';
import 'l10n.dart';
import 'theme.dart';

/// Three welcome cards over Home (IMG_6793 to 6795). [onDone] gets true when
/// she taps Let's go, which adds the Getting started stack.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final ValueChanged<bool> onDone;

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = Prefs.current.catName;
    final pages = [
      (
        const CatAvatar(size: 106),
        tr('Hi, I’m $name', '嗨，我是 $name'),
        tr('I’m here for the little things: a reminder when it’s time, company while you focus, and a chat about your day.', '我会陪你做好生活里的小事：到点提醒你，专注时陪着你，还能和你聊聊今天。'),
      ),
      (
        const _SwipeHint(),
        tr('Swipe to find us', '滑一下就能找到我们'),
        tr('On Home, swipe in from the left edge to chat with me. Swipe in from the right for Focus, Timeline and Notes.', '在首页从左边缘滑进来就能和我聊天；从右边缘滑进来是专注、时间轴和笔记。'),
      ),
      (
        const _PeekCat(),
        tr('Start with one small thing', '从一件小事开始'),
        tr('Tap + beside your list and add one thing for today. The Getting started list on Home walks you through the rest, one short part at a time.', '点清单旁的 +，给今天加一件事。首页的新手清单会一小段一小段地带你熟悉其他功能。'),
      ),
    ];
    final (art, title, body) = pages[_page];
    final last = _page == pages.length - 1;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Material(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(_page),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 124, child: Center(child: art)),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(
                        color: Palette.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? Palette.sage
                                  : Palette.muted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('onboard-next'),
                        onPressed: () {
                          Feel.tap();
                          if (last) return widget.onDone(true);
                          setState(() => _page++);
                        },
                        child: Text(last ? tr('Let’s go', '开始吧') : tr('Next', '下一步')),
                      ),
                    ),
                    if (!last)
                      TextButton(
                        key: const Key('onboard-skip'),
                        onPressed: () => widget.onDone(false),
                        child: Text(
                          tr('Skip', '跳过'),
                          style: TextStyle(color: Palette.muted),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
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

/// The little phone with Chat and Records handles on its edges.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    height: 140,
    decoration: BoxDecoration(
      color: Palette.cream,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Palette.line, width: 2),
    ),
    child: Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.chevron_right, color: Palette.sage),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Icon(Icons.chevron_left, color: Palette.sage),
        ),
        Align(
          alignment: Alignment(0, 0.75),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(tr('Chat', '聊天'), style: TextStyle(color: Palette.ink)),
              Text(tr('Records', '记录'), style: TextStyle(color: Palette.ink)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The cat peeking over the edge of a desk, with a heart and a few sparkles
/// (IMG_6795). Drawn for this app.
class _PeekCat extends StatelessWidget {
  const _PeekCat();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 170,
      height: 124,
      child: CustomPaint(painter: _PeekPainter()),
    ),
  );
}

class _PeekPainter extends CustomPainter {
  const _PeekPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final desk = h * 0.78;
    // The cat, cut off by the desk so only its head shows.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, desk + 2));
    final cat = h * 0.98;
    canvas.translate((w - cat) / 2, desk - cat * 0.86);
    const CatPainter(paw: false).paint(canvas, Size(cat, cat));
    canvas.restore();
    // Desk edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, desk, w * 0.88, h * 0.12),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFF2D2B0),
    );
    // Two paws resting on the edge.
    final line = Paint()
      ..color = const Color(0xFF4A1F33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final dx in [-0.13, 0.13]) {
      final r = Rect.fromCenter(
        center: Offset(w * (0.5 + dx), desk + 2),
        width: w * 0.15,
        height: h * 0.14,
      );
      canvas.drawOval(r, Paint()..color = const Color(0xFFFFF5F8));
      canvas.drawOval(r, line);
    }
    // Sparkles on both sides and a heart at the top right.
    final ray = Paint()
      ..color = const Color(0xFFF6C46B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.12, h * 0.3), Offset(w * 0.18, h * 0.34), ray);
    canvas.drawLine(Offset(w * 0.17, h * 0.16), Offset(w * 0.2, h * 0.23), ray);
    canvas.drawLine(Offset(w * 0.84, h * 0.4), Offset(w * 0.9, h * 0.36), ray);
    final c = Offset(w * 0.84, h * 0.12);
    const s = 7.0;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + s)
        ..cubicTo(c.dx - s * 1.9, c.dy - s * 0.2, c.dx - s * 0.9, c.dy - s * 1.6, c.dx, c.dy - s * 0.5)
        ..cubicTo(c.dx + s * 0.9, c.dy - s * 1.6, c.dx + s * 1.9, c.dy - s * 0.2, c.dx, c.dy + s),
      Paint()..color = const Color(0xFFF58C7B),
    );
  }

  @override
  bool shouldRepaint(_PeekPainter old) => false;
}
