import 'package:calligro_app/features/teacher_money/data/payout_settings_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payout details (IBAN, address, CliQ alias) are private: they live in
/// users/{uid}/private/payout, never on the public users / teachers documents.
void main() {
  late FakeFirebaseFirestore db;
  late PayoutSettingsRepository repo;

  const bank = PayoutSettings(
    selectedMethod: PayoutSettings.bankTransfer,
    bankName: 'Arab Bank',
    accountName: 'Ali Hassan',
    swift: 'ARABJOAX',
    iban: 'JO94CBJO0010000000000131000302',
    country: 'Jordan',
    city: 'Amman',
    street: 'Main St',
    postalCode: '11118',
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = PayoutSettingsRepository(firestore: db);
    await db.collection('users').doc('t1').set({'name': 'Ali', 'role': 'teacher'});
    await db.collection('teachers').doc('t1').set({'role': 'teacher'});
  });

  test('saves into the private document only', () async {
    await repo.save('t1', bank);

    final private = await db.doc('users/t1/private/payout').get();
    expect(private.data()!['selectedMethod'], 'bankTransfer');
    expect((private.data()!['bankTransfer'] as Map)['iban'], bank.iban);
    expect(private.data()!['cliq'], isNull, reason: 'only the active method is kept');

    for (final path in ['users/t1', 'teachers/t1']) {
      final public = (await db.doc(path).get()).data()!;
      expect(public.containsKey('payoutSettings'), isFalse, reason: '$path is public');
      expect(public.toString(), isNot(contains(bank.iban)), reason: '$path is public');
    }
  });

  test('loads what was saved (round trip)', () async {
    await repo.save('t1', bank);
    expect(await repo.load('t1'), bank);

    const cliq = PayoutSettings(selectedMethod: PayoutSettings.cliq, cliqAlias: 'ALI.H', cliqHolderName: 'Ali Hassan');
    await repo.save('t1', cliq);
    final loaded = await repo.load('t1');
    expect(loaded, cliq);
    expect(loaded!.iban, isEmpty, reason: 'switching method wipes the old bank details');
  });

  test('nothing saved yet → null / no payout info', () async {
    expect(await repo.load('t1'), isNull);
    expect(await repo.hasPayoutInfo('t1'), isFalse);
    await repo.save('t1', bank);
    expect(await repo.hasPayoutInfo('t1'), isTrue);
  });

  test('reads the exact shape the migration writes (old payoutSettings map)', () async {
    await db.doc('users/t1/private/payout').set({
      'selectedMethod': 'cliq',
      'cliq': {'alias': 'OLD', 'holderName': 'Old Name'},
      'bankTransfer': null,
    });
    final loaded = await repo.load('t1');
    expect(loaded!.selectedMethod, 'cliq');
    expect(loaded.cliqAlias, 'OLD');
    expect(loaded.cliqHolderName, 'Old Name');
  });

  test('unknown or missing method falls back to CliQ', () async {
    await db.doc('users/t1/private/payout').set({'bankTransfer': null});
    expect((await repo.load('t1'))!.selectedMethod, PayoutSettings.cliq);
  });
}
