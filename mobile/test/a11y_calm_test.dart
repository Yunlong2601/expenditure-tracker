// Every screen and sheet in the Calm look against Flutter's accessibility
// checks, in light and dark mode on an iPhone SE: Calm's deeper colours must
// keep text as readable as Cosy's (see stress/a11y.dart).
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/a11y.dart';

void main() {
  a11yAll([
    iPhoneRun(dark: false, calm: true),
    iPhoneRun(dark: true, calm: true),
  ]);
}
