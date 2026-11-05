import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'categories.dart';
import 'feel.dart';
import 'format.dart';
import 'kitty.dart';
import 'ledger.dart';
import 'share.dart';

/// A cute picture of her month, to keep or send to friends.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.ledger, this.month});
  final Ledger ledger;
  final DateTime? month;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _picture = GlobalKey();
  late DateTime _month = DateTime((widget.month ?? DateTime.now()).year, (widget.month ?? DateTime.now()).month);
  bool _sharing = false;

  void _go(int by) {
    Feel.tap();
    setState(() => _month = DateTime(_month.year, _month.month + by));
  }

  Future<void> _share() async {
    Feel.tap();
    setState(() => _sharing = true);
    try {
      final b = _picture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final name = 'TinyHabitsCat-${DateFormat('yyyy-MM').format(_month)}.png';
      if (png != null) await Share.bytes(png.buffer.asUint8List(), name);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: const Text('My month')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(tooltip: 'Previous month', onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left)),
                Text(DateFormat('MMMM yyyy').format(_month), style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: isThisMonth ? null : () => _go(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RepaintBoundary(
              key: _picture,
              child: _SummaryCard(ledger: widget.ledger, month: _month),
            ),
            const SizedBox(height: 20),
            Pressable(
              scale: 0.96,
              child: FilledButton.icon(
                key: const Key('share-summary'),
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Save or share picture'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ledger, required this.month});
  final Ledger ledger;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final end = DateTime(month.year, month.month + 1, 0, 23, 59);
    final o = ledger.overview(now: end, recent: 0);
    final items = [
      for (final e in ledger.all)
        if (!e.moneyIn && e.date.year == month.year && e.date.month == month.month) e,
    ];
    final spent = o.spent('SGD');
    final cats = [
      for (final c in o.byCategory)
        if (c.currency == 'SGD') c,
    ];
    final top = cats.isEmpty ? 1.0 : cats.first.amount;
    final biggest = items.isEmpty ? null : (items..sort((a, b) => b.amount.compareTo(a.amount))).first;
    final teas = items.where((e) => (e.category ?? '').toLowerCase() == 'bubble tea').length;
    final on = cs.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, Color.alphaBlend(cs.primary.withValues(alpha: 0.25), cs.primaryContainer)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My ${DateFormat('MMMM').format(month)}',
                      style: t.titleLarge?.copyWith(color: on, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(spent, 'SGD'),
                        key: const Key('summary-total'),
                        style: t.displaySmall?.copyWith(color: on, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      items.isEmpty ? 'Nothing logged yet' : '${items.length} things logged',
                      style: t.bodyMedium?.copyWith(color: on),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 88,
                height: 88,
                child: CustomPaint(
                  painter: CatPainter(asleep: items.isEmpty, mood: CatMood.delighted, paw: items.isNotEmpty),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final c in cats.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(iconFor(c.category), size: 20, color: on),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 96,
                    child: Text(
                      c.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: on),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.amount / top,
                        minHeight: 10,
                        color: cs.primary,
                        backgroundColor: on.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(c.amount, 'SGD'),
                    style: TextStyle(color: on, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (biggest != null || teas > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (biggest != null)
                  _Fact(
                    'Biggest buy: ${biggest.merchant ?? biggest.category ?? 'something'}, '
                    '${money(biggest.amount, biggest.currency)}',
                  ),
                if (teas > 0) _Fact('$teas bubble tea${teas == 1 ? '' : 's'}'),
                if (o.received('SGD') > 0) _Fact('Got ${money(o.received('SGD'), 'SGD')}'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              paw(on.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text('Tiny Habits Cat', style: t.labelLarge?.copyWith(color: on.withValues(alpha: 0.8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget paw(Color c) => SizedBox(width: 16, height: 16, child: CustomPaint(painter: _PawPainter(c)));
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: cs.onSurface)),
    );
  }
}

class _PawPainter extends CustomPainter {
  _PawPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintPaw(canvas, size.center(Offset.zero), size.width / 2.4, 0, color);

  @override
  bool shouldRepaint(_PawPainter old) => old.color != color;
}
