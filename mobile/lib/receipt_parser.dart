import 'reader.dart';

/// One line of text found in the image, top to bottom. [height] is the text
/// height as a fraction of the image height, so big text (the amount on a
/// payment screenshot) can be told apart from small print.
class TextLine {
  const TextLine(this.text, [this.height = 0]);
  final String text;
  final double height;
  @override
  String toString() => text;
}

/// Turns the text the phone read off a receipt or payment screenshot into an
/// expense. Everything here is guesswork from patterns, so it reports how sure
/// it is and the app asks the person whenever it isn't.
ReadReceipt parseReceipt(List<TextLine> raw, {List<String> categories = const [], DateTime? now}) {
  now ??= DateTime.now();
  final lines = [
    for (final l in raw)
      if (_normalize(l.text).trim().isNotEmpty) TextLine(_normalize(l.text).trim(), l.height),
  ];
  final all = lines.map((l) => l.text).join('\n');
  final lower = all.toLowerCase();

  final found = _findTotal(lines);
  final merchant = _findMerchant(lines, found?.line);
  final currency = found?.amount.currency ?? _currencyFromText(all, lower);
  final category = _category((merchant ?? '').toLowerCase(), categories) ?? _category(lower, categories);

  if (found == null) {
    return ReadReceipt(
      isReceipt: lines.isNotEmpty,
      merchant: merchant,
      currency: currency,
      date: _findDate(lines, now),
      category: category,
      paymentMethod: _paymentMethod(lower),
      problem: lines.isEmpty ? 'there is no text in this picture' : null,
    );
  }
  return ReadReceipt(
    merchant: merchant,
    total: found.amount.value,
    currency: currency,
    date: _findDate(lines, now),
    category: category,
    paymentMethod: _paymentMethod(lower),
    confidence: found.confidence,
    problem: found.confidence == 'low' ? 'please check the amount' : null,
  );
}

String _normalize(String s) => s
    .replaceAll('：', ':')
    .replaceAll('．', '.')
    .replaceAll('，', ',')
    .replaceAll('−', '-')
    .replaceAll('—', '-')
    .replaceAll('（', '(')
    .replaceAll('）', ')')
    .replaceAll(' ', ' ');

class _Amount {
  const _Amount(this.value, this.currency, {required this.signed, required this.marked});
  final double value;
  final String? currency;

  /// Had a minus sign, as on Alipay and WeChat Pay success screens.
  final bool signed;

  /// Had a currency symbol or code.
  final bool marked;
}

class _Found {
  const _Found(this.amount, this.line, this.confidence);
  final _Amount amount;
  final int line;
  final String confidence;
}

final _amountRe = RegExp(
  r'(-\s*)?(S\$|US\$|SGD|USD|CNY|RMB|MYR|RM|\$|¥|￥)?\s*(?<![\d.,:/])((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)(?![\d.,:/%])(\s*元)?',
  caseSensitive: false,
);

String? _currencyCode(String? symbol, bool yuan) {
  if (yuan) return 'CNY';
  switch (symbol?.toUpperCase()) {
    case 'S\$' || 'SGD' || '\$':
      return 'SGD';
    case 'US\$' || 'USD':
      return 'USD';
    case 'CNY' || 'RMB' || '¥' || '￥':
      return 'CNY';
    case 'MYR' || 'RM':
      return 'MYR';
  }
  return null;
}

/// Money amounts on a line. Bare whole numbers (quantities, phone numbers,
/// receipt numbers) only count when they carry a currency symbol.
List<_Amount> _amounts(String line) {
  final out = <_Amount>[];
  for (final m in _amountRe.allMatches(line)) {
    final symbol = m.group(2);
    final yuan = m.group(4) != null;
    final number = m.group(3)!;
    final hasCents = RegExp(r'\.\d{2}$').hasMatch(number);
    // "RM" glued to a word ("FORM 2.50") is not ringgit.
    final glued =
        symbol != null &&
        symbol.toUpperCase() == 'RM' &&
        m.start > 0 &&
        RegExp(r'[A-Za-z]').hasMatch(line[m.start - 1]);
    final marked = (symbol != null && !glued) || yuan;
    if (!hasCents && !marked) continue;
    final value = double.tryParse(number.replaceAll(',', ''));
    if (value == null || value <= 0 || value > 100000) continue;
    out.add(_Amount(value, glued ? null : _currencyCode(symbol, yuan), signed: m.group(1) != null, marked: marked));
  }
  return out;
}

