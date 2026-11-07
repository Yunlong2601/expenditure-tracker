// Every screen in Chinese and dark mode with text at 200%, on the smallest
// iPhone.
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/stress.dart';

void main() {
  final cjk = chineseFont();
  stressAll(lang: 'zh', dark: true, fonts: [?cjk], text: 2, on: [0]);
}
