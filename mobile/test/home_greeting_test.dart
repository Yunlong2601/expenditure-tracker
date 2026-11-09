@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/home_tab.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';

import 'stress/stress.dart';

void main() {
  // Real letter widths, so big text wraps as it does on a phone.
  setUpAll(() => loadFont(roboto()));

  setUp(() async {
    Prefs.current = Prefs.memory();
    await Prefs.current.setOnboarded();
    CatFigure.animate = false;
  });

  test('Mochi says a few words that suit the time of day', () async {
    expect(homeGreeting(DateTime(2026, 11, 9, 7)), 'Good morning!');
    expect(homeGreeting(DateTime(2026, 11, 9, 14)), 'You’ve got this!');
    expect(homeGreeting(DateTime(2026, 11, 9, 19)), 'How was today?');
    expect(homeGreeting(DateTime(2026, 11, 9, 23)), 'Rest is a task too.');
    expect(homeGreeting(DateTime(2026, 11, 9, 2)), 'Rest is a task too.');
    await Prefs.current.setLanguage('zh');
    expect(homeGreeting(DateTime(2026, 11, 9, 7)), '早上好！');
  });

  for (final (phone, text) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(393, 852), 1.0),
    (const Size(430, 932), 2.0),
  ]) {
    testWidgets('the hello never covers the date on the wall '
        '(${phone.width.toInt()} wide, text x$text)', (t) async {
      t.view.physicalSize = phone * 3;
      t.view.devicePixelRatio = 3;
      t.platformDispatcher.textScaleFactorTestValue = text;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final store = DayStore.memory();
      DayStore.current = store;
      await t.pumpWidget(
        MaterialApp(
          theme: tinyTheme(Brightness.light),
          home: AppShell(store: store),
        ),
      );
      await t.pump();
      final bubble = t.getRect(find.byKey(const Key('home-greeting')));
      // The wall calendar starts 70% of the way across.
      expect(bubble.right, lessThan(phone.width * 0.7));
      expect(bubble.top, greaterThanOrEqualTo(0));
    });
  }
}
