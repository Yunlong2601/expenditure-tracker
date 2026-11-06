import 'dart:convert';
import 'dart:io';

/// Her settings, kept in a small file next to the expenses.
class Prefs {
  Prefs._(this._file, this._values);

  /// Settings kept only in memory, as in tests.
  Prefs.memory() : this._(null, {});

  static Prefs current = Prefs.memory();

  final File? _file;
  final Map<String, Object?> _values;

  static Future<Prefs> load(Directory dir) async {
    final f = File('${dir.path}/prefs.json');
    var values = <String, Object?>{};
    try {
      if (await f.exists()) values = (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>();
    } on FormatException catch (_) {}
    return current = Prefs._(f, values);
  }

  Future<void> _set(String key, Object? value) async {
    value == null ? _values.remove(key) : _values[key] = value;
    final f = _file;
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(_values), flush: true);
  }

  /// Everything, for a backup.
  Map<String, Object?> toJson() => Map.of(_values);

  /// Replaces every setting with the ones from a backup.
  Future<void> restore(Map<String, Object?> values) async {
    _values
      ..clear()
      ..addAll(values);
    final f = _file;
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(_values), flush: true);
  }

  /// Pocket money in S$, per [allowanceDaily] day or else per week. Null when not set.
  double? get allowance => (_values['allowance'] as num?)?.toDouble();
  bool get allowanceDaily => _values['allowance_daily'] == true;
  Future<void> setAllowance(double? amount, {bool daily = false}) async {
    await _set('allowance', amount);
    await _set('allowance_daily', daily ? true : null);
  }

  /// The cat's evening reminder, at [reminderAt] minutes after midnight.
  bool get reminderOn => _values['reminder'] == true;
  int get reminderAt => (_values['reminder_at'] as num?)?.toInt() ?? 21 * 60;
  Future<void> setReminder({required bool on, int? at}) async {
    await _set('reminder', on ? true : null);
    if (at != null) await _set('reminder_at', at);
  }

  /// No sounds on weekdays from 7:30 am to 2:30 pm. On unless she turns it off.
  bool get schoolQuiet => _values['school_quiet'] != false;
  Future<void> setSchoolQuiet(bool v) => _set('school_quiet', v ? null : false);

  /// What she's saving for, how much it costs and how much is in the jar.
  String? get goalName => _values['goal_name'] as String?;
  double get goalTarget => (_values['goal_target'] as num?)?.toDouble() ?? 0;
  double get goalSaved => (_values['goal_saved'] as num?)?.toDouble() ?? 0;
  Future<void> setGoal(String? name, {double target = 0, double saved = 0}) async {
    await _set('goal_name', name);
    await _set('goal_target', name == null ? null : target);
    await _set('goal_saved', name == null ? null : saved);
  }

  Future<void> addToGoal(double amount) =>
      _set('goal_saved', ((goalSaved + amount).clamp(0, double.infinity) * 100).round() / 100);

  /// The home screen shows the whole month, else the allowance period.
  bool get showMonth => _values['show_month'] == true || allowance == null;
  Future<void> setShowMonth(bool v) => _set('show_month', v ? true : null);

  /// Saw the three welcome cards.
  bool get onboarded => _values['onboarded'] == true;
  Future<void> setOnboarded() => _set('onboarded', true);

  /// What she calls the cat.
  String get catName => (_values['cat_name'] as String?) ?? 'Mochi';
  Future<void> setCatName(String v) => _set('cat_name', v.trim().isEmpty ? null : v.trim());

  /// Agreed to chat with the cat.
  bool get chatOn => _values['chat_on'] == true;
  Future<void> setChatOn(bool v) => _set('chat_on', v ? true : null);

  /// Agreed that chat may go to the online AI. Asked again on its own, so
  /// agreeing to on-phone chat never counts for the AI.
  bool get chatAi => _values['chat_ai'] == true;
  Future<void> setChatAi(bool v) => _set('chat_ai', v ? true : null);

  /// How often the cat speaks up: 0 quiet, 1 sometimes, 2 often.
  int get chatty => (_values['chatty'] as num?)?.toInt() ?? 1;
  Future<void> setChatty(int v) => _set('chatty', v == 1 ? null : v);

  /// The calm sound under a focus session: rain, waves, fire, or none.
  String? get focusSound => _values['focus_sound'] as String?;
  Future<void> setFocusSound(String? v) => _set('focus_sound', v);

  /// Quiet mode: no sounds or check-ins at all.
  bool get quiet => _values['quiet'] == true;
  Future<void> setQuiet(bool v) => _set('quiet', v ? true : null);

  /// 'light', 'dark' or null to follow the phone.
  String? get themeMode => _values['theme'] as String?;
  Future<void> setThemeMode(String? v) => _set('theme', v);

  /// 'zh', 'en' or null to follow the phone.
  String? get language => _values['language'] as String?;
  Future<void> setLanguage(String? v) => _set('language', v);
}
