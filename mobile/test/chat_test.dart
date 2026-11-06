import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/chat.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';

void main() {
  setUp(() => Prefs.current = Prefs.memory());

  testWidgets('the consent note says what goes to the AI when it is on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConsentSheet(online: true))));
    expect(find.textContaining('DeepSeek'), findsOneWidget);
    expect(find.textContaining('AI can make mistakes'), findsOneWidget);
    expect(find.textContaining('Spending and private tasks stay on your phone'), findsOneWidget);
    expect(find.text('Nothing leaves your phone'), findsNothing);
  });

  testWidgets('the consent note promises on-phone replies without the AI', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConsentSheet(online: false))));
    expect(find.text('Nothing leaves your phone'), findsOneWidget);
    expect(find.textContaining('DeepSeek'), findsNothing);
  });

  testWidgets('the cat shows typing dots, then replies', (tester) async {
    await Prefs.current.setChatOn(true);
    final s = DayStore.memory();
    await tester.pumpWidget(MaterialApp(home: ChatScreen(store: s)));
    await tester.enterText(find.byKey(const Key('chat-field')), 'what’s left?');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    final typing = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Typing');
    expect(typing, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(typing, findsNothing);
    expect(find.text('Your list is empty. Want to add one small thing?'), findsOneWidget);
    expect(s.chat.map((e) => e.kind), ['me', 'cat']);
  });


  testWidgets('asking the cat to remind you puts the task on the list', (tester) async {
    await Prefs.current.setChatOn(true);
    final s = DayStore.memory();
    await tester.pumpWidget(MaterialApp(home: ChatScreen(store: s)));
    await tester.enterText(find.byKey(const Key('chat-field')), 'add buy milk');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(s.tasks.single.title, 'Buy milk');
    expect(find.text('Added “Buy milk” today.'), findsOneWidget);
  });
}
