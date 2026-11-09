// Every screen on iPhones with the Dynamic Island (and one with a notch):
// no words, icons or buttons may sit under the status bar and the island
// at the top, or under the home bar at the bottom. Phones stay upright
// (Info.plist and main.dart), so the island is never beside the content.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/records.dart';
import 'package:spendsnap/theme.dart';

import 'stress/stress.dart';

/// A phone's size and its safe area (the status bar, island or notch, and
/// home bar), in points.
typedef Bars = ({String name, Size size, EdgeInsets safe});

const bars = <Bars>[
  (
    name: 'notch, 390 x 844',
    size: Size(390, 844),
    safe: EdgeInsets.only(top: 47, bottom: 34),
  ),
  (
    name: 'Dynamic Island, 393 x 852',
    size: Size(393, 852),
    safe: EdgeInsets.only(top: 59, bottom: 34),
  ),
  (
    name: 'Dynamic Island, 402 x 874',
    size: Size(402, 874),
    safe: EdgeInsets.only(top: 62, bottom: 34),
  ),
  (
    name: 'Dynamic Island, 440 x 956',
    size: Size(440, 956),
    safe: EdgeInsets.only(top: 62, bottom: 34),
  ),
  // Headroom for a taller top bar than any of the above.
  (
    name: 'taller top bar, 420 x 912',
    size: Size(420, 912),
    safe: EdgeInsets.only(top: 68, bottom: 34),
  ),
];

/// BARS=0,2 runs only those phones.
const onlyBars = String.fromEnvironment('BARS');

FakeViewPadding _pad(EdgeInsets e) => FakeViewPadding(
  left: e.left * 3,
  top: e.top * 3,
  right: e.right * 3,
  bottom: e.bottom * 3,
);

/// What on screen sits under a bar, by the words it shows or its kind.
List<String> underBars(WidgetTester t, Size screen, EdgeInsets safe) {
  final found = <String>[];
  final keep = Rect.fromLTRB(
    safe.left,
    safe.top,
    screen.width - safe.right,
    screen.height - safe.bottom,
  );
  void look(Finder f, String Function(Widget) name) {
    for (final e in f.evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      var r = box.localToGlobal(Offset.zero) & box.size;
      if (r.isEmpty) continue;
      // Full-screen layers (a page, a sheet's barrier) aren't content.
      if (r.width >= screen.width * 0.95 && r.height >= screen.height * 0.6) {
        continue;
      }
      // Only the part a list shows; a list itself may run under the home
      // bar, since its last rows scroll up out from under it.
      var inList = false;
      e.visitAncestorElements((a) {
        if (a.widget is Scrollable) {
          final s = a.renderObject;
          if (s is RenderBox && s.hasSize) {
            r = r.intersect(s.localToGlobal(Offset.zero) & s.size);
            inList = true;
          }
        }
        return true;
      });
      if (r.width <= 0.5 || r.height <= 0.5) continue;
      final top = r.top < keep.top - 0.5;
      final side = r.left < keep.left - 0.5 || r.right > keep.right + 0.5;
      final bottom = !inList && r.bottom > keep.bottom + 0.5;
      if (top || side || bottom) {
        final where = [if (top) 'top', if (side) 'side', if (bottom) 'bottom'];
        found.add('${name(e.widget)} (${where.join(', ')}, $r)');
      }
    }
  }

  look(find.byType(RichText), (w) {
    final s = (w as RichText).text.toPlainText();
    return 'text "${s.length > 30 ? '${s.substring(0, 30)}…' : s}"';
  });
  look(find.byType(EditableText), (_) => 'text field');
  look(
    find.byWidgetPredicate(
      (w) =>
          (w is InkResponse && (w.onTap != null || w.onLongPress != null)) ||
          (w is GestureDetector && w.onTap != null),
    ),
    (w) => 'button ${w.runtimeType}',
  );
  return found;
}

void main() {
  late Directory dir;
  setUpAll(() => loadFont(roboto()));
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bars');
    CatFigure.animate = false;
  });
  tearDown(() async {
    final f = FocusSession.current;
    if (f.started) await f.finish(early: true);
    f.setSubject('study');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('the room draws only wall behind the status bar', (t) async {
    const top = 62.0;
    final key = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 402,
              child: RoomScene(
                height: 300 + top,
                top: top,
                items: {'poster', 'lights', 'shelf', 'fish', 'lamp'},
              ),
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await t.runAsync(() async {
      final image = await boundary.toImage();
      return image.toByteData();
    });
    final width = boundary.size.width.toInt();
    // The wall is a soft cream, from F7EFE3 at the top to F4EADB.
    final odd = <String>[];
    for (var y = 0; y < top; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final (r, g, b) = (
          bytes!.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
        if (r < 0xF2 || g < 0xE8 || b < 0xD8 || b > 0xE6) odd.add('($x, $y)');
      }
    }
    expect(odd, isEmpty, reason: 'not wall at ${odd.take(5).join(' ')}');
  });

  final picked = onlyBars.isEmpty
      ? bars
      : [for (final i in onlyBars.split(',')) bars[int.parse(i)]];
  for (final phone in picked) {
    testWidgets('nothing hides under the bars: ${phone.name}', (t) async {
      final ledger = await seededLedger(t, dir);
      t.view.devicePixelRatio = 3;
      t.view.physicalSize = phone.size * 3;
      t.view.padding = _pad(phone.safe);
      t.view.viewPadding = _pad(phone.safe);
      addTearDown(t.view.reset);
      final problems = <String>[];
      for (final MapEntry(key: name, value: open) in screens.entries) {
        await openScreen(t, lang: 'en', ledger: ledger, open: open);
        for (final p in underBars(t, phone.size, phone.safe)) {
          problems.add('$name: $p');
        }
        await closeScreen(t);
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
