import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/feel.dart';
import 'package:spendsnap/settings_screen.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('feel'));
  tearDown(() async => dir.delete(recursive: true));

  testWidgets('the Sounds switch is remembered across launches', (t) async {
    await t.runAsync(() => Feel.load(dir));
    expect(Feel.soundOn, isTrue);

    await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('sounds')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    expect(Feel.soundOn, isFalse);

    await t.runAsync(() => Feel.load(dir));
    expect(Feel.soundOn, isFalse);
  });
}
