import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';

Widget _app(DayStore s) => MaterialApp(
  theme: tinyTheme(Brightness.light),
  home: AppShell(store: s),
);

/// Adds a task on [day] and ticks it at noon that day.
Future<Task> _doneOn(DayStore s, DateTime day, [String title = 'Read']) async {
  final t = await s.addTask(title, day: day);
  await s.tick(t, now: DateTime(day.year, day.month, day.day, 12));
  return t;
}

void main() {
  setUp(() {
    Prefs.current = Prefs.memory();
    CatFigure.animate = false;
  });

  group('paws', () {
    test('one for each thing done, up to $pawsPerDay a day, '
        'and one for every 10 minutes of focus', () async {
      final s = DayStore.memory();
      final today = dayOf(DateTime.now());
      for (var i = 0; i < 10; i++) {
        await _doneOn(s, today, 'Task $i');
      }
      expect(s.paws, pawsPerDay);
      await _doneOn(s, today.subtract(const Duration(days: 1)));
      expect(s.paws, pawsPerDay + 1);
      await s.add(s.focus, '25', kind: 'study');
      // A session she left early doesn't count.
      await s.add(s.focus, '30', kind: 'study', quit: true);
      expect(s.paws, pawsPerDay + 1 + 2);
    });

    test('what is earned stays, and a new outfit goes straight on', () async {
      final s = DayStore.memory();
      final earned = <String>[];
      s.onEarned = (items) => earned.addAll(items.map((r) => r.id));
      final today = dayOf(DateTime.now());
      final tasks = [
        for (var i = 0; i < 3; i++) await _doneOn(s, today, 'Task $i'),
      ];
      expect(earned, ['cushion']);
      expect(s.room, {'cushion'});
      expect(s.nextItem?.id, 'rug');

      // Deleting the tasks takes nothing away.
      for (final t in tasks) {
        await s.removeTask(t);
      }
      expect(s.paws, 3);
      expect(s.room, {'cushion'});

      // 220 minutes of focus brings her to 25 paws: the rug, the lights
      // and the bow, which she puts on.
      await s.add(s.focus, '220', kind: 'study');
      expect(earned, ['cushion', 'rug', 'lights', 'bow']);
      expect(s.outfit, 'bow');
      await s.wear(null);
      expect(s.outfit, isNull);
      // Nothing she hasn't earned.
      await s.wear('crown');
      expect(s.outfit, isNull);
    });

    test('the room comes back from the file, without cheering again', () async {
      final dir = await Directory.systemTemp.createTemp('room');
      addTearDown(() => dir.delete(recursive: true));
      final s = await DayStore.load(dir);
      await s.add(s.focus, '90', kind: 'study');
      await s.wear('cushion');
      expect(s.room, {'cushion', 'rug'});

      final again = await DayStore.load(dir);
      final earned = <RoomItem>[];
      again.onEarned = earned.addAll;
      expect(again.room, {'cushion', 'rug'});
      expect(again.paws, 9);
      await again.save();
      expect(earned, isEmpty);
    });

    test('a backup made before rooms earns quietly when restored', () async {
      final s = DayStore.memory();
      final earned = <RoomItem>[];
      s.onEarned = earned.addAll;
      final today = dayOf(DateTime.now());
      await s.restore({
        'tasks': [
          for (var i = 0; i < 4; i++)
            Task(
              title: 'Old $i',
              day: today,
              done: true,
              doneAt: today.add(const Duration(hours: 9)),
            ).toJson(),
        ],
      });
      expect(s.room, {'cushion'});
      expect(earned, isEmpty);
    });
  });

  group('streak', () {
    // A Wednesday.
    final wed = DateTime(2026, 11, 11);
    DateTime day(int n) => DateTime(2026, 11, n);

    test('is 0 before anything is done', () {
      expect(DayStore.memory().streak(wed), 0);
    });

    test('counts days with something done, today too once it is', () async {
      final s = DayStore.memory();
      await _doneOn(s, day(9));
      await _doneOn(s, day(10));
      // Today isn't over, so not having done anything yet doesn't break it.
      expect(s.streak(wed), 2);
      await _doneOn(s, wed);
      expect(s.streak(wed), 3);
    });

    test('a focus session counts as a day done', () async {
      final s = DayStore.memory();
      s.focus.add(
        Entry(at: day(10).add(const Duration(hours: 16)), text: '20'),
      );
      expect(s.streak(wed), 1);
    });

    test(
      'two rest days a week keep it going; a third missed day ends it',
      () async {
        final s = DayStore.memory();
        // Last week: Thursday and Friday done, the weekend off.
        await _doneOn(s, day(5));
        await _doneOn(s, day(6));
        // This week: Monday and Tuesday done.
        await _doneOn(s, day(9));
        await _doneOn(s, day(10));
        expect(s.streak(wed), 4);
        expect(s.restDaysUsed(wed), 0);

        // The weekend before used both of last week's rest days, so the
        // missed Wednesday the 4th ends it there, even with the 3rd done.
        await _doneOn(s, day(3));
        expect(s.streak(wed), 4);
      },
    );

    test('rest days used are counted for this week', () async {
      final s = DayStore.memory();
      await _doneOn(s, day(6));
      // Monday and Tuesday of this week off.
      expect(s.restDaysUsed(wed), 2);
      expect(s.streak(wed), 1);
      // A third day off this week ends it.
      expect(s.streak(DateTime(2026, 11, 12)), 0);
    });
  });

  group('on Home', () {
    late DayStore store;

    setUp(() async {
      store = DayStore.memory();
      DayStore.current = store;
      await Prefs.current.setOnboarded();
    });

    testWidgets('the streak and the paws open their sheets', (tester) async {
      final today = dayOf(DateTime.now());
      await _doneOn(store, today.subtract(const Duration(days: 1)));
      await _doneOn(store, today);
      await tester.pumpWidget(_app(store));
      expect(find.text('2-day streak'), findsOneWidget);
      expect(find.text('2 paws · next: Cushion'), findsOneWidget);

      await tester.tap(find.byKey(const Key('streak-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('streak-sheet')), findsOneWidget);
      expect(find.byKey(const Key('rest-left')), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('paws-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-sheet')), findsOneWidget);
      expect(find.text('1 more paw for the cushion'), findsOneWidget);
    });

    testWidgets('earning something cheers, says what it is, and shows it', (
      tester,
    ) async {
      final today = dayOf(DateTime.now());
      await _doneOn(store, today, 'One');
      await _doneOn(store, today, 'Two');
      final third = await store.addTask('Three');
      await tester.pumpWidget(_app(store));
      final tick = find.byKey(Key('tick-${third.id}'));
      await tester.ensureVisible(tick);
      await tester.pumpAndSettle();
      await tester.tap(tick);
      await tester.pumpAndSettle();
      expect(find.text('New for Mochi: Cushion!'), findsOneWidget);
      await tester.tap(find.text('See'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('room-sheet')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('room-item-cushion')),
          matching: find.text('In the room'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an earned outfit is put on and taken off with a tap', (
      tester,
    ) async {
      await store.add(store.focus, '220', kind: 'study');
      await store.wear(null);
      await tester.pumpWidget(_app(store));
      await tester.tap(find.byKey(const Key('paws-chip')));
      await tester.pumpAndSettle();
      final bow = find.byKey(const Key('room-item-bow'));
      await tester.scrollUntilVisible(
        bow,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(bow);
      await tester.pumpAndSettle();
      expect(store.outfit, 'bow');
      expect(find.text('Wearing'), findsOneWidget);
      await tester.tap(bow);
      await tester.pumpAndSettle();
      expect(store.outfit, isNull);
      // One she hasn't earned does nothing.
      final crown = find.byKey(const Key('room-item-crown'));
      await tester.tap(crown);
      await tester.pumpAndSettle();
      expect(store.outfit, isNull);
    });
  });
}
