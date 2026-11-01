import 'package:flutter/material.dart';

import 'api.dart';
import 'home_screen.dart';
import 'settings.dart';
import 'settings_screen.dart';

typedef ApiFactory = ScannerApi Function(ServerSettings settings);

ScannerApi _defaultApi(ServerSettings s) => ScannerApi(baseUrl: s.url, apiKey: s.apiKey);

const pink = Color(0xFFFF69B4);

class SpendSnapApp extends StatelessWidget {
  const SpendSnapApp({super.key, required this.store, this.apiFactory = _defaultApi, this.picker});

  final SettingsStore store;
  final ApiFactory apiFactory;
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
      home: _Root(store: store, apiFactory: apiFactory, picker: picker),
    );
  }
}

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

class _Root extends StatefulWidget {
  const _Root({required this.store, required this.apiFactory, this.picker});
  final SettingsStore store;
  final ApiFactory apiFactory;
  final ReceiptPicker? picker;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  ServerSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.load().then(
      (s) => setState(() {
        _settings = s;
        _loading = false;
      }),
    );
  }

  Future<void> _openSettings() async {
    final s = await Navigator.of(context).push<ServerSettings>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(initial: _settings, store: widget.store),
      ),
    );
    if (s != null) setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _settings;
    if (s == null) {
      return SettingsScreen(store: widget.store, firstRun: true, onSaved: (saved) => setState(() => _settings = saved));
    }
    return HomeScreen(
      key: ValueKey('${s.url}|${s.apiKey}'),
      api: widget.apiFactory(s),
      picker: widget.picker,
      onOpenSettings: _openSettings,
    );
  }
}
