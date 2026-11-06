import 'package:flutter/material.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'format.dart';
import 'home_tab.dart';
import 'kitty.dart';
import 'ledger.dart';
import 'l10n.dart';
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

/// The Dashboard tab (IMG_6790 to 6792): a week card that opens the month
/// calendar, countdowns, the day's review, the tasks card with its completed
/// log, mood, focus and money.
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

  /// The month calendar opens from the small week card at the top.
  bool _calendarOpen = false;

  void _toggleCalendar() {
    Feel.tap();
    setState(() {
      _calendarOpen = !_calendarOpen;
      _month = DateTime(_picked.year, _picked.month);
    });
  }

  void _pick(DateTime d) {
    Feel.tap();
    setState(() {
      _picked = dayOf(d);
      _month = DateTime(d.year, d.month);
    });
  }

  /// The month calendar (IMG_6791): tap a day to pick it, again to open it.
  Widget _calendar() {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: _MonthGrid(
        month: _month,
        picked: _picked,
        store: _s,
        ledger: widget.ledger,
        onMonth: (m) => setState(() => _month = m),
        onAdd: (d) {
          Feel.tap();
          showTinySheet<void>(
            context,
            (_) => TaskSheet(store: _s, day: dayOf(d)),
          );
        },
        // The first tap picks a day and shows its +; a second tap opens it.
        onPick: (d) {
          final again = sameDay(d, _picked);
          _pick(d);
          if (!again) return;
          showTinySheet<void>(
            context,
            (_) =>
                DaySheet(store: _s, day: dayOf(d), ledger: widget.ledger),
            tall: true,
          );
        },
      ),
    );
  }

  /// Countdowns, first on the Dashboard so the next big day is in view.
  Widget _countdowns(TextTheme t) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('Countdowns', '倒数日'),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('add-countdown'),
                onPressed: () => addCountdown(context, _s),
                icon: const Icon(Icons.add),
                label: Text(tr('Add', '添加')),
              ),
            ],
          ),
          if (_s.upcoming().isEmpty)
            Text(
              tr('Exams, trips, birthdays: count down to what matters.', '考试、旅行、生日：给重要的日子倒数。'),
              style: t.bodyMedium?.copyWith(color: Palette.muted),
            ),
          for (final c in _s.upcoming())
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.title),
              subtitle: Text('${fullDate(c.date)} ${weekdayShort(c.date)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.daysLeft() == 0 ? tr('Today', '就是今天') : tr('${c.daysLeft()} days', '${c.daysLeft()} 天'),
                    style: t.titleMedium?.copyWith(
                      color: Palette.sage,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Delete', '删除'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _s.remove(_s.countdowns, c),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DateTime get _weekStart =>
      _picked.subtract(Duration(days: _picked.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final isToday = sameDay(_picked, DateTime.now());
    final dayLabel = isToday ? tr('Today', '今日') : dayMonth(_picked);
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
            clipBehavior: Clip.none,
            children: [
              // The cat studying among books and plants, off the right edge.
              Positioned(
                right: -16,
                top: -top - 12,
                child: SceneArt(
                  kind: SceneKind.studying,
                  width: 220,
                  height: top + 182,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Dashboard', '看板'),
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    tr('Every day of effort, recorded', '记录努力的每一天'),
                    style: t.bodyMedium?.copyWith(color: Palette.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 232,
                    child: Semantics(
                      expanded: _calendarOpen,
                      hint: _calendarOpen
                          ? tr('Hides the month calendar', '收起月历')
                          : tr('Shows the month calendar', '展开月历'),
                      child: Panel(
                      key: const Key('calendar-toggle'),
                      onTap: _toggleCalendar,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    _Chevron(
                                      tooltip: tr('Last week', '上一周'),
                                      icon: Icons.chevron_left,
                                      onTap: () => _pick(
                                        _picked.subtract(
                                          const Duration(days: 7),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        monthYear(_picked),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _Chevron(
                                      tooltip: tr('Next week', '下一周'),
                                      icon: Icons.chevron_right,
                                      onTap: () => _pick(
                                        _picked.add(const Duration(days: 7)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PillButton(
                                key: const Key('dash-today'),
                                label: tr('Today', '今天'),
                                dense: true,
                                onPressed: () => _pick(DateTime.now()),
                              ),
                            ],
                          ),
                          _WeekStrip(
                            start: _weekStart,
                            picked: _picked,
                            onPick: _pick,
                          ),
                          // A small handle that says the card opens.
                          AnimatedRotation(
                            key: const Key('calendar-handle'),
                            turns: _calendarOpen ? 0.5 : 0,
                            duration: _motion(context),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
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
            ],
          ),
        ),
        // The month calendar, opened from the week card.
        AnimatedSize(
          duration: _motion(context),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _calendarOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _calendar(),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 12),
        _countdowns(t),
        const SizedBox(height: 12),
        // Today's review.
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('$dayLabel’s review', '$dayLabel复盘'),
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 64),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.sageSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                        done.isEmpty && mood == null && focus == 0
                            ? tr('No review for this day yet.\nWhen you’re done, we’ll look back together.', '还没有这一天的复盘。\n忙完后，我们一起回顾。')
                            : '${tr('${done.length} done · $focus min focus', '完成 ${done.length} 件 · 专注 $focus 分钟')}'
                                  '${mood == null ? '' : tr(' · felt ${mood.label.toLowerCase()}', ' · 心情${mood.zh}')}'
                                  '${spent == null ? '' : tr(' · spent $spent', ' · 花了 $spent')}',
                        style: t.bodyLarge?.copyWith(
                          color: Palette.sage,
                          height: 1.45,
                        ),
                      ),
                  ),
                  // The cat peeking over the box, as in the wireframe.
                  const Positioned(
                    right: -8,
                    bottom: -10,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: CustomPaint(painter: CatPainter(star: true)),
                      ),
                    ),
                  ),
                ],
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
                    tr('Tasks', '任务'),
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
                    child: Text(tr('Completed ›', '完成记录 ›')),
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
                    label: tr('Done', '完成'),
                  ),
                  _Stat(
                    icon: Icons.schedule,
                    color: const Color(0xFFE8B067),
                    value: '$timed',
                    label: tr('Timed', '定时'),
                  ),
                  _Stat(
                    icon: Icons.track_changes,
                    color: const Color(0xFF7FB58A),
                    value: '$focus',
                    label: tr('Focus min', '专注分钟'),
                  ),
                  _Stat(
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFEB8A5A),
                    value: '${_streak()}',
                    label: tr('Day streak', '连续天数'),
                  ),
                ],
              ),
            ],
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
                      tr('Mood diary', '心情日记'),
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      tr('How are you feeling right now?', '此刻心情如何？'),
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
                        tr('Money', '记账'),
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        spent == null
                            ? tr('Nothing spent ${isToday ? 'today' : 'this day'}', isToday ? '今天还没花钱' : '这天没有花钱')
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
                final isToday = sameDay(d, DateTime.now());
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onPick(d),
                  child: Column(
                    children: [
                      Text(
                        weekdayHeads[i],
                        style: t.labelSmall?.copyWith(color: Palette.muted),
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
    required this.onAdd,
    this.ledger,
  });
  final DateTime month, picked;
  final DayStore store;
  final Ledger? ledger;
  final ValueChanged<DateTime> onMonth, onPick;

  /// The + on the picked day: plan something for it.
  final ValueChanged<DateTime> onAdd;

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
              monthLong(month),
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              '${month.year}',
              style: t.titleMedium?.copyWith(color: Palette.muted),
            ),
            const Spacer(),
            IconButton(
              tooltip: tr('Last month', '上个月'),
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: tr('Next month', '下个月'),
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, w) in weekdayHeads.indexed)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: t.labelMedium?.copyWith(
                      color: i == 6 ? cs.primary : Palette.muted,
                    ),
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
                            padding: const EdgeInsets.fromLTRB(5, 5, 3, 4),
                            decoration: BoxDecoration(
                              color: on
                                  ? cs.primary.withValues(alpha: 0.1)
                                  : inMonth
                                  ? _cell(context)
                                  : _cell(context).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: on ? cs.primary : Colors.transparent,
                                width: 1.6,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                Container(
                                  constraints: isToday
                                      ? const BoxConstraints(
                                          minWidth: 19,
                                          minHeight: 19,
                                        )
                                      : null,
                                  alignment: isToday ? Alignment.center : null,
                                  padding: isToday
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        )
                                      : null,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: cs.primary.withValues(
                                            alpha: on ? 0.75 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            11,
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
                                    if (on) ...[
                                      const SizedBox(width: 1),
                                      Expanded(
                                        child: _AddDay(
                                          onTap: () => onAdd(d),
                                        ),
                                      ),
                                    ],
                                  ],
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
              tr(' Done   ', ' 完成   '),
              style: t.labelSmall?.copyWith(color: Palette.muted),
            ),
            _dot(const Color(0xFFE8B067)),
            Text(
              tr(' Spent   ', ' 花销   '),
              style: t.labelSmall?.copyWith(color: Palette.muted),
            ),
            const MoodFace(mood: Mood.happy, size: 12),
            Text(tr(' Mood', ' 心情'), style: t.labelSmall?.copyWith(color: Palette.muted)),
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
        title: Text(tr('Add something you did', '补记一件做完的事')),
        content: TextField(
          key: const Key('past-field'),
          controller: c,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(tr('Add', '添加')),
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
        final label = sameDay(day, DateTime.now()) ? tr('Today · ', '今天 · ') : '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(title: tr('Completed', '完成记录')),
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
                            Text(tr('done', '件完成'), style: t.titleMedium),
                          ],
                        ),
                        Text(
                          '$label${dayMonthWeekday(day)}',
                          style: t.bodyMedium?.copyWith(color: Palette.muted),
                        ),
                      ],
                    ),
                  ),
                  PillButton(
                    key: const Key('add-past'),
                    label: tr('+ Add past', '+ 补记'),
                    onPressed: () => _addPast(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: done.isEmpty
                  ? SizedBox(
                      width: double.infinity,
                      child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // The cat hugging its star, as in IMG_6790.
                        const ExcludeSemantics(
                          child: SizedBox.square(
                            dimension: 120,
                            child: CustomPaint(
                              painter: CatPainter(star: true),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('Nothing finished this day yet', '这一天还没有完成的任务'),
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Finish one and it shows up here', '完成一件，它就会出现在这里'),
                          style: t.bodyMedium?.copyWith(color: Palette.muted),
                        ),
                      ],
                    ),
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
                              hhmm(x.doneAt!),
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
              title: longDay(day),
              action: tr('Add', '添加'),
              onAction: () => showTinySheet<void>(
                context,
                (_) => TaskSheet(store: store, day: day),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  head(tr('Tasks', '任务')),
                  if (tasks.isEmpty)
                    Text(
                      tr('No tasks', '没有任务'),
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
                  head(tr('Mood', '心情')),
                  if (moods.isEmpty)
                    Text(
                      tr('Not logged', '没有记录'),
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
                              '${zh ? mood.zh : mood.label} · ${hhmm(m.at)}',
                            ),
                          ),
                    ],
                  ),
                  head(tr('Focus', '专注')),
                  Text(
                    tr('${store.focusMinutesOn(day)} minutes', '${store.focusMinutesOn(day)} 分钟'),
                    style: t.bodyLarge,
                  ),
                  if (lines.isNotEmpty) ...[
                    head(tr('Timeline', '时间轴')),
                    for (final e in lines)
                      Text(
                        '${hhmm(e.at)}  ${e.text}',
                        style: t.bodyLarge,
                      ),
                  ],
                  if (ledger != null) ...[
                    head(tr('Money', '记账')),
                    Text(spent ?? tr('Nothing spent', '没有花钱'), style: t.bodyLarge),
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

/// The small dashed + on the picked calendar day (IMG_6791).
class _AddDay extends StatelessWidget {
  const _AddDay({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: tr('Add for this day', '给这天添加'),
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('day-add'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The whole space beside the date takes the tap, not just the ring.
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            child: CustomPaint(
              painter: DashedRing(c.withValues(alpha: 0.7)),
              child: SizedBox.square(
                dimension: 17,
                child: Icon(Icons.add, size: 12, color: c),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// How long the calendar takes to open; instant with reduced motion.
Duration _motion(BuildContext context) => MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 260);

/// A small chevron for the week card, with a full-size tap area.
class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: 20,
      child: SizedBox(width: 26, height: 44, child: Icon(icon, size: 20)),
    ),
  );
}

/// The soft fill of a calendar day, darker at night.
Color _cell(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF30312C)
    : Palette.sand;
