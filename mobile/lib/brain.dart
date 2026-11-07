import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'day.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'task_talk.dart';

/// The cat's online brain, which is optional: a Supabase Edge Function that
/// asks an AI for the reply, Groq's free plan first and DeepSeek as a
/// low-cost backup (see supabase/README.md). It's on only when
/// the app is built with
/// `--dart-define=CAT_AI_URL=https://<project>.supabase.co/functions/v1/cat-chat`
/// and `--dart-define=CAT_AI_KEY=<the project's anon key>`. Any failure gives
/// null, and the cat answers on the phone instead.
class CatBrain {
  CatBrain(this.url, {this.key = '', this.timeout = const Duration(seconds: 15)});

  final Uri url;
  final String key;
  final Duration timeout;

  static const _url = String.fromEnvironment('CAT_AI_URL');
  static const _key = String.fromEnvironment('CAT_AI_KEY');

  /// The brain the app uses, or null when chat stays on the phone.
  static CatBrain? current = _fromBuild();

  static CatBrain? _fromBuild() {
    final u = Uri.tryParse(_url);
    return u == null || !u.isScheme('https') ? null : CatBrain(u, key: _key);
  }

  /// Sends [body] and returns the cat's reply, or null if anything goes wrong.
  Future<String?> ask(Map<String, Object?> body) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _post(client, body).timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> _post(HttpClient client, Map<String, Object?> body) async {
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    if (key.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      req.headers.set('apikey', key);
    }
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) return null;
    final reply = (jsonDecode(text) as Map<String, dynamic>)['reply'];
    return reply is String && reply.trim().isNotEmpty ? reply.trim() : null;
  }
}

/// She has agreed to chat in the way this build works: on the phone, or
/// through the online AI when it's set up.
bool get chatAgreed =>
    Prefs.current.chatOn && (CatBrain.current == null || Prefs.current.chatAi);

/// Records her answer to the consent sheet.
Future<void> setChatAgreed(bool v) async {
  await Prefs.current.setChatOn(v);
  await Prefs.current.setChatAi(v && CatBrain.current != null);
}

/// Starts of a message that asks the cat to remember something.
const rememberStarts = ['remember ', '记住', '帮我记住'];

/// Words that make a message about money.
const moneyWords = ['spend', 'spent', 'money', '花', '钱', '账'];

/// Messages the cat always answers on the phone: spending never leaves it,
/// "remember …" is saved right away, and "remind me …" or "add …" puts a
/// task on the list.
bool staysOnPhone(String said) {
  final m = said.trim().toLowerCase();
  return rememberStarts.any(m.startsWith) ||
      moneyWords.any(m.contains) ||
      parseTaskAsk(said) != null;
}

/// Recent chat to send, oldest first. Lines answered on the phone, and the
/// cat's answers to them, are left out so spending never goes along.
List<Map<String, String>> chatLines(Iterable<Entry> chat, {int count = 12}) {
  final out = <Map<String, String>>[];
  var skip = false;
  for (final e in chat) {
    if (e.kind == 'me') {
      skip = staysOnPhone(e.text);
      if (!skip) out.add({'from': 'me', 'text': e.text});
    } else if (!skip) {
      out.add({'from': 'cat', 'text': e.text});
    }
  }
  return out.length > count ? out.sublist(out.length - count) : out;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// What the cat may know about [day]: public tasks only, never spending.
Map<String, Object?> dayFacts(DayStore s, DateTime day) {
  final mood = s.moodOf(day);
  return {
    'date': '${day.year}-${_two(day.month)}-${_two(day.day)}',
    'left': [
      for (final t in s.tasksOn(day).where((t) => !t.private && !t.done))
        t.topStep == null ? t.title : '${t.title}: ${t.topStep!.title}',
    ],
    'done': [for (final t in s.doneOn(day).where((t) => !t.private)) t.title],
    'mood': mood == null ? '' : (zh ? mood.zh : mood.label),
    'focusMinutes': s.focusMinutesOn(day),
  };
}

Map<String, Object?> _base(DayStore s) => {
  'lang': zh ? 'zh' : 'en',
  'catName': Prefs.current.catName,
  'memories': [
    for (final m in s.memories.skip(s.memories.length > 40 ? s.memories.length - 40 : 0))
      m.text,
  ],
};

/// The request for a reply to [said], given the chat before it.
Map<String, Object?> replyAsk(String said, DayStore s, Iterable<Entry> before) => {
  ..._base(s),
  'mode': 'reply',
  'message': said,
  'history': chatLines(before),
  'day': dayFacts(s, DateTime.now()),
};

/// The request for the cat's notebook page about [day].
Map<String, Object?> notebookAsk(DayStore s, DateTime day) => {
  ..._base(s),
  'mode': 'notebook',
  'message': '',
  'history': chatLines(s.chat.where((e) => sameDay(e.at, day)), count: 16),
  'day': dayFacts(s, day),
};
