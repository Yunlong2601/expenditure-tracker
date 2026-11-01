import 'package:flutter/material.dart';

import 'feel.dart';
import 'format.dart';
import 'kitty.dart';
import 'prefs.dart';

/// "Saving for concert tickets: S$45 of S$120", with a cat that gets happier
/// as the jar fills. Shows a small "Start a savings goal" button when unset.
class GoalCard extends StatefulWidget {
  const GoalCard({super.key});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  Prefs get _p => Prefs.current;

  Future<void> _setGoal() async {
    final r = await showDialog<(String, double)?>(
      context: context,
      builder: (_) => _GoalDialog(name: _p.goalName, target: _p.goalName == null ? null : _p.goalTarget),
    );
    if (r == null) return;
    if (r.$1.isEmpty) {
      await _p.setGoal(null);
    } else {
      await _p.setGoal(r.$1, target: r.$2, saved: _p.goalName == null ? 0 : _p.goalSaved);
    }
    setState(() {});
  }

  Future<void> _add() async {
    final v = await showDialog<double>(context: context, builder: (_) => const _AmountDialog());
    if (v == null || v <= 0) return;
    final wasDone = _p.goalSaved >= _p.goalTarget;
    await _p.addToGoal(v);
    Feel.logged();
    if (!wasDone && _p.goalSaved >= _p.goalTarget) KittyLayer.cheer();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = _p.goalName;
    if (name == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('goal-start'),
          onPressed: () {
            Feel.tap();
            _setGoal();
          },
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Start a savings goal'),
        ),
      );
    }
    final target = _p.goalTarget;
    final saved = _p.goalSaved;
    final done = saved >= target;
    final part = target <= 0 ? 1.0 : (saved / target).clamp(0.0, 1.0);
    // Grows from small to full size as the jar fills.
    final catSize = 44 + 24 * part;
    return Pressable(
      scale: 0.98,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cs.secondaryContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          key: const Key('goal'),
          onTap: _setGoal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Center(
                    child: SizedBox(
                      width: catSize,
                      height: catSize,
                      child: CustomPaint(
                        painter: CatPainter(mood: part >= 0.75 ? CatMood.delighted : CatMood.happy, paw: done),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? 'You did it! $name' : 'Saving for $name',
                        style: t.titleMedium?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: part,
                          minHeight: 8,
                          backgroundColor: cs.onSecondaryContainer.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${money(saved, 'SGD')} of ${money(target, 'SGD')}',
                        key: const Key('goal-progress'),
                        style: t.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('goal-add'),
                  tooltip: 'Add to savings',
                  onPressed: () {
                    Feel.tap();
                    _add();
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.name, this.target});
  final String? name;
  final double? target;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _target = TextEditingController(text: widget.target?.toStringAsFixed(2) ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Savings goal'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('goal-name'),
          controller: _name,
          autofocus: widget.name == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: "What's it for?", hintText: 'Concert tickets'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('goal-target'),
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'How much does it cost?', prefixText: r'S$ ', errorText: _error),
        ),
      ],
    ),
    actions: [
      if (widget.name != null)
        TextButton(onPressed: () => Navigator.of(context).pop(('', 0.0)), child: const Text('Remove')),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        key: const Key('goal-save'),
        onPressed: () {
          final v = double.tryParse(_target.text.replaceAll(',', '').trim()) ?? 0;
          if (_name.text.trim().isEmpty || v <= 0) {
            Feel.oops();
            setState(() => _error = 'Give it a name and a price');
            return;
          }
          Navigator.of(context).pop((_name.text.trim(), v));
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog();

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add to savings'),
    content: TextField(
      key: const Key('goal-amount'),
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: const InputDecoration(prefixText: r'S$ ', hintText: '5.00'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        key: const Key('goal-amount-save'),
        onPressed: () => Navigator.of(context).pop(double.tryParse(_amount.text.replaceAll(',', '').trim())),
        child: const Text('Add'),
      ),
    ],
  );
}
