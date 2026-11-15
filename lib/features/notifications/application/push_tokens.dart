import '../domain/notification_repositories.dart';

/// This device's push token on the signed-in account.
///
/// A phone used by several accounts kept its token on EVERY one of them, so it
/// received one copy per account (2-3 at once). Now: signing out removes the
/// token from the account and resets it; the server also removes a token from
/// any other account when a new one claims it (functions/notification_tokens.js).
class PushTokens {
  PushTokens({required PushGateway gateway, required PushTokenStore store})
      : _gateway = gateway,
        _store = store;

  final PushGateway _gateway;
  final PushTokenStore _store;

  Future<void> register(String uid, {required String language}) async {
    if (uid.isEmpty) return;
    try {
      final token = await _gateway.token();
      if (token != null && token.isNotEmpty) await _store.save(uid, token, language: language);
    } catch (_) {
      // No permission / simulator without APNs: nothing to save.
    }
  }

  /// Call BEFORE signing out (the user's document is still writable).
  Future<void> unregister(String uid) async {
    if (uid.isEmpty) return;
    try {
      final token = await _gateway.token();
      if (token != null && token.isNotEmpty) await _store.clear(uid, token);
    } catch (_) {}
    try {
      await _gateway.deleteToken(); // the next account gets a fresh token
    } catch (_) {}
  }
}
