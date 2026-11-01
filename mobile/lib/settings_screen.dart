import 'package:flutter/material.dart';

import 'feel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onExport});

  final VoidCallback? onExport;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SwitchListTile.adaptive(
              key: const Key('sounds'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Sounds'),
              subtitle: const Text('A soft click and chime when you log. The silent switch mutes them.'),
              value: Feel.soundOn,
              onChanged: (v) async {
                await Feel.setSoundOn(v);
                if (v) Feel.play(Sound.tap);
                setState(() {});
              },
            ),
            const Divider(height: 32),
            Text('Your data stays on this phone', style: t.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Receipts are read by your iPhone itself, even in flight mode. Expenses and receipt photos are '
              'saved only on this phone and included in your iPhone backup. Nothing is sent anywhere.',
              style: t.bodyMedium,
            ),
            if (widget.onExport != null) ...[
              const SizedBox(height: 24),
              Pressable(
                scale: 0.96,
                child: OutlinedButton.icon(
                  key: const Key('export'),
                  onPressed: () {
                    Feel.tap();
                    widget.onExport!();
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Copy all expenses as a spreadsheet (CSV)'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
