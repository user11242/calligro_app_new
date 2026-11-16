import 'package:flutter/widgets.dart';

import '../application/email_codes.dart';
import '../data/services/auth_service.dart';
import '../data/cloud_email_codes.dart';

/// What the auth screens talk to. The ONLY place that picks real implementations.
class AuthServices {
  AuthServices({required this.emailCodes, AuthService? account}) : _account = account;

  static AuthServices? _instance;
  static AuthServices get instance => _instance ??= AuthServices(emailCodes: EmailCodes(gateway: CloudEmailCodes()));

  final EmailCodes emailCodes;
  AuthService? _account;

  /// Sign-in, sign-up and session (the data-layer facade). Created on first use.
  AuthService get account => _account ??= AuthService();
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
