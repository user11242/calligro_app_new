import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calligro_app/features/auth/widgets/link_account_dialog.dart';
import 'package:calligro_app/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('Layer 3: Dialogs -> LinkAccountDialog (Coverage)', () {
    testWidgets('LinkAccountDialog renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const LinkAccountDialog(email: 'test@example.com', provider: 'google'),
      ));
      
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      
      // Should find a password TextField
      expect(find.byType(TextField), findsOneWidget);
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, true);
    });

    testWidgets('LinkAccountDialog toggles password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(
        const LinkAccountDialog(email: 'test@example.com'),
      ));
      
      await tester.pumpAndSettle();

      TextField textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, true);

      // Tap the visibility icon
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, false);
      
      // Tap again
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, true);
    });

    testWidgets('LinkAccountDialog close button dismisses dialog', (WidgetTester tester) async {
      bool isClosed = false;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => const LinkAccountDialog(email: 'test'),
              );
              isClosed = true;
            },
            child: const Text('Open'),
          ),
        ),
      ));
      
      // Open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      // Close via X button (assuming there's a TextButton with label 'Cancel' or standard l10n)
      // Since it's localized, let's find the Cancel text by its l10n translation
      // Usually it's 'Cancel' in English
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(isClosed, true);
    });
  });
}
