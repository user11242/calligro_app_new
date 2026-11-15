import 'package:calligro_app/features/auth/application/email_codes.dart';
import 'package:calligro_app/features/auth/domain/email_code.dart';
import 'package:calligro_app/features/auth/presentation/auth_scope.dart';
import 'package:calligro_app/features/auth/widgets/verification/universal_otp_step.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_auth.dart';

/// The real code step (email) with the real EmailCodes, on a fake server.
void main() {
  late FakeEmailCodeGateway server;
  late GlobalKey<UniversalOtpStepState> key;
  var verified = 0;

  Future<void> pump(WidgetTester tester, {EmailCodePurpose purpose = EmailCodePurpose.register}) async {
    server = FakeEmailCodeGateway();
    key = GlobalKey<UniversalOtpStepState>();
    verified = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: AuthScope(
        services: AuthServices(emailCodes: EmailCodes(gateway: server)),
        child: Scaffold(
          body: UniversalOtpStep(key: key, destination: 'sara@x.com', emailPurpose: purpose, onVerified: () => verified++),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Types the code; the field submits by itself once 6 digits are in.
  Future<void> type(WidgetTester tester, String code) async {
    key.currentState!.otpController.text = code;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 4)); // let snack bars finish
  }

  testWidgets('the code is requested from the SERVER when the step opens', (tester) async {
    await pump(tester);
    expect(server.sent, ['sara@x.com']);
    expect(find.text('Check your inbox.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a wrong code is refused by the server (the phone used to compare it itself)', (tester) async {
    await pump(tester);
    await type(tester, '000000');
    expect(verified, 0);
    expect(server.attempts['sara@x.com'], 1, reason: 'checked by the server');
  });

  testWidgets('the right code passes; Arabic digits work too', (tester) async {
    await pump(tester);
    await type(tester, '٤٨٢٩١٣');
    expect(verified, 1);
    expect(key.currentState!.verifiedCode, '482913');
  });

  testWidgets('password reset: the code is kept for the final step', (tester) async {
    await pump(tester, purpose: EmailCodePurpose.reset);
    await type(tester, '482913');
    expect(verified, 1);
    expect(server.codes['sara@x.com'], '482913', reason: 'still there for resetPasswordWithOtp');
  });

  testWidgets('asking again too soon shows the wait message instead of failing silently', (tester) async {
    server = FakeEmailCodeGateway()..cooldown = true;
    key = GlobalKey<UniversalOtpStepState>();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: AuthScope(
        services: AuthServices(emailCodes: EmailCodes(gateway: server)),
        child: Scaffold(body: UniversalOtpStep(key: key, destination: 'sara@x.com', onVerified: () {})),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Too many failed attempts. Please try again later.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
