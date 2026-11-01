import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'home_screen.dart';
import 'ledger.dart';
import 'reader.dart';

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

class SpendSnapApp extends StatelessWidget {
  const SpendSnapApp({super.key, this.ledgerDir, this.reader, this.picker});

  final Directory? ledgerDir;
  final ReceiptReader? reader;
  final ReceiptPicker? picker;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: pink, brightness: b),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Spend Snap',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: _Root(ledgerDir: ledgerDir, reader: reader ?? OfflineReader(), picker: picker),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({this.ledgerDir, required this.reader, this.picker});
  final Directory? ledgerDir;
  final ReceiptReader reader;
  final ReceiptPicker? picker;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  Ledger? _ledger;

  @override
  void initState() {
    super.initState();
    () async {
      final dir = widget.ledgerDir ?? Directory('${(await getApplicationDocumentsDirectory()).path}/spendsnap');
      final ledger = Ledger(dir);
      await ledger.load();
      if (mounted) setState(() => _ledger = ledger);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    if (ledger == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return HomeScreen(ledger: ledger, reader: widget.reader, picker: widget.picker);
  }
}
