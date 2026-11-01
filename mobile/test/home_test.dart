import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spendsnap/api.dart';
import 'package:spendsnap/app.dart';
import 'package:spendsnap/home_screen.dart';

class MockApi extends Mock implements ScannerApi {}

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

const empty = Overview(month: '2026-11', totals: [], byCategory: [], recent: []);
final some = Overview(
  month: '2026-11',
  totals: const [Money('SGD', 482.3), Money('CNY', 120)],
  byCategory: const [CategoryTotal('Food & drink', 'SGD', 300)],
  recent: [
    Expense(id: '1', date: DateTime.now(), amount: 7.4, currency: 'SGD', merchant: 'Ya Kun', category: 'Food & drink'),
  ],
);

Widget wrap(ScannerApi api, ReceiptPicker picker) => MaterialApp(
  home: HomeScreen(api: api, picker: picker, onOpenSettings: () {}),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const ExpenseFields(total: '0'));
  });

  late MockApi api;
  late FakePicker picker;
  setUp(() {
    api = MockApi();
    picker = FakePicker();
  });

  testWidgets('shows this month total in SGD with other currencies below', (t) async {
    when(() => api.overview()).thenAnswer((_) async => some);
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    expect(find.text(r'S$482.30'), findsOneWidget);
    expect(find.text('+ ¥120.00'), findsOneWidget);
    expect(find.text('Ya Kun'), findsOneWidget);
  });

  testWidgets('confident scan saves with no questions and refreshes', (t) async {
    when(() => api.overview()).thenAnswer((_) async => empty);
    when(() => api.scan(any(), filename: any(named: 'filename')))
        .thenAnswer((_) async => const ScanResult(saved: true, message: r'Logged S$7.40 at Ya Kun'));
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('snap')));
    await t.pumpAndSettle();
    expect(picker.camCalls, 1);
    expect(find.text(r'Logged S$7.40 at Ya Kun'), findsOneWidget);
    expect(find.text('Quick check'), findsNothing);
    verify(() => api.overview()).called(2);
  });

  testWidgets('unsure scan opens the review sheet and saves the corrected amount', (t) async {
    when(() => api.overview()).thenAnswer((_) async => empty);
    when(
      () => api.scan(
        any(),
        filename: any(named: 'filename'),
        fields: any(named: 'fields', that: isNull),
      ),
    ).thenAnswer(
      (_) async => const ScanResult(
        saved: false,
        needsReview: true,
        message: "Not saved: I couldn't read the total.",
        receipt: ReadReceipt(merchant: 'Grab', currency: 'SGD'),
        accounts: ['DBS'],
        account: 'DBS',
      ),
    );
    when(
      () => api.scan(
        any(),
        filename: any(named: 'filename'),
        fields: any(named: 'fields', that: isNotNull),
      ),
    ).thenAnswer((_) async => const ScanResult(saved: true, message: r'Logged S$14.20 at Grab'));
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('screenshot')));
    await t.pumpAndSettle();
    expect(picker.galleryCalls, 1);
    expect(find.text('Quick check'), findsOneWidget);
    await t.enterText(find.byKey(const Key('review-total')), '14.20');
    await t.tap(find.byKey(const Key('review-save')));
    await t.pumpAndSettle();
    final captured = verify(
      () => api.scan(
        any(),
        filename: any(named: 'filename'),
        fields: captureAny(named: 'fields', that: isNotNull),
      ),
    ).captured;
    final f = captured.single as ExpenseFields;
    expect((f.total, f.merchant, f.account, f.currency), ('14.20', 'Grab', 'DBS', 'SGD'));
    expect(find.text(r'Logged S$14.20 at Grab'), findsOneWidget);
  });

  testWidgets('cash quick add: amount then one tap on a category', (t) async {
    when(() => api.overview()).thenAnswer((_) async => empty);
    when(() => api.addManual(any()))
        .thenAnswer((_) async => const ScanResult(saved: true, message: r'Logged S$4.50 (Food & drink)'));
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cash')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cat-Food & drink')));
    await t.pump();
    expect(find.text('Type the amount first'), findsOneWidget);
    await t.enterText(find.byKey(const Key('quick-amount')), '4.5');
    await t.tap(find.byKey(const Key('cat-Food & drink')));
    await t.pumpAndSettle();
    final f = verify(() => api.addManual(captureAny())).captured.single as ExpenseFields;
    expect((f.total, f.currency, f.category), ('4.50', 'SGD', 'Food & drink'));
    expect(find.text(r'Logged S$4.50 (Food & drink)'), findsOneWidget);
  });

  testWidgets('server errors show as a message instead of a crash', (t) async {
    when(() => api.overview()).thenThrow(ApiException("Can't reach your server."));
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    expect(find.text("Can't reach your server."), findsOneWidget);
  });

  testWidgets('a failed save reopens the review with the typed amount kept', (t) async {
    when(() => api.overview()).thenAnswer((_) async => empty);
    when(
      () => api.scan(
        any(),
        filename: any(named: 'filename'),
        fields: any(named: 'fields', that: isNull),
      ),
    ).thenAnswer(
      (_) async => const ScanResult(
        saved: false,
        needsReview: true,
        message: 'Check it',
        receipt: ReadReceipt(merchant: 'Grab', currency: 'USD'),
      ),
    );
    var attempts = 0;
    when(
      () => api.scan(
        any(),
        filename: any(named: 'filename'),
        fields: any(named: 'fields', that: isNotNull),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw ApiException("Can't reach your server.");
      return const ScanResult(saved: true, message: 'Logged US\$9.00 at Grab');
    });
    await t.pumpWidget(wrap(api, picker));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('snap')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('review-total')), '9.00');
    await t.tap(find.byKey(const Key('review-save')));
    await t.pumpAndSettle();
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '9.00'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    await t.tap(find.byKey(const Key('review-save')));
    await t.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Logged US\$9.00 at Grab'), findsOneWidget);
  });
}
