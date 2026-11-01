import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'format.dart';

/// One expense, as stored on the phone.
class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    this.merchant,
    this.category,
    this.paymentMethod,
    this.summary,
    this.receiptFile,
    this.receiptHash,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    amount: (j['amount'] as num).toDouble(),
    currency: j['currency'] as String,
    merchant: j['merchant'] as String?,
    category: j['category'] as String?,
    paymentMethod: j['payment_method'] as String?,
    summary: j['summary'] as String?,
    receiptFile: j['receipt_file'] as String?,
    receiptHash: j['receipt_hash'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final DateTime date;
  final double amount;
  final String currency;
  final String? merchant;
  final String? category;
  final String? paymentMethod;
  final String? summary;

  /// File name of the saved receipt image, inside the ledger's folder.
  final String? receiptFile;

  /// Fingerprint of the receipt image, to spot the same picture sent twice.
  final String? receiptHash;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': isoDate(date),
    'amount': amount,
    'currency': currency,
    if (merchant != null) 'merchant': merchant,
    if (category != null) 'category': category,
    if (paymentMethod != null) 'payment_method': paymentMethod,
    if (summary != null) 'summary': summary,
    if (receiptFile != null) 'receipt_file': receiptFile,
    if (receiptHash != null) 'receipt_hash': receiptHash,
    'created_at': createdAt.toIso8601String(),
  };
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
  const Overview({required this.totals, required this.byCategory, required this.recent});
  final List<Money> totals;
  final List<CategoryTotal> byCategory;
  final List<Expense> recent;
}

/// All expenses, kept in one JSON file in the app's private folder on the
/// phone, with receipt images next to it. Nothing leaves the phone.
/// iPhone backups (iCloud or Mac) include this folder.
class Ledger {
  Ledger(this.dir);

  final Directory dir;
  final List<Expense> _items = [];
  bool _loaded = false;

  File get _file => File('${dir.path}/expenses.json');
  Directory get _receipts => Directory('${dir.path}/receipts');

  List<Expense> get all => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    if (!await _file.exists()) return;
    final raw = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    _items
      ..clear()
      ..addAll([for (final e in raw['expenses'] as List) Expense.fromJson(e as Map<String, dynamic>)]);
  }

  Future<void> _save() async {
    await dir.create(recursive: true);
    // Write to a temp file and rename, so a crash mid-write can't corrupt the ledger.
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'version': 1,
        'expenses': [for (final e in _items) e.toJson()],
      }),
      flush: true,
    );
    await tmp.rename(_file.path);
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  Future<Expense> add({
    required double amount,
    required String currency,
    DateTime? date,
    String? merchant,
    String? category,
    String? paymentMethod,
    String? summary,
    Uint8List? receipt,
  }) async {
    await load();
    final id = _newId();
    String? fileName;
    if (receipt != null) {
      await _receipts.create(recursive: true);
      fileName = 'receipts/$id.jpg';
      await File('${dir.path}/$fileName').writeAsBytes(receipt, flush: true);
    }
    final now = DateTime.now();
    final e = Expense(
      id: id,
      date: date ?? now,
      amount: (amount * 100).round() / 100,
      currency: currency.toUpperCase(),
      merchant: _clean(merchant),
      category: _clean(category),
      paymentMethod: _clean(paymentMethod),
      summary: _clean(summary),
      receiptFile: fileName,
      receiptHash: receipt == null ? null : fingerprint(receipt),
      createdAt: now,
    );
    _items.add(e);
    await _save();
    return e;
  }

  /// Changes an expense's details. Its receipt photo stays attached.
  Future<Expense?> update(
    String id, {
    required double amount,
    required String currency,
    required DateTime date,
    String? merchant,
    String? category,
  }) async {
    await load();
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    final old = _items[i];
    final e = Expense(
      id: old.id,
      date: date,
      amount: (amount * 100).round() / 100,
      currency: currency.toUpperCase(),
      merchant: _clean(merchant),
      category: _clean(category),
      paymentMethod: old.paymentMethod,
      summary: old.summary,
      receiptFile: old.receiptFile,
      receiptHash: old.receiptHash,
      createdAt: old.createdAt,
    );
    _items[i] = e;
    await _save();
    return e;
  }

  Future<void> delete(String id) async {
    await load();
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _items.removeAt(i);
    await _save();
    if (e.receiptFile != null) {
      final f = File('${dir.path}/${e.receiptFile}');
      if (await f.exists()) await f.delete();
    }
  }

  /// Was this already logged? True for the very same picture sent again, or
  /// the same amount at the same shop logged in the last 10 minutes. Buying
  /// the same bubble tea twice in a day is normal and doesn't ask.
  bool isDuplicate({
    required double amount,
    required String currency,
    String? merchant,
    Uint8List? image,
    DateTime? now,
  }) {
    final hash = image == null ? null : fingerprint(image);
    final since = (now ?? DateTime.now()).subtract(const Duration(minutes: 10));
    return _items.any(
      (e) =>
          (hash != null && e.receiptHash == hash) ||
          ((e.amount - amount).abs() < 0.005 &&
              e.currency == currency.toUpperCase() &&
              (e.merchant ?? '').toLowerCase() == (merchant ?? '').toLowerCase() &&
              e.createdAt.isAfter(since)),
    );
  }

  /// A short fingerprint of some bytes (FNV-1a plus the length).
  static String fingerprint(List<int> bytes) {
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${bytes.length.toRadixString(36)}-${h.toRadixString(36)}';
  }

  File? receiptFor(Expense e) => e.receiptFile == null ? null : File('${dir.path}/${e.receiptFile}');

  List<String> categories() {
    final seen = <String>{};
    for (final e in _items.reversed) {
      if (e.category != null) seen.add(e.category!);
    }
    return seen.toList();
  }

  Overview overview({DateTime? now, int recent = 30}) {
    final today = now ?? DateTime.now();
    final monthItems = _items.where((e) => e.date.year == today.year && e.date.month == today.month);
    final totals = <String, double>{};
    final byCat = <(String, String), double>{};
    for (final e in monthItems) {
      totals[e.currency] = (totals[e.currency] ?? 0) + e.amount;
      final k = (e.category ?? 'Other', e.currency);
      byCat[k] = (byCat[k] ?? 0) + e.amount;
    }
    final sorted = [..._items]
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
      });
    return Overview(
      totals: [for (final t in totals.entries) Money(t.key, t.value)]..sort((a, b) => b.amount.compareTo(a.amount)),
      byCategory: [for (final c in byCat.entries) CategoryTotal(c.key.$1, c.key.$2, c.value)]
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      recent: sorted.take(recent).toList(),
    );
  }

  /// Spreadsheet-friendly copy of everything, for backups or Excel.
  String toCsv() {
    String q(String? s) => '"${(s ?? '').replaceAll('"', '""')}"';
    final rows = [..._items]..sort((a, b) => a.date.compareTo(b.date));
    return [
      'date,amount,currency,shop,category,paid_with,what',
      for (final e in rows)
        [
          isoDate(e.date),
          e.amount.toStringAsFixed(2),
          e.currency,
          q(e.merchant),
          q(e.category),
          q(e.paymentMethod),
          q(e.summary),
        ].join(','),
    ].join('\n');
  }

  static String? _clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
