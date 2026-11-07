// Without a Chinese font, the test font's square letters are the right
// width for Chinese characters, though too wide for numbers.
@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/stress.dart';

void main() {
  final cjk = chineseFont();
  stressAll(lang: 'zh', dark: true, fonts: [?cjk]);
}
