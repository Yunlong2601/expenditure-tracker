import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';
import 'package:spendsnap/week_card.dart';

void main() {
  late DayStore store;
  late Directory dir;
  late List<MethodCall> shared;
  var shareWorks = true;

  setUp(() async {
    Prefs.current = Prefs.memory();
    await Prefs.current.setOnboarded();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
    dir = await Directory.systemTemp.createTemp('week');
    shared = [];
    shareWorks = true;
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('spendsnap/share'), (
      c,
    ) async {
      shared.add(c);
      return shareWorks;
    });
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (c) async => dir.path,
    );
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('a week in numbers', () {
    // Monday 2 to Sunday 8 November, looked at on Wednesday the 11th.
    DateTime nov(int d, [int h = 12]) => DateTime(2026, 11, d, h);

    test('adds up study, things done, active days and moods', () async {
      final a = await store.addTask('Maths homework', day: nov(2));
      await store.tick(a, now: nov(2));
      final b = await store.addTask('Pack bag', day: nov(3));
      await store.tick(b, now: nov(3));
      store.focus
        ..add(Entry(at: nov(4), text: '30', kind: 'maths'))
        ..add(Entry(at: nov(5), text: '45', kind: 'science'))
        ..add(Entry(at: nov(5, 16), text: '20', kind: 'maths'))
        // Left early: not counted.
        ..add(Entry(at: nov(6), text: '50', kind: 'english', quit: true))
        // The week before.
        ..add(Entry(at: nov(1), text: '60', kind: 'maths'));
      await store.addMood(Mood.happy, at: nov(2));
      await store.addMood(Mood.tired, at: nov(7));

      final w = WeekStats.of(store, nov(5), now: nov(11));
      expect(w.monday, DateTime(2026, 11, 2));
      expect(w.range, '2 – 8 Nov');
      expect(w.study, 95);
      expect(w.done, 2);
      expect(w.activeDays, 4);
      expect(w.moods, [Mood.happy, null, null, null, null, Mood.tired, null]);
      expect(w.subjects.map((e) => '${e.key} ${e.value}'), [
        'maths 50',
        'science 45',
      ]);
      expect(w.spoken, contains('studied 1 h 35 min, 2 things done'));
    });

    test('says something kind about any week', () {
      WeekStats week({int study = 0, int done = 0, int active = 0}) =>
          WeekStats(
            monday: nov(2),
            study: study,
            done: done,
            activeDays: active,
            moods: List.filled(7, null),
            subjects: const [],
            streak: 0,
          );
      expect(week().cheer('Mochi'), 'A quiet week. A fresh start on Monday!');
      expect(
        week(study: 320, done: 1, active: 2).cheer('Mochi'),
        'Mochi is proud of all that studying!',
      );
      expect(
        week(study: 40, done: 9, active: 6).cheer('Mochi'),
        'Something done on 6 days. Great rhythm!',
      );
      expect(
        week(done: 2, active: 2).cheer('Mochi'),
        'Every little bit counts. Keep going!',
      );
    });

    test('a week across two months names both', () {
      final w = WeekStats.of(store, DateTime(2026, 11, 1));
      expect(w.range, '26 Oct – 1 Nov');
    });
  });

  group('the picture', () {
    Widget app() => MaterialApp(
      theme: tinyTheme(Brightness.light),
      home: AppShell(store: store, initialTab: 1),
    );

    Future<void> open(WidgetTester t) async {
      await store.add(store.focus, '25', kind: 'maths');
      await t.pumpWidget(app());
      final entry = find.byKey(const Key('week-card-open'));
      await t.scrollUntilVisible(
        entry,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('dashboard-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(entry);
      await t.pumpAndSettle();
    }

    testWidgets('opens from the Dashboard and goes back a week', (t) async {
      await open(t);
      expect(find.byType(WeekCard), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      final bar = find.descendant(
        of: find.byKey(const Key('week-subjects')),
        matching: find.byType(ColoredBox),
      );
      expect(t.getSize(bar), const Size(304, 10));
      final next = t.widget<IconButton>(find.byKey(const Key('week-next')));
      expect(next.onPressed, isNull);

      await t.tap(find.byKey(const Key('week-back')));
      await t.pumpAndSettle();
      expect(find.text('0 min'), findsOneWidget);
      await t.tap(find.byKey(const Key('week-next')));
      await t.pumpAndSettle();
      expect(find.text('25 min'), findsOneWidget);
    });

    testWidgets('shares a story-sized picture', (t) async {
      await open(t);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('share-week')));
        for (var i = 0; i < 50 && shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await t.pumpAndSettle();
      final path = shared.single.arguments as String;
      expect(path, contains('TinyHabitsCat-week-'));
      late final Uint8List png;
      await t.runAsync(() async => png = await File(path).readAsBytes());
      // PNG width and height, from its header.
      final header = ByteData.sublistView(png, 16, 24);
      expect((header.getUint32(0), header.getUint32(4)), (1080, 1920));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('says so when sharing doesn’t open', (t) async {
      shareWorks = false;
      await open(t);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('share-week')));
        for (var i = 0; i < 50 && shared.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await t.pumpAndSettle();
      expect(find.text('Couldn’t open sharing. Try again.'), findsOneWidget);
    });

    testWidgets('opens from the streak sheet too', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: tinyTheme(Brightness.light),
          home: AppShell(store: store),
        ),
      );
      await t.tap(find.byKey(const Key('streak-chip')));
      await t.pumpAndSettle();
      final share = find.byKey(const Key('streak-share'));
      await t.ensureVisible(share);
      await t.pumpAndSettle();
      await t.tap(share);
      await t.pumpAndSettle();
      expect(find.byType(WeekCardScreen), findsOneWidget);
    });
  });
}
