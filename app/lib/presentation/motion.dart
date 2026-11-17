import 'package:flutter/material.dart';

/// Shared timing for routine schedule transitions.
abstract final class AppMotion {
  static const entrance = Duration(milliseconds: 210);
  static const exit = Duration(milliseconds: 168);
  static const change = Duration(milliseconds: 200);
  static const staggerStep = Duration(milliseconds: 30);
  static const maxStaggerRows = 8;

  static Duration duration(BuildContext context, Duration preferred) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;

  static Widget sharedFadeSlide(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
}
