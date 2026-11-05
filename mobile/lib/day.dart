import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'l10n.dart';

String _id() =>
    '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// One step of a stack. The list shows only the first step not yet done.
class StackStep {
  StackStep(this.title, {this.done = false, this.note});
  String title;
  bool done;
  String? note;

  factory StackStep.fromJson(Map<String, dynamic> j) => StackStep(
    j['title'] as String,
    done: j['done'] == true,
    note: j['note'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    if (done) 'done': true,
    if (note != null) 'note': note,
  };
}

/// Something to do on a day, at an optional time. With steps it is a stack.
class Task {
  Task({
    String? id,
    required this.title,
    required this.day,
    this.minutes,
    this.done = false,
    this.doneAt,
    this.note,
    this.private = false,
    List<StackStep>? steps,
  }) : id = id ?? _id(),
       steps = steps ?? [];

  final String id;
  String title;
  DateTime day;

  /// Minutes after midnight, or null for no set time.
  int? minutes;
  bool done;
  DateTime? doneAt;
  String? note;

  /// Private tasks stay out of what the cat reads and shares.
  bool private;
  final List<StackStep> steps;

  bool get isStack => steps.isNotEmpty;
  int get stepsDone => steps.where((s) => s.done).length;

  /// The step shown on the list: the first one not checked off yet.
  StackStep? get topStep => steps.where((s) => !s.done).firstOrNull;

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    title: j['title'] as String,
    day: DateTime.parse(j['day'] as String),
    minutes: (j['minutes'] as num?)?.toInt(),
    done: j['done'] == true,
    doneAt: j['done_at'] == null
        ? null
        : DateTime.parse(j['done_at'] as String),
    note: j['note'] as String?,
    private: j['private'] == true,
    steps: [
      for (final s in (j['steps'] as List? ?? const []))
        StackStep.fromJson((s as Map).cast()),
    ],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'day': dayOf(day).toIso8601String(),
    if (minutes != null) 'minutes': minutes,
    if (done) 'done': true,
    if (doneAt != null) 'done_at': doneAt!.toIso8601String(),
    if (note != null) 'note': note,
    if (private) 'private': true,
    if (steps.isNotEmpty) 'steps': [for (final s in steps) s.toJson()],
  };
}

/// The six moods of the mood diary, in the order shown.
enum Mood {
  happy('Happy', '开心'),
  calm('Calm', '平静'),
  okay('Okay', '一般'),
  tired('Tired', '疲惫'),
  low('Low', '低落'),
  anxious('Anxious', '焦虑');

  const Mood(this.label, this.zh);
  final String label, zh;
}

/// A dated thing with a kind and text: moods, timeline entries, notes, chat lines.
class Entry {
  Entry({String? id, required this.at, required this.text, this.kind})
    : id = id ?? _id();
  final String id;
  final DateTime at;
  String text;

  /// Mood name for moods, "me" or "cat" for chat lines.
  final String? kind;

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    text: j['text'] as String,
    kind: j['kind'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'text': text,
    if (kind != null) 'kind': kind,
  };
}

/// A date to count down to.
class Countdown {
  Countdown({String? id, required this.title, required this.date})
    : id = id ?? _id();
  final String id;
  String title;
  DateTime date;

  int daysLeft([DateTime? now]) =>
      dayOf(date).difference(dayOf(now ?? DateTime.now())).inDays;

