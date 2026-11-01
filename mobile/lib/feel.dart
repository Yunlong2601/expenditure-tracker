import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Short interface sounds bundled in assets/sounds, made for this app.
enum Sound { tap, logged, removed, oops }

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

  static void play(Sound s) {
    if (!soundOn) return;
    _call('play', 'assets/sounds/${s.name}.wav');
  }

  /// A light tick under the finger for presses.
  static void tap() {
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

  static void _call(String method, [Object? arg]) {
    _channel.invokeMethod<void>(method, arg).catchError((_) {});
  }
}

/// Sinks slightly while a finger is down, like a physical key.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.95});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !still ? widget.scale : 1,
        // Quick in, a touch slower back out so the release is visible.
        duration: Duration(milliseconds: _down ? 90 : 220),
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
