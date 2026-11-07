import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/brain.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/settings_screen.dart';
import 'package:spendsnap/summary.dart';

void main() {
  late Directory dir;
  late DayStore store;
  late List<MethodCall> shared;
  late List<MethodCall> reminded;
  late bool allowNotify;
  String? picked;
  var reminderChanged = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings');
    Prefs.current = Prefs.memory();
    store = DayStore.memory();
    DayStore.current = store;
    shared = [];
    reminded = [];
    allowNotify = true;
    picked = null;
    reminderChanged = 0;
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('spendsnap/remind'), (
      c,
    ) async {
      reminded.add(c);
      return c.method == 'ask' ? allowNotify : null;
    });
    m.setMockMethodCallHandler(const MethodChannel('spendsnap/share'), (
      c,
    ) async {
      shared.add(c);
      return c.method == 'pick' ? picked : true;
    });
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (c) async => dir.path,
    );
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// A ledger with one expense, made outside test time.
  Future<Ledger> ledgerWithOne(WidgetTester tester) async {
    late final Ledger l;
    await tester.runAsync(() async {
      l = Ledger(Directory('${dir.path}/ledger'));
      await l.add(amount: 3.2, currency: 'SGD', merchant: 'Canteen');
    });
    return l;
  }

  /// Shows Settings on a tall screen, so every row in the list is built.
  Future<void> show(
    WidgetTester tester, {
    Ledger? ledger,
    VoidCallback? onExport,
  }) {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          ledger: ledger,
          onExport: onExport,
          onReminderChanged: () => reminderChanged++,
        ),
      ),
    );
  }

  /// Taps something whose work writes or reads real files.
  Future<void> tapReal(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('the evening reminder needs permission, then can be timed', (
    tester,
  ) async {
    await show(tester);
    expect(find.byKey(const Key('reminder-time')), findsNothing);

    allowNotify = false;
    await tester.tap(find.byKey(const Key('reminder')));
    await tester.pumpAndSettle();
    expect(Prefs.current.reminderOn, isFalse);
    expect(find.textContaining('Allow notifications'), findsOneWidget);
    // The message takes her straight to the app's notifications in Settings.
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(
      reminded.last,
      isMethodCall('openSettings', arguments: 'notifications'),
    );

    allowNotify = true;
    await tester.tap(find.byKey(const Key('reminder')));
    await tester.pumpAndSettle();
    expect(Prefs.current.reminderOn, isTrue);
    expect(reminderChanged, 1);
    expect(find.text('Remind me at 9:00 PM'), findsOneWidget);

    // Type 9:45 in the clock's keyboard mode.
    await tester.tap(find.byKey(const Key('reminder-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '45');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(Prefs.current.reminderAt, 21 * 60 + 45);
    expect(reminderChanged, 2);
    expect(find.text('Remind me at 9:45 PM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder')));
    await tester.pumpAndSettle();
    expect(Prefs.current.reminderOn, isFalse);
    expect(find.byKey(const Key('reminder-time')), findsNothing);
  });

  testWidgets('quiet during school hours is remembered', (tester) async {
    await show(tester);
    final was = Prefs.current.schoolQuiet;
    await tester.tap(find.byKey(const Key('school-quiet')));
    await tester.pumpAndSettle();
    expect(Prefs.current.schoolQuiet, !was);
  });

  testWidgets('pocket money is set from its row', (tester) async {
    await show(tester);
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-allowance')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('allowance-amount')), '20');
    await tester.tap(find.byKey(const Key('allowance-save')));
    await tester.pumpAndSettle();
    expect(Prefs.current.allowance, 20);
    expect(find.textContaining('a week'), findsOneWidget);
  });

  testWidgets('money parts are hidden without the Money module', (
    tester,
  ) async {
    await show(tester);
    for (final k in ['summary', 'backup', 'restore', 'export']) {
      expect(find.byKey(Key(k)), findsNothing);
    }
    expect(find.textContaining('never sent anywhere'), findsOneWidget);
  });

  testWidgets('the privacy note matches what the chat sends in this build', (
    tester,
  ) async {
    // Chat on the phone only: nothing about sending.
    await show(tester);
    expect(find.textContaining('Chatting with the cat'), findsNothing);

    // With the online brain built in, it says what's sent, as the chat's
    // own consent sheet does.
    CatBrain.current = CatBrain(Uri.parse('https://cat.example/chat'));
    addTearDown(() => CatBrain.current = null);
    await tester.pumpWidget(const SizedBox());
    await show(tester);
    expect(
      find.textContaining('sends only what it showed you'),
      findsOneWidget,
    );
  });

  testWidgets('export copies, and the month picture opens', (tester) async {
    final l = await ledgerWithOne(tester);
    var exported = 0;
    await show(tester, ledger: l, onExport: () => exported++);
    await tester.ensureVisible(find.byKey(const Key('export')));
    await tester.tap(find.byKey(const Key('export')));
    expect(exported, 1);
    await tester.tap(find.byKey(const Key('summary')));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
  });

  testWidgets('back up shares one file with expenses, settings and the day', (
    tester,
  ) async {
    final l = await ledgerWithOne(tester);
    await Prefs.current.setCatName('Biscuit');
    await store.addTask('Feed the fish');
    await show(tester, ledger: l);
    await tapReal(tester, find.byKey(const Key('backup')));

    final call = shared.singleWhere((c) => c.method == 'file');
    final path = call.arguments as String;
    expect(path, contains('TinyHabitsCat-backup-'));
    late final Map<String, Object?> data;
    await tester.runAsync(() async {
      data = (jsonDecode(await File(path).readAsString()) as Map)
          .cast<String, Object?>();
    });
    expect(Ledger.backupSize(data), 1);
    expect((data['prefs']! as Map)['cat_name'], 'Biscuit');
    expect(jsonEncode(data['day']), contains('Feed the fish'));
    expect(find.textContaining('Backed up'), findsOneWidget);
  });

  testWidgets('restore asks first, then brings everything back', (
    tester,
  ) async {
    // A backup from "another phone".
    final l = await ledgerWithOne(tester);
    late final String file;
    await tester.runAsync(() async {
      final data = await l.backup();
      data['prefs'] = {'cat_name': 'Biscuit'};
      final other = DayStore.memory();
      await other.addTask('Feed the fish');
      data['day'] = other.toJson();
      file = '${dir.path}/backup.json';
      await File(file).writeAsString(jsonEncode(data));
    });

    // This phone has nothing yet.
    late final Ledger here;
    await tester.runAsync(
      () async => here = Ledger(Directory('${dir.path}/here')),
    );
    await show(tester, ledger: here);

    picked = file;
    await tapReal(tester, find.byKey(const Key('restore')));
    expect(find.text('Restore this backup?'), findsOneWidget);
    expect(find.textContaining('It has 1 expense.'), findsOneWidget);

    // Cancel keeps this phone as it was.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(here.all, isEmpty);

    await tapReal(tester, find.byKey(const Key('restore')));
    await tapReal(tester, find.byKey(const Key('restore-yes')));
    expect(here.all.single.merchant, 'Canteen');
    expect(Prefs.current.catName, 'Biscuit');
    expect(store.tasks.single.title, 'Feed the fish');
    expect(reminderChanged, 1);
    expect(find.text('Restored 1 expense.'), findsOneWidget);
  });

  testWidgets('a file that isn\'t a backup is turned away', (tester) async {
    final l = await ledgerWithOne(tester);
    await tester.runAsync(() async {
      picked = '${dir.path}/notes.json';
      await File(picked!).writeAsString('{"hello": "world"}');
    });
    await show(tester, ledger: l);
    await tapReal(tester, find.byKey(const Key('restore')));
    expect(
      find.textContaining("isn't a Tiny Habits Cat backup"),
      findsOneWidget,
    );
    expect(l.all, hasLength(1));
  });

  testWidgets('cancelling the file picker does nothing', (tester) async {
    final l = await ledgerWithOne(tester);
    await show(tester, ledger: l);
    await tapReal(tester, find.byKey(const Key('restore')));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
