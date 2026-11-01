import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'app.dart';
import 'categories.dart';
import 'format.dart';
import 'picker.dart';
import 'quick_add_sheet.dart';
import 'review_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onOpenSettings, this.picker});

  final ScannerApi api;
  final VoidCallback onOpenSettings;
  final ReceiptPicker? picker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReceiptPicker _picker = widget.picker ?? DevicePicker();
  Overview? _overview;
  String? _error;
  bool _busy = false;
  String _busyText = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final o = await widget.api.overview();
      if (!mounted) return;
      setState(() {
        _overview = o;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Future<T?> _withBusy<T>(String text, Future<T> Function() work) async {
    setState(() {
      _busy = true;
      _busyText = text;
    });
    try {
      return await work();
    } on ApiException catch (e) {
      _toast(e.message);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan({required bool camera}) async {
    final PickedImage? img;
    try {
      img = camera ? await _picker.camera() : await _picker.gallery();
    } catch (_) {
      _toast(camera ? 'Allow camera access in Settings to snap receipts.' : 'Allow photo access in Settings.');
      return;
    }
    if (img == null || !mounted) return;
    final bytes = Uint8List.fromList(img.bytes);

    final result = await _withBusy('Reading your receipt…', () => widget.api.scan(bytes, filename: img!.name));
    if (result == null || !mounted) return;

    if (result.saved) {
      _toast(result.message);
      _refresh();
      return;
    }
    if (!result.needsReview || result.receipt == null) {
      _toast(result.message);
      return;
    }
    // Keep the photo and any corrections until the save goes through, so a
    // dropped connection never means re-taking the picture.
    ExpenseFields? draft;
    var current = result;
    while (mounted) {
      final fields = await showModalBottomSheet<ExpenseFields>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => ReviewSheet(result: current, image: bytes, draft: draft),
      );
      if (fields == null || !mounted) return;
      draft = fields;
      final saved = await _withBusy('Saving…', () => widget.api.scan(bytes, filename: img!.name, fields: fields));
      if (!mounted) return;
      if (saved != null) _toast(saved.message);
      if (saved != null && saved.saved) {
        _refresh();
        return;
      }
      if (saved != null) {
        current = ScanResult(
          saved: false,
          needsReview: true,
          message: saved.message,
          receipt: current.receipt,
          account: current.account,
          accounts: current.accounts,
          categories: current.categories,
        );
      }
    }
  }

  Future<void> _quickAdd() async {
    final fields = await showModalBottomSheet<ExpenseFields>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const QuickAddSheet(),
    );
    if (fields == null || !mounted) return;
    final r = await _withBusy('Saving…', () => widget.api.addManual(fields));
    if (r == null || !mounted) return;
    _toast(r.message);
    if (r.saved) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('This month'),
        actions: [
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: widget.onOpenSettings),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _TotalCard(overview: _overview, error: _error),
                const SizedBox(height: 20),
                // Payment screenshots come first: PayNow, GrabPay, Alipay, WeChat
                // and card apps all show a success screen, and it's the one record
                // every digital payment leaves.
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
                SizedBox(
                  height: 60,
                  child: FilledButton.tonalIcon(
                    key: const Key('cash'),
                    onPressed: _busy ? null : _quickAdd,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Paid cash? Type the amount', style: TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                if (_overview != null && _overview!.byCategory.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Where it went', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final c in _overview!.byCategory.take(5))
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
                if (_overview != null) ...[
                  const SizedBox(height: 20),
                  Text('Recent', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_overview!.recent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Nothing yet. Snap your first receipt above.'),
                    ),
                  for (final e in _overview!.recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(iconFor(e.category)),
                      title: Text(e.merchant ?? e.category ?? 'Expense', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          shortDate(e.date),
                          if (e.category != null) e.category!,
                          if (e.account != null) e.account!,
                        ].join(' · '),
                      ),
                      trailing: Text(money(e.amount, e.currency)),
                    ),
                ],
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_busyText)],
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
  const _TotalCard({required this.overview, required this.error});
  final Overview? overview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget child;
    if (overview == null && error != null) {
      child = Text(error!, style: t.bodyLarge);
    } else if (overview == null) {
      child = const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()));
    } else {
      final totals = overview!.totals;
      final main = totals.isEmpty ? null : totals.firstWhere((m) => m.currency == 'SGD', orElse: () => totals.first);
      final others = totals.where((m) => m != main);
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent so far', style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              main == null ? money(0, 'SGD') : money(main.amount, main.currency),
              key: const Key('total'),
              style: t.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
            ),
          ),
          for (final m in others)
            Text('+ ${money(m.amount, m.currency)}', style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: t.bodySmall),
            ),
        ],
      );
    }
    return Card(
      color: cs.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
  );
}
