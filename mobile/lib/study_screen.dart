import 'dart:async';

import 'package:flutter/material.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'records.dart';
import 'remind.dart';
import 'study.dart';
import 'theme.dart';

/// The study view: the whole screen for the clock and the cat, nothing else
/// to tap on. The screen stays on, leaving the app follows the rule she
/// picked, and in Lock me in the phone can be locked to the app.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.store});
  final DayStore store;

  /// Starts the session, or carries on with a paused one, and opens the
  /// study view over everything.
  static Future<void> open(BuildContext context, DayStore store) {
    final f = FocusSession.current;
    if (!f.running) {
      if (!f.started) {
        // The cat's call to come back is a notification.
        Remind.ask();
        if (f.rule == StudyRule.lock) StudyGuard.lock(true);
      }
      f.start(store);
    }
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StudyScreen(store: store),
      ),
    );
  }

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  FocusSession get _f => FocusSession.current;

  /// Redraws the clock; the session itself keeps time.
  Timer? _tick;
  int _ticks = 0;

  /// Guided Access is holding the phone on the app.
  bool _locked = false;

  /// The session that ended while this view was open, for the summary.
  ({int minutes, String label, int left, bool quit})? _done;
  late bool _wasStarted = _f.started;

  @override
  void initState() {
    super.initState();
    _f.addListener(_changed);
    StudyGuard.awake(true);
    _checkLock();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (++_ticks % 4 == 0) _checkLock();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _f.removeListener(_changed);
    StudyGuard.awake(false);
    super.dispose();
  }

  void _changed() {
    if (_wasStarted && !_f.started && _f.last != null) _done = _f.last;
    _wasStarted = _f.started;
    if (mounted) setState(() {});
  }

  Future<void> _checkLock() async {
    if (_f.rule != StudyRule.lock) return;
    final v = await StudyGuard.locked();
    if (mounted && v != _locked) setState(() => _locked = v);
  }

  Future<void> _askStop() async {
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Stop studying?', '不学了吗？')),
        content: Text(tr('The minutes so far are saved.', '已经学习的时间会保存下来。')),
        actions: [
          TextButton(
            key: const Key('study-keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Keep studying', '继续学习')),
          ),
          FilledButton(
            key: const Key('study-stop'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Stop', '结束')),
          ),
        ],
      ),
    );
    if (stop == true) await _f.finish(early: true);
  }

  void _again() {
    Feel.tap();
    setState(() => _done = null);
    if (_f.rule == StudyRule.lock) StudyGuard.lock(true);
    _f.start(widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final done = _done;
    final shown = _f.stopwatch ? _f.elapsed : _f.left;
    final progress = _f.stopwatch
        ? (shown.inSeconds % 60) / 60
        : 1 - _f.left.inSeconds / Duration(minutes: _f.length).inSeconds;
    return PopScope(
      canPop: !_f.running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askStop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('study-close'),
                      tooltip: tr('Close', '关闭'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _RulePill(rule: _f.rule),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CatAvatar(
                            size: 104,
                            mood: done == null
                                ? (_f.isAway ? CatMood.worried : CatMood.happy)
                                : (done.quit ? CatMood.sad : CatMood.delighted),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subjectLabel(done?.label ?? _f.label),
                            key: const Key('study-subject'),
                            style: t.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (done == null) ...[
                            SizedBox.square(
                              dimension: 236,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size.square(236),
                                    painter: FocusRing(progress, cs.primary, track: context.greenSoft),
                                  ),
                                  // Big text shrinks to fit inside the ring.
                                  Padding(
                                    padding: const EdgeInsets.all(30),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        focusClock(shown),
                                        key: const Key('study-clock'),
                                        style: t.displayMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _f.running
                                            ? (_f.stopwatch
                                                  ? tr('Counting up', '正计时')
                                                  : tr(
                                                      'of ${_f.length} min',
                                                      '共 ${_f.length} 分钟',
                                                    ))
                                            : tr('Paused', '已暂停'),
                                        style: t.bodyMedium?.copyWith(
                                          color: context.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_f.note != null)
                              _Line(
                                key: const Key('study-note'),
                                icon: Icons.pets,
                                text: _f.note!,
                              ),
                            Text(
                              _f.leftCount == 0
                                  ? tr(
                                      'You haven’t left the app. Keep it up!',
                                      '你一直没离开，继续加油！',
                                    )
                                  : tr(
                                      'Left the app: ${_f.leftCount} ${_f.leftCount == 1 ? 'time' : 'times'}',
                                      '离开应用：${_f.leftCount} 次',
                                    ),
                              key: const Key('study-left'),
                              style: t.bodyMedium?.copyWith(
                                color: context.muted,
                              ),
                            ),
                            if (_f.rule == StudyRule.lock) ...[
                              const SizedBox(height: 12),
                              _LockCard(locked: _locked),
                            ],
                          ] else
                            _Summary(done: done, locked: _locked),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (done != null)
                  Row(
                    children: [
                      if (done.quit) ...[
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('study-again'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(64, 52),
                            ),
                            onPressed: _again,
                            child: Text(tr('Try again', '再来一次')),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          key: const Key('study-finish'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(tr('Close', '关闭')),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('study-pause'),
                          onPressed: () {
                            Feel.tap();
                            _f.running ? _f.pause() : _f.start(widget.store);
                          },
                          child: Text(
                            _f.running
                                ? tr('Pause', '暂停')
                                : tr('Keep going', '继续'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        key: const Key('study-done'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 52),
                        ),
                        onPressed: () => _f.finish(early: true),
                        child: Text(tr('Done', '完成')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rule she picked, at the top right.
class _RulePill extends StatelessWidget {
  const _RulePill({required this.rule});
  final StudyRule rule;

  @override
  Widget build(BuildContext context) => Chip(
    key: const Key('study-rule'),
    avatar: Icon(switch (rule) {
      StudyRule.nudge => Icons.notifications_active_outlined,
      StudyRule.strict => Icons.timer_off_outlined,
      StudyRule.lock => Icons.lock_outline,
    }, size: 18),
    label: Text(rule.label),
  );
}

/// A soft line with an icon, for what the cat says.
class _Line extends StatelessWidget {
  const _Line({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// Lock me in: whether the phone is locked to the app, and how to lock it.
class _LockCard extends StatelessWidget {
  const _LockCard({required this.locked});
  final bool locked;

  @override
  Widget build(BuildContext context) => Panel(
    key: const Key('study-lock'),
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    child: Row(
      children: [
        Icon(
          locked ? Icons.lock : Icons.lock_open,
          color: locked ? Theme.of(context).colorScheme.primary : context.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            locked
                ? tr(
                    'Locked to this app. When you finish, triple-click the side button and enter your passcode.',
                    '已锁定在这个应用里。完成后，连按三下侧边按钮并输入密码。',
                  )
                : tr(
                    'Not locked yet. Triple-click the side button to lock the phone to this app.',
                    '还没锁定。连按三下侧边按钮，把手机锁定在这个应用里。',
                  ),
          ),
        ),
        if (!locked)
          TextButton(
            key: const Key('study-lock-help'),
            onPressed: () =>
                showTinySheet<void>(context, (_) => const LockHelp()),
            child: Text(tr('How?', '怎么做？')),
          ),
      ],
    ),
  );
}

/// How to turn on Guided Access, once, so a triple-click locks the phone
/// to the app.
class LockHelp extends StatelessWidget {
  const LockHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = [
      tr(
        'Open Settings, then Accessibility, then Guided Access, and turn it on.',
        '打开“设置”→“辅助功能”→“引导式访问”，把它打开。',
      ),
      tr(
        'Tap Passcode Settings and set a passcode. A parent can set it, so only they can unlock it.',
        '轻点“密码设置”设一个密码。可以请家长来设，这样只有家长能解锁。',
      ),
      tr(
        'Come back here and triple-click the side button (the Home button on older iPhones), then tap Start.',
        '回到这里，连按三下侧边按钮（旧款 iPhone 是主屏幕按钮），再轻点“开始”。',
      ),
      tr(
        'When you finish, triple-click again and enter the passcode.',
        '完成后再连按三下，输入密码即可退出。',
      ),
    ];
    // Scrolls when the steps don't fit, on a small phone with big text.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Lock the phone to this app', '把手机锁定在这个应用里'),
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'The iPhone’s Guided Access keeps you in one app until the passcode is entered. You set it up once.',
              'iPhone 的“引导式访问”会把你留在一个应用里，直到输入密码。只需设置一次。',
            ),
            style: t.bodyMedium?.copyWith(color: context.muted),
          ),
          const SizedBox(height: 14),
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('${i + 1}', style: t.labelMedium),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s, style: t.bodyLarge)),
                ],
              ),
            ),
          Text(
            tr(
              'On Android, use App pinning in Settings, under Security.',
              '安卓手机可在“设置”的“安全”里使用“固定应用”。',
            ),
            style: t.bodySmall?.copyWith(color: context.muted),
          ),
        ],
      ),
    );
  }
}

/// What the cat says when a session is over.
class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.locked});
  final ({int minutes, String label, int left, bool quit}) done;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final what = subjectLabel(done.label);
    final n = done.left;
    final text = done.quit && done.minutes == 0
        ? tr(
            'You left the app, so this one doesn’t count. Shall we try again?',
            '你离开了应用，这次不计入。要再来一次吗？',
          )
        : done.quit
        ? tr(
            'You left the app, so these ${done.minutes} min don’t count. Shall we try again?',
            '你离开了应用，这 ${done.minutes} 分钟不计入。要再来一次吗？',
          )
        : done.minutes == 0
        ? tr(
            'Under a minute this time. Every little bit counts!',
            '这次不到一分钟。一点一点来就好！',
          )
        : n == 0
        ? tr(
            '${done.minutes} min of $what, and you never left the app.',
            '完成 ${done.minutes} 分钟「$what」，一次都没离开！',
          )
        : tr(
            '${done.minutes} min of $what. You left the app $n ${n == 1 ? 'time' : 'times'}.',
            '完成 ${done.minutes} 分钟「$what」，离开应用 $n 次。',
          );
    return Panel(
      key: const Key('study-summary'),
      child: Column(
        children: [
          Text(
            done.quit
                ? tr('This session ended', '这次专注结束了')
                : tr('Well done!', '做得好！'),
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: t.bodyLarge),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
              tr(
                'Triple-click the side button and enter your passcode to unlock the phone.',
                '连按三下侧边按钮并输入密码，就能解锁手机。',
              ),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: context.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Study time on the Focus page: today, the last 7 days, by subject, and the
/// latest sessions, including the ones that ended because she left.
class StudyLog extends StatelessWidget {
  const StudyLog({super.key, required this.store, this.now});
  final DayStore store;
  final DateTime? now;

  static int _minutes(Entry e) => int.tryParse(e.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final today = now ?? DateTime.now();
    final from = DateTime(today.year, today.month, today.day - 6);
    final week = store.focus.where((e) => !e.at.isBefore(from)).toList();
    final bySubject = <String, int>{};
    for (final e in week.where((e) => !e.quit)) {
      bySubject.update(
        subjectLabel(e.kind),
        (v) => v + _minutes(e),
        ifAbsent: () => _minutes(e),
      );
    }
    final subjects = bySubject.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final most = subjects.isEmpty ? 1 : subjects.first.value;
    final left = week.fold(0, (n, e) => n + e.left);
    final recent = store.focus.reversed.take(10).toList();
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: t.bodySmall?.copyWith(color: context.muted)),
        ],
      ),
    );
    return Panel(
      key: const Key('study-log'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Study time', '学习时间'),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(
                tr(
                  '${store.focusMinutesOn(today)} min',
                  '${store.focusMinutesOn(today)} 分钟',
                ),
                tr('Today', '今天'),
              ),
              stat(
                tr(
                  '${store.focusMinutesWeek(today)} min',
                  '${store.focusMinutesWeek(today)} 分钟',
                ),
                tr('7 days', '近 7 天'),
              ),
              stat(tr('$left×', '$left 次'), tr('Left the app', '离开应用')),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              tr('Last 7 days by subject', '近 7 天各科目'),
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final s in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        s.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.value / most,
                          minHeight: 8,
                          color: cs.primary,
                          backgroundColor: context.greenSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr('${s.value} min', '${s.value} 分钟'),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            tr('Recent sessions', '最近的专注'),
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr('Your study sessions will show here.', '你的专注记录会显示在这里。'),
                style: t.bodyMedium?.copyWith(color: context.muted),
              ),
            ),
          for (final e in recent)
            Padding(
              key: Key('session-${e.id}'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    e.quit ? Icons.cancel_outlined : Icons.check_circle_outline,
                    size: 20,
                    color: e.quit ? context.muted : cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subjectLabel(e.kind),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            '${dayMonth(e.at)} ${hhmm(e.at)}',
                            if (e.left > 0)
                              tr('left ${e.left}×', '离开 ${e.left} 次'),
                          ].join(' · '),
                          style: t.bodySmall?.copyWith(color: context.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    e.quit
                        ? tr('Ended early', '提前结束')
                        : tr('${_minutes(e)} min', '${_minutes(e)} 分钟'),
                    style: t.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: e.quit ? context.muted : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
