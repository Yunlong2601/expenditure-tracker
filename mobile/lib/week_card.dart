import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'day.dart';
import 'exam.dart';
import 'feel.dart';
import 'home_tab.dart' show MoodDot;
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'room.dart' show flame;
import 'share.dart';
import 'study.dart' show subjectLabel;
import 'theme.dart';

/// One week, Monday to Sunday, in the numbers the picture shows. No task
/// names, so the picture is safe to post.
class WeekStats {
  const WeekStats({
    required this.monday,
    required this.study,
    required this.done,
    required this.activeDays,
    required this.moods,
    required this.subjects,
    required this.streak,
  });

  /// The week that [day] falls in, as it stands [now].
  factory WeekStats.of(DayStore s, DateTime day, {DateTime? now}) {
    final today = dayOf(now ?? DateTime.now());
    final monday = mondayOf(day);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final by = <String, int>{};
    for (final d in days) {
      for (final e in s.focusOn(d)) {
        final m = int.tryParse(e.text) ?? 0;
        if (m > 0) by.update(e.kind ?? '', (v) => v + m, ifAbsent: () => m);
      }
    }
    return WeekStats(
      monday: monday,
      study: by.values.fold(0, (a, b) => a + b),
      done: days.fold(0, (n, d) => n + s.doneOn(d).length),
      activeDays: days.where(s.activeOn).length,
      moods: [for (final d in days) s.moodOf(d)],
      subjects: by.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      streak: s.streak(days.last.isBefore(today) ? days.last : today),
    );
  }

  final DateTime monday;

  /// Minutes of finished focus.
  final int study;

  /// Things ticked off.
  final int done;

  /// Days with something done, out of 7.
  final int activeDays;

  /// Each day's mood, Monday first.
  final List<Mood?> moods;
  final List<MapEntry<String, int>> subjects;
  final int streak;

  DateTime get sunday => DateTime(monday.year, monday.month, monday.day + 6);

  /// "3 – 9 Nov", or "27 Oct – 2 Nov" across months.
  String get range {
    if (zh) return '${dayMonth(monday)} – ${dayMonth(sunday)}';
    return monday.month == sunday.month
        ? '${monday.day} – ${dayMonth(sunday)}'
        : '${dayMonth(monday)} – ${dayMonth(sunday)}';
  }

  /// What the cat says about the week.
  String cheer(String cat) {
    if (study == 0 && done == 0) {
      return tr('A quiet week. A fresh start on Monday!', '这周比较安静，下周一重新开始！');
    }
    if (study >= 300) {
      return tr('$cat is proud of all that studying!', '$cat 为你的努力骄傲！');
    }
    if (activeDays >= 5) {
      return tr(
        'Something done on $activeDays days. Great rhythm!',
        '这周有 $activeDays 天都有完成，节奏很棒！',
      );
    }
    return tr('Every little bit counts. Keep going!', '每一点努力都算数，继续加油！');
  }

  /// What a screen reader says instead of reading the picture piece by piece.
  String get spoken => tr(
    'My week, $range: studied ${minutesText(study)}, '
        '${count(done, 'thing')} done, ${count(streak, 'day')} streak.',
    '我的一周，$range：学习 ${minutesText(study)}，完成 $done 件事，连续 $streak 天。',
  );
}

/// The Monday of [d]'s week.
DateTime mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Opens the week's picture.
Future<void> showWeekCard(BuildContext context, DayStore store) {
  Feel.tap();
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => WeekCardScreen(store: store)));
}

/// A picture of her week sized for stories (1080 × 1920), to save or send.
class WeekCardScreen extends StatefulWidget {
  const WeekCardScreen({super.key, required this.store, this.week});
  final DayStore store;
  final DateTime? week;

  @override
  State<WeekCardScreen> createState() => _WeekCardScreenState();
}

class _WeekCardScreenState extends State<WeekCardScreen> {
  final _picture = GlobalKey();
  late DateTime _monday = mondayOf(widget.week ?? DateTime.now());
  bool _sharing = false;

  void _go(int weeks) {
    Feel.tap();
    setState(
      () => _monday = DateTime(
        _monday.year,
        _monday.month,
        _monday.day + 7 * weeks,
      ),
    );
  }

