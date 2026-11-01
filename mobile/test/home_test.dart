import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/app.dart';
import 'package:spendsnap/home_screen.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/reader.dart';

class FakePicker implements ReceiptPicker {
  int camCalls = 0, galleryCalls = 0;
  @override
  Future<PickedImage?> camera() async {
    camCalls++;
    return const PickedImage([0xff, 0xd8, 0, 0], 'cam.jpg');
  }

  @override
  Future<PickedImage?> gallery() async {
    galleryCalls++;
    return const PickedImage([0xff, 0xd8, 1, 1], 'shot.png');
  }
}

class FakeReader implements ReceiptReader {
  FakeReader(this.answer);
  Object answer;
  int calls = 0;
  @override
  Future<ReadReceipt> read(Uint8List image, {List<String> categories = const []}) async {
    calls++;
    if (answer is ReadException) throw answer;
    return answer as ReadReceipt;
  }
}

final yaKun = ReadReceipt(
  merchant: 'Ya Kun',
  total: 7.4,
  currency: 'SGD',
  date: DateTime.now(),
  category: 'Food & drink',
  confidence: 'high',
);

void main() {
  late Directory dir;
  late Ledger ledger;
  late FakePicker picker;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('home');
    ledger = Ledger(dir);
    picker = FakePicker();
    Prefs.current = Prefs.memory();
  });
  tearDown(() async => dir.delete(recursive: true));

  Widget wrap(ReceiptReader reader) => MaterialApp(
    home: HomeScreen(ledger: ledger, reader: reader, picker: picker),
  );
  final unreadable = FakeReader(ReadException("This phone can't read receipts yet. Type the amount in."));

  // Real file writes only finish while the test lets real time pass.
  Future<void> tapAndSettle(WidgetTester t, Finder f) async {
    await t.runAsync(() async {
      await t.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
  }

  // A save shows a message; closing it in test time keeps the next save's
  // message from replacing it after the test has ended.
  Future<void> dismiss(WidgetTester t) async {
    t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await t.pumpAndSettle();
  }

  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1179, 2556);
    view.devicePixelRatio = 3;
  });

  testWidgets('shows this month total in SGD with other currencies below', (t) async {
    await t.runAsync(() async {
      await ledger.add(amount: 482.3, currency: 'SGD', merchant: 'Ya Kun', category: 'Food & drink');
      await ledger.add(amount: 120, currency: 'CNY');
    });
    await t.pumpWidget(wrap(unreadable));
    expect(find.text(r'S$482.30'), findsWidgets);
    expect(find.text('+ ¥120.00'), findsOneWidget);
    expect(find.text('Ya Kun'), findsOneWidget);
  });

  testWidgets('confident read saves on the phone with no questions, and Undo removes it', (t) async {
    final reader = FakeReader(yaKun);
    await t.pumpWidget(wrap(reader));
    await tapAndSettle(t, find.byKey(const Key('snap')));
    expect(picker.camCalls, 1);
    expect(find.text('Quick check'), findsNothing);
    expect(ledger.all.single.merchant, 'Ya Kun');
    expect(ledger.receiptFor(ledger.all.single)!.existsSync(), isTrue);
    expect(find.text(r'S$7.40'), findsWidgets);
    expect(find.text(r'Logged S$7.40 at Ya Kun (Food & drink)'), findsOneWidget);
    // Tapped outside runAsync so the snackbar closes in test time.
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    expect(ledger.all, isEmpty);
  });

  testWidgets('unsure read opens the quick check; the corrected amount is saved', (t) async {
    final reader = FakeReader(const ReadReceipt(merchant: 'Grab', currency: 'SGD', confidence: 'low'));
    await t.pumpWidget(wrap(reader));
    await tapAndSettle(t, find.byKey(const Key('screenshot')));
    expect(picker.galleryCalls, 1);
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.text("I couldn't read the total."), findsOneWidget);
    await t.enterText(find.byKey(const Key('review-total')), '14.20');
    await tapAndSettle(t, find.byKey(const Key('review-save')));
    final e = ledger.all.single;
    expect((e.amount, e.merchant, e.currency), (14.2, 'Grab', 'SGD'));
  });

  testWidgets('a second copy of the same receipt asks before saving', (t) async {
    await t.runAsync(() => ledger.add(amount: 7.4, currency: 'SGD', merchant: 'Ya Kun', date: DateTime.now()));
    await t.pumpWidget(wrap(FakeReader(yaKun)));
    await tapAndSettle(t, find.byKey(const Key('snap')));
    expect(find.text('This looks like one you already logged. Save it again?'), findsOneWidget);
    expect(ledger.all, hasLength(1));
  });

  testWidgets('phone could not read it: the photo is kept and the amount is typed', (t) async {
    await t.pumpWidget(wrap(unreadable));
    await tapAndSettle(t, find.byKey(const Key('snap')));
    expect(find.text('Quick check'), findsOneWidget);
    await t.enterText(find.byKey(const Key('review-total')), '3.50');
    await tapAndSettle(t, find.byKey(const Key('review-save')));
    expect(ledger.all.single.amount, 3.5);
    expect(ledger.all.single.receiptFile, isNotNull);
  });

  testWidgets('read error falls back to typing it in', (t) async {
    await t.pumpWidget(wrap(FakeReader(ReadException("Couldn't read this picture. Type the amount in."))));
    await tapAndSettle(t, find.byKey(const Key('snap')));
    expect(find.text("Couldn't read this picture. Type the amount in."), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);
  });

  testWidgets('tap an expense, Edit, and the change is saved', (t) async {
    await t.runAsync(() => ledger.add(amount: 3, currency: 'SGD', merchant: 'Canteen', category: 'Food & drink'));
    await t.pumpWidget(wrap(unreadable));
    await t.tap(find.text('Canteen'));
    await t.pumpAndSettle();
    // Started in real time, like the other saves, so the file write finishes.
    await tapAndSettle(t, find.byKey(const Key('edit-expense')));
    expect(find.text('Edit'), findsOneWidget);
    await t.enterText(find.byKey(const Key('review-total')), '3.80');
    await tapAndSettle(t, find.byKey(const Key('review-save')));
    expect(ledger.all.single.amount, 3.8);
    expect(find.text(r'S$3.80'), findsWidgets);
  });

  testWidgets('cash in ringgit, and a new category of her own', (t) async {
    await t.pumpWidget(wrap(unreadable));
    await tapAndSettle(t, find.byKey(const Key('cash')));
    await t.tap(find.byKey(const Key('cur-MYR')));
    await t.enterText(find.byKey(const Key('quick-amount')), '12');
    await tapAndSettle(t, find.byKey(const Key('cat-new')));
    await t.enterText(find.byKey(const Key('new-category')), 'Concert');
    await tapAndSettle(t, find.byKey(const Key('new-category-save')));
    final e = ledger.all.single;
    expect((e.amount, e.currency, e.category), (12.0, 'MYR', 'Concert'));

    // Next time her own category is right there.
    await tapAndSettle(t, find.byKey(const Key('cash')));
    expect(find.byKey(const Key('cat-Concert')), findsOneWidget);
  });

  testWidgets('pocket money: set it once, see what is left this week, and the cat worries', (t) async {
    await t.runAsync(() => ledger.add(amount: 50, currency: 'SGD', category: 'Shopping'));
    await t.pumpWidget(wrap(unreadable));
    await tapAndSettle(t, find.byKey(const Key('set-allowance')));
    await t.enterText(find.byKey(const Key('allowance-amount')), '80');
    await tapAndSettle(t, find.byKey(const Key('allowance-save')));
    expect(find.text('Left this week'), findsOneWidget);
    expect(find.text(r'S$30.00'), findsOneWidget);
    expect(find.byKey(const Key('cat-happy')), findsOneWidget);
    await dismiss(t);

    // Spend more: 85% used, the cat gets worried.
    await tapAndSettle(t, find.byKey(const Key('cash')));
    await t.enterText(find.byKey(const Key('quick-amount')), '18');
    await tapAndSettle(t, find.byKey(const Key('cat-Bubble tea')));
    expect(find.text(r'S$12.00'), findsOneWidget);
    expect(find.byKey(const Key('cat-worried')), findsOneWidget);
    await dismiss(t);

    // Mum gives S$50: more room this week, happy again.
    await tapAndSettle(t, find.byKey(const Key('cash')));
    await t.tap(find.byKey(const Key('mode-in')));
    await t.pump();
    await t.enterText(find.byKey(const Key('quick-amount')), '50');
    await tapAndSettle(t, find.byKey(const Key('cat-From family')));
    expect(ledger.all.last.moneyIn, isTrue);
    expect(find.text(r'S$62.00'), findsOneWidget);
    expect(find.byKey(const Key('cat-happy')), findsOneWidget);
    expect(find.text(r'+S$50.00'), findsOneWidget);
    await dismiss(t);
  });

  testWidgets('over budget: the cat is sad but kind', (t) async {
    await t.runAsync(() async {
      await Prefs.current.setAllowance(10, daily: true);
      await ledger.add(amount: 12, currency: 'SGD', category: 'Food & drink');
    });
    await t.pumpWidget(wrap(unreadable));
    expect(find.text('Over today'), findsOneWidget);
    expect(find.text(r'S$2.00'), findsOneWidget);
    expect(find.byKey(const Key('cat-sad')), findsOneWidget);
    expect(find.text("It's okay. A fresh start tomorrow."), findsOneWidget);
  });

  testWidgets('cash quick add: amount then one tap on a category', (t) async {
    await t.pumpWidget(wrap(unreadable));
    await tapAndSettle(t, find.byKey(const Key('cash')));
    await t.tap(find.byKey(const Key('cat-Food & drink')));
    await t.pump();
    expect(find.text('Type the amount first'), findsOneWidget);
    await t.enterText(find.byKey(const Key('quick-amount')), '4.5');
    await tapAndSettle(t, find.byKey(const Key('cat-Food & drink')));
    final e = ledger.all.single;
    expect((e.amount, e.currency, e.category), (4.5, 'SGD', 'Food & drink'));
    expect(find.text(r'Logged S$4.50 (Food & drink)'), findsOneWidget);
  });
}
