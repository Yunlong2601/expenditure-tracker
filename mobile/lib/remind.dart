import 'package:flutter/services.dart';

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
}
