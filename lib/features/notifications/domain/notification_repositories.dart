import 'notification_models.dart';

/// users/{uid}/notifications (written by the server).
abstract interface class InboxRepository {
  /// Newest first, live.
  Stream<List<InboxItem>> watch(String uid);
  Stream<int> watchUnreadCount(String uid);
  Future<void> markRead(String uid, String itemId);
  Future<void> markAllRead(String uid);
}

/// The device's push token on the user's document.
abstract interface class PushTokenStore {
  Future<void> save(String uid, String token, {required String language});

  /// Removes [token] from [uid] (only if it is still that user's token).
  Future<void> clear(String uid, String token);
}

/// The push service on this device (FCM).
abstract interface class PushGateway {
  /// Asks permission and returns this device's token (null = denied/unavailable).
  Future<String?> token();
  Future<void> deleteToken();
}

/// Opens screens (implemented by the presentation layer).
abstract interface class NotificationNavigator {
  void open(NotificationTarget target);
}
