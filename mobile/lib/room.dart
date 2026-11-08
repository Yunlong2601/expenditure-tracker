import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'theme.dart';

/// The flame's orange.
const flame = Color(0xFFEB8A5A);

String pawsText(int n) => tr(count(n, 'paw'), '$n 个爪印');

/// Opens Mochi's room: the paws earned, what's next, and everything there
/// is to earn.
Future<void> showRoomSheet(BuildContext context, DayStore store) {
  Feel.tap();
  return showTinySheet<void>(
    context,
    (_) => RoomSheet(store: store),
    tall: true,
  );
}

/// Opens the streak: days in a row, this week, and the rest days left.
Future<void> showStreakSheet(BuildContext context, DayStore store) {
  Feel.tap();
  return showTinySheet<void>(context, (_) => StreakSheet(store: store));
}

/// The streak and the paws, for the chip row on Home.
List<Widget> roomChips(BuildContext context, DayStore store) {
  final days = store.streak();
  final next = store.nextItem;
  final paws = store.paws;
  return [
    ActionChip(
      key: const Key('streak-chip'),
      avatar: const Icon(Icons.local_fire_department, color: flame, size: 20),
      label: Text(
        days > 0
            ? tr('$days-day streak', '连续 $days 天')
            : tr('Start a streak', '开始连续打卡'),
      ),
      onPressed: () => showStreakSheet(context, store),
    ),
    ActionChip(
      key: const Key('paws-chip'),
      avatar: Icon(Icons.pets, color: context.green, size: 18),
      label: Text(
        next == null
            ? pawsText(paws)
            : tr(
                '${pawsText(paws)} · next: ${next.label}',
                '${pawsText(paws)} · 下一个：${next.label}',
              ),
      ),
      onPressed: () => showRoomSheet(context, store),
    ),
  ];
}

