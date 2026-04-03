// lib/core/services/deep_link_service.dart

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

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
    
    // Pattern: https://calligro.digital/post/ID
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
      final String postId = uri.pathSegments[1];
      _navigateToPost(postId);
    }
  }

  void _navigateToPost(String postId) {
    // Adding a slight delay to ensure navigator is mounted on cold boot
    Future.microtask(() {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          '/postDetails',
          arguments: {'postId': postId},
        );
      }
    });
  }

  /// Handle data from Firebase Cloud Messaging (FCM)
  void handleFcmData(Map<String, dynamic> data) {
    debugPrint("Handling FCM data: $data");
    // Example: {route: /postDetails, postId: 123}
    if (data.containsKey('route') && data['route'] == '/postDetails' && data.containsKey('postId')) {
      _navigateToPost(data['postId']);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
