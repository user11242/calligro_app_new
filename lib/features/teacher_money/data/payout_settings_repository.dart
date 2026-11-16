import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a teacher gets paid. Only the active method's details are kept.
class PayoutSettings {
  static const cliq = 'cliq';
  static const bankTransfer = 'bankTransfer';

  final String selectedMethod;
  final String cliqAlias;
  final String cliqHolderName;
  final String bankName;
  final String accountName;
  final String swift;
  final String iban;
  final String country;
  final String city;
  final String street;
  final String postalCode;

  const PayoutSettings({
    required this.selectedMethod,
    this.cliqAlias = '',
    this.cliqHolderName = '',
    this.bankName = '',
    this.accountName = '',
    this.swift = '',
    this.iban = '',
    this.country = '',
    this.city = '',
    this.street = '',
    this.postalCode = '',
  });

  bool get isBankTransfer => selectedMethod == bankTransfer;

  /// Same shape the old `payoutSettings` map had (so migrated data reads back unchanged).
  Map<String, dynamic> toMap() => {
        'selectedMethod': selectedMethod,
        'cliq': isBankTransfer ? null : {'alias': cliqAlias.trim(), 'holderName': cliqHolderName.trim()},
        'bankTransfer': isBankTransfer
            ? {
                'bankName': bankName.trim(),
                'accountName': accountName.trim(),
                'swift': swift.trim(),
                'iban': iban.trim(),
                'country': country.trim(),
                'city': city.trim(),
                'street': street.trim(),
                'postalCode': postalCode.trim(),
              }
            : null,
      };

  factory PayoutSettings.fromMap(Map<String, dynamic> m) {
    String s(Map? map, String key) => (map?[key] ?? '').toString();
    final cliqMap = m['cliq'] as Map?;
    final bank = m['bankTransfer'] as Map?;
    final method = m['selectedMethod'] == bankTransfer ? bankTransfer : cliq;
    return PayoutSettings(
      selectedMethod: method,
      cliqAlias: s(cliqMap, 'alias'),
      cliqHolderName: s(cliqMap, 'holderName'),
      bankName: s(bank, 'bankName'),
      accountName: s(bank, 'accountName'),
      swift: s(bank, 'swift'),
      iban: s(bank, 'iban'),
      country: s(bank, 'country'),
      city: s(bank, 'city'),
      street: s(bank, 'street'),
      postalCode: s(bank, 'postalCode'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PayoutSettings && other.toMap().toString() == toMap().toString();

  @override
  int get hashCode => toMap().toString().hashCode;
}

/// Payout details live in users/{uid}/private/payout — readable only by the
/// teacher and admins (firestore.rules). NEVER on the public users/teachers docs.
class PayoutSettingsRepository {
  PayoutSettingsRepository({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('payout');

  Future<PayoutSettings?> load(String uid) async {
    final data = (await _doc(uid).get()).data();
    return data == null ? null : PayoutSettings.fromMap(data);
  }

  Future<bool> hasPayoutInfo(String uid) async => (await _doc(uid).get()).exists;

  Future<void> save(String uid, PayoutSettings settings) =>
      _doc(uid).set({...settings.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
}
