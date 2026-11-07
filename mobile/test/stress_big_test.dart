// Every screen with text at 200%, the size WCAG asks for and the largest
// the app uses (it stops growing there), on the smallest and a large
// iPhone. English here; Chinese in stress_big_zh_test.dart.
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/stress.dart';

void main() =>
    stressAll(lang: 'en', dark: false, fonts: roboto(), text: 2, on: [0, 3]);
