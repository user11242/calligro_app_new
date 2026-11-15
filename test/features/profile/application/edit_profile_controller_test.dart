import 'package:calligro_app/features/profile/application/edit_profile_controller.dart';
import 'package:calligro_app/features/profile/domain/profile_edit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_profile.dart';

void main() {
  late FakeProfileEditor editor;
  late FakePhotoUploader photos;
  late FakePhoneChecker phones;
  final verifications = <String>[];
  var verifyAnswer = true;

  Future<bool> verify(String phone) async {
    verifications.add(phone);
    return verifyAnswer;
  }

  Future<EditProfileController> loaded() async {
    final c = EditProfileController(uid: 't1', editor: editor, photos: photos, phones: phones, debounce: Duration.zero);
    await c.load();
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

  setUp(() {
    editor = FakeProfileEditor()..profiles['t1'] = editableAli;
    photos = FakePhotoUploader();
    phones = FakePhoneChecker();
    verifications.clear();
    verifyAnswer = true;
  });

  test('loads the current profile into the fields', () async {
    final c = await loaded();
    expect(c.isLoading, isFalse);
    expect(c.name, 'Ali Hassan');
    expect(c.bio, 'Teacher');
    expect(c.phone, '+962791234567');
    expect(c.photoUrl, 'old.jpg');
    expect(c.nameStatus, FieldStatus.ok, reason: 'your current name is yours');
  });

  test('unknown user → not found', () async {
    final c = EditProfileController(uid: 'ghost', editor: editor, photos: photos, phones: phones);
    await c.load();
    expect(c.notFound, isTrue);
  });

  group('name', () {
    test('rule problems show immediately, without a lookup', () async {
      final c = await loaded();
      c.onNameChanged('Al');
      expect(c.nameProblem, NameProblem.length);
      expect(c.nameStatus, FieldStatus.error);
      expect(editor.nameChecks, isEmpty);
    });

    test('a free name is checked (debounced) and accepted', () async {
      final c = await loaded();
      c.onNameChanged('Omar Farouk');
      expect(c.nameStatus, FieldStatus.checking);
      await settle();
      expect(c.nameStatus, FieldStatus.ok);
      expect(editor.nameChecks, ['Omar Farouk']);
    });

    test('a name reserved by someone else is rejected', () async {
      editor.takenNames.add('omar');
      final c = await loaded();
      c.onNameChanged('Omar');
      await settle();
      expect(c.nameTaken, isTrue);
      expect(c.nameStatus, FieldStatus.error);
    });

    test('going back to your own name needs no lookup', () async {
      final c = await loaded();
      c.onNameChanged('ali hassan');
      await settle();
      expect(c.nameStatus, FieldStatus.ok);
      expect(editor.nameChecks, isEmpty);
    });

    test('a late answer for an older name never overrides the newest one', () async {
      editor.takenNames.add('omar');
      editor.nameDelays['Omar'] = const Duration(milliseconds: 40); // slow, and "taken"
      final c = await loaded();
      c.onNameChanged('Omar');
      await Future<void>.delayed(const Duration(milliseconds: 5)); // its check is now in flight
      c.onNameChanged('Omar Farouk'); // fast, free
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(editor.nameChecks, ['Omar', 'Omar Farouk']);
      expect(c.nameTaken, isFalse);
      expect(c.nameStatus, FieldStatus.ok);
    });
  });

  group('phone', () {
    test('an invalid number is an error', () async {
      phones.invalid.add('+96279');
      final c = await loaded();
      c.onPhoneChanged('+96279', 'JO');
      await settle();
      expect(c.phoneProblem, PhoneProblem.invalid);
    });

    test('a number reserved by someone else is an error', () async {
      phones.invalid.clear();
      editor.takenPhones.add('+962790000000');
      final c = await loaded();
      c.onPhoneChanged('+962790000000', 'JO');
      await settle();
      expect(c.phoneProblem, PhoneProblem.taken);
    });

    test('a free valid number is ok', () async {
      final c = await loaded();
      c.onPhoneChanged('+962795555555', 'JO');
      await settle();
      expect(c.phoneProblem, isNull);
      expect(c.phoneStatus, FieldStatus.ok);
    });
  });

  group('save', () {
    test('nothing changed → "no changes", nothing written', () async {
      final c = await loaded();
      expect(await c.save(verifyPhone: verify), EditResult.noChanges);
      expect(editor.saves, isEmpty);
    });

    test('name + bio change saves without SMS verification', () async {
      final c = await loaded();
      c.onNameChanged('Omar');
      c.bio = 'New bio';
      await settle();
      expect(await c.save(verifyPhone: verify), EditResult.saved);
      final (_, draft, photo) = editor.saves.single;
      expect(draft.name, 'Omar');
      expect(draft.bio, 'New bio');
      expect(photo, 'old.jpg');
      expect(verifications, isEmpty);
    });

    test('a new phone must be verified by SMS first', () async {
      final c = await loaded();
      c.onPhoneChanged('+962795555555', 'JO');
      await settle();
      expect(await c.save(verifyPhone: verify), EditResult.saved);
      expect(verifications, ['+962795555555']);
    });

    test('cancelled verification → nothing saved', () async {
      verifyAnswer = false;
      final c = await loaded();
      c.onPhoneChanged('+962795555555', 'JO');
      await settle();
      expect(await c.save(verifyPhone: verify), EditResult.phoneNotVerified);
      expect(editor.saves, isEmpty);
    });

    test('a new photo is uploaded and its URL saved', () async {
      final c = await loaded();
      c.pickPhoto('/tmp/me.jpg');
      expect(await c.save(verifyPhone: verify), EditResult.saved);
      expect(photos.uploads, ['/tmp/me.jpg']);
      expect(editor.saves.single.$3, 'https://cdn/t1/me.jpg');
    });

    test('a failed upload saves nothing (no half-saved profile)', () async {
      photos.fail = true;
      final c = await loaded();
      c.pickPhoto('/tmp/me.jpg');
      c.bio = 'changed';
      expect(await c.save(verifyPhone: verify), EditResult.failed);
      expect(editor.saves, isEmpty);
    });

    test('invalid fields block saving', () async {
      final c = await loaded();
      c.onNameChanged('!!');
      expect(await c.save(verifyPhone: verify), EditResult.invalid);
      c.onNameChanged('Ali Hassan');
      c.bio = 'x' * 301;
      expect(await c.save(verifyPhone: verify), EditResult.invalid);
    });

    test('a name taken in the meantime is caught at save time', () async {
      final c = await loaded();
      c.onNameChanged('Omar');
      await settle();
      editor.takenNames.add('omar');
      expect(await c.save(verifyPhone: verify), EditResult.nameTaken);
      expect(editor.saves, isEmpty);
    });

    test('saving while a check is running is refused (busy)', () async {
      final c = EditProfileController(
          uid: 't1', editor: editor, photos: photos, phones: phones, debounce: const Duration(milliseconds: 50));
      await c.load();
      c.onNameChanged('Omar');
      expect(await c.save(verifyPhone: verify), EditResult.busy);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    test('a refused write → failed; after a success the new values become the baseline', () async {
      final c = await loaded();
      c.bio = 'one';
      editor.failSave = true;
      expect(await c.save(verifyPhone: verify), EditResult.failed);
      editor.failSave = false;
      expect(await c.save(verifyPhone: verify), EditResult.saved);
      expect(await c.save(verifyPhone: verify), EditResult.noChanges);
    });
  });
}
