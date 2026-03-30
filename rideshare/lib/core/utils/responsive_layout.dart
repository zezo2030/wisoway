import 'package:flutter/material.dart';

enum DeviceType { phone, tablet, desktop }

class ResponsiveLayout {
  static const double phoneBreakpoint = 768;
  static const double tabletBreakpoint = 1024;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < phoneBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool useNavigationRail(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneBreakpoint;

  static double getNavigationRailWidth(BuildContext context) {
    if (MediaQuery.of(context).size.width >= tabletBreakpoint) {
      return 80;
    }
    return 72;
  }

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneBreakpoint) return DeviceType.phone;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }
}
