import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('Layer 3: Core Widgets -> SmartImage (Coverage)', () {
    testWidgets('SmartImage renders local asset correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const SmartImage(
          imageUrl: 'assets/images/logo.png', // Typical asset path
          width: 100,
          height: 100,
        ),
      ));
      
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('SmartImage renders CachedNetworkImage for URLs', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const SmartImage(
          imageUrl: 'https://example.com/image.jpg',
        ),
      ));
      
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('SmartImage applies BorderRadius using ClipRRect', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        SmartImage(
          imageUrl: 'assets/images/logo.png',
          borderRadius: BorderRadius.circular(10),
        ),
      ));
      
      expect(find.byType(ClipRRect), findsOneWidget);
      final clipRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRect.borderRadius, BorderRadius.circular(10));
    });

    testWidgets('SmartImage applies ColorFilter correctly to asset images', (WidgetTester tester) async {
      const filter = ColorFilter.mode(Colors.red, BlendMode.srcIn);
      await tester.pumpWidget(buildTestableWidget(
        const SmartImage(
          imageUrl: 'assets/images/logo.png',
          colorFilter: filter,
        ),
      ));
      
      expect(find.byType(ColorFiltered), findsOneWidget);
      final colorFiltered = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(colorFiltered.colorFilter, filter);
    });
  });
}
