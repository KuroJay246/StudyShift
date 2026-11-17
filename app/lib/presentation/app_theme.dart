import 'package:flutter/material.dart';

import '../data/preferences_repository.dart';
import 'design/studyshift_spacing.dart';

class _AccentColors {
  const _AccentColors(this.light, this.dark);
  final Color light;
  final Color dark;
}

class _FeaturedColors {
  const _FeaturedColors(this.start, this.end, this.wave);
  final Color start;
  final Color end;
  final Color wave;
}

class SchedulePalette extends ThemeExtension<SchedulePalette> {
  const SchedulePalette({
    required this.work,
    required this.onWork,
    required this.training,
    required this.onTraining,
    required this.school,
    required this.onSchool,
    required this.deadline,
    required this.onDeadline,
    required this.personal,
    required this.onPersonal,
    required this.conflict,
    required this.featuredStart,
    required this.featuredEnd,
    required this.featuredWave,
  });

  final Color work;
  final Color onWork;
  final Color training;
  final Color onTraining;
  final Color school;
  final Color onSchool;
  final Color deadline;
  final Color onDeadline;
  final Color personal;
  final Color onPersonal;
  final Color conflict;
  final Color featuredStart;
  final Color featuredEnd;
  final Color featuredWave;

  @override
  SchedulePalette copyWith({
    Color? work,
    Color? onWork,
    Color? training,
    Color? onTraining,
    Color? school,
    Color? onSchool,
    Color? deadline,
    Color? onDeadline,
    Color? personal,
    Color? onPersonal,
    Color? conflict,
    Color? featuredStart,
    Color? featuredEnd,
    Color? featuredWave,
  }) => SchedulePalette(
    work: work ?? this.work,
    onWork: onWork ?? this.onWork,
    training: training ?? this.training,
    onTraining: onTraining ?? this.onTraining,
    school: school ?? this.school,
    onSchool: onSchool ?? this.onSchool,
    deadline: deadline ?? this.deadline,
    onDeadline: onDeadline ?? this.onDeadline,
    personal: personal ?? this.personal,
    onPersonal: onPersonal ?? this.onPersonal,
    conflict: conflict ?? this.conflict,
    featuredStart: featuredStart ?? this.featuredStart,
    featuredEnd: featuredEnd ?? this.featuredEnd,
    featuredWave: featuredWave ?? this.featuredWave,
  );

  @override
  SchedulePalette lerp(ThemeExtension<SchedulePalette>? other, double t) {
    if (other is! SchedulePalette) return this;
    return SchedulePalette(
      work: Color.lerp(work, other.work, t)!,
      onWork: Color.lerp(onWork, other.onWork, t)!,
      training: Color.lerp(training, other.training, t)!,
      onTraining: Color.lerp(onTraining, other.onTraining, t)!,
      school: Color.lerp(school, other.school, t)!,
      onSchool: Color.lerp(onSchool, other.onSchool, t)!,
      deadline: Color.lerp(deadline, other.deadline, t)!,
      onDeadline: Color.lerp(onDeadline, other.onDeadline, t)!,
      personal: Color.lerp(personal, other.personal, t)!,
      onPersonal: Color.lerp(onPersonal, other.onPersonal, t)!,
      conflict: Color.lerp(conflict, other.conflict, t)!,
      featuredStart: Color.lerp(featuredStart, other.featuredStart, t)!,
      featuredEnd: Color.lerp(featuredEnd, other.featuredEnd, t)!,
      featuredWave: Color.lerp(featuredWave, other.featuredWave, t)!,
    );
  }
}

