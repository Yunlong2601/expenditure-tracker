import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks that every piece of text on the top screen stands out from what's
/// behind it, by WCAG's rule: 4.5:1, or 3:1 for large text.
///
/// Flutter's own textContrastGuideline reads the screen at one pixel per
/// point, where small letters blur into the background, so it reports
/// grey 11-point text as 1.1:1 when it's really 4.8:1. This reads the
/// background from the screen at full resolution and takes the text's
/// colour from its style instead.
Future<List<String>> contrastProblems(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final dpr = tester.view.devicePixelRatio;
  late final ByteData bytes;
  late final int width;
  late final double px;
  await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds, pixelRatio: dpr);
    width = image.width;
    // Image pixels per point, whatever units paintBounds is in.
    px = image.width / view.size.width;
    bytes = (await image.toByteData())!;
    image.dispose();
  });
  final height = bytes.lengthInBytes ~/ (4 * width);

  Color pixel(int x, int y) {
    final i = 4 * (y * width + x);
    return Color.fromARGB(
      255,
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  final problems = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    // Only the screen or sheet on top: what's under a sheet is dimmed.
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final box = e.renderObject! as RenderParagraph;
    if (!box.attached || !box.hasSize || box.size.isEmpty) continue;
    final text = box.text.toPlainText().trim();
    if (text.isEmpty) continue;
    // WCAG doesn't count a button that's turned off.
    var off = false;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is ButtonStyleButton) off = !w.enabled;
      return w is! ButtonStyleButton;
    });
    if (off) continue;
    final r = (box.localToGlobal(Offset.zero) & box.size).intersect(
      Offset.zero & view.size,
    );
    if (r.isEmpty || r.width < 1 || r.height < 1) continue;

    // The background is the commonest colour in a thin frame just outside
    // the text, so the letters themselves (or the test font's squares)
    // don't count.
    final counts = <int, int>{};
    void sample(double x, double y) {
      final ix = (x * px).floor(), iy = (y * px).floor();
      if (ix < 0 || iy < 0 || ix >= width || iy >= height) return;
      final c = pixel(ix, iy).toARGB32();
      counts[c] = (counts[c] ?? 0) + 1;
    }

    for (var d = 1.0; d <= 3; d++) {
      for (var x = r.left; x <= r.right; x += 0.5) {
        sample(x, r.top - d);
        sample(x, r.bottom + d);
      }
      for (var y = r.top; y <= r.bottom; y += 0.5) {
        sample(r.left - d, y);
        sample(r.right + d, y);
      }
    }
    if (counts.isEmpty) continue;
    final bg = Color(
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
    );

    // Each colour used in the text, laid over that background.
    final scale = box.textScaler.scale(1);
    void check(InlineSpan span, TextStyle? inherited) {
      final style = inherited?.merge(span.style) ?? span.style;
      // Icons are pictures next to words, not text.
      final icon = style?.fontFamily == 'MaterialIcons';
      if (span is TextSpan &&
          !icon &&
          (span.text?.trim().isNotEmpty ?? false)) {
        final c = style?.color;
        // Faded text is a turned-off button or a placeholder, which WCAG
        // doesn't count.
        if (c != null && c.a >= 0.45) {
          final fg = Color.alphaBlend(c, bg);
          final size = (style?.fontSize ?? 14) * scale;
          final bold = (style?.fontWeight?.value ?? 400) >= 700;
          final large = size >= 18 || (size >= 14 && bold);
          final need = large ? 3.0 : 4.5;
          final got = ratio(fg, bg);
          if (got < need) {
            problems.add(
              '"${span.text!.trim()}" is ${got.toStringAsFixed(2)}:1, '
              'needs $need:1 (${hex(fg)} on ${hex(bg)}, '
              '${size.toStringAsFixed(0)} pt)',
            );
          }
        }
      }
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          check(child, style);
        }
      }
    }

    check(box.text, null);
  }
  return problems;
}

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG's contrast ratio between two opaque colours.
double ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
