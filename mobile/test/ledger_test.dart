import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/ledger.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('ledger'));
  tearDown(() async => dir.delete(recursive: true));

  test('saves to disk with the receipt image and reloads', () async {
    final l = Ledger(dir);
    final e = await l.add(
      amount: 7.4,
      currency: 'sgd',
      merchant: ' Ya Kun ',
      category: 'Food & drink',
      receipt: Uint8List.fromList([0xff, 0xd8, 1]),
      date: DateTime(2026, 11, 1),
    );
    expect(e.currency, 'SGD');
    expect(e.merchant, 'Ya Kun');
    expect(await File('${dir.path}/${e.receiptFile}').readAsBytes(), [0xff, 0xd8, 1]);

    final again = Ledger(dir);
    await again.load();
    expect(again.all.single.merchant, 'Ya Kun');
    expect(again.all.single.amount, 7.4);
  });

  test('delete removes the expense and its image', () async {
    final l = Ledger(dir);
    final e = await l.add(amount: 3, currency: 'SGD', receipt: Uint8List(2));
    final f = l.receiptFor(e)!;
    expect(await f.exists(), isTrue);
    await l.delete(e.id);
    expect(l.all, isEmpty);
    expect(await f.exists(), isFalse);
  });

  test('monthly overview: totals per currency, by category, newest first', () async {
    final l = Ledger(dir);
    await l.add(amount: 7.4, currency: 'SGD', category: 'Food & drink', date: DateTime(2026, 11, 1));
    await l.add(amount: 12.6, currency: 'SGD', category: 'Food & drink', date: DateTime(2026, 11, 2));
    await l.add(amount: 19.9, currency: 'CNY', date: DateTime(2026, 11, 2));
    await l.add(amount: 100, currency: 'SGD', category: 'Bills', date: DateTime(2026, 10, 20));
    final o = l.overview(now: DateTime(2026, 11, 3));
    expect([for (final m in o.totals) '${m.currency} ${m.amount}'], ['SGD 20.0', 'CNY 19.9']);
    expect(o.byCategory.first.category, 'Food & drink');
    expect(o.byCategory.any((c) => c.category == 'Other' && c.currency == 'CNY'), isTrue);
    expect(o.recent.first.currency, 'CNY');
    expect(o.recent.last.category, 'Bills');
  });

  test('spots duplicates: the same picture, or the same buy within 10 minutes', () async {
    final l = Ledger(dir);
    final shot = Uint8List.fromList([1, 2, 3, 4]);
    final e = await l.add(amount: 5.8, currency: 'SGD', merchant: 'LiHO', receipt: shot);
    final now = e.createdAt;
    // Logged a minute ago: probably the same buy.
    expect(
      l.isDuplicate(amount: 5.8, currency: 'sgd', merchant: 'liho', now: now.add(const Duration(minutes: 1))),
      isTrue,
    );
    // Same drink again after school: a real second buy.
    expect(
      l.isDuplicate(amount: 5.8, currency: 'SGD', merchant: 'LiHO', now: now.add(const Duration(hours: 3))),
      isFalse,
    );
    // The very same screenshot, any time later.
    expect(l.isDuplicate(amount: 1, currency: 'SGD', image: shot, now: now.add(const Duration(days: 2))), isTrue);
    expect(
      l.isDuplicate(
        amount: 1,
        currency: 'SGD',
        image: Uint8List.fromList([4, 3, 2, 1]),
        now: now.add(const Duration(days: 2)),
      ),
      isFalse,
    );
  });

  test('edits keep the receipt photo', () async {
    final l = Ledger(dir);
    final e = await l.add(amount: 3, currency: 'SGD', merchant: 'Canteen', receipt: Uint8List(2));
    await l.update(
      e.id,
      amount: 3.5,
      currency: 'MYR',
      date: DateTime(2026, 11, 2),
      merchant: 'Kedai',
      category: 'Food',
    );
    final again = Ledger(dir);
    await again.load();
    final x = again.all.single;
    expect((x.amount, x.currency, x.merchant, x.category, x.receiptFile), (3.5, 'MYR', 'Kedai', 'Food', e.receiptFile));
  });

  test('week and day totals; money in is kept apart from spending', () async {
    final l = Ledger(dir);
    final wed = DateTime(2026, 11, 4, 12); // a Wednesday
    await l.add(amount: 5, currency: 'SGD', date: DateTime(2026, 11, 2)); // Monday, same week
    await l.add(amount: 7, currency: 'SGD', date: DateTime(2026, 11, 1)); // Sunday, last week
    await l.add(amount: 3, currency: 'SGD', date: wed);
    await l.add(amount: 50, currency: 'SGD', date: wed, moneyIn: true, category: 'Pocket money');
    final week = l.overview(now: wed, period: Period.week);
    expect((week.spent('SGD'), week.received('SGD')), (8.0, 50.0));
    expect(l.overview(now: wed, period: Period.day).spent('SGD'), 3.0);
    expect(l.overview(now: wed).spent('SGD'), 15.0);
    expect(l.categories(), isNot(contains('Pocket money')));
  });

  test('splitting a bill: her share is spending, friends owe the rest, even with odd cents', () async {
    final l = Ledger(dir);
    final e = await l.add(amount: 20, currency: 'SGD', merchant: 'Pizza Hut', category: 'Food & drink');
    final mine = await l.split(e.id, 3, names: ['Amy']);
    expect(mine!.amount, 6.66);
    expect([for (final d in l.owed) '${d.who} ${d.amount}'], ['Amy 6.67', 'Friend 2 6.67']);
    await l.markPaid(l.owed.first.id);

    final again = Ledger(dir);
    await again.load();
    expect(again.all.single.amount, 6.66);
    expect(again.all.single.summary, r'Split 3 ways, S$20.00 in total');
    expect([for (final d in again.owed) d.who], ['Friend 2']);

    // Deleting the bill drops what's still owed for it.
    await again.delete(e.id);
    expect(again.owed, isEmpty);
  });

  test('exports CSV', () async {
    final l = Ledger(dir);
    await l.add(amount: 5.2, currency: 'SGD', merchant: 'Kopi "Corner"', date: DateTime(2026, 11, 1));
    expect(l.toCsv().split('\n').last, '2026-11-01,5.20,SGD,"Kopi ""Corner""","","",""');
  });
}
