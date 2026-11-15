/// What the edit-profile screen starts from.
class EditableProfile {
  final String uid;
  final String role;
  final String name;
  final String bio;

  /// Full international number ('' when none).
  final String phone;
  final String photoUrl;
  final String email;

  const EditableProfile({
    required this.uid,
    this.role = 'student',
    this.name = '',
    this.bio = '',
    this.phone = '',
    this.photoUrl = '',
    this.email = '',
  });
}

/// What the user typed / picked.
class ProfileDraft {
  final String name;
  final String bio;
  final String phone;

  /// A newly picked photo (local file), or null to keep the current one.
  final String? newPhotoPath;

  const ProfileDraft({required this.name, required this.bio, required this.phone, this.newPhotoPath});
}

enum NameProblem { empty, length, characters }

/// The edit-profile rules (pure, unit-tested). Uniqueness is enforced by the
/// locked_usernames / locked_phones reservations in firestore.rules.
class ProfileEditPolicy {
  ProfileEditPolicy._();

  static const nameMinLength = 3;
  static const nameMaxLength = 50;
  static const bioMaxLength = 300;

  /// Letters of any script (Arabic, Turkish, …), digits and spaces; at least one letter.
  static final _nameChars = RegExp(r'^(?=.*[\p{L}])[\p{L}\p{N}\s]+$', unicode: true);

  static NameProblem? validateName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return NameProblem.empty;
    if (name.length < nameMinLength || name.length > nameMaxLength) return NameProblem.length;
    if (!_nameChars.hasMatch(name)) return NameProblem.characters;
    return null;
  }

  static bool validateBio(String bio) => bio.trim().length <= bioMaxLength;

  static bool hasChanges(EditableProfile original, ProfileDraft draft) =>
      draft.name.trim() != original.name.trim() ||
      draft.bio.trim() != original.bio.trim() ||
      draft.phone.trim() != original.phone.trim() ||
      draft.newPhotoPath != null;

  /// The locked_usernames document id for a name.
  static String nameKey(String name) => name.trim().toLowerCase();

  static bool nameReservationMoves(String oldName, String newName) => nameKey(oldName) != nameKey(newName);

  static bool needsPhoneVerification(EditableProfile original, String newPhone) =>
      newPhone.trim().isNotEmpty && newPhone.trim() != original.phone.trim();
}
