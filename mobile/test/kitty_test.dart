import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/kitty.dart';

void main() {
  Widget app({bool still = false}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: still),
      child: KittyLayer(child: child!),
    ),
    home: Scaffold(
      body: Center(
        child: TextButton(onPressed: KittyLayer.cheer, child: const Text('Log')),
      ),
    ),
  );

  int painted(WidgetTester t) => find.byWidgetPredicate((w) => w is CustomPaint && w.painter != null).evaluate().length;

  for (final still in [false, true]) {
    testWidgets('paws and the cheering cat appear and then clear away${still ? ' (Reduce Motion)' : ''}', (t) async {
      await t.pumpWidget(app(still: still));
      final before = painted(t);

      await t.tap(find.text('Log'));
      await t.pump(const Duration(milliseconds: 300));
      // One paw burst for the tap, one cat.
      expect(painted(t), before + 2);

      await t.pumpAndSettle();
      expect(painted(t), before);
    });
  }

  testWidgets('dragging does not leave paw prints', (t) async {
    await t.pumpWidget(app());
    final before = painted(t);
    await t.dragFrom(const Offset(100, 100), const Offset(0, 200));
    await t.pump();
    expect(painted(t), before);
  });
}
