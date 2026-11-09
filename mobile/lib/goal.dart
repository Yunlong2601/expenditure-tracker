import 'package:flutter/material.dart';

import 'feel.dart';
import 'format.dart';
import 'jar.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';

/// "Saving for concert tickets: S$45 of S$120", with the thing's picture in a
/// jar that fills up and a cat on the lid that gets happier as it does.
/// Shows a small "Start a savings goal" button when unset.
class GoalCard extends StatefulWidget {
  const GoalCard({super.key});

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  Prefs get _p => Prefs.current;

  Future<void> _setGoal() async {
    final r = await showDialog<(String, double, String?)?>(
      context: context,
      builder: (_) =>
          _GoalDialog(name: _p.goalName, target: _p.goalName == null ? null : _p.goalTarget, pic: _p.goalPic),
    );
    if (r == null) return;
    if (r.$1.isEmpty) {
      await _p.setGoal(null);
    } else {
      await _p.setGoal(r.$1, target: r.$2, saved: _p.goalName == null ? 0 : _p.goalSaved, pic: r.$3);
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
          label: Text(tr('Start a savings goal', '开始一个存钱目标')),
        ),
      );
    }
    final target = _p.goalTarget;
    final saved = _p.goalSaved;
    final done = saved >= target;
    final part = target <= 0 ? 1.0 : (saved / target).clamp(0.0, 1.0);
    final pic = _p.goalPic ?? goalPicFor(name);
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
                Jar(
                  key: const Key('goal-jar'),
                  fill: part,
                  size: const Size(58, 68),
                  mood: part >= 0.75 ? CatMood.delighted : CatMood.happy,
                  child: Text(pic, key: const Key('goal-pic'), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? tr('You did it! $name', '做到啦！$name') : tr('Saving for $name', '正在为 $name 存钱'),
                        style: t.titleMedium?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('${money(saved, 'SGD')} of ${money(target, 'SGD')}', '${money(saved, 'SGD')} / ${money(target, 'SGD')}'),
                        key: const Key('goal-progress'),
                        style: t.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('goal-add'),
                  tooltip: tr('Add to savings', '存一笔'),
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
  const _GoalDialog({this.name, this.target, this.pic});
  final String? name;
  final double? target;
  final String? pic;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _target = TextEditingController(text: widget.target?.toStringAsFixed(2) ?? '');
  // Picked by her, else guessed from the name as she types.
  late String? _pic = widget.pic;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(tr('Savings goal', '存钱目标')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('goal-name'),
          controller: _name,
          autofocus: widget.name == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr("What's it for?", '为了什么存钱？'), hintText: tr('Concert tickets', '演唱会门票')),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(tr('Picture', '图片'), style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final p in goalPics)
              ChoiceChip(
                key: Key('goal-pic-$p'),
                label: Text(p, style: const TextStyle(fontSize: 20)),
                showCheckmark: false,
                selected: p == (_pic ?? goalPicFor(_name.text)),
                onSelected: (_) => setState(() => _pic = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('goal-target'),
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('How much does it cost?', '需要多少钱？'), prefixText: r'S$ ', errorText: _error),
        ),
      ],
    ),
    actions: [
      if (widget.name != null)
        TextButton(onPressed: () => Navigator.of(context).pop(('', 0.0, null)), child: Text(tr('Remove', '移除'))),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Cancel', '取消'))),
      FilledButton(
        key: const Key('goal-save'),
        onPressed: () {
          final v = double.tryParse(_target.text.replaceAll(',', '').trim()) ?? 0;
          if (_name.text.trim().isEmpty || v <= 0) {
            Feel.oops();
            setState(() => _error = tr('Give it a name and a price', '写上名字和价格'));
            return;
          }
          Navigator.of(context).pop((_name.text.trim(), v, _pic));
        },
        child: Text(tr('Save', '保存')),
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
    title: Text(tr('Add to savings', '存一笔')),
    content: TextField(
      key: const Key('goal-amount'),
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: const InputDecoration(prefixText: r'S$ ', hintText: '5.00'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Cancel', '取消'))),
      FilledButton(
        key: const Key('goal-amount-save'),
        onPressed: () => Navigator.of(context).pop(double.tryParse(_amount.text.replaceAll(',', '').trim())),
        child: Text(tr('Add', '添加')),
      ),
    ],
  );
}
