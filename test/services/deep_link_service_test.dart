import 'package:calligro_app/core/services/deep_link_service.dart';
import 'package:calligro_app/features/notifications/domain/notification_models.dart';
import 'package:calligro_app/features/notifications/presentation/notification_services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/notifications/fakes/fake_notifications.dart';

/// Pushes routed by DeepLinkService go through the app's ONE notification opener.
void main() {
  group('DeepLinkService FCM routing', () {
    test('a course chat push opens the course chat with its details', () {
      final nav = RecordingNavigator();
      NotificationServices.instance.opener.attach(nav);
      addTearDown(() => NotificationServices.instance.opener.detach(nav));
      DeepLinkService().handleFcmData({
        'route': '/courseChat',
        'courseId': 'course_99',
        'courseName': 'Naskh Basics',
        'teacherId': 'teacher_7',
      });
      expect(nav.opened.single, const CourseChatTarget('course_99', courseName: 'Naskh Basics', teacherId: 'teacher_7'));
    });

    test('an incomplete course chat push opens the inbox instead of nothing', () {
      final nav = RecordingNavigator();
      NotificationServices.instance.opener.attach(nav);
      addTearDown(() => NotificationServices.instance.opener.detach(nav));
      DeepLinkService().handleFcmData({'route': '/courseChat'});
      expect(nav.opened.single, const InboxTarget());
    });
  });
}
