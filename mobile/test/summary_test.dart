import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/summary.dart';

void main() {
  testWidgets('the month picture shows the total, top categories and fun facts', (t) async {
    final view = t.view;
    view.physicalSize = const Size(1179, 2556);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);
    late Ledger ledger;
    await t.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('summary');
      addTearDown(() => dir.delete(recursive: true));
      ledger = Ledger(dir);
      final d = DateTime(2026, 10, 12);
      await ledger.add(amount: 5.8, currency: 'SGD', merchant: 'LiHO', category: 'Bubble tea', date: d);
      await ledger.add(amount: 6.2, currency: 'SGD', merchant: 'KOI', category: 'Bubble tea', date: d);
      await ledger.add(amount: 35, currency: 'SGD', merchant: 'Uniqlo', category: 'Shopping', date: d);
      await ledger.add(amount: 50, currency: 'SGD', category: 'Pocket money', date: d, moneyIn: true);
    });
    await t.pumpWidget(
      MaterialApp(
        home: SummaryScreen(ledger: ledger, month: DateTime(2026, 10)),
      ),
    );
    expect(find.text('My October'), findsOneWidget);
    expect(find.text(r'S$47.00'), findsOneWidget);
    expect(find.text('3 things logged'), findsOneWidget);
    expect(find.text(r'Biggest buy: Uniqlo, S$35.00'), findsOneWidget);
    expect(find.text('2 bubble teas'), findsOneWidget);
    expect(find.text(r'Got S$50.00'), findsOneWidget);

    // Back a month: nothing yet.
    await t.tap(find.byTooltip('Previous month'));
    await t.pump();
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });
}
