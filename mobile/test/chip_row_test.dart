import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/theme.dart';

void main() {
  testWidgets('chips stay on one line and scroll when they do not fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: ChipRow(
                children: [
                  for (final s in ['Study', 'Homework', 'Reading', 'Revision'])
                    Chip(label: Text(s)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final ys = {
      for (final c in tester.widgetList<Chip>(find.byType(Chip)))
        tester.getTopLeft(find.byWidget(c)).dy,
    };
    expect(ys, hasLength(1), reason: 'no chip on a line of its own');
    final last = find.widgetWithText(Chip, 'Revision');
    expect(tester.getTopRight(last).dx, greaterThan(500));
    await tester.drag(find.byType(ChipRow), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopRight(last).dx, lessThanOrEqualTo(500));
  });
}
