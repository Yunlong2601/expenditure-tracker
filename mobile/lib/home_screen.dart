import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'categories.dart';
import 'draft.dart';
import 'feel.dart';
import 'format.dart';
import 'kitty.dart';
import 'ledger.dart';
import 'picker.dart';
import 'quick_add_sheet.dart';
import 'reader.dart';
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

  String _describe(Expense e) =>
      '${money(e.amount, e.currency)}${e.merchant != null ? ' at ${e.merchant}' : ''}'
      '${e.category != null ? ' (${e.category})' : ''}';

  Future<void> _save(ExpenseDraft d, {Uint8List? image}) async {
    final e = await _ledger.add(
      amount: d.amount,
      currency: d.currency,
      date: d.date,
      merchant: d.merchant,
      category: d.category,
      paymentMethod: d.paymentMethod,
      summary: d.summary,
      receipt: image,
    );
    if (!mounted) return;
    Feel.logged();
    KittyLayer.cheer();
    setState(() => _fresh = e.id);
    _toast(
      'Logged ${_describe(e)}',
      action: SnackBarAction(
        label: 'Undo',
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
      _toast(camera ? 'Allow camera access in Settings to snap receipts.' : 'Allow photo access in Settings.');
      return;
    }
    if (img == null || !mounted) return;
    final bytes = Uint8List.fromList(img.bytes);

    var receipt = const ReadReceipt();
    var message = 'Type in the amount.';
    {
      setState(() {
        _busy = true;
        _busyText = 'Reading your receipt…';
      });
      try {
        receipt = await widget.reader.read(bytes, categories: _ledger.categories());
        message = !receipt.isReceipt
            ? "This doesn't look like a receipt${receipt.problem != null ? ': ${receipt.problem}' : ''}."
            : receipt.total == null
            ? "I couldn't read the total."
            : "I'm not sure about this one${receipt.problem != null ? ' (${receipt.problem})' : ''}.";
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
    if (duplicate) message = 'This looks like one you already logged. Save it again?';
    final d = await _review(receipt, bytes, message);
    if (d != null) await _save(d, image: bytes);
  }

  Future<void> _quickAdd() async {
    final d = await showModalBottomSheet<ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const QuickAddSheet(),
    );
    if (d != null) await _save(d);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onExport: () async {
            await Clipboard.setData(ClipboardData(text: _ledger.toCsv()));
            _toast('Copied. Paste it into Notes, Mail or a spreadsheet.');
          },
        ),
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
        title: 'Edit',
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
    _toast('Saved ${money(d.amount, d.currency)}');
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
              e.merchant ?? 'Expense',
              shortDate(e.date),
              if (e.category != null) e.category!,
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
              label: const Text('Edit'),
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
                  _toast('Deleted ${_describe(e)}');
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
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
    final o = _ledger.overview();
    return Scaffold(
      appBar: AppBar(
        title: const Text('This month'),
        actions: [
          Pressable(
            child: IconButton(
              tooltip: 'Settings',
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
              _TotalCard(overview: o),
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
                      label: 'Payment\nscreenshot',
                      onPressed: _busy ? null : () => _scan(camera: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigAction(
                      key: const Key('snap'),
                      icon: Icons.photo_camera,
                      label: 'Snap\nreceipt',
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
                    label: const Text('Paid cash? Type the amount', style: TextStyle(fontSize: 16)),
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
              if (o.byCategory.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Where it went', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in o.byCategory.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(iconFor(c.category), color: cs.onPrimaryContainer),
                    ),
                    title: Text(c.category),
                    trailing: Text(money(c.amount, c.currency), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
              const SizedBox(height: 20),
              Text('Recent', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (o.recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      SizedBox(width: 120, height: 100, child: CustomPaint(painter: CatPainter(asleep: true))),
                      SizedBox(height: 12),
                      Text('Nothing yet. Add your first expense above.', textAlign: TextAlign.center),
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
                      leading: Icon(iconFor(e.category)),
                      title: Text(e.merchant ?? e.category ?? 'Expense', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          shortDate(e.date),
                          if (e.category != null) e.category!,
                          if (e.paymentMethod != null) e.paymentMethod!,
                        ].join(' · '),
                      ),
                      trailing: Text(money(e.amount, e.currency)),
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
  const _TotalCard({required this.overview});
  final Overview overview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final totals = overview.totals;
    final main = totals.isEmpty ? null : totals.firstWhere((m) => m.currency == 'SGD', orElse: () => totals.first);
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spent so far', style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUp(
                value: main?.amount ?? 0,
                builder: (context, v) => Text(
                  money(v, main?.currency ?? 'SGD'),
                  key: const Key('total'),
                  style: t.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                    // Digits keep their width while the total rolls.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            for (final m in totals.where((m) => m != main))
              Text('+ ${money(m.amount, m.currency)}', style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          ],
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
