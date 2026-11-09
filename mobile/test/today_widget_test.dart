import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/theme.dart';
import 'package:spendsnap/today_widget.dart';

void main() {
  late DayStore store;
  late List<Map<String, Object?>> sent;
  final now = DateTime(2026, 11, 11, 9);

  setUp(() async {
    Prefs.current = Prefs.memory();
    await Prefs.current.setOnboarded();
    store = DayStore.memory();
    DayStore.current = store;
    CatFigure.animate = false;
    TodayWidget.forget();
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('spendsnap/widget'), (
          c,
        ) async {
          if (c.method == 'update') {
            sent.add(
              (jsonDecode(c.arguments as String) as Map)
                  .cast<String, Object?>(),
            );
          }
          return null;
        });
  });

  group('what the widget shows', () {
    test('the next three open things, by time, with a secret kept', () async {
      final day = DateTime(2026, 11, 11);
      final done = await store.addTask('Feed the fish', day: day);
      await store.tick(done, now: now);
      await store.addTask('Read', day: day);
      await store.addTask('Piano', day: day, minutes: 17 * 60 + 30);
      await store.addTask('Diary', day: day, private: true);
      await store.addTask('Pack bag', day: day, minutes: 7 * 60);
      await store.addTask('Tomorrow', day: day.add(const Duration(days: 1)));

      final p = TodayWidget.payload(store, now: now);
      expect(p['day'], '2026-11-11');
      expect(p['title'], 'Today');
      expect(p['tasks'], [
        {'title': 'Pack bag', 'time': '07:00'},
        {'title': 'Piano', 'time': '17:30'},
        {'title': 'Read', 'time': null},
      ]);
      expect(p['more'], '+1 more');
      expect(p['done'], '1 of 5 done');
      expect(p['streak'], 1);
      expect(p['streakText'], '1 day');
    });

    test('private tasks show as private', () async {
      await store.addTask('Diary', day: now, private: true);
      final p = TodayWidget.payload(store, now: now);
      expect(p['tasks'], [
        {'title': 'Private task', 'time': null},
      ]);
      expect(p['more'], isNull);
    });

    test('a kind word when there is nothing, or all is done', () async {
      var p = TodayWidget.payload(store, now: now);
      expect(p['tasks'], isEmpty);
      expect(p['done'], isNull);
      expect(p['empty'], 'Nothing planned. Add one small thing?');

      final t = await store.addTask('Read', day: now);
      await store.tick(t, now: now);
      p = TodayWidget.payload(store, now: now);
      expect(p['tasks'], isEmpty);
      expect(p['empty'], 'All done. Mochi is proud!');
    });

    test('in Chinese too', () async {
      await Prefs.current.setLanguage('zh');
      await store.addTask('读书', day: now);
      final p = TodayWidget.payload(store, now: now);
      expect(p['title'], '今天');
      expect(p['done'], '完成 0 / 1');
      expect(p['stale'], '打开应用看看今天');
    });
  });

  group('sending it', () {
    test('only when something changed', () async {
      await TodayWidget.push(store);
      await TodayWidget.push(store);
      expect(sent, hasLength(1));
      await store.addTask('Read');
      await TodayWidget.push(store);
      expect(sent, hasLength(2));
      expect((sent.last['tasks']! as List).single, {
        'title': 'Read',
        'time': null,
      });
    });

    test('no bridge is fine', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('spendsnap/widget'),
            null,
          );
      await expectLater(TodayWidget.push(store), completes);
    });

    testWidgets('the app keeps it up to date as tasks change', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: tinyTheme(Brightness.light),
          home: AppShell(store: store),
        ),
      );
      await t.pump();
      expect(sent, hasLength(1));
      await store.addTask('Science worksheet');
      await t.pump();
      expect(sent, hasLength(2));
      expect(
        (sent.last['tasks']! as List).map((e) => (e as Map)['title']),
        contains('Science worksheet'),
      );
    });
  });
}
