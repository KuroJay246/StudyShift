import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/preferences_repository.dart';
import 'app_theme.dart';
import 'widgets/studyshift_brand_icon.dart';

/// Branded first-frame experience shown while local preferences and schedules
/// are read. It never waits on a network request.
class StudyShiftSplash extends StatefulWidget {
  const StudyShiftSplash({
    super.key,
    required this.ready,
    this.accentTheme = AccentTheme.studyShiftBlue,
  });

  final bool ready;
  final AccentTheme accentTheme;

  @override
  State<StudyShiftSplash> createState() => _StudyShiftSplashState();
}

class _StudyShiftSplashState extends State<StudyShiftSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF5F5F5) : const Color(0xFF0B1F5B);
    final secondary = dark ? const Color(0xFFB3B3B3) : const Color(0xFF40577F);
    final background = dark ? Colors.black : const Color(0xFFF7F9FE);
    final appTheme = Theme.of(context);
    final palette = appTheme.extension<SchedulePalette>();
    final accent = appTheme.colorScheme.primary;
    final featuredStart = palette?.featuredStart ?? accent;
    final featuredEnd = palette?.featuredEnd ?? accent;
    final featuredWave =
        palette?.featuredWave ?? appTheme.colorScheme.secondary;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = math.min(
            144.0,
            math.max(96.0, constraints.maxHeight * .19),
          );
          final progressWidth = math.max(
            0.0,
            math.min(280.0, constraints.maxWidth - 48.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _SplashWavesPainter(
                  dark: dark,
                  start: featuredStart,
                  end: featuredEnd,
                  wave: featuredWave,
                ),
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final stage = reducedMotion ? 1.0 : _controller.value;
                        final progress = ((stage - .48) / .48).clamp(0.0, 1.0);
                        final showReady = widget.ready && stage >= .84;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _entrance(
                              stage,
                              .12,
                              .34,
                              StudyShiftBrandIcon(
                                size: iconSize,
                                start: featuredStart,
                                end: featuredEnd,
                                accent: accent,
                                highlight: featuredWave,
                                accentTheme: widget.accentTheme,
                              ),
                              startingOpacity: .62,
                            ),
                            const SizedBox(height: 24),
                            _entrance(
                              stage,
                              .30,
                              .53,
                              _SplashWordmark(dark: dark, accent: accent),
                            ),
                            const SizedBox(height: 10),
                            _entrance(
                              stage,
                              .36,
                              .57,
                              Text(
                                'WORK  •  STUDY  •  PLAN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 74),
                            _entrance(
                              stage,
                              .48,
                              .72,
                              SizedBox(
                                width: progressWidth,
                                height: 8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: reducedMotion ? 1 : progress,
                                    backgroundColor: dark
                                        ? const Color(0xFF263B60)
                                        : const Color(0xFFCFE2FF),
                                    valueColor: AlwaysStoppedAnimation(accent),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _entrance(
                              stage,
                              .51,
                              .75,
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                layoutBuilder: (currentChild, _) =>
                                    currentChild ?? const SizedBox.shrink(),
                                child: showReady
                                    ? Row(
                                        key: const ValueKey('ready'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: accent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Ready!',
                                            style: TextStyle(
                                              color: foreground,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Loading your schedule…',
                                        key: const ValueKey('loading'),
                                        style: TextStyle(
                                          color: secondary,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _entrance(
    double progress,
    double begin,
    double end,
    Widget child, {
    double startingOpacity = 0,
  }) {
    final entrance = Curves.easeOutCubic.transform(
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0),
    );
    final value = startingOpacity + (1 - startingOpacity) * entrance;
    return Opacity(
      opacity: value,
      child: Transform.scale(scale: .96 + (.04 * value), child: child),
    );
  }
}

class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark({required this.dark, required this.accent});

  final bool dark;
  final Color accent;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'StudyShift',
    child: Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.1,
          color: dark ? const Color(0xFFF5F5F5) : const Color(0xFF0B1F5B),
        ),
        children: [
          TextSpan(text: 'Study'),
          TextSpan(
            text: 'Shift',
            style: TextStyle(color: accent),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}

class _SplashWavesPainter extends CustomPainter {
  const _SplashWavesPainter({
    required this.dark,
    required this.start,
    required this.end,
    required this.wave,
  });

  final bool dark;
  final Color start;
  final Color end;
  final Color wave;

  @override
  void paint(Canvas canvas, Size size) {
    final top = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .48, 0)
      ..cubicTo(
        size.width * .25,
        size.height * .08,
        size.width * .18,
        size.height * .21,
        0,
        size.height * .34,
      )
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [start.withValues(alpha: .22), wave.withValues(alpha: .08)]
              : [end.withValues(alpha: .20), wave.withValues(alpha: .07)],
        ).createShader(Offset.zero & size),
    );

    final base = Path()
      ..moveTo(0, size.height * .84)
      ..cubicTo(
        size.width * .28,
        size.height * .78,
        size.width * .60,
        size.height * .91,
        size.width,
        size.height * .80,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      base,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [start, end, end]
                  : [
                      wave.withValues(alpha: .54),
                      wave.withValues(alpha: .78),
                      end,
                    ],
            ).createShader(
              Offset(0, size.height * .78) &
                  Size(size.width, size.height * .22),
            ),
    );

    final highlight = Path()
      ..moveTo(0, size.height * .89)
      ..cubicTo(
        size.width * .29,
        size.height * .82,
        size.width * .62,
        size.height * .96,
        size.width,
        size.height * .86,
      )
      ..lineTo(size.width, size.height * .91)
      ..cubicTo(
        size.width * .63,
        size.height,
        size.width * .28,
        size.height * .87,
        0,
        size.height * .94,
      )
      ..close();
    canvas.drawPath(
      highlight,
      Paint()..color = wave.withValues(alpha: dark ? .55 : .72),
    );
  }

  @override
  bool shouldRepaint(_SplashWavesPainter oldDelegate) =>
      oldDelegate.dark != dark ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.wave != wave;
}
