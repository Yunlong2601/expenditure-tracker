// Every screen and sheet against Flutter's accessibility checks: buttons
// big enough to tap (44 points on iPhone, 48 on Android), every button has
// a name VoiceOver can read, and text stands out enough from what's behind
// it (see contrast.dart). a11y_test.dart runs the Cosy look, and
// a11y_calm_test.dart the Calm one.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/records.dart';

import 'contrast.dart';
import 'edge_taps.dart';
import 'stress.dart';

/// One pass over every screen: on [phone], light or [dark], in the Calm
/// look or not, with [checks], and the contrast check if [contrast].
typedef A11yRun = ({
  Phone phone,
  bool dark,
  bool calm,
  bool contrast,
  List<AccessibilityGuideline> checks,
});

/// A common Android size (412 x 915), for Android's 48-point taps.
const android = (name: 'Android phone', size: Size(412, 915), text: 1.0);
const iOSEdge = EdgeTapTargetGuideline(Size(44, 44));
const androidEdge = EdgeTapTargetGuideline(Size(48, 48));

/// An iPhone SE, for Apple's 44-point taps, names and contrast.
A11yRun iPhoneRun({required bool dark, bool calm = false}) => (
  phone: phones[1],
  dark: dark,
  calm: calm,
  contrast: true,
  checks: [iOSTapTargetGuideline, iOSEdge, labeledTapTargetGuideline],
);

/// Runs every screen through the checks on each of [runs].
void a11yAll(List<A11yRun> runs) {
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFont(roboto());
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('a11y');
    CatFigure.animate = false;
  });
  tearDown(() async {
    final f = FocusSession.current;
    if (f.started) await f.finish(early: true);
    f.setSubject('study');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  for (final run in runs) {
    final contrast = run.contrast;
    testWidgets(
      'every screen passes: ${run.phone.name}, ${run.dark ? 'dark' : 'light'}${run.calm ? ', Calm' : ''}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final ledger = await seededLedger(tester, dir);
        usePhone(tester, run.phone, dark: run.dark);
        final problems = <String>[];
        for (final MapEntry(key: name, value: open) in screens.entries) {
          if (only.isNotEmpty && !only.split(',').contains(name)) continue;
          await openScreen(
            tester,
            lang: 'en',
            ledger: ledger,
            open: open,
            calm: run.calm,
          );
          for (final g in run.checks) {
            final r = await g.evaluate(tester);
            if (r.passed) continue;
            for (final node in r.reason!.trim().split(
              RegExp(r'\n(?=SemanticsNode#)'),
            )) {
              if (!accepted(tester, node)) {
                problems.add('$name: ${node.split('\n').first}');
              }
            }
          }
          if (contrast) {
            for (final p in await contrastProblems(tester)) {
              problems.add('$name, contrast: $p');
            }
          }
          await closeScreen(tester);
        }
        semantics.dispose();
        if (log.isNotEmpty) {
          File(log).writeAsStringSync(
            '== ${run.phone.name} ${run.dark ? 'dark' : 'light'}\n${problems.join('\n')}\n',
            mode: FileMode.append,
          );
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );
  }
}

/// Known and kept on purpose: the Dashboard's small week card from the
/// wireframe, whose days are 31 points wide and arrows 26 (Apple asks for
/// 44). Making them bigger means a full-width card, which is a design call.
bool accepted(WidgetTester tester, String node) =>
    find.byKey(const Key('calendar-toggle')).evaluate().isNotEmpty &&
    node.contains(RegExp(r'tooltip: "(Last|Next) week"|label: "[A-Z]\\n\d+"'));
