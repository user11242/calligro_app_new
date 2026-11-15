import 'dart:io';
import 'dart:ui';

import 'package:device_region/device_region.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phone_number/phone_number.dart' as lib_phone;

import 'package:calligro_app/core/utils/image_utils.dart';

import '../domain/profile_repositories.dart';

/// Profile photos in Storage under user_profile_images/{uid}/ (owner-only in storage.rules).
class FirebaseProfilePhotoUploader implements ProfilePhotoUploader {
  FirebaseProfilePhotoUploader({FirebaseStorage? storage}) : _injected = storage;
  final FirebaseStorage? _injected;

  @override
  Future<String> upload(String uid, String localPath) async {
    // Fix EXIF rotation so Android shows the photo the same way as iOS.
    final file = await fixExifRotation(File(localPath));
    final ref = (_injected ?? FirebaseStorage.instance)
        .ref()
        .child('user_profile_images/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final snapshot = await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return snapshot.ref.getDownloadURL();
  }
}

/// libphonenumber via the phone_number plugin.
class LibPhoneNumberChecker implements PhoneNumberChecker {
  final _util = lib_phone.PhoneNumberUtil();

  @override
  Future<bool> isValid(String phone, String isoCode) async {
    try {
      return await _util.validate(phone, regionCode: isoCode);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<(String, String)?> split(String phone) async {
    if (phone.trim().isEmpty) return null;
    try {
      final parsed = await _util.parse(phone);
      if (parsed.regionCode.isEmpty) return null;
      return (parsed.regionCode.toUpperCase(), parsed.nationalNumber);
    } catch (e) {
      // Older Jordanian numbers that libphonenumber could not parse.
      if (phone.startsWith('+962')) return ('JO', phone.substring(4));
      return null;
    }
  }

  @override
  Future<String> deviceCountry() async {
    try {
      var code = await DeviceRegion.getSIMCountryCode(); // SIM first, then system region
      if (code == null || code.isEmpty) code = PlatformDispatcher.instance.locale.countryCode;
      if (code != null && code.isNotEmpty) return code.toUpperCase();
    } catch (e) {
      debugPrint('Country could not be detected: $e');
    }
    return 'US';
  }
}

/// Gallery picker (800px, quality 75, like before).
Future<String?> pickProfilePhotoFromGallery() async {
  final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 75);
  return image?.path;
}
