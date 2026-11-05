import 'package:flutter/services.dart';

import 'day.dart';
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
      });
    } on Object catch (_) {
      // No notifications here (tests, other platforms): nothing to do.
    }
  }

  /// The cat's check-in message for each kind of check-in.
  static String checkInText(int kind, String name) => switch (kind) {
    0 => '$name here: how’s your list going? Tap to see what’s next.',
    1 => '$name is cheering for you! One small thing at a time.',
    _ => 'Time to look back on today with $name.',
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
