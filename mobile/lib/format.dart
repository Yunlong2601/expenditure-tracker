import 'package:intl/intl.dart';

const _symbols = {
  'SGD': r'S$',
  'CNY': '¥',
  'USD': r'US$',
  'MYR': 'RM',
  'HKD': r'HK$',
  'JPY': '¥',
  'EUR': '€',
  'GBP': '£',
};

String money(double amount, String currency) {
  final f = NumberFormat('#,##0.00');
  return '${_symbols[currency] ?? '$currency '}${f.format(amount)}';
}

String shortDate(DateTime d, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM').format(d);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Small stand-in so this file has no Flutter dependency.
class DateUtils {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
