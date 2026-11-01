import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerSettings {
  const ServerSettings({required this.url, required this.apiKey});
  final String url;
  final String apiKey;
  bool get isComplete => url.isNotEmpty && apiKey.isNotEmpty;
}

/// Keeps the server address and access key in the iOS Keychain /
/// Android Keystore.
class SettingsStore {
  SettingsStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  Future<ServerSettings?> load() async {
    final url = await _s.read(key: 'server_url') ?? '';
    final key = await _s.read(key: 'api_key') ?? '';
    final s = ServerSettings(url: url, apiKey: key);
    return s.isComplete ? s : null;
  }

  Future<void> save(ServerSettings s) async {
    await _s.write(key: 'server_url', value: s.url.trim());
    await _s.write(key: 'api_key', value: s.apiKey.trim());
  }
}
