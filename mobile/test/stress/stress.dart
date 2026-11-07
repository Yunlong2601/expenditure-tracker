// Every screen and sheet, on small and large iPhones, at normal and the
// largest standard text size. Any layout error (text or a row that doesn't
// fit) fails the test and names the screen. stress_test.dart runs it in
// English and light mode, stress_zh_test.dart in Chinese and dark mode, and
// the stress_big tests with text at 200%.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/chat.dart';
import 'package:spendsnap/companion.dart';
import 'package:spendsnap/dashboard.dart';
import 'package:spendsnap/day.dart';
import 'package:spendsnap/home_screen.dart';
import 'package:spendsnap/home_tab.dart';
import 'package:spendsnap/ledger.dart';
import 'package:spendsnap/me_tab.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/quick_add_sheet.dart';
import 'package:spendsnap/reader.dart';
import 'package:spendsnap/records.dart';
import 'package:spendsnap/settings_screen.dart';
import 'package:spendsnap/shell.dart';
import 'package:spendsnap/stack_sheet.dart';
import 'package:spendsnap/study.dart';
import 'package:spendsnap/study_screen.dart';
import 'package:spendsnap/summary.dart';
import 'package:spendsnap/theme.dart';

class _NoReader implements ReceiptReader {
  @override
  Future<ReadReceipt> read(image, {List<String> categories = const []}) =>
      throw ReadException('no reader in tests');
}

/// A phone: logical size and text scale.
typedef Phone = ({String name, Size size, double text});

const phones = <Phone>[
  (name: 'iPhone SE (1st gen)', size: Size(320, 568), text: 1.0),
  (name: 'iPhone SE', size: Size(375, 667), text: 1.0),
  (name: 'iPhone SE, largest text', size: Size(375, 667), text: 1.35),
  (name: 'iPhone 15 Pro, largest text', size: Size(393, 852), text: 1.35),
];

/// --dart-define=STRESS=Pet tab,Chat runs only those screens;
/// STRESS_PHONES=0,2 only those phones; STRESS_LOG=path writes progress there;
/// STRESS_TEXT=3.1 sets every phone's text size (3.1 is iOS's largest).
const only = String.fromEnvironment('STRESS');
const onlyPhones = String.fromEnvironment('STRESS_PHONES');
const log = String.fromEnvironment('STRESS_LOG');
const textSize = String.fromEnvironment('STRESS_TEXT');

/// The test font draws every letter as a square, about twice as wide as a
/// real one, so English would overflow everywhere. Load real fonts instead:
/// Roboto, which comes with Flutter, for English, and a Chinese font from
/// the computer when there is one. Both are a little narrower than the
/// iPhone's, which [stressAll] makes up for with slightly bigger text.
///
/// Chip and button labels whose theme style names no font still get the
/// test font's squares (on a phone they get the system font), so for them
/// this test errs on the wide side.
Future<void> loadFont(List<String> files) async {
  final l = FontLoader('Roboto');
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

/// Flutter's own copy of Roboto, next to the test runner.
List<String> roboto() {
  // .../bin/cache/artifacts/engine/<platform>/flutter_tester
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final files = [
    for (final w in ['Regular', 'Medium', 'Bold', 'Black'])
      '${artifacts.path}/material_fonts/Roboto-$w.ttf',
  ];
  final missing = files.where((f) => !File(f).existsSync());
  if (missing.isNotEmpty) throw StateError('Roboto not found: $missing');
  return files;
}

/// A Chinese font on this computer, if any.
String? chineseFont() => [
  '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
  '/System/Library/Fonts/PingFang.ttc',
].where((f) => File(f).existsSync()).firstOrNull;

const long =
    'Finish the science project poster with Mei and Arjun before Friday';

Future<void> seed(DayStore s) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  await s.addTask(
    long,
    minutes: 7 * 60 + 30,
    repeat: Repeat.weekdays,
    remind: true,
  );
  await s.addTask('Read', minutes: 20 * 60);
  await s.addTask('Secret plan', private: true);
  final done = await s.addTask('Feed the fish', repeat: Repeat.daily);
  await s.tick(s.occurrence(done, today));
  await s.addTask(
    'Morning routine for a very busy school day',
    steps: [
      StackStep('Brush teeth and wash face carefully'),
      StackStep(
        'Pack the school bag',
        note: 'Maths book, water bottle, the permission slip',
      ),
      StackStep('Breakfast'),
    ],
  );
  await s.addTask(
    'Piano lesson',
    day: today.add(const Duration(days: 1)),
    minutes: 16 * 60,
  );
  await s.addCountdown(
    'Mum’s birthday party at the big restaurant',
    today.add(const Duration(days: 47)),
    yearly: true,
  );
  await s.addCountdown('Met Mochi', today.subtract(const Duration(days: 120)));
  await s.add(s.moods, 'Great day at school with everyone', kind: 'happy');
  await s.add(s.focus, '25', kind: 'study');
  await s.add(s.focus, '6', kind: 'homework', left: 2, quit: true);
  await s.add(s.focus, '45', kind: long, left: 1);
  await s.add(s.timeline, 'Wake up');
  await s.add(
    s.notes,
    'Ideas for the art fair: paper lanterns, cat stickers and lemonade',
  );
  await s.add(
    s.memories,
    'Her best friend is called Mei and she loves drawing cats',
  );
  await s.add(s.chat, 'Hello Mochi! What should I do first today?', kind: 'me');
  await s.add(
    s.chat,
    'Start with the poster, one small part at a time. You’ve got this!',
    kind: 'cat',
  );
  await s.add(
    s.notebook,
    'Today she finished the poster and fed the fish. I’m proud of her.',
  );
}

