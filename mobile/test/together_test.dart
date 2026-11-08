import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/records.dart';
import 'package:spendsnap/theme.dart';
import 'package:spendsnap/together.dart';

void main() {
  late DayStore store;
  final f = FocusSession.current;
  // Wednesday 11 November, 3:40:30 pm.
  var now = DateTime(2026, 11, 11, 15, 40, 30);

  setUp(() {
    Prefs.current = Prefs.memory();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
    now = DateTime(2026, 11, 11, 15, 40, 30);
    togetherClock = () => now;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('spendsnap/study'),
          (c) async => c.method == 'locked' ? false : null,
        );
  });

  tearDown(() async {
    togetherClock = DateTime.now;
    if (f.started) await f.finish(early: true);
    f.setLength(25);
    f.setSubject('study');
    f.last = null;
    f.note = null;
    f.together = false;
    f.lastTogether = false;
  });

  group('codes', () {
    test('every start minute and length has its own code', () {
      final day = DateTime(2026, 11, 11);
      final seen = <String>{};
      for (var m = 0; m < 24 * 60; m++) {
        final start = day.add(Duration(minutes: m));
        for (final len in togetherLengths) {
          final code = togetherCode(start, len);
          expect(code, hasLength(4));
          expect(seen.add(code), isTrue, reason: '$start $len');
          final back = readTogetherCode(code, start)!;
          expect((back.start, back.minutes), (start, len));
        }
      }
      expect(seen, hasLength(8640));
    });

    test('a minute apart, codes look nothing alike', () {
      final a = togetherCode(DateTime(2026, 11, 11, 15, 42), 25);
      final b = togetherCode(DateTime(2026, 11, 11, 15, 43), 25);
      expect((int.parse(a) - int.parse(b)).abs(), greaterThan(10));
    });

    test('start at least a minute away, on the minute', () {
      expect(togetherStart(now), DateTime(2026, 11, 11, 15, 42));
      expect(
        togetherStart(DateTime(2026, 11, 11, 23, 59, 5)),
        DateTime(2026, 11, 12, 0, 1),
      );
    });

    test('a code made just before midnight starts tomorrow', () {
      final start = DateTime(2026, 11, 12, 0, 1);
      final read = readTogetherCode(
        togetherCode(start, 30),
        DateTime(2026, 11, 11, 23, 59, 30),
      )!;
      expect(read.start, start);
      expect(read.minutes, 30);
    });

    test('anything else is not a code', () {
      for (final c in ['', '12', 'abcd', '12345', '9999', '8640']) {
        expect(readTogetherCode(c, now), isNull, reason: c);
      }
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester t) async {
      t.view.physicalSize = const Size(393, 852) * 3;
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: tinyTheme(Brightness.light),
          home: RecordsScreen(store: store, tab: 1),
        ),
      );
      final button = find.byKey(const Key('together-open'));
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
    }

    /// Lets the clock reach the start and the study view open.
    Future<void> reachStart(WidgetTester t) async {
      now = DateTime(2026, 11, 11, 15, 42);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 600));
    }

    Future<void> finishAndClose(WidgetTester t) async {
      await f.finish();
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
    }

    testWidgets('making a code starts the timer on the minute', (t) async {
      await open(t);
      await t.tap(find.byKey(const Key('together-45')));
      await t.pump();
      await t.tap(find.byKey(const Key('together-make')));
      await t.pump();
      final code = togetherCode(DateTime(2026, 11, 11, 15, 42), 45);
      expect(find.text(code), findsOneWidget);
      expect(find.text('Starts at 3:42 PM · 45 min'), findsOneWidget);
      expect(find.textContaining('Starting in 1:30.'), findsOneWidget);

      now = DateTime(2026, 11, 11, 15, 41, 50);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Starting in 0:10.'), findsOneWidget);
      expect(f.started, isFalse);

      await reachStart(t);
      expect(f.running, isTrue);
      expect(f.length, 45);
      expect(f.together, isTrue);
      expect(find.byKey(const Key('together-sheet')), findsNothing);
      expect(find.byKey(const Key('study-clock')), findsOneWidget);

      await finishAndClose(t);
      expect(f.lastTogether, isTrue);
      expect(f.together, isFalse);
      expect(find.byKey(const Key('together-done')), findsOneWidget);
      await t.tap(find.byKey(const Key('study-finish')));
      await t.pumpAndSettle();
    });

    testWidgets('joining with a friend’s code', (t) async {
      final code = togetherCode(DateTime(2026, 11, 11, 15, 42), 25);
      await open(t);
      await t.tap(find.byKey(const Key('together-join')));
      await t.pumpAndSettle();
      final go = find.byKey(const Key('together-go'));
      expect(t.widget<FilledButton>(go).onPressed, isNull);

      await t.enterText(find.byKey(const Key('together-code')), code);
      await t.pump();
      expect(find.text('Starts at 3:42 PM · 25 min'), findsOneWidget);
      await t.tap(go);
      await t.pump();
      expect(find.byKey(const Key('together-shown')), findsOneWidget);

      await reachStart(t);
      expect(f.running, isTrue);
      expect(f.length, 25);
      await finishAndClose(t);
      await t.tap(find.byKey(const Key('study-finish')));
      await t.pumpAndSettle();
    });

    testWidgets('a code that has started, or is far off, can’t be joined', (
      t,
    ) async {
      await open(t);
      await t.tap(find.byKey(const Key('together-join')));
      await t.pumpAndSettle();
      final field = find.byKey(const Key('together-code'));

      await t.enterText(
        field,
        togetherCode(DateTime(2026, 11, 11, 15, 40), 25),
      );
      await t.pump();
      expect(
        find.text(
          'That session has already started. Make a new code together.',
        ),
        findsOneWidget,
      );

      await t.enterText(field, togetherCode(DateTime(2026, 11, 11, 17, 0), 25));
      await t.pump();
      expect(find.text('Check the code with your friend.'), findsOneWidget);

      await t.enterText(field, '9999');
      await t.pump();
      expect(find.text('That isn’t a code. It has 4 digits.'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('together-go'))).onPressed,
        isNull,
      );
    });

    testWidgets('cancel goes back, and nothing starts', (t) async {
      await open(t);
      await t.tap(find.byKey(const Key('together-make')));
      await t.pump();
      await t.tap(find.byKey(const Key('together-cancel')));
      await t.pump();
      expect(find.byKey(const Key('together-make')), findsOneWidget);
      await reachStart(t);
      expect(f.started, isFalse);
    });
  });
}
