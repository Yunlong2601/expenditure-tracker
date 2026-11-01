import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'draft.dart';
import 'feel.dart';
import 'format.dart';
import 'reader.dart';

/// Shown only when the receipt couldn't be read with confidence. Everything
/// that was read is already filled in.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.receipt,
    this.image,
    this.message,
    this.categories = const [],
    this.title = 'Quick check',
  });

  final ReadReceipt receipt;

  /// The receipt photo, when there is one to show.
  final Uint8List? image;
  final String? message;
  final List<String> categories;
  final String title;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late final ReadReceipt r = widget.receipt;
  late final _total = TextEditingController(text: r.total?.toStringAsFixed(2) ?? '');
  late final _merchant = TextEditingController(text: r.merchant ?? '');
  late final _category = TextEditingController(text: r.category ?? '');
  late final String _scanned = (r.currency ?? 'SGD').toUpperCase();
  late String _currency = _scanned;
  late DateTime _date = r.date ?? DateTime.now();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _total.dispose();
    _merchant.dispose();
    _category.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) {
      Feel.oops();
      return;
    }
    Navigator.of(context).pop(
      ExpenseDraft(
        amount: double.parse(_total.text.replaceAll(',', '').trim()),
        currency: _currency,
        date: _date,
        merchant: _merchant.text.trim(),
        category: _category.text.trim(),
        paymentMethod: r.paymentMethod,
        summary: r.summary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final choices = {...currencies, _scanned, _currency}.toList();
    final cats = {...widget.categories, 'Food & drink', 'Transport', 'Groceries', 'Shopping', 'Bills'}.toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(widget.title, style: t.titleLarge),
            if (widget.message != null) ...[const SizedBox(height: 4), Text(widget.message!, style: t.bodyMedium)],
            const SizedBox(height: 12),
            if (widget.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  widget.image!,
                  height: 160,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: const Key('review-total'),
                    controller: _total,
                    autofocus: r.total == null,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: t.headlineSmall,
                    decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                    validator: (v) =>
                        (double.tryParse((v ?? '').replaceAll(',', '')) ?? 0) > 0 ? null : 'Enter the amount',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: [for (final c in choices) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _currency = v ?? _currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _merchant,
              decoration: const InputDecoration(labelText: 'Shop', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _category.text),
              optionsBuilder: (v) => cats.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _category.text = v,
              fieldViewBuilder: (context, controller, focus, _) => TextFormField(
                controller: controller,
                focusNode: focus,
                onChanged: (v) => _category.text = v,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.event),
              label: Text(shortDate(_date)),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 20),
            Pressable(
              scale: 0.97,
              child: FilledButton(
                key: const Key('review-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: const Text('Save', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
