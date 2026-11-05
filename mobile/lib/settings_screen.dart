import 'dart:convert';

import 'package:flutter/material.dart';

import 'allowance.dart';
import 'day.dart';
import 'feel.dart';
import 'format.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'ledger.dart';
import 'remind.dart';
import 'share.dart';
import 'summary.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.ledger, this.onExport, this.onReminderChanged});

  /// For the summary picture, backups and restores. Hidden when null.
  final Ledger? ledger;
  final VoidCallback? onExport;

  /// Reschedules the evening reminder.
  final VoidCallback? onReminderChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> _backup() async {
    Feel.tap();
    final data = await widget.ledger!.backup();
    data['prefs'] = Prefs.current.toJson();
    data['day'] = DayStore.current.toJson();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final ok = await Share.bytes(utf8.encode(jsonEncode(data)), 'TinyHabitsCat-backup-$day.json');
    if (ok && mounted) _say(tr('Backed up. Keep that file somewhere safe.', '备份好了。把这个文件放在安全的地方。'));
  }

  Future<void> _restore() async {
    Feel.tap();
    final data = await Share.pickJson();
    if (!mounted || data == null) return;
    final n = Ledger.backupSize(data);
    if (n == null) {
      Feel.oops();
      return _say(tr("That file isn't a Tiny Habits Cat backup.", '这不是 Tiny Habits Cat 的备份文件。'));
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Restore this backup?', '恢复这个备份？')),
        content: Text(tr('It has $n expenses. Everything on this phone now will be replaced by it.', '里面有 $n 笔账。手机上现在的所有数据都会被它替换。')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Cancel', '取消'))),
          FilledButton(
            key: const Key('restore-yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Restore', '恢复')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await widget.ledger!.restore(data);
    final prefs = data['prefs'];
    if (prefs is Map) await Prefs.current.restore(prefs.cast<String, Object?>());
    final day = data['day'];
    if (day is Map) await DayStore.current.restore(day.cast<String, dynamic>());
    widget.onReminderChanged?.call();
    Feel.logged();
    if (!mounted) return;
    setState(() {});
    _say(tr('Restored $n expenses.', '已恢复 $n 笔账。'));
  }

  String _time(BuildContext context) {
    final at = Prefs.current.reminderAt;
    return TimeOfDay(hour: at ~/ 60, minute: at % 60).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings', '设置'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ListTile(
              key: const Key('settings-allowance'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.savings_outlined),
              title: Text(tr('Pocket money', '零花钱')),
              subtitle: Text(
                Prefs.current.allowance == null
                    ? tr('Not set', '未设置')
                    : zh
                        ? '${Prefs.current.allowanceDaily ? '每天' : '每周'} ${money(Prefs.current.allowance!, 'SGD')}'
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
              title: Text(tr('Sounds', '通知声音')),
              subtitle: Text(tr('A soft click and chime when you log. The silent switch mutes them.', '记账时有轻轻的提示音。静音键可以关掉。')),
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
              title: Text(tr('Quiet during school hours', '上课时间保持安静')),
              subtitle: Text(tr('Weekdays 7:30 am to 2:30 pm: no sounds, just a little buzz.', '工作日早上 7:30 到下午 2:30：不出声，只轻轻震动。')),
              value: Prefs.current.schoolQuiet,
              onChanged: (v) async {
                await Prefs.current.setSchoolQuiet(v);
                setState(() {});
              },
            ),
            SwitchListTile.adaptive(
              key: const Key('reminder'),
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Evening reminder', '晚间提醒')),
              subtitle: Text(
                tr(
                  'The cat asks at ${_time(context)} if you spent anything. '
                      'Skipped on days you already logged.',
                  '小猫会在 ${_time(context)} 问你今天花钱了没有。当天已经记过账就不打扰。',
                ),
              ),
              value: Prefs.current.reminderOn,
              onChanged: (v) async {
                if (v && !await Remind.ask()) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('Allow notifications for Tiny Habits Cat in iPhone Settings first.', '请先在 iPhone 设置里允许 Tiny Habits Cat 发通知。'))),
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
                title: Text(tr('Remind me at ${_time(context)}', '每天 ${_time(context)} 提醒我')),
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
            Text(tr('Your data stays on this phone', '你的数据只在这台手机上'), style: t.titleMedium),
            const SizedBox(height: 8),
            Text(
              tr(
                'Receipts are read by your iPhone itself, even in flight mode. Expenses and receipt photos are '
                    'saved only on this phone and included in your iPhone backup. Nothing is sent anywhere.',
                '小票由 iPhone 自己识别，飞行模式也能用。账目和小票照片只存在这台手机上，并包含在 iPhone 备份里。不会发送到任何地方。',
              ),
              style: t.bodyMedium,
            ),
            if (widget.ledger != null) ...[
              const SizedBox(height: 24),
              Pressable(
                scale: 0.96,
                child: FilledButton.icon(
                  key: const Key('summary'),
                  onPressed: () {
                    Feel.tap();
                    Navigator.of(context)
                        .push<void>(MaterialPageRoute(builder: (_) => SummaryScreen(ledger: widget.ledger!)));
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(tr('My month as a picture', '把本月做成一张图')),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('backup'),
                      onPressed: _backup,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(tr('Back up', '备份')),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('restore'),
                      onPressed: _restore,
                      icon: const Icon(Icons.restore),
                      label: Text(tr('Restore', '恢复')),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  'Back up saves one file with everything, photos included. Keep it in Files or iCloud Drive, '
                      'or send it to yourself. Restore puts it back on a new phone.',
                  '备份会把所有内容（包括照片）存成一个文件。放在「文件」或 iCloud 云盘里，或者发给自己。换新手机时用恢复导回来。',
                ),
                style: t.bodySmall,
              ),
            ],
            if (widget.onExport != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('export'),
                  onPressed: () {
                    Feel.tap();
                    widget.onExport!();
                  },
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: Text(tr('Copy as a spreadsheet (CSV)', '复制为表格（CSV）')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
