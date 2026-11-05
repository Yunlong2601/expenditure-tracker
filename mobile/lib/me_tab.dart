import 'package:flutter/material.dart';

import 'companion.dart';
import 'feel.dart';
import 'prefs.dart';
import 'theme.dart';

/// The Me tab (IMG_6780): the cat's name, four quick switches,
/// preferences and more.
class MeTab extends StatefulWidget {
  const MeTab({
    super.key,
    required this.onSettings,
    required this.onThemeChanged,
  });

  /// Opens the full settings: reminders, pocket money, backup and restore.
  final VoidCallback onSettings;
  final VoidCallback onThemeChanged;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  Prefs get _p => Prefs.current;

  void _say(String s) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
    );

  static const _chatty = ['Quiet', 'Sometimes', 'Often'];

  String get _themeLabel => switch (_p.themeMode) {
    'light' => 'Light',
    'dark' => 'Dark',
    _ => 'Same as phone',
  };

  Future<void> _pickTheme() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, label) in [
              ('system', 'Same as phone'),
              ('light', 'Light'),
              ('dark', 'Dark'),
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
    await showTinySheet<void>(context, (_) => const CompanionSheet());
    setState(() {});
  }

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
            children: [
              const Positioned(right: 0, top: 0, child: CatFigure(size: 140)),
              Positioned(
                left: 0,
                top: 10,
                right: 140,
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
                              'Plan life slowly, together',
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
                label: 'Reminders',
                value: _p.reminderOn ? 'On' : 'Off',
                onTap: widget.onSettings,
              ),
              _Tile(
                key: const Key('tile-chatty'),
                icon: Icons.favorite_border,
                bg: Palette.rose,
                fg: const Color(0xFFD9686B),
                label: 'Chattiness',
                value: _chatty[_p.chatty],
                onTap: () async {
                  await _p.setChatty((_p.chatty + 1) % 3);
                  Feel.tap();
                  setState(() {});
                },
              ),
              _Tile(
                key: const Key('tile-quiet'),
                icon: Icons.schedule,
                bg: Palette.peach,
                fg: const Color(0xFFD08A4A),
                label: 'Quiet mode',
                value: _p.quiet ? 'On' : 'Off',
                onTap: () async {
                  await _p.setQuiet(!_p.quiet);
                  setState(() {});
                },
              ),
              _Tile(
                key: const Key('tile-sound'),
                icon: Icons.bolt_outlined,
                bg: Palette.sky,
                fg: const Color(0xFF5C8FC7),
                label: 'Sounds',
                value: Feel.soundOn ? 'On' : 'Off',
                onTap: () async {
                  await Feel.setSoundOn(!Feel.soundOn);
                  if (Feel.soundOn) Feel.play(Sound.tap);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'My preferences',
          rows: [
            _Row(
              icon: Icons.palette_outlined,
              bg: Palette.peach,
              label: 'Theme',
              value: _themeLabel,
              onTap: _pickTheme,
            ),
            _Row(
              icon: Icons.menu_book_outlined,
              bg: Palette.mint,
              label: 'Language',
              value: 'English',
              onTap: () => _say('Chinese is coming soon.'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'More',
          rows: [
            _Row(
              icon: Icons.person_outline,
              bg: Palette.peach,
              label: 'Privacy',
              onTap: () =>
                  showTinySheet<void>(context, (_) => const _PrivacySheet()),
            ),
            _Row(
              key: const Key('row-data'),
              icon: Icons.cloud_outlined,
              bg: Palette.mint,
              label: 'Data, backup and reminders',
              onTap: widget.onSettings,
            ),
            _Row(
              icon: Icons.help_outline,
              bg: Palette.rose,
              label: 'Help and feedback',
              onTap: () =>
                  showTinySheet<void>(context, (_) => const _HelpSheet()),
            ),
            _Row(
              icon: Icons.info_outline,
              bg: Palette.sky,
              label: 'About',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Tiny Habits Cat',
                applicationVersion: '0.2.0',
                applicationLegalese:
                    'By Shenetic. Everything stays on your phone.',
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(height: 6),
              Text(label, style: t.labelMedium),
              Text(value, style: t.labelSmall?.copyWith(color: Palette.muted)),
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
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 52),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: Palette.ink.withValues(alpha: 0.65)),
    ),
    title: Text(label, style: const TextStyle(fontSize: 17)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(value!, style: const TextStyle(color: Palette.muted)),
        const Icon(Icons.chevron_right, color: Palette.muted, size: 20),
      ],
    ),
    onTap: () {
      Feel.tap();
      onTap();
    },
  );
}

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
        SheetHeader(
          title: 'Your companion',
          action: 'Save',
          onAction: () async {
            await Prefs.current.setCatName(_name.text);
            Feel.logged();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 12),
        const CatAvatar(size: 96),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: TextField(
            key: const Key('cat-name'),
            controller: _name,
            textAlign: TextAlign.center,
            maxLength: 20,
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
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
        const SheetHeader(title: 'Privacy'),
        SwitchListTile.adaptive(
          key: const Key('chat-on'),
          title: const Text('Chat with the cat'),
          subtitle: const Text(
            'Replies are made on this phone. Turn off to stop the cat reading your day.',
          ),
          value: Prefs.current.chatOn,
          onChanged: (v) async {
            await Prefs.current.setChatOn(v);
            setState(() {});
          },
        ),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Everything stays on your phone'),
          subtitle: Text(
            'Tasks, moods, notes and expenses are never uploaded. Back them up from Data.',
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
    const tips = [
      ('Add a task', 'Tap + on Home. Tap the time on the right to set when.'),
      (
        'Make a stack',
        'Hold + to make a list of steps. Home shows only the next step.',
      ),
      (
        'Chat and Records',
        'Swipe in from the left edge for Chat, from the right for Focus, Timeline and Notes.',
      ),
      (
        'Mood and calendar',
        'The Dashboard shows each day: done tasks, mood and spending.',
      ),
      (
        'Money',
        'Open Money on the Dashboard to snap receipts and see your month.',
      ),
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader(title: 'Help'),
          for (final (title, body) in tips)
            ListTile(title: Text(title), subtitle: Text(body)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