/// Each screen or sheet, opened from a blank page.
final screens = <String, Opener>{
  'Pet tab': (t, c, s, l) async {},
  'Schedule': (t, c, s, l) async {
    await t.tap(find.byKey(const Key('tab-schedule')));
  },
  'Dashboard': (t, c, s, l) => t.tap(find.byType(NavigationDestination).at(1)),
  'Me': (t, c, s, l) => t.tap(find.byType(NavigationDestination).at(2)),
  'Records: Timeline': (t, c, s, l) => _push(c, RecordsScreen(store: s)),
  'Records: Focus': (t, c, s, l) => _push(c, RecordsScreen(store: s, tab: 1)),
  'Records: Notes': (t, c, s, l) => _push(c, RecordsScreen(store: s, tab: 2)),
  'Study view': (t, c, s, l) async {
    await Prefs.current.setStudyRule(StudyRule.lock.index);
    FocusSession.current.setSubject('homework');
    StudyScreen.open(c, s);
    FocusSession.current.appLeft(
      DateTime.now().subtract(const Duration(seconds: 5)),
    );
    await FocusSession.current.appBack();
  },
  'Study summary': (t, c, s, l) async {
    StudyScreen.open(c, s);
    await t.pump();
    await FocusSession.current.finish(quit: true);
  },
  'Guided Access steps': (t, c, s, l) => _sheet(c, (_) => const LockHelp()),
  'Chat': (t, c, s, l) async {
    await Prefs.current.setChatOn(true);
    await _push(c, ChatScreen(store: s));
  },
  'Chat consent': (t, c, s, l) => _sheet(c, (_) => const ConsentSheet()),
  'Check-ins': (t, c, s, l) =>
      _sheet(c, (_) => CheckInsSheet(store: s), tall: true),
  'What I remember': (t, c, s, l) =>
      _sheet(c, (_) => MemorySheet(store: s), tall: true),
  'Notebook': (t, c, s, l) =>
      _sheet(c, (_) => NotebookSheet(store: s), tall: true),
  'New task': (t, c, s, l) => _sheet(c, (_) => TaskSheet(store: s)),
  'Edit repeating task': (t, c, s, l) =>
      _sheet(c, (_) => TaskSheet(store: s, task: s.tasks.first)),
  'New stack': (t, c, s, l) =>
      _sheet(c, (_) => StackSheet(store: s), tall: true),
  'Edit stack': (t, c, s, l) => _sheet(
    c,
    (_) => StackSheet(store: s, task: s.tasks.firstWhere((x) => x.isStack)),
    tall: true,
  ),
  'Search tasks': (t, c, s, l) async {
    await _sheet(c, (_) => TaskSearchSheet(store: s), tall: true);
    await t.pump();
    await t.enterText(find.byKey(const Key('search-field')), 'e');
  },
  'Edit countdown': (t, c, s, l) async {
    editCountdown(c, s, s.countdowns.first);
  },
  'Mood': (t, c, s, l) async {
    showMoodSheet(c, s);
  },
  'Day sheet': (t, c, s, l) => _sheet(
    c,
    (_) => DaySheet(store: s, day: DateTime.now(), ledger: l),
    tall: true,
  ),
  'Completed': (t, c, s, l) => _sheet(
    c,
    (_) => CompletedSheet(store: s, day: DateTime.now()),
    tall: true,
  ),
  'Companion': (t, c, s, l) async {
    showCompanion(c);
  },
  'Feedback': (t, c, s, l) => _sheet(c, (_) => const FeedbackSheet()),
  'Money': (t, c, s, l) => _push(c, HomeScreen(ledger: l, reader: _NoReader())),
  'Cash entry': (t, c, s, l) => _sheet(c, (_) => const QuickAddSheet()),
  'Month picture': (t, c, s, l) => _push(c, SummaryScreen(ledger: l)),
  'Settings': (t, c, s, l) => _push(c, SettingsScreen(ledger: l)),
};

Future<void> _push(BuildContext c, Widget w) async {
  Navigator.of(c).push<void>(MaterialPageRoute(builder: (_) => w));
}

Future<void> _sheet(
  BuildContext c,
  WidgetBuilder b, {
  bool tall = false,
}) async {
  showTinySheet<void>(c, b, tall: tall);
}

typedef Opener = Future<void> Function(
  WidgetTester,
  BuildContext,
  DayStore,
  Ledger,
);

