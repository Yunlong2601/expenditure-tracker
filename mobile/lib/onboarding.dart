import 'package:flutter/material.dart';

import 'companion.dart';
import 'feel.dart';
import 'prefs.dart';
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
        const CatAvatar(size: 130),
        'Hi, I’m $name',
        'I’m here for the little things: a reminder when it’s time, company while you focus, and a chat about your day.',
      ),
      (
        const _SwipeHint(),
        'Swipe to find us',
        'On Home, swipe in from the left edge to chat with me. Swipe in from the right for Focus, Timeline and Notes.',
      ),
      (
        const CatFigure(size: 120),
        'Start with one small thing',
        'Tap + beside your list and add one thing for today. The Getting started list on Home walks you through the rest, one short part at a time.',
      ),
    ];
    final (art, title, body) = pages[_page];
    final last = _page == pages.length - 1;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.18),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Material(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(_page),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 140, child: Center(child: art)),
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
                              color: i == _page ? Palette.sage : Palette.line,
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
                        child: Text(last ? 'Let’s go' : 'Next'),
                      ),
                    ),
                    if (!last)
                      TextButton(
                        key: const Key('onboard-skip'),
                        onPressed: () => widget.onDone(false),
                        child: const Text(
                          'Skip',
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
    child: const Stack(
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
              Text('Chat', style: TextStyle(color: Palette.ink)),
              Text('Records', style: TextStyle(color: Palette.ink)),
            ],
          ),
        ),
      ],
    ),
  );
}
