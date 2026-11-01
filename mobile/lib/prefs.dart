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

  /// Pocket money in S$, per [allowanceDaily] day or else per week. Null when not set.
  double? get allowance => (_values['allowance'] as num?)?.toDouble();
  bool get allowanceDaily => _values['allowance_daily'] == true;
  Future<void> setAllowance(double? amount, {bool daily = false}) async {
    await _set('allowance', amount);
    await _set('allowance_daily', daily ? true : null);
  }

  /// The home screen shows the whole month, else the allowance period.
  bool get showMonth => _values['show_month'] == true || allowance == null;
  Future<void> setShowMonth(bool v) => _set('show_month', v ? true : null);
}
