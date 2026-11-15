import 'package:calligro_app/features/profile/domain/profile_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name rules (same as registration)', () {
    test('required, 3–50 characters', () {
      expect(ProfileEditPolicy.validateName(''), NameProblem.empty);
      expect(ProfileEditPolicy.validateName('   '), NameProblem.empty);
      expect(ProfileEditPolicy.validateName('Al'), NameProblem.length);
      expect(ProfileEditPolicy.validateName('A' * 51), NameProblem.length);
      expect(ProfileEditPolicy.validateName('Ali'), isNull);
    });

    test('letters (any script), digits and spaces; at least one letter', () {
      expect(ProfileEditPolicy.validateName('علي حسن'), isNull);
      expect(ProfileEditPolicy.validateName('Çağlar Öz'), isNull);
      expect(ProfileEditPolicy.validateName('Ali 2'), isNull);
      expect(ProfileEditPolicy.validateName('12345'), NameProblem.characters);
      expect(ProfileEditPolicy.validateName('Ali!'), NameProblem.characters);
      expect(ProfileEditPolicy.validateName('<script>'), NameProblem.characters);
    });

    test('surrounding spaces do not count', () {
      expect(ProfileEditPolicy.validateName('  Ali  '), isNull);
      expect(ProfileEditPolicy.validateName(' Al '), NameProblem.length);
    });
  });

  test('bio at most 300 characters', () {
    expect(ProfileEditPolicy.bioMaxLength, 300);
    expect(ProfileEditPolicy.validateBio('x' * 300), isTrue);
    expect(ProfileEditPolicy.validateBio('x' * 301), isFalse);
  });

  group('changes', () {
    const original = EditableProfile(uid: 'u1', name: 'Ali', bio: 'Hi', phone: '+962791234567', photoUrl: 'p.jpg');

    test('nothing changed (ignoring surrounding spaces)', () {
      expect(ProfileEditPolicy.hasChanges(original, const ProfileDraft(name: ' Ali ', bio: 'Hi ', phone: '+962791234567')), isFalse);
    });

    test('any field or a new photo counts', () {
      expect(ProfileEditPolicy.hasChanges(original, const ProfileDraft(name: 'Ali H', bio: 'Hi', phone: '+962791234567')), isTrue);
      expect(ProfileEditPolicy.hasChanges(original, const ProfileDraft(name: 'Ali', bio: 'Hello', phone: '+962791234567')), isTrue);
      expect(ProfileEditPolicy.hasChanges(original, const ProfileDraft(name: 'Ali', bio: 'Hi', phone: '+962790000000')), isTrue);
      expect(
          ProfileEditPolicy.hasChanges(
              original, const ProfileDraft(name: 'Ali', bio: 'Hi', phone: '+962791234567', newPhotoPath: '/tmp/me.jpg')),
          isTrue);
    });

    test('a name reservation only moves when the lower-case name changes', () {
      expect(ProfileEditPolicy.nameKey('  Ali Hassan '), 'ali hassan');
      expect(ProfileEditPolicy.nameReservationMoves('Ali', 'ALI'), isFalse, reason: 'case-only change keeps the same reservation');
      expect(ProfileEditPolicy.nameReservationMoves('Ali', 'Omar'), isTrue);
    });

    test('the phone must be re-verified only when it changed to a non-empty number', () {
      expect(ProfileEditPolicy.needsPhoneVerification(original, '+962791234567'), isFalse);
      expect(ProfileEditPolicy.needsPhoneVerification(original, '+962790000000'), isTrue);
      expect(ProfileEditPolicy.needsPhoneVerification(original, ''), isFalse);
    });
  });
}
