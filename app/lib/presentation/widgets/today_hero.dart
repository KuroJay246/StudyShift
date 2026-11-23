import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Today identity, time-of-day greeting, date controls, and a restrained
/// local-time sky illustration inspired by the approved StudyShift concept.
class TodayHero extends StatefulWidget {
  const TodayHero({
    super.key,
    required this.greeting,
    required this.hour,
    required this.dateLabel,
    required this.isToday,
    required this.onChooseDay,
    required this.onToday,
    this.featuredContent,
    this.weatherPageKey,
    this.weatherSummary,
    this.weatherCaption,
    this.onWeatherSwipe,
    this.compact = false,
  });

  final String greeting;
  final int hour;
  final String dateLabel;
  final bool isToday;
  final VoidCallback onChooseDay;
  final VoidCallback onToday;
  final Widget? featuredContent;
  final Object? weatherPageKey;
  final Widget? weatherSummary;
  final Widget? weatherCaption;
  final ValueChanged<int>? onWeatherSwipe;
  final bool compact;

  static bool isNightForHour(int hour) => hour >= 21 || hour < 6;

  static List<Color> sunColorsForHour(int hour) => hour >= 17 && hour < 18
      ? const [Color(0xFFFFF1D0), Color(0xFFFFBE61), Color(0xFFF27A52)]
      : const [Color(0xFFFFF5C9), Color(0xFFFFD458), Color(0xFFFFA83D)];

  static const double sunHaloRadius = 32;
  static const double sunDiscRadius = 18;
  static const double sunRayOuterRadius = 28;
  // Anchor the sun/moon to the greeting header. The painter also covers the
  // featured card, so a percentage of its full height can drift onto the date.
  static const double celestialCenterY = 38;

  static List<Color> sunColorsForPalette(
    int hour, {
    required Color featuredStart,
    required Color featuredEnd,
    required Color featuredWave,
  }) => sunColorsForHour(hour);

  /// Celestial bodies retain their natural palette; user themes tint the
  /// surrounding horizon and schedule surfaces, not the sun or moon itself.
  static Color moonColorForAppearance({required bool isDark}) =>
      isDark ? const Color(0xFFF3F6FF) : const Color(0xFFF2CC76);

  static Color moonOutlineColorForAppearance({required bool isDark}) =>
      isDark ? const Color(0xFF9AA8BF) : const Color(0xFF786038);

  static bool showsHorizonForTheme({required bool isDark}) => !isDark;

  /// The live weather summary supplies its own condition icon. Keep the
  /// illustrated horizon off in that layout so it cannot visually collide
  /// with the weather summary or featured schedule card.
  static bool showsHorizonWithWeather({required bool isDark}) => false;

  /// Keeps the moon readable without a hard, full circular halo in light mode.
  static double moonGlowOpacity({required bool isDark}) => isDark ? .025 : 0;

  @override
  State<TodayHero> createState() => _TodayHeroState();
}

