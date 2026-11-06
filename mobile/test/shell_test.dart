import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/records.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';

Widget _app(DayStore s) => MaterialApp(
  theme: tinyTheme(Brightness.light),
  home: AppShell(store: s),
);

void main() {
  late DayStore store;

  setUp(() {
    Prefs.current = Prefs.memory();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
  });

  testWidgets('the welcome cards end with the getting started stack', (
    tester,
  ) async {
    await tester.pumpWidget(_app(store));
    expect(find.text('Hi, I’m Mochi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboard-next')));
    await tester.pumpAndSettle();
    expect(find.text('Swipe to find us'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboard-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboard-next')));
    await tester.pumpAndSettle();
    expect(Prefs.current.onboarded, isTrue);
    expect(find.text(DayStore.gettingStartedSteps.first), findsOneWidget);
  });

  testWidgets('+ adds a task for today and the circle ticks it', (
    tester,
  ) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title')),
      'Water the plant',
    );
    await tester.tap(find.byKey(const Key('sheet-Save')));
    await tester.pumpAndSettle();
    expect(find.text('Water the plant'), findsOneWidget);
    final t = store.tasks.single;
    await tester.tap(find.byKey(Key('tick-${t.id}')));
    await tester.pumpAndSettle();
    expect(t.done, isTrue);
  });

  testWidgets('the mood diary records a mood', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('quick-mood')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mood-calm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sheet-Record')));
    await tester.pumpAndSettle();
    expect(store.moodOf(DateTime.now()), Mood.calm);
  });

  testWidgets('the tabs show Dashboard and Me', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('Every day of effort, recorded'), findsOneWidget);
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('My preferences'), findsOneWidget);
  });

  testWidgets('Me → Language switches the app to Chinese and back', (
    tester,
  ) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    expect(find.text('Pet'), findsOneWidget);
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('row-language')));
    await tester.tap(find.byKey(const Key('row-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lang-zh')));
    await tester.pumpAndSettle();
    expect(Prefs.current.language, 'zh');
    expect(find.text('宠物'), findsOneWidget);
    expect(find.text('我的偏好'), findsOneWidget);
    expect(find.text('账号与安全'), findsOneWidget);
    await tester.tap(find.byKey(const Key('row-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pumpAndSettle();
    expect(find.text('Pet'), findsOneWidget);
    expect(find.text('Account & security'), findsOneWidget);
  });

  testWidgets('the + on the picked calendar day plans that day', (
    tester,
  ) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('week-today-dot')), findsOneWidget);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final cell = find.byKey(Key('day-${tomorrow.month}-${tomorrow.day}'));
    // The month calendar stays folded until the week card is tapped.
    expect(cell, findsNothing);
    await tester.tap(find.byKey(const Key('calendar-handle')));
    await tester.pumpAndSettle();
    // The calendar sits below the fold, so scroll the Dashboard to it.
    await tester.scrollUntilVisible(
      cell,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('dashboard-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(cell.first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('day-add')));
    await tester.tap(find.byKey(const Key('day-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title')), 'Pack bag');
    await tester.tap(find.byKey(const Key('task-private')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sheet-Save')));
    await tester.pumpAndSettle();
    final t = store.tasks.single;
    expect(t.title, 'Pack bag');
    expect(t.day, dayOf(tomorrow));
    expect(t.private, isTrue);
  });

  testWidgets('the Dashboard shows countdowns first and folds the calendar', (
    tester,
  ) async {
    await Prefs.current.setOnboarded();
    await store.addCountdown('Exam', DateTime.now().add(const Duration(days: 9)));
    await tester.pumpWidget(_app(store));
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    // Countdowns sit above the day's review, with the next one in view.
    final countdowns = tester.getTopLeft(find.text('Countdowns')).dy;
    expect(countdowns, lessThan(tester.getTopLeft(find.text('Today’s review')).dy));
    expect(find.text('Exam'), findsOneWidget);
    // Tapping the week card opens the month calendar, and again folds it.
    final today = DateTime.now();
    final cell = find.byKey(Key('day-${today.month}-${today.day}'));
    expect(cell, findsNothing);
    await tester.tap(find.byKey(const Key('calendar-handle')));
    await tester.pumpAndSettle();
    expect(cell, findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-handle')));
    await tester.pumpAndSettle();
    expect(cell, findsNothing);
  });

  testWidgets('the Records tab opens on Timeline', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('edge-records')));
    await tester.pumpAndSettle();
    expect(find.text('What are you doing now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-0')));
    await tester.pumpAndSettle();
    expect(store.timeline.single.text, 'Study');
  });


  testWidgets('Schedule shows the week and + plans the picked day', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('tab-schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-week')), findsOneWidget);
    // Another day of this week: tomorrow, or Monday on a Sunday.
    final today = DateTime.now();
    final i = today.weekday % 7;
    final picked = DateTime(today.year, today.month, today.day - (today.weekday - 1) + i);
    await tester.tap(find.byKey(Key('schedule-day-$i')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title')), 'Library books');
    await tester.tap(find.byKey(const Key('sheet-Save')));
    await tester.pumpAndSettle();
    expect(store.tasks.single.day, dayOf(picked));
    expect(find.text('Library books'), findsOneWidget);
    // Back to Today, where it isn't.
    await tester.tap(find.byKey(const Key('tab-today')));
    await tester.pumpAndSettle();
    expect(find.text('Library books'), findsNothing);
  });

  testWidgets('a task set to repeat every day comes back tomorrow', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title')), 'Feed the fish');
    await tester.tap(find.byKey(const Key('repeat-daily')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sheet-Save')));
    await tester.pumpAndSettle();
    expect(store.tasks.single.repeat, Repeat.daily);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(store.tasksOn(tomorrow).single.title, 'Feed the fish');
    expect(find.byIcon(Icons.repeat), findsOneWidget);
  });

  testWidgets('search finds a task and opens it', (tester) async {
    await Prefs.current.setOnboarded();
    final old = await store.addTask('Return the milk crate', day: DateTime(2026, 1, 3));
    await store.addTask('Gym');
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('search-tasks')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-field')), 'milk');
    await tester.pump();
    expect(find.byKey(Key('found-${old.id}')), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget, reason: 'only on the list behind');
    await tester.tap(find.byKey(Key('found-${old.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('a countdown can be edited, and a past day counts days since', (tester) async {
    await Prefs.current.setOnboarded();
    final now = DateTime.now();
    final met = await store.addCountdown('Met Mochi', DateTime(now.year, now.month, now.day - 30));
    await tester.pumpWidget(_app(store));
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('30 days since'), findsOneWidget);
    await tester.tap(find.byKey(Key('countdown-${met.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('countdown-name')), 'Mochi day');
    await tester.tap(find.byKey(const Key('countdown-yearly')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('countdown-save')));
    await tester.pumpAndSettle();
    expect(met.title, 'Mochi day');
    expect(met.yearly, isTrue);
    expect(met.isPast(), isFalse, reason: 'a yearly day comes round again');
  });

  testWidgets('the Dashboard shows what is not done, the rate and the week', (tester) async {
    await Prefs.current.setOnboarded();
    final a = await store.addTask('One');
    await store.addTask('Two');
    await store.tick(a);
    await store.add(store.focus, '25');
    await tester.pumpWidget(_app(store));
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('Not done'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    final i = DateTime.now().weekday - 1;
    expect(tester.getSize(find.byKey(Key('bar-$i'))).height, greaterThan(40));
    await tester.scrollUntilVisible(
      find.byKey(const Key('focus-card')),
      200,
      scrollable: find
          .descendant(of: find.byKey(const Key('dashboard-list')), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets('focus: a stopwatch, any length, and a task to focus on', (tester) async {
    await Prefs.current.setOnboarded();
    final f = FocusSession.current;
    addTearDown(() {
      f.setStopwatch(false);
      f.setLength(25);
      f.clearTask();
    });
    final t = await store.addTask('Essay');
    await tester.pumpWidget(_app(store));
    // From the task's sheet, Focus on this opens the timer for it.
    await tester.tap(find.text('Essay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-focus')));
    await tester.pumpAndSettle();
    expect(find.text('For: ${t.title}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-length-field')), '50');
    await tester.tap(find.byKey(const Key('focus-length-save')));
    await tester.pumpAndSettle();
    expect(f.length, 50);
    expect(find.text('50:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-mode-stopwatch')));
    await tester.pumpAndSettle();
    expect(f.stopwatch, isTrue);
    expect(find.text('00:00'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('sound-rain')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sound-rain')));
    await tester.pumpAndSettle();
    expect(Prefs.current.focusSound, 'rain');
  });
}
