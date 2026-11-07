import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'allowance.dart';
import 'app.dart';
import 'categories.dart';
import 'draft.dart';
import 'feel.dart';
import 'format.dart';
import 'goal.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'ledger.dart';
import 'picker.dart';
import 'prefs.dart';
import 'quick_add_sheet.dart';
import 'reader.dart';
import 'remind.dart';
import 'split.dart';
import 'summary.dart';
import 'review_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.ledger, required this.reader, this.picker});

  final Ledger ledger;

  /// Reads receipts on the phone. When it can't, the person types the amount.
  final ReceiptReader reader;
  final ReceiptPicker? picker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReceiptPicker _picker = widget.picker ?? DevicePicker();
  bool _busy = false;

  /// The expense just logged, so its row can slide in.
  Object? _fresh;
  String _busyText = '';

  Ledger get _ledger => widget.ledger;

  void _toast(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action, behavior: SnackBarBehavior.floating));
  }

  String _describe(Expense e) => zh
      ? '${e.moneyIn ? '收入 ' : ''}${money(e.amount, e.currency)}${e.merchant != null ? '（${e.merchant}）' : ''}'
            '${e.category != null ? ' · ${catLabel(e.category!)}' : ''}'
      : '${e.moneyIn ? 'got ' : ''}${money(e.amount, e.currency)}${e.merchant != null ? ' at ${e.merchant}' : ''}'
            '${e.category != null ? ' (${e.category})' : ''}';

  Future<void> _save(ExpenseDraft d, {Uint8List? image}) async {
    var e = await _ledger.add(
      amount: d.amount,
      currency: d.currency,
      date: d.date,
      merchant: d.merchant,
      category: d.category,
      paymentMethod: d.paymentMethod,
      summary: d.summary,
      receipt: image,
      moneyIn: d.moneyIn,
    );
    if (d.splitPeople > 1) e = await _ledger.split(e.id, d.splitPeople, names: d.splitNames) ?? e;
    Remind.sync(_ledger);
    if (!mounted) return;
    Feel.logged();
    KittyLayer.cheer();
    setState(() => _fresh = e.id);
    _toast(
      e.moneyIn
          ? tr('Yay, ${_describe(e)}', '耶，${_describe(e)}')
          : d.splitPeople > 1
          ? tr(
              'Logged your share, ${_describe(e)}. Friends owe you ${money(d.amount - e.amount, e.currency)}',
              '已记下你那份：${_describe(e)}。朋友欠你 ${money(d.amount - e.amount, e.currency)}',
            )
          : tr('Logged ${_describe(e)}', '已记下 ${_describe(e)}'),
      action: SnackBarAction(
        label: tr('Undo', '撤销'),
        onPressed: () async {
          Feel.removed();
          await _ledger.delete(e.id);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<ExpenseDraft?> _review(ReadReceipt r, Uint8List image, String message) => showModalBottomSheet<ExpenseDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReviewSheet(receipt: r, image: image, message: message, categories: _ledger.categories()),
  );

  Future<void> _scan({required bool camera}) async {
    final PickedImage? img;
    try {
      img = camera ? await _picker.camera() : await _picker.gallery();
    } catch (_) {
      Feel.oops();
      _toast(
        camera ? tr('Allow camera access in Settings to snap receipts.', '请在设置里允许使用相机来拍小票。') : tr('Allow photo access in Settings.', '请在设置里允许访问照片。'),
        action: Remind.settingsAction(),
      );
      return;
    }
    if (img == null || !mounted) return;
    final bytes = Uint8List.fromList(img.bytes);

    var receipt = const ReadReceipt();
    var message = tr('Type in the amount.', '请输入金额。');
    {
      setState(() {
        _busy = true;
        _busyText = tr('Reading your receipt…', '正在识别小票……');
      });
      try {
        receipt = await widget.reader.read(bytes, categories: _ledger.categories());
        message = !receipt.isReceipt
            ? tr(
                "This doesn't look like a receipt${receipt.problem != null ? ': ${receipt.problem}' : ''}.",
                '这看起来不像小票${receipt.problem != null ? '：${receipt.problem}' : ''}。',
              )
            : receipt.total == null
            ? tr("I couldn't read the total.", '我没看清总金额。')
            : tr(
                "I'm not sure about this one${receipt.problem != null ? ' (${receipt.problem})' : ''}.",
                '这张我不太确定${receipt.problem != null ? '（${receipt.problem}）' : ''}。',
              );
      } on ReadException catch (e) {
        message = e.message;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;

    final when = receipt.date ?? DateTime.now();
    final currency = receipt.currency ?? 'SGD';
    final duplicate =
        receipt.total != null &&
        _ledger.isDuplicate(amount: receipt.total!, currency: currency, merchant: receipt.merchant, image: bytes);
    if (receipt.confident && !duplicate) {
      await _save(
        ExpenseDraft(
          amount: receipt.total!,
          currency: currency,
          date: when,
          merchant: receipt.merchant,
          category: receipt.category,
          paymentMethod: receipt.paymentMethod,
          summary: receipt.summary,
        ),
        image: bytes,
      );
      return;
    }
    if (duplicate) message = tr('This looks like one you already logged. Save it again?', '这笔好像已经记过了。还要再存一次吗？');
    final d = await _review(receipt, bytes, message);
    if (d != null) await _save(d, image: bytes);
  }

  Future<void> _quickAdd() async {
    final d = await showModalBottomSheet<ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => QuickAddSheet(ownCategories: _ledger.categories()),
    );
    if (d != null) await _save(d);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          ledger: _ledger,
          onReminderChanged: () => Remind.sync(_ledger),
          onExport: () async {
            await Clipboard.setData(ClipboardData(text: _ledger.toCsv()));
            _toast(tr('Copied. Paste it into Notes, Mail or a spreadsheet.', '已复制。可以粘贴到备忘录、邮件或表格里。'));
          },
        ),
      ),
    );
    // Pocket money may have changed.
    if (mounted) setState(() {});
  }

  String _owedText() {
    final sums = <String, double>{};
    for (final d in _ledger.owed) {
      sums[d.currency] = (sums[d.currency] ?? 0) + d.amount;
    }
    return [for (final s in sums.entries) money(s.value, s.key)].join(' + ');
  }

  void _showOwed() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          final owed = _ledger.owed;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(tr('Friends owe you', '朋友欠你的'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (owed.isEmpty)
                Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text(tr('All paid back. Yay!', '都还清啦，耶！'))),
              for (final (i, d) in owed.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(d.who.characters.first.toUpperCase())),
                  title: Text('${d.who} · ${money(d.amount, d.currency)}'),
                  subtitle: Text('${d.forWhat} · ${shortDate(d.date)}'),
                  trailing: FilledButton.tonal(
                    key: Key('paid-$i'),
                    onPressed: () async {
                      Feel.logged();
                      await _ledger.markPaid(d.id);
                      refresh(() {});
                      if (mounted) setState(() {});
                    },
                    child: Text(tr('Paid back', '已还')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(Expense e) async {
    final d = await showModalBottomSheet<ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReviewSheet(
        title: tr('Edit', '编辑'),
        receipt: ReadReceipt(
          merchant: e.merchant,
          total: e.amount,
          currency: e.currency,
          date: e.date,
          category: e.category,
        ),
        categories: _ledger.categories(),
      ),
    );
    if (d == null) return;
    await _ledger.update(
      e.id,
      amount: d.amount,
      currency: d.currency,
      date: d.date ?? e.date,
      merchant: d.merchant,
      category: d.category,
    );
    if (!mounted) return;
    Feel.logged();
    setState(() {});
    _toast(tr('Saved ${money(d.amount, d.currency)}', '已保存 ${money(d.amount, d.currency)}'));
  }

  void _showExpense(Expense e) {
    final f = _ledger.receiptFor(e);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(money(e.amount, e.currency), style: Theme.of(ctx).textTheme.headlineMedium),
          Text(
            [
              e.merchant ?? tr('Expense', '支出'),
              shortDate(e.date),
              if (e.category != null) catLabel(e.category!),
              if (e.paymentMethod != null) e.paymentMethod!,
            ].join(' · '),
          ),
          if (e.summary != null) Text(e.summary!),
          if (f != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(f, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ],
          const SizedBox(height: 16),
          if (!e.moneyIn) ...[
            Pressable(
              scale: 0.96,
              child: FilledButton.icon(
                key: const Key('log-again'),
                onPressed: () {
                  Feel.tap();
                  Navigator.of(ctx).pop();
                  _save(
                    ExpenseDraft(
                      amount: e.amount,
                      currency: e.currency,
                      merchant: e.merchant,
                      category: e.category,
                      paymentMethod: e.paymentMethod,
                    ),
                  );
                },
                icon: const Icon(Icons.replay),
                label: Text(tr('Log again today', '今天再记一笔')),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!e.moneyIn && !(e.summary ?? '').startsWith('Split ')) ...[
            Pressable(
              scale: 0.96,
              child: OutlinedButton.icon(
                key: const Key('split-expense'),
                onPressed: () async {
                  Feel.tap();
                  final s = await askSplit(ctx, total: e.amount, currency: e.currency);
                  if (s == null || !ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  final mine = await _ledger.split(e.id, s.$1, names: s.$2);
                  if (mine == null || !mounted) return;
                  Feel.logged();
                  setState(() {});
                  _toast(
                    tr(
                      'Your share is ${money(mine.amount, mine.currency)}. '
                          'Friends owe you ${money(e.amount - mine.amount, e.currency)}',
                      '你那份是 ${money(mine.amount, mine.currency)}。'
                          '朋友欠你 ${money(e.amount - mine.amount, e.currency)}',
                    ),
                  );
                },
                icon: const Icon(Icons.groups_outlined),
                label: Text(tr('Split with friends', '和朋友分摊')),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Pressable(
            scale: 0.96,
            child: FilledButton.tonalIcon(
              key: const Key('edit-expense'),
              onPressed: () {
                Feel.tap();
                Navigator.of(ctx).pop();
                _edit(e);
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(tr('Edit', '编辑')),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ),
          const SizedBox(height: 10),
          Pressable(
            scale: 0.96,
            child: OutlinedButton.icon(
              key: const Key('delete-expense'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                Feel.removed();
                await _ledger.delete(e.id);
                if (mounted) {
                  setState(() {});
                  _toast(tr('Deleted ${_describe(e)}', '已删除 ${_describe(e)}'));
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(tr('Delete', '删除')),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prefs = Prefs.current;
    final period = prefs.showMonth ? Period.month : (prefs.allowanceDaily ? Period.day : Period.week);
    final o = _ledger.overview(period: period);
    final usuals = _ledger.usuals();
    return Scaffold(
      appBar: AppBar(
        title: prefs.allowance == null
            ? Text(tr('This month', '本月'))
            : SegmentedButton<bool>(
                key: const Key('period'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(prefs.allowanceDaily ? tr('Today', '今天') : tr('This week', '本周'))),
                  ButtonSegment(value: true, label: Text(tr('This month', '本月'))),
                ],
                selected: {prefs.showMonth},
                onSelectionChanged: (s) async {
                  HapticFeedback.selectionClick();
                  await prefs.setShowMonth(s.first);
                  if (mounted) setState(() {});
                },
              ),
        actions: [
          Pressable(
            child: IconButton(
              key: const Key('open-summary'),
              tooltip: tr('My month as a picture', '把本月做成一张图'),
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () {
                Feel.tap();
                Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => SummaryScreen(ledger: _ledger)));
              },
            ),
          ),
          Pressable(
            child: IconButton(
              tooltip: tr('Settings', '设置'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Feel.tap();
                _openSettings();
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _TotalCard(
                overview: o,
                period: period,
                allowance: prefs.allowance,
                onSetAllowance: () async {
                  Feel.tap();
                  if (await editAllowance(context) && mounted) setState(() {});
                },
              ),
              const SizedBox(height: 20),
              // Payment screenshots come first: PayNow, GrabPay, Alipay, WeChat and
              // card apps all show a success screen, the one record every digital
              // payment leaves.
              Row(
                children: [
                  Expanded(
                    child: _BigAction(
                      key: const Key('screenshot'),
                      icon: Icons.screenshot_outlined,
                      label: tr('Payment\nscreenshot', '付款\n截图'),
                      onPressed: _busy ? null : () => _scan(camera: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigAction(
                      key: const Key('snap'),
                      icon: Icons.photo_camera,
                      label: tr('Snap\nreceipt', '拍小票'),
                      onPressed: _busy ? null : () => _scan(camera: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Pressable(
                enabled: !_busy,
                scale: 0.97,
                child: SizedBox(
                  height: 60,
                  child: FilledButton.tonalIcon(
                    key: const Key('cash'),
                    onPressed: _busy
                        ? null
                        : () {
                            Feel.tap();
                            _quickAdd();
                          },
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(tr('Paid cash? Type the amount', '付现金？输入金额'), style: TextStyle(fontSize: 16)),
                    style:
                        FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))
                            .copyWith(
                              // Pink reads better than a white flash on this darker button.
                              overlayColor: WidgetStateProperty.resolveWith(
                                (s) => s.contains(WidgetState.pressed) ? cs.primary.withValues(alpha: 0.4) : null,
                              ),
                            ),
                  ),
                ),
              ),
              if (_ledger.owed.isNotEmpty) ...[
                const SizedBox(height: 12),
                Pressable(
                  scale: 0.97,
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: cs.tertiaryContainer,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      key: const Key('owed'),
                      leading: Icon(Icons.groups_outlined, color: cs.onTertiaryContainer),
                      title: Text(
                        tr('Friends owe you ${_owedText()}', '朋友欠你 ${_owedText()}'),
                        style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(tr('Tap when someone pays you back', '有人还钱时点一下'), style: TextStyle(color: cs.onTertiaryContainer)),
                      trailing: Icon(Icons.chevron_right, color: cs.onTertiaryContainer),
                      onTap: () {
                        Feel.tap();
                        _showOwed();
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const GoalCard(),
              if (usuals.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(tr('Usual', '常用'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, u) in usuals.indexed)
                      Pressable(
                        scale: 0.92,
                        child: ActionChip(
                          key: Key('usual-$i'),
                          avatar: Icon(iconFor(u.category), size: 20),
                          label: Text('${u.label} ${money(u.amount, u.currency)}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          onPressed: _busy
                              ? null
                              : () {
                                  Feel.tap();
                                  _save(
                                    ExpenseDraft(
                                      amount: u.amount,
                                      currency: u.currency,
                                      merchant: u.merchant,
                                      category: u.category,
                                    ),
                                  );
                                },
                        ),
                      ),
                  ],
                ),
              ],
              if (o.byCategory.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(tr('Where it went', '花在哪了'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in o.byCategory.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(iconFor(c.category), color: cs.onPrimaryContainer),
                    ),
                    title: Text(catLabel(c.category)),
                    trailing: Text(money(c.amount, c.currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
              const SizedBox(height: 20),
              Text(tr('Recent', '最近'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (o.recent.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      SizedBox(width: 120, height: 100, child: CustomPaint(painter: CatPainter(asleep: true))),
                      SizedBox(height: 12),
                      Text(tr('Nothing yet. Add your first expense above.', '还没有记录。在上面记下第一笔吧。'), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              for (final e in o.recent)
                _Arrive(
                  key: ValueKey(e.id),
                  animate: e.id == _fresh,
                  child: Pressable(
                    scale: 0.97,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Feel.tap();
                        _showExpense(e);
                      },
                      leading: Icon(e.moneyIn ? Icons.savings_outlined : iconFor(e.category)),
                      title: Text(e.merchant ?? (e.category == null ? null : catLabel(e.category!)) ?? tr('Expense', '支出'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          shortDate(e.date),
                          if (e.category != null) catLabel(e.category!),
                          if (e.paymentMethod != null) e.paymentMethod!,
                        ].join(' · '),
                      ),
                      trailing: e.moneyIn
                          ? Text(
                              '+${money(e.amount, e.currency)}',
                              style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.w600),
                            )
                          : Text(money(e.amount, e.currency)),
                    ),
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_busy,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: !_busy
                    ? const SizedBox.shrink()
                    : ColoredBox(
                        color: Colors.black38,
                        child: Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(_busyText),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.overview, required this.period, this.allowance, required this.onSetAllowance});
  final Overview overview;
  final Period period;

  /// Pocket money per day or week, in S$.
  final double? allowance;
  final VoidCallback onSetAllowance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final on = cs.onPrimaryContainer;
    final totals = overview.totals;
    final budget = period == Period.month || allowance == null ? null : allowance! + overview.received('SGD');
    final spent = overview.spent('SGD');
    final main = totals.isEmpty ? null : totals.firstWhere((m) => m.currency == 'SGD', orElse: () => totals.first);
    final others = totals.where((m) => m.currency != (budget == null ? main?.currency : 'SGD'));
    final when = period == Period.day ? tr('today', '今天') : tr('this week', '本周');

    Widget big(double value, String currency) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: CountUp(
        value: value,
        builder: (context, v) => Text(
          money(v, currency),
          key: const Key('total'),
          style: t.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: on,
            // Digits keep their width while the total rolls.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );

    final List<Widget> body;
    Widget? cat;
    if (budget != null) {
      final left = budget - spent;
      final used = budget <= 0 ? 1.0 : spent / budget;
      final mood = used > 1 ? CatMood.sad : (used >= 0.8 ? CatMood.worried : CatMood.happy);
      cat = SizedBox(
        width: 76,
        height: 76,
        child: CustomPaint(
          key: Key('cat-${mood.name}'),
          painter: CatPainter(mood: mood, paw: false),
        ),
      );
      body = [
        Text(left >= 0 ? tr('Left $when', '$when还剩') : tr('Over $when', '$when超支'), style: t.titleMedium?.copyWith(color: on)),
        const SizedBox(height: 4),
        big(left.abs(), 'SGD'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: used.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: on.withValues(alpha: 0.15),
            color: mood == CatMood.happy ? cs.primary : cs.error,
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('Spent ${money(spent, 'SGD')} of ${money(budget, 'SGD')}', '已花 ${money(spent, 'SGD')}，共 ${money(budget, 'SGD')}'), style: t.bodyMedium?.copyWith(color: on)),
        if (overview.received('SGD') > 0)
          Text(
            tr('Includes ${money(overview.received('SGD'), 'SGD')} money in', '含收入 ${money(overview.received('SGD'), 'SGD')}'),
            style: t.bodySmall?.copyWith(color: on.withValues(alpha: 0.8)),
          ),
        if (mood != CatMood.happy)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              mood == CatMood.sad
                  ? tr(
                      "It's okay. A fresh start ${period == Period.day ? 'tomorrow' : 'on Monday'}.",
                      '没关系，${period == Period.day ? '明天' : '下周一'}重新开始。',
                    )
                  : tr('Careful, almost used up!', '小心，快用完啦！'),
              style: t.bodyMedium?.copyWith(color: on, fontWeight: FontWeight.w600),
            ),
          ),
      ];
    } else {
      body = [
        Text(period == Period.month ? tr('Spent this month', '本月已花') : tr('Spent $when', '$when已花'), style: t.titleMedium?.copyWith(color: on)),
        const SizedBox(height: 4),
        big(main?.amount ?? 0, main?.currency ?? 'SGD'),
        if (overview.received('SGD') > 0)
          Text(tr('Money in: ${money(overview.received('SGD'), 'SGD')}', '收入：${money(overview.received('SGD'), 'SGD')}'), style: t.bodyMedium?.copyWith(color: on)),
        if (allowance == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              key: const Key('set-allowance'),
              onPressed: onSetAllowance,
              style: TextButton.styleFrom(foregroundColor: on, padding: EdgeInsets.zero),
              icon: const Icon(Icons.savings_outlined),
              label: Text(tr('Set my pocket money', '设置我的零花钱')),
            ),
          ),
      ];
    }
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        key: const Key('total-card'),
        // Tap to change the pocket money.
        onTap: allowance == null ? null : onSetAllowance,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...body,
                    for (final m in others)
                      Text('+ ${money(m.amount, m.currency)}', style: t.titleMedium?.copyWith(color: on)),
                  ],
                ),
              ),
              if (cat != null) ...[const SizedBox(width: 8), cat],
            ],
          ),
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    enabled: onPressed != null,
    child: ConstrainedBox(
      // Grows with larger text sizes instead of cutting the label off.
      constraints: const BoxConstraints(minHeight: 120),
      child: FilledButton(
        onPressed: onPressed == null
            ? null
            : () {
                Feel.tap();
                onPressed!();
              },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Slides a just-logged row into the list so it's clear where it went.
class _Arrive extends StatelessWidget {
  const _Arrive({super.key, required this.animate, required this.child});
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, still ? 0 : (1 - t) * -14), child: child),
      ),
      child: child,
    );
  }
}
