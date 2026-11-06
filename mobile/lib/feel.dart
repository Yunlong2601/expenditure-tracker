import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prefs.dart';

/// Short interface sounds bundled in assets/sounds, made for this app.
enum Sound { tap, logged, removed, oops, mew }

/// Sound and haptics for taps and results. Sounds play through the iPhone's
/// system sound player, so the silent switch mutes them. Anything that fails
/// (tests, other platforms) is silently skipped.
class Feel {
  Feel._();

  static const _channel = MethodChannel('spendsnap/feel');
  static File? _offFile;
  static bool soundOn = true;

  /// Remembers the Sounds switch in [dir], next to the expenses.
  static Future<void> load(Directory dir) async {
    _offFile = File('${dir.path}/sounds_off');
    soundOn = !await _offFile!.exists();
  }

  static Future<void> setSoundOn(bool on) async {
    soundOn = on;
    final f = _offFile;
    if (f == null) return;
    try {
      on ? await f.delete() : await f.create(recursive: true);
    } on FileSystemException catch (_) {}
  }

  /// Weekdays 7:30 am to 2:30 pm, when the school-hours switch is on.
  static bool inSchoolHours([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (t.weekday > DateTime.friday) return false;
    final m = t.hour * 60 + t.minute;
    return m >= 7 * 60 + 30 && m < 14 * 60 + 30;
  }

  static void play(Sound s) {
    if (!soundOn || Prefs.current.quiet || (Prefs.current.schoolQuiet && inSchoolHours())) return;
    _call('play', 'assets/sounds/${s.name}.wav');
  }

  static DateTime _lastTap = DateTime(0);

  /// A pop and a light tick under the finger for presses. The press effect and
  /// the button's own handler can both ask for it; one finger gets one pop.
  static void tap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < const Duration(milliseconds: 80)) return;
    _lastTap = now;
    HapticFeedback.lightImpact();
    play(Sound.tap);
  }

  /// The system "done" haptic plus the logged chime.
  static void logged() {
    _call('success');
    play(Sound.logged);
  }

  static void removed() {
    HapticFeedback.mediumImpact();
    play(Sound.removed);
  }

  static void oops() {
    _call('warning');
    play(Sound.oops);
  }

  /// Plays a calm sound from assets/sounds on a loop under a focus session,
  /// or stops it with null. She picks it herself, so it plays whatever the
  /// Sounds switch says; the silent switch still mutes it.
  static void loop(String? name) => name == null
      ? _call('stopLoop')
      : _call('loop', 'assets/sounds/$name.wav');

  static void _call(String method, [Object? arg]) {
    _channel.invokeMethod<void>(method, arg).catchError((_) {});
  }
}

/// Sinks slightly while a finger is down, like a physical key.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.92});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  DateTime _pressedAt = DateTime(0);
  Timer? _up;

  /// A quick tap still shows the whole press before springing back.
  static const _minPress = Duration(milliseconds: 110);

  void _press() {
    if (!widget.enabled) return;
    Feel.tap();
    _pressedAt = DateTime.now();
    setState(() => _down = true);
  }

  void _release() {
    final left = _minPress - DateTime.now().difference(_pressedAt);
    _up?.cancel();
    _up = Timer(left > Duration.zero ? left : Duration.zero, () {
      if (mounted && _down) setState(() => _down = false);
    });
  }

  @override
  void dispose() {
    _up?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _down && !still ? widget.scale : 1,
        // Quick in, then a springy bounce back out.
        duration: Duration(milliseconds: _down ? 90 : 320),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Rolls a number from its last value to the new one. The first value shows
/// immediately; only changes animate.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.builder});
  final double value;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, value);
    // TweenAnimationBuilder starts later changes from wherever it is now.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}
