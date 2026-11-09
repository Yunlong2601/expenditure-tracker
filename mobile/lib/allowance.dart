import 'package:flutter/material.dart';

import 'feel.dart';
import 'l10n.dart';
import 'prefs.dart';

/// Asks how much pocket money she gets, per week or per day, and saves it.
/// Returns true when something changed.
Future<bool> editAllowance(BuildContext context) async {
  final p = Prefs.current;
  final result = await showDialog<(double?, bool)>(
    context: context,
    builder: (_) => _AllowanceDialog(amount: p.allowance, daily: p.allowanceDaily),
  );
  if (result == null) return false;
  await p.setAllowance(result.$1, daily: result.$2);
  return true;
}

class _AllowanceDialog extends StatefulWidget {
  const _AllowanceDialog({this.amount, required this.daily});
  final double? amount;
  final bool daily;

  @override
  State<_AllowanceDialog> createState() => _AllowanceDialogState();
}

class _AllowanceDialogState extends State<_AllowanceDialog> {
  late final _amount = TextEditingController(text: widget.amount?.toStringAsFixed(2) ?? '');
  late bool _daily = widget.daily;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
    if (v <= 0) {
      Feel.oops();
      setState(() => _error = tr('How much do you get?', '你能拿到多少？'));
      return;
    }
    Navigator.of(context).pop((v, _daily));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Pocket money', '零花钱')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('allowance-amount'),
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(prefixText: r'S$ ', hintText: '80.00', errorText: _error),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(tr('Per week', '每周'))),
            ButtonSegment(value: true, label: Text(tr('Per day', '每天'))),
          ],
          selected: {_daily},
          onSelectionChanged: (s) => setState(() => _daily = s.first),
        ),
      ],
    ),
    actions: [
      if (widget.amount != null)
        TextButton(onPressed: () => Navigator.of(context).pop((null, false)), child: Text(tr('Remove', '移除'))),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Cancel', '取消'))),
      FilledButton(key: const Key('allowance-save'), onPressed: _save, child: Text(tr('Save', '保存'))),
    ],
  );
}
