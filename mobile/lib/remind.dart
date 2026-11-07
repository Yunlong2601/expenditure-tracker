import 'package:flutter/services.dart';

import 'day.dart';
import 'l10n.dart';
import 'ledger.dart';
import 'prefs.dart';

/// The cat's notifications: the evening "did you spend anything today?",
/// daily check-ins, and reminders for tasks and countdowns.
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

  /// The cat's own hellos for each level of Chattiness (Me → 主动程度):
  /// none when Quiet, one in the evening Sometimes, three a day Often.
  static List<({String id, int minutes, String body})> nudges(
    int chatty,
    String name,
  ) => [
    if (chatty >= 2)
      (
        id: 'nudge-morning',
        minutes: 9 * 60,
        body: tr(
          'Good morning from $name! Pick one small thing for today.',
          '早上好，我是$name！挑一件小事，今天就从它开始。',
        ),
      ),
    if (chatty >= 2)
      (
        id: 'nudge-afternoon',
        minutes: 15 * 60,
        body: tr(
          '$name says: a sip of water and a little stretch?',
          '$name提醒你：喝口水，伸个懒腰吧？',
        ),
      ),
    if (chatty >= 1)
      (
        id: 'nudge-evening',
        minutes: 20 * 60 + 30,
        body: tr(
          'How did today go? $name would love to hear about it.',
          '今天过得怎么样？$name想听你说说。',
        ),
      ),
  ];

  /// Lines up a daily notification for every check-in and the cat's own
  /// hellos, or none while check-ins are paused or quiet mode is on.
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
        if (on)
          for (final n in nudges(p.chatty, p.catName))
            {
              'id': n.id,
              'hour': n.minutes ~/ 60,
              'minute': n.minutes % 60,
              'body': n.body,
            },
      ]);
    } on Object catch (_) {
      // No notifications here (tests, other platforms): nothing to do.
    }
  }

  /// Reminders for tasks with a time and their reminder on, over the next
  /// two weeks, and for countdowns, the morning before and the morning of the
  /// day. Nearest first, and at most [max]: an iPhone keeps 64 waiting in all.
  /// Quiet mode keeps them, without a sound.
  static List<Map<String, Object>> alerts(
    DayStore s, {
    DateTime? now,
    int max = 40,
  }) {
    final t0 = now ?? DateTime.now();
    final out = <({DateTime at, String id, String body})>[];
    for (var i = 0; i < 14; i++) {
      final day = DateTime(t0.year, t0.month, t0.day + i);
      for (final t in s.tasksOn(day)) {
        final m = t.minutes;
        if (!t.remind || m == null || t.done) continue;
        final at = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
        if (!at.isAfter(t0)) continue;
        out.add((
          at: at,
          id: 'task-${t.id}',
          // A private task's name stays off the lock screen.
          body: t.private
              ? tr('Time for your private task.', '该做那件不公开的事啦。')
              : tr('Time for “${t.title}”. You’ve got this!', '该做「${t.title}」啦，你可以的！'),
        ));
      }
    }
    for (final c in s.countdowns) {
      if (!c.remind || c.isPast(t0)) continue;
      final d = c.next(t0);
      final before = DateTime(d.year, d.month, d.day - 1, 9);
      final on = DateTime(d.year, d.month, d.day, 9);
      if (before.isAfter(t0)) {
        out.add((
          at: before,
          id: 'countdown-${c.id}-before',
          body: tr('${c.title} is tomorrow!', '明天就是${c.title}啦！'),
        ));
      }
      if (on.isAfter(t0)) {
        out.add((
          at: on,
          id: 'countdown-${c.id}',
          body: tr('${c.title} is today!', '今天就是${c.title}！'),
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    final sound = !Prefs.current.quiet;
    return [
      for (final a in out.take(max))
        {
          'id': a.id,
          'at': a.at.millisecondsSinceEpoch,
          'body': a.body,
          'sound': sound,
        },
    ];
  }

  /// Replaces every task and countdown reminder on the phone with [alerts].
  static Future<void> syncAlerts(DayStore s) async {
    try {
      await _channel.invokeMethod<void>('alerts', alerts(s));
    } on Object catch (_) {
      // No notifications here (tests, other platforms): nothing to do.
    }
  }
}
