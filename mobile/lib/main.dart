import 'package:flutter/material.dart';

import 'app.dart';
import 'settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SpendSnapApp(store: SettingsStore()));
}
