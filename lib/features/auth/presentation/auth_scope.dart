import 'package:flutter/widgets.dart';

import '../application/email_codes.dart';
import '../data/cloud_email_codes.dart';

/// What the auth screens talk to. The ONLY place that picks real implementations.
class AuthServices {
  AuthServices({required this.emailCodes});

  static AuthServices? _instance;
  static AuthServices get instance => _instance ??= AuthServices(emailCodes: EmailCodes(gateway: CloudEmailCodes()));

  final EmailCodes emailCodes;
}

class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.services, required super.child});
  final AuthServices services;

  /// Auth screens are reached before any dashboard: without a scope the same
  /// cached real services are used.
  static AuthServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.services ?? AuthServices.instance;

  @override
  bool updateShouldNotify(AuthScope oldWidget) => services != oldWidget.services;
}
