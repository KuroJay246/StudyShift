import 'package:flutter/widgets.dart';

/// Layout tokens from the owner-approved StudyShift design specification.
abstract final class StudyShiftSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;

  static const double pageMargin = 16;
  static const double expandedPageMargin = 24;
  static const double appBarHeight = 64;
  static const double bottomNavigationHeight = 80;
  static const double cardPadding = 16;
  static const double cardRadius = 16;
  static const double largeRadius = 24;
  static const double inputHeight = 56;
  static const double buttonHeight = 48;
  static const double buttonRadius = 14;
  static const double filterChipHeight = 36;
  static const double fabSize = 56;
  static const double touchTarget = 48;

  static const pageInsets = EdgeInsets.symmetric(horizontal: pageMargin);
}
