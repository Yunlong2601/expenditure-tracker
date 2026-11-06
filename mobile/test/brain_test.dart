import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/brain.dart';
import 'package:spendsnap/chat.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';

/// Real sockets, even if the test binding has swapped HttpClient out.
class _RealHttp extends HttpOverrides {}

/// A stand-in for the Supabase function, on this machine.
class FakeCat {
  late HttpServer _server;
  final asks = <Map<String, dynamic>>[];
  final headers = <HttpHeaders>[];
  int status = 200;
  String reply = 'Meow from the cloud';
  Duration delay = Duration.zero;

  Future<CatBrain> start({Duration timeout = const Duration(seconds: 5)}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      try {
        asks.add(jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>);
        headers.add(req.headers);
        await Future<void>.delayed(delay);
        req.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'reply': reply}));
        await req.response.close();
      } catch (_) {
        // The app gave up waiting and hung up.
      }
    });
    return CatBrain(
      Uri.parse('http://127.0.0.1:${_server.port}/functions/v1/cat-chat'),
      key: 'anon-key',
      timeout: timeout,
    );
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late FakeCat fake;
  late CatBrain brain;

  setUp(() async {
    HttpOverrides.global = _RealHttp();
    Prefs.current = Prefs.memory();
    fake = FakeCat();
    brain = await fake.start();
  });
  tearDown(() async {
    await fake.stop();
    HttpOverrides.global = null;
  });

  group('what may go to the AI', () {
    test('spending and "remember" stay on the phone', () {
      expect(staysOnPhone('How much did I spend today?'), isTrue);
      expect(staysOnPhone('今天花了多少钱'), isTrue);
      expect(staysOnPhone('Remember I like cats'), isTrue);
      expect(staysOnPhone('帮我记住明天带伞'), isTrue);
      expect(staysOnPhone('I finished my essay'), isFalse);
    });

    test('recent chat leaves out money questions and their answers', () {
      final now = DateTime.now();
      final lines = chatLines([
        Entry(at: now, text: 'hi', kind: 'me'),
        Entry(at: now, text: 'meow', kind: 'cat'),
        Entry(at: now, text: 'how much did I spend?', kind: 'me'),
        Entry(at: now, text: r'Today you spent $12.00.', kind: 'cat'),
        Entry(at: now, text: 'ok thanks', kind: 'me'),
      ]);
      expect(lines.map((l) => l['text']), ['hi', 'meow', 'ok thanks']);
      expect(lines.map((l) => l['from']), ['me', 'cat', 'me']);
      final many = [for (var i = 0; i < 30; i++) Entry(at: now, text: '$i', kind: 'me')];
      expect(chatLines(many), hasLength(12));
      expect(chatLines(many).last['text'], '29');
    });

    test('the day sent has public tasks only', () async {
      final s = DayStore.memory();
      await s.addTask('Diary', private: true);
      await s.addTask('Homework');
      final ask = replyAsk('hey', s, const []);
      expect((ask['day']! as Map)['left'], ['Homework']);
      expect(jsonEncode(ask), isNot(contains('Diary')));
      expect(ask['lang'], 'en');
      expect(ask['catName'], 'Mochi');
      expect(ask['mode'], 'reply');
    });
  });

  group('CatBrain', () {
    test('sends the ask with the key and returns the reply', () async {
      expect(await brain.ask({'mode': 'reply', 'message': 'hi'}), 'Meow from the cloud');
      expect(fake.asks.single['message'], 'hi');
      expect(fake.headers.single.value('authorization'), 'Bearer anon-key');
      expect(fake.headers.single.value('apikey'), 'anon-key');
    });

    test('gives null when the function fails or says nothing', () async {
      fake.status = 503;
      expect(await brain.ask({'message': 'hi'}), isNull);
      fake
        ..status = 200
        ..reply = '  ';
      expect(await brain.ask({'message': 'hi'}), isNull);
    });

    test('gives null when it is slow or unreachable', () async {
      fake.delay = const Duration(seconds: 3);
      final slow = CatBrain(brain.url, timeout: const Duration(milliseconds: 200));
      expect(await slow.ask({'message': 'hi'}), isNull);
      final down = CatBrain(Uri.parse('http://127.0.0.1:1/cat-chat'));
      expect(await down.ask({'message': 'hi'}), isNull);
    });
  });

  group('catAnswer', () {
    test('uses the AI reply, with the chat before it', () async {
      final s = DayStore.memory();
      final before = [Entry(at: DateTime.now(), text: 'hello', kind: 'me')];
      expect(await catAnswer('I finished my essay', s, before: before, brain: brain), 'Meow from the cloud');
      expect(fake.asks.single['message'], 'I finished my essay');
      expect(fake.asks.single['history'], [
        {'from': 'me', 'text': 'hello'},
      ]);
    });

    test('answers on the phone when the AI fails', () async {
      fake.status = 500;
      final s = DayStore.memory();
      await s.addTask('Homework');
      expect(await catAnswer('what’s left?', s, brain: brain), contains('Homework'));
    });

    test('never sends spending or "remember"', () async {
      final s = DayStore.memory();
      expect(
        await catAnswer('How much did I spend?', s, brain: brain, spentToday: () => r'$3.00'),
        r'Today you spent $3.00.',
      );
      await catAnswer('Remember I like oat milk', s, brain: brain);
      expect(s.memories.single.text, 'I like oat milk');
      expect(fake.asks, isEmpty);
    });
  });

  group('notebook', () {
    test('the AI writes recent pages and the template the older ones', () async {
      final s = DayStore.memory();
      final now = DateTime.now();
      s.chat
        ..add(Entry(at: now.subtract(const Duration(days: 10)), text: 'hi', kind: 'me'))
        ..add(Entry(at: now.subtract(const Duration(days: 1)), text: 'I finished my essay', kind: 'me'));
      fake.reply = 'You finished your essay. Proud of you.';
      await writeNotebook(s, brain: brain);
      expect(s.notebook, hasLength(2));
      final recent = s.notebook.firstWhere((n) => sameDay(n.at, now.subtract(const Duration(days: 1))));
      expect(recent.text, 'You finished your essay. Proud of you.');
      final old = s.notebook.firstWhere((n) => sameDay(n.at, now.subtract(const Duration(days: 10))));
      expect(old.text, contains('chatted once'));
      expect(fake.asks.single['mode'], 'notebook');
      expect(fake.asks.single['history'], [
        {'from': 'me', 'text': 'I finished my essay'},
      ]);
    });

    test('uses the template when the AI fails', () async {
      fake.status = 500;
      final s = DayStore.memory();
      s.chat.add(Entry(at: DateTime.now().subtract(const Duration(days: 1)), text: 'hi', kind: 'me'));
      await writeNotebook(s, brain: brain);
      expect(s.notebook.single.text, contains('chatted once'));
    });
  });
}
