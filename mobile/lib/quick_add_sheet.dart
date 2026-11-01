import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'categories.dart';
import 'draft.dart';
import 'feel.dart';
import 'format.dart';

/// For cash at the canteen: type the amount, tap a category, done.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, this.ownCategories = const []});

  /// Categories she made up herself, shown after the built-in ones.
  final List<String> ownCategories;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amount = TextEditingController();
  String _currency = 'SGD';
  String? _error;

  /// Recording money she got instead of money spent.
  bool _in = false;

  static const _sources = <(String, IconData)>[
    ('Pocket money', Icons.savings_outlined),
    ('From family', Icons.family_restroom),
    ('Friend paid back', Icons.handshake_outlined),
    ('Red packet', Icons.redeem),
    ('Other', Icons.more_horiz),
  ];

  /// One tap away; the rest sit under "More".
  static const _main = ['SGD', 'MYR', 'CNY'];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;

  bool _needAmount() {
    if (_value > 0) return false;
    Feel.oops();
    setState(() => _error = 'Type the amount first');
    return true;
  }

  void _pick(String category) {
    if (_needAmount()) return;
    Navigator.of(context).pop(ExpenseDraft(amount: _value, currency: _currency, category: category, moneyIn: _in));
  }

  Future<void> _newCategory() async {
    if (_needAmount()) return;
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name != null && name.trim().isNotEmpty) _pick(name.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final builtIn = {for (final (n, _) in quickCategories) n.toLowerCase()};
    final own = [
      for (final c in widget.ownCategories)
        if (!builtIn.contains(c.toLowerCase())) c,
    ];
    Widget chip(String name, IconData icon) => Pressable(
      scale: 0.92,
      child: ActionChip(
        key: Key('cat-$name'),
        avatar: Icon(icon, size: 20),
        label: Text(name),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        onPressed: () {
          HapticFeedback.selectionClick();
          _pick(name);
        },
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('I spent'), icon: Icon(Icons.shopping_bag_outlined)),
                ButtonSegment(
                  value: true,
                  label: Text('I got money', key: Key('mode-in')),
                  icon: Icon(Icons.savings_outlined),
                ),
              ],
              selected: {_in},
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _in = s.first);
              },
            ),
            const SizedBox(height: 16),
            Text(_in ? 'How much did you get?' : 'How much?', style: t.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final c in {..._main, _currency})
                  ChoiceChip(
                    key: Key('cur-$c'),
                    label: Text(c == 'CNY' ? '¥ RMB' : money(0, c).replaceAll(RegExp(r'[\d.,]'), '').trim()),
                    selected: _currency == c,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _currency = c);
                    },
                  ),
                PopupMenuButton<String>(
                  key: const Key('cur-more'),
                  tooltip: 'More currencies',
                  onSelected: (c) => setState(() => _currency = c),
                  itemBuilder: (_) => [
                    for (final c in currencies)
                      if (!_main.contains(c))
                        PopupMenuItem(value: c, child: Text('$c  ${money(0, c).split('0').first}')),
                  ],
                  child: const Chip(avatar: Icon(Icons.public, size: 18), label: Text('More')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('quick-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: t.headlineMedium,
              decoration: InputDecoration(
                prefixText: '${money(0, _currency).split('0').first} ',
                hintText: '0.00',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _error == null ? null : setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            Text(_in ? 'Where from?' : 'Tap what it was for', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_in) ...[
                  for (final (name, icon) in _sources) chip(name, icon),
                ] else ...[
                  for (final (name, icon) in quickCategories) chip(name, icon),
                  for (final name in own) chip(name, iconFor(name)),
                ],
                if (!_in)
                  Pressable(
                    scale: 0.92,
                    child: ActionChip(
                      key: const Key('cat-new'),
                      avatar: const Icon(Icons.add, size: 20),
                      label: const Text('New…'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      onPressed: _newCategory,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New category'),
    content: TextField(
      key: const Key('new-category'),
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'e.g. Concert, Bus card top-up'),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        key: const Key('new-category-save'),
        onPressed: () => Navigator.of(context).pop(_name.text),
        child: const Text('Save'),
      ),
    ],
  );
}
