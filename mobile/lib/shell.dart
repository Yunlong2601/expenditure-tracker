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
      bottomNavigationBar: NavigationBar(
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
            icon: const Icon(Icons.bar_chart_rounded),
            label: tr('Dashboard', '看板'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: tr('Me', '我'),
          ),
        ],
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
