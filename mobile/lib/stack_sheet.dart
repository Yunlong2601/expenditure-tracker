import 'package:flutter/material.dart';

import 'day.dart';
import 'feel.dart';
import 'theme.dart';

/// Edit stack (IMG_6797, 6798): the stack's name, a help note, numbered step
/// cards with a note each, hold to reorder, swipe left to delete, add step.
class StackSheet extends StatefulWidget {
  const StackSheet({super.key, required this.store, this.task});
  final DayStore store;

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
    _help = widget.task?.title == DayStore.gettingStartedTitle;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final steps = _steps.where((s) => s.title.trim().isNotEmpty).toList();
    final title = _title.text.trim().isEmpty
        ? (steps.firstOrNull?.title ?? 'Stack')
        : _title.text.trim();
    final t = widget.task;
    if (steps.isEmpty) {
      if (t != null) await widget.store.removeTask(t);
    } else if (t == null) {
      await widget.store.addTask(title, steps: steps);
    } else {
      t.title = title;
      t.steps
        ..clear()
        ..addAll(steps);
      t.done = t.topStep == null;
      t.doneAt = t.done ? (t.doneAt ?? DateTime.now()) : null;
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
        title: const Text('Step'),
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: const Text('OK'),
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
        SheetHeader(title: 'Edit stack', action: 'Save', onAction: _save),
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
                      decoration: const InputDecoration(
                        hintText: 'Name this stack',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'How stacks work',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.question_mark),
                    onPressed: () => setState(() => _help = !_help),
                  ),
                ],
              ),
              if (_help)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Steps stacked on top of each other: your list shows only the top one, and the next '
                    'appears when you check it off. Hold a step to reorder; swipe left to delete.',
                    style: t.bodyMedium?.copyWith(
                      color: Palette.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$done of ${_steps.length} steps done',
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) => setState(() {
                      for (final s in _steps) {
                        s.done = v == 'all';
                      }
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'all', child: Text('Mark all done')),
                      PopupMenuItem(value: 'none', child: Text('Start over')),
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
                label: const Text(
                  'Add step',
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
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.muted, width: 1.4),
                  borderRadius: BorderRadius.circular(7),
                  color: step.done ? Palette.sageSoft : null,
                ),
                child: step.done
                    ? const Icon(Icons.check, size: 16, color: Palette.sage)
                    : Text(
                        '$n',
                        style: t.labelMedium?.copyWith(color: Palette.muted),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title.isEmpty ? 'New step' : step.title,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: step.title.isEmpty ? Palette.muted : null,
                        decoration: step.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.done ? 'Done' : 'To-do',
                      style: t.bodySmall?.copyWith(color: Palette.muted),
                    ),
                    InkWell(
                      onTap: onToggleNote,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              noteOpen ? Icons.expand_less : Icons.expand_more,
                              size: 14,
                              color: Palette.muted,
                            ),
                            Text(
                              ' Note',
                              style: t.bodySmall?.copyWith(
                                color: Palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (noteOpen)
                      TextFormField(
                        initialValue: step.note,
                        maxLines: null,
                        onChanged: onNote,
                        decoration: const InputDecoration(
                          hintText: 'Add a note',
                          isDense: true,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Palette.muted),
                onSelected: onMenu,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(step.done ? 'Mark to-do' : 'Mark done'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete step'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
