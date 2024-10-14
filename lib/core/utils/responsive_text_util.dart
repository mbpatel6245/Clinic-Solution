import 'package:flutter/material.dart';

class ResponsiveTextUtil {
  // Static method to get a responsive font size based on screen size and platform
  static double getResponsiveFontSize(
      BuildContext context, {
        double baseFontSize = 14.0,
      }) {
    // Fetch screen dimensions
    double deviceWidth = MediaQuery.of(context).size.width;
    double deviceHeight = MediaQuery.of(context).size.height;
    TargetPlatform platform = Theme.of(context).platform;

    // Factor to adjust size based on platform (Optional)
    double platformFactor = _getPlatformFactor(platform);

    // Calculate size factor based on screen size
    double sizeFactor = (deviceWidth + deviceHeight) / 1500;

    // Return final font size by adjusting the base font size
    return baseFontSize * sizeFactor * platformFactor;
  }

  // Private method to return platform-based adjustments (Optional)
  static double _getPlatformFactor(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 1.20;  // Keep font size as is on mobile platforms
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 0.7;  // Slightly larger for desktop platforms
      case TargetPlatform.fuchsia:
      default:
        return 1.0;
    }
  }
}
