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
}
