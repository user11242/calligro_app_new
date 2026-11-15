import 'package:cloud_functions/cloud_functions.dart';

import '../domain/auth_repositories.dart';
import '../domain/email_code.dart';

class CloudEmailCodes implements EmailCodeGateway {
  CloudEmailCodes({FirebaseFunctions? functions}) : _injected = functions;
  final FirebaseFunctions? _injected;
  FirebaseFunctions get _f => _injected ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<void> send(String email) async {
    try {
      await _f.httpsCallable('sendEmailCode').call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') throw const EmailCodeCooldown();
      rethrow;
    }
  }

  @override
  Future<EmailCodeCheck> check(String email, String code, EmailCodePurpose purpose) async {
    final r = await _f.httpsCallable('verifyEmailCode').call({'email': email, 'code': code, 'purpose': purpose.name});
    final data = r.data is Map ? r.data as Map : const {};
    return EmailCodeCheck.fromServer(data['result']);
  }

  @override
  Future<void> resetPassword(String email, String code, String newPassword) async {
    try {
      final r = await _f
          .httpsCallable('resetPasswordWithOtp')
          .call({'email': email, 'otp': code, 'newPassword': newPassword});
      final data = r.data is Map ? r.data as Map : const {};
      if (data['success'] != true) throw Exception('Password reset failed.');
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Password reset failed.');
    }
  }
}
