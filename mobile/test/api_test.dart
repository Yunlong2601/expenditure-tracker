import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spendsnap/api.dart';

void main() {
  group('ScannerApi', () {
    test('overview sends the key and parses totals', () async {
      late http.Request seen;
      final api = ScannerApi(
        baseUrl: 'http://box:8082',
        apiKey: 'k3y',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'month': '2026-11',
              'totals': [
                {'currency': 'SGD', 'total': '20.00'},
                {'currency': 'CNY', 'total': '19.90'},
              ],
              'by_category': [
                {'category': 'Food & drink', 'currency': 'SGD', 'total': '20.00'},
              ],
              'recent': [
                {
                  'id': '3',
                  'date': '2026-11-02',
                  'amount': '19.90',
                  'currency': 'CNY',
                  'merchant': '瑞幸咖啡',
                  'category': null,
                  'account': 'Alipay',
                  'has_receipt': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final o = await api.overview();
      expect(seen.url.toString(), 'http://box:8082/api/expenses');
      expect(seen.headers['X-Api-Key'], 'k3y');
      expect(o.totals.map((m) => '${m.currency} ${m.amount}'), ['SGD 20.0', 'CNY 19.9']);
      expect(o.recent.single.merchant, '瑞幸咖啡');
    });

    test('scan sends the image as multipart with corrected fields', () async {
      late http.BaseRequest seen;
      late String body;
      final api = ScannerApi(
        baseUrl: 'http://box:8082/',
        apiKey: 'k',
        client: MockClient.streaming((req, stream) async {
          seen = req;
          body = latin1.decode(await stream.toBytes());
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'saved': true, 'message': 'Logged S\$5.20'}))),
            200,
          );
        }),
      );
      final r = await api.scan(
        Uint8List.fromList([0xff, 0xd8, 1, 2]),
        fields: const ExpenseFields(total: '5.20', currency: 'SGD', merchant: 'Kopitiam', category: ''),
      );
      expect(r.saved, isTrue);
      expect(seen.url.path, '/api/receipt');
      expect(body, contains('name="file"'));
      expect(body, contains('name="merchant"'));
      expect(body, isNot(contains('name="category"')));
    });

    test('needs-review result is parsed', () async {
      final api = ScannerApi(
        baseUrl: 'http://box',
        apiKey: 'k',
        client: MockClient.streaming(
          (req, s) async => http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'saved': false,
                  'needs_review': true,
                  'message': "Not saved: I'm not sure",
                  'receipt': {'merchant': 'Grab', 'total': null, 'confidence': 'low'},
                  'accounts': ['DBS'],
                  'categories': ['Transport'],
                }),
              ),
            ),
            200,
          ),
        ),
      );
      final r = await api.scan(Uint8List(4));
      expect(r.needsReview, isTrue);
      expect(r.receipt!.merchant, 'Grab');
      expect(r.accounts, ['DBS']);
    });

    test('wrong key gives a friendly message', () async {
      final api = ScannerApi(
        baseUrl: 'http://box',
        apiKey: 'bad',
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      expect(api.overview(), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('access key'))));
    });

    test('unreachable server gives a friendly message', () async {
      final api = ScannerApi(
        baseUrl: 'http://box',
        apiKey: 'k',
        client: MockClient((_) async => throw Exception('socket')),
      );
      expect(api.overview(), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains("Can't reach"))));
    });

    test('server error message is passed through', () async {
      final api = ScannerApi(
        baseUrl: 'http://box',
        apiKey: 'k',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'message': 'Firefly rejected the access token.'}), 502),
        ),
      );
      expect(
        api.overview(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Firefly rejected the access token.')),
      );
    });

    test('manual expense posts JSON', () async {
      late http.Request seen;
      final api = ScannerApi(
        baseUrl: 'http://box',
        apiKey: 'k',
        client: MockClient((req) async {
          seen = req;
          return http.Response(jsonEncode({'saved': true, 'message': 'Logged S\$4.50'}), 200);
        }),
      );
      final r = await api.addManual(const ExpenseFields(total: '4.50', category: 'Food & drink'));
      expect(r.message, r'Logged S$4.50');
      expect(jsonDecode(seen.body), {'total': '4.50', 'category': 'Food & drink'});
    });
  });
}
