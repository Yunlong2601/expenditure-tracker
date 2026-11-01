import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Something went wrong talking to the receipt scanner. [message] is
/// already written for the person using the app.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    this.merchant,
    this.category,
    this.account,
    this.hasReceipt = false,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: '${j['id']}',
    date: DateTime.parse(j['date'] as String),
    amount: double.parse('${j['amount']}'),
    currency: j['currency'] as String,
    merchant: j['merchant'] as String?,
    category: j['category'] as String?,
    account: j['account'] as String?,
    hasReceipt: j['has_receipt'] as bool? ?? false,
  );

  final String id;
  final DateTime date;
  final double amount;
  final String currency;
  final String? merchant;
  final String? category;
  final String? account;
  final bool hasReceipt;
}

class Money {
  const Money(this.currency, this.amount);
  final String currency;
  final double amount;
}

class CategoryTotal {
  const CategoryTotal(this.category, this.currency, this.amount);
  final String category;
  final String currency;
  final double amount;
}

class Overview {
  const Overview({required this.month, required this.totals, required this.byCategory, required this.recent});

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
    month: j['month'] as String,
    totals: [for (final t in j['totals'] as List) Money(t['currency'] as String, double.parse('${t['total']}'))],
    byCategory: [
      for (final c in j['by_category'] as List)
        CategoryTotal(c['category'] as String, c['currency'] as String, double.parse('${c['total']}')),
    ],
    recent: [for (final e in j['recent'] as List) Expense.fromJson(e as Map<String, dynamic>)],
  );

  final String month;
  final List<Money> totals;
  final List<CategoryTotal> byCategory;
  final List<Expense> recent;
}

/// What the scanner read from a receipt.
class ReadReceipt {
  const ReadReceipt({
    this.merchant,
    this.total,
    this.currency,
    this.date,
    this.category,
    this.paymentMethod,
    this.summary,
    this.confidence = 'low',
    this.problem,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> j) => ReadReceipt(
    merchant: j['merchant'] as String?,
    total: j['total'] as String?,
    currency: j['currency'] as String?,
    date: j['date'] as String?,
    category: j['category'] as String?,
    paymentMethod: j['payment_method'] as String?,
    summary: j['summary'] as String?,
    confidence: j['confidence'] as String? ?? 'low',
    problem: j['problem'] as String?,
  );

  final String? merchant;
  final String? total;
  final String? currency;
  final String? date;
  final String? category;
  final String? paymentMethod;
  final String? summary;
  final String confidence;
  final String? problem;
}

class ScanResult {
  const ScanResult({
    required this.saved,
    required this.message,
    this.needsReview = false,
    this.receipt,
    this.account,
    this.accounts = const [],
    this.categories = const [],
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
    saved: j['saved'] as bool? ?? false,
    message: j['message'] as String? ?? '',
    needsReview: j['needs_review'] as bool? ?? false,
    receipt: j['receipt'] == null ? null : ReadReceipt.fromJson(j['receipt'] as Map<String, dynamic>),
    account: j['account'] as String?,
    accounts: [for (final a in (j['accounts'] as List? ?? const [])) '$a'],
    categories: [for (final c in (j['categories'] as List? ?? const [])) '$c'],
  );

  final bool saved;
  final String message;
  final bool needsReview;
  final ReadReceipt? receipt;
  final String? account;
  final List<String> accounts;
  final List<String> categories;
}

/// Corrected fields from the review sheet, or a hand-typed expense.
class ExpenseFields {
  const ExpenseFields({
    required this.total,
    this.currency,
    this.merchant,
    this.category,
    this.date,
    this.account,
    this.summary,
  });

  final String total;
  final String? currency;
  final String? merchant;
  final String? category;
  final String? date;
  final String? account;
  final String? summary;

  Map<String, String> toMap() => {
    'total': total,
    if (currency?.isNotEmpty ?? false) 'currency': currency!,
    if (merchant?.isNotEmpty ?? false) 'merchant': merchant!,
    if (category?.isNotEmpty ?? false) 'category': category!,
    if (date?.isNotEmpty ?? false) 'date': date!,
    if (account?.isNotEmpty ?? false) 'account': account!,
    if (summary?.isNotEmpty ?? false) 'summary': summary!,
  };
}

/// Client for the receipt scanner add-on that sits next to Firefly III.
class ScannerApi {
  ScannerApi({required String baseUrl, required this.apiKey, http.Client? client})
    : base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _http = client ?? http.Client();

  final Uri base;
  final String apiKey;
  final http.Client _http;

  static const _timeout = Duration(seconds: 90);

  Map<String, String> get _headers => {'X-Api-Key': apiKey, 'Accept': 'application/json'};

  Future<Overview> overview() async {
    final r = await _send(() => _http.get(base.resolve('api/expenses'), headers: _headers));
    return Overview.fromJson(_decode(r));
  }

  /// Send a photo or screenshot. With no [fields] the server reads it and
  /// saves it if it is confident; with [fields] it saves those values.
  Future<ScanResult> scan(Uint8List image, {String filename = 'receipt.jpg', ExpenseFields? fields}) async {
    final req = http.MultipartRequest('POST', base.resolve('api/receipt'))
      ..headers.addAll(_headers)
      ..files.add(http.MultipartFile.fromBytes('file', image, filename: filename));
    if (fields != null) req.fields.addAll(fields.toMap());
    final r = await _send(() async => http.Response.fromStream(await _http.send(req)));
    return ScanResult.fromJson(_decode(r, okStatuses: const {200, 400, 409, 502}));
  }

  Future<ScanResult> addManual(ExpenseFields fields) async {
    final r = await _send(
      () => _http.post(
        base.resolve('api/expense'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(fields.toMap()),
      ),
    );
    return ScanResult.fromJson(_decode(r, okStatuses: const {200, 409, 422, 502}));
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException("Can't reach your server. Check the address in Settings, and that you're online.");
    }
  }

  Map<String, dynamic> _decode(http.Response r, {Set<int> okStatuses = const {200}}) {
    if (r.statusCode == 401) {
      throw ApiException('The access key is wrong. Check it in Settings.');
    }
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    if (!okStatuses.contains(r.statusCode) || body == null) {
      final msg = body?['message'] ?? body?['detail'];
      throw ApiException(msg is String ? msg : 'The server had a problem (${r.statusCode}).');
    }
    return body;
  }
}
