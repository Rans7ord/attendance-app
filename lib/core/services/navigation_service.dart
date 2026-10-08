import 'package:flutter/material.dart';

/// Global key so non-widget code (like the Dio 401 interceptor in
/// ApiService) can navigate without needing a BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();