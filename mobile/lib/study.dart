import 'package:flutter/services.dart';

import 'l10n.dart';

/// What happens when she leaves the app in the middle of a study session.
/// She picks one on the Focus page.
enum StudyRule {
  /// The clock pauses while she is away, and the cat calls her back.
  nudge,

  /// Staying away longer than [studyGrace] ends the session, and its minutes
  /// don't count.
  strict,

  /// Like [strict], and the phone is locked to the app with Guided Access,
  /// so she can't leave at all until she is done.
  lock;

  String get label => switch (this) {
    nudge => tr('Nudge me', '提醒我'),
    strict => tr('Strict', '严格'),
    lock => tr('Lock me in', '锁定'),
  };

  String get about => switch (this) {
    nudge => tr(
      'If you leave the app, the clock pauses and the cat calls you back.',
      '离开应用时计时暂停，小猫会叫你回来。',
    ),
    strict => tr(
      'Leave the app for more than 15 seconds and the session ends without counting.',
      '离开应用超过 15 秒，这次专注就结束，不计时间。',
    ),
    lock => tr(
      'The phone stays on this app until you finish, with the iPhone’s Guided Access.',
      '用 iPhone 的“引导式访问”把手机锁定在这个应用里，直到完成。',
    ),
  };
}

/// How long she may be away in Strict and Lock me in before the session ends.
const studyGrace = Duration(seconds: 15);

/// The subjects on the Focus page. They are saved by these keys; a session
/// for a task is saved with the task's title instead.
/// What a focus session can be for: school subjects first, then the rest.
const studySubjects = [
  'study',
  'maths',
  'english',
  'science',
  'chinese',
  'homework',
  'reading',
  'revision',
];

/// The name to show for a session's subject or task.
String subjectLabel(String? key) => switch (key) {
  'study' => tr('Study', '学习'),
  'maths' => tr('Maths', '数学'),
  'english' => tr('English', '英语'),
  'science' => tr('Science', '科学'),
  'chinese' => tr('Chinese', '华文'),
  'homework' => tr('Homework', '作业'),
  'reading' => tr('Reading', '阅读'),
  'revision' => tr('Revision', '复习'),
  null || '' => tr('Focus', '专注'),
  _ => key,
};

/// "45 sec", "3 min" or "1 h 5 min".
String awayText(Duration d) {
  if (d.inSeconds < 60) return tr('${d.inSeconds} sec', '${d.inSeconds} 秒');
  if (d.inMinutes < 60) return tr('${d.inMinutes} min', '${d.inMinutes} 分钟');
  final m = d.inMinutes % 60;
  return tr(
    '${d.inHours} h${m > 0 ? ' $m min' : ''}',
    '${d.inHours} 小时${m > 0 ? ' $m 分钟' : ''}',
  );
}

/// The phone side of study mode, on the iPhone. Anywhere it isn't there
/// (tests, Android for now) every call quietly does nothing.
class StudyGuard {
  StudyGuard._();

  static const _channel = MethodChannel('spendsnap/study');

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on Object catch (_) {
      return null;
    }
  }

  /// Keeps the screen on while she studies, so it doesn't lock by itself.
  static Future<void> awake(bool on) => _call<void>('awake', on);

  /// Whether Guided Access is holding the phone on this app right now.
  static Future<bool> locked() async => await _call<bool>('locked') ?? false;

  /// Asks the phone to lock itself to this app, or to let go. Only school or
  /// family-managed phones let an app do this; on others she triple-clicks
  /// the side button, and this gives false.
  static Future<bool> lock(bool on) async => await _call<bool>('lock', on) ?? false;

  /// Notifications that call her back, each [seconds] after she left.
  static Future<void> callBack(List<({int seconds, String body})> lines) => _call<void>(
    'callBack',
    [
      for (final l in lines) {'seconds': l.seconds, 'body': l.body},
    ],
  );

  /// Takes back the call-back notifications once she has returned.
  static Future<void> cancelCallBack() => _call<void>('cancelCallBack');
}
