import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'home_tab.dart' show clock;
import 'prefs.dart';
import 'remind.dart';
import 'theme.dart';

/// Chat with the cat (IMG_6783 to 6788), opened by swiping in from the left
/// on Home. Replies are written on the phone from what the app knows about
/// her day; nothing is sent anywhere.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store, this.spentToday});
  final DayStore store;

  /// Today's spending as text, for "how much did I spend?".
  final String Function()? spentToday;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  DayStore get _s => widget.store;

  @override
  void initState() {
    super.initState();
    writeNotebook(_s);
    if (!Prefs.current.chatOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askConsent());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _askConsent() async {
    final yes = await showTinySheet<bool>(context, (_) => const ConsentSheet());
    if (yes == true) {
      await Prefs.current.setChatOn(true);
      if (mounted) setState(() {});
    }
  }

  Future<void> _send([String? text]) async {
    final v = (text ?? _c.text).trim();
    if (v.isEmpty) return;
    if (!Prefs.current.chatOn) return _askConsent();
    _c.clear();
    Feel.tap();
    await _s.add(_s.chat, v, kind: 'me');
    final reply = catReply(v, _s, spentToday: widget.spentToday);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _s.add(_s.chat, reply, kind: 'cat');
    Feel.play(Sound.mew);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _menu(String v) async {
    Feel.tap();
    final sheet = switch (v) {
      'checkins' => CheckInsSheet(store: _s),
      'memory' => MemorySheet(store: _s),
      _ => NotebookSheet(store: _s),
    };
    await showTinySheet<void>(context, (_) => sheet, tall: true);
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear this chat?'),
        content: const Text('Memories and the notebook stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    _s.chat.clear();
    await _s.save();
    Feel.removed();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = Prefs.current.catName;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CatAvatar(size: 44),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6DBB6A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online',
                      style: t.bodySmall?.copyWith(color: Palette.muted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            key: const Key('chat-clear'),
            tooltip: 'Clear chat',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
          PopupMenuButton<String>(
            key: const Key('chat-menu'),
            icon: const Icon(Icons.more_horiz),
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'checkins', child: Text('Check-ins')),
              PopupMenuItem(value: 'memory', child: Text('What I remember')),
              PopupMenuItem(value: 'notebook', child: Text('My notebook')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _s,
        builder: (context, _) {
          final lines = _s.chat.reversed.toList();
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  children: [
                    for (final e in lines)
                      _Bubble(text: e.text, mine: e.kind == 'me'),
                    _Bubble(
                      text: 'Hi! You’re here~\nHow’s your day going?',
                      mine: false,
                      link: 'See what I can help with',
                      onLink: () => _send('What can you help with?'),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Share today’s list',
                          icon: const Icon(Icons.add),
                          onPressed: () => _send('Here’s my list for today'),
                        ),
                        Expanded(
                          child: TextField(
                            key: const Key('chat-field'),
                            controller: _c,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Chat with me…',
                              border: InputBorder.none,
                            ),
                            onSubmitted: _send,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Quick asks',
                          icon: const Icon(Icons.bolt_outlined),
                          onSelected: _send,
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'Cheer me on',
                              child: Text('Cheer me on'),
                            ),
                            PopupMenuItem(
                              value: 'What’s left today?',
                              child: Text('What’s left today?'),
                            ),
                            PopupMenuItem(
                              value: 'Let’s review my day',
                              child: Text('Let’s review my day'),
                            ),
                          ],
                        ),
                        IconButton.filled(
                          key: const Key('chat-send'),
                          tooltip: 'Send',
                          style: IconButton.styleFrom(
                            backgroundColor: cs.primary.withValues(alpha: 0.75),
                          ),
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.mine,
    this.link,
    this.onLink,
  });
  final String text;
  final bool mine;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.68,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: mine
            ? cs.primary.withValues(alpha: 0.14)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: mine
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.bodyLarge?.copyWith(height: 1.4)),
          if (link != null)
            GestureDetector(
              onTap: onLink,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$link ›',
                  style: t.bodyMedium?.copyWith(color: cs.primary),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[const CatAvatar(size: 40), const SizedBox(width: 8)],
          bubble,
        ],
      ),
    );
  }
}

