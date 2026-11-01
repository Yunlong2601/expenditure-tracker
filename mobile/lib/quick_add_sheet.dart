import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'draft.dart';
import 'categories.dart';
import 'feel.dart';

/// For cash at the hawker centre: type the amount, tap a category, done.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amount = TextEditingController();
  String _currency = 'SGD';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pick(String category) {
    final v = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    if (v <= 0) {
      Feel.oops();
      setState(() => _error = 'Type the amount first');
      return;
    }
    Navigator.of(context).pop(ExpenseDraft(amount: v, currency: _currency, category: category));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How much?', style: t.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'SGD', label: Text(r'S$')),
                    ButtonSegment(value: 'CNY', label: Text('¥')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (s) => setState(() => _currency = s.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('quick-amount'),
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: t.headlineMedium,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _error == null ? null : setState(() => _error = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Tap what it was for', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, icon) in quickCategories)
                  Pressable(
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
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
