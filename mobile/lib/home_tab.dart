import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'kitty.dart';
import 'onboarding.dart';
import 'prefs.dart';
import 'stack_sheet.dart';
import 'l10n.dart';
import 'theme.dart';

String clock(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

/// The Pet tab (IMG_6793 to 6798): the cat's room, today's list with a +
/// beside it, and edge tabs that open Chat (left) and Records (right).
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.store,
    required this.onChat,
    required this.onRecords,
    this.onExpense,
  });
  final DayStore store;
  final VoidCallback onChat, onRecords;
  final VoidCallback? onExpense;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  DayStore get _s => widget.store;
  double _dragX = 0;
  bool? _fromLeft;

  String _greeting() {
    final h = DateTime.now().hour;
    final name = Prefs.current.catName;
    if (h < 11) return tr('Good morning! $name is ready for today.', '早上好！$name 准备好陪你开始今天啦。');
    if (h < 17) return tr('Hi again. One small thing at a time.', '又见面啦，一次做好一件小事。');
    if (h < 22) return tr('Evening. How did today go?', '晚上好，今天过得怎么样？');
    return tr('It’s late. $name says rest is a task too.', '很晚啦，$name 说休息也是一件要做的事。');
  }

  Future<void> _addTask() async {
    Feel.tap();
    await showTinySheet<void>(context, (_) => TaskSheet(store: _s));
  }

  Future<void> _newStack() async {
    HapticFeedback.mediumImpact();
    await showTinySheet<void>(
      context,
      (_) => StackSheet(store: _s),
      tall: true,
    );
  }

  Future<void> _open(Task t) async {
    Feel.tap();
    if (t.isStack) {
      await showTinySheet<void>(
        context,
        (_) => StackSheet(store: _s, task: t),
        tall: true,
      );
    } else {
      await showTinySheet<void>(context, (_) => TaskSheet(store: _s, task: t));
    }
  }

  Future<void> _tick(Task t) async {
    final wasDone = t.done;
    await _s.tick(t);
    if (!wasDone && (t.done || t.isStack)) {
      Feel.logged();
      if (t.done) KittyLayer.cheer();
    } else {
      Feel.tap();
    }
  }

  Future<void> _pickTime(Task t) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: t.minutes == null
          ? now
          : TimeOfDay(hour: t.minutes! ~/ 60, minute: t.minutes! % 60),
    );
    if (picked == null) return;
    t.minutes = picked.hour * 60 + picked.minute;
    await _s.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final list = _s.tasksOn(today);
    final countdowns = _s.upcoming().take(3).toList();
    final w = MediaQuery.sizeOf(context).width;

    return GestureDetector(
      // Swipe in from the left edge for Chat, from the right edge for Records.
      onHorizontalDragStart: (d) {
        final x = d.globalPosition.dx;
        _fromLeft = x < 32 ? true : (x > w - 32 ? false : null);
        _dragX = 0;
      },
      onHorizontalDragUpdate: (d) => _dragX += d.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_fromLeft == true && _dragX > 60) widget.onChat();
        if (_fromLeft == false && _dragX < -60) widget.onRecords();
        _fromLeft = null;
      },
      child: Stack(
        children: [
          ListView(
            key: const Key('home-list'),
            padding: EdgeInsets.zero,
            children: [
              RoomScene(
                height: 300 + MediaQuery.paddingOf(context).top,
                catSize: 160,
                child: Positioned(
                  left: 20,
                  right: 20,
                  top: MediaQuery.paddingOf(context).top + 12,
                  child: Text(
                    _greeting(),
                    style: t.titleMedium?.copyWith(
                      color: Palette.ink.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (countdowns.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in countdowns)
                              Chip(
                                avatar: const Icon(
                                  Icons.hourglass_bottom,
                                  size: 16,
                                ),
                                label: Text(
                                  c.daysLeft() == 0
                                      ? tr('${c.title} is today!', '${c.title} 就是今天！')
                                      : tr('${c.title} in ${c.daysLeft()}d', '${c.title} 还有 ${c.daysLeft()} 天'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Today', '今天'),
                                  style: t.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  longDay(today),
                                  style: t.bodyMedium?.copyWith(
                                    color: Palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Tap + for a task; hold it to make a stack.
                          GestureDetector(
                            onLongPress: _newStack,
                            onVerticalDragEnd: (d) {
                              if ((d.primaryVelocity ?? 0) > 100) _newStack();
                            },
                            child: IconButton.filled(
                              key: const Key('add-task'),
                              tooltip: tr('Add for today (hold to make a stack)', '添加今天的事（长按做成一叠）'),
                              iconSize: 28,
                              onPressed: _addTask,
                              icon: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        Panel(
                          child: Row(
                            children: [
                              const CatAvatar(size: 44),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  tr('Nothing here yet. Tap + and add one small thing for today.', '这里还空着。点 +，给今天加一件小事。'),
                                  style: t.bodyMedium?.copyWith(
                                    color: Palette.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final task in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TaskRow(
                              task: task,
                              onTick: () => _tick(task),
                              onTap: () => _open(task),
                              onTime: () => _pickTime(task),
                            ),
                          ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            key: const Key('quick-mood'),
                            avatar: const Icon(
                              Icons.sentiment_satisfied_alt,
                              size: 18,
                            ),
                            label: Text(tr('Log mood', '记心情')),
                            onPressed: () => showMoodSheet(context, _s),
                          ),
                          ActionChip(
                            key: const Key('quick-countdown'),
                            avatar: const Icon(
                              Icons.hourglass_bottom,
                              size: 18,
                            ),
                            label: Text(tr('Countdown', '倒数日')),
                            onPressed: () => addCountdown(context, _s),
                          ),
                          if (widget.onExpense != null)
                            ActionChip(
                              key: const Key('quick-expense'),
                              avatar: const Icon(
                                Icons.payments_outlined,
                                size: 18,
                              ),
                              label: Text(tr('Expense', '记一笔')),
                              onPressed: widget.onExpense,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: MediaQuery.paddingOf(context).top + 150,
            child: EdgeTab(
              key: const Key('edge-chat'),
              label: tr('Chat', '聊天'),
              left: true,
              onTap: widget.onChat,
            ),
          ),
          Positioned(
            right: 0,
            top: MediaQuery.paddingOf(context).top + 150,
            child: EdgeTab(
              key: const Key('edge-records'),
              label: tr('Records', '记录'),
              left: false,
              onTap: widget.onRecords,
            ),
          ),
          if (!Prefs.current.onboarded)
            Positioned.fill(
              child: Onboarding(
                onDone: (start) async {
                  await Prefs.current.setOnboarded();
                  if (start) await _s.addGettingStarted();
                  if (mounted) setState(() {});
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of the list: circle to tick, the title (or the stack's top step)
/// and the time on the right.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onTick,
    required this.onTap,
    this.onTime,
  });
  final Task task;
  final VoidCallback onTick, onTap;
  final VoidCallback? onTime;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final top = task.topStep;
    final title = top?.title ?? task.title;
    return Panel(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      onTap: onTap,
      child: Row(
        children: [
          IconButton(
            key: Key('tick-${task.id}'),
            tooltip: task.done ? tr('Mark to-do', '改回待办') : tr('Done', '完成'),
            onPressed: onTick,
            icon: Icon(
              task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.done ? cs.primary : Palette.muted,
              size: 26,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: task.done ? TextDecoration.lineThrough : null,
                    color: task.done ? Palette.muted : null,
                  ),
                ),
                if (task.isStack)
                  Text(
                    tr('${task.title} · ${task.stepsDone} of ${task.steps.length}', '${task.title} · ${task.stepsDone}/${task.steps.length}'),
                    style: t.bodySmall?.copyWith(color: Palette.muted),
                  ),
              ],
            ),
          ),
          if (task.private)
            Icon(
              Icons.lock_outline,
              size: 16,
              color: Palette.muted,
              semanticLabel: tr('Private', '不公开'),
            ),
          if (task.isStack)
            const Icon(Icons.layers_outlined, size: 18, color: Palette.muted),
          TextButton(
            onPressed: onTime,
            child: Text(
              task.minutes == null ? tr('Any time', '随时') : clock(context, task.minutes!),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or edit a simple task: a title, a time and a note.
class TaskSheet extends StatefulWidget {
  const TaskSheet({super.key, required this.store, this.task, this.day});
  final DayStore store;
  final Task? task;
  final DateTime? day;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final _title = TextEditingController(text: widget.task?.title);
  late final _note = TextEditingController(text: widget.task?.note);
  late int? _minutes = widget.task?.minutes;
  late bool _private = widget.task?.private ?? false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return Navigator.of(context).pop();
    final t = widget.task;
    if (t == null) {
      final n = await widget.store.addTask(
        title,
        day: widget.day,
        minutes: _minutes,
        private: _private,
      );
      n.note = _note.text.trim().isEmpty ? null : _note.text.trim();
      await widget.store.save();
    } else {
      t
        ..title = title
        ..minutes = _minutes
        ..private = _private
        ..note = _note.text.trim().isEmpty ? null : _note.text.trim();
      await widget.store.save();
    }
    Feel.logged();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            title: t != null
                ? tr('Edit', '编辑')
                : widget.day == null || sameDay(widget.day!, DateTime.now())
                ? tr('Add for today', '添加今天的事')
                : tr('Add for ${dayMonth(widget.day!)}', '添加到${dayMonth(widget.day!)}'),
            action: tr('Save', '保存'),
            onAction: _save,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('task-title'),
                  controller: _title,
                  autofocus: t == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: tr('What’s one small thing?', '想做的一件小事是？'),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  decoration: InputDecoration(
                    hintText: tr('Note (optional)', '备注（可不填）'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Palette.muted),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const Key('task-time'),
                      onPressed: () async {
                        final p = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (p != null) {
                          setState(() => _minutes = p.hour * 60 + p.minute);
                        }
                      },
                      child: Text(
                        _minutes == null
                            ? tr('Set a time', '设个时间')
                            : clock(context, _minutes!),
                      ),
                    ),
                    if (_minutes != null)
                      IconButton(
                        tooltip: tr('No time', '不定时间'),
                        onPressed: () => setState(() => _minutes = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    const Spacer(),
                    FilterChip(
                      key: const Key('task-private'),
                      avatar: Icon(
                        _private ? Icons.lock_outline : Icons.public,
                        size: 18,
                      ),
                      showCheckmark: false,
                      selected: _private,
                      label: Text(
                        _private ? tr('Private', '不公开') : tr('Public', '公开'),
                      ),
                      tooltip: tr(
                        'Private tasks aren’t shared with the cat',
                        '不公开的事不会发给小猫',
                      ),
                      onSelected: (v) => setState(() => _private = v),
                    ),
                  ],
                ),
                if (t != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: () async {
                          await widget.store.removeTask(t);
                          Feel.removed();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr('Delete', '删除')),
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

/// Mood diary (IMG_6792): today's date, a 7-day dot row and six moods.
Future<void> showMoodSheet(BuildContext context, DayStore s) =>
    showTinySheet<void>(context, (_) => MoodSheet(store: s), tall: true);

class MoodSheet extends StatefulWidget {
  const MoodSheet({super.key, required this.store});
  final DayStore store;

  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> {
  Mood? _picked;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.store;
    final today = dayOf(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            title: tr('Mood diary', '心情日记'),
            action: tr('Record', '记录'),
            onAction: _picked == null
                ? null
                : () async {
                    await s.addMood(_picked!);
                    Feel.logged();
                    if (context.mounted) Navigator.of(context).pop();
                  },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${tr('Today', '今天')} · ${dayMonthWeekday(today)}',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      tr('${s.moodsOn(today).length} entries', '${s.moodsOn(today).length} 条记录'),
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final d in days)
                      // Today sits in a soft green tile, as in IMG_6792.
                      Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        decoration: BoxDecoration(
                          color: sameDay(d, today) ? Palette.sageSoft : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              sameDay(d, today) ? tr('Today', '今') : '${d.day}',
                              style: t.labelMedium?.copyWith(
                                color: sameDay(d, today)
                                    ? Palette.sage
                                    : Palette.muted,
                                fontWeight: sameDay(d, today)
                                    ? FontWeight.w700
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            MoodDot(mood: s.moodOf(d)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Palette.sand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('How are you feeling right now?', '此刻心情如何？'),
                        style: t.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final m in Mood.values)
                            InkWell(
                              key: Key('mood-${m.name}'),
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Feel.tap();
                                setState(() => _picked = m);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  children: [
                                    MoodFace(
                                      mood: m,
                                      size: 36,
                                      selected: _picked == m,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      zh ? m.zh : m.label,
                                      style: t.labelSmall?.copyWith(
                                        color: Palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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

const moodColors = {
  Mood.happy: Color(0xFFFCEBB6),
  Mood.calm: Color(0xFFDDEFD8),
  Mood.okay: Color(0xFFEDEAE4),
  Mood.tired: Color(0xFFE7E1F4),
  Mood.low: Color(0xFFDDE9F6),
  Mood.anxious: Color(0xFFF9DEDC),
};

/// A small round face for a mood.
class MoodFace extends StatelessWidget {
  const MoodFace({
    super.key,
    required this.mood,
    this.size = 36,
    this.selected = false,
  });
  final Mood mood;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: moodColors[mood],
      shape: BoxShape.circle,
      // A faint ring, or a green one when picked.
      border: Border.all(
        color: selected ? Palette.sage : Palette.ink.withValues(alpha: 0.08),
        width: selected ? 2.5 : 1,
      ),
    ),
    child: CustomPaint(painter: _FacePainter(mood)),
  );
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.mood);
  final Mood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    final p = Paint()
      ..color = Palette.ink.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;
    // Eyes.
    for (final x in [14.0, 26.0]) {
      if (mood == Mood.calm || mood == Mood.tired) {
        canvas.drawLine(
          Offset((x - 2.5) * s, 17 * s),
          Offset((x + 2.5) * s, 17 * s),
          p,
        );
      } else {
        canvas.drawCircle(
          Offset(x * s, 17 * s),
          1.4 * s,
          p..style = PaintingStyle.fill,
        );
        p.style = PaintingStyle.stroke;
      }
    }
    // Mouth.
    final m = Path();
    switch (mood) {
      case Mood.happy:
        m
          ..moveTo(14 * s, 24 * s)
          ..quadraticBezierTo(20 * s, 30 * s, 26 * s, 24 * s);
      case Mood.calm:
        m
          ..moveTo(15 * s, 25 * s)
          ..quadraticBezierTo(20 * s, 28 * s, 25 * s, 25 * s);
      case Mood.okay:
      case Mood.tired:
        m
          ..moveTo(16 * s, 26 * s)
          ..lineTo(24 * s, 26 * s);
      case Mood.low:
        m
          ..moveTo(15 * s, 28 * s)
          ..quadraticBezierTo(20 * s, 23 * s, 25 * s, 28 * s);
      case Mood.anxious:
        m
          ..moveTo(14 * s, 27 * s)
          ..lineTo(17 * s, 25 * s)
          ..lineTo(20 * s, 27 * s)
          ..lineTo(23 * s, 25 * s)
          ..lineTo(26 * s, 27 * s);
    }
    canvas.drawPath(m, p);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.mood != mood;
}

/// A dashed empty circle, or the day's mood face.
class MoodDot extends StatelessWidget {
  const MoodDot({super.key, this.mood, this.size = 30});
  final Mood? mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = mood;
    if (m != null) return MoodFace(mood: m, size: size);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: DashedRing(Palette.muted.withValues(alpha: 0.45), width: 1.2),
      ),
    );
  }
}

/// A dashed circle: an empty day, or the small + on a calendar day.
class DashedRing extends CustomPainter {
  const DashedRing(this.color, {this.width = 1.1});
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2);
    const n = 12;
    const step = 2 * 3.141592653589793 / n;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(r, i * step, step * 0.55, false, p);
    }
  }

  @override
  bool shouldRepaint(DashedRing old) =>
      old.color != color || old.width != width;
}


/// Asks for a name and a date, then adds a countdown.
Future<void> addCountdown(BuildContext context, DayStore s) async {
  final name = TextEditingController();
  DateTime? date;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(tr('New countdown', '新的倒数日')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('countdown-name'),
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                hintText: tr('Exams, a trip, a birthday…', '考试、旅行、生日……'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('countdown-date'),
              icon: const Icon(Icons.event),
              label: Text(
                date == null
                    ? tr('Pick the day', '选日子')
                    : fullDate(date!),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: ctx,
                  firstDate: now,
                  lastDate: DateTime(now.year + 10),
                  initialDate: now.add(const Duration(days: 7)),
                );
                if (d != null) set(() => date = d);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            key: const Key('countdown-save'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Add', '添加')),
          ),
        ],
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  await s.addCountdown(
    name.text.trim(),
    date ?? DateTime.now().add(const Duration(days: 7)),
  );
  Feel.logged();
}
