import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Local Lucide artwork for app navigation and high frequency actions.
///
/// Assets are bundled with the app, so rendering never makes a network request.
class ShiftIcon extends StatelessWidget {
  const ShiftIcon(this.name, {super.key, this.size = 24});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/lucide/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}
