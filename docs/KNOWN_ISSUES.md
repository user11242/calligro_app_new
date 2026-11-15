# Known issues (recorded, not fixed yet)

Found during the auth review (2026-11-15). Left as they are on purpose, by decision; fix only when asked.

## 1. Teachers' phone numbers are not verified at email registration
- **Where:** `verification_wizard_page.dart` → `UniversalOtpStep` → `OtpAuthService.verifySmsCode`.
- **What:** at that point no one is signed in, so `verifySmsCode` only builds a `PhoneAuthCredential` on the phone and returns it. Firebase never checks the code, so any 6 digits are accepted.
- **Not affected:** the Google sign-up wizard, where a user exists and `linkWithCredential` really checks the code.
- **Proposed fix:** `signInWithCredential(phone)` at the phone step, then link `EmailAuthProvider.credential(email, password)` at the end instead of `createUserWithEmailAndPassword`.

## 2. Deleting an account from the teacher Security page always fails
- **Where:** `security_page.dart` → `AuthService.deleteAccount()`.
- **What:** this client-side soft delete writes `status: 'deleted'` to `users/{uid}`, but `firestore.rules` don't let owners change `status`, so the whole batch is refused.
- **Not affected:** rejected teachers, who use the server callable `deleteOwnAccount` (a hard delete), which works.
- **Proposed fix:** do the same soft delete in a server callable.
