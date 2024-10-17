/*
 * Copyright (C) 2023. Aatmunn Inc. All rights reserved.
 *
 * The copyright to the computer software herein is the property of GuardHat
 * Inc. This software may not be used and/or copied without
 * explicit written permission of Aatmunn Inc, and only in accordance
 * with the terms and conditions stipulated in the license agreement and/or
 * contract under which the software has been supplied.
 *
 */

import 'package:clinic_solution/main.dart';
import 'package:flutter/material.dart';


// This is where the magic happens.
// This functions are responsible to make UI responsive across all the mobile devices.

Size size = View.of(navigatorKey.currentContext!).physicalSize /
    View.of(navigatorKey.currentContext!).devicePixelRatio;

// Caution! If you think these are static values and are used to build a static UI,  you mustn’t.
// These are the Viewport values of your Figma Design.
// These are used in the code as a reference to create your UI Responsively.
num SCREEN_DESIGN_WIDTH = (MediaQuery.of(navigatorKey.currentContext!).size.width );
num SCREEN_DESIGN_HEIGHT = (MediaQuery.of(navigatorKey.currentContext!).size.height );
num FIGMA_DESIGN_STATUS_BAR = MediaQuery.of(navigatorKey.currentContext!).viewPadding.top;

///This method is used to get device viewport width.
get width {
  return size.width;
}

///This method is used to get device viewport height.
get height {
  num statusBar =
      MediaQueryData.fromView(View.of(navigatorKey.currentContext!)).viewPadding.top;
  num bottomBar = MediaQueryData.fromView(View.of(navigatorKey.currentContext!))
      .viewPadding
      .bottom;
  num screenHeight = size.height - statusBar - bottomBar;
  return screenHeight;
}

///This method is used to set padding/margin (for the left and Right side) & width of the screen or widget according to the Viewport width.
double getHorizontalSize(double px) {
  return ((px * width) / SCREEN_DESIGN_WIDTH);
}

///This method is used to set padding/margin (for the top and bottom side) & height of the screen or widget according to the Viewport height.
double getVerticalSize(double px) {
  return ((px * height) / (SCREEN_DESIGN_HEIGHT - FIGMA_DESIGN_STATUS_BAR));
}

///This method is used to set smallest px in image height and width
double getSize(double px) {
  var height = getVerticalSize(px);
  var width = getHorizontalSize(px);
  if (height < width) {
    return height.toInt().toDouble();
  } else {
    return width.toInt().toDouble();
  }
}

///This method is used to set text font size according to Viewport
double getFontSize(double px) {
  return getSize(px);
}

///This method is used to set padding responsively
EdgeInsetsGeometry getPadding({
  double? all,
  double? left,
  double? top,
  double? right,
  double? bottom,
}) {
  return getMarginOrPadding(
    all: all,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );
}

///This method is used to set margin responsively
EdgeInsetsGeometry getMargin({
  double? all,
  double? left,
  double? top,
  double? right,
  double? bottom,
}) {
  return getMarginOrPadding(
    all: all,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );
}

///This method is used to get padding or margin responsively
EdgeInsetsGeometry getMarginOrPadding({
  double? all,
  double? left,
  double? top,
  double? right,
  double? bottom,
}) {
  if (all != null) {
    left = all;
    top = all;
    right = all;
    bottom = all;
  }
  return EdgeInsets.only(
    left: getHorizontalSize(
      left ?? 0,
    ),
    top: getVerticalSize(
      top ?? 0,
    ),
    right: getHorizontalSize(
      right ?? 0,
    ),
    bottom: getVerticalSize(
      bottom ?? 0,
    ),
  );
}


/// The function calculates the size of a given text with a specified text style.
///
/// Args:
///   text (String): The text for which the size needs to be calculated.
///   style (TextStyle): TextStyle is a class in Flutter that defines the visual
/// properties of a text widget, such as font size, font weight, font style, color,
/// etc. It is used to customize the appearance of text in a Flutter app. The
/// TextStyle parameter in the calculateTextSize method specifies the style of the
/// text
// Size calculateTextSize(String text, TextStyle style) {
//   final TextPainter textPainter = TextPainter(
//     text: TextSpan(text: text, style: style),
//     textDirection: TextDirection.ltr,
//     textScaleFactor: Get.textScaleFactor/*WidgetsBinding.instance.window.textScaleFactor*/,
//   )..layout();
//   return textPainter.size;
// }
