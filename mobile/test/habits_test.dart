import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/brain.dart';
import 'package:spendsnap/chat.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/remind.dart';
import 'package:spendsnap/task_talk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Prefs.current = Prefs.memory());

  // Friday 6 November 2026, 5:30 pm.
  final now = DateTime(2026, 11, 6, 17, 30);
  final fri = DateTime(2026, 11, 6);
  DateTime plus(int days) => DateTime(fri.year, fri.month, fri.day + days);

  group('repeating tasks', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('habits'));
    tearDown(() async => dir.delete(recursive: true));

    test('a daily task comes back each day, and each day is ticked on its own', () async {
      final s = await DayStore.load(dir);
      await s.addTask('Brush teeth', day: fri, minutes: 21 * 60, repeat: Repeat.daily);
      final today = s.tasksOn(fri).single;
      expect(today, isA<Occurrence>());
      expect(s.tasksOn(plus(3)).single.title, 'Brush teeth');
      expect(s.tasksOn(plus(-1)), isEmpty);

      await s.tick(today, now: DateTime(2026, 11, 6, 21, 5));
      expect(today.done, isTrue);
      expect(s.tasksOn(plus(1)).single.done, isFalse);
      expect(s.doneOn(fri).single.title, 'Brush teeth');

      // Editing one day edits them all; the done days survive a reload.
      s.tasksOn(plus(1)).single.title = 'Brush teeth well';
      await s.save();
      final again = await DayStore.load(dir);
      expect(again.tasks, hasLength(1));
      expect(again.tasksOn(plus(2)).single.title, 'Brush teeth well');
      expect(again.tasksOn(fri).single.done, isTrue);
      expect(again.tasksOn(plus(1)).single.done, isFalse);
    });

    test('weekdays skip the weekend and weekly keeps its weekday', () {
      final s = DayStore.memory();
      s.newTask('Homework', day: fri, repeat: Repeat.weekdays);
      s.newTask('Piano', day: fri, repeat: Repeat.weekly);
      List<String> on(int d) => [for (final t in s.tasksOn(plus(d))) t.title];
      expect(on(0), ['Homework', 'Piano']);
      expect(on(1), isEmpty); // Saturday
      expect(on(2), isEmpty); // Sunday
      expect(on(3), ['Homework']); // Monday
      expect(on(7), ['Homework', 'Piano']); // next Friday
    });

    test('delete just one day, or every day', () async {
      final s = DayStore.memory();
      await s.addTask('Walk', day: fri, repeat: Repeat.daily);
      await s.removeTask(s.tasksOn(plus(1)).single, onlyThisDay: true);
      expect(s.tasksOn(plus(1)), isEmpty);
      expect(s.tasksOn(plus(2)), hasLength(1));
      await s.removeTask(s.tasksOn(plus(2)).single);
      expect(s.tasks, isEmpty);
    });

    test('stopping a repeat from a later day keeps the days before it', () async {
      final s = DayStore.memory();
      final t = s.newTask('Stretch', day: fri);
      await s.tick(t, now: now);
      s.setRepeat(t, Repeat.daily);
      expect(s.tasksOn(fri).single.done, isTrue, reason: 'the first day stays done');
      s.setRepeat(s.tasksOn(plus(2)).single, Repeat.none);
      expect(s.tasksOn(plus(2)), hasLength(1));
      expect(s.tasksOn(plus(3)), isEmpty);
      expect(s.tasksOn(fri).single.done, isTrue);
    });

    test('search finds tasks by name, note or step, each repeating one once', () {
      final s = DayStore.memory();
      s.newTask('Buy milk', day: plus(-3));
      s.newTask('Read', day: fri, repeat: Repeat.daily).note = 'the milk chapter';
      s.newTask('Morning', steps: [StackStep('Pour milk')]);
      s.newTask('Gym');
      expect(s.search('MILK'), hasLength(3));
      expect(s.search(''), isEmpty);
      expect(s.search('gym').single.title, 'Gym');
    });
  });

  group('countdowns', () {
    test('a yearly one counts to its next time round', () {
      final c = Countdown(title: 'Birthday', date: DateTime(2012, 3, 14), yearly: true);
      expect(c.next(now), DateTime(2027, 3, 14));
      expect(c.daysLeft(now), 128);
      expect(c.isPast(now), isFalse);
      expect(c.fallsOn(DateTime(2030, 3, 14)), isTrue);
      expect(c.fallsOn(DateTime(2010, 3, 14)), isFalse);
      final leap = Countdown(title: 'Leap', date: DateTime(2024, 2, 29), yearly: true);
      expect(leap.next(now), DateTime(2027, 2, 28));
    });

    test('a day that has passed counts the days since', () async {
      final s = DayStore.memory();
      await s.addCountdown('Met Mochi', DateTime(2026, 10, 7));
      await s.addCountdown('Exams', DateTime(2026, 11, 20));
      expect(s.upcoming(now).single.title, 'Exams');
      expect(s.past(now).single.daysSince(now), 30);
      expect(s.countdownsOn(DateTime(2026, 11, 20)).single.title, 'Exams');
    });
  });

  group('reminders', () {
    late List<MethodCall> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('spendsnap/remind'),
        (c) async {
          calls.add(c);
          return null;
        },
      );
    });

    test('tasks ring at their time and countdowns the morning before and of', () async {
      final s = DayStore.memory();
      s.newTask('Read', day: fri, minutes: 20 * 60, remind: true);
      s.newTask('Lunch', day: fri, minutes: 12 * 60, remind: true); // already gone
      s.newTask('Quiet', day: fri, minutes: 19 * 60); // no reminder
      s.newTask('Diary', day: fri, minutes: 18 * 60, remind: true, private: true);
      final done = s.newTask('Done', day: fri, minutes: 22 * 60, remind: true);
      await s.tick(done, now: now);
      s.newTask('Water', day: fri, minutes: 8 * 60, remind: true, repeat: Repeat.daily);
      await s.addCountdown('Exams', DateTime(2026, 11, 9));

      final a = Remind.alerts(s, now: now);
      final bodies = [for (final x in a) x['body']];
      expect(bodies.first, 'Time for your private task.');
      expect(bodies[1], 'Time for “Read”. You’ve got this!');
      expect(bodies, contains('Exams is tomorrow!'));
      expect(bodies, contains('Exams is today!'));
      expect(bodies.where((b) => b == 'Time for “Water”. You’ve got this!'), hasLength(13));
      expect(bodies.any((b) => '$b'.contains('Lunch') || '$b'.contains('Quiet') || '$b'.contains('Done')), isFalse);
      expect(a.first['at'], DateTime(2026, 11, 6, 18).millisecondsSinceEpoch);

      // At most 40, and quiet mode keeps them without a sound.
      for (var i = 0; i < 50; i++) {
        s.newTask('More $i', day: plus(1), minutes: 10 * 60, remind: true);
      }
      await Prefs.current.setQuiet(true);
      final many = Remind.alerts(s, now: now);
      expect(many, hasLength(40));
      expect(many.every((x) => x['sound'] == false), isTrue);

      await Remind.syncAlerts(s);
      expect(calls.single.method, 'alerts');
    });
  });

  group('tasks from chat', () {
    TaskAsk? ask(String s) => parseTaskAsk(s, now: now);

    test('reads English asks', () {
      final a = ask('remind me at 8 to read')!;
      expect((a.title, a.day, a.minutes, a.remind), ('Read', fri, 20 * 60, true));
      final b = ask('Remind me tomorrow at 9am to bring my PE kit')!;
      expect((b.title, b.day, b.minutes), ('Bring my PE kit', plus(1), 9 * 60));
      final c = ask('every day at 9 remind me to brush my teeth')!;
      expect((c.title, c.repeat, c.minutes), ('Brush my teeth', Repeat.daily, 9 * 60));
      final d = ask('remind me to water the plants every monday')!;
      expect((d.title, d.repeat, d.day), ('Water the plants', Repeat.weekly, plus(3)));
      final e = ask('add buy milk to my list')!;
      expect((e.title, e.minutes, e.remind), ('Buy milk', null, false));
      expect(ask('add read 2 chapters')!.title, 'Read 2 chapters');
      expect(ask('todo: finish homework tomorrow')!.day, plus(1));
    });

    test('reads Chinese asks', () {
      final a = ask('每天晚上九点提醒我刷牙')!;
      expect((a.title, a.repeat, a.minutes, a.remind), ('刷牙', Repeat.daily, 21 * 60, true));
      final b = ask('提醒我明天下午3点交作业')!;
      expect((b.title, b.day, b.minutes), ('交作业', plus(1), 15 * 60));
      final c = ask('帮我提醒我下周三上午十点半去看牙医')!;
      expect((c.title, c.day, c.minutes), ('看牙医', DateTime(2026, 11, 11), 10 * 60 + 30));
      expect(ask('待办：今天晚上八点前写完作业')!.title, '写完作业');
      expect(ask('每周一提醒我倒垃圾')!.day, plus(3));
    });

    test('leaves other messages alone', () {
      expect(ask('what is on my todo list'), isNull);
      expect(ask('remember I like oat milk'), isNull);
      expect(ask('add up how much money I spent'), isNull);
      expect(ask('remind me'), isNull);
      expect(ask('I want to add a cat'), isNull);
    });

    test('the cat puts it on the list, on the phone', () {
      final s = DayStore.memory();
      expect(staysOnPhone('remind me at 8 to read'), isTrue);
      final reply = catReply('remind me at 8 to read', s);
      final t = s.tasks.single;
      expect(t.title, 'Read');
      expect(t.minutes, isNotNull);
      expect(t.remind, isTrue);
      expect(reply, startsWith('Added “Read”'));
    });
  });
}
