import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/home_tab.dart';
import 'package:spendsnap/me_tab.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';

Widget _app(DayStore s, {bool calm = false}) => MaterialApp(
  theme: tinyTheme(Brightness.light, calm: calm),
  home: AppShell(store: s),
);

void main() {
  late DayStore store;
  final today = dayOf(DateTime.now());

  setUp(() async {
    Prefs.current = Prefs.memory();
    await Prefs.current.setOnboarded();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
  });

  group('exams', () {
    test('are spotted by name, in English and Chinese', () {
      for (final exam in [
        'PSLE',
        'SA2',
        'Science test',
        'Mid-year exams',
        'EOY',
        '期末考试',
        '数学测验',
        '期中',
      ]) {
        expect(looksLikeExam(exam), isTrue, reason: exam);
      }
      for (final other in [
        'Trip to Bintan',
        'Mum’s birthday',
        '生日',
        'Met Mochi',
      ]) {
        expect(looksLikeExam(other), isFalse, reason: other);
      }
    });

    test('a switch she flips is kept, and old countdowns are guessed', () {
      final c = Countdown(title: 'Science test', date: today, exam: false);
      expect(Countdown.fromJson(c.toJson()).exam, isFalse);
      final old = Countdown.fromJson({
        'id': 'a',
        'title': 'PSLE',
        'date': today.toIso8601String(),
      });
      expect(old.exam, isTrue);
    });

    test('exam season is the last $examSeasonDays days before one', () async {
      await store.addCountdown('Trip', today.add(const Duration(days: 3)));
      final far = await store.addCountdown(
        'SA2',
        today.add(const Duration(days: 40)),
      );
      expect(store.examSoon(), isNull);
      far.date = today.add(const Duration(days: 30));
      expect(store.examSoon(), far);
      far.date = today.subtract(const Duration(days: 1));
      expect(store.examSoon(), isNull);
    });

    test('study time by subject covers the last seven days', () async {
      await store.add(store.focus, '30', kind: 'maths');
      await store.add(store.focus, '20', kind: 'science');
      await store.add(store.focus, '25', kind: 'maths');
      await store.add(store.focus, '40', kind: 'english', quit: true);
      store.focus.add(
        Entry(
          at: today.subtract(const Duration(days: 8)),
          text: '60',
          kind: 'science',
        ),
      );
      expect(store.focusBySubject(today).map((e) => '${e.key} ${e.value}'), [
        'maths 55',
        'science 20',
      ]);
    });
  });

  group('exam season on Home', () {
    testWidgets(
      'leads with the exam, today against the goal, and the subjects',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await store.addCountdown('PSLE', today.add(const Duration(days: 12)));
        await store.add(store.focus, '20', kind: 'maths');
        await tester.pumpWidget(_app(store));
        expect(find.byKey(const Key('exam-card')), findsOneWidget);
        expect(find.text('PSLE in 12 days'), findsOneWidget);
        expect(find.text('Today: 20 min of 45 min'), findsOneWidget);
        expect(find.text('Maths 20 min'), findsOneWidget);

        await tester.tap(find.byKey(const Key('exam-goal')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('goal-30')));
        await tester.pumpAndSettle();
        expect(Prefs.current.studyGoal, 30);
        expect(find.text('Today: 20 min of 30 min'), findsOneWidget);

        await tester.tap(find.byKey(const Key('exam-study')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('focus-clock')), findsOneWidget);
      },
    );

    testWidgets('not when the exam is more than a month away', (tester) async {
      await store.addCountdown('PSLE', today.add(const Duration(days: 45)));
      await tester.pumpWidget(_app(store));
      expect(find.byKey(const Key('exam-card')), findsNothing);
    });

    testWidgets('naming a countdown like an exam turns the switch on', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(HomeTab));
      addCountdown(ctx, store);
      await tester.pumpAndSettle();
      bool examOn() => tester
          .widget<SwitchListTile>(find.byKey(const Key('countdown-exam')))
          .value;
      expect(examOn(), isFalse);
      await tester.enterText(
        find.byKey(const Key('countdown-name')),
        'SA2 maths',
      );
      await tester.pump();
      expect(examOn(), isTrue);
      // She knows best: off stays off.
      await tester.tap(find.byKey(const Key('countdown-exam')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('countdown-save')));
      await tester.pumpAndSettle();
      expect(store.countdowns.single.exam, isFalse);
    });
  });

  group('the Calm look', () {
    testWidgets('is picked in Me', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: tinyTheme(Brightness.light),
          home: Scaffold(
            body: MeTab(onSettings: () {}, onThemeChanged: () {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('row-look')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('look-calm')));
      await tester.pumpAndSettle();
      expect(Prefs.current.calm, isTrue);
      expect(find.text('Calm'), findsOneWidget);
    });

    testWidgets('has a shorter room, a smaller cat and deeper colours', (
      tester,
    ) async {
      await tester.pumpWidget(_app(store, calm: true));
      final room = tester.widget<RoomScene>(find.byType(RoomScene));
      expect(room.height, 250);
      expect(room.catSize, 128);
      final ctx = tester.element(find.byType(HomeTab));
      expect(ctx.calm, isTrue);
      expect(ctx.green, CalmPalette.teal);

      // Back to Cosy, once the theme has faded across.
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(tester.widget<RoomScene>(find.byType(RoomScene)).height, 300);
    });
  });
}
