import 'dart:math';

import 'package:flutter/material.dart';

import 'brain.dart';
import 'companion.dart';
import 'day.dart';
import 'feel.dart';
import 'home_tab.dart' show clock;
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'remind.dart';
import 'theme.dart';

/// Chat with the cat (IMG_6783 to 6788), opened by swiping in from the left
/// on Home. When the build has the online AI ([CatBrain]), replies come from
/// it; otherwise, or when it can't be reached, they're written on the phone
/// from what the app knows about the day. Spending never leaves the phone.
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

  /// Replies still on their way; shows the typing dots.
  int _waiting = 0;

  @override
  void initState() {
    super.initState();
    writeNotebook(_s);
    if (!chatAgreed) {
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
      await setChatAgreed(true);
      if (mounted) setState(() {});
    }
  }

  Future<void> _send([String? text]) async {
    final v = (text ?? _c.text).trim();
    if (v.isEmpty) return;
    if (!chatAgreed) return _askConsent();
    _c.clear();
    Feel.tap();
    final before = _s.chat.toList();
    await _s.add(_s.chat, v, kind: 'me');
    setState(() => _waiting++);
    final pause = Future<void>.delayed(const Duration(milliseconds: 450));
    final String reply;
    try {
      reply = await catAnswer(v, _s, before: before, spentToday: widget.spentToday);
      await pause;
    } finally {
      if (mounted) setState(() => _waiting--);
    }
    await _s.add(_s.chat, reply, kind: 'cat');
    Feel.play(Sound.mew);
    if (!mounted) return;
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
        title: Text(tr('Clear this chat?', '清空聊天记录？')),
        content: Text(tr('Memories and the notebook stay.', '宠物记忆和内心本会保留。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Clear', '清空')),
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
    final round = IconButton.styleFrom(
      backgroundColor: Theme.of(context).cardTheme.color,
      fixedSize: const Size(42, 42),
      side: const BorderSide(color: Palette.line),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 0,
        shape: const Border(bottom: BorderSide(color: Palette.line)),
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
                      tr('Online', '在线'),
                      style: t.bodySmall?.copyWith(color: Palette.muted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('chat-clear'),
            tooltip: tr('Clear chat', '清空聊天'),
            style: round,
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            key: const Key('chat-menu'),
            style: round,
            icon: const Icon(Icons.more_horiz),
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'checkins', child: Text(tr('Check-ins', '定时约定'))),
              PopupMenuItem(value: 'memory', child: Text(tr('What I remember', '宠物记忆'))),
              PopupMenuItem(value: 'notebook', child: Text(tr('My notebook', '内心本'))),
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
                    if (_waiting > 0) const _Typing(),
                    for (final e in lines)
                      _Bubble(text: e.text, mine: e.kind == 'me'),
                    _Bubble(
                      text: tr('Hi! You’re here~\nHow’s your day going?', '嗨！你来啦~\n今天过得怎么样？'),
                      mine: false,
                      link: tr('See what I can help with', '看看我能帮你做什么'),
                      onLink: () => _send(tr('What can you help with?', '你能帮我做什么？')),
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
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: tr('Share today’s list', '分享今天的清单'),
                          style: round,
                          icon: const Icon(Icons.add),
                          onPressed: () => _send(tr('Here’s my list for today', '这是我今天的清单')),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            key: const Key('chat-field'),
                            controller: _c,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: tr('Chat with me…', '和我聊聊吧…'),
                              filled: true,
                              fillColor: cs.onSurface.withValues(alpha: 0.04),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: _send,
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          tooltip: tr('Quick asks', '快捷提问'),
                          style: IconButton.styleFrom(
                            backgroundColor: cs.onSurface.withValues(alpha: 0.04),
                            fixedSize: const Size(42, 42),
                          ),
                          icon: const Icon(Icons.bolt_outlined),
                          onSelected: _send,
                          itemBuilder: (_) => [
                            for (final q in [
                              tr('Cheer me on', '给我打气'),
                              tr('What’s left today?', '今天还剩什么？'),
                              tr('Let’s review my day', '一起复盘今天吧'),
                            ])
                              PopupMenuItem(value: q, child: Text(q)),
                          ],
                        ),
                        // Soft green until there's something to send.
                        ValueListenableBuilder(
                          valueListenable: _c,
                          builder: (context, v, _) => IconButton.filled(
                            key: const Key('chat-send'),
                            tooltip: tr('Send', '发送'),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(46, 46),
                              backgroundColor: cs.primary.withValues(
                                alpha: v.text.trim().isEmpty ? 0.45 : 1,
                              ),
                            ),
                            onPressed: _send,
                            icon: const Icon(Icons.send_rounded, size: 20),
                          ),
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

/// The cat's typing dots while a reply is on its way.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Still dots when reduced motion is on.
    if (MediaQuery.disableAnimationsOf(context)) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) => AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final wave = (sin(_a.value * 2 * pi - i * 0.9) + 1) / 2;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: Palette.muted.withValues(alpha: 0.35 + 0.65 * wave),
            shape: BoxShape.circle,
          ),
        );
      },
    );
    return Semantics(
      liveRegion: true,
      label: tr('${Prefs.current.catName} is typing', '${Prefs.current.catName}正在输入'),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CatAvatar(size: 40),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [dot(0), dot(1), dot(2)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cat's reply: from the online AI when it's set up and answers,
/// otherwise made on the phone. Spending and "remember" stay on the phone.
/// [before] is the chat before this message.
Future<String> catAnswer(
  String said,
  DayStore s, {
  Iterable<Entry> before = const [],
  String Function()? spentToday,
  CatBrain? brain,
}) async {
  final b = brain ?? CatBrain.current;
  if (b != null && !staysOnPhone(said)) {
    final r = await b.ask(replyAsk(said, s, before));
    if (r != null) return r;
  }
  return catReply(said, s, spentToday: spentToday);
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
  bool has(List<String> words) => words.any(m.contains);
  final today = DateTime.now();
  // Private tasks are never read by the cat.
  final mine = s.tasksOn(today).where((t) => !t.private).toList();
  final left = mine.where((t) => !t.done).toList();
  final done = s.doneOn(today).where((t) => !t.private).length;
  String pick(List<String> o) => o[r.nextInt(o.length)];

  for (final start in rememberStarts) {
    if (m.startsWith(start)) {
      final what = said.substring(start.length).replaceFirst(RegExp(r'^[:：，,\s]+'), '').trim();
      s.memories.add(Entry(at: today, text: what));
      return tr(
        'Got it, I’ll remember: “$what”. You can see it under What I remember.',
        '记住啦：“$what”。在「宠物记忆」里可以看到。',
      );
    }
  }
  if (has(['help', '帮', '能做什么'])) {
    return tr(
      'I can tell you what’s left today, cheer you on, review your day with you, and remember small things. '
          'Start a message with “remember” and I’ll keep it.',
      '我可以告诉你今天还剩什么、给你打气、陪你复盘，还能记住小事。用“记住”开头说给我听，我就会记下来。',
    );
  }
  if (has(['left', 'list', 'todo', 'to-do', 'task', '还剩', '清单', '任务', '待办', '要做'])) {
    if (left.isEmpty) {
      return done == 0
          ? tr('Your list is empty. Want to add one small thing?', '清单还是空的，要不要加一件小事？')
          : tr('All done! $done things finished today.', '全部完成！今天做完了 $done 件事。');
    }
    final next = left.first;
    final name = next.topStep?.title ?? next.title;
    final at = next.minutes == null ? '' : clockText(next.minutes!);
    return tr(
      '${left.length} left. Next up: $name${at.isEmpty ? '' : ' at $at'}. You’ve got this.',
      '还剩 ${left.length} 件。下一件：$name${at.isEmpty ? '' : '（$at）'}。你可以的！',
    );
  }
  if (has(moneyWords)) {
    final v = spentToday?.call();
    return v == null
        ? tr('Open Money on the Dashboard to see it.', '在看板的「记账」里可以看到。')
        : tr('Today you spent $v.', '今天花了 $v。');
  }
  if (has(['review', '复盘', '回顾'])) {
    final mood = s.moodOf(today);
    final f = s.focusMinutesOn(today);
    return tr(
      'Today: $done done, ${left.length} still open, $f min of focus'
          '${mood == null ? '' : ', and you felt ${mood.label.toLowerCase()}'}. '
          '${done > 0 ? 'That’s real progress.' : 'Tomorrow is a fresh page.'}',
      '今天：完成 $done 件，还有 ${left.length} 件，专注 $f 分钟'
          '${mood == null ? '' : '，心情${mood.zh}'}。'
          '${done > 0 ? '这是实实在在的进步。' : '明天又是新的一页。'}',
    );
  }
  if (has(['tired', 'sad', 'anxious', 'stress', 'bad', '累', '难过', '焦虑', '压力', '烦', '不开心'])) {
    return pick([
      tr(
        'That sounds hard. Want to log it in your mood diary? Even a small rest counts as a task today.',
        '听起来好辛苦。要不要记进心情日记？今天休息一下也算完成一件事。',
      ),
      tr('I’m here. Maybe drink some water and pick just one tiny thing.', '我在呢。先喝口水，只挑一件很小的事做就好。'),
    ]);
  }
  if (has(['cheer', 'encourage', '鼓励', '加油', '打气'])) {
    return pick([
      tr('You’re doing better than you think!', '你比自己想的还要棒！'),
      tr('One step, then another. I’m right here.', '一步，再一步。我一直在这里。'),
      tr('Proud of you for showing up today.', '今天你也来了，为你骄傲。'),
    ]);
  }
  if (has(['happy', 'good', 'great', '开心', '不错', '棒', '好耶'])) {
    return pick([
      tr('Yay! That makes my tail swish.', '耶！我的尾巴都摇起来了。'),
      tr('Love that for you. Tell me more?', '真好呀，再多说一点？'),
    ]);
  }
  return pick([
    tr('Mm-hm, I’m listening.', '嗯嗯，我在听。'),
    tr('Tell me more?', '再多说一点？'),
    tr('Thanks for telling me. Anything you want to get done next?', '谢谢你告诉我。接下来想做点什么吗？'),
    tr('I’ll sit right here with you.', '我就在这里陪着你。'),
  ]);
}

/// "09:30" from minutes after midnight.
String clockText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Writes a short page for each past day of chat, once. With the online AI,
/// the cat writes the last few days itself; older days, and any page the AI
/// can't write, use the template.
Future<void> writeNotebook(DayStore s, {CatBrain? brain}) async {
  final b = brain ?? CatBrain.current;
  final today = dayOf(DateTime.now());
  final days = {for (final e in s.chat) dayOf(e.at)}
      .where((d) => d.isBefore(today))
      .toList()
    ..sort();
  var wrote = false;
  for (final d in days) {
    if (s.notebook.any((n) => sameDay(n.at, d))) continue;
    String? page;
    if (b != null && today.difference(d).inDays <= 3) {
      page = await b.ask(notebookAsk(s, d));
      // Another visit may have written it while we waited.
      if (s.notebook.any((n) => sameDay(n.at, d))) continue;
    }
    s.notebook.add(Entry(at: d, text: page ?? notebookPage(s, d)));
    wrote = true;
  }
  if (wrote) await s.save();
}

/// The template page for [d].
String notebookPage(DayStore s, DateTime d) {
  final talked = s.chat.where((e) => sameDay(e.at, d) && e.kind == 'me').length;
  final done = s.doneOn(d).where((t) => !t.private).length;
  final mood = s.moodOf(d);
  return zh
      ? '那天我们聊了 $talked 次。'
            '${done > 0 ? '你完成了 $done 件事。' : ''}'
            '${mood != null ? '你的心情是${mood.zh}。' : ''}'
            '你来找我，我很开心。'
      : '${talked == 1 ? 'We chatted once' : 'We chatted $talked times'} that day. '
            '${done > 0 ? 'You finished ${done == 1 ? 'one thing' : '$done things'}. ' : ''}'
            '${mood != null ? 'You felt ${mood.label.toLowerCase()}. ' : ''}'
            'I’m glad you came by.';
}

/// Before chatting (IMG_6783): what the cat uses and the promises. [online]
/// is true when replies come from the online AI, so the wording says what is
/// sent and where.
class ConsentSheet extends StatelessWidget {
  const ConsentSheet({super.key, this.online});
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ai = online ?? CatBrain.current != null;
    Widget row(IconData i, String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              shape: BoxShape.circle,
            ),
            child: Icon(i, size: 17, color: Palette.sage),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: t.bodyLarge)),
        ],
      ),
    );
    Widget check(String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Palette.sage),
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
            SheetHeader(title: tr('Before you chat with the cat', '和小猫聊天之前')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ai
                        ? tr(
                            'To reply, the cat sends these through our server to an AI service (Groq or DeepSeek):',
                            '为了回复你，小猫会经由我们的服务器，把这些发送给 AI 服务（Groq 或 DeepSeek）：',
                          )
                        : tr('The cat’s replies are made on this phone. To understand you, it looks at:', '小猫的回复在这台手机上生成。为了更懂你，它会参考：'),
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
                          tr('Your messages and recent chat', '你的消息和最近的聊天'),
                        ),
                        row(
                          Icons.favorite_border,
                          tr('Things the cat remembers about you', '小猫记住的关于你的事'),
                        ),
                        row(
                          Icons.assignment_outlined,
                          tr('Your public tasks, moods and focus for today', '你今天公开的任务、心情和专注'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ai) ...[
                    check(tr('Only these are sent. Spending and private tasks stay on your phone', '只发送上面这些。花销和不公开的事留在手机上')),
                    check(tr('AI can make mistakes. Don’t share passwords, your address or other private details', 'AI 也会出错。不要发送密码、住址等隐私信息')),
                    check(tr('If the AI can’t be reached, the cat answers on your phone', '连不上 AI 时，小猫会在手机上回复')),
                  ] else ...[
                    check(tr('Nothing leaves your phone', '数据不会离开你的手机')),
                    check(tr('Private tasks are never read', '不公开的事不会被读取')),
                  ],
                  check(tr('Tasks, focus and records work fine without chat', '不聊天也能正常使用任务、专注和记录')),
                  check(tr('You can turn it off any time in Me → Account & security', '随时可以在「我的 → 账号与安全」里关闭')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('consent-yes'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(tr('Agree and start chatting', '同意并开始聊天')),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        tr('Not now', '暂不开启'),
                        style: const TextStyle(color: Palette.muted),
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
            title: tr('Check-ins', '定时约定'),
            action: tr('Add', '新增'),
            onAction: () => _add(context, 0),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.sand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(tr('Pause check-ins', '暂停约定')),
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
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Palette.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tr('On this phone', '仅在本机'),
                        style: t.bodySmall?.copyWith(color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final (k, _) in CheckIn.kinds.indexed) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 64,
                    title: Text(CheckIn.label(k), style: t.titleMedium),
                    trailing: TextButton.icon(
                      key: Key('checkin-new-$k'),
                      onPressed: () => _add(context, k),
                      style: TextButton.styleFrom(
                        foregroundColor: Palette.muted,
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('New', '新建')),
                    ),
                  ),
                  for (final c in store.checkIns.where((c) => c.kind == k))
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 12),
                      leading: const Icon(Icons.notifications_none, size: 20),
                      title: Text(tr('Every day at ${clock(context, c.minutes)}', '每天 ${clock(context, c.minutes)}')),
                      trailing: IconButton(
                        tooltip: tr('Delete', '删除'),
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          await store.remove(store.checkIns, c);
                          Remind.syncCheckIns(store);
                        },
                      ),
                    ),
                  const Divider(height: 1, color: Palette.line),
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
        SnackBar(
          content: Text(
            tr(
              'Allow notifications for Tiny Habits Cat in iPhone Settings to get check-ins.',
              '在 iPhone 设置里允许 Tiny Habits Cat 发通知，才能收到定时约定。',
            ),
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
        title: Text(tr('Something to remember', '要记住的事')),
        content: TextField(
          key: const Key('memory-field'),
          controller: c,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('I like oat milk, my exam is in June…', '我喜欢燕麦奶，六月要考试……'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text),
            child: Text(tr('Save', '保存')),
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
              title: tr('What I remember', '宠物记忆'),
              action: tr('Add', '新增'),
              onAction: _add,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const CatAvatar(size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('The important things, I’ll keep', '重要的事，我会记着'),
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              tr('No need to say them again, and you can ask me to forget any time.', '不必每次重说，也可以随时让我忘记。'),
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
                      hintText: tr('Search memories', '搜索记忆'),
                      filled: true,
                      fillColor: Palette.sand,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      // How many memories, always shown, as in IMG_6787.
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          '${s.memories.length}',
                          style: t.bodySmall?.copyWith(color: Palette.muted),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (s.memories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Remember one small thing first?', '先记住一件小事?'),
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr('Tell me what you like, or tap “Add” in the top right.', '告诉我你的偏好，或者点右上角“新增”。'),
                            style: t.bodyMedium?.copyWith(color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
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
                        tooltip: tr('Forget', '忘掉'),
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
        SheetHeader(title: tr('My notebook', '内心本')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  // The whole cat, no frame, as in IMG_6788.
                  const SizedBox(
                    width: 58,
                    height: 58,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: CatPainter(star: true)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('What’s on $name’s mind', '$name 的心里话'),
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tr('A little at a time, as I think of it.', '想到一点，就写下一点。'),
                        style: t.bodySmall?.copyWith(color: Palette.muted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 64),
              if (pages.isEmpty) ...[
                const Icon(
                  Icons.favorite_border,
                  color: Palette.sage,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('The first page is still brewing', '第一段心里话，还在酝酿'),
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('Chat with me for a bit, and the next day I’ll write down the little things worth keeping.', '我们聊上几句，第二天我会把想留住的小事写在这里。'),
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
                          longDay(p.at),
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
