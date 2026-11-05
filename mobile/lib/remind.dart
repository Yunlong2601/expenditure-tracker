import 'package:flutter/services.dart';

import 'day.dart';
import 'l10n.dart';
import 'ledger.dart';
import 'prefs.dart';

/// The cat's evening "did you spend anything today?" notification.
class Remind {
  Remind._();

  static const _channel = MethodChannel('spendsnap/remind');

  /// Asks the phone for permission to notify. False if she said no.
  static Future<bool> ask() async {
    try {
      return await _channel.invokeMethod<bool>('ask') ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  /// Lines up the next week of reminders, skipping today once she has logged
  /// something today. Call after anything is saved and on launch.
  static Future<void> sync(Ledger ledger, {DateTime? now}) async {
    final p = Prefs.current;
    final today = now ?? DateTime.now();
    final loggedToday = ledger.all.any(
      (e) => e.createdAt.year == today.year && e.createdAt.month == today.month && e.createdAt.day == today.day,
    );
    try {
      if (!p.reminderOn) {
        await _channel.invokeMethod<void>('cancel');
        return;
      }
      await _channel.invokeMethod<void>('schedule', {
        'hour': p.reminderAt ~/ 60,
        'minute': p.reminderAt % 60,
        'skipToday': loggedToday,
        'lines': eveningLines,
      });
    } on Object catch (_) {
      // No notifications here (tests, other platforms): nothing to do.
    }
  }

  /// The evening reminder lines, one a day in turn.
  static List<String> get eveningLines => zh
      ? const [
          '喵！今天花钱了吗？',
          '悄悄问一句……今天喝奶茶了吗？3 秒就能记一笔。',
          '食堂、零食、公交？趁还记得告诉我！',
          '睡前查一下：今天有要记的账吗？',
        ]
      : const [
          'Meow! Did you spend anything today?',
          'Psst... any bubble tea today? Log it in 3 seconds.',
          'Canteen, snacks, bus? Tell me before you forget!',
          'Quick check before bed: anything to log today?',
        ];

  /// The cat's check-in message for each kind of check-in.
  static String checkInText(int kind, String name) => switch (kind) {
    0 => tr(
      '$name here: how’s your list going? Tap to see what’s next.',
      '我是$name，清单进行得怎么样？点开看看下一件。',
    ),
    1 => tr(
      '$name is cheering for you! One small thing at a time.',
      '$name在为你加油！一次做好一件小事。',
    ),
    _ => tr(
      'Time to look back on today with $name.',
      '该和$name一起回顾今天啦。',
    ),
  };

  /// Lines up a daily notification for every check-in, or none while
  /// check-ins are paused or quiet mode is on.
  static Future<void> syncCheckIns(DayStore store) async {
    final p = Prefs.current;
    final on = !store.checkInsPaused && !p.quiet;
    try {
      await _channel.invokeMethod<void>('checkins', [
        if (on)
          for (final c in store.checkIns)
            {
              'id': c.id,
              'hour': c.minutes ~/ 60,
              'minute': c.minutes % 60,
              'body': checkInText(c.kind, p.catName),
            },
      ]);
    } on Object catch (_) {
      // No notifications here (tests, other platforms): nothing to do.
    }
  }
}