const _strongTotal = [
  'grand total',
  'total amount',
  'amount paid',
  'total paid',
  'net total',
  'nett total',
  'total due',
  'amount due',
  'total payable',
  'total (sgd)',
  'total sgd',
  'payment amount',
  'you paid',
  '实付',
  '实收',
  '应付',
  '应收',
  '合计',
  '总计',
  '总额',
  '支付金额',
  '付款金额',
  '消费金额',
  '交易金额',
];
const _weakTotal = ['total', 'nett', 'amount', 'paid', 'payment', '金额'];
const _notTotal = [
  'subtotal',
  'sub total',
  'sub-total',
  'total qty',
  'total quantity',
  'total item',
  'no. of item',
  'saving',
  'change',
  'service charge',
  'svc chg',
  'rounding',
  'discount',
  'tendered',
  'balance',
  'points',
  'cashback',
  '找零',
  '优惠',
  '折扣',
  '余额',
  '积分',
  '数量',
];
final _taxRe = RegExp(r'\b(gst|tax|vat)\b|税');

bool _excluded(String l) =>
    _notTotal.any(l.contains) || (_taxRe.hasMatch(l) && !l.contains('incl') && !l.contains('含'));

/// Amount on this line, or on the next one when the label and the number were
/// read as separate lines.
(_Amount, int)? _amountNear(List<TextLine> lines, int i) {
  final here = _amounts(lines[i].text);
  if (here.isNotEmpty) return (here.last, i);
  if (i + 1 < lines.length && !_excluded(lines[i + 1].text.toLowerCase())) {
    final next = _amounts(lines[i + 1].text);
    if (next.isNotEmpty) return (next.first, i);
  }
  return null;
}

_Found? _findTotal(List<TextLine> lines) {
  // 1. Payment screenshots: the amount is by far the biggest text.
  final heights = [for (final l in lines) l.height]..sort();
  if (lines.length >= 3 && heights.last > 0) {
    final median = heights[heights.length ~/ 2];
    var best = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_amounts(lines[i].text).isEmpty) continue;
      if (best < 0 || lines[i].height > lines[best].height) best = i;
    }
    if (best >= 0 && lines[best].height >= median * 1.6) {
      return _Found(_amounts(lines[best].text).first, best, 'high');
    }
  }

  // 2. A labelled total; the last one wins because the final figure is printed last.
  for (final (words, confidence) in [(_strongTotal, 'high'), (_weakTotal, 'medium')]) {
    _Found? hit;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].text.toLowerCase();
      if (!words.any(l.contains) || _excluded(l)) continue;
      final a = _amountNear(lines, i);
      if (a != null) hit = _Found(a.$1, a.$2, confidence);
    }
    if (hit != null) return hit;
  }

  // 3. One amount with a minus sign or currency symbol, as on payment screens.
  final marked = <(_Amount, int)>[
    for (var i = 0; i < lines.length; i++)
      if (!_excluded(lines[i].text.toLowerCase()))
        for (final a in _amounts(lines[i].text))
          if (a.signed || a.marked) (a, i),
  ];
  if (marked.isNotEmpty && marked.map((m) => m.$1.value).toSet().length == 1) {
    return _Found(marked.first.$1, marked.first.$2, 'medium');
  }

  // 4. Last resort: the largest amount. Usually right, but ask.
  _Found? largest;
  for (var i = 0; i < lines.length; i++) {
    if (_excluded(lines[i].text.toLowerCase())) continue;
    for (final a in _amounts(lines[i].text)) {
      if (largest == null || a.value > largest.amount.value) {
        largest = _Found(a, i, 'low');
      }
    }
  }
  return largest;
}

String _currencyFromText(String all, String lower) {
  if (RegExp(r'S\$|\bSGD\b').hasMatch(all)) return 'SGD';
  if (RegExp(r'[¥￥元]|\bRMB\b|\bCNY\b').hasMatch(all)) return 'CNY';
  if (RegExp(r'\bMYR\b|\bRM\s?\d').hasMatch(all) || lower.contains('malaysia')) {
    return 'MYR';
  }
  if (RegExp(r'US\$|\bUSD\b').hasMatch(all)) return 'USD';
  if (RegExp(r'singapore|\bgst\b|paynow|grabpay|\bnets\b|\buen\b').hasMatch(lower)) {
    return 'SGD';
  }
  if (RegExp(r'[一-鿿]').allMatches(all).length >= 6) return 'CNY';
  return 'SGD';
}

final _monthNames = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};
const _mon = r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?';

