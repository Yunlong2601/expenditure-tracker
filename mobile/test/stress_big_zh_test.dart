// Every screen in Chinese and dark mode with text at 200%, on the smallest
// iPhone. It uses the test font, whose square letters are as wide as Chinese
// ones and wider than real digits, so it is the harder case and runs the same
// here as on CI, which has no Chinese font.
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/stress.dart';

void main() {
  stressAll(lang: 'zh', dark: true, fonts: [], text: 2, on: [0]);
}