/// The cat's reply, made on the phone from what the app knows.
String catReply(
  String said,
  DayStore s, {
  String Function()? spentToday,
  Random? random,
}) {
  final r = random ?? Random();
  final m = said.toLowerCase();
  final today = DateTime.now();
  final left = s.tasksOn(today).where((t) => !t.done).toList();
  final done = s.doneOn(today).length;
  String pick(List<String> o) => o[r.nextInt(o.length)];

  if (m.startsWith('remember ')) {
    final what = said.substring(9).trim();
    s.memories.add(Entry(at: today, text: what));
    return 'Got it, I’ll remember: “$what”. You can see it under What I remember.';
  }
  if (m.contains('help')) {
    return 'I can tell you what’s left today, cheer you on, review your day with you, and remember small things. '
        'Start a message with “remember” and I’ll keep it.';
  }
  if (m.contains('left') ||
      m.contains('list') ||
      m.contains('todo') ||
      m.contains('to-do') ||
      m.contains('task')) {
    if (left.isEmpty) {
      return done == 0
          ? 'Your list is empty. Want to add one small thing?'
          : 'All done! $done things finished today.';
    }
    final next = left.first;
    final at = next.minutes == null
        ? ''
        : ' at ${DateFormat('HH:mm').format(DateTime(0, 1, 1, 0, next.minutes!))}';
    return '${left.length} left. Next up: ${next.topStep?.title ?? next.title}$at. You’ve got this.';
  }
  if (m.contains('spend') || m.contains('spent') || m.contains('money')) {
    final v = spentToday?.call();
    return v == null
        ? 'Open Money on the Dashboard to see it.'
        : 'Today you spent $v.';
  }
  if (m.contains('review')) {
    final mood = s.moodOf(today);
    final f = s.focusMinutesOn(today);
    return 'Today: $done done, ${left.length} still open, $f min of focus'
        '${mood == null ? '' : ', and you felt ${mood.label.toLowerCase()}'}. '
        '${done > 0 ? 'That’s real progress.' : 'Tomorrow is a fresh page.'}';
  }
  if (m.contains('tired') ||
      m.contains('sad') ||
      m.contains('anxious') ||
      m.contains('stress') ||
      m.contains('bad')) {
    return pick([
      'That sounds hard. Want to log it in your mood diary? Even a small rest counts as a task today.',
      'I’m here. Maybe drink some water and pick just one tiny thing.',
    ]);
  }
  if (m.contains('cheer') || m.contains('encourage')) {
    return pick([
      'You’re doing better than you think!',
      'One step, then another. I’m right here.',
      'Proud of you for showing up today.',
    ]);
  }
  if (m.contains('happy') || m.contains('good') || m.contains('great')) {
    return pick([
      'Yay! That makes my tail swish.',
      'Love that for you. Tell me more?',
    ]);
  }
  return pick([
    'Mm-hm, I’m listening.',
    'Tell me more?',
    'Thanks for telling me. Anything you want to get done next?',
    'I’ll sit right here with you.',
  ]);
}

/// Writes a short page for each past day she chatted, once.
void writeNotebook(DayStore s) {
  final today = dayOf(DateTime.now());
  final days = {for (final e in s.chat) dayOf(e.at)}
      .where((d) => d.isBefore(today));
  var wrote = false;
  for (final d in days) {
    if (s.notebook.any((n) => sameDay(n.at, d))) continue;
    final talked = s.chat
        .where((e) => sameDay(e.at, d) && e.kind == 'me')
        .length;
    final done = s.doneOn(d).length;
    final mood = s.moodOf(d);
    s.notebook.add(
      Entry(
        at: d,
        text:
            '${talked == 1 ? 'We chatted once' : 'We chatted $talked times'} that day. '
            '${done > 0 ? 'You finished ${done == 1 ? 'one thing' : '$done things'}. ' : ''}'
            '${mood != null ? 'You felt ${mood.label.toLowerCase()}. ' : ''}'
            'I’m glad you came by.',
      ),
    );
    wrote = true;
  }
  if (wrote) s.save();
}

