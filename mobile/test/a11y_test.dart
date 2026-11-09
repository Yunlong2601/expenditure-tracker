// Every screen and sheet in the Cosy look against Flutter's accessibility
// checks, in light and dark mode, on an iPhone SE and an Android phone (see
// stress/a11y.dart).
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/a11y.dart';

void main() {
  a11yAll([
    iPhoneRun(dark: false),
    iPhoneRun(dark: true),
    (
      phone: android,
      dark: false,
      calm: false,
      contrast: false,
      checks: [androidTapTargetGuideline, androidEdge],
    ),
  ]);
}
