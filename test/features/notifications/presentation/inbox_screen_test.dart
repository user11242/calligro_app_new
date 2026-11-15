import 'package:calligro_app/features/notifications/application/notification_opener.dart';
import 'package:calligro_app/features/notifications/application/push_tokens.dart';
import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:calligro_app/features/notifications/presentation/notification_services.dart';
import 'package:calligro_app/features/notifications/presentation/notifications_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_notifications.dart';

/// The real inbox screen on a fake inbox, with the real opener.
void main() {
  late FakeInboxRepository inbox;
  late RecordingNavigator nav;

  Future<void> pump(WidgetTester tester) async {
    final opener = NotificationOpener()..attach(nav);
    final services = NotificationServices(
      opener: opener,
      inbox: inbox,
      tokens: PushTokens(gateway: FakePushGateway(), store: FakePushTokenStore()),
      currentUid: () => 'u1',
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: NotificationScope(services: services, child: const NotificationsPage()),
    ));
    // Let the list's slide-in animation finish (several frames, not one jump).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void init() {
    nav = RecordingNavigator();
    inbox = FakeInboxRepository()
      ..put('u1', InboxItem(id: 'n1', title: 'Payout Completed', body: 'Done', createdAt: DateTime(2026, 11, 1)))
      ..put('u1', InboxItem(id: 'n2', title: 'New Assignment', body: 'Alif drills', type: 'assignment', createdAt: DateTime(2026, 11, 10),
          target: const CourseTarget('c1')));
  }

  testWidgets('tapping an item opens what it is about and marks it read (it used to open nothing)', (tester) async {
    init();
    await pump(tester);
    await tester.tap(find.text('New Assignment'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(nav.opened, [const CourseTarget('c1')]);
    expect(inbox.readCalls, ['n2']);
  });

  testWidgets('an item with no destination is just marked read (no loop back into the inbox)', (tester) async {
    init();
    await pump(tester);
    await tester.tap(find.text('Payout Completed'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(nav.opened, isEmpty);
    expect(inbox.readCalls, ['n1']);
  });

  testWidgets('mark all read', (tester) async {
    init();
    await pump(tester);
    await tester.tap(find.byIcon(Icons.done_all));
    await tester.pump(const Duration(milliseconds: 300));
    expect(inbox.items['u1']!.every((i) => i.read), isTrue);
  });
}
