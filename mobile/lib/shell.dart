import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'chat.dart';
import 'dashboard.dart';
import 'day.dart';
import 'feel.dart';
import 'home_screen.dart';
import 'home_tab.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'ledger.dart';
import 'me_tab.dart';
import 'reader.dart';
import 'records.dart';
import 'remind.dart';
import 'settings_screen.dart';

/// The three tabs from the wireframes: Pet, Dashboard and Me.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.store,
    this.ledger,
    this.reader,
    this.picker,
    this.onThemeChanged,
    this.initialTab = 0,
  });
  final DayStore store;

  /// The Money module. Without it the money parts are hidden.
  final Ledger? ledger;
  final ReceiptReader? reader;
  final ReceiptPicker? picker;
  final VoidCallback? onThemeChanged;

  /// The tab shown first: 0 Pet, 1 Dashboard, 2 Me.
  final int initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late var _tab = widget.initialTab;

  Future<void> _push(Widget w) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => w));

  void _chat() {
    Feel.tap();
    Navigator.of(context).push<void>(
      _slide(
        ChatScreen(store: widget.store, spentToday: _spentToday),
        fromLeft: true,
      ),
    );
  }

  void _records() {
    Feel.tap();
    Navigator.of(
      context,
    ).push<void>(_slide(RecordsScreen(store: widget.store), fromLeft: false));
  }

  String _spentToday() =>
      spentOn(widget.ledger, DateTime.now()) ?? tr('nothing so far', '还没有');

  VoidCallback? get _money {
    final l = widget.ledger;
    final r = widget.reader;
    if (l == null || r == null) return null;
    return () async {
      Feel.tap();
      await _push(HomeScreen(ledger: l, reader: r, picker: widget.picker));
      // Expenses may have changed: redraw the Dashboard's money and calendar.
      if (mounted) setState(() {});
    };
  }

  Future<void> _settings() async {
    final l = widget.ledger;
    await _push(
      SettingsScreen(
        ledger: l,
        onReminderChanged: l == null ? null : () => Remind.sync(l),
        onExport: l == null
            ? null
            : () => Clipboard.setData(ClipboardData(text: l.toCsv())),
      ),
    );
    // A restore can bring back other expenses and check-ins.
    Remind.syncCheckIns(widget.store);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => IndexedStack(
          index: _tab,
          children: [
            HomeTab(
              store: widget.store,
              onChat: _chat,
              onRecords: _records,
              onExpense: _money,
            ),
            DashboardTab(
              store: widget.store,
              ledger: widget.ledger,
              onMoney: _money,
            ),
            MeTab(
              onSettings: _settings,
              onThemeChanged: widget.onThemeChanged ?? () {},
              onLanguageChanged: () {
                final l = widget.ledger;
                if (l != null) Remind.sync(l);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: TabBarCard(
        tab: _tab,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() => _tab = i);
          },
          destinations: [
            NavigationDestination(
              icon: const SizedBox.square(
                dimension: 28,
                child: CustomPaint(painter: CatPainter(paw: false)),
              ),
              label: tr('Pet', '宠物'),
            ),
            NavigationDestination(
              icon: const LineIcon(LineGlyph.bars),
              label: tr('Dashboard', '看板'),
            ),
            NavigationDestination(
              icon: const LineIcon(LineGlyph.person),
              label: tr('Me', '我'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides a screen in from the edge she swiped from.
Route<void> _slide(Widget w, {required bool fromLeft}) =>
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => w,
      transitionsBuilder: (context, a, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        return SlideTransition(
          position: Tween(
            begin: Offset(fromLeft ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );

/// The white tab bar card from the wireframes: rounded top corners, a soft
/// shadow and a short green line under the open tab's label.
class TabBarCard extends StatelessWidget {
  const TabBarCard({super.key, required this.tab, required this.child});
  final int tab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF242521) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = box.maxWidth / 3;
          return Stack(
            children: [
              child,
              AnimatedPositioned(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: 64,
                left: slot * tab + slot / 2 - 9,
                child: ExcludeSemantics(
                  child: Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2),
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

/// Thin line icons drawn to match the wireframes' tab bar.
enum LineGlyph { bars, person }

class LineIcon extends StatelessWidget {
  const LineIcon(this.glyph, {super.key});
  final LineGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LinePainter(glyph, icon.color ?? Colors.grey),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.glyph, this.color);
  final LineGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * u
      ..strokeCap = StrokeCap.round;
    switch (glyph) {
      case LineGlyph.bars:
        canvas.drawLine(Offset(7 * u, 11 * u), Offset(7 * u, 19 * u), pen);
        canvas.drawLine(Offset(12 * u, 5 * u), Offset(12 * u, 19 * u), pen);
        canvas.drawLine(Offset(17 * u, 9 * u), Offset(17 * u, 19 * u), pen);
      case LineGlyph.person:
        canvas.drawCircle(Offset(12 * u, 8 * u), 3.8 * u, pen);
        canvas.drawPath(
          Path()
            ..moveTo(4.5 * u, 20.5 * u)
            ..cubicTo(4.5 * u, 16 * u, 8 * u, 13.5 * u, 12 * u, 13.5 * u)
            ..cubicTo(16 * u, 13.5 * u, 19.5 * u, 16 * u, 19.5 * u, 20.5 * u),
          pen,
        );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.glyph != glyph || old.color != color;
}
