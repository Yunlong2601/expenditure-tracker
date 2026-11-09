@Tags(['skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'stress/stress.dart';

void main() => stressAll(lang: 'en', dark: false, fonts: roboto());
