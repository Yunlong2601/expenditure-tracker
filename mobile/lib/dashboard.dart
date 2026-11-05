import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'format.dart';
import 'home_tab.dart';
import 'kitty.dart';
import 'ledger.dart';
import 'theme.dart';

/// What she spent on [day], like "S$12.40", or null if nothing.
String? spentOn(Ledger? l, DateTime day) {
  if (l == null) return null;
  final by = <String, double>{};
  for (final e in l.all) {
    if (e.moneyIn || !sameDay(e.date, day)) continue;
    by[e.currency] = (by[e.currency] ?? 0) + e.amount;
  }
  if (by.isEmpty) return null;
  return [for (final MapEntry(:key, :value) in by.entries) money(value, key)]
      .join(' + ');
}

/// The Dashboard tab (IMG_6790 to 6792): a week strip, today's review, the
/// tasks card with its completed log, the month calendar, mood, focus,
/// money and countdowns.
class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.store,
    this.ledger,
    this.onMoney,
  });
  final DayStore store;
  final Ledger? ledger;
  final VoidCallback? onMoney;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DayStore get _s => widget.store;
  DateTime _picked = dayOf(DateTime.now());
  late DateTime _month = DateTime(_picked.year, _picked.month);

  void _pick(DateTime d) {
    Feel.tap();
    setState(() {
      _picked = dayOf(d);
      _month = DateTime(d.year, d.month);
    });
  }

  DateTime get _weekStart =>
      _picked.subtract(Duration(days: _picked.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final isToday = sameDay(_picked, DateTime.now());
    final dayLabel = isToday ? 'Today' : DateFormat('d MMM').format(_picked);
    final tasks = _s.tasksOn(_picked);
    final done = _s.doneOn(_picked);
    final timed = tasks.where((x) => x.minutes != null).length;
    final focus = _s.focusMinutesOn(_picked);
    final spent = spentOn(widget.ledger, _picked);
    final mood = _s.moodOf(_picked);

    return ListView(
      key: const Key('dashboard-list'),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 32),
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              const Positioned(right: 0, top: 0, child: CatFigure(size: 150)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Every day of effort, recorded',
                    style: t.bodyMedium?.copyWith(color: Palette.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 290,
                    child: Panel(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Last week',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _pick(
                                        _picked.subtract(
                                          const Duration(days: 7),
                                        ),
                                      ),
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMM yyyy').format(_picked),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Next week',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _pick(
                                        _picked.add(const Duration(days: 7)),
                                      ),
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ),
                              PillButton(
                                key: const Key('dash-today'),
                                label: 'Today',
                                onPressed: () => _pick(DateTime.now()),
                              ),
                            ],
                          ),
                          _WeekStrip(
                            start: _weekStart,
                            picked: _picked,
                            onPick: _pick,
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
        const SizedBox(height: 12),
        // Today's review.
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dayLabel’s review',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.sageSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        done.isEmpty && mood == null && focus == 0
                            ? 'No review for this day yet.\nWhen you’re done, we’ll look back together.'
                            : '${done.length} done · $focus min focus'
                                  '${mood == null ? '' : ' · felt ${mood.label.toLowerCase()}'}'
                                  '${spent == null ? '' : ' · spent $spent'}',
                        style: t.bodyLarge?.copyWith(
                          color: Palette.sage,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CustomPaint(painter: CatPainter(paw: false)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tasks.
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Tasks',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('open-completed'),
                    onPressed: () => showTinySheet<void>(
                      context,
                      (_) => CompletedSheet(store: _s, day: _picked),
                      tall: true,
                    ),
                    child: const Text('Completed ›'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat(
                    icon: Icons.check_circle,
                    color: const Color(0xFF6FAE6A),
                    value: '${done.length}',
                    label: 'Done',
                  ),
                  _Stat(
                    icon: Icons.schedule,
                    color: const Color(0xFFE8B067),
                    value: '$timed',
                    label: 'Timed',
                  ),
                  _Stat(
                    icon: Icons.track_changes,
                    color: const Color(0xFF7FB58A),
                    value: '$focus',
                    label: 'Focus min',
                  ),
                  _Stat(
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFEB8A5A),
                    value: '${_streak()}',
                    label: 'Day streak',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Month calendar.
        Panel(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: _MonthGrid(
            month: _month,
            picked: _picked,
            store: _s,
            ledger: widget.ledger,
            onMonth: (m) => setState(() => _month = m),
            onPick: (d) {
              _pick(d);
              showTinySheet<void>(
                context,
                (_) =>
                    DaySheet(store: _s, day: dayOf(d), ledger: widget.ledger),
                tall: true,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Mood.
        Panel(
          onTap: () => showMoodSheet(context, _s),
          child: Row(
            children: [
              MoodDot(mood: _s.moodOf(DateTime.now()), size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood diary',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'How are you feeling right now?',
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Palette.muted),
            ],
          ),
        ),
        if (widget.onMoney != null) ...[
          const SizedBox(height: 12),
          Panel(
            key: const Key('money-card'),
            onTap: widget.onMoney,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Palette.peach,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFFD08A4A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Money',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        spent == null
                            ? 'Nothing spent ${isToday ? 'today' : 'this day'}'
                            : '$dayLabel: $spent',
                        style: t.bodyMedium?.copyWith(color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Palette.muted),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Countdowns.
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Countdowns',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('add-countdown'),
                    onPressed: () => addCountdown(context, _s),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_s.upcoming().isEmpty)
                Text(
                  'Exams, trips, birthdays: count down to what matters.',
                  style: t.bodyMedium?.copyWith(color: Palette.muted),
                ),
              for (final c in _s.upcoming())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.title),
                  subtitle: Text(DateFormat('EEE, d MMM yyyy').format(c.date)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.daysLeft() == 0 ? 'Today' : '${c.daysLeft()} days',
                        style: t.titleMedium?.copyWith(
                          color: Palette.sage,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _s.remove(_s.countdowns, c),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Days in a row, ending today, with at least one thing done.
  int _streak() {
    var d = dayOf(DateTime.now());
    if (_s.doneOn(d).isEmpty) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (_s.doneOn(d).isNotEmpty) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: t.labelSmall?.copyWith(color: Palette.muted)),
      ],
    );
  }
}

const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.start,
    required this.picked,
    required this.onPick,
  });
  final DateTime start, picked;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (_) {
                final d = start.add(Duration(days: i));
                final on = sameDay(d, picked);
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onPick(d),
                  child: Column(
                    children: [
                      Text(
                        _weekdays[i],
                        style: t.labelSmall?.copyWith(color: Palette.muted),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? cs.primary : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${d.day}',
                          style: t.titleSmall?.copyWith(
                            color: on ? cs.onPrimary : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.picked,
    required this.store,
    required this.onMonth,
    required this.onPick,
    this.ledger,
  });
  final DateTime month, picked;
  final DayStore store;
  final Ledger? ledger;
  final ValueChanged<DateTime> onMonth, onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final first = month.subtract(Duration(days: month.weekday - 1));
    final today = dayOf(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 6),
            Text(
              DateFormat('MMMM').format(month),
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              '${month.year}',
              style: t.titleMedium?.copyWith(color: Palette.muted),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Last month',
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: t.labelMedium?.copyWith(color: Palette.muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final d = DateTime(
                        first.year,
                        first.month,
                        first.day + row * 7 + col,
                      );
                      final inMonth = d.month == month.month;
                      final on = sameDay(d, picked);
                      final isToday = sameDay(d, today);
                      final hasTasks = store.doneOn(d).isNotEmpty;
                      final mood = store.moodOf(d);
                      final spent = spentOn(ledger, d) != null;
                      return Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: InkWell(
                          key: Key('day-${d.month}-${d.day}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onPick(d),
                          child: Container(
                            height: 64,
                            padding: const EdgeInsets.fromLTRB(6, 5, 4, 4),
                            decoration: BoxDecoration(
                              color: inMonth
                                  ? Palette.sand
                                  : Palette.sand.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: on ? cs.primary : Colors.transparent,
                                width: 1.6,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: isToday
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        )
                                      : null,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        )
                                      : null,
                                  child: Text(
                                    '${d.day}',
                                    style: t.labelLarge?.copyWith(
                                      color: isToday
                                          ? cs.onPrimary
                                          : (inMonth
                                                ? null
                                                : Palette.muted.withValues(
                                                    alpha: 0.6,
                                                  )),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    if (mood != null)
                                      MoodFace(mood: mood, size: 14),
                                    if (hasTasks) _dot(const Color(0xFF6FAE6A)),
                                    if (spent) _dot(const Color(0xFFE8B067)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(const Color(0xFF6FAE6A)),
            Text(
              ' Done   ',
              style: t.labelSmall?.copyWith(color: Palette.muted),
            ),
            _dot(const Color(0xFFE8B067)),
            Text(
              ' Spent   ',
              style: t.labelSmall?.copyWith(color: Palette.muted),
            ),
            const MoodFace(mood: Mood.happy, size: 12),
            Text(' Mood', style: t.labelSmall?.copyWith(color: Palette.muted)),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
    width: 7,
    height: 7,
    margin: const EdgeInsets.only(left: 2),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// Completed log (IMG_6790): how many done that day, add a past one, the list.
class CompletedSheet extends StatelessWidget {
  const CompletedSheet({super.key, required this.store, required this.day});
  final DayStore store;
  final DateTime day;

  Future<void> _addPast(BuildContext context) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add something you did'),
        content: TextField(
          key: const Key('past-field'),
          controller: c,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    final at = sameDay(day, DateTime.now())
        ? DateTime.now()
        : DateTime(day.year, day.month, day.day, 12);
    final t = await store.addTask(v.trim(), day: day);
    await store.tick(t, now: at);
    Feel.logged();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final done = store.doneOn(day);
        final label = sameDay(day, DateTime.now()) ? 'Today · ' : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(title: 'Completed'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${done.length}',
                              style: t.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('done', style: t.titleMedium),
                          ],
                        ),
                        Text(
                          '$label${DateFormat('d MMM, EEE').format(day)}',
                          style: t.bodyMedium?.copyWith(color: Palette.muted),
                        ),
                      ],
                    ),
                  ),
                  PillButton(
                    key: const Key('add-past'),
                    label: '+ Add past',
                    onPressed: () => _addPast(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: done.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CatFigure(size: 110, mood: CatMood.worried),
                        const SizedBox(height: 12),
                        Text(
                          'Nothing finished this day yet',
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Finish one and it shows up here',
                          style: t.bodyMedium?.copyWith(color: Palette.muted),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        for (final x in done)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle,
                              color: Palette.sage,
                            ),
                            title: Text(x.title),
                            trailing: Text(
                              DateFormat('HH:mm').format(x.doneAt!),
                              style: t.bodySmall,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Everything on one day: tasks, moods, focus, timeline and money.
class DaySheet extends StatelessWidget {
  const DaySheet({
    super.key,
    required this.store,
    required this.day,
    this.ledger,
  });
  final DayStore store;
  final DateTime day;
  final Ledger? ledger;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = store.tasksOn(day);
        final moods = store.moodsOn(day);
        final lines = store.timeline.where((e) => sameDay(e.at, day)).toList();
        final spent = spentOn(ledger, day);
        Widget head(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            s,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        return Column(
          children: [
            SheetHeader(
              title: DateFormat('EEEE, d MMM').format(day),
              action: 'Add',
              onAction: () => showTinySheet<void>(
                context,
                (_) => TaskSheet(store: store, day: day),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  head('Tasks'),
                  if (tasks.isEmpty)
                    Text(
                      'No tasks',
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  for (final x in tasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TaskRow(
                        task: x,
                        onTick: () => store.tick(x),
                        onTap: () {},
                      ),
                    ),
                  head('Mood'),
                  if (moods.isEmpty)
                    Text(
                      'Not logged',
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final m in moods)
                        if (Mood.values.asNameMap()[m.kind] case final mood?)
                          Chip(
                            avatar: MoodFace(mood: mood, size: 22),
                            label: Text(
                              '${mood.label} · ${DateFormat('HH:mm').format(m.at)}',
                            ),
                          ),
                    ],
                  ),
                  head('Focus'),
                  Text(
                    '${store.focusMinutesOn(day)} minutes',
                    style: t.bodyLarge,
                  ),
                  if (lines.isNotEmpty) ...[
                    head('Timeline'),
                    for (final e in lines)
                      Text(
                        '${DateFormat('HH:mm').format(e.at)}  ${e.text}',
                        style: t.bodyLarge,
                      ),
                  ],
                  if (ledger != null) ...[
                    head('Money'),
                    Text(spent ?? 'Nothing spent', style: t.bodyLarge),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
