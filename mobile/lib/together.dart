import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'day.dart';
import 'exam.dart' show minutesText;
import 'feel.dart';
import 'l10n.dart';
import 'records.dart';
import 'study.dart';
import 'study_screen.dart';
import 'theme.dart';

/// Study together: friends sitting side by side start the same timer from a
/// four-digit code. The code only says when to start and for how long, and
/// every phone's clock is already right, so nothing goes online and nobody
/// needs an account.

/// How long a shared session can be, in minutes.
const togetherLengths = [15, 25, 30, 45, 60, 90];

// Every start minute of the day times every length: 8640 sessions, each
// with its own code. Mixing by 7 (which shares no factor with 8640) means
// codes made a minute apart look nothing alike, so a typo is unlikely to
// land on a real session that starts at about the same time.
const _sessions = 1440 * 6;
const _mix = 7;
const _unmix = 3703; // 7 × 3703 = 3 × 8640 + 1

/// The time now; tests move it.
DateTime Function() togetherClock = DateTime.now;

/// When a session made [now] starts: the next whole minute at least a
/// minute away, so friends have time to type the code in.
DateTime togetherStart(DateTime now) =>
    DateTime(now.year, now.month, now.day, now.hour, now.minute + 2);

/// The code for a session starting at [start] for [minutes].
String togetherCode(DateTime start, int minutes) {
  final l = togetherLengths.indexOf(minutes);
  assert(l >= 0, '$minutes is not a shared session length');
  final n = (start.hour * 60 + start.minute) * togetherLengths.length + l;
  return (n * _mix % _sessions).toString().padLeft(4, '0');
}

/// What [code] means as seen [now]: the start nearest to now, and the
/// length. Null when it isn't a code.
({DateTime start, int minutes})? readTogetherCode(String code, DateTime now) {
  final c = code.trim();
  if (!RegExp(r'^\d{4}$').hasMatch(c)) return null;
  final n = int.parse(c);
  if (n >= _sessions) return null;
  final x = n * _unmix % _sessions;
  final minute = x ~/ togetherLengths.length;
  var start = DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60);
  // A code made just before midnight starts tomorrow, and the other way.
  final off = start.difference(now);
  if (off < const Duration(hours: -12)) {
    start = DateTime(
      start.year,
      start.month,
      start.day + 1,
      start.hour,
      start.minute,
    );
  } else if (off > const Duration(hours: 12)) {
    start = DateTime(
      start.year,
      start.month,
      start.day - 1,
      start.hour,
      start.minute,
    );
  }
  return (start: start, minutes: togetherLengths[x % togetherLengths.length]);
}

/// Opens Study together.
Future<void> showTogether(BuildContext context, DayStore store) {
  Feel.tap();
  return showTinySheet<void>(context, (_) => TogetherSheet(store: store));
}

class TogetherSheet extends StatefulWidget {
  const TogetherSheet({super.key, required this.store});
  final DayStore store;

  @override
  State<TogetherSheet> createState() => _TogetherSheetState();
}

class _TogetherSheetState extends State<TogetherSheet> {
  final _code = TextEditingController();
  bool _joining = false;
  late int _minutes = togetherLengths.contains(FocusSession.current.length)
      ? FocusSession.current.length
      : 25;

  /// The session she made or joined, while it waits to start.
  ({DateTime start, int minutes, String code})? _plan;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _wait(DateTime start, int minutes, String code) {
    Feel.tap();
    setState(() => _plan = (start: start, minutes: minutes, code: code));
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
  }

  void _make() {
    final start = togetherStart(togetherClock());
    _wait(start, _minutes, togetherCode(start, _minutes));
  }

  /// Starts everyone's clock on the minute.
  void _check() {
    final p = _plan;
    if (p == null || !mounted) return;
    if (togetherClock().isBefore(p.start)) {
      setState(() {});
      return;
    }
    _tick?.cancel();
    final nav = Navigator.of(context, rootNavigator: true);
    FocusSession.current
      ..setStopwatch(false)
      ..setLength(p.minutes)
      ..together = true;
    nav.pop();
    StudyScreen.openOn(nav, widget.store);
  }

