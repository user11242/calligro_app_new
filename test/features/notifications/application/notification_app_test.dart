import 'package:calligro_app/features/notifications/application/notification_opener.dart';
import 'package:calligro_app/features/notifications/application/push_tokens.dart';
import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_notifications.dart';

void main() {
  group('opening a tapped notification', () {
    var now = DateTime(2026, 11, 15, 12);
    late NotificationOpener opener;
    late RecordingNavigator nav;

    setUp(() {
      now = DateTime(2026, 11, 15, 12);
      opener = NotificationOpener(clock: () => now);
      nav = RecordingNavigator();
    });

    test('a dashboard on screen opens it right away', () {
      opener.attach(nav);
      opener.openData({'route': '/courseDetails', 'courseId': 'c1'});
      expect(nav.opened, [const CourseTarget('c1')]);
    });

    test('tapped while the app was closed: kept, then opened once a dashboard is up (it was lost under the splash)', () {
      opener.openData({'route': '/postDetails', 'postId': 'p1'});
      expect(nav.opened, isEmpty);
      expect(opener.pending, const PostTarget('p1'));
      opener.attach(nav);
      expect(nav.opened, [const PostTarget('p1')]);
      expect(opener.pending, isNull);
    });

    test('the same tap reported twice (tray + launch message) opens one screen', () {
      opener.attach(nav);
      opener.openData({'route': '/profile', 'userId': 'u1'});
      now = now.add(const Duration(milliseconds: 800));
      opener.openData({'route': '/profile', 'userId': 'u1'});
      expect(nav.opened, hasLength(1));
      now = now.add(const Duration(seconds: 5));
      opener.openData({'route': '/profile', 'userId': 'u1'});
      expect(nav.opened, hasLength(2), reason: 'a real second tap later still works');
    });

    test('signing out / leaving the dashboard: taps wait for the next one', () {
      opener.attach(nav);
      opener.detach(nav);
      opener.open(const InboxTarget());
      expect(nav.opened, isEmpty);
      final next = RecordingNavigator();
      opener.attach(next);
      expect(next.opened, [const InboxTarget()]);
    });
  });

  group('push tokens (THE BUG: one phone, several accounts → 2-3 copies)', () {
    test('register saves this device\'s token; sign-out removes it and resets the device token', () async {
      final gateway = FakePushGateway();
      final store = FakePushTokenStore();
      final tokens = PushTokens(gateway: gateway, store: store);
      await tokens.register('a', language: 'en');
      expect(store.tokens, {'a': 'tok-1'});

      await tokens.unregister('a');
      expect(store.tokens, isEmpty);
      expect(gateway.deletes, 1);

      await tokens.register('b', language: 'ar');
      expect(store.tokens, {'b': 'tok-2'}, reason: 'the next account gets a fresh token; account a no longer has one');
    });

    test('no permission / no token: nothing saved; signed out: nothing done', () async {
      final store = FakePushTokenStore();
      await PushTokens(gateway: FakePushGateway()..currentToken = null, store: store).register('a', language: 'en');
      expect(store.tokens, isEmpty);
      await PushTokens(gateway: FakePushGateway(), store: store).register('', language: 'en');
      expect(store.tokens, isEmpty);
    });
  });
}