class _TodayHeroState extends State<TodayHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    value: .5,
    duration: const Duration(milliseconds: 2600),
  );
  bool? _reduceMotion;
  double _weatherDragDistance = 0;
  bool _weatherDragHandled = false;
  int _weatherSwipeDirection = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _glow.stop();
      _glow.value = .5;
    } else {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide =
              constraints.maxWidth >= 640 && widget.featuredContent != null;
          final greeting = Text(
            widget.greeting,
            maxLines: sideBySide ? 1 : null,
            overflow: sideBySide ? TextOverflow.ellipsis : null,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          );
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              greeting,
              _dateControls(context, compact: true),
              if (widget.weatherCaption != null) ...[
                const SizedBox(height: 2),
                widget.weatherCaption!,
              ],
              if (widget.weatherSummary != null) ...[
                const SizedBox(height: 6),
                widget.weatherSummary!,
              ],
            ],
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _weatherSwipeTarget(_weatherPageTransition(header)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 7, child: widget.featuredContent!),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _weatherSwipeTarget(_weatherPageTransition(header)),
                      if (widget.featuredContent != null) ...[
                        const SizedBox(height: 4),
                        widget.featuredContent!,
                      ],
                    ],
                  ),
          );
        },
      );
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final night = TodayHero.isNightForHour(widget.hour);
    final scheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<SchedulePalette>();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: -16,
          right: -16,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, _) => Semantics(
                label: widget.weatherSummary == null
                    ? night
                          ? 'Night sky with a softly glowing crescent moon'
                          : 'Sky with a softly glowing sun'
                    : null,
                child: CustomPaint(
                  painter: _TodaySkyPainter(
                    isDark: dark,
                    hour: widget.hour,
                    showCelestial:
                        widget.isToday && widget.weatherSummary == null,
                    showHorizon: widget.weatherSummary == null
                        ? TodayHero.showsHorizonForTheme(isDark: dark)
                        : TodayHero.showsHorizonWithWeather(isDark: dark),
                    glow: _reduceMotion == true ? .5 : _glow.value,
                    surface: scheme.surface,
                    featuredStart: palette?.featuredStart ?? scheme.primary,
                    featuredEnd: palette?.featuredEnd ?? scheme.primary,
                    featuredWave: palette?.featuredWave ?? scheme.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          // Keep the greeting, date and featured card in one painted region so
          // the sky and horizon flow behind the whole Today composition.
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _weatherSwipeTarget(
                _weatherPageTransition(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.greeting,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (widget.weatherSummary != null) ...[
                            const SizedBox(width: 8),
                            widget.weatherSummary!,
                          ],
                        ],
                      ),
                      const SizedBox(
                        key: ValueKey('today-weather-swipe-gap'),
                        height: 4,
                      ),
                      _dateControls(
                        context,
                        compact: widget.weatherSummary != null,
                      ),
                      if (widget.weatherCaption != null) ...[
                        const SizedBox(height: 2),
                        widget.weatherCaption!,
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.featuredContent != null) ...[
                const SizedBox(height: 8),
                widget.featuredContent!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _weatherSwipeTarget(Widget child) {
    if (widget.onWeatherSwipe == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _weatherDragDistance = 0;
        _weatherDragHandled = false;
      },
      onHorizontalDragUpdate: (details) {
        if (_weatherDragHandled) return;
        _weatherDragDistance += details.primaryDelta ?? 0;
        if (_weatherDragDistance.abs() < 32) return;
        _weatherDragHandled = true;
        _weatherSwipeDirection = _weatherDragDistance < 0 ? 1 : -1;
        widget.onWeatherSwipe!(_weatherSwipeDirection);
      },
      child: child,
    );
  }

  Widget _weatherPageTransition(Widget child) {
    final pageKey = widget.weatherPageKey;
    if (pageKey == null) return child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final incomingOffset = Offset(_weatherSwipeDirection.toDouble(), 0);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final startOffset = animation.status == AnimationStatus.reverse
            ? -incomingOffset
            : incomingOffset;
        final position = Tween<Offset>(
          begin: startOffset,
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: position, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey<Object>(pageKey), child: child),
    );
  }

  Widget _dateControls(BuildContext context, {bool compact = false}) {
    final dateButton = Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: widget.onChooseDay,
        child: Text(
          widget.dateLabel,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(flex: compact || !widget.isToday ? 1 : 7, child: dateButton),
        if (widget.isToday && !compact) const Spacer(flex: 3),
        if (!widget.isToday)
          TextButton(onPressed: widget.onToday, child: const Text('Today')),
      ],
    );
  }
}

class _TodaySkyPainter extends CustomPainter {
  const _TodaySkyPainter({
    required this.isDark,
    required this.hour,
    required this.showCelestial,
    required this.showHorizon,
    required this.glow,
    required this.surface,
    required this.featuredStart,
    required this.featuredEnd,
    required this.featuredWave,
  });