class RoomSheet extends StatelessWidget {
  const RoomSheet({super.key, required this.store});
  final DayStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = Prefs.current.catName;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final paws = store.paws;
        final next = store.nextItem;
        final last = roomItems.lastWhere(
          (r) => r.paws <= paws,
          orElse: () => const RoomItem('', 0, '', ''),
        );
        final progress = next == null
            ? 1.0
            : (paws - last.paws) / (next.paws - last.paws);
        return Column(
          key: const Key('room-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(title: tr('$name’s room', '$name 的房间')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pets, color: context.green, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pawsText(paws),
                                    key: const Key('room-paws'),
                                    style: t.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    next == null
                                        ? tr(
                                            '$name has everything. Amazing!',
                                            '$name 什么都有啦，太棒了！',
                                          )
                                        : tr(
                                            '${count(next.paws - paws, 'more paw')} for the ${next.label.toLowerCase()}',
                                            '再得 ${next.paws - paws} 个爪印就有${next.label}',
                                          ),
                                    style: t.bodyMedium?.copyWith(
                                      color: context.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 10,
                            color: context.green,
                            backgroundColor: context.greenSoft,
                            semanticsLabel: tr(
                              'Paws to the next thing',
                              '离下一个还差的爪印',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tr(
                      'One paw for each thing you tick off (up to $pawsPerDay a day) and one for every 10 minutes of focus. What you earn stays, even after a quiet week.',
                      '每完成一件事得 1 个爪印（每天最多 $pawsPerDay 个），每专注 10 分钟也得 1 个。得到的东西会一直留着，休息一周也不会少。',
                    ),
                    style: t.bodyMedium?.copyWith(color: context.muted),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('For the room', '房间里的'),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _Grid(
                    children: [
                      for (final r in roomItems.where((r) => !r.outfit))
                        _ItemCard(item: r, earned: store.room.contains(r.id)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr('For $name to wear', '给 $name 穿戴的'),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Tap one $name has to put it on or take it off.',
                      '点一下已经有的，就能戴上或摘下。',
                    ),
                    style: t.bodyMedium?.copyWith(color: context.muted),
                  ),
                  const SizedBox(height: 10),
                  _Grid(
                    children: [
                      for (final r in roomItems.where((r) => r.outfit))
                        _ItemCard(
                          item: r,
                          earned: store.room.contains(r.id),
                          worn: store.outfit == r.id,
                          onTap: store.room.contains(r.id)
                              ? () {
                                  Feel.tap();
                                  store.wear(
                                    store.outfit == r.id ? null : r.id,
                                  );
                                }
                              : null,
                        ),
                    ],
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

/// Cards three to a row, or two with big text, each as tall as its words.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 10.0;
      final perRow = bigText(context) ? 2 : 3;
      final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.earned,
    this.worn = false,
    this.onTap,
  });
  final RoomItem item;
  final bool earned, worn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = worn
        ? tr('Wearing', '戴着')
        : earned
        ? (item.outfit ? tr('Tap to wear', '点一下戴上') : tr('In the room', '在房间里'))
        : pawsText(item.paws);
    return Semantics(
      button: onTap != null,
      selected: worn,
      label: earned
          ? item.label
          : tr(
              '${item.label}, at ${pawsText(item.paws)}',
              '${item.label}，${pawsText(item.paws)}解锁',
            ),
      excludeSemantics: true,
      child: Material(
        key: Key('room-item-${item.id}'),
        color: worn ? context.greenSoft : context.sand,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  width: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: earned ? 1 : 0.3,
                        child: CustomPaint(
                          size: const Size(64, 56),
                          painter: _ItemPreview(item),
                        ),
                      ),
                      if (!earned)
                        Icon(
                          Icons.lock_outline,
                          size: 22,
                          color: context.muted,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: t.labelSmall?.copyWith(
                    color: worn ? context.green : context.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thing for the room on its own, or Mochi wearing an outfit.
class _ItemPreview extends CustomPainter {
  _ItemPreview(this.item);
  final RoomItem item;

  @override
  void paint(Canvas canvas, Size size) {
    if (item.outfit) {
      CatPainter(paw: false, outfit: item.id).paint(canvas, size);
      return;
    }
    // Each thing at its own shape: long ones wide, tall ones tall.
    final (w, h) = switch (item.id) {
      'rug' || 'cushion' => (60.0, 26.0),
      'lights' => (60.0, 30.0),
      'shelf' => (58.0, 40.0),
      'poster' => (36.0, 48.0),
      'lamp' => (34.0, 50.0),
      _ => (46.0, 46.0),
    };
    final r = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: math.min(w, size.width),
      height: math.min(h, size.height),
    );
    paintRoomItem(canvas, item.id, r);
  }

  @override
  bool shouldRepaint(_ItemPreview old) => old.item.id != item.id;
}

class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key, required this.store});
  final DayStore store;

  /// This week, Monday first: a missed day is a rest day until the week's
  /// rest days run out.
  List<_Mark> _marks(DateTime today, DateTime monday) {
    final first = store.firstActiveDay;
    var rests = 0;
    return [
      for (var i = 0; i < 7; i++)
        switch (DateTime(monday.year, monday.month, monday.day + i)) {
          final d when store.activeOn(d) => _Mark.done,
          final d when sameDay(d, today) => _Mark.today,
          final d when d.isAfter(today) => _Mark.toCome,
          final d when first == null || d.isBefore(first) => _Mark.before,
          _ => ++rests <= restDays ? _Mark.rest : _Mark.missed,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = store.streak();
    final left = restDays - store.restDaysUsed();
    final today = dayOf(DateTime.now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('streak-sheet'),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(title: tr('Streak', '连续打卡')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: flame,
                        size: 44,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          days > 0
                              ? tr(count(days, 'day'), '$days 天')
                              : tr('Not started yet', '还没开始'),
                          style: t.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Days in a row with at least one thing done or a focus session.',
                      '连续每天至少完成一件事或专注一次的天数。',
                    ),
                    style: t.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                    child: Row(
                      children: [
                        for (final (i, mark) in _marks(today, monday).indexed)
                          Expanded(
                            child: _WeekDay(
                              day: DateTime(
                                monday.year,
                                monday.month,
                                monday.day + i,
                              ),
                              mark: mark,
                              head: weekdayHeads[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      'Everyone needs a break. You get $restDays rest days a week: a day off uses one, and your streak keeps going.',
                      '谁都需要休息。每周有 $restDays 天休息日：哪天没做也只是用掉一天休息日，连续天数不会断。',
                    ),
                    style: t.bodyMedium?.copyWith(color: context.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    key: const Key('rest-left'),
                    tr('Rest days left this week: $left', '本周还剩 $left 天休息日'),
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

enum _Mark { done, rest, missed, today, toCome, before }

/// One day of this week: done, a rest day, today or still to come.
class _WeekDay extends StatelessWidget {
  const _WeekDay({required this.day, required this.mark, required this.head});
  final DateTime day;
  final _Mark mark;
  final String head;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = mark == _Mark.done;
    final isToday = sameDay(day, DateTime.now());
    final (icon, color, what) = switch (mark) {
      _Mark.done => (Icons.local_fire_department, flame, tr('done', '完成')),
      _Mark.rest => (
        Icons.bedtime_outlined,
        context.muted,
        tr('rest day', '休息日'),
      ),
      _Mark.missed => (Icons.remove, context.muted, tr('missed', '没做')),
      _Mark.today => (null, context.muted, tr('today', '今天')),
      _Mark.toCome => (null, context.muted, tr('to come', '还没到')),
      _Mark.before => (null, context.muted, tr('before you started', '开始之前')),
    };
    return Semantics(
      label: '${fullDate(day)}: $what',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            head,
            style: t.labelMedium?.copyWith(
              color: isToday ? context.green : context.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? flame.withValues(alpha: 0.16) : null,
              border: isToday && !done
                  ? Border.all(color: context.green, width: 2)
                  : null,
            ),
            child: icon == null ? null : Icon(icon, size: 20, color: color),
          ),
        ],
      ),
    );
  }
}
