import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Layer 3: Core Widgets -> ProfileAvatar (Coverage)', () {
    testWidgets('ProfileAvatar renders placeholder icon when imageUrl is null', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfileAvatar(imageUrl: null),
      ));
      
      // Should find the CircleAvatar and the placeholder Icon (Icons.person)
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      
      // Should not use SmartImage when url is null
      expect(find.byType(SmartImage), findsNothing);
    });

    testWidgets('ProfileAvatar renders SmartImage when imageUrl is valid', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfileAvatar(imageUrl: 'https://example.com/photo.jpg'),
      ));
      
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(SmartImage), findsOneWidget);
    });

    testWidgets('ProfileAvatar responds to onTap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(buildTestableWidget(
        ProfileAvatar(
          imageUrl: null,
          onTap: () {
            tapped = true;
          },
        ),
      ));
      
      await tester.tap(find.byType(ProfileAvatar));
      expect(tapped, true);
    });

    testWidgets('ProfileAvatar wraps in Hero if heroTag is provided', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const ProfileAvatar(
          imageUrl: null,
          heroTag: 'my-hero-tag',
        ),
      ));
      
      expect(find.byType(Hero), findsOneWidget);
      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'my-hero-tag');
    });
  });
}
