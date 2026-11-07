import 'package:intl/intl.dart';

import 'l10n.dart';

const _symbols = {
  'SGD': r'S$',
  'CNY': '¥',
  'USD': r'US$',
  'MYR': 'RM',
  'HKD': r'HK$',
  'JPY': 'JP¥',
  'THB': '฿',
  'KRW': '₩',
  'EUR': '€',
  'GBP': '£',
};

/// Currencies offered when typing an amount, most used first.
const currencies = ['SGD', 'MYR', 'CNY', 'USD', 'THB', 'JPY', 'KRW', 'HKD'];

String money(double amount, String currency) {
  final f = NumberFormat('#,##0.00');
  return '${_symbols[currency] ?? '$currency '}${f.format(amount)}';
}

String shortDate(DateTime d, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return tr('Today', '今天');
  if (diff == 1) return tr('Yesterday', '昨天');
  return dayMonth(d);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Small stand-in so this file has no Flutter dependency.
class DateUtils {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
