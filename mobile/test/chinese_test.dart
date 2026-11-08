import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsnap/app.dart';
import 'package:spendsnap/l10n.dart';
import 'package:spendsnap/prefs.dart';
import 'package:spendsnap/theme.dart';

void main() {
  setUp(() => Prefs.current = Prefs.memory());

  group('Chinese that looks native', () {
    test('dates are written without spaces', () async {
      await Prefs.current.setLanguage('zh');
      expect(monthYear(DateTime(2026, 11, 8)), '2026年11月');
      expect(fullDate(DateTime(2026, 11, 8)), '2026年11月8日');
    });

    test('characters keep their spacing and body text gets room', () async {
      await Prefs.current.setLanguage('zh');
      final t = tinyTheme(Brightness.light).textTheme;
      expect(t.headlineMedium!.letterSpacing, 0);
      expect(t.displayMedium!.letterSpacing, 0);
      expect(t.bodyMedium!.height, 1.5);
      expect(t.bodyLarge!.height, 1.5);
      expect(t.bodyMedium!.fontSize, 15);
    });

    test('English keeps its tighter headings', () async {
      await Prefs.current.setLanguage('en');
      final t = tinyTheme(Brightness.light).textTheme;
      expect(t.headlineMedium!.letterSpacing, -0.3);
      expect(t.bodyMedium!.height, isNot(1.5));
    });

    test('the app is Purrpose, and 喵学伴 in Chinese', () async {
      await Prefs.current.setLanguage('en');
      expect(appName, 'Purrpose');
      await Prefs.current.setLanguage('zh');
      expect(appName, '喵学伴');
    });

    test('the app asks for Simplified Chinese by name', () {
      expect(simplifiedChinese.languageCode, 'zh');
      expect(simplifiedChinese.scriptCode, 'Hans');
    });
  });
}