  Future<void> _share() async {
    Feel.tap();
    setState(() => _sharing = true);
    var ok = false;
    try {
      final b =
          _picture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final d = _monday;
      final name =
          'TinyHabitsCat-week-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.png';
      if (png != null) ok = await Share.bytes(png.buffer.asUint8List(), name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Couldn’t open sharing. Try again.', '没能打开分享，再试一次吧。'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stats = WeekStats.of(widget.store, _monday);
    final thisWeek = !mondayOf(DateTime.now()).isAfter(_monday);
    return Scaffold(
      appBar: AppBar(title: Text(tr('My week', '我的一周'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            // As big as fits with the button still in view, on any phone.
            final w = box.maxWidth - 40;
            final h = (w * 16 / 9).clamp(
              0.0,
              (box.maxHeight - 200).clamp(300.0, double.infinity),
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('week-back'),
                      tooltip: tr('Last week', '上一周'),
                      onPressed: () => _go(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        stats.range,
                        textAlign: TextAlign.center,
                        style: t.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('week-next'),
                      tooltip: tr('Next week', '下一周'),
                      onPressed: thisWeek ? null : () => _go(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: h * 9 / 16,
                    height: h,
                    child: Semantics(
                      image: true,
                      label: stats.spoken,
                      excludeSemantics: true,
                      child: FittedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: RepaintBoundary(
                            key: _picture,
                            child: WeekCard(store: widget.store, stats: stats),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('share-week'),
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.ios_share),
                  label: Text(tr('Save or share picture', '保存或分享图片')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Only your numbers are on it, no task names.',
                    '图里只有你的数字，没有任务名。',
                  ),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: context.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The picture itself: 360 × 640, drawn the same whatever the text size.
class WeekCard extends StatelessWidget {
  const WeekCard({super.key, required this.store, required this.stats});
  final DayStore store;
  final WeekStats stats;

  static const size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = Prefs.current.catName;
    final good = stats.activeDays >= 4 || stats.study >= 120;
    final subjects = stats.subjects.take(4).toList();
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.greenSoft, context.sand],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('MY WEEK', '我的一周'),
                  style: t.labelLarge?.copyWith(
                    color: context.green,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  stats.range,
                  maxLines: 1,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: CatPainter(
                        mood: good ? CatMood.delighted : CatMood.happy,
                        outfit: store.outfit,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Tile(
                      value: minutesText(stats.study),
                      label: tr('studied', '学习'),
                      icon: Icons.timer_outlined,
                      color: subjectColors[0],
                    ),
                    const SizedBox(width: 10),
                    _Tile(
                      value: '${stats.done}',
                      label: tr(
                        stats.done == 1 ? 'thing done' : 'things done',
                        '件事完成',
                      ),
                      icon: Icons.check_circle_outline,
                      color: subjectColors[1],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Tile(
                      value: tr(
                        count(stats.streak, 'day'),
                        '${stats.streak} 天',
                      ),
                      label: tr('streak', '连续打卡'),
                      icon: Icons.local_fire_department,
                      color: flame,
                    ),
                    const SizedBox(width: 10),
                    _Tile(
                      value: '${stats.activeDays} / 7',
                      label: tr('days active', '天有行动'),
                      icon: Icons.event_available_outlined,
                      color: subjectColors[2],
                    ),
                  ],
                ),
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      key: const Key('week-subjects'),
                      height: 10,
                      child: Row(
                        // Full height: a bare ColoredBox is as small as it may be.
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, MapEntry(value: m))
                              in subjects.indexed)
                            Expanded(
                              flex: m,
                              child: ColoredBox(color: subjectColors[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      for (final MapEntry(key: k, value: m) in subjects.take(3))
                        '${subjectLabel(k)} ${minutesText(m)}',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (final (i, m) in stats.moods.indexed)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              weekdayHeads[i],
                              style: t.labelSmall?.copyWith(
                                color: context.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            MoodDot(mood: m, size: 28),
                          ],
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  stats.cheer(cat),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.pets, size: 16, color: context.green),
                    const SizedBox(width: 6),
                    Text(
                      'Tiny Habits Cat',
                      style: t.labelMedium?.copyWith(
                        color: context.muted,
                        fontWeight: FontWeight.w700,
                      ),
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

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String value, label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: context.muted),
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
