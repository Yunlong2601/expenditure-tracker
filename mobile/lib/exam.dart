import 'package:flutter/material.dart';

import 'day.dart';
import 'feel.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'study.dart';
import 'theme.dart';

/// "1 h 10 min" or "25 min".
String minutesText(int m) => m >= 60
    ? tr(
        '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}',
        '${m ~/ 60} 小时${m % 60 == 0 ? '' : ' ${m % 60} 分钟'}',
      )
    : tr('$m min', '$m 分钟');

/// A colour for each subject in the week's bar, most studied first.
const subjectColors = [
  Color(0xFF7FB58A),
  Color(0xFF8EA7D8),
  Color(0xFFE8B067),
  Color(0xFFEB8A5A),
];

/// Goals to pick from, in minutes a day.
const studyGoals = [15, 30, 45, 60, 90, 120];

/// Exam season: when an exam is a month away or less, Home leads with it.
/// Days to go, today's study against the goal, and the week by subject.
class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.store,
    required this.exam,
    required this.onStudy,
  });
  final DayStore store;
  final Countdown exam;
  final VoidCallback onStudy;

  Future<void> _pickGoal(BuildContext context) async {
    Feel.tap();
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  tr('Study goal for each day', '每天的学习目标'),
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final m in studyGoals)
                ListTile(
                  key: Key('goal-$m'),
                  selected: Prefs.current.studyGoal == m,
                  title: Text(minutesText(m)),
                  trailing: Prefs.current.studyGoal == m
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(m),
                ),
            ],
          ),
        ),
      ),
    );
    if (v == null) return;
    await Prefs.current.setStudyGoal(v);
    await store.save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = exam.daysLeft();
    final goal = Prefs.current.studyGoal;
    final today = store.focusMinutesOn(DateTime.now());
    final subjects = store.focusBySubject(DateTime.now()).take(4).toList();
    return Panel(
      key: const Key('exam-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.school_outlined, color: context.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days == 0
                          ? tr(
                              '${exam.title} is today. You’ve got this!',
                              '今天就是${exam.title}，加油！',
                            )
                          : tr(
                              '${exam.title} in ${count(days, 'day')}',
                              '离${exam.title}还有 $days 天',
                            ),
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      tr(
                        'Exam season · ${dateWithWeekday(exam.next())}',
                        '备考中 · ${dateWithWeekday(exam.next())}',
                      ),
                      style: t.bodyMedium?.copyWith(color: context.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Today against the goal; tap the goal to change it.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                tr(
                  'Today: ${minutesText(today)} of ${minutesText(goal)}',
                  '今天：${minutesText(today)} / ${minutesText(goal)}',
                ),
                key: const Key('exam-today'),
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextButton(
                key: const Key('exam-goal'),
                onPressed: () => _pickGoal(context),
                child: Text(tr('Change goal', '改目标')),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (today / goal).clamp(0.0, 1.0),
              minHeight: 10,
              color: context.green,
              backgroundColor: context.greenSoft,
              semanticsLabel: tr('Today’s study goal', '今天的学习目标'),
            ),
          ),
          if (today >= goal) ...[
            const SizedBox(height: 6),
            Text(
              tr(
                'Goal done for today. Rest is part of studying too.',
                '今天的目标完成啦。休息也是学习的一部分。',
              ),
              style: t.bodyMedium?.copyWith(
                color: context.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            tr('This week by subject', '这周各科'),
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (subjects.isEmpty)
            Text(
              tr(
                'No study time yet this week. Start with 15 minutes.',
                '这周还没有学习时间，先从 15 分钟开始吧。',
              ),
              style: t.bodyMedium?.copyWith(color: context.muted),
            )
          else ...[
            // One bar shared out by subject, with a key under it.
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final (i, MapEntry(value: m)) in subjects.indexed)
                      Expanded(
                        flex: m,
                        child: ColoredBox(color: subjectColors[i]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final (i, MapEntry(key: k, value: m)) in subjects.indexed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: subjectColors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${subjectLabel(k)} ${minutesText(m)}',
                          style: t.bodyMedium,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('exam-study'),
              onPressed: onStudy,
              icon: const Icon(Icons.timer_outlined),
              label: Text(tr('Study now', '现在学习')),
            ),
          ),
        ],
      ),
    );
  }
}
