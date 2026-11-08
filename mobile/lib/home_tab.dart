import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'companion.dart';
import 'day.dart';
import 'exam.dart';
import 'feel.dart';
import 'kitty.dart';
import 'onboarding.dart';
import 'prefs.dart';
import 'records.dart';
import 'remind.dart';
import 'room.dart';
import 'stack_sheet.dart';
import 'l10n.dart';
import 'theme.dart';

String clock(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

/// The Pet tab (IMG_6793 to 6798): the cat's room, today's list with a +
/// beside it, and edge tabs that open Chat (left) and Records (right).
/// Schedule (IMG_6789) shows a week strip to plan any day; the magnifier
/// searches every task.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.store,
    required this.onChat,
    required this.onRecords,
    this.onExpense,
    this.onFocus,
  });
  final DayStore store;
  final VoidCallback onChat, onRecords;
  final VoidCallback? onExpense;

  /// Opens the focus timer, from the exam card.
  final VoidCallback? onFocus;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  DayStore get _s => widget.store;
  double _dragX = 0;
  bool? _fromLeft;

  /// Schedule shows the week strip and the picked day's list.
  bool _schedule = false;
  DateTime _day = dayOf(DateTime.now());

  /// The day the list shows and + adds to.
  DateTime get _shown => _schedule ? _day : dayOf(DateTime.now());

  void _show(bool schedule) {
    Feel.tap();
    setState(() {
      _schedule = schedule;
      if (!schedule) _day = dayOf(DateTime.now());
    });
  }

  void _pickDay(DateTime d) {
    Feel.tap();
    setState(() => _day = dayOf(d));
  }

  Future<void> _search() async {
    Feel.tap();
    await showTinySheet<void>(
      context,
      (_) => TaskSearchSheet(store: _s),
      tall: true,
    );
  }

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
    await showTinySheet<void>(
      context,
      (_) => TaskSheet(store: _s, day: _schedule ? _day : null),
    );
  }

  Future<void> _newStack() async {
    HapticFeedback.mediumImpact();
    await showTinySheet<void>(
      context,
      (_) => StackSheet(store: _s, day: _schedule ? _day : null),
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
      if (t.done) {
        KittyLayer.cheer();
        CatFigure.hop();
      }
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
    // A first time on a task turns its reminder on.
    if (t.minutes == null && !t.isStack) t.remind = true;
    t.minutes = picked.hour * 60 + picked.minute;
    await _s.save();
    if (t.remind) await Remind.ask();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final shown = _shown;
    final list = _s.tasksOn(shown);
    final isToday = sameDay(shown, today);
    // In exam season the exam has its own card, so its chip would say it twice.
    final exam = _s.examSoon();
    final countdowns = _s.upcoming().where((c) => c != exam).take(3).toList();
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
              // Calm has a shorter room and a smaller cat, so the list
              // comes up sooner.
              RoomScene(
                height: (context.calm ? 250 : 300) + MediaQuery.paddingOf(context).top,
                catSize: context.calm ? 128 : 160,
                items: _s.room,
                outfit: _s.outfit,
                child: Positioned(
                  left: 20,
                  right: 20,
                  top: MediaQuery.paddingOf(context).top + 12,
                  // On a soft label of its own, so the words never sit on
                  // the window or the wall behind.
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _greeting(),
                        style: t.titleMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                      // In exam season, the exam comes first.
                      if (exam != null) ...[
                        ExamCard(
                          store: _s,
                          exam: exam,
                          onStudy: widget.onFocus ?? widget.onRecords,
                        ),
                        const SizedBox(height: 16),
                      ],
                      // The streak, the paws that fill the room above,
                      // and the next big days, on one line.
                      ChipRow(
                        children: [
                          ...roomChips(context, _s),
                          for (final c in countdowns)
                            Chip(
                              avatar: const Icon(
                                Icons.hourglass_bottom,
                                size: 16,
                              ),
                              label: Text(
                                c.daysLeft() == 0
                                    ? tr('${c.title} is today!', '${c.title} 就是今天！')
                                    : tr('${c.title} in ${count(c.daysLeft(), 'day')}', '${c.title} 还有 ${c.daysLeft()} 天'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // On a small phone with big text the headings
                          // shrink a little instead of pushing the buttons off.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  HeadTab(
                                    key: const Key('tab-today'),
                                    label: tr('Today', '今天'),
                                    on: !_schedule,
                                    onTap: () => _show(false),
                                  ),
                                  const SizedBox(width: 18),
                                  HeadTab(
                                    key: const Key('tab-schedule'),
                                    label: tr('Schedule', '日程'),
                                    on: _schedule,
                                    onTap: () => _show(true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('search-tasks'),
                            tooltip: tr('Search tasks', '搜索任务'),
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                          ),
                          // Tap + for a task; hold it to make a stack.
                          GestureDetector(
                            onLongPress: _newStack,
                            onVerticalDragEnd: (d) {
                              if ((d.primaryVelocity ?? 0) > 100) _newStack();
                            },
                            child: IconButton.filled(
                              key: const Key('add-task'),
                              tooltip: isToday
                                  ? tr('Add for today (hold to make a stack)', '添加今天的事（长按做成一叠）')
                                  : tr('Add for ${dayMonth(shown)} (hold to make a stack)', '添加到${dayMonth(shown)}（长按做成一叠）'),
                              iconSize: 28,
                              onPressed: _addTask,
                              icon: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        longDay(shown),
                        style: t.bodyMedium?.copyWith(color: context.muted),
                      ),
                      if (_schedule) ...[
                        const SizedBox(height: 10),
                        Panel(
                          key: const Key('schedule-week'),
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: tr('Last week', '上一周'),
                                    onPressed: () => _pickDay(_day.subtract(const Duration(days: 7))),
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Expanded(
                                    child: Text(
                                      monthYear(_day),
                                      textAlign: TextAlign.center,
                                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: tr('Next week', '下一周'),
                                    onPressed: () => _pickDay(_day.add(const Duration(days: 7))),
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                  // Shrinks with very big text on a narrow phone.
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 96),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: PillButton(
                                        key: const Key('schedule-today'),
                                        label: tr('Today', '今天'),
                                        dense: true,
                                        onPressed: () => _pickDay(DateTime.now()),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ),
                              WeekStrip(
                                id: 'schedule',
                                start: weekStart(_day),
                                picked: _day,
                                onPick: _pickDay,
                                marks: {
                                  for (var i = 0; i < 7; i++)
                                    if (_s.tasksOn(weekStart(_day).add(Duration(days: i))).isNotEmpty) i,
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (list.isEmpty)
                        Panel(
                          child: Row(
                            children: [
                              const CatAvatar(size: 44),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  isToday
                                      ? tr('Nothing here yet. Tap + and add one small thing for today.', '这里还空着。点 +，给今天加一件小事。')
                                      : tr('Nothing planned for this day. Tap + to plan one.', '这天还没有安排。点 + 安排一件。'),
                                  style: t.bodyMedium?.copyWith(
                                    color: context.muted,
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
              icon: Icons.chat_bubble_outline_rounded,
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
              icon: Icons.edit_note_rounded,
              left: false,
              onTap: widget.onRecords,
            ),
          ),
          if (!Prefs.current.onboarded)
            Positioned.fill(
              // VoiceOver reads only the welcome card, not the list it covers.
              child: BlockSemantics(
                child: Onboarding(
                  onDone: (start) async {
                    await Prefs.current.setOnboarded();
                    if (start) await _s.addGettingStarted();
                    if (mounted) setState(() {});
                  },
                ),
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
              color: task.done ? cs.primary : context.muted,
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
                    color: task.done ? context.muted : null,
                  ),
                ),
                if (task.isStack)
                  Text(
                    tr('${task.title} · ${task.stepsDone} of ${task.steps.length}', '${task.title} · ${task.stepsDone}/${task.steps.length}'),
                    style: t.bodySmall?.copyWith(color: context.muted),
                  ),
              ],
            ),
          ),
          if (task.private)
            Icon(
              Icons.lock_outline,
              size: 16,
              color: context.muted,
              semanticLabel: tr('Private', '不公开'),
            ),
          if (task.isStack)
            Icon(Icons.layers_outlined, size: 18, color: context.muted),
          if (task.repeat != Repeat.none)
            Icon(
              Icons.repeat,
              size: 16,
              color: context.muted,
              semanticLabel: task.repeat.label,
            ),
          if (task.remind && task.minutes != null)
            Icon(
              Icons.notifications_none,
              size: 16,
              color: context.muted,
              semanticLabel: tr('Reminder on', '会提醒'),
            ),
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

/// Add or edit a simple task: a title, a time with its reminder, a note,
/// how it repeats, and whether the cat may read it.
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
  late bool _remind = widget.task?.remind ?? false;
  late Repeat _repeat = _startRepeat();

  /// A repeating task stopped on this very day shows as Once.
  Repeat _startRepeat() {
    final t = widget.task;
    if (t == null) return Repeat.none;
    final end = t is Occurrence ? t.series.endDay : null;
    return end != null && sameDay(end, t.day) ? Repeat.none : t.repeat;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return Navigator.of(context).pop();
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final remind = _remind && _minutes != null;
    final t = widget.task;
    if (t == null) {
      widget.store.newTask(
        title,
        day: widget.day,
        minutes: _minutes,
        private: _private,
        repeat: _repeat,
        remind: remind,
      ).note = note;
    } else {
      t
        ..title = title
        ..minutes = _minutes
        ..private = _private
        ..remind = remind
        ..note = note;
      widget.store.setRepeat(t, _repeat);
    }
    await widget.store.save();
    Feel.logged();
    if (remind) await Remind.ask();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(Task t) async {
    var onlyThisDay = false;
    if (t is Occurrence) {
      final pick = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Delete a repeating task', '删除重复的任务')),
          content: Text(tr('Take it off just this day, or every day?', '只删这一天，还是每一天都删？')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('Cancel', '取消')),
            ),
            TextButton(
              key: const Key('delete-this-day'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('Just this day', '只删这一天')),
            ),
            TextButton(
              key: const Key('delete-every-day'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('Every day', '每一天')),
            ),
          ],
        ),
      );
      if (pick == null) return;
      onlyThisDay = pick;
    }
    await widget.store.removeTask(t, onlyThisDay: onlyThisDay);
    Feel.removed();
    if (mounted) Navigator.of(context).pop();
  }

  /// Opens the focus timer for this task.
  void _focus(Task t) {
    Feel.tap();
    FocusSession.current.forTask(t.title);
    final nav = Navigator.of(context);
    nav.pop();
    nav.push<void>(
      MaterialPageRoute(builder: (_) => RecordsScreen(store: widget.store, tab: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  // The Private chip moves to its own line when big text
                  // leaves no room beside the time.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, color: context.muted),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextButton(
                                key: const Key('task-time'),
                                onPressed: () async {
                                  final p = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (p != null) {
                                    setState(() {
                                      // A first time turns the reminder on.
                                      if (_minutes == null) _remind = true;
                                      _minutes = p.hour * 60 + p.minute;
                                    });
                                  }
                                },
                                child: Text(
                                  _minutes == null
                                      ? tr('Set a time', '设个时间')
                                      : clock(context, _minutes!),
                                ),
                              ),
                            ),
                            if (_minutes != null)
                              IconButton(
                                tooltip: tr('No time', '不定时间'),
                                onPressed: () => setState(() => _minutes = null),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                          ],
                        ),
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
                  ),
                  if (_minutes != null)
                    SwitchListTile(
                      key: const Key('task-remind'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.notifications_none),
                      title: Text(tr('Remind me at ${clock(context, _minutes!)}', '${clock(context, _minutes!)} 提醒我')),
                      value: _remind,
                      onChanged: (v) => setState(() => _remind = v),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    tr('Repeat', '重复'),
                    style: tt.labelLarge?.copyWith(color: context.muted),
                  ),
                  const SizedBox(height: 6),
                  ChipRow(
                    children: [
                      for (final r in Repeat.values)
                        ChoiceChip(
                          key: Key('repeat-${r.name}'),
                          label: Text(r.label),
                          selected: _repeat == r,
                          onSelected: (_) => setState(() => _repeat = r),
                        ),
                    ],
                  ),
                  if (t != null)
                    // Side by side when they fit, one under the other when not.
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          key: const Key('task-focus'),
                          onPressed: () => _focus(t),
                          icon: const Icon(Icons.timer_outlined),
                          label: Text(tr('Focus on this', '专注做这件')),
                        ),
                        TextButton.icon(
                          key: const Key('task-delete'),
                          onPressed: () => _delete(t),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(tr('Delete', '删除')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big Today / Schedule words over the list, with a short green line
/// under the one showing.
class HeadTab extends StatelessWidget {
  const HeadTab({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          // 48 points tall with the line, big enough to tap.
          padding: const EdgeInsets.symmetric(vertical: 4.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.headlineSmall?.copyWith(
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? null : context.muted,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: on ? 24 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search every task, past and planned, by its name, note or steps.
class TaskSearchSheet extends StatefulWidget {
  const TaskSearchSheet({super.key, required this.store});
  final DayStore store;

  @override
  State<TaskSearchSheet> createState() => _TaskSearchSheetState();
}

class _TaskSearchSheetState extends State<TaskSearchSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _open(Task t) async {
    Feel.tap();
    await showTinySheet<void>(
      context,
      (_) => t.isStack
          ? StackSheet(store: widget.store, task: t)
          : TaskSheet(store: widget.store, task: t),
      tall: t.isStack,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final found = widget.store.search(_q.text);
    return Column(
      children: [
        SheetHeader(title: tr('Search tasks', '搜索任务')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            key: const Key('search-field'),
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr('Search names, notes and steps', '搜索名称、备注和步骤'),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _q.text.trim().isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    tr('Every task is here, done or planned.', '做完的、计划好的，每件事都能搜到。'),
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: context.muted),
                  ),
                )
              : found.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    tr('Nothing found for “${_q.text.trim()}”', '没有找到「${_q.text.trim()}」'),
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: context.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  children: [
                    for (final x in found)
                      ListTile(
                        key: Key('found-${x.id}'),
                        leading: Icon(
                          x.repeat != Repeat.none
                              ? Icons.repeat
                              : x.done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: x.done ? context.green : context.muted,
                        ),
                        title: Text(x.title),
                        subtitle: Text(
                          x.repeat != Repeat.none
                              ? tr('${x.repeat.label} from ${dayMonth(x.day)}', '${dayMonth(x.day)}起${x.repeat.label}')
                              : dayMonthWeekday(x.day),
                        ),
                        trailing: x.private
                            ? Icon(Icons.lock_outline, size: 16, color: context.muted)
                            : null,
                        onTap: () => _open(x),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Monday of the week [d] is in.
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Seven days from [start] with the picked one filled in and a dot under
/// today. Days in [marks] (0 for Monday) get a small dot: something planned.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.start,
    required this.picked,
    required this.onPick,
    this.marks = const {},
    this.id = 'week',
  });
  final DateTime start, picked;
  final ValueChanged<DateTime> onPick;
  final Set<int> marks;

  /// Starts each day's key, like "week-day-0" for Monday.
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Seven days share one row, so the day numbers stop growing at iOS's
    // largest standard text size, as a calendar's grid does.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.35,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final d = DateTime(start.year, start.month, start.day + i);
                  final on = sameDay(d, picked);
                  final isToday = sameDay(d, DateTime.now());
                  return InkWell(
                    key: Key('$id-day-$i'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onPick(d),
                    child: Column(
                      children: [
                        Text(
                          weekdayHeads[i],
                          style: t.labelSmall?.copyWith(color: context.muted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 26,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: on ? cs.primary : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${d.day}',
                                style: t.titleMedium?.copyWith(
                                  color: on ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.75),
                                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                                  height: 1.1,
                                ),
                              ),
                              // The small dot under today, as in the wireframe.
                              Container(
                                key: isToday ? const Key('week-today-dot') : null,
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? (on ? cs.onPrimary : cs.primary)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (marks.isNotEmpty)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: marks.contains(i)
                                  ? context.green.withValues(alpha: 0.7)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
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
          // Scrolls when big text makes the week and the faces taller than
          // the sheet.
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
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
                          tr(count(s.moodsOn(today).length, 'entry', 'entries'), '${s.moodsOn(today).length} 条记录'),
                          style: t.bodyMedium?.copyWith(color: context.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Seven equal slots, so the week fits the smallest phone.
                    Row(
                      children: [
                        for (final d in days)
                          // Today sits in a soft green tile, as in IMG_6792.
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                              decoration: BoxDecoration(
                                color: sameDay(d, today) ? context.greenSoft : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  // The weekday over the date, as on the
                                  // Dashboard's week.
                                  Text(
                                    weekdayHeads[d.weekday - 1],
                                    style: t.labelSmall?.copyWith(
                                      // Green on today's tile, where grey
                                      // is too faint at night.
                                      color: sameDay(d, today)
                                          ? context.green
                                          : context.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      sameDay(d, today)
                                          ? tr('Today', '今')
                                          : '${d.day}',
                                      style: t.labelMedium?.copyWith(
                                        color: sameDay(d, today)
                                            ? context.green
                                            : context.muted,
                                        fontWeight: sameDay(d, today)
                                            ? FontWeight.w700
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  MoodDot(mood: s.moodOf(d)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.sand,
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
                          // Six in a row when they fit, two rows of three when not.
                          LayoutBuilder(
                            builder: (context, box) {
                              final big = MediaQuery.textScalerOf(context).scale(1);
                              final perRow =
                                  box.maxWidth / Mood.values.length >= 50 * big
                                  ? Mood.values.length
                                  : 3;
                              return Wrap(
                                runSpacing: 8,
                                children: [
                                  for (final m in Mood.values)
                                    SizedBox(
                                      width: box.maxWidth / perRow,
                                      child: InkWell(
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
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  zh ? m.zh : m.label,
                                                  style: t.labelSmall?.copyWith(
                                                    color: context.muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
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
        color: selected ? context.green : Palette.ink.withValues(alpha: 0.08),
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
        painter: DashedRing(context.muted.withValues(alpha: 0.45), width: 1.2),
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
Future<void> addCountdown(BuildContext context, DayStore s) =>
    editCountdown(context, s);

/// Adds a countdown, or changes or deletes [c]. A day that has passed counts
/// the days since; a yearly one, like a birthday, comes round every year.
Future<void> editCountdown(
  BuildContext context,
  DayStore s, [
  Countdown? c,
]) async {
  final name = TextEditingController(text: c?.title);
  DateTime? date = c?.date;
  var yearly = c?.yearly ?? false;
  var remind = c?.remind ?? true;
  // Guessed from the name until she flips the switch herself.
  bool? exam = c?.exam;
  final today = dayOf(DateTime.now());
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final past = date != null && !yearly && dayOf(date!).isBefore(today);
        return AlertDialog(
          title: Text(
            c == null ? tr('New countdown', '新的倒数日') : tr('Edit countdown', '编辑倒数日'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('countdown-name'),
                  controller: name,
                  autofocus: c == null,
                  decoration: InputDecoration(
                    hintText: tr('Exams, a trip, a birthday…', '考试、旅行、生日……'),
                  ),
                  onChanged: (_) => set(() {}),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('countdown-date'),
                  icon: const Icon(Icons.event),
                  label: Text(
                    date == null ? tr('Pick the day', '选日子') : fullDate(date!),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(today.year - 100),
                      lastDate: DateTime(today.year + 50),
                      initialDate: date ?? today.add(const Duration(days: 7)),
                    );
                    if (d != null) set(() => date = d);
                  },
                ),
                if (past)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tr('This day has passed, so it counts the days since.', '这天已经过去，会数已经过了多少天。'),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: context.muted),
                    ),
                  ),
                SwitchListTile(
                  key: const Key('countdown-yearly'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Every year', '每年重复')),
                  subtitle: Text(tr('Like a birthday', '比如生日')),
                  value: yearly,
                  onChanged: (v) => set(() => yearly = v),
                ),
                SwitchListTile(
                  key: const Key('countdown-exam'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('It’s an exam', '这是考试')),
                  subtitle: Text(tr('Home helps you get ready in the last 30 days', '最后 30 天，首页会帮你备考')),
                  value: exam ?? looksLikeExam(name.text),
                  onChanged: (v) => set(() => exam = v),
                ),
                SwitchListTile(
                  key: const Key('countdown-remind'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('Remind me', '提醒我')),
                  subtitle: Text(tr('9 am the day before, and on the day', '前一天和当天早上 9 点')),
                  value: remind,
                  onChanged: (v) => set(() => remind = v),
                ),
              ],
            ),
          ),
          actions: [
            if (c != null)
              TextButton(
                key: const Key('countdown-delete'),
                onPressed: () => Navigator.of(ctx).pop('delete'),
                child: Text(tr('Delete', '删除')),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('Cancel', '取消')),
            ),
            FilledButton(
              key: const Key('countdown-save'),
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: Text(c == null ? tr('Add', '添加') : tr('Save', '保存')),
            ),
          ],
        );
      },
    ),
  );
  if (result == 'delete' && c != null) {
    await s.remove(s.countdowns, c);
    Feel.removed();
    return;
  }
  if (result != 'save' || name.text.trim().isEmpty) return;
  final day = date ?? today.add(const Duration(days: 7));
  if (c == null) {
    await s.addCountdown(name.text.trim(), day, yearly: yearly, remind: remind, exam: exam);
  } else {
    c
      ..title = name.text.trim()
      ..date = day
      ..yearly = yearly
      ..remind = remind
      ..exam = exam ?? looksLikeExam(name.text.trim());
    await s.save();
  }
  Feel.logged();
  if (remind) await Remind.ask();
}
