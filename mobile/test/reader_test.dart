import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/reader.dart';
import 'package:spendsnap/receipt_parser.dart';

final now = DateTime(2026, 11, 1, 20);

ReadReceipt parse(List<Object> lines, {List<String> categories = const []}) =>
    parseReceipt([for (final l in lines) l is TextLine ? l : TextLine('$l', 0.012)], categories: categories, now: now);

void main() {
  group('printed Singapore receipts', () {
    test('kopitiam receipt: total after GST and service charge', () {
      final r = parse([
        'YA KUN KAYA TOAST',
        'Raffles City #B1-12',
        'GST Reg No: 199801234K',
        'Tel: 6338 1234',
        '28/10/2026  08:41',
        '1 x Kaya Toast Set A   5.60',
        '1 x Kopi C             1.80',
        'Subtotal               7.40',
        'Svc Chg 10%            0.74',
        'GST 9%                 0.73',
        'TOTAL                  8.87',
        'VISA                   8.87',
        'Thank you!',
      ]);
      expect((r.merchant, r.total, r.currency), ('YA KUN KAYA TOAST', 8.87, 'SGD'));
      expect(r.date, DateTime(2026, 10, 28));
      expect((r.category, r.paymentMethod), ('Food & drink', 'card'));
      expect(r.confident, isTrue);
    });

    test('supermarket: grand total beats subtotal, change and savings', () {
      final r = parse([
        'NTUC FairPrice',
        'Toa Payoh Hub',
        'MEIJI MILK 2L         S\$6.95',
        'BREAD                 S\$2.40',
        'SUB-TOTAL             S\$9.35',
        'TOTAL SAVINGS         S\$1.00',
        'GRAND TOTAL           S\$8.35',
        'CASH                  S\$10.00',
        'CHANGE                S\$1.65',
        '31 Oct 2026 19:02',
      ]);
      expect((r.merchant, r.total, r.currency, r.category), ('NTUC FairPrice', 8.35, 'SGD', 'Groceries'));
      expect(r.date, DateTime(2026, 10, 31));
      expect(r.paymentMethod, 'cash');
      expect(r.confident, isTrue);
    });

    test('label and amount read as separate lines', () {
      final r = parse(['Guardian', 'Nett Total', '12.90', 'Thank you']);
      expect((r.total, r.category), (12.9, 'Health'));
    });

    test('uses an existing category name when it matches', () {
      expect(parse(['Grab', 'Trip fare', 'Total  S\$14.20'], categories: ['transport']).category, 'transport');
    });
  });

  group('payment screenshots', () {
    test('Alipay in China: the big amount, the payee above it, CNY', () {
      final r = parse([
        const TextLine('20:15', 0.012),
        const TextLine('账单详情', 0.015),
        const TextLine('瑞幸咖啡', 0.02),
        const TextLine('-19.90', 0.045),
        const TextLine('交易成功', 0.015),
        const TextLine('支付时间  2026-10-28 15:02:11', 0.012),
        const TextLine('付款方式  支付宝余额', 0.012),
        const TextLine('商品说明  生椰拿铁', 0.012),
      ]);
      expect((r.merchant, r.total, r.currency), ('瑞幸咖啡', 19.9, 'CNY'));
      expect((r.category, r.paymentMethod), ('Food & drink', 'Alipay'));
      expect(r.date, DateTime(2026, 10, 28));
      expect(r.confident, isTrue);
    });

    test('PayNow transfer from a bank app', () {
      final r = parse([
        const TextLine('9:41', 0.012),
        const TextLine('Transfer successful', 0.02),
        const TextLine('S\$ 25.00', 0.05),
        const TextLine('To', 0.012),
        const TextLine('Hai Nan Chicken Rice', 0.014),
        const TextLine('via PayNow', 0.012),
        const TextLine('1 Nov 2026, 12:31 PM', 0.012),
      ]);
      expect((r.merchant, r.total, r.currency, r.paymentMethod), ('Hai Nan Chicken Rice', 25.0, 'SGD', 'PayNow'));
      expect(r.date, DateTime(2026, 11, 1));
      expect(r.category, 'Food & drink');
    });

    test('WeChat Pay with a yuan sign', () {
      final r = parse(['微信支付', '收款方: 美团', '-¥36.50', '当前状态 支付成功', '10月30日 18:20']);
      expect((r.merchant, r.total, r.currency), ('美团', 36.5, 'CNY'));
      expect(r.date, DateTime(2026, 10, 30));
      expect(r.paymentMethod, 'WeChat Pay');
    });
  });

  group('when unsure, the app asks', () {
    test('no labelled total: largest amount, low confidence', () {
      final r = parse(['Some shop', 'item 3.20', 'item 4.50', 'ref 1234567']);
      expect(r.total, 4.5);
      expect(r.confident, isFalse);
    });

    test('no amount at all', () {
      final r = parse(['Hello world', 'call 6123 4567']);
      expect(r.total, isNull);
      expect(r.confident, isFalse);
    });

    test('nothing in the picture', () {
      final r = parse([]);
      expect(r.isReceipt, isFalse);
      expect(r.confident, isFalse);
    });

    test('dates in the future or times are not taken as dates or amounts', () {
      final r = parse(['Cafe', '12/12/2026 10:30', 'Total 4.00']);
      expect(r.date, isNull);
      expect(r.total, 4.0);
    });
  });

  test('OfflineReader passes the phone text to the parser', () async {
    final r = await OfflineReader(_FakeText(['Koi Thé', 'TOTAL 5.30'])).read(Uint8List(0));
    expect((r.merchant, r.total, r.category), ('Koi Thé', 5.3, 'Food & drink'));
  });

  test('a phone without text recognition gives a friendly message', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await expectLater(
      VisionTextRecognizer().read(Uint8List(4)),
      throwsA(isA<ReadException>().having((e) => e.message, 'message', contains('Type the amount'))),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('spendsnap/text'),
      (call) async => [
        {'text': 'TOTAL 3.00', 'height': 0.01},
      ],
    );
    final lines = await VisionTextRecognizer().read(Uint8List(4));
    expect((lines.single.text, lines.single.height), ('TOTAL 3.00', 0.01));
  });
}

class _FakeText implements TextRecognizer {
  _FakeText(this.lines);
  final List<String> lines;
  @override
  Future<List<TextLine>> read(Uint8List image) async => [for (final l in lines) TextLine(l)];
}
