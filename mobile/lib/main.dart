import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Phones stay upright: turned sideways, the Dynamic Island or camera
  // hole would sit beside the content, and the room and lists are built
  // for a tall screen. Tablets still turn. (Info.plist does the same for
  // iPhones from the moment the app opens.)
  final view = binding.platformDispatcher.implicitView;
  if (view != null &&
      view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const SpendSnapApp());
}
