import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';

/// Asks how many people (her included) share a bill, and optionally who.
/// Returns null when cancelled.
Future<(int, List<String>)?> askSplit(BuildContext context, {required double total, required String currency}) =>
    showDialog<(int, List<String>)>(
      context: context,
      builder: (_) => _SplitDialog(total: total, currency: currency),
    );

class _SplitDialog extends StatefulWidget {
  const _SplitDialog({required this.total, required this.currency});
  final double total;
  final String currency;

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  int _people = 2;
  final _names = TextEditingController();

  @override
  void dispose() {
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final each = widget.total / _people;
    return AlertDialog(
      title: const Text('Split the bill'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many people, you included?', style: t.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 2; n <= 8; n++)
                ChoiceChip(
                  key: Key('split-$n'),
                  label: Text('$n'),
                  selected: _people == n,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _people = n);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Each pays ${money(each, widget.currency)}', style: t.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const Key('split-names'),
            controller: _names,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: "Friends' names (optional)", hintText: 'Amy, Bella, Chloe'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          key: const Key('split-save'),
          onPressed: () => Navigator.of(context).pop((
            _people,
            [
              for (final n in _names.text.split(RegExp('[,，、]')))
                if (n.trim().isNotEmpty) n.trim(),
            ],
          )),
          child: const Text('Split'),
        ),
      ],
    );
  }
}
