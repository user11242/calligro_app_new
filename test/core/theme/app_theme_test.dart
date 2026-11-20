import 'package:calligro_app/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Android "flash" between pages: the page animation paints a background while it
/// runs. It must be black like the pages, never the theme's light default surface.
void main() {
  test('Android page animation paints black, not the light default', () {
    final builder = AppTheme.build().pageTransitionsTheme.builders[TargetPlatform.android];
    expect(builder, isA<PredictiveBackPageTransitionsBuilder>());
    expect((builder as PredictiveBackPageTransitionsBuilder).fallbackColor, Colors.black);
    expect(ThemeData().colorScheme.surface.computeLuminance(), greaterThan(0.8),
        reason: 'the default it replaces really is almost white');
  });

  testWidgets('mid-animation on Android, nothing light is painted between two dark pages', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      navigatorKey: nav,
      home: const Scaffold(body: SizedBox.expand()),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox.expand())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // in the middle of the animation

    final painted = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((b) => b.color)
        .where((c) => c.a > 0)
        .toList();
    expect(painted, isNotEmpty);
    for (final c in painted) {
      expect(c.computeLuminance(), lessThan(0.05), reason: 'a light colour ($c) would flash');
    }
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });
}
