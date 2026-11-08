import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'feel.dart';
import 'day.dart';
import 'shell.dart';
import 'theme.dart';
import 'kitty.dart';
import 'l10n.dart';
import 'prefs.dart';
import 'remind.dart';
import 'ledger.dart';
import 'reader.dart';

/// The old pink, still used by a few money screens.
const pink = Color(0xFFFF69B4);

/// Lets tests replace the camera and photo library.
abstract class ReceiptPicker {
  Future<PickedImage?> camera();
  Future<PickedImage?> gallery();
}

class PickedImage {
  const PickedImage(this.bytes, this.name);
  final List<int> bytes;
  final String name;
}

/// Tiny Habits Cat. [SpendSnapApp] keeps its old name so tests and the
/// iOS project don't need to change.
class SpendSnapApp extends StatefulWidget {
  const SpendSnapApp({super.key, this.ledgerDir, this.reader, this.picker});

  final Directory? ledgerDir;
  final ReceiptReader? reader;
  final ReceiptPicker? picker;

  @override
  State<SpendSnapApp> createState() => _SpendSnapAppState();
}

class _SpendSnapAppState extends State<SpendSnapApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone's language changed: follow it, unless one was picked in Me.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (Prefs.current.language != null) return;
    setState(() {});
    redrawAll();
    Remind.syncCheckIns(DayStore.current);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny Habits Cat',
      debugShowCheckedModeBanner: false,
      theme: tinyTheme(Brightness.light, calm: Prefs.current.calm),
      darkTheme: tinyTheme(Brightness.dark, calm: Prefs.current.calm),
      themeMode: switch (Prefs.current.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      // The phone's language, or the one picked in Me → Language.
      locale: Locale(zh ? 'zh' : 'en'),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Text grows with the phone's setting up to 200%, as WCAG asks; past
      // that (iOS goes to about 310%) the cat scenes and cards lose their shape.
      builder: (_, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        child: KittyLayer(child: child!),
      ),
      home: _Root(
        ledgerDir: widget.ledgerDir,
        reader: widget.reader ?? OfflineReader(),
        picker: widget.picker,
        onThemeChanged: () => setState(() {}),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({this.ledgerDir, required this.reader, this.picker, required this.onThemeChanged});
  final Directory? ledgerDir;
  final ReceiptReader reader;
  final ReceiptPicker? picker;
  final VoidCallback onThemeChanged;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  Ledger? _ledger;
  DayStore? _day;

  @override
  void initState() {
    super.initState();
    () async {
      // The folder keeps its old name so existing expenses carry over.
      final dir = widget.ledgerDir ?? Directory('${(await getApplicationDocumentsDirectory()).path}/spendsnap');
      final ledger = Ledger(dir);
      await ledger.load();
      await Feel.load(dir);
      await Prefs.load(dir);
      final day = await DayStore.load(dir);
      Remind.sync(ledger);
      Remind.syncCheckIns(day);
      widget.onThemeChanged();
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _day = day;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    final day = _day;
    if (ledger == null || day == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AppShell(
      store: day,
      ledger: ledger,
      reader: widget.reader,
      picker: widget.picker,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}
