import 'dart:ui' as ui;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';

import 'prefs.dart';

/// The phone's own language code, such as "en" or "zh". Tests can swap it.
String Function() phoneLanguage = () => ui.PlatformDispatcher.instance.locale.languageCode;

/// Chinese when picked in Me → Language, or, until a language is picked,
/// when the phone itself is set to Chinese. Otherwise English.
bool get zh => switch (Prefs.current.language) {
  'zh' => true,
  'en' => false,
  _ => phoneLanguage() == 'zh',
};

/// The text in the app's language.
String tr(String en, String zh_) => zh ? zh_ : en;

/// The app's name: Purrpose in English, 喵学伴 ("cat study buddy") in
/// Chinese.
String get appName => tr('Purrpose', '喵学伴');

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

/// "Nov 2026" or "2026年11月".
String monthYear(DateTime d) =>
    zh ? '${d.year}年${d.month}月' : '${_monthsEn[d.month - 1]} ${d.year}';

/// "November" or "11月".
String monthLong(DateTime d) => zh ? '${d.month}月' : _monthsLongEn[d.month - 1];

/// "5 Nov" or "11月5日".
String dayMonth(DateTime d) =>
    zh ? '${d.month}月${d.day}日' : '${d.day} ${_monthsEn[d.month - 1]}';

/// "Thu, 5 Nov" or "11月5日 周四": the weekday where each language puts it.
String dayMonthWeekday(DateTime d) => zh
    ? '${dayMonth(d)} ${weekdayShort(d)}'
    : '${weekdayShort(d)}, ${dayMonth(d)}';

/// [dayMonthWeekday] with the year when it isn't this year: "Thu, 5 Nov
/// 2027" or "2027年11月5日 周四".
String dateWithWeekday(DateTime d, {DateTime? now}) {
  if (d.year == (now ?? DateTime.now()).year) return dayMonthWeekday(d);
  return zh ? '${d.year}年${dayMonthWeekday(d)}' : '${dayMonthWeekday(d)} ${d.year}';
}

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

/// The time as the phone shows it: "9:30 AM", or "09:30" with the 24-hour
/// clock on, the same as task times.
String clockAt(BuildContext context, DateTime d) =>
    TimeOfDay.fromDateTime(d).format(context);

/// "09:30".
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "1 day", "3 days": a count with the English word in the right form.
String count(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';