  final bool isDark;
  final int hour;
  final bool showCelestial;
  final bool showHorizon;
  final double glow;
  final Color surface;
  final Color featuredStart;
  final Color featuredEnd;
  final Color featuredWave;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final isNight = TodayHero.isNightForHour(hour);
    final celestialCenter = Offset(
      size.width * .82,
      TodayHero.celestialCenterY,
    );
    final sunColors = TodayHero.sunColorsForPalette(
      hour,
      featuredStart: featuredStart,
      featuredEnd: featuredEnd,
      featuredWave: featuredWave,
    );
    final moonColor = TodayHero.moonColorForAppearance(isDark: isDark);
    final celestialColor = isNight ? moonColor : sunColors[1];
    final pulse = math.sin(glow * math.pi);
    if (showCelestial) {
      canvas.save();
      canvas.translate(celestialCenter.dx, celestialCenter.dy);
      canvas.scale(1 + pulse * (isNight ? .018 : .024));
      if (isNight) {
        final glowOpacity = TodayHero.moonGlowOpacity(isDark: isDark);
        if (glowOpacity > 0) {
          const glowRadius = 26.0;
          canvas.drawCircle(
            Offset.zero,
            glowRadius,
            Paint()
              ..shader =
                  RadialGradient(
                    colors: [
                      celestialColor.withValues(alpha: glowOpacity),
                      celestialColor.withValues(alpha: 0),
                    ],
                    stops: const [0, 1],
                  ).createShader(
                    Rect.fromCircle(center: Offset.zero, radius: glowRadius),
                  ),
          );
        }
      } else {
        canvas.drawCircle(
          Offset.zero,
          TodayHero.sunHaloRadius,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    celestialColor.withValues(
                      alpha: (isDark ? .16 : .12) + pulse * .04,
                    ),
                    celestialColor.withValues(alpha: .04),
                    celestialColor.withValues(alpha: 0),
                  ],
                  stops: const [0, .58, 1],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset.zero,
                    radius: TodayHero.sunHaloRadius,
                  ),
                ),
        );
      }
      if (!isNight) {
        final rayPaint = Paint()
          ..color = sunColors[1].withValues(
            alpha: (isDark ? .62 : .72) + pulse * .1,
          )
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var index = 0; index < 8; index++) {
          final angle = index * math.pi / 4;
          final inner = Offset(math.cos(angle) * 22, math.sin(angle) * 22);
          final outer = Offset(
            math.cos(angle) * TodayHero.sunRayOuterRadius,
            math.sin(angle) * TodayHero.sunRayOuterRadius,
          );
          canvas.drawLine(inner, outer, rayPaint);
        }
      }
      if (isNight) {
        canvas.drawCircle(
          Offset.zero,
          22,
          Paint()
            ..color = TodayHero.moonOutlineColorForAppearance(isDark: isDark)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawCircle(
        Offset.zero,
        isNight ? 22 : TodayHero.sunDiscRadius,
        Paint()
          ..shader =
              RadialGradient(
                colors: isNight
                    ? [
                        Color.lerp(
                          moonColor,
                          Colors.white,
                          isDark ? .18 : .04,
                        )!,
                        moonColor,
                      ]
                    : sunColors,
              ).createShader(
                Rect.fromCircle(
                  center: Offset.zero,
                  radius: isNight ? 22 : TodayHero.sunDiscRadius,
                ),
              ),
      );
      if (isNight) {
        // A small offset cutout keeps a readable crescent instead of the
        // oversized pale disc that the previous halo made look like a full moon.
        canvas.drawCircle(const Offset(12, -10), 18, Paint()..color = surface);
        for (final star in const [
          Offset(-34, -16),
          Offset(32, 21),
          Offset(-25, 30),
        ]) {
          canvas.drawCircle(
            star,
            1.4,
            Paint()..color = featuredWave.withValues(alpha: .4 + pulse * .3),
          );
        }
      }
      canvas.restore();
    }

    if (!showHorizon || !TodayHero.showsHorizonForTheme(isDark: isDark)) {
      canvas.restore();
      return;
    }

    // Paint two broad, closed horizon ribbons behind the featured card. Keep
    // their upper and lower contours separate so they read as soft hills,
    // rather than thin crossing strokes or filled wedges around the card.
    // The scene sits in a tall card stack, so anchor the horizon to a bounded
    // header-sized space instead of stretching it across the full card.
    final horizonHeight = math.min(size.height, 350.0);
    final waveLeft = -size.width * .18;
    final waveRight = size.width * 1.18;
    final backWave = Path()
      ..moveTo(waveLeft, horizonHeight * .56)
      ..cubicTo(
        size.width * .20,
        horizonHeight * .48,
        size.width * .70,
        horizonHeight * .64,
        waveRight,
        horizonHeight * .50,
      )
      ..cubicTo(
        size.width * .86,
        horizonHeight * .62,
        size.width * .18,
        horizonHeight * .76,
        waveLeft,
        horizonHeight * .70,
      )
      ..close();
    canvas.drawPath(
      backWave,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                featuredWave.withValues(alpha: .13),
                featuredEnd.withValues(alpha: .035),
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                horizonHeight * .48,
                size.width,
                horizonHeight * .28,
              ),
            ),
    );

    final frontWave = Path()
      ..moveTo(waveLeft, horizonHeight * .72)
      ..cubicTo(
        size.width * .20,
        horizonHeight * .62,
        size.width * .72,
        horizonHeight * .82,
        waveRight,
        horizonHeight * .66,
      )
      ..cubicTo(
        size.width * .78,
        horizonHeight * .78,
        size.width * .16,
        horizonHeight * .90,
        waveLeft,
        horizonHeight * .86,
      )
      ..close();
    canvas.drawPath(
      frontWave,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                featuredWave.withValues(alpha: .085),
                featuredWave.withValues(alpha: .025),
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                horizonHeight * .62,
                size.width,
                horizonHeight * .30,
              ),
            ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TodaySkyPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.hour != hour ||
      oldDelegate.showCelestial != showCelestial ||
      oldDelegate.showHorizon != showHorizon ||
      oldDelegate.glow != glow ||
      oldDelegate.surface != surface ||
      oldDelegate.featuredStart != featuredStart ||
      oldDelegate.featuredEnd != featuredEnd ||
      oldDelegate.featuredWave != featuredWave;
}
