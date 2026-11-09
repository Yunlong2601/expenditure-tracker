import 'package:flutter/material.dart';

import 'day.dart';
import 'feel.dart';
import 'l10n.dart';
import 'theme.dart';

/// Edit stack (IMG_6797, 6798): the stack's name, a help note, numbered step
/// cards with a note each, hold to reorder, swipe left to delete, add step.
class StackSheet extends StatefulWidget {
  const StackSheet({super.key, required this.store, this.task, this.day});
  final DayStore store;

  /// The day a new stack goes on; today when null.
  final DateTime? day;

  /// The stack to edit, or null to make a new one.
  final Task? task;

  @override
  State<StackSheet> createState() => _StackSheetState();
}

class _StackSheetState extends State<StackSheet> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final List<StackStep> _steps = [
    for (final s in widget.task?.steps ?? const <StackStep>[])
      StackStep(s.title, done: s.done, note: s.note),
  ];
  final _openNotes = <StackStep>{};
  bool _help = false;

  @override
  void initState() {
    super.initState();
    if (_steps.isEmpty) _steps.add(StackStep(''));
    // The note stays folded until "?" is tapped, as in IMG_6797.
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = _steps.where((s) => s.title.trim().isNotEmpty).toList();
    final title = _title.text.trim().isEmpty
        ? (steps.firstOrNull?.title ?? tr('Stack', '分步任务'))
        : _title.text.trim();
    final t = widget.task;
    if (steps.isEmpty) {
      if (t != null) await widget.store.removeTask(t);
    } else if (t == null) {
      await widget.store.addTask(title, steps: steps, day: widget.day);
    } else {
      t.title = title;
      t.steps
        ..clear()
        ..addAll(steps);
      t.done = t.topStep == null;
      t.doneAt = t.done ? (t.doneAt ?? DateTime.now()) : null;
      widget.store.unlockNextPart(t);
      await widget.store.save();
    }
    Feel.logged();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editStep(StackStep s) async {
    final c = TextEditingController(text: s.title);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Step', '步骤')),
        content: TextField(
          key: const Key('step-field'),
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(tr('OK', '好')),
          ),
        ],
      ),
    );
    if (v != null) setState(() => s.title = v.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final done = _steps.where((s) => s.done).length;
    return Column(
      children: [
        SheetHeader(title: tr('Edit stack', '编辑分步任务'), action: tr('Save', '保存'), onAction: _save),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('stack-title'),
                      controller: _title,
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('Name this stack', '给这个任务起个名字'),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: tr('How stacks work', '分步任务怎么用'),
                    iconSize: 18,
                    icon: const Icon(Icons.question_mark),
                    onPressed: () => setState(() => _help = !_help),
                  ),
                ],
              ),
              if (_help)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    tr('Steps stacked on top of each other: your list shows only the top one, and the next appears when you check it off. Hold a step to reorder; swipe left to delete.', '把一件事拆成几步：清单上只显示当前这一步，勾掉后下一步才出现。长按步骤可以排序，左滑删除。'),
                    style: t.bodyMedium?.copyWith(
                      color: context.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('$done of ${count(_steps.length, 'step')} done', '已完成 $done/${_steps.length} 步'),
                      style: t.bodyMedium?.copyWith(color: context.muted),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('All steps', '所有步骤'),
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) => setState(() {
                      for (final s in _steps) {
                        s.done = v == 'all';
                      }
                    }),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'all', child: Text(tr('Mark all done', '全部完成'))),
                      PopupMenuItem(value: 'none', child: Text(tr('Start over', '重新开始'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => setState(() {
                  _steps.insert(to, _steps.removeAt(from));
                }),
                children: [
                  for (final (i, s) in _steps.indexed)
                    ReorderableDelayedDragStartListener(
                      key: ObjectKey(s),
                      index: i,
                      child: Dismissible(
                        key: ObjectKey(('d', s)),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => setState(() => _steps.remove(s)),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Icon(Icons.delete_outline, color: cs.error),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StepCard(
                            n: i + 1,
                            step: s,
                            noteOpen: _openNotes.contains(s),
                            onTap: () => _editStep(s),
                            onToggleNote: () => setState(
                              () => _openNotes.contains(s)
                                  ? _openNotes.remove(s)
                                  : _openNotes.add(s),
                            ),
                            onNote: (v) => s.note = v.trim().isEmpty ? null : v,
                            onMenu: (v) => setState(() {
                              if (v == 'delete') _steps.remove(s);
                              if (v == 'toggle') s.done = !s.done;
                            }),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: TextButton.icon(
                key: const Key('add-step'),
                icon: const Icon(Icons.add),
                label: Text(
                  tr('Add step', '添加步骤'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final s = StackStep('');
                  setState(() => _steps.add(s));
                  await _editStep(s);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.n,
    required this.step,
    required this.noteOpen,
    required this.onTap,
    required this.onToggleNote,
    required this.onNote,
    required this.onMenu,
  });
  final int n;
  final StackStep step;
  final bool noteOpen;
  final VoidCallback onTap, onToggleNote;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 2),
          // The box and the menu line up with the step's first line.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: context.muted, width: 1.4),
                  borderRadius: BorderRadius.circular(7),
                  color: step.done ? context.greenSoft : null,
                ),
                child: step.done
                    ? Icon(Icons.check, size: 16, color: context.green)
                    : Text(
                        '$n',
                        style: t.labelMedium?.copyWith(color: context.muted),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title.isEmpty ? tr('New step', '新步骤') : step.title,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: step.title.isEmpty ? context.muted : null,
                        decoration: step.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    // Done or to-do, then the note, on one line when they fit.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          step.done ? tr('Done', '已完成') : tr('To-do', '待办'),
                          style: t.bodySmall?.copyWith(color: context.muted),
                        ),
                        Text(
                          '  ·  ',
                          style: t.bodySmall?.copyWith(color: context.muted),
                        ),
                        InkWell(
                          onTap: onToggleNote,
                          // Big enough to tap (48 points), though the words are small.
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 48,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr('Note', '备注'),
                                  style: t.bodySmall?.copyWith(
                                    color: context.muted,
                                  ),
                                ),
                                Icon(
                                  noteOpen ? Icons.expand_less : Icons.expand_more,
                                  size: 16,
                                  color: context.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (noteOpen)
                      TextFormField(
                        initialValue: step.note,
                        maxLines: null,
                        onChanged: onNote,
                        decoration: InputDecoration(
                          hintText: tr('Add a note', '写点备注'),
                          isDense: true,
                        ),
                      ),
                  ],
                ),
              ),
              // Raised so its dots sit on the first line too.
              Transform.translate(
                offset: const Offset(0, -10),
                child: PopupMenuButton<String>(
                  tooltip: tr('Step options', '这一步的选项'),
                  icon: Icon(Icons.more_horiz, color: context.muted),
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(step.done ? tr('Mark to-do', '改回待办') : tr('Mark done', '标为完成')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr('Delete step', '删除这一步')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
