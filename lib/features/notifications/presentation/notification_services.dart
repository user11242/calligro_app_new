import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../application/notification_opener.dart';
import '../application/push_tokens.dart';
import '../data/firestore_notification_repositories.dart';
import '../domain/notification_repositories.dart';

/// The app-wide notification services. ONE opener for the whole app (push
/// handlers in main.dart, the inbox and the in-app banner all use it).
class NotificationServices {
  NotificationServices({
    required this.opener,
    required this.inbox,
    required this.tokens,
    required this.currentUid,
  });

  static NotificationServices? _instance;
  static NotificationServices get instance => _instance ??= NotificationServices(
        opener: NotificationOpener(),
        inbox: FirestoreInboxRepository(),
        tokens: PushTokens(gateway: FirebasePushGateway(), store: FirestorePushTokenStore()),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid ?? '',
      );

  final NotificationOpener opener;
  final InboxRepository inbox;
  final PushTokens tokens;
  final String Function() currentUid;
}

class NotificationScope extends InheritedWidget {
  const NotificationScope({super.key, required this.services, required super.child});
  final NotificationServices services;

  static NotificationServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>()?.services ?? NotificationServices.instance;

  @override
  bool updateShouldNotify(NotificationScope oldWidget) => services != oldWidget.services;
}
