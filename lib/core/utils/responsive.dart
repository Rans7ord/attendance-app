import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  /// Wraps content in a centered, max-width column on wide screens;
  /// full width on mobile. Use this for forms like login.
  static Widget centeredForm(BuildContext context, Widget child, {double maxWidth = 420}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile(context) ? double.infinity : maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}