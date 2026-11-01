import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// The iPhone share sheet and Files picker, via a small bridge in
/// `ios/Runner/AppDelegate.swift`.
class Share {
  Share._();

  static const _channel = MethodChannel('spendsnap/share');

  /// Writes [bytes] to a temporary file called [name] and opens the share
  /// sheet for it. Returns false if it couldn't be shared.
  static Future<bool> bytes(List<int> bytes, String name) async {
    try {
      final f = File('${(await getTemporaryDirectory()).path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      return await _channel.invokeMethod<bool>('file', f.path) ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  /// Lets her pick a backup file in Files. Null when cancelled or unreadable.
  static Future<Map<String, Object?>?> pickJson() async {
    try {
      final path = await _channel.invokeMethod<String>('pick');
      if (path == null) return null;
      return (jsonDecode(await File(path).readAsString()) as Map).cast<String, Object?>();
    } on Object catch (_) {
      return null;
    }
  }
}