  factory Countdown.fromJson(Map<String, dynamic> j) => Countdown(
    id: j['id'] as String,
    title: j['title'] as String,
    date: DateTime.parse(j['date'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': dayOf(date).toIso8601String(),
  };
}

/// A check-in the cat sends at a time each day: see progress, cheer you on, review together.
class CheckIn {
  CheckIn({String? id, required this.kind, required this.minutes})
    : id = id ?? _id();
  final String id;
  final int kind;
  int minutes;

  static const kinds = [
    'See how it’s going',
    'Cheer me on',
    'Review the day together',
  ];
  static const kindsZh = ['看看进展', '给我鼓励', '一起复盘'];

  /// The kind's name in the app's language.
  static String label(int kind) => (zh ? kindsZh : kinds)[kind];

  factory CheckIn.fromJson(Map<String, dynamic> j) => CheckIn(
    id: j['id'] as String,
    kind: (j['kind'] as num).toInt(),
    minutes: (j['minutes'] as num).toInt(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'minutes': minutes};
}

/// Everything that isn't money: tasks, moods, focus, timeline, notes, countdowns
/// and the cat's chat. One JSON file next to the expenses, on the phone only.
class DayStore extends ChangeNotifier {
  DayStore(this._file);
  DayStore.memory() : _file = null;

  static DayStore current = DayStore.memory();

  final File? _file;
  final tasks = <Task>[];
  final moods = <Entry>[];
  final timeline = <Entry>[];
  final notes = <Entry>[];
  final chat = <Entry>[];
  final memories = <Entry>[];
  final notebook = <Entry>[];
  final countdowns = <Countdown>[];
  final checkIns = <CheckIn>[];

  /// Finished focus sessions: [Entry.text] holds the minutes.
  final focus = <Entry>[];
  bool checkInsPaused = false;

  static Future<DayStore> load(Directory dir) async {
    final s = DayStore(File('${dir.path}/day.json'));
    try {
      if (await s._file!.exists()) {
        s._read((jsonDecode(await s._file.readAsString()) as Map).cast());
      }
    } on FormatException catch (_) {}
    return current = s;
  }

  void _read(Map<String, dynamic> j) {
    List<Entry> entries(String k) => [
      for (final e in (j[k] as List? ?? const []))
        Entry.fromJson((e as Map).cast()),
    ];
    tasks
      ..clear()
      ..addAll([
        for (final t in (j['tasks'] as List? ?? const []))
          Task.fromJson((t as Map).cast()),
      ]);
    for (final (list, key) in [
      (moods, 'moods'),
      (timeline, 'timeline'),
      (notes, 'notes'),
      (chat, 'chat'),
      (memories, 'memories'),
      (notebook, 'notebook'),
      (focus, 'focus'),
    ]) {
      list
        ..clear()
        ..addAll(entries(key));
    }
    countdowns
      ..clear()
      ..addAll([
        for (final c in (j['countdowns'] as List? ?? const []))
          Countdown.fromJson((c as Map).cast()),
      ]);
    checkIns
      ..clear()
      ..addAll([
        for (final c in (j['check_ins'] as List? ?? const []))
          CheckIn.fromJson((c as Map).cast()),
      ]);
    checkInsPaused = j['check_ins_paused'] == true;
  }

  Map<String, dynamic> toJson() => {
    'tasks': [for (final t in tasks) t.toJson()],
    'moods': [for (final e in moods) e.toJson()],
    'timeline': [for (final e in timeline) e.toJson()],
    'notes': [for (final e in notes) e.toJson()],
    'chat': [for (final e in chat) e.toJson()],
    'memories': [for (final e in memories) e.toJson()],
    'notebook': [for (final e in notebook) e.toJson()],
    'focus': [for (final e in focus) e.toJson()],
    'countdowns': [for (final c in countdowns) c.toJson()],
    'check_ins': [for (final c in checkIns) c.toJson()],
    if (checkInsPaused) 'check_ins_paused': true,
  };

  Future<void> restore(Map<String, dynamic> j) async {
    _read(j);
    await save();
  }

  /// Writes the file and tells every screen to redraw.
  Future<void> save() {
    notifyListeners();
    final f = _file;
    if (f == null) return Future.value();
    final text = jsonEncode(toJson());
    // One write at a time, each to a temp file then renamed over day.json,
    // so a crash mid-write can't leave a half-written file behind.
    // A failed write doesn't block the next one.
    return _writing = _writing.catchError((Object _) {}).then((_) async {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(f.path);
    });
  }

  Future<void> _writing = Future.value();

  // Tasks.

  /// The day's tasks: timed ones by time, then the rest in the order added.
  List<Task> tasksOn(DateTime day) {
    final list = tasks.where((t) => sameDay(t.day, day)).toList();
    list.sort((a, b) => (a.minutes ?? 99999).compareTo(b.minutes ?? 99999));
    return list;
  }

  List<Task> doneOn(DateTime day) =>
      tasks
          .where((t) => t.done && t.doneAt != null && sameDay(t.doneAt!, day))
          .toList()
        ..sort((a, b) => a.doneAt!.compareTo(b.doneAt!));

  Future<Task> addTask(
    String title, {
    DateTime? day,
    int? minutes,
    List<StackStep>? steps,
    bool private = false,
  }) async {
    final t = Task(
      title: title,
      day: dayOf(day ?? DateTime.now()),
      minutes: minutes,
      private: private,
      steps: steps,
    );
    tasks.add(t);
    await save();
    return t;
  }

  /// Ticks a task, or the top step of a stack. A stack is done with its last step.
  Future<void> tick(Task t, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final top = t.topStep;
    if (top != null) {
      top.done = true;
      if (t.topStep == null) {
        t.done = true;
        t.doneAt = at;
      }
    } else {
      t.done = !t.done;
      t.doneAt = t.done ? at : null;
    }
    unlockNextPart(t, now: at);
    await save();
  }

  Future<void> removeTask(Task t) async {
    tasks.remove(t);
    await save();
  }

  /// The guided list from the welcome cards, added once.
  Future<void> addGettingStarted() async {
    if (tasks.any(isGettingStarted)) return;
    await addTask(
      gettingStartedTitle,
      steps: [for (final s in gettingStartedSteps) StackStep(s)],
    );
  }

  /// When a Getting started part is finished, puts the next part on today's
  /// list, so the guide goes "one short part at a time" (IMG_6795, 6797).
  /// Returns whether a part was added. Doesn't save.
  bool unlockNextPart(Task t, {DateTime? now}) {
    final part = gettingStartedPart(t);
    if (!t.done || part == null || part + 1 >= _parts.length) return false;
    if (tasks.any((x) => gettingStartedPart(x) == part + 1)) return false;
    tasks.add(
      Task(
        title: partTitle(part + 1),
        day: dayOf(now ?? DateTime.now()),
        steps: [for (final s in partSteps(part + 1)) StackStep(s)],
      ),
    );
    return true;
  }

  static const _parts = [
    (
      en: 'Part 1 · Plan your day',
      zh: '第一部分 · 安排你的一天',
      stepsEn: [
        'Tap + to add something for today',
        'Tap the time on the right to set when',
        'Tap the circle on the left when it’s done',
        'Hold + and drag down to make a stack',
        'Tap this task to see how stacks work',
        'Swipe in from the right edge to start a focus',
      ],
      stepsZh: [
        '点 + 添加今天要做的事',
        '点右边的时间，设定什么时候做',
        '做完了就点左边的圆圈',
        '按住 + 往下拖，做成一叠',
        '点这件事，看看一叠是怎么用的',
        '从屏幕右边缘往里滑，开始专注',
      ],
    ),
    (
      en: 'Part 2 · Look back on your day',
      zh: '第二部分 · 回顾你的一天',
      stepsEn: [
        'Tap Log mood under your list and pick how you feel',
        'Open Dashboard to see today’s review',
        'Tap Completed › to see what you finished',
        'Tap a day on the calendar, then its + to plan ahead',
        'Swipe in from the right edge and write what you’re doing now',
      ],
      stepsZh: [
        '点清单下面的「记心情」，选一下现在的心情',
        '打开「看板」，看看今日复盘',
        '点「完成记录 ›」，看看做完了什么',
        '在日历上点一天，再点它的 +，提前安排',
        '从右边缘滑进来，写下现在在做什么',
      ],
    ),
    (
      en: 'Part 3 · Get to know your cat',
      zh: '第三部分 · 认识你的小猫',
      stepsEn: [
        'Swipe in from the left edge to chat with me',
        'Tap ⋯ in the chat and set a check-in time',
        'Tell me one thing to remember in What I remember',
        'In Me, tap my name to give me a new one',
        'Pick a theme and a language in Me',
      ],
      stepsZh: [
        '从左边缘滑进来，和我聊聊天',
        '在聊天里点 ⋯，设一个定时约定',
        '在「宠物记忆」里告诉我一件要记住的事',
        '在「我」里点我的名字，给我起个新名字',
        '在「我」里选一下主题和语言',
      ],
    ),
  ];

  /// Which Getting started part [t] is (0 for Part 1), or null.
  static int? gettingStartedPart(Task? t) {
    if (t == null) return null;
    for (final (i, p) in _parts.indexed) {
      if (t.title == p.en || t.title == p.zh) return i;
    }
    return null;
  }

  static bool isGettingStarted(Task? t) => gettingStartedPart(t) != null;
  static int get gettingStartedParts => _parts.length;
  static String partTitle(int i) => zh ? _parts[i].zh : _parts[i].en;
  static List<String> partSteps(int i) =>
      zh ? _parts[i].stepsZh : _parts[i].stepsEn;
  static String get gettingStartedTitle => partTitle(0);
  static List<String> get gettingStartedSteps => partSteps(0);

  // Moods and the rest.

  Future<void> addMood(Mood m, {DateTime? at, String? note}) async {
    moods.add(Entry(at: at ?? DateTime.now(), text: note ?? '', kind: m.name));
    await save();
  }

  List<Entry> moodsOn(DateTime day) =>
      moods.where((e) => sameDay(e.at, day)).toList();

  /// The last mood logged that day, for the calendar and the 7-day row.
  Mood? moodOf(DateTime day) {
    final list = moodsOn(day);
    if (list.isEmpty) return null;
    return Mood.values.asNameMap()[list.last.kind];
  }

  Future<void> add(
    List<Entry> list,
    String text, {
    DateTime? at,
    String? kind,
  }) async {
    list.add(Entry(at: at ?? DateTime.now(), text: text, kind: kind));
    await save();
  }

  Future<void> remove(List<Object> list, Object item) async {
    list.remove(item);
    await save();
  }

  int focusMinutesOn(DateTime day) => focus
      .where((e) => sameDay(e.at, day))
      .fold(0, (n, e) => n + (int.tryParse(e.text) ?? 0));

  Future<void> addCountdown(String title, DateTime date) async {
    countdowns
      ..add(Countdown(title: title, date: date))
      ..sort((a, b) => a.date.compareTo(b.date));
    await save();
  }

  /// Countdowns still to come, nearest first.
  List<Countdown> upcoming([DateTime? now]) =>
      countdowns.where((c) => c.daysLeft(now) >= 0).toList();
}
