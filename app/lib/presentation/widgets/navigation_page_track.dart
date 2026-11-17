import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Moves the retained main-navigation pages without rebuilding their content
/// for every pointer or animation tick.
class NavigationPageTrack extends StatelessWidget {
  const NavigationPageTrack({
    super.key,
    required this.pagePosition,
    required this.pageWidth,
    required this.selectedIndex,
    required this.pages,
  });

  final ValueListenable<double> pagePosition;
  final double pageWidth;
  final int selectedIndex;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.hardEdge,
    children: [
      for (var index = 0; index < pages.length; index++)
        Positioned.fill(
          child: AnimatedBuilder(
            animation: pagePosition,
            child: TickerMode(
              enabled: index == selectedIndex,
              child: ExcludeSemantics(
                excluding: index != selectedIndex,
                child: IgnorePointer(
                  ignoring: index != selectedIndex,
                  child: pages[index],
                ),
              ),
            ),
            builder: (context, child) => Transform.translate(
              key: Key('navigation-page-transform-$index'),
              offset: Offset((index - pagePosition.value) * pageWidth, 0),
              child: child,
            ),
          ),
        ),
    ],
  );
}
