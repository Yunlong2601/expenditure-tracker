import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'study.dart';
import 'study_screen.dart';
import 'theme.dart';

/// Records (IMG_6782), opened by swiping in from the right on Home:
/// Timeline, Focus and Notes.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.store, this.tab = 0});
  final DayStore store;
  final int tab;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late var _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => ListView(
          padding: EdgeInsets.zero,
          children: [
            // At least the art's height; taller when big text wraps the tabs
            // onto more lines, so none is cut off.
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 196 + MediaQuery.paddingOf(context).top,
              ),
              child: Stack(
                children: [
                  // The cat writing notes, at the top right as in IMG_6782.
                  Positioned(
                    right: 0,
                    top: 0,
                    child: SceneArt(
                      kind: SceneKind.writing,
                      width: 215,
                      height: 184 + MediaQuery.paddingOf(context).top,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      top: MediaQuery.paddingOf(context).top + 40,
                      right: 110,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BackButton(),
                            Text(
                              tr('Records', '记录'),
                              style: t.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final (i, label) in [
                                tr('Timeline', '时间轴'),
                                tr('Focus', '专注'),
                                tr('Notes', '笔记'),
                              ].indexed)
                                ChoiceChip(
                                  key: Key('records-$i'),
                                  label: Text(label),
                                  selected: _tab == i,
                                  showCheckmark: false,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  // White with a thin edge, soft green when
                                  // open, as in the wireframe.
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  selectedColor: Theme.of(context).chipTheme.backgroundColor,
                                  side: BorderSide(
                                    color: _tab == i
                                        ? Colors.transparent
                                        : const Color(0xFFE6E0D6),
                                  ),
                                  labelStyle: TextStyle(
                                    fontSize: 16,
                                    color: _tab == i
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: _tab == i
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  onSelected: (_) {
                                    Feel.tap();
                                    setState(() => _tab = i);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: switch (_tab) {
                0 => _Timeline(store: widget.store),
                1 => Column(
                  children: [
                    FocusTimer(store: widget.store),
                    const SizedBox(height: 16),
                    StudyLog(store: widget.store),
                  ],
                ),
                _ => _Notes(store: widget.store),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded "+ placeholder" input that adds a line when submitted.
class AddLine extends StatefulWidget {
  const AddLine({super.key, required this.hint, required this.onAdd});
  final String hint;
  final ValueChanged<String> onAdd;

  @override
  State<AddLine> createState() => AddLineState();
}

class AddLineState extends State<AddLine> {
  final _c = TextEditingController();

  void add([String? text]) {
    final v = (text ?? _c.text).trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _c.clear();
    Feel.logged();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Row(
      children: [
        IconButton(
          tooltip: tr('Add', '添加'),
          icon: Icon(Icons.add, color: Colors.orange.shade400),
          onPressed: add,
        ),
        Expanded(
          child: TextField(
            controller: _c,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: InputBorder.none,
            ),
            onSubmitted: add,
          ),
        ),
      ],
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.store});
  final DayStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = store.timeline
        .where((e) => sameDay(e.at, DateTime.now()))
        .toList();
    final chips = zh ? ['学习', '工作', '通勤', '吃饭', '运动', '休息'] : ['Study', 'Work', 'Commute', 'Eat', 'Exercise', 'Rest'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddLine(
          hint: tr('What are you doing now?', '现在在做什么？'),
          onAdd: (v) => store.add(store.timeline, v),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (today.isEmpty) ...[
                // Faded sample lines, as in the wireframe.
                for (final (time, what) in [
                  ('08:30', tr('Wake up', '起床')),
                  ('09:10', tr('Study', '学习')),
                  ('12:00', tr('Lunch', '吃饭')),
                ])
                  Opacity(
                    opacity: 0.45,
                    child: _TimelineRow(
                      time: time,
                      text: what,
                      last: time == '12:00',
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  tr('No records yet', '还没有记录'),
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('Write what you’re doing and the time is noted for you.', '写下正在做的事，开始时间会自动记下'),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: context.muted),
                ),
                const SizedBox(height: 14),
              ] else
                for (final (i, e) in today.indexed)
                  _TimelineRow(
                    time: hhmm(e.at),
                    text: e.text,
                    last: i == today.length - 1,
                    onDelete: () => store.remove(store.timeline, e),
                  ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in chips)
                    ActionChip(
                      key: Key('timeline-${chips.indexOf(c)}'),
                      label: Text(c),
                      onPressed: () => store
                          .add(store.timeline, c)
                          .then((_) => Feel.logged()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.time,
    required this.text,
    this.last = false,
    this.onDelete,
  });
  final String time, text;
  final bool last;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                time,
                style: t.bodyMedium?.copyWith(color: context.muted),
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 17),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF9CC293),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 1.5, color: Palette.line)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.sand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(text, style: t.bodyLarge)),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: context.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The calm sounds for focus, made for this app, in assets/sounds.
const focusSounds = ['rain', 'waves', 'fire'];

String focusSoundLabel(String? name) => switch (name) {
  'rain' => tr('Rain', '雨声'),
  'waves' => tr('Waves', '海浪'),
  'fire' => tr('Fire', '炉火'),
  _ => tr('Off', '关'),
};

/// The focus session in progress. It lives outside the Focus view, so
/// switching to Timeline, Notes or Home doesn't lose it, and it records the
/// session when time is up even if the view is gone. A timer counts down
/// from [length] minutes; a stopwatch counts up until she taps Done.
///
/// It also keeps watch while she studies: [appLeft] and [appBack] follow the
/// app going into the background and coming back, and the [rule] she picked
/// says what leaving does.
class FocusSession extends ChangeNotifier {
  FocusSession._();
  static final current = FocusSession._();

  int length = 25;
  bool stopwatch = false;

  /// The task this session is for, if it was started from one.
  String? task;

  /// The subject picked on the Focus page; it stays for the next session.
  String subject = 'study';

  /// What the session is saved and shown as: the task, or the subject.
  String get label => task ?? subject;

  /// Times she left the app in this session, and how long she was away.
  int leftCount = 0;
  Duration away = Duration.zero;
  DateTime? _leftAt;

  /// What the cat says about the last time she left, for the study view.
  String? note;

  /// The session that finished last, for the study view's summary.
  ({int minutes, String label, int left, bool quit})? last;

  Duration _left = const Duration(minutes: 25);
  Duration _counted = Duration.zero;
  DateTime? _endsAt;
  DateTime? _since;
  Timer? _end;
  DayStore? _store;

  bool get running => _endsAt != null || _since != null;

  /// Started and not yet finished, running or paused.
  bool get started =>
      running ||
      _leftAt != null ||
      (stopwatch ? _counted > Duration.zero : _left != Duration(minutes: length));

  /// Away from the app right now, with the clock held until she is back.
  bool get isAway => _leftAt != null;

  Duration get left {
    final e = _endsAt;
    if (e == null) return _left;
    final l = e.difference(DateTime.now());
    return l.isNegative ? Duration.zero : l;
  }

  /// Time counted so far.
  Duration get elapsed {
    if (stopwatch) {
      final s = _since;
      return s == null ? _counted : _counted + DateTime.now().difference(s);
    }
    return Duration(minutes: length) - left;
  }

  /// Any length from 1 minute to 4 hours.
  void setLength(int minutes) {
    if (started) return;
    length = minutes.clamp(1, 240);
    _left = Duration(minutes: length);
    notifyListeners();
  }

  void setStopwatch(bool on) {
    if (started) return;
    stopwatch = on;
    notifyListeners();
  }

  /// Gets ready to focus on [title]; a session already going keeps its own.
  void forTask(String title) {
    if (started) return;
    task = title;
    notifyListeners();
  }

  void clearTask() {
    task = null;
    notifyListeners();
  }

  void setSubject(String key) {
    if (started) return;
    subject = key;
    task = null;
    notifyListeners();
  }

  /// What leaving the app does, from Prefs.
  StudyRule get rule =>
      StudyRule.values[Prefs.current.studyRule.clamp(0, StudyRule.values.length - 1)];
  Future<void> setRule(StudyRule r) async {
    if (started) return;
    await Prefs.current.setStudyRule(r.index);
    notifyListeners();
  }

  /// The calm sound, from Prefs. Changing it while running switches at once.
  String? get sound => Prefs.current.focusSound;
  Future<void> setSound(String? name) async {
    await Prefs.current.setFocusSound(name);
    if (running) Feel.loop(name);
    notifyListeners();
  }

  /// No session going: the next start begins a new one.
  bool _fresh = true;

  void start(DayStore store) {
    _store = store;
    if (_fresh) {
      _fresh = false;
      leftCount = 0;
      away = Duration.zero;
      note = null;
      last = null;
    }
    if (stopwatch) {
      _since = DateTime.now();
    } else {
      _endsAt = DateTime.now().add(_left);
      _end = Timer(_left, () => finish());
    }
    if (sound != null) Feel.loop(sound);
    notifyListeners();
  }

  void pause() {
    if (stopwatch) {
      _counted = elapsed;
      _since = null;
    } else {
      _left = left;
      _endsAt = null;
      _end?.cancel();
    }
    Feel.loop(null);
    notifyListeners();
  }

  /// The app went into the background while the clock was running: hold the
  /// clock, and line up the cat's call to come back.
  void appLeft([DateTime? now]) {
    if (!running || _leftAt != null) return;
    _leftAt = now ?? DateTime.now();
    leftCount++;
    pause();
    final name = Prefs.current.catName;
    final what = subjectLabel(label);
    StudyGuard.callBack(
      rule == StudyRule.nudge
          ? [
              (
                seconds: 5,
                body: tr(
                  '$name paused your $what. Come back and finish it!',
                  '$name帮你暂停了「$what」，快回来完成它吧！',
                ),
              ),
            ]
          : [
              (
                seconds: 3,
                body: tr(
                  'Come back within 15 seconds to keep your $what going!',
                  '15 秒内回来，「$what」就能继续！',
                ),
              ),
              (
                seconds: studyGrace.inSeconds + 1,
                body: tr(
                  'Your $what ended because you left. $name is waiting to try again.',
                  '你离开了，「$what」已结束。$name在等你再来一次。',
                ),
              ),
            ],
    );
  }

  /// The app is back in front. A short trip carries on where she left off;
  /// in Strict and Lock me in, a long one ends the session.
  Future<void> appBack([DateTime? now]) async {
    final l = _leftAt;
    if (l == null) return;
    _leftAt = null;
    StudyGuard.cancelCallBack();
    final d = (now ?? DateTime.now()).difference(l);
    away += d;
    if (rule != StudyRule.nudge && d > studyGrace) {
      note = tr(
        'You were away for ${awayText(d)}, so this session ended.',
        '你离开了 ${awayText(d)}，这次专注结束了。',
      );
      await finish(early: true, quit: true);
      return;
    }
    note = tr(
      'Welcome back! You were away for ${awayText(d)}.',
      '欢迎回来！你离开了 ${awayText(d)}。',
    );
    final s = _store;
    if (s != null) start(s);
  }

  /// Records the minutes focused (all of them when time ran out) and resets.
  /// A session that ended because she left is kept, marked [quit], and its
  /// minutes don't count towards her totals.
  Future<void> finish({bool early = false, bool quit = false}) async {
    final minutes = stopwatch
        ? elapsed.inMinutes
        : (early ? elapsed.inMinutes : length);
    final name = label;
    final times = leftCount;
    _end?.cancel();
    _endsAt = null;
    _since = null;
    _leftAt = null;
    _counted = Duration.zero;
    _left = Duration(minutes: length);
    task = null;
    leftCount = 0;
    _fresh = true;
    last = (minutes: minutes, label: name, left: times, quit: quit);
    Feel.loop(null);
    if (rule == StudyRule.lock) StudyGuard.lock(false);
    notifyListeners();
    final s = _store;
    if (s != null && (minutes > 0 || quit)) {
      await s.add(s.focus, '$minutes', kind: name, left: times, quit: quit);
      if (quit) {
        Feel.oops();
      } else {
        Feel.logged();
        KittyLayer.cheer();
      }
    }
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "25:00", or "1:05:09" past an hour.
String focusClock(Duration d) => d.inHours > 0
    ? '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}'
    : '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';

/// A focus timer: 15, 25, 45 or any minutes, or a stopwatch that counts
/// up; a calm sound if she likes; the cat keeps her company, and finished
/// sessions count towards today's focus.
class FocusTimer extends StatefulWidget {
  const FocusTimer({super.key, required this.store});
  final DayStore store;

  @override
  State<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<FocusTimer> {
  FocusSession get _f => FocusSession.current;

  /// Redraws the clock; the session itself keeps time.
  Timer? _redraw;

  @override
  void initState() {
    super.initState();
    _f.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (_f.running && _redraw == null) {
      _redraw = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_f.running) {
      _redraw?.cancel();
      _redraw = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _f.removeListener(_changed);
    _redraw?.cancel();
    super.dispose();
  }

  Future<void> _custom() async {
    final c = TextEditingController(text: '${_f.length}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('How many minutes?', '专注多少分钟？')),
        content: TextField(
          key: const Key('focus-length-field'),
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: tr('min', '分钟'),
            helperText: tr('1 to 240', '1 到 240'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            key: const Key('focus-length-save'),
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(c.text.trim())),
            child: Text(tr('OK', '好')),
          ),
        ],
      ),
    );
    if (v != null && v > 0) _f.setLength(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final shown = _f.stopwatch ? _f.elapsed : _f.left;
    final clockText = focusClock(shown);
    final progress = _f.stopwatch
        ? (shown.inSeconds % 60) / 60
        : 1 - _f.left.inSeconds / Duration(minutes: _f.length).inSeconds;
    final today = widget.store.focusMinutesOn(DateTime.now());
    final locked = _f.started;
    final preset = const [15, 25, 45].contains(_f.length);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text(tr('Timer', '倒计时'), key: const Key('focus-mode-timer')),
              ),
              ButtonSegment(
                value: true,
                label: Text(tr('Stopwatch', '正计时'), key: const Key('focus-mode-stopwatch')),
              ),
            ],
            selected: {_f.stopwatch},
            onSelectionChanged: locked ? null : (v) => _f.setStopwatch(v.first),
          ),
          const SizedBox(height: 12),
          if (!_f.stopwatch)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final m in const [15, 25, 45])
                  ChoiceChip(
                    key: Key('focus-$m'),
                    label: Text(tr('$m min', '$m 分钟')),
                    selected: _f.length == m,
                    onSelected: locked ? null : (_) => _f.setLength(m),
                  ),
                ChoiceChip(
                  key: const Key('focus-custom'),
                  avatar: const Icon(Icons.tune, size: 16),
                  label: Text(preset ? tr('Other', '自定') : tr('${_f.length} min', '${_f.length} 分钟')),
                  selected: !preset,
                  onSelected: locked ? null : (_) => _custom(),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (_f.task == null)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final k in studySubjects)
                  ChoiceChip(
                    key: Key('subject-$k'),
                    label: Text(subjectLabel(k)),
                    selected: _f.subject == k,
                    onSelected: locked ? null : (_) => _f.setSubject(k),
                  ),
              ],
            ),
          if (_f.task != null) ...[
            InputChip(
              key: const Key('focus-task'),
              avatar: const Icon(Icons.task_alt, size: 18),
              label: Text(tr('For: ${_f.task}', '专注：${_f.task}')),
              onDeleted: locked ? null : _f.clearTask,
              deleteButtonTooltipMessage: tr('Not for a task', '不关联任务'),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox.square(
            dimension: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(210),
                  painter: FocusRing(progress, cs.primary),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CatAvatar(size: 60),
                    const SizedBox(height: 8),
                    Text(
                      clockText,
                      key: const Key('focus-clock'),
                      style: t.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.music_note_outlined, size: 18, color: context.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final name in [null, ...focusSounds])
                      ChoiceChip(
                        key: Key('sound-${name ?? 'off'}'),
                        label: Text(focusSoundLabel(name)),
                        selected: _f.sound == name,
                        onSelected: (_) {
                          Feel.tap();
                          _f.setSound(name);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('If I leave the app', '如果我离开应用'),
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<StudyRule>(
              showSelectedIcon: false,
              segments: [
                for (final r in StudyRule.values)
                  ButtonSegment(
                    value: r,
                    label: Text(r.label, key: Key('rule-${r.name}')),
                  ),
              ],
              selected: {_f.rule},
              onSelectionChanged: locked
                  ? null
                  : (v) {
                      Feel.tap();
                      _f.setRule(v.first);
                    },
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _f.rule.about,
              key: const Key('rule-about'),
              style: t.bodySmall?.copyWith(color: context.muted),
            ),
          ),
          if (_f.rule == StudyRule.lock)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('rule-lock-help'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => showTinySheet<void>(context, (_) => const LockHelp()),
                child: Text(tr('How to set up Guided Access', '如何设置“引导式访问”')),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('focus-start'),
                  onPressed: () {
                    Feel.tap();
                    StudyScreen.open(context, widget.store);
                  },
                  child: Text(
                    _f.running
                        ? tr('Back to studying', '回到学习')
                        : (_f.started ? tr('Keep going', '继续') : tr('Start studying', '开始学习')),
                  ),
                ),
              ),
              if (_f.started) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('focus-stop'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 52),
                  ),
                  onPressed: () => _f.finish(early: true),
                  child: Text(tr('Done', '完成')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr('Focused today: $today min', '今天已专注 $today 分钟'),
            style: t.bodyMedium?.copyWith(color: context.muted),
          ),
        ],
      ),
    );
  }
}

/// The ring round the focus clock, filling as time goes.
class FocusRing extends CustomPainter {
  FocusRing(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = Palette.sageSoft);
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(FocusRing old) => old.progress != progress;
}

class _Notes extends StatelessWidget {
  const _Notes({required this.store});
  final DayStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final notes = store.notes.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddLine(
          hint: tr('Jot something down…', '随手记点什么……'),
          onAdd: (v) => store.add(store.notes, v),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              tr('No notes yet. Ideas, lists, little thoughts: they all fit here.', '还没有笔记。想法、清单、小心思，都可以放在这里。'),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: context.muted),
            ),
          ),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => store.remove(store.notes, n),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.text, style: t.bodyLarge),
                    const SizedBox(height: 6),
                    Text(
                      '${dayMonth(n.at)} ${hhmm(n.at)}',
                      style: t.bodySmall?.copyWith(color: context.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