/// Before chatting (IMG_6783): what the cat uses and the promises.
class ConsentSheet extends StatelessWidget {
  const ConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget row(IconData i, String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(i, size: 20, color: Palette.sage),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: t.bodyLarge)),
        ],
      ),
    );
    Widget check(String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Palette.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(s, style: t.bodyMedium)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(title: 'Before you chat'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The cat’s replies are made on this phone. To understand you, it looks at:',
                    style: t.bodyLarge?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.sand,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        row(
                          Icons.chat_bubble_outline,
                          'Your messages and recent chat',
                        ),
                        row(
                          Icons.favorite_border,
                          'Things the cat remembers about you',
                        ),
                        row(
                          Icons.assignment_outlined,
                          'Your tasks, moods and focus for today',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  check('Nothing leaves your phone'),
                  check('Tasks, focus and records work fine without chat'),
                  check('You can turn it off any time in Me → Privacy'),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('consent-yes'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Agree and start chatting'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Not now',
                        style: TextStyle(color: Palette.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Check-ins (IMG_6786): pause switch and three kinds, each with a time.
class CheckInsSheet extends StatelessWidget {
  const CheckInsSheet({super.key, required this.store});
  final DayStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Column(
        children: [
          SheetHeader(
            title: 'Check-ins',
            action: 'New',
            onAction: () => _add(context, 0),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.sand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('Pause check-ins'),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        key: const Key('pause-checkins'),
                        value: store.checkInsPaused,
                        onChanged: (v) {
                          store.checkInsPaused = v;
                          store.save();
                          Remind.syncCheckIns(store);
                        },
                      ),
                      const Spacer(),
                      Text(
                        'On this phone',
                        style: t.bodySmall?.copyWith(color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final (k, label) in CheckIn.kinds.indexed) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label, style: t.titleMedium),
                    trailing: TextButton.icon(
                      key: Key('checkin-new-$k'),
                      onPressed: () => _add(context, k),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ),
                  for (final c in store.checkIns.where((c) => c.kind == k))
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 12),
                      leading: const Icon(Icons.notifications_none, size: 20),
                      title: Text('Every day at ${clock(context, c.minutes)}'),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await store.remove(store.checkIns, c);
                          Remind.syncCheckIns(store);
                        },
                      ),
                    ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, int kind) async {
    final p = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (p == null) return;
    store.checkIns.add(CheckIn(kind: kind, minutes: p.hour * 60 + p.minute));
    await store.save();
    Feel.logged();
    final allowed = await Remind.ask();
    await Remind.syncCheckIns(store);
    if (!allowed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow notifications for Tiny Habits Cat in iPhone Settings to get check-ins.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// What I remember (IMG_6787): a search box and the cat's memories.
class MemorySheet extends StatefulWidget {
  const MemorySheet({super.key, required this.store});
  final DayStore store;

  @override
  State<MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<MemorySheet> {
  var _q = '';

  Future<void> _add() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Something to remember'),
        content: TextField(
          key: const Key('memory-field'),
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'I like oat milk, my exam is in June…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    await widget.store.add(widget.store.memories, v.trim());
    Feel.logged();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.memories
            .where((m) => m.text.toLowerCase().contains(_q.toLowerCase()))
            .toList();
        return Column(
          children: [
            SheetHeader(
              title: 'What I remember',
              action: 'New',
              onAction: _add,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Row(
                    children: [
                      const CatAvatar(size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The important things, I’ll keep',
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'You don’t need to repeat them. Ask me to forget any time.',
                              style: t.bodySmall?.copyWith(
                                color: Palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Search memories',
                      filled: true,
                      fillColor: Palette.sand,
                      suffixText: '${s.memories.length}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (s.memories.isEmpty) ...[
                    Text(
                      'Start with one small thing?',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell me what you like, or tap New in the top right.',
                      style: t.bodyMedium?.copyWith(color: Palette.muted),
                    ),
                  ],
                  for (final m in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.favorite,
                        color: Color(0xFFF2A7A7),
                        size: 18,
                      ),
                      title: Text(m.text),
                      trailing: IconButton(
                        tooltip: 'Forget',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => s.remove(s.memories, m),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// My notebook (IMG_6788): what the cat wrote the day after you chatted.
class NotebookSheet extends StatelessWidget {
  const NotebookSheet({super.key, required this.store});
  final DayStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = Prefs.current.catName;
    final pages = store.notebook.reversed.toList();
    return Column(
      children: [
        const SheetHeader(title: 'My notebook'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              Row(
                children: [
                  const CatAvatar(size: 52),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name’s little notes',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'A bit at a time, as I think of things.',
                        style: t.bodySmall?.copyWith(color: Palette.muted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              if (pages.isEmpty) ...[
                const Icon(
                  Icons.favorite_border,
                  color: Palette.sage,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  'The first page is still brewing',
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chat with me for a bit, and the next day I’ll write down the little things worth keeping.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    color: Palette.muted,
                    height: 1.5,
                  ),
                ),
              ],
              for (final p in pages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMM').format(p.at),
                          style: t.labelLarge?.copyWith(color: Palette.sage),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.text,
                          style: t.bodyLarge?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