DateTime? _findDate(List<TextLine> lines, DateTime now) {
  DateTime? valid(int y, int m, int d, {bool guessYear = false}) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    var date = DateTime(y, m, d);
    if (date.month != m) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (guessYear && date.isAfter(today)) date = DateTime(y - 1, m, d);
    if (date.isAfter(today.add(const Duration(days: 1)))) return null;
    if (date.isBefore(today.subtract(const Duration(days: 3 * 366)))) {
      return null;
    }
    return date;
  }

  for (final line in lines) {
    final l = line.text.toLowerCase();
    // 2026-10-28, 2026/10/28, 2026.10.28, 2026年10月28日
    var m = RegExp(r'(?<!\d)(20\d{2})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})(?!\d)').firstMatch(l);
    if (m != null) {
      final d = valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) return d;
    }
    // 28/10/2026, 28-10-26: Singapore writes the day first.
    m = RegExp(r'(?<![\d.])(\d{1,2})[/\-.](\d{1,2})[/\-.](20\d{2}|\d{2})(?![\d.])').firstMatch(l);
    if (m != null) {
      var (a, b) = (int.parse(m[1]!), int.parse(m[2]!));
      if (b > 12 && a <= 12) (a, b) = (b, a);
      final d = valid(int.parse(m[3]!), b, a);
      if (d != null) return d;
    }
    // 28 Oct 2026, 28 October
    m = RegExp('(?<!\\d)(\\d{1,2})(?:st|nd|rd|th)?\\s*-?$_mon\\s*-?,?\\s*(20\\d{2})?\\b').firstMatch(l);
    if (m != null) {
      final d = valid(
        m[3] != null ? int.parse(m[3]!) : now.year,
        _monthNames[m[2]]!,
        int.parse(m[1]!),
        guessYear: m[3] == null,
      );
      if (d != null) return d;
    }
    // Oct 28, 2026
    m = RegExp('\\b$_mon\\s+(\\d{1,2})(?!\\d)(?:st|nd|rd|th)?,?\\s*(20\\d{2})?').firstMatch(l);
    if (m != null) {
      final d = valid(
        m[3] != null ? int.parse(m[3]!) : now.year,
        _monthNames[m[1]]!,
        int.parse(m[2]!),
        guessYear: m[3] == null,
      );
      if (d != null) return d;
    }
    // 10月28日
    m = RegExp(r'(?<!\d)(\d{1,2})月(\d{1,2})日').firstMatch(l);
    if (m != null) {
      final d = valid(now.year, int.parse(m[1]!), int.parse(m[2]!), guessYear: true);
      if (d != null) return d;
    }
  }
  return null;
}

final _merchantLabel = RegExp(
  r'^(merchant(?: name)?|paid to|pay to|payee|recipient|to|收款方|收款人|商户名称|商户全称|商户|商家|对方账户|交易对方)(?![A-Za-z])\s*:?\s*(.*)$',
  caseSensitive: false,
);
final _notMerchant = RegExp(
  r'^\d{1,2}:\d{2}|receipt|invoice|payment|success|transaction|details|order|welcome|reg\.? no|\buen\b|\btel\b|phone|\bfax\b|'
  r'www\.|http|@|total|thank|cashier|\btable\b|\bdate\b|\btime\b|\bpax\b|\bslip\b|'
  r'支付成功|交易成功|付款成功|账单详情|订单|交易详情|已支付|当前状态',
  caseSensitive: false,
);

bool _looksLikeName(String s) {
  if (s.length < 2 || s.length > 48) return false;
  if (_notMerchant.hasMatch(s) || _amounts(s).isNotEmpty) return false;
  final letters = RegExp(r'[A-Za-z一-鿿]').allMatches(s).length;
  final digits = RegExp(r'\d').allMatches(s).length;
  return letters >= 2 && digits <= letters;
}

String _cleanName(String s) => s.replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}).]+$', unicode: true), '');

String? _findMerchant(List<TextLine> lines, int? amountLine) {
  for (var i = 0; i < lines.length; i++) {
    final m = _merchantLabel.firstMatch(lines[i].text);
    if (m == null) continue;
    final value = m[2]!.trim();
    if (value.isNotEmpty && _looksLikeName(value)) return _cleanName(value);
    if (value.isEmpty && i + 1 < lines.length && _looksLikeName(lines[i + 1].text)) {
      return _cleanName(lines[i + 1].text);
    }
  }
  // On payment screens the payee sits just above the big amount.
  if (amountLine != null && amountLine > 0 && amountLine <= 6) {
    for (var i = amountLine - 1; i >= 0 && i >= amountLine - 2; i--) {
      if (_looksLikeName(lines[i].text)) return _cleanName(lines[i].text);
    }
  }
  // On printed receipts the shop name is at the top.
  for (final l in lines.take(6)) {
    if (_looksLikeName(l.text)) return _cleanName(l.text);
  }
  return null;
}

String? _paymentMethod(String l) {
  if (l.contains('alipay') || l.contains('支付宝')) return 'Alipay';
  if (l.contains('wechat') || l.contains('微信')) return 'WeChat Pay';
  if (l.contains('paynow')) return 'PayNow';
  if (l.contains('grabpay')) return 'GrabPay';
  if (RegExp(r'\b(visa|mastercard|master card|amex|nets|contactless|credit|debit|apple pay)\b').hasMatch(l)) {
    return 'card';
  }
  if (RegExp(r'\bcash\b|现金').hasMatch(l)) return 'cash';
  return null;
}

