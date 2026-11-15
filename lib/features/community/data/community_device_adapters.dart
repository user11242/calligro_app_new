import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:calligro_app/core/services/translation_service.dart';

import '../domain/repositories/community_repositories.dart';

/// Post images in Firebase Storage under community_posts/{uid}/ (matches storage.rules).
class FirebaseCommunityMediaStorage implements CommunityMediaStorage {
  FirebaseCommunityMediaStorage({FirebaseStorage? storage}) : _injected = storage;
  final FirebaseStorage? _injected;

  // Resolved on first use so building the screens never needs Storage.
  FirebaseStorage get _storage => _injected ?? FirebaseStorage.instance;

  @override
  Future<List<String>> uploadPostImages(String userId, List<String> localPaths) => Future.wait(localPaths.map((p) async {
        final name = p.split('/').last;
        final ref = _storage.ref().child('community_posts/$userId/${DateTime.now().millisecondsSinceEpoch}_$name');
        // storage.rules only accept images here (the picker always produces JPEGs).
        final snapshot = await ref.putFile(File(p), SettableMetadata(contentType: 'image/jpeg'));
        return snapshot.ref.getDownloadURL();
      }));

  @override
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Image $url could not be deleted: $e');
    }
  }
}

/// Gallery picker + compression (1080px, q75, EXIF rotation applied then stripped).
class AssetCommunityImagePicker implements CommunityImagePicker {
  AssetCommunityImagePicker(this._context);
  final BuildContext _context;

  @override
  Future<List<String>> pickImages({required int maxCount}) async {
    if (maxCount <= 0) return const [];
    final picked = await AssetPicker.pickAssets(
      _context,
      pickerConfig: AssetPickerConfig(maxAssets: maxCount, requestType: RequestType.image),
    );
    if (picked == null || picked.isEmpty) return const [];
    final tempDir = await getTemporaryDirectory();
    final paths = <String>[];
    for (final (i, entity) in picked.take(maxCount).indexed) {
      final file = await entity.file;
      if (file == null) continue;
      final out = await FlutterImageCompress.compressAndGetFile(
        file.path,
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        autoCorrectionAngle: true, // fix EXIF rotation (Android)
        keepExif: false, // and strip it so it can't be mis-read
      );
      if (out != null) paths.add(out.path);
    }
    return paths;
  }
}

class ServiceCommunityTranslator implements CommunityTranslator {
  final TranslationService _service = TranslationService();

  @override
  Future<String> identifyLanguage(String text) => _service.identifyLanguage(text);

  @override
  Future<String> translate(String text, {required String targetLanguage}) =>
      _service.translate(text: text, target: targetLanguage);
}
