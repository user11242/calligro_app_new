import 'package:calligro_app/core/services/deep_link_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLinkService FCM Routing', () {
    testWidgets('navigates to /courseChat with course arguments from FCM data',
        (tester) async {
      Map<String, dynamic>? capturedArgs;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: DeepLinkService().navigatorKey,
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/courseChat': (context) {
              capturedArgs = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              return const Scaffold(body: Text('Course Chat Screen'));
            },
          },
        ),
      );

      DeepLinkService().handleFcmData({
        'route': '/courseChat',
        'courseId': 'course_99',
        'courseName': 'Naskh Basics',
        'teacherId': 'teacher_7',
      });

      await tester.pumpAndSettle();

      expect(find.text('Course Chat Screen'), findsOneWidget);
      expect(capturedArgs?['courseId'], 'course_99');
      expect(capturedArgs?['courseName'], 'Naskh Basics');
      expect(capturedArgs?['teacherId'], 'teacher_7');
    });

    testWidgets('ignores /courseChat payload when courseId is missing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: DeepLinkService().navigatorKey,
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/courseChat': (_) => const Scaffold(body: Text('Course Chat Screen')),
          },
        ),
      );

      DeepLinkService().handleFcmData({'route': '/courseChat'});
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Course Chat Screen'), findsNothing);
    });
  });
}

