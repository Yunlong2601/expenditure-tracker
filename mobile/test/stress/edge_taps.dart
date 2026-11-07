import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the tap size of buttons that touch the edge of the screen.
///
/// Flutter's own tap size checks pass over anything touching the screen's
/// edge, in case it's a list item scrolled half off. That also lets through
/// buttons stuck to the edge on purpose, like the Chat and Records tabs on
/// the Pet tab. This looks at just those, still passing over anything at the
/// edge of a list that scrolls.
class EdgeTapTargetGuideline extends AccessibilityGuideline {
  const EdgeTapTargetGuideline(this.size);

  /// 44 x 44 on iPhone, 48 x 48 on Android.
  final Size size;

  @override
  String get description => 'Buttons on the screen edge are big enough';

  @override
  Evaluation evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final view in tester.binding.renderViews) {
      final root = view.owner!.semanticsOwner!.rootSemanticsNode!;
      final screen = Offset.zero & view.flutterView.physicalSize;
      final dpr = view.flutterView.devicePixelRatio;
      void visit(SemanticsNode node) {
        node.visitChildren((c) {
          visit(c);
          return true;
        });
        if (node.isMergedIntoParent) return;
        final data = node.getSemanticsData();
        final tappable =
            data.hasAction(SemanticsAction.tap) ||
            data.hasAction(SemanticsAction.longPress);
        if (!tappable || data.flagsCollection.isHidden) return;
        // The dimmed backdrop behind a sheet isn't a button: tapping
        // anywhere on it closes the sheet.
        if (data.hasAction(SemanticsAction.dismiss)) return;
        var r = node.rect;
        for (SemanticsNode? n = node; n != null; n = n.parent) {
          if (n.transform != null) {
            r = MatrixUtils.transformRect(n.transform!, r);
          }
          // Half scrolled off, perhaps: Flutter's check is right to skip it.
          if (n.flagsCollection.hasImplicitScrolling && _touches(r, n.rect)) {
            return;
          }
        }
        // Not on the edge: Flutter's own check has seen it already.
        if (!_touches(r, screen)) return;
        final got = r.size / dpr;
        if (got.width < size.width - precisionErrorTolerance ||
            got.height < size.height - precisionErrorTolerance) {
          result += Evaluation.fail(
            '$node: on the screen edge, expected at least $size, '
            'but found $got',
          );
        }
      }

      visit(root);
    }
    return result;
  }

  static bool _touches(Rect child, Rect parent) =>
      child.left - parent.left <= 0.001 ||
      parent.right - child.right <= 0.001 ||
      child.top - parent.top <= 0.001 ||
      parent.bottom - child.bottom <= 0.001;
}
