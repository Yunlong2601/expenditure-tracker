import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/l10n.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/records.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/study.dart';
import 'package:spendsnap/study_screen.dart';
import 'package:spendsnap/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DayStore store;
  late List<MethodCall> calls;
  final f = FocusSession.current;

  setUp(() {
    Prefs.current = Prefs.memory();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('spendsnap/study'), (
          c,
        ) async {
          calls.add(c);
          return c.method == 'locked' ? false : null;
        });
  });

  tearDown(() async {
    if (f.started) await f.finish(early: true);
    f.setStopwatch(false);
    f.setLength(25);
    f.setSubject('study');
    f.last = null;
    f.note = null;
    phoneLanguage = () => 'en';
  });

  group('leaving the app', () {
    test('Nudge me pauses the clock, calls her back, and carries on when she returns', () async {
      final t0 = DateTime.now();
      f.start(store);
      f.appLeft(t0);
      expect(f.isAway, isTrue);
      expect(f.running, isFalse);
      expect(f.started, isTrue);
      expect(f.leftCount, 1);
      final back = calls.singleWhere((c) => c.method == 'callBack');
      expect((back.arguments as List).single, containsPair('seconds', 5));
      await f.appBack(t0.add(const Duration(minutes: 3)));
      expect(calls.last.method, 'cancelCallBack');
      expect(f.running, isTrue);
      expect(f.away, const Duration(minutes: 3));
      expect(f.note, 'Welcome back! You were away for 3 min.');
      await f.finish();
      final e = store.focus.single;
      expect(e.left, 1);
      expect(e.quit, isFalse);
      expect(store.focusMinutesOn(DateTime.now()), 25);
    });

    test('Strict forgives a quick look, and ends the session after 15 seconds away', () async {
      await f.setRule(StudyRule.strict);
      final t0 = DateTime.now();
      f.start(store);
      f.appLeft(t0);
      expect(
        (calls.singleWhere((c) => c.method == 'callBack').arguments as List),
        hasLength(2),
      );
      await f.appBack(t0.add(const Duration(seconds: 10)));
      expect(f.running, isTrue, reason: '10 seconds is within the grace');
      f.appLeft(t0.add(const Duration(seconds: 20)));
      await f.appBack(t0.add(const Duration(seconds: 50)));
      expect(f.started, isFalse);
      expect(f.last?.quit, isTrue);
      expect(f.last?.left, 2);
      expect(f.note, 'You were away for 30 sec, so this session ended.');
      final e = store.focus.single;
      expect(e.quit, isTrue);
      expect(
        store.focusMinutesOn(DateTime.now()),
        0,
        reason: 'a session she left does not count',
      );
      expect(store.focusOn(DateTime.now()), isEmpty);
    });

    test('leaving while paused or before starting does nothing', () async {
      f.appLeft();
      expect(f.isAway, isFalse);
      f.start(store);
      f.pause();
      f.appLeft();
      expect(f.leftCount, 0);
      expect(calls.where((c) => c.method == 'callBack'), isEmpty);
    });

    test(
      'the subject is saved with the session and stays for the next one',
      () async {
        f.setSubject('homework');
        f.start(store);
        await f.finish();
        expect(store.focus.single.kind, 'homework');
        expect(f.subject, 'homework');
        expect(subjectLabel('homework'), 'Homework');
        expect(subjectLabel('Essay'), 'Essay');
      },
    );

    test('a session survives a reload with how often she left', () {
      final e = Entry.fromJson(
        Entry(
          at: DateTime(2026, 11, 7),
          text: '12',
          kind: 'reading',
          left: 3,
          quit: true,
        ).toJson(),
      );
      expect((e.left, e.quit, e.kind), (3, true, 'reading'));
      expect(
        Entry.fromJson(Entry(at: DateTime(2026), text: '5').toJson()).left,
        0,
      );
    });
  });

  testWidgets('the app going to the background counts as leaving', (
    tester,
  ) async {
    await Prefs.current.setOnboarded();
    await tester.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: AppShell(store: store),
      ),
    );
    f.start(store);
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    expect(
      f.leftCount,
      0,
      reason: 'Control Center only makes the app inactive',
    );
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    expect(f.isAway, isTrue);
    expect(f.leftCount, 1);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    expect(f.isAway, isFalse);
    expect(f.running, isTrue);
    await f.finish(early: true);
  });

  testWidgets('pick a subject and a rule, study full screen, and stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: RecordsScreen(store: store, tab: 1),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('subject-reading')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject-reading')));
    await tester.pump();
    expect(f.subject, 'reading');
    await tester.ensureVisible(find.byKey(const Key('rule-strict')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-strict')));
    await tester.pumpAndSettle();
    expect(Prefs.current.studyRule, 1);
    expect(find.textContaining('more than 15 seconds'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rule-lock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rule-lock-help')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rule-lock-help')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Guided Access'), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('focus-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(f.running, isTrue);
    expect(find.byKey(const Key('study-clock')), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    expect(find.byKey(const Key('study-lock')), findsOneWidget);
    expect(
      calls.map((c) => c.method),
      containsAll(['awake', 'lock', 'locked']),
    );

    // Leaving and coming back shows on the study view.
    final t0 = DateTime.now();
    f.appLeft(t0);
    await tester.pump();
    expect(find.text('Left the app: 1 time'), findsOneWidget);
    await f.appBack(t0.add(const Duration(seconds: 5)));
    await tester.pump();
    expect(find.text('Welcome back! You were away for 5 sec.'), findsOneWidget);

    // Back asks first, and Keep studying keeps going.
    await tester.tap(find.byKey(const Key('study-close')));
    await tester.pumpAndSettle();
    expect(find.text('Stop studying?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('study-keep')));
    await tester.pumpAndSettle();
    expect(f.running, isTrue);
    await tester.tap(find.byKey(const Key('study-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('study-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('study-summary')), findsOneWidget);
    expect(
      find.text('Under a minute this time. Every little bit counts!'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('study-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('study-clock')), findsNothing);
    expect(calls.where((c) => c.method == 'awake').last.arguments, isFalse);
  });

  testWidgets('the study log shows today, the week, subjects and sessions', (
    tester,
  ) async {
    final now = DateTime.now();
    await store.add(store.focus, '30', at: now, kind: 'study');
    await store.add(store.focus, '20', at: now, kind: 'reading', left: 1);
    await store.add(
      store.focus,
      '5',
      at: now,
      kind: 'study',
      left: 2,
      quit: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(child: StudyLog(store: store)),
        ),
      ),
    );
    expect(find.text('Study time'), findsOneWidget);
    expect(
      find.text('50 min'),
      findsNWidgets(2),
      reason: 'today and the last 7 days',
    );
    expect(find.text('3×'), findsOneWidget);
    expect(find.text('Ended early'), findsOneWidget);
    expect(find.text('Reading'), findsWidgets);
  });

  test('the language follows the phone until one is picked', () async {
    phoneLanguage = () => 'zh';
    expect(zh, isTrue);
    expect(subjectLabel('study'), '学习');
    await Prefs.current.setLanguage('en');
    expect(zh, isFalse);
    await Prefs.current.setLanguage(null);
    phoneLanguage = () => 'fr';
    expect(zh, isFalse);
  });
}
