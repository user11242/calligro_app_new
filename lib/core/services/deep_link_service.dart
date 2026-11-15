// lib/core/services/deep_link_service.dart

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/features/notifications/presentation/notification_services.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void init() {
    _appLinks = AppLinks();
    _handleInitialLink();
    _listenToLinks();
  }

  Future<void> _handleInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint("Failed to get initial link: $e");
    }
  }

  void _listenToLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint("Link listener error: $err");
      },
    );
  }

  void _handleUri(Uri uri) {
    debugPrint("Handling incoming link: $uri");
    
    // Pattern: https://calligroacademy.com/post/ID
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
      final String postId = uri.pathSegments[1];
      _pushNamed('/postDetails', {'postId': postId});
    }
  }

  void _pushNamed(String routeName, Map<String, dynamic> arguments) {
    // Adding a slight delay to ensure navigator is mounted on cold boot
    Future.microtask(() {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
      }
    });
  }

  /// Notification taps go through NotificationServices.instance.opener
  /// (lib/features/notifications), which knows every route the server sends.
  void handleFcmData(Map<String, dynamic> data) => NotificationServices.instance.opener.openData(data);

  void dispose() {
    _linkSubscription?.cancel();
  }
}
