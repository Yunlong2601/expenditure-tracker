import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/me_tab.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/theme.dart';

void main() {
  setUp(() => Prefs.current = Prefs.memory());

  final shares = <String>[];
  var canShare = false;
  setUp(() {
    shares.clear();
    canShare = false;
  });

  Future<void> open(WidgetTester tester, Widget Function(BuildContext) button) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: button))));

  testWidgets('feedback is copied when the share sheet is not there', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTinySheet<void>(
                context,
                (_) => FeedbackSheet(
                  share: (bytes, name) async {
                    shares.add(name);
                    return canShare;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('feedback-field')), 'Please add a dark cat');
    await tester.tap(find.byKey(const Key('sheet-Send')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('Please add a dark cat'));
    expect(copied, contains('Tiny Habits Cat'));
    expect(find.text('Copied. Paste it into a message to us.'), findsOneWidget);
    expect(find.byKey(const Key('feedback-field')), findsNothing);
    expect(shares, ['feedback.txt']);
  });

  testWidgets('feedback goes to the share sheet when there is one', (tester) async {
    canShare = true;
    await open(
      tester,
      (context) => TextButton(
        onPressed: () => showTinySheet<void>(
          context,
          (_) => FeedbackSheet(
            share: (bytes, name) async {
              shares.add(name);
              return canShare;
            },
          ),
        ),
        child: const Text('open'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Nothing written yet: Send does nothing.
    await tester.tap(find.byKey(const Key('sheet-Send')));
    await tester.pumpAndSettle();
    expect(shares, isEmpty);
    await tester.enterText(find.byKey(const Key('feedback-field')), 'Love it');
    await tester.tap(find.byKey(const Key('sheet-Send')));
    await tester.pumpAndSettle();
    expect(shares, ['feedback.txt']);
    expect(find.textContaining('Copied'), findsNothing);
    expect(find.byKey(const Key('feedback-field')), findsNothing);
  });
}
