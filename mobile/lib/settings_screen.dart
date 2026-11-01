import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onExport});

  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Your data stays on this phone', style: t.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Receipts are read by your iPhone itself, even in flight mode. Expenses and receipt photos are '
              'saved only on this phone and included in your iPhone backup. Nothing is sent anywhere.',
              style: t.bodyMedium,
            ),
            if (onExport != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('export'),
                onPressed: onExport,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Copy all expenses as a spreadsheet (CSV)'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
