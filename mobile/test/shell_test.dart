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

  testWidgets('the Records tab opens on Timeline', (tester) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(_app(store));
    await tester.tap(find.byKey(const Key('edge-records')));
    await tester.pumpAndSettle();
    expect(find.text('What are you doing now?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-Study')));
    await tester.pumpAndSettle();
    expect(store.timeline.single.text, 'Study');
  });
}
