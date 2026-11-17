import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/widgets/shift_brand_mark.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('wordmark remains legible in $brightness appearance', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          home: const Scaffold(body: Center(child: StudyShiftWordmark())),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final spans = _textSpans(richText.text)
          .where((span) => span.text != null)
          .toList();

      expect(spans[0].text, 'Study');
      expect(
        spans[0].style?.color,
        brightness == Brightness.dark
            ? const Color(0xFFF8FAFF)
            : const Color(0xFF0B1F5B),
      );
      expect(spans[1].text, 'Shift');
      expect(
        spans[1].style?.color,
        (brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
            .colorScheme
            .primary,
      );
    });
  }

  testWidgets('approved S mark follows the selected accent palette', (
    tester,
  ) async {
    for (final accentTheme in AccentTheme.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(accentTheme: accentTheme),
          home: Scaffold(body: StudyShiftBrandMark(accentTheme: accentTheme)),
        ),
      );
      expect(find.byType(ColorFiltered), findsNothing);
      final mark = tester.widget<Image>(find.byType(Image));
      expect(
        (mark.image as AssetImage).assetName,
        'assets/branding/studyshift-symbol-${switch (accentTheme) {
          AccentTheme.studyShiftBlue => 'blue',
          AccentTheme.teal => 'teal',
          AccentTheme.violet => 'violet',
          AccentTheme.amber => 'amber',
          AccentTheme.red => 'red',
        }}.png',
      );
    }
  });
}

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}
