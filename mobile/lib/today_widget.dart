import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'day.dart';
import 'l10n.dart';
import 'prefs.dart';

/// The Home Screen widget: today's next three things to do, how many are
/// done and the streak. The app hands it the words to show through a small
/// bridge (`MainActivity.kt` on Android), since the widget can't run Dart.
class TodayWidget {
  TodayWidget._();

  static const _channel = MethodChannel('spendsnap/widget');
  static String? _last;

  /// What the widget shows for [now]'s day. Private tasks keep their
  /// secret: the Home Screen is on show to anyone holding the phone.
  static Map<String, Object?> payload(DayStore s, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final tasks = s.tasksOn(today);
    final open = tasks.where((t) => !t.done).toList();
    final done = tasks.length - open.length;
    return {
      'day': dayKey(today),
      'title': tr('Today', '今天'),
      'tasks': [
        for (final t in open.take(3))
          {
            'title': t.private ? tr('Private task', '私密任务') : t.title,
            'time': t.minutes == null
                ? null
                : hhmm(DateTime(0, 1, 1, 0, t.minutes!)),
          },
      ],
      'more': open.length > 3
          ? tr('+${open.length - 3} more', '还有 ${open.length - 3} 件')
          : null,
      'done': tasks.isEmpty
          ? null
          : tr('$done of ${tasks.length} done', '完成 $done / ${tasks.length}'),
      'empty': tasks.isEmpty
          ? tr('Nothing planned. Add one small thing?', '今天还没安排，加一件小事吧？')
          : tr(
              'All done. ${Prefs.current.catName} is proud!',
              '都完成啦，${Prefs.current.catName} 为你骄傲！',
            ),
      'streak': max(0, s.streak(now)),
      'streakText': tr(count(s.streak(now), 'day'), '${s.streak(now)} 天'),
      'stale': tr('Open the app to see today', '打开应用看看今天'),
    };
  }

  /// Sends today's words to the widget, when they changed. Does nothing
  /// where there is no widget, such as in tests.
  static Future<void> push(DayStore s) async {
    final words = jsonEncode(payload(s));
    if (words == _last) return;
    _last = words;
    try {
      await _channel.invokeMethod<void>('update', words);
    } on Object catch (_) {
      // No widget on this phone, or no bridge: nothing to update.
    }
  }

  @visibleForTesting
  static void forget() => _last = null;
}