  /// What the code typed so far means, or why it can't be joined.
  (({DateTime start, int minutes})?, String?) _read() {
    final c = _code.text.trim();
    if (c.length < 4) return (null, null);
    final now = togetherClock();
    final r = readTogetherCode(c, now);
    if (r == null) {
      return (
        null,
        tr('That isn’t a code. It has 4 digits.', '这不是号码，号码是 4 位数字。'),
      );
    }
    if (!r.start.isAfter(now)) {
      return (
        null,
        tr(
          'That session has already started. Make a new code together.',
          '那次已经开始了，一起生成一个新号码吧。',
        ),
      );
    }
    if (r.start.difference(now) > const Duration(minutes: 15)) {
      return (null, tr('Check the code with your friend.', '和朋友核对一下号码。'));
    }
    return (r, null);
  }

  String _startsAt(DateTime start, int minutes) => tr(
    'Starts at ${clockAt(context, start)} · ${minutesText(minutes)}',
    '${clockAt(context, start)} 开始 · ${minutesText(minutes)}',
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = _plan;
    final busy = FocusSession.current.started;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('together-sheet'),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(title: tr('Study together', '一起学习')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(
                      'For friends sitting together. One of you makes a code, the others type it in, and your timers start at the same moment. Nothing goes online.',
                      '和坐在一起的朋友用。一个人生成号码，其他人输入，大家的计时会在同一刻开始。不联网，什么都不会上传。',
                    ),
                    style: t.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (busy)
                    Text(
                      tr(
                        'Finish the session you’re in first.',
                        '先完成正在进行的这次专注吧。',
                      ),
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    )
                  else if (p != null)
                    ..._waiting(t, p)
                  else if (_joining)
                    ..._join(t)
                  else
                    ..._choose(t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _choose(TextTheme t) => [
    Text(
      tr('How long?', '学多久？'),
      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in togetherLengths)
          ChoiceChip(
            key: Key('together-$m'),
            label: Text(minutesText(m)),
            selected: _minutes == m,
            onSelected: (_) => setState(() => _minutes = m),
          ),
      ],
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      key: const Key('together-make'),
      onPressed: _make,
      icon: const Icon(Icons.pin_outlined),
      label: Text(tr('Make a code', '生成号码')),
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      key: const Key('together-join'),
      onPressed: () {
        Feel.tap();
        setState(() => _joining = true);
      },
      icon: const Icon(Icons.keyboard_outlined),
      label: Text(tr('I have a code', '我有号码')),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    ),
  ];

  List<Widget> _join(TextTheme t) {
    final (r, problem) = _read();
    return [
      TextField(
        key: const Key('together-code'),
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: t.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          labelText: tr('Your friend’s code', '朋友的号码'),
          counterText: '',
          errorText: problem,
          helperText: r == null ? null : _startsAt(r.start, r.minutes),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const Key('together-go'),
        onPressed: r == null
            ? null
            : () => _wait(r.start, r.minutes, _code.text.trim()),
        child: Text(tr('Join', '加入')),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => setState(() {
          _joining = false;
          _code.clear();
        }),
        child: Text(tr('Back', '返回')),
      ),
    ];
  }

  List<Widget> _waiting(
    TextTheme t,
    ({DateTime start, int minutes, String code}) p,
  ) {
    final left = p.start.difference(togetherClock());
    final secs = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    return [
      Text(
        tr('Your code', '号码'),
        textAlign: TextAlign.center,
        style: t.titleSmall?.copyWith(color: context.muted),
      ),
      Text(
        p.code,
        key: const Key('together-shown'),
        textAlign: TextAlign.center,
        style: t.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 10,
          color: context.green,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        _startsAt(p.start, p.minutes),
        textAlign: TextAlign.center,
        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        tr(
          'Starting in ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}. Keep this open. Friends type the same code on their phones.',
          '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')} 后开始。别关掉这里，朋友在自己手机上输入同一个号码。',
        ),
        key: const Key('together-wait'),
        textAlign: TextAlign.center,
        style: t.bodyLarge,
      ),
      const SizedBox(height: 4),
      Text(
        tr(
          'Subject: ${subjectLabel(FocusSession.current.label)}',
          '科目：${subjectLabel(FocusSession.current.label)}',
        ),
        textAlign: TextAlign.center,
        style: t.bodyMedium?.copyWith(color: context.muted),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        key: const Key('together-cancel'),
        onPressed: () {
          _tick?.cancel();
          setState(() => _plan = null);
        },
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(tr('Cancel', '取消')),
      ),
    ];
  }
}
