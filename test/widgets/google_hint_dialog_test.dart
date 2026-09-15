import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/auth/widgets/google_hint_dialog.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'dart:io' show Platform;

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => child,
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  group('Layer 3: Dialogs -> GoogleHintDialog (Coverage)', () {
    testWidgets('GoogleHintDialog renders correctly and handles Google tap', (WidgetTester tester) async {
      bool googleTapped = false;

      await tester.pumpWidget(buildTestableWidget(
        GoogleHintDialog(
          onContinue: () {
            googleTapped = true;
          },
        ),
      ));
      
      // Open the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify content
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
      
      // Tap Google button
      // Since it's an ElevatedButton with an image icon, we can find it by type or text if we know the localized text.
      // But finding by type is easier:
      final buttons = find.byType(ElevatedButton);
      expect(buttons, findsWidgets); // There might be multiple ElevatedButtons in the tree
      
      // Let's just tap the first one inside the Dialog
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(ElevatedButton)).first);
      await tester.pumpAndSettle();

      expect(googleTapped, true);
    });

    testWidgets('GoogleHintDialog maybeLater button closes the dialog', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        GoogleHintDialog(
          onContinue: () {},
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      // Find the "Maybe Later" TextButton
      final maybeLater = find.byType(TextButton);
      await tester.tap(maybeLater);
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
