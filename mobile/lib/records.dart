import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'kitty.dart';
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
            SizedBox(
              height: 200 + MediaQuery.paddingOf(context).top,
              child: Stack(
                children: [
                  const Positioned(
                    right: 8,
                    bottom: 0,
                    child: CatFigure(size: 120),
                  ),
                  Positioned(
                    left: 8,
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 116,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BackButton(),
                            Text(
                              'Records',
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
                                'Timeline',
                                'Focus',
                                'Notes',
                              ].indexed)
                                ChoiceChip(
                                  key: Key('records-$label'),
                                  label: Text(label),
                                  selected: _tab == i,
                                  showCheckmark: false,
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
                1 => FocusTimer(store: widget.store),
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
          tooltip: 'Add',
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
    final chips = ['Study', 'Work', 'Commute', 'Eat', 'Exercise', 'Rest'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AddLine(
          hint: 'What are you doing now?',
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
                  ('08:30', 'Wake up'),
                  ('09:10', 'Study'),
                  ('12:00', 'Lunch'),
                ])
                  Opacity(
                    opacity: 0.45,
                    child: _TimelineRow(
                      time: time,
                      text: what,
                      last: what == 'Lunch',
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'No records yet',
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write what you’re doing and the time is noted for you.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: Palette.muted),
                ),
                const SizedBox(height: 14),
              ] else
                for (final (i, e) in today.indexed)
                  _TimelineRow(
                    time: DateFormat('HH:mm').format(e.at),
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
                      key: Key('timeline-$c'),
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
                style: t.bodyMedium?.copyWith(color: Palette.muted),
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
                  color: Palette.sand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(text, style: t.bodyLarge)),
                    if (onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Palette.muted,
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

/// The focus session in progress. It lives outside the Focus view, so
/// switching to Timeline, Notes or Home doesn't lose it, and it records the
/// session when time is up even if the view is gone.
class FocusSession extends ChangeNotifier {
  FocusSession._();
  static final current = FocusSession._();

  int length = 25;
  Duration _left = const Duration(minutes: 25);
  DateTime? _endsAt;
  Timer? _end;
  DayStore? _store;

  bool get running => _endsAt != null;

  /// Started and not yet finished, running or paused.
  bool get started => running || _left != Duration(minutes: length);

  Duration get left {
    final e = _endsAt;
    if (e == null) return _left;
    final l = e.difference(DateTime.now());
    return l.isNegative ? Duration.zero : l;
  }

  void setLength(int minutes) {
    if (started) return;
    length = minutes;
    _left = Duration(minutes: minutes);
    notifyListeners();
  }

  void start(DayStore store) {
    _store = store;
    _endsAt = DateTime.now().add(_left);
    _end = Timer(_left, () => finish());
    notifyListeners();
  }

  void pause() {
    _left = left;
    _endsAt = null;
    _end?.cancel();
    notifyListeners();
  }

  /// Records the minutes focused (all of them when time ran out) and resets.
  Future<void> finish({bool early = false}) async {
    final spent = (Duration(minutes: length) - left).inMinutes;
    final minutes = early ? spent : length;
    _end?.cancel();
    _endsAt = null;
    _left = Duration(minutes: length);
    notifyListeners();
    final s = _store;
    if (minutes > 0 && s != null) {
      await s.add(s.focus, '$minutes');
      Feel.logged();
      KittyLayer.cheer();
    }
  }
}

/// A focus timer: pick 15, 25 or 45 minutes, the cat keeps you company,
/// and finished sessions count towards today's focus.
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final left = _f.left;
    final total = Duration(minutes: _f.length).inSeconds;
    final progress = 1 - left.inSeconds / total;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final today = widget.store.focusMinutesOn(DateTime.now());
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 15, label: Text('15 min')),
              ButtonSegment(value: 25, label: Text('25 min')),
              ButtonSegment(value: 45, label: Text('45 min')),
            ],
            selected: {_f.length},
            onSelectionChanged: _f.started
                ? null
                : (s) => _f.setLength(s.first),
          ),
          const SizedBox(height: 24),
          SizedBox.square(
            dimension: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(220),
                  painter: _Ring(progress, cs.primary),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CatAvatar(size: 64),
                    const SizedBox(height: 8),
                    Text(
                      '$mm:$ss',
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('focus-start'),
                  onPressed: () {
                    Feel.tap();
                    _f.running ? _f.pause() : _f.start(widget.store);
                  },
                  child: Text(
                    _f.running
                        ? 'Pause'
                        : (_f.started ? 'Keep going' : 'Start focus'),
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
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Focused today: $today min',
            style: t.bodyMedium?.copyWith(color: Palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.progress, this.color);
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
  bool shouldRepaint(_Ring old) => old.progress != progress;
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
          hint: 'Jot something down…',
          onAdd: (v) => store.add(store.notes, v),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No notes yet. Ideas, lists, little thoughts: they all fit here.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: Palette.muted),
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
                      DateFormat('d MMM, HH:mm').format(n.at),
                      style: t.bodySmall?.copyWith(color: Palette.muted),
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
