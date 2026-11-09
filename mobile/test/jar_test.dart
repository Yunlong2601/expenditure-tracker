import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/home_screen.dart';
import 'package:spendsnap/jar.dart';
import 'package:spendsnap/l10n.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/reader.dart';

class _NoReader implements ReceiptReader {
  @override
  Future<ReadReceipt> read(
    Uint8List image, {
    List<String> categories = const [],
  }) => throw ReadException('No');
}

void main() {
  setUp(() => Prefs.current = Prefs.memory());

  group('the pocket money jar', () {
    test('counts what is left in bubble teas', () {
      expect(treatsLeft(12), 'Mochi: that’s about 3 bubble teas.');
      expect(treatsLeft(4), 'Mochi: that’s about 1 bubble tea.');
      expect(treatsLeft(2.5), 'Mochi: enough for a snack.');
      expect(treatsLeft(0.4), 'Mochi: just some coins left.');
      expect(treatsLeft(0), isNull);
      expect(treatsLeft(-3), isNull);
    });

    test('speaks Chinese too', () async {
      await Prefs.current.setLanguage('zh');
      expect(zh, isTrue);
      expect(treatsLeft(12), 'Mochi：大概还够买 3 杯奶茶。');
    });

    test('goal pictures are guessed from the name, in both languages', () {
      expect(goalPicFor('AirPods'), '🎧');
      expect(goalPicFor('Nintendo Switch game'), '🎮');
      expect(goalPicFor('Concert tickets'), '🎟️');
      expect(goalPicFor('演唱会门票'), '🎟️');
      expect(goalPicFor('新鞋'), '👟');
      expect(goalPicFor('Something nice'), '⭐');
      expect(goalPics, contains('⭐'));
    });
  });

  group('on the money screen', () {
    late Directory dir;
    late Ledger ledger;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('jar');
      ledger = Ledger(dir);
    });
    tearDown(() async {
      await ledger.idle.timeout(const Duration(seconds: 3), onTimeout: () {});
      await dir.delete(recursive: true);
    });

    Widget app() => MaterialApp(
      home: HomeScreen(ledger: ledger, reader: _NoReader()),
    );

    testWidgets('the jar shows what is left, and the cat counts treats', (
      t,
    ) async {
      await t.runAsync(() async {
        await Prefs.current.setAllowance(80);
        await ledger.add(amount: 68, currency: 'SGD', category: 'Shopping');
      });
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final jar = t.widget<Jar>(find.byKey(const Key('money-jar')));
      expect(jar.fill, closeTo(12 / 80, 0.001));
      expect(find.text('Mochi: that’s about 3 bubble teas.'), findsOneWidget);
      expect(find.byKey(const Key('cat-worried')), findsOneWidget);
    });

    testWidgets('no treats when it is all spent', (t) async {
      await t.runAsync(() async {
        await Prefs.current.setAllowance(10, daily: true);
        await ledger.add(amount: 12, currency: 'SGD', category: 'Shopping');
      });
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(t.widget<Jar>(find.byKey(const Key('money-jar'))).fill, 0);
      expect(find.byKey(const Key('treats-left')), findsNothing);
    });

    testWidgets('a savings goal gets a picture, guessed or picked', (t) async {
      await t.runAsync(
        () => Prefs.current.setGoal('AirPods', target: 200, saved: 50),
      );
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('🎧'), findsOneWidget);
      expect(t.widget<Jar>(find.byKey(const Key('goal-jar'))).fill, 0.25);

      // She picks the phone instead, and keeps what she has saved.
      await t.tap(find.byKey(const Key('goal')));
      await t.pumpAndSettle();
      expect(
        t.widget<ChoiceChip>(find.byKey(const Key('goal-pic-🎧'))).selected,
        isTrue,
      );
      await t.tap(find.byKey(const Key('goal-pic-📱')));
      await t.pump();
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('goal-save')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(Prefs.current.goalPic, '📱');
      expect(Prefs.current.goalSaved, 50);
      expect(
        find.descendant(
          of: find.byKey(const Key('goal-jar')),
          matching: find.text('📱'),
        ),
        findsOneWidget,
      );
    });
  });
}
