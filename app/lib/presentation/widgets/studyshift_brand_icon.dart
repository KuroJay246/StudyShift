import 'package:flutter/material.dart';

import '../../data/preferences_repository.dart';

/// Composes the approved raster S artwork on the selected theme's launcher tile.
/// Keep the supplied bitmap's aspect ratio; launcher masks are handled by Android.
class StudyShiftBrandIcon extends StatelessWidget {
  const StudyShiftBrandIcon({
    super.key,
    required this.size,
    required this.start,
    required this.end,
    required this.accent,
    required this.highlight,
    required this.accentTheme,
    this.semanticLabel = 'StudyShift app icon',
  });

  final double size;
  final Color start;
  final Color end;
  final Color accent;
  final Color highlight;
  final AccentTheme accentTheme;
  final String semanticLabel;

  String get _symbolAsset =>
      'assets/branding/studyshift-symbol-${switch (accentTheme) {
        AccentTheme.studyShiftBlue => 'blue',
        AccentTheme.teal => 'teal',
        AccentTheme.violet => 'violet',
        AccentTheme.amber => 'amber',
        AccentTheme.red => 'red',
      }}.png';

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .17),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, Color.lerp(start, end, .52)!, end],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .25),
            blurRadius: size * .19,
            offset: Offset(0, size * .08),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(.9, .9),
                radius: 1.25,
                colors: [
                  highlight.withValues(alpha: .4),
                  highlight.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Image.asset(
            _symbolAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    ),
  );
}