class AppTheme {
  static const _secondary = Color(0xFF2563EB);
  static const _background = Color(0xFFF7F9FE);
  static const _surfaceAlt = Color(0xFFEDF3FF);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF475569);
  static const _border = Color(0xFFDCE5F3);
  static const _darkBackground = Color(0xFF000000);
  static const _darkSurface = Color(0xFF000000);
  static const _darkSurfaceAlt = Color(0xFF121212);
  static const _darkSurfaceRaised = Color(0xFF1E1E1E);
  static const _darkTextPrimary = Color(0xFFF5F5F5);
  static const _darkTextSecondary = Color(0xFFB3B3B3);
  static const _darkBorder = Color(0xFF303030);

  static _AccentColors _accentColors(AccentTheme theme) => switch (theme) {
    AccentTheme.studyShiftBlue => const _AccentColors(
      Color(0xFF0D47E1),
      Color(0xFF7DB4FF),
    ),
    AccentTheme.teal => const _AccentColors(
      Color(0xFF00796B),
      Color(0xFF80CBC4),
    ),
    AccentTheme.violet => const _AccentColors(
      Color(0xFF6D28D9),
      Color(0xFFB39DDB),
    ),
    AccentTheme.amber => const _AccentColors(
      Color(0xFF9A5B00),
      Color(0xFFFFD180),
    ),
    AccentTheme.red => const _AccentColors(
      Color(0xFFE11D2E),
      Color(0xFFFF7581),
    ),
  };

  static _FeaturedColors _featuredColors(AccentTheme theme) => switch (theme) {
    AccentTheme.studyShiftBlue => const _FeaturedColors(
      Color(0xFF0B1F5B),
      Color(0xFF0D47E1),
      Color(0xFF1FB6FF),
    ),
    AccentTheme.teal => const _FeaturedColors(
      Color(0xFF063B37),
      Color(0xFF00796B),
      Color(0xFF30D6C2),
    ),
    AccentTheme.violet => const _FeaturedColors(
      Color(0xFF251052),
      Color(0xFF6D28D9),
      Color(0xFFB69CFF),
    ),
    AccentTheme.amber => const _FeaturedColors(
      Color(0xFF472900),
      Color(0xFF9A5B00),
      Color(0xFFFFC45C),
    ),
    AccentTheme.red => const _FeaturedColors(
      Color(0xFF54121D),
      Color(0xFFE11D2E),
      Color(0xFFFF5364),
    ),
  };

  static SchedulePalette _schedulePalette(
    AccentTheme theme, {
    required bool dark,
    AppPreferences? preferences,
  }) {
    final featured = _featuredColors(theme);
    final work = preferences?.workColor == null
        ? (dark ? const Color(0xFF7DB4FF) : const Color(0xFF2563EB))
        : Color(preferences!.workColor!);
    final school = preferences?.schoolColor == null
        ? (dark ? const Color(0xFFB69CFF) : const Color(0xFF7C3AED))
        : Color(preferences!.schoolColor!);
    final training = preferences?.trainingColor == null
        ? (dark ? const Color(0xFFFFC27A) : const Color(0xFFC28113))
        : Color(preferences!.trainingColor!);
    final deadline = preferences?.deadlineColor == null
        ? (dark ? const Color(0xFFFFC27A) : const Color(0xFFB45309))
        : Color(preferences!.deadlineColor!);
    final personal = preferences?.personalColor == null
        ? (dark ? const Color(0xFF5EEAD4) : const Color(0xFF0D9488))
        : Color(preferences!.personalColor!);
    return SchedulePalette(
      work: work,
      onWork: _onCategory(work, dark: dark),
      training: training,
      onTraining: _onCategory(training, dark: dark),
      school: school,
      onSchool: _onCategory(school, dark: dark),
      deadline: deadline,
      onDeadline: _onCategory(deadline, dark: dark),
      personal: personal,
      onPersonal: _onCategory(personal, dark: dark),
      conflict: dark ? const Color(0xFF4B2026) : const Color(0xFFFEE4E2),
      featuredStart: featured.start,
      featuredEnd: featured.end,
      featuredWave: featured.wave,
    );
  }

  static Color _onCategory(Color color, {required bool dark}) =>
      Color.lerp(color, dark ? Colors.white : Colors.black, dark ? .52 : .34)!;

  static ThemeData light({
    AccentTheme accentTheme = AccentTheme.studyShiftBlue,
    AppPreferences? preferences,
  }) {
    final primary = _accentColors(accentTheme).light;
    final tint = primary.withValues(alpha: .12);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: _background,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: accentTheme == AccentTheme.studyShiftBlue
              ? _secondary
              : primary,
          onSecondary: Colors.white,
          tertiary: primary,
          error: const Color(0xFFD92D20),
          surface: _background,
          surfaceContainerLow: Color.alphaBlend(
            primary.withValues(alpha: .045),
            Colors.white,
          ),
          surfaceContainer: Color.alphaBlend(tint, _surfaceAlt),
          onSurface: _textPrimary,
          onSurfaceVariant: _textSecondary,
          outline: _border,
          outlineVariant: _border,
        );
    return _theme(
      scheme,
      _schedulePalette(accentTheme, dark: false, preferences: preferences),
    );
  }

  static ThemeData dark({
    AccentTheme accentTheme = AccentTheme.studyShiftBlue,
    AppPreferences? preferences,
  }) {
    final primary = _accentColors(accentTheme).dark;
    final tint = _accentColors(accentTheme).light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: _darkBackground,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.black,
          secondary: accentTheme == AccentTheme.studyShiftBlue
              ? const Color(0xFF59B8FF)
              : primary,
          onSecondary: Colors.black,
          tertiary: primary,
          error: const Color(0xFFFCA5A5),
          surface: _darkSurface,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: Color.alphaBlend(
            tint.withValues(alpha: .10),
            _darkSurfaceAlt,
          ),
          surfaceContainer: Color.alphaBlend(
            tint.withValues(alpha: .20),
            _darkSurfaceRaised,
          ),
          surfaceContainerHigh: const Color(0xFF292929),
          onSurface: _darkTextPrimary,
          onSurfaceVariant: _darkTextSecondary,
          outline: _darkBorder,
          outlineVariant: _darkBorder,
        );
    return _theme(
      scheme,
      _schedulePalette(accentTheme, dark: true, preferences: preferences),
    );
  }

  static ThemeData _theme(ColorScheme scheme, SchedulePalette schedulePalette) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 30 / 24,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          height: 26 / 20,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 22 / 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
        bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
        bodySmall: TextStyle(fontSize: 12, height: 16 / 12),
        labelLarge: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(fontSize: 12, height: 16 / 12),
      ),
      extensions: [schedulePalette],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        toolbarHeight: StudyShiftSpacing.appBarHeight,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudyShiftSpacing.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        constraints: const BoxConstraints(
          minHeight: StudyShiftSpacing.inputHeight,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        height: StudyShiftSpacing.bottomNavigationHeight,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return base.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(StudyShiftSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyShiftSpacing.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(StudyShiftSpacing.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyShiftSpacing.buttonRadius),
          ),
        ),
      ),
    );
  }
}
