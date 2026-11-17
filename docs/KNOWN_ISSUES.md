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

# Temporary bridges for the store app (remove after the forced update)

Added 2026-11-17. The rules were tightened before the new app reached the stores, so the
store app (1.0.24, build 107) was rejected. These bridges keep it working until everyone updates.

## A. Old-app course creation (`createdAt` from the phone's clock)
- **Where:** `firestore.rules` → `validNewCourse` → `oldAppCreatedAtOk()`.
- **What:** the old app stamps a new course with `DateTime.now()`; the rules accept only the
  server's time. The bridge accepts a `createdAt` within 10 minutes of the server's time.
- **Tests:** `functions/test/course_rules.test.js` → "store app 1.0.24 can still create courses (temporary bridge)".
- **Still blocked on the old app:** teachers without saved payout details. The old app only opens
  "Add Course" when `users/{id}.payoutSettings` exists, and saving it there stays blocked (privacy).
- **To remove:**
  1. Release the new app.
  2. Raise `min_required_build` in `app_config/version_control` to the new build (forces the update).
  3. Delete `oldAppCreatedAtOk` and its use (back to `d.createdAt == request.time`).
  4. Delete the bridge tests.
  5. Deploy the rules.
- **Do not run the payout migration before step 2:** it removes `payoutSettings` from public
  profiles, which would stop every old-app teacher at "Add Course".
