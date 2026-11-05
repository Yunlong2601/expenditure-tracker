import 'package:flutter/widgets.dart';

import 'prefs.dart';

/// Chinese only when picked in Me → Language. English is the default.
bool get zh => Prefs.current.language == 'zh';

/// The text in the app's language.
String tr(String en, String zh_) => zh ? zh_ : en;

/// Redraws every screen, open sheets included, after the language changes.
void redrawAll() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) mark(root);
}

const _weekdaysZh = ['一', '二', '三', '四', '五', '六', '日'];
const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _monthsLongEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// One-letter (English) or one-character (Chinese) weekday headers, Monday first.
List<String> get weekdayHeads =>
    zh ? _weekdaysZh : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "Thu" or "周四".
String weekdayShort(DateTime d) =>
    zh ? '周${_weekdaysZh[d.weekday - 1]}' : _weekdaysEn[d.weekday - 1];

/// "Nov 2026" or "2026 年 11 月".
String monthYear(DateTime d) =>
    zh ? '${d.year} 年 ${d.month} 月' : '${_monthsEn[d.month - 1]} ${d.year}';

/// "November" or "11月".
String monthLong(DateTime d) => zh ? '${d.month}月' : _monthsLongEn[d.month - 1];

/// "5 Nov" or "11月5日".
String dayMonth(DateTime d) =>
    zh ? '${d.month}月${d.day}日' : '${d.day} ${_monthsEn[d.month - 1]}';

/// "5 Nov, Thu" or "11月5日 周四".
String dayMonthWeekday(DateTime d) => zh
    ? '${dayMonth(d)} ${weekdayShort(d)}'
    : '${dayMonth(d)}, ${weekdayShort(d)}';

/// "Thursday, 5 Nov" or "11月5日 周四".
String longDay(DateTime d) {
  if (zh) return dayMonthWeekday(d);
  const long = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${long[d.weekday - 1]}, ${dayMonth(d)}';
}

/// "5 Nov 2026" or "2026年11月5日".
String fullDate(DateTime d) =>
    zh ? '${d.year}年${dayMonth(d)}' : '${dayMonth(d)} ${d.year}';

/// "09:30".
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
