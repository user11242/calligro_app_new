import 'dart:async';

import 'package:calligro_app/features/admin/presentation/widgets/send_user_notification_dialog.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, String)> sent;
  late Completer<void> server;
  bool? result;

  Future<void> open(WidgetTester tester, {Future<void> Function(String, String)? send}) async {
    sent = [];
    server = Completer<void>();
    result = null;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<bool>(
              context: context,
              builder: (_) => SendUserNotificationDialog(
                userName: 'yazan Akq',
                send: send ??
                    (t, b) {
                      sent.add((t, b));
                      return server.future;
                    },
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Hello');
    await tester.enterText(find.byType(TextField).at(1), 'Your class moved');
  }

  testWidgets('a slow send shows a spinner and a second tap sends nothing more', (tester) async {
    await open(tester);
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton)); // impatient second tap
    await tester.pump();
    expect(sent, [('Hello', 'Your class moved')], reason: 'sent exactly once');

    server.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SendUserNotificationDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('a server error is shown in the dialog (no unhandled error), and Send works again', (tester) async {
    var calls = 0;
    await open(tester, send: (t, b) async {
      calls++;
      if (calls == 1) throw Exception('[firebase_functions/internal] token expired');
    });
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sendNotificationError')), findsOneWidget);
    expect(find.byType(SendUserNotificationDialog), findsOneWidget, reason: 'stays open, text kept');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(result, isTrue);
  });

  testWidgets('empty title or body sends nothing', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sent, isEmpty);
  });

  testWidgets('cancel closes without sending', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    expect(result, isFalse);
  });
}
