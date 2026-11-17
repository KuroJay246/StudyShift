import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/presentation/app_theme.dart';

void main() {
  test(
    'accent options adapt while preserving separate light and dark surfaces',
    () {
      final tealLight = AppTheme.light(accentTheme: AccentTheme.teal);
      final tealDark = AppTheme.dark(accentTheme: AccentTheme.teal);
      expect(tealLight.colorScheme.primary, const Color(0xFF00796B));
      expect(tealDark.colorScheme.primary, const Color(0xFF80CBC4));
      expect(tealLight.colorScheme.brightness, Brightness.light);
      expect(tealDark.colorScheme.brightness, Brightness.dark);
      expect(
        tealLight.colorScheme.surfaceContainer,
        isNot(AppTheme.light().colorScheme.surfaceContainer),
      );
      expect(
        tealDark.extension<SchedulePalette>()!.featuredStart,
        isNot(AppTheme.dark().extension<SchedulePalette>()!.featuredStart),
      );
    },
  );

  test('light appearance follows the StudyShift blue palette', () {
    final theme = AppTheme.light();
    final palette = theme.extension<SchedulePalette>()!;

    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F9FE));
    expect(theme.colorScheme.surface, const Color(0xFFF7F9FE));
    expect(theme.colorScheme.primary, const Color(0xFF0D47E1));
    expect(theme.colorScheme.secondary, const Color(0xFF2563EB));
    expect(palette.work, const Color(0xFF2563EB));
    expect(palette.school, const Color(0xFF7C3AED));
    expect(theme.textTheme.headlineLarge?.fontSize, 28);
    expect(theme.textTheme.titleMedium?.fontSize, 16);
    expect(theme.navigationBarTheme.height, 80);
    expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
  });

  test('dark appearance uses black surfaces with clear categories', () {
    final theme = AppTheme.dark();
    final palette = theme.extension<SchedulePalette>()!;

    expect(theme.colorScheme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.colorScheme.surface, Colors.black);
    expect(theme.colorScheme.surfaceContainerLow, isNot(Colors.black));
    expect(theme.colorScheme.surfaceContainer, isNot(Colors.black));
    expect(theme.colorScheme.primary, const Color(0xFF7DB4FF));
    expect(palette.work, isNot(palette.school));
    expect(palette.personal, isNot(palette.work));
  });

  test('dark surface stays black when a different accent is selected', () {
    final theme = AppTheme.dark(accentTheme: AccentTheme.teal);

    expect(theme.colorScheme.surface, Colors.black);
    expect(theme.colorScheme.surfaceContainerLow, isNot(Colors.black));
    expect(theme.colorScheme.primary, const Color(0xFF80CBC4));
  });

  test('red theme has matching light and dark accents', () {
    final light = AppTheme.light(accentTheme: AccentTheme.red);
    final dark = AppTheme.dark(accentTheme: AccentTheme.red);

    expect(light.colorScheme.primary, const Color(0xFFE11D2E));
    expect(dark.colorScheme.primary, const Color(0xFFFF7581));
    expect(dark.colorScheme.surface, Colors.black);
    expect(
      dark.extension<SchedulePalette>()!.featuredStart,
      const Color(0xFF54121D),
    );
  });

  test('calendar colors can be customized independently from app theme', () {
    const preferences = AppPreferences(
      accentTheme: AccentTheme.violet,
      workColor: 0xFFE91E63,
      trainingColor: 0xFFFF9800,
      schoolColor: 0xFF2196F3,
    );
    final theme = AppTheme.light(
      accentTheme: AccentTheme.violet,
      preferences: preferences,
    );
    final palette = theme.extension<SchedulePalette>()!;

    expect(theme.colorScheme.primary, const Color(0xFF6D28D9));
    expect(palette.work, const Color(0xFFE91E63));
    expect(palette.training, const Color(0xFFFF9800));
    expect(palette.school, const Color(0xFF2196F3));
  });
}
