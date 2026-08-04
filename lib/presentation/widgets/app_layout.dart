import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class AppLayout {
  AppLayout._();

  static const double pageHorizontalPadding = 16;
  static const double pageMaxContentWidth = 720;

  static EdgeInsets pageInsets(
    BoxConstraints constraints, {
    double top = 12,
    double bottom = 12,
  }) {
    final sideInset =
        pageHorizontalPadding +
        math.max(0.0, constraints.maxWidth - pageMaxContentWidth) / 2;
    return EdgeInsets.fromLTRB(sideInset, top, sideInset, bottom);
  }
}
