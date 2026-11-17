import 'package:flutter/material.dart';

import '../../data/preferences_repository.dart';

class StudyShiftBrandMark extends StatelessWidget {
  const StudyShiftBrandMark({
    super.key,
    this.size = 42,
    this.accentTheme = AccentTheme.studyShiftBlue,
  });

  final double size;
  final AccentTheme accentTheme;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/studyshift-symbol-${switch (accentTheme) {
        AccentTheme.studyShiftBlue => 'blue',
        AccentTheme.teal => 'teal',
        AccentTheme.violet => 'violet',
        AccentTheme.amber => 'amber',
        AccentTheme.red => 'red',
      }}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'StudyShift S logo',
    );
  }
}

class StudyShiftWordmark extends StatelessWidget {
  const StudyShiftWordmark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: compact ? 16 : 24,
      height: 1,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      letterSpacing: -.6,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: 'Study',
            style: style?.copyWith(
              color: dark ? const Color(0xFFF8FAFF) : const Color(0xFF0B1F5B),
            ),
          ),
          TextSpan(
            text: 'Shift',
            style: style?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}
