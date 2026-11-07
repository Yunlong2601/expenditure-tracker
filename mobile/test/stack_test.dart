import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/stack_sheet.dart';
import 'package:spendsnap/theme.dart';

void main() {
  late DayStore store;
  bool? saved;

  setUp(() {
    Prefs.current = Prefs.memory();
    store = DayStore.memory();
    DayStore.current = store;
    saved = null;
  });

  /// Opens the stack editor as the app does, in a tall sheet.
  Future<void> open(WidgetTester tester, {Task? task}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tinyTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showTinySheet<bool>(
                context,
                (_) => StackSheet(store: store, task: task),
                tall: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Taps a step card and types its name in the dialog.
  Future<void> name(WidgetTester tester, String card, String title) async {
    await tester.tap(find.text(card).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('step-field')), title);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  /// The ⋯ menu on the step card with this title.
  Finder menuOf(String step) => find.descendant(
    of: find.ancestor(of: find.text(step), matching: find.byType(Row)).last,
    matching: find.byTooltip('Step options'),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new stack gets a name and steps, and saves in order', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('0 of 1 step done'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('stack-title')), 'Morning');
    await name(tester, 'New step', 'Brush teeth');
    await tester.tap(find.byKey(const Key('add-step')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('step-field')), 'Pack bag');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 2 steps done'), findsOneWidget);
    await save(tester);

    expect(saved, isTrue);
    final t = store.tasks.single;
    expect(t.title, 'Morning');
    expect(t.isStack, isTrue);
    expect([for (final s in t.steps) s.title], ['Brush teeth', 'Pack bag']);
    expect(t.topStep?.title, 'Brush teeth');
  });

  testWidgets('with no name, the stack is called after its first step', (
    tester,
  ) async {
    await open(tester);
    await name(tester, 'New step', 'Feed the fish');
    await save(tester);
    expect(store.tasks.single.title, 'Feed the fish');
  });

  testWidgets('empty steps are dropped, and a cancelled step stays unnamed', (
    tester,
  ) async {
    await open(tester);
    await name(tester, 'New step', 'Read');
    await tester.tap(find.byKey(const Key('add-step')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('New step'), findsOneWidget);
    await save(tester);
    expect([for (final s in store.tasks.single.steps) s.title], ['Read']);
  });

  testWidgets('a new stack with no steps saves nothing', (tester) async {
    await open(tester);
    await save(tester);
    expect(store.tasks, isEmpty);
  });

  testWidgets('marking every step done finishes the stack; starting over '
      'brings it back', (tester) async {
    final t = await store.addTask(
      'Homework',
      steps: [StackStep('Maths'), StackStep('Reading')],
    );
    await open(tester, task: t);
    expect(find.text('Homework'), findsOneWidget);
    await tester.tap(find.byTooltip('All steps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all done'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 steps done'), findsOneWidget);
    await save(tester);
    expect(t.done, isTrue);
    expect(t.doneAt, isNotNull);

    await open(tester, task: t);
    await tester.tap(find.byTooltip('All steps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(t.done, isFalse);
    expect(t.doneAt, isNull);
    expect(t.topStep?.title, 'Maths');
  });

  testWidgets('a step can be ticked, renamed, given a note and deleted', (
    tester,
  ) async {
    final t = await store.addTask(
      'Room',
      steps: [StackStep('Bed'), StackStep('Desk'), StackStep('Floor')],
    );
    await open(tester, task: t);

    // Tick the first step from its own menu.
    await tester.tap(menuOf('Bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 steps done'), findsOneWidget);

    // Rename the second and write a note on it.
    await name(tester, 'Desk', 'Tidy desk');
    await tester.tap(find.text(' Note').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Pens in the cup');
    await tester.pump();

    // Delete the third.
    await tester.ensureVisible(find.text('Floor'));
    await tester.pumpAndSettle();
    await tester.tap(menuOf('Floor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete step'));
    await tester.pumpAndSettle();
    expect(find.text('Floor'), findsNothing);

    await save(tester);
    expect([for (final s in t.steps) s.title], ['Bed', 'Tidy desk']);
    expect(t.steps.first.done, isTrue);
    expect(t.steps[1].note, 'Pens in the cup');
    expect(t.topStep?.title, 'Tidy desk');
    expect(t.done, isFalse);
  });

  testWidgets('closing without saving changes nothing', (tester) async {
    final t = await store.addTask('Room', steps: [StackStep('Bed')]);
    await open(tester, task: t);
    await tester.tap(find.byTooltip('Step options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(t.steps.single.done, isFalse);
  });

  testWidgets('swiping a step away deletes it', (tester) async {
    final t = await store.addTask(
      'Room',
      steps: [StackStep('Bed'), StackStep('Desk')],
    );
    await open(tester, task: t);
    await tester.drag(find.text('Bed'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Bed'), findsNothing);
    await save(tester);
    expect([for (final s in t.steps) s.title], ['Desk']);
  });

  testWidgets('the ? explains how stacks work', (tester) async {
    await open(tester);
    expect(find.textContaining('Steps stacked'), findsNothing);
    await tester.tap(find.byTooltip('How stacks work'));
    await tester.pump();
    expect(find.textContaining('Steps stacked'), findsOneWidget);
  });
}
