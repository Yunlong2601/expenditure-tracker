import 'package:flutter/material.dart';

import 'settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store, this.initial, this.firstRun = false, this.onSaved});

  final SettingsStore store;
  final ServerSettings? initial;
  final bool firstRun;
  final ValueChanged<ServerSettings>? onSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _key = TextEditingController(text: widget.initial?.apiKey ?? '');
  final _form = GlobalKey<FormState>();
  bool _hideKey = true;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    var url = _url.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    final s = ServerSettings(url: url, apiKey: _key.text.trim());
    await widget.store.save(s);
    if (!mounted) return;
    widget.onSaved?.call(s);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.firstRun) ...[
                const SizedBox(height: 24),
                Text('Spend Snap', style: t.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Connect to your receipt scanner once. After that it is one tap per receipt.', style: t.bodyLarge),
                const SizedBox(height: 32),
              ],
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Server address',
                  hintText: 'http://100.64.0.5:8082',
                  helperText: 'The receipt scanner address (port 8082)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the server address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _key,
                obscureText: _hideKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Access key',
                  helperText: 'RECEIPTS_API_KEY from your .env file',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _hideKey ? 'Show key' : 'Hide key',
                    icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hideKey = !_hideKey),
                  ),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the access key' : null,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(widget.firstRun ? 'Start' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
