import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/feel.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/remind.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late List<MethodCall> calls;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('remind');
    Prefs.current = Prefs.memory();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('spendsnap/remind'),
      (c) async {
        calls.add(c);
        return c.method == 'ask' ? true : null;
      },
    );
  });
  tearDown(() async => dir.delete(recursive: true));

  test('school hours are weekday mornings to 2:30 pm', () {
    expect(Feel.inSchoolHours(DateTime(2026, 11, 2, 10)), isTrue); // Monday
    expect(Feel.inSchoolHours(DateTime(2026, 11, 2, 7, 29)), isFalse);
    expect(Feel.inSchoolHours(DateTime(2026, 11, 2, 14, 30)), isFalse);
    expect(Feel.inSchoolHours(DateTime(2026, 11, 7, 10)), isFalse); // Saturday
    expect(Prefs.current.schoolQuiet, isTrue);
  });

  test('the reminder is off until she turns it on, then skips today once she logged', () async {
    final ledger = Ledger(dir);
    await Remind.sync(ledger);
    expect(calls.single.method, 'cancel');

    await Prefs.current.setReminder(on: true);
    await Remind.sync(ledger);
    expect(calls.last.arguments, {
      'hour': 21,
      'minute': 0,
      'skipToday': false,
      'lines': Remind.eveningLines,
    });

    await ledger.add(amount: 3.5, currency: 'SGD');
    await Prefs.current.setReminder(on: true, at: 20 * 60 + 30);
    await Remind.sync(ledger);
    expect(calls.last.arguments, {
      'hour': 20,
      'minute': 30,
      'skipToday': true,
      'lines': Remind.eveningLines,
    });
    await Prefs.current.setLanguage('zh');
    await Remind.sync(ledger);
    expect(
      ((calls.last.arguments as Map)['lines'] as List).first,
      contains('喵'),
    );
  });

  test('settings survive a restart', () async {
    final p = await Prefs.load(dir);
    await p.setReminder(on: true, at: 19 * 60);
    await p.setSchoolQuiet(false);
    await p.setAllowance(80);
    final again = await Prefs.load(dir);
    expect((again.reminderOn, again.reminderAt, again.schoolQuiet, again.allowance), (true, 19 * 60, false, 80.0));
  });
}
