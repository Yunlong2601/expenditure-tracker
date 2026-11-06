import 'day.dart';
import 'l10n.dart';

/// A task asked for in chat, like "remind me at 8 to read" or
/// "每天晚上九点提醒我刷牙".
typedef TaskAsk = ({
  String title,
  DateTime day,
  int? minutes,
  Repeat repeat,
  bool remind,
});

const _weekdaysEn = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
const _weekdaysZh = '一二三四五六日';

/// Money talk stays with the money replies, never becomes a task.
const _moneyWords = ['spend', 'spent', 'money', 'dollar', r'$', '花钱', '钱', '账'];

/// "九" is 9, "十二" is 12, "三十" is 30; digits pass through.
int? _number(String s) {
  final d = int.tryParse(s);
  if (d != null) return d;
  const digits = {'零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};
  if (!s.contains('十')) return s.length == 1 ? digits[s] : null;
  final parts = s.split('十');
  final tens = parts[0].isEmpty ? 1 : digits[parts[0]];
  final ones = parts.length < 2 || parts[1].isEmpty ? 0 : digits[parts[1]];
  if (tens == null || ones == null) return null;
  return tens * 10 + ones;
}

/// The next [weekday] (1 Monday to 7 Sunday) from [today], today included.
DateTime _next(DateTime today, int weekday) =>
    DateTime(today.year, today.month, today.day + (weekday - today.weekday) % 7);

/// Reads a chat message that asks for a task, on the phone. Null when it
/// doesn't ask for one. A message asks when it starts with "add", "todo",
/// "new task", "添加", "待办" and the like, or says "remind me" / "提醒我".
TaskAsk? parseTaskAsk(String said, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final today = dayOf(at);
  var text = said.trim();
  final low = text.toLowerCase();
  if (text.isEmpty || _moneyWords.any(low.contains)) return null;

  final enStart = RegExp(
    r'^(?:please\s+|can you\s+|could you\s+)?(?:add(?: a)?(?: task| to-?do)?|(?:a |new )?(?:task|to-?do|to do)s?|new task)\s*[:,-]?\s+',
    caseSensitive: false,
  );
  final enRemind = RegExp(r'\b(?:please\s+)?remind me(?:\s+to)?\b', caseSensitive: false);
  final zhStart = RegExp(r'^(?:帮我)?(?:添加|加个|加一个|加一件|新任务|待办|任务)\s*[:：，,]?\s*');
  final zhRemind = RegExp(r'(?:帮我)?提醒我(?:一下)?');
  final remind = enRemind.hasMatch(text) || zhRemind.hasMatch(text);
  if (!remind && !enStart.hasMatch(text) && !zhStart.hasMatch(text)) return null;
  text = text
      .replaceFirst(enStart, '')
      .replaceFirst(zhStart, '')
      .replaceAll(enRemind, ' ')
      .replaceAll(zhRemind, ' ');

  // How it repeats, and on which weekday a weekly one starts.
  var repeat = Repeat.none;
  int? weekday;
  /// Takes out the first match [take] accepts, so it isn't in the title.
  String cutIf(RegExp r, bool Function(RegExpMatch m) take) {
    for (final m in r.allMatches(text)) {
      if (take(m)) return text.replaceRange(m.start, m.end, ' ');
    }
    return text;
  }

  /// Takes out the first match, after [on] reads it.
  String cut(RegExp r, void Function(RegExpMatch m) on) => cutIf(r, (m) {
    on(m);
    return true;
  });

  text = cut(
    RegExp(r'\bevery\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b', caseSensitive: false),
    (m) {
      repeat = Repeat.weekly;
      weekday = _weekdaysEn.indexOf(m[1]!.toLowerCase()) + 1;
    },
  );
  text = cut(RegExp(r'每(?:个)?(?:周|星期|礼拜)([一二三四五六日天])'), (m) {
    repeat = Repeat.weekly;
    weekday = m[1] == '天' ? 7 : _weekdaysZh.indexOf(m[1]!) + 1;
  });
  text = cut(RegExp(r'\b(?:every\s+weekday|on\s+weekdays|weekdays)\b|每个?工作日|工作日', caseSensitive: false), (_) => repeat = Repeat.weekdays);
  text = cut(RegExp(r'\b(?:every\s*day|daily|each\s+day)\b|每天|每日', caseSensitive: false), (_) => repeat = Repeat.daily);
  text = cut(RegExp(r'\b(?:every\s+week|weekly)\b|每周|每星期', caseSensitive: false), (_) => repeat = Repeat.weekly);

  // Which day.
  DateTime? day;
  var tonight = false;
  text = cut(RegExp(r'\b(?:the\s+)?day\s+after\s+tomorrow\b|后天', caseSensitive: false), (_) => day = today.add(const Duration(days: 2)));
  text = cut(RegExp(r'\btomorrow\b|明天', caseSensitive: false), (_) => day = DateTime(today.year, today.month, today.day + 1));
  text = cut(RegExp(r'\btonight\b|今晚', caseSensitive: false), (_) {
    day = today;
    tonight = true;
  });
  text = cut(RegExp(r'\btoday\b|今天', caseSensitive: false), (_) => day = today);
  text = cut(
    RegExp(r'\b(?:on\s+)?(?:(next)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b', caseSensitive: false),
    (m) {
      final d = _next(today, _weekdaysEn.indexOf(m[2]!.toLowerCase()) + 1);
      // "Next Monday" said on a Monday is a week away.
      day = m[1] != null && sameDay(d, today)
          ? DateTime(d.year, d.month, d.day + 7)
          : d;
    },
  );
  text = cut(RegExp(r'(下)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天])'), (m) {
    final wd = m[2] == '天' ? 7 : _weekdaysZh.indexOf(m[2]!) + 1;
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    day = m[1] != null
        ? DateTime(monday.year, monday.month, monday.day + 7 + wd - 1)
        : _next(today, wd);
  });

  // What time.
  int? minutes;
  text = cut(RegExp(r'\b(?:at|by|before)\s+noon\b|中午12点|中午十二点', caseSensitive: false), (_) => minutes = 12 * 60);
  if (minutes == null) {
    text = cutIf(
      RegExp(r'(?:\b(?:at|by|before|around)\s+)?\b(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?=\s|$|[,.!?])', caseSensitive: false),
      (m) {
        // A bare number needs "at", a colon or am/pm to be a time.
        final said = m[0]!.toLowerCase().trim();
        if (m[3] == null && m[2] == null && !RegExp(r'^(at|by|before|around)\b').hasMatch(said)) return false;
        var h = int.parse(m[1]!);
        final mm = int.tryParse(m[2] ?? '') ?? 0;
        if (h > 23 || mm > 59) return false;
        final mer = m[3]?.replaceAll('.', '').toLowerCase();
        if (mer == 'pm' && h < 12) h += 12;
        if (mer == 'am' && h == 12) h = 0;
        if (mer == null && h < 12 && (tonight || h <= 6)) h += 12;
        minutes = h * 60 + mm;
        return true;
      },
    );
  }
  if (minutes == null) {
    text = cutIf(
      RegExp(r'(早上|早晨|上午|中午|下午|傍晚|晚上|夜里)?\s*(\d{1,2}|[零一二两三四五六七八九十]{1,3})\s*[点點:：时]\s*(半|一刻|(\d{1,2}|[零一二三四五六七八九十]{1,3})\s*分?)?\s*(?:之前|以前|前)?'),
      (m) {
        var h = _number(m[2]!);
        if (h == null || h > 23) return false;
        final part = m[1];
        final mm = m[3] == '半' ? 30 : (m[3] == '一刻' ? 15 : (m[4] == null ? 0 : _number(m[4]!) ?? 0));
        if (const ['下午', '傍晚', '晚上', '夜里'].contains(part) && h < 12) h += 12;
        if (part == '中午' && h < 4) h += 12;
        if (part == null && h < 12 && (tonight || h <= 6)) h += 12;
        if (part == '早上' || part == '早晨' || part == '上午') {
          if (h == 12) h = 0;
        }
        minutes = h * 60 + mm;
        return true;
      },
    );
  }

  // A time already gone today, with no day said, means the next one:
  // 8 becomes 8 pm, or tomorrow at 8 when 8 pm has gone too.
  var on = day ?? (weekday == null ? today : _next(today, weekday!));
  if (weekday != null) on = _next(on, weekday!);
  final m0 = minutes;
  if (day == null && repeat == Repeat.none && m0 != null) {
    DateTime when(int m) => DateTime(today.year, today.month, today.day, m ~/ 60, m % 60);
    if (!when(m0).isAfter(at)) {
      if (m0 < 12 * 60 && when(m0 + 12 * 60).isAfter(at)) {
        minutes = m0 + 12 * 60;
      } else {
        on = DateTime(today.year, today.month, today.day + 1);
      }
    }
  }

  final title = _clean(text);
  if (title.isEmpty) return null;
  return (
    title: title,
    day: on,
    minutes: minutes,
    repeat: repeat,
    remind: remind && minutes != null,
  );
}

/// What's left once the asking words, day and time are gone.
String _clean(String s) {
  var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (var i = 0; i < 3; i++) {
    t = t
        .replaceFirst(RegExp(r'^(?:to|that|i need to|i have to|i should|me|and|then|please|，|,|:|：|-|要|去|得|该)\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*(?:to|on|at|for)?\s*(?:my|the)?\s*(?:to-?do\s*)?list\s*$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'[\s,，.。!！?？~～:：-]+$'), '')
        .replaceFirst(RegExp(r'\s+(?:for|on|by|at|before|from)$', caseSensitive: false), '')
        .trim();
  }
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

String _hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// The cat's answer once a task from chat is on the list.
String taskAskReply(TaskAsk a, {DateTime? now}) {
  final today = dayOf(now ?? DateTime.now());
  final m = a.minutes;
  final en = switch (a.repeat) {
    Repeat.daily => 'every day',
    Repeat.weekdays => 'every weekday',
    Repeat.weekly => 'every ${_weekdaysEn[a.day.weekday - 1][0].toUpperCase()}${_weekdaysEn[a.day.weekday - 1].substring(1)}',
    Repeat.none => sameDay(a.day, today)
        ? 'today'
        : sameDay(a.day, today.add(const Duration(days: 1)))
        ? 'tomorrow'
        : 'on ${dayMonth(a.day)}',
  };
  final cn = switch (a.repeat) {
    Repeat.daily => '每天',
    Repeat.weekdays => '每个工作日',
    Repeat.weekly => '每周${_weekdaysZh[a.day.weekday - 1]}',
    Repeat.none => sameDay(a.day, today)
        ? '今天'
        : sameDay(a.day, today.add(const Duration(days: 1)))
        ? '明天'
        : dayMonth(a.day),
  };
  return tr(
    'Added “${a.title}” $en${m == null ? '' : ' at ${_hhmm(m)}'}.'
        '${a.remind ? ' I’ll remind you.' : ''}',
    '加好啦：$cn${m == null ? '' : ' ${_hhmm(m)}'}「${a.title}」。'
        '${a.remind ? '到时候我会提醒你。' : ''}',
  );
}
