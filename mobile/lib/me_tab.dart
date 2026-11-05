import 'package:flutter/material.dart';

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'remind.dart';
import 'theme.dart';

/// The Me tab (IMG_6780): the cat's name, four quick switches,
/// preferences and more.
class MeTab extends StatefulWidget {
  const MeTab({
    super.key,
    required this.onSettings,
    required this.onThemeChanged,
    this.onLanguageChanged,
  });

  /// Opens the full settings: reminders, pocket money, backup and restore.
  final VoidCallback onSettings;
  final VoidCallback onThemeChanged;

  /// Called after the language changes, to reword the reminders.
  final VoidCallback? onLanguageChanged;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  Prefs get _p => Prefs.current;

  List<String> get _chatty => zh
      ? const ['安静', '偶尔', '经常']
      : const ['Quiet', 'Sometimes', 'Often'];

  String get _themeLabel => switch (_p.themeMode) {
    'light' => tr('Light', '白色'),
    'dark' => tr('Dark', '深色'),
    _ => tr('Same as phone', '跟随系统'),
  };

  String get _on => tr('On', '开');
  String get _off => tr('Off', '关');

  Future<void> _pickLanguage() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, label) in [('en', 'English'), ('zh', '中文')])
              ListTile(
                key: Key('lang-$k'),
                title: Text(label),
                trailing: (zh ? 'zh' : 'en') == k
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(k),
              ),
          ],
        ),
      ),
    );
    if (v == null || v == (zh ? 'zh' : 'en')) return;
    await _p.setLanguage(v);
    widget.onThemeChanged();
    widget.onLanguageChanged?.call();
    Remind.syncCheckIns(DayStore.current);
    redrawAll();
  }

  Future<void> _pickTheme() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, label) in [
              ('system', tr('Same as phone', '跟随系统')),
              ('light', tr('Light', '白色')),
              ('dark', tr('Dark', '深色')),
            ])
              ListTile(
                title: Text(label),
                trailing: (_p.themeMode ?? 'system') == k
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(k),
              ),
          ],
        ),
      ),
    );
    if (v == null) return;
    await _p.setThemeMode(v == 'system' ? null : v);
    widget.onThemeChanged();
    setState(() {});
  }

  Future<void> _editCat() async {
    await showCompanion(context);
    setState(() {});
  }

  /// A short list of choices for one of the four quick tiles.
  Future<int?> _pick(String title, List<String> options, int current) =>
      showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final (i, label) in options.indexed)
                ListTile(
                  key: Key('pick-$i'),
                  title: Text(label),
                  trailing: i == current ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(ctx).pop(i),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      key: const Key('me-list'),
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 32),
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The cat reading by the window, bleeding off the right edge.
              Positioned(
                right: -16,
                top: -top - 8,
                child: SceneArt(
                  kind: SceneKind.reading,
                  width: 210,
                  height: top + 158,
                ),
              ),
              Positioned(
                left: 0,
                top: 10,
                right: 150,
                child: InkWell(
                  key: const Key('edit-cat'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: _editCat,
                  child: Row(
                    children: [
                      const CatAvatar(size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _p.catName,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            Text(
                              tr('Plan life slowly, together', '一起把生活慢慢安排好'),
                              style: t.bodySmall?.copyWith(
                                color: Palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Tile(
                key: const Key('tile-notify'),
                icon: Icons.notifications_none,
                bg: Palette.mint,
                fg: const Color(0xFF5E9B63),
                label: tr('Reminders', '系统通知'),
                value: _p.reminderOn ? _on : _off,
                onTap: widget.onSettings,
              ),
              _Tile(
                key: const Key('tile-chatty'),
                icon: Icons.favorite_border,
                bg: Palette.rose,
                fg: const Color(0xFFD9686B),
                label: tr('Chattiness', '主动程度'),
                value: _chatty[_p.chatty],
                onTap: () async {
                  final v = await _pick(
                    tr('Chattiness', '主动程度'),
                    _chatty,
                    _p.chatty,
                  );
                  if (v == null) return;
                  await _p.setChatty(v);
                  Feel.tap();
                  // More hellos from the cat need permission to notify.
                  if (v > 0) await Remind.ask();
                  Remind.syncCheckIns(DayStore.current);
                  setState(() {});
                },
              ),
              _Tile(
                key: const Key('tile-quiet'),
                icon: Icons.schedule,
                bg: Palette.peach,
                fg: const Color(0xFFD08A4A),
                label: tr('Quiet mode', '安静模式'),
                value: _p.quiet ? _on : _off,
                onTap: () async {
                  final v = await _pick(
                    tr('Quiet mode', '安静模式'),
                    [_on, _off],
                    _p.quiet ? 0 : 1,
                  );
                  if (v == null) return;
                  await _p.setQuiet(v == 0);
                  Remind.syncCheckIns(DayStore.current);
                  setState(() {});
                },
              ),
              _Tile(
                key: const Key('tile-sound'),
                icon: Icons.bolt_outlined,
                bg: Palette.sky,
                fg: const Color(0xFF5C8FC7),
                label: tr('Sounds', '通知声音'),
                value: Feel.soundOn ? _on : _off,
                onTap: () async {
                  final v = await _pick(
                    tr('Sounds', '通知声音'),
                    [_on, _off],
                    Feel.soundOn ? 0 : 1,
                  );
                  if (v == null) return;
                  await Feel.setSoundOn(v == 0);
                  if (Feel.soundOn) Feel.play(Sound.tap);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: tr('My preferences', '我的偏好'),
          rows: [
            _Row(
              icon: Icons.palette_outlined,
              bg: Palette.peach,
              label: tr('Theme', '主题'),
              value: _themeLabel,
              onTap: _pickTheme,
            ),
            _Row(
              icon: Icons.menu_book_outlined,
              bg: Palette.mint,
              key: const Key('row-language'),
              label: tr('Language', '语言'),
              value: zh ? '中文' : 'English',
              onTap: _pickLanguage,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: tr('More', '更多功能'),
          rows: [
            _Row(
              icon: Icons.person_outline,
              bg: Palette.peach,
              key: const Key('row-account'),
              label: tr('Account & security', '账号与安全'),
              onTap: () =>
                  showTinySheet<void>(context, (_) => const _PrivacySheet()),
            ),
            _Row(
              key: const Key('row-data'),
              icon: Icons.cloud_outlined,
              bg: Palette.mint,
              label: tr('Data, backup and reminders', '数据与备份'),
              onTap: widget.onSettings,
            ),
            _Row(
              icon: Icons.help_outline,
              bg: Palette.rose,
              label: tr('Help and feedback', '帮助与反馈'),
              onTap: () =>
                  showTinySheet<void>(context, (_) => const _HelpSheet()),
            ),
            _Row(
              icon: Icons.info_outline,
              bg: Palette.sky,
              label: tr('About us', '关于我们'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Tiny Habits Cat',
                applicationVersion: '0.2.0',
                applicationLegalese: tr(
                  'By Shenetic. Everything stays on your phone.',
                  '由 Shenetic 制作。所有数据都留在你的手机上。',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final Color bg, fg;
  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(height: 8),
              // The state is read out and shown when tapped, as in the
              // wireframe, which shows only the name.
              Text(label, style: t.labelMedium?.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 50, color: Palette.line),
          r,
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.bg,
    required this.label,
    this.value,
    required this.onTap,
  });
  final IconData icon;
  final Color bg;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.only(left: 0, right: 8),
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: Palette.ink.withValues(alpha: 0.6)),
    ),
    title: Text(label, style: const TextStyle(fontSize: 17)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(
            value!,
            style: const TextStyle(color: Palette.muted, fontSize: 15),
          ),
        const SizedBox(width: 6),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: Palette.muted.withValues(alpha: 0.7),
          size: 12,
        ),
      ],
    ),
    onTap: () {
      Feel.tap();
      onTap();
    },
  );
}

/// Opens Your companion as the floating card from IMG_6781.
Future<void> showCompanion(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 18),
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: const CompanionSheet(),
  ),
);

/// Your companion (IMG_6781): the cat's picture and name.
class CompanionSheet extends StatefulWidget {
  const CompanionSheet({super.key});

  @override
  State<CompanionSheet> createState() => _CompanionSheetState();
}

class _CompanionSheetState extends State<CompanionSheet> {
  late final _name = TextEditingController(text: Prefs.current.catName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        SheetHeader(
          title: tr('Your companion', '你的伙伴'),
          action: tr('Save', '保存'),
          onAction: () async {
            await Prefs.current.setCatName(_name.text);
            Remind.syncCheckIns(DayStore.current);
            Feel.logged();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 18),
        const CatAvatar(size: 84),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: TextField(
            key: const Key('cat-name'),
            controller: _name,
            maxLength: 20,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Palette.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFE2DCD1)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PrivacySheet extends StatefulWidget {
  const _PrivacySheet();

  @override
  State<_PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<_PrivacySheet> {
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(title: tr('Account & security', '账号与安全')),
        SwitchListTile.adaptive(
          key: const Key('chat-on'),
          title: Text(tr('Chat with the cat', '和小猫聊天')),
          subtitle: Text(
            tr(
              'Replies are made on this phone. Turn off to stop the cat reading your day.',
              '回复在这台手机上生成。关掉后，小猫就不会读取你的一天。',
            ),
          ),
          value: Prefs.current.chatOn,
          onChanged: (v) async {
            await Prefs.current.setChatOn(v);
            setState(() {});
          },
        ),
        ListTile(
          leading: const Icon(Icons.visibility_off_outlined),
          title: Text(tr('Private tasks', '不公开的事')),
          subtitle: Text(
            tr(
              'Tasks marked Private are never read or shared by the cat.',
              '标为不公开的事，小猫不会读取，也不会分享。',
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(tr('Everything stays on your phone', '所有数据都留在手机上')),
          subtitle: Text(
            tr(
              'Tasks, moods, notes and expenses are never uploaded. Back them up from Data.',
              '任务、心情、笔记和账目都不会上传。可以在「数据」里备份。',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    final tips = [
      (
        tr('Add a task', '添加一件事'),
        tr(
          'Tap + on Home. Tap the time on the right to set when.',
          '在首页点 +。点右边的时间设定什么时候做。',
        ),
      ),
      (
        tr('Make a stack', '做成一叠'),
        tr(
          'Hold + to make a list of steps. Home shows only the next step.',
          '长按 + 做一串步骤。首页只显示下一步。',
        ),
      ),
      (
        tr('Keep it private', '不公开'),
        tr(
          'Turn on Private when adding a task, and the cat won’t read it.',
          '添加时打开「不公开」，小猫就不会读取。',
        ),
      ),
      (
        tr('Chat and Records', '聊天和记录'),
        tr(
          'Swipe in from the left edge for Chat, from the right for Focus, Timeline and Notes.',
          '从左边缘滑进来聊天，从右边缘滑进来是专注、时间轴和笔记。',
        ),
      ),
      (
        tr('Mood and calendar', '心情和日历'),
        tr(
          'The Dashboard shows each day: done tasks, mood and spending. Tap + on a day to plan it.',
          '看板展示每一天：完成的事、心情和花销。点某天的 + 就能安排那天。',
        ),
      ),
      (
        tr('Money', '记账'),
        tr(
          'Open Money on the Dashboard to snap receipts and see your month.',
          '在看板打开「记账」，拍小票、看本月花销。',
        ),
      ),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(title: tr('Help', '帮助')),
          for (final (title, body) in tips)
            ListTile(title: Text(title), subtitle: Text(body)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
