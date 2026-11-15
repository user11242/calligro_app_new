import 'package:calligro_app/features/auth/application/email_codes.dart';
import 'package:calligro_app/features/auth/domain/email_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_auth.dart';

void main() {
  late FakeEmailCodeGateway server;
  late EmailCodes codes;
  setUp(() {
    server = FakeEmailCodeGateway();
    codes = EmailCodes(gateway: server);
  });

  test('send: sent / cooldown / failed', () async {
    expect(await codes.send(' a@x.com '), SendCodeOutcome.sent);
    expect(server.sent, ['a@x.com']);
    server.cooldown = true;
    expect(await codes.send('a@x.com'), SendCodeOutcome.cooldown);
    server
      ..cooldown = false
      ..failSend = Exception('down');
    expect(await codes.send('a@x.com'), SendCodeOutcome.failed);
  });

  test('registration: the SERVER decides (the phone used to compare the code itself)', () async {
    await codes.send('a@x.com');
    expect(await codes.verify('a@x.com', '111111', purpose: EmailCodePurpose.register), EmailCodeCheck.wrong);
    expect(await codes.verify('a@x.com', '482913', purpose: EmailCodePurpose.register), EmailCodeCheck.ok);
    expect(await codes.verify('a@x.com', '482913', purpose: EmailCodePurpose.register), EmailCodeCheck.missing,
        reason: 'used once');
    expect(await codes.verify('a@x.com', '12', purpose: EmailCodePurpose.register), EmailCodeCheck.wrong,
        reason: 'incomplete codes are not even sent');
  });

  test('password reset (THE BUG: it never worked): verify keeps the code, the final step uses it', () async {
    await codes.send('a@x.com');
    expect(await codes.verify('a@x.com', '482913', purpose: EmailCodePurpose.reset), EmailCodeCheck.ok);
    await codes.resetPassword('a@x.com', '482913', 'newSecret1');
    expect(server.resets.single.password, 'newSecret1');
    expect(() => codes.resetPassword('a@x.com', '482913', 'again'), throwsException, reason: 'a code works once');
  });

  test('five wrong tries lock the code (no guessing)', () async {
    await codes.send('a@x.com');
    for (var i = 0; i < 4; i++) {
      expect(await codes.verify('a@x.com', '000000', purpose: EmailCodePurpose.reset), EmailCodeCheck.wrong);
    }
    expect(await codes.verify('a@x.com', '000000', purpose: EmailCodePurpose.reset), EmailCodeCheck.locked);
    expect(await codes.verify('a@x.com', '482913', purpose: EmailCodePurpose.reset), EmailCodeCheck.missing);
  });
}