const _categoryWords = <String, List<String>>{
  // Checked before food, so tea shops land here rather than under food.
  'Bubble tea': [
    'bubble tea',
    'milk tea',
    'koi',
    'liho',
    'chicha',
    'mixue',
    'heytea',
    'gong cha',
    'playmade',
    'each a cup',
    'tiger sugar',
    'chagee',
    'partea',
    'r&b tea',
    'sharetea',
    '喜茶',
    '奶茶',
    '霸王茶姬',
    '蜜雪',
  ],
  'Snacks': [
    '7-eleven',
    '7 eleven',
    'cheers',
    'old chang kee',
    'llaollao',
    'polar puffs',
    'ice cream',
    'snack',
    'candy',
    '零食',
    '便利店',
  ],
  'Stationery': ['popular', 'stationery', 'smiggle', 'typo', 'kinokuniya', 'bookstore', 'books', '文具', '书店'],
  'Food & drink': [
    'kopi',
    'coffee',
    'cafe',
    'café',
    'restaurant',
    'food',
    'kitchen',
    'bakery',
    'toast',
    'ya kun',
    'mcdonald',
    'kfc',
    'starbucks',
    'luckin',
    'hawker',
    'kopitiam',
    'eating house',
    'burger',
    'pizza',
    'noodle',
    'dim sum',
    'bak kut teh',
    'chicken rice',
    'nasi',
    'mee',
    'prata',
    'sushi',
    'ramen',
    'bistro',
    'bar & grill',
    'foodpanda',
    'deliveroo',
    'grabfood',
    'meituan',
    '咖啡',
    '餐',
    '饭',
    '面',
    '茶',
    '奶',
    '食',
    '酒楼',
    '美团',
    '饿了么',
    '瑞幸',
    '麦当劳',
    '肯德基',
  ],
  'Groceries': [
    'ntuc',
    'fairprice',
    'cold storage',
    'sheng siong',
    'giant',
    'donki',
    'redmart',
    'supermarket',
    'market',
    'prime',
    'hao mart',
    'scarlett',
    '超市',
    '盒马',
    '生鲜',
    '菜',
  ],
  'Transport': [
    'grab',
    'gojek',
    'comfortdelgro',
    'cdg',
    'taxi',
    'cab',
    'mrt',
    'smrt',
    'sbs transit',
    'ez-link',
    'simplygo',
    'tada',
    'ryde',
    'zig',
    'parking',
    'petrol',
    'esso',
    'caltex',
    'shell',
    'sinopec',
    'didi',
    'uber',
    '滴滴',
    '地铁',
    '公交',
    '出租',
    '加油',
    '高铁',
    '12306',
    '打车',
  ],
  'Shopping': [
    'shopee',
    'lazada',
    'taobao',
    'tmall',
    'amazon',
    'uniqlo',
    'ikea',
    'daiso',
    'muji',
    'decathlon',
    'zara',
    'h&m',
    'courts',
    'challenger',
    'best denki',
    '淘宝',
    '天猫',
    '京东',
    '拼多多',
  ],
  'Bills': [
    'singtel',
    'starhub',
    'm1 ',
    'simba',
    'circles',
    'sp group',
    'sp services',
    'insurance',
    'town council',
    'utilities',
    'electric',
    'phone bill',
    '电费',
    '水费',
    '话费',
    '燃气',
    '物业',
  ],
  'Fun': [
    'cinema',
    'golden village',
    'shaw theatres',
    'cathay',
    'netflix',
    'spotify',
    'disney',
    'movie',
    'karaoke',
    'teo heng',
    'klook',
    'sentosa',
    'zoo',
    '电影',
    'ktv',
    '门票',
  ],
  'Health': [
    'guardian',
    'watsons',
    'clinic',
    'pharmacy',
    'dental',
    'hospital',
    'polyclinic',
    'medical',
    'unity',
    '药',
    '医院',
    '诊所',
  ],
};

String? _category(String text, List<String> existing) {
  for (final MapEntry(key: name, value: words) in _categoryWords.entries) {
    // "grab" alone means a ride; GrabFood and GrabMart are food and groceries.
    final hit = words.any((w) {
      if (w == 'grab') return RegExp(r'grab(?!food|mart|pay)').hasMatch(text);
      if (RegExp(r'^[a-z ]+$').hasMatch(w) && w.length <= 4) {
        return RegExp('\\b${RegExp.escape(w.trim())}\\b').hasMatch(text);
      }
      return text.contains(w);
    });
    if (hit) {
      return existing.firstWhere((c) => c.toLowerCase() == name.toLowerCase(), orElse: () => name);
    }
  }
  return null;
}