/// A ledger with two expenses, made outside test time: its first save
/// waits on a future made where it's built.
Future<Ledger> seededLedger(WidgetTester tester, Directory dir) async {
  late final Ledger ledger;
  await tester.runAsync(() async {
    ledger = Ledger(dir);
    await ledger.add(
      amount: 4.5,
      currency: 'SGD',
      merchant: 'Kopitiam at the hawker centre near school',
      category: 'Food & drink',
    );
    await ledger.add(
      amount: 1288,
      currency: 'CNY',
      merchant: '超市',
      category: 'Shopping',
    );
  });
  return ledger;
}

/// Starts the app fresh with a full day, then opens one screen and lets
/// it settle.
Future<void> openScreen(
  WidgetTester tester, {
  required String lang,
  required Ledger ledger,
  required Opener open,
}) async {
  Prefs.current = Prefs.memory();
  await Prefs.current.setOnboarded();
  await Prefs.current.setLanguage(lang);
  // The longest name the cat can be given (20 letters).
  await Prefs.current.setCatName('Mochi Marshmallow II');
  final s = DayStore.memory();
  DayStore.current = s;
  await seed(s);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: tinyTheme(Brightness.light),
      darkTheme: tinyTheme(Brightness.dark),
      home: AppShell(store: s, ledger: ledger),
    ),
  );
  await tester.pumpAndSettle();
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  await open(tester, nav.context, s, ledger);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Ends any study session and clears the screen, so the next one starts clean.
Future<void> closeScreen(WidgetTester tester) async {
  if (FocusSession.current.started) {
    await FocusSession.current.finish(early: true);
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Sets the phone's size, text size and light or dark. [size] is the text
/// size picked on the phone, when it isn't [phone]'s own.
void usePhone(
  WidgetTester tester,
  Phone phone, {
  double text = 1,
  double? size,
  bool dark = false,
}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = phone.size * 3;
  tester.platformDispatcher.textScaleFactorTestValue =
      (size ?? phone.text) * text;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// [text] sets every phone's text size, and [on] picks phones by their
/// place in [phones].
void stressAll({
  required String lang,
  required bool dark,
  required List<String> fonts,
  double? text,
  List<int>? on,
}) {
  final size = text ?? double.tryParse(textSize);
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (fonts.isNotEmpty) await loadFont(fonts);
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stress');
    CatFigure.animate = false;
  });
  tearDown(() async {
    final f = FocusSession.current;
    if (f.started) await f.finish(early: true);
    f.setSubject('study');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final picked = onlyPhones.isNotEmpty
      ? [for (final i in onlyPhones.split(',')) phones[int.parse(i)]]
      : [
          for (final (i, p) in phones.indexed)
            if (on == null || on.contains(i)) p,
        ];
  for (final phone in picked) {
    final label = size == null
        ? phone.name
        : '${phone.name.split(',').first}, ${(size * 100).round()}% text';
    testWidgets('every screen fits: $label, $lang${dark ? ', dark' : ''}', (
      tester,
    ) async {
      final problems = <String>[];
      final ledger = await seededLedger(tester, dir);
      // Real fonts here are about 6% narrower than the iPhone's.
      usePhone(
        tester,
        phone,
        text: fonts.isEmpty ? 1 : 1.06,
        size: size,
        dark: dark,
      );

      final saved = FlutterError.onError;
      var current = '';
      FlutterError.onError = (d) {
        final where = RegExp(r'lib/[a-z_]+\.dart:\d+')
            .allMatches(d.toString())
            .map((m) => m.group(0))
            .toSet()
            .take(2)
            .join(', ');
        problems.add(
          '$current: ${d.exceptionAsString().split('\n').first} ($where)',
        );
      };
      try {
        for (final MapEntry(key: name, value: open) in screens.entries) {
          if (only.isNotEmpty && !only.split(',').contains(name)) continue;
          current = name;
          if (log.isNotEmpty) {
            File(log).writeAsStringSync(
              '${DateTime.now()} ${phone.name} $lang $name\n',
              mode: FileMode.append,
            );
          }
          await openScreen(tester, lang: lang, ledger: ledger, open: open);
          // A screen whose layout already failed can leave lists half laid
          // out, and walking them would throw before the problems are shown.
          if (problems.any((p) => p.startsWith('$current: '))) {
            await closeScreen(tester);
            continue;
          }
          // Scroll every list to its end a screen at a time, so each row of
          // a long list is laid out on the way, not only its top and bottom.
          for (final sc in find.byType(Scrollable).evaluate().toList()) {
            // Scrolling one list can take another (one inside it) away.
            if (!sc.mounted) continue;
            final st = (sc as StatefulElement).state as ScrollableState;
            for (var step = 0; step < 40 && sc.mounted; step++) {
              final p = st.position;
              final end = p.maxScrollExtent;
              if (!end.isFinite || p.pixels >= end) break;
              p.jumpTo(
                (p.pixels + p.viewportDimension * 0.8).clamp(0.0, end),
              );
              await tester.pump();
            }
          }
          await closeScreen(tester);
        }
      } finally {
        FlutterError.onError = saved;
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
