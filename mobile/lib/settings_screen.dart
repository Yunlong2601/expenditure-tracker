import 'package:flutter/material.dart';

import 'allowance.dart';
import 'feel.dart';
import 'format.dart';
import 'prefs.dart';
import 'remind.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onExport, this.onReminderChanged});

  final VoidCallback? onExport;

  /// Reschedules the evening reminder.
  final VoidCallback? onReminderChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _time(BuildContext context) {
    final at = Prefs.current.reminderAt;
    return TimeOfDay(hour: at ~/ 60, minute: at % 60).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              key: const Key('settings-allowance'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Pocket money'),
              subtitle: Text(
                Prefs.current.allowance == null
                    ? 'Not set'
                    : '${money(Prefs.current.allowance!, 'SGD')} ${Prefs.current.allowanceDaily ? 'a day' : 'a week'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Feel.tap();
                if (await editAllowance(context)) setState(() {});
              },
            ),
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
            SwitchListTile.adaptive(
              key: const Key('school-quiet'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet during school hours'),
              subtitle: const Text('Weekdays 7:30 am to 2:30 pm: no sounds, just a little buzz.'),
              value: Prefs.current.schoolQuiet,
              onChanged: (v) async {
                await Prefs.current.setSchoolQuiet(v);
                setState(() {});
              },
            ),
            SwitchListTile.adaptive(
              key: const Key('reminder'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Evening reminder'),
              subtitle: Text(
                'The cat asks at ${_time(context)} if you spent anything. '
                'Skipped on days you already logged.',
              ),
              value: Prefs.current.reminderOn,
              onChanged: (v) async {
                if (v && !await Remind.ask()) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Allow notifications for Spend Snap in iPhone Settings first.')),
                  );
                  return;
                }
                await Prefs.current.setReminder(on: v);
                widget.onReminderChanged?.call();
                setState(() {});
              },
            ),
            if (Prefs.current.reminderOn)
              ListTile(
                key: const Key('reminder-time'),
                contentPadding: const EdgeInsets.only(left: 16),
                leading: const Icon(Icons.schedule),
                title: Text('Remind me at ${_time(context)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final at = Prefs.current.reminderAt;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: at ~/ 60, minute: at % 60),
                  );
                  if (picked == null) return;
                  await Prefs.current.setReminder(on: true, at: picked.hour * 60 + picked.minute);
                  widget.onReminderChanged?.call();
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
