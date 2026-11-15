import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/profile_edit.dart';
import '../domain/profile_repositories.dart';

enum FieldStatus { idle, checking, ok, error }

enum PhoneProblem { invalid, taken }

enum EditResult { saved, noChanges, invalid, nameTaken, phoneTaken, phoneNotVerified, busy, failed }

/// Edit-profile screen: fields, live validation (rules + availability),
/// SMS verification of a new phone, photo upload and the atomic save.
class EditProfileController extends ChangeNotifier {
  EditProfileController({
    required this.uid,
    required ProfileEditorRepository editor,
    required ProfilePhotoUploader photos,
    required PhoneNumberChecker phones,
    this.debounce = const Duration(milliseconds: 600),
  })  : _editor = editor,
        _photos = photos,
        _phones = phones;

  final String uid;
  final Duration debounce;
  final ProfileEditorRepository _editor;
  final ProfilePhotoUploader _photos;
  final PhoneNumberChecker _phones;
  bool _disposed = false;

  EditableProfile? _original;
  EditableProfile? get original => _original;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool get notFound => !_isLoading && _original == null;
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  // Fields
  String name = '';
  String bio = '';
  String phone = '';
  String? _newPhotoPath;
  String? get newPhotoPath => _newPhotoPath;
  String get photoUrl => _original?.photoUrl ?? '';

  // Name state
  NameProblem? _nameProblem;
  NameProblem? get nameProblem => _nameProblem;
  bool _nameTaken = false;
  bool get nameTaken => _nameTaken;
  FieldStatus _nameStatus = FieldStatus.idle;
  FieldStatus get nameStatus => _nameStatus;
  Timer? _nameTimer;
  int _nameGen = 0;

  // Phone state
  PhoneProblem? _phoneProblem;
  PhoneProblem? get phoneProblem => _phoneProblem;
  FieldStatus _phoneStatus = FieldStatus.idle;
  FieldStatus get phoneStatus => _phoneStatus;
  Timer? _phoneTimer;
  int _phoneGen = 0;

  bool get isChecking => _nameStatus == FieldStatus.checking || _phoneStatus == FieldStatus.checking;

  Future<void> load() async {
    try {
      _original = await _editor.load(uid);
    } catch (e) {
      debugPrint('Profile could not be loaded for editing: $e');
      _original = null;
    }
    final o = _original;
    if (o != null) {
      name = o.name;
      bio = o.bio;
      phone = o.phone;
      _nameStatus = FieldStatus.ok;
      _phoneStatus = FieldStatus.ok;
    }
    _isLoading = false;
    _notify();
  }

  void onNameChanged(String value) {
    name = value;
    _nameTimer?.cancel();
    final gen = ++_nameGen;
    _nameTaken = false;
    _nameProblem = ProfileEditPolicy.validateName(value);
    if (_nameProblem != null) {
      _nameStatus = FieldStatus.error;
    } else if (!ProfileEditPolicy.nameReservationMoves(_original?.name ?? '', value)) {
      _nameStatus = FieldStatus.ok; // your own name
    } else {
      _nameStatus = FieldStatus.checking;
      _nameTimer = Timer(debounce, () async {
        final taken = await _safe(() => _editor.isNameTaken(value.trim(), uid: uid));
        if (gen != _nameGen || _disposed) return; // a newer edit happened
        _nameTaken = taken;
        _nameStatus = taken ? FieldStatus.error : FieldStatus.ok;
        _notify();
      });
    }
    _notify();
  }

  void onPhoneChanged(String completeNumber, String isoCode) {
    phone = completeNumber.trim();
    _phoneTimer?.cancel();
    final gen = ++_phoneGen;
    _phoneProblem = null;
    _phoneStatus = FieldStatus.checking;
    _notify();
    _phoneTimer = Timer(debounce, () async {
      final valid = await _phones.isValid(phone, isoCode);
      if (gen != _phoneGen || _disposed) return;
      if (!valid) {
        _phoneProblem = PhoneProblem.invalid;
        _phoneStatus = FieldStatus.error;
        _notify();
        return;
      }
      final mine = phone == (_original?.phone ?? '').trim();
      final taken = !mine && await _safe(() => _editor.isPhoneTaken(phone, uid: uid));
      if (gen != _phoneGen || _disposed) return;
      _phoneProblem = taken ? PhoneProblem.taken : null;
      _phoneStatus = taken ? FieldStatus.error : FieldStatus.ok;
      _notify();
    });
  }

  void pickPhoto(String localPath) {
    _newPhotoPath = localPath;
    _notify();
  }

  ProfileDraft get draft => ProfileDraft(name: name, bio: bio, phone: phone, newPhotoPath: _newPhotoPath);

  /// [verifyPhone] shows the SMS-code step for a new number; true when verified.
  Future<EditResult> save({required Future<bool> Function(String phone) verifyPhone}) async {
    final o = _original;
    if (o == null || _isSaving || isChecking) return EditResult.busy;
    if (ProfileEditPolicy.validateName(name) != null ||
        !ProfileEditPolicy.validateBio(bio) ||
        _nameTaken ||
        _phoneProblem != null) {
      return EditResult.invalid;
    }
    final d = draft;
    if (!ProfileEditPolicy.hasChanges(o, d)) return EditResult.noChanges;

    _isSaving = true;
    _notify();
    try {
      // Re-check at save time: someone may have taken the name / number meanwhile.
      if (ProfileEditPolicy.nameReservationMoves(o.name, d.name) &&
          await _editor.isNameTaken(d.name.trim(), uid: uid)) {
        _nameTaken = true;
        _nameStatus = FieldStatus.error;
        return EditResult.nameTaken;
      }
      if (ProfileEditPolicy.needsPhoneVerification(o, d.phone)) {
        if (await _editor.isPhoneTaken(d.phone.trim(), uid: uid)) {
          _phoneProblem = PhoneProblem.taken;
          _phoneStatus = FieldStatus.error;
          return EditResult.phoneTaken;
        }
        if (!await verifyPhone(d.phone.trim())) return EditResult.phoneNotVerified;
      }
      final url = d.newPhotoPath == null ? o.photoUrl : await _photos.upload(uid, d.newPhotoPath!);
      await _editor.save(o, d, photoUrl: url);
      _original = EditableProfile(
        uid: o.uid,
        role: o.role,
        name: d.name.trim(),
        bio: d.bio.trim(),
        phone: d.phone.trim(),
        photoUrl: url,
        email: o.email,
      );
      _newPhotoPath = null;
      return EditResult.saved;
    } catch (e) {
      debugPrint('Profile could not be saved: $e');
      return EditResult.failed;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<bool> _safe(Future<bool> Function() check) async {
    try {
      return await check();
    } catch (e) {
      debugPrint('Availability check failed: $e');
      return false; // the save-time check and firestore.rules still protect uniqueness
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _nameTimer?.cancel();
    _phoneTimer?.cancel();
    super.dispose();
  }
}
