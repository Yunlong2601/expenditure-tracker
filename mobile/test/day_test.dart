import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/chat.dart';
import 'package:spendsnap/day.dart';

void main() {
  group('DayStore', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('day'));
    tearDown(() async => dir.delete(recursive: true));

    test(
      'a stack shows one step at a time and is done with its last',
      () async {
        final s = DayStore.memory();
        final t = await s.addTask(
          'Morning',
          steps: [StackStep('Wash'), StackStep('Dress')],
        );
        expect(t.topStep?.title, 'Wash');
        await s.tick(t);
        expect(t.topStep?.title, 'Dress');
        expect(t.done, isFalse);
        await s.tick(t);
        expect(t.done, isTrue);
        expect(s.doneOn(DateTime.now()), [t]);
      },
    );

    test('a plain task ticks on and off', () async {
      final s = DayStore.memory();
      final t = await s.addTask('Water');
      await s.tick(t);
      expect(t.done, isTrue);
      await s.tick(t);
      expect(t.done, isFalse);
      expect(t.doneAt, isNull);
    });

    test('timed tasks come first, by time', () async {
      final s = DayStore.memory();
      await s.addTask('Any time');
      await s.addTask('Late', minutes: 20 * 60);
      await s.addTask('Early', minutes: 8 * 60);
      expect(s.tasksOn(DateTime.now()).map((t) => t.title), [
        'Early',
        'Late',
        'Any time',
      ]);
    });

    test('the getting started stack is added once', () async {
      final s = DayStore.memory();
      await s.addGettingStarted();
      await s.addGettingStarted();
      expect(s.tasks, hasLength(1));
      expect(
        s.tasks.single.steps,
        hasLength(DayStore.gettingStartedSteps.length),
      );
    });

    test('everything survives a reload from the file', () async {
      final s = await DayStore.load(dir);
      await s.addTask(
        'Read',
        minutes: 600,
        steps: [StackStep('Ch 1', note: 'slowly')],
      );
      await s.addMood(Mood.calm);
      await s.addCountdown(
        'Exams',
        DateTime.now().add(const Duration(days: 3)),
      );
      await s.add(s.focus, '25');
      final again = await DayStore.load(dir);
      expect(again.tasks.single.steps.single.note, 'slowly');
      expect(again.moodOf(DateTime.now()), Mood.calm);
      expect(again.upcoming().single.daysLeft(), 3);
      expect(again.focusMinutesOn(DateTime.now()), 25);
    });

    test('countdowns in the past are not upcoming', () async {
      final s = DayStore.memory();
      await s.addCountdown(
        'Gone',
        DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(s.upcoming(), isEmpty);
    });
  });

  group('the cat', () {
    test('remembers what she asks it to', () {
      final s = DayStore.memory();
      final reply = catReply('Remember I like oat milk', s);
      expect(s.memories.single.text, 'I like oat milk');
      expect(reply, contains('oat milk'));
    });

    test('says what is left today', () async {
      final s = DayStore.memory();
      await s.addTask('Homework');
      expect(catReply('what’s left?', s), contains('Homework'));
    });

    test('writes a notebook page for a past day of chat, once', () {
      final s = DayStore.memory();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      s.chat.add(Entry(at: yesterday, text: 'hi', kind: 'me'));
      writeNotebook(s);
      writeNotebook(s);
      expect(s.notebook, hasLength(1));
      expect(s.notebook.single.text, contains('chatted once'));
    });
  });
}
