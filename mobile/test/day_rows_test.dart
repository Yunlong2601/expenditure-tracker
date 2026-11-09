import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/home_tab.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/theme.dart';

// The test font draws every letter and digit a full em wide, wider than
// any phone font, so a row that fits here fits on a phone.
void main() {
  setUp(() {
    Prefs.current = Prefs.memory();
  });

  Future<void> show(WidgetTester t, double text, Widget child) async {
    t.view.physicalSize = const Size(320, 568) * 3;
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = text;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            children: [child],
          ),
        ),
      ),
    );
  }

  for (final text in [1.0, 1.35, 2.0]) {
    testWidgets('two-digit days fit the week strip (text x$text)', (t) async {
      final start = DateTime(2026, 11, 23);
      await show(
        t,
        text,
        WeekStrip(start: start, picked: start, onPick: (_) {}, marks: {0, 6}),
      );
      expect(t.takeException(), isNull);
      for (final day in ['23', '26', '29']) {
        expect(find.text(day), findsOneWidget);
      }
    });
  }

  for (final lang in ['en', 'zh']) {
    for (final text in [1.0, 1.35, 2.0]) {
      testWidgets('a task with a time, repeat and reminder fits '
          '($lang, text x$text)', (t) async {
        await Prefs.current.setLanguage(lang);
        var timeTaps = 0;
        final task = Task(
          title: 'Finish the science project poster',
          day: DateTime(2026, 11, 9),
          minutes: 7 * 60 + 30,
          repeat: Repeat.weekdays,
          remind: true,
          private: true,
        );
        await show(
          t,
          text,
          TaskRow(
            task: task,
            onTick: () {},
            onTap: () {},
            onTime: () => timeTaps++,
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.byIcon(Icons.repeat), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none), findsOneWidget);
        await t.tap(find.byType(TextButton));
        expect(timeTaps, 1);
        if (text >= 1.5) {
          // At the biggest sizes the time goes under the title, so the
          // title keeps most of the row.
          final row = t.getRect(find.byType(TaskRow));
          final title = t.getRect(find.text(task.title));
          final time = t.getRect(find.byType(TextButton));
          expect(title.width, greaterThan(row.width * 0.5));
          expect(time.top, greaterThanOrEqualTo(title.bottom));
        }
      });
    }
  }
}
