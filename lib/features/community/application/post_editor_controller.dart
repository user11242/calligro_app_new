import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

enum EditorResult { saved, invalid, needsAccount, notAllowed, busy, failed }

/// Create-post and edit-post screens: caption, images (max 5), admin options.
class PostEditorController extends ChangeNotifier {
  PostEditorController._({
    required CommunityRepository repository,
    required CommunityMediaStorage media,
    required this.session,
    this.original,
  })  : _repo = repository,
        _media = media,
        caption = original?.caption ?? '',
        _existing = List.of(original?.imageUrls ?? const []);

  factory PostEditorController.create({
    required CommunityRepository repository,
    required CommunityMediaStorage media,
    required CommunitySession session,
  }) =>
      PostEditorController._(repository: repository, media: media, session: session);

  factory PostEditorController.edit({
    required CommunityPost post,
    required CommunityRepository repository,
    required CommunityMediaStorage media,
    required CommunitySession session,
  }) =>
      PostEditorController._(repository: repository, media: media, session: session, original: post);

  final CommunityRepository _repo;
  final CommunityMediaStorage _media;
  final CommunitySession session;

  /// The post being edited (null when creating).
  final CommunityPost? original;
  bool get isEditing => original != null;

  // Plain fields bound to text fields / switches by the page.
  String caption;
  String linkUrl = '';
  String linkTitle = '';
  bool pin = false;
  bool hide = false;

  final List<String> _existing;
  final List<String> _new = [];
  List<String> get existingImageUrls => List.unmodifiable(_existing);
  List<String> get newImagePaths => List.unmodifiable(_new);
  int get imageCount => _existing.length + _new.length;
  int get freeImageSlots => CommunityPolicy.maxImagesPerPost - imageCount;
  bool get canAddImages => freeImageSlots > 0;
  bool get canUseAdminOptions => !isEditing && session.isAdmin;

  bool _saving = false;
  bool get isSaving => _saving;
  CommunityValidationError? _error;
  CommunityValidationError? get error => _error;

  /// Opens the picker for the free slots only. Returns how many were added.
  Future<int> addImages(CommunityImagePicker picker) async {
    if (!canAddImages) return 0;
    final picked = await picker.pickImages(maxCount: freeImageSlots);
    final added = picked.take(freeImageSlots).toList();
    _new.addAll(added);
    notifyListeners();
    return added.length;
  }

  void removeExistingImage(int index) {
    _existing.removeAt(index);
    notifyListeners();
  }

  void removeNewImage(int index) {
    _new.removeAt(index);
    notifyListeners();
  }

  Future<EditorResult> submit() async {
    if (!CommunityPolicy.canInteract(session)) return EditorResult.needsAccount;
    if (isEditing && !CommunityPolicy.canEdit(session, original!)) return EditorResult.notAllowed;
    if (_saving) return EditorResult.busy;

    final draft = CommunityPolicy.sanitizeForAuthor(
      NewPost(
        caption: caption,
        imagePaths: _new,
        linkUrl: linkUrl,
        linkTitle: linkTitle,
        isPinned: pin,
        isHidden: hide,
      ),
      session,
    );
    _error = isEditing
        ? CommunityPolicy.validateEdit(caption: draft.caption, imageCount: imageCount)
        : CommunityPolicy.validateNewPost(draft);
    if (_error != null) {
      notifyListeners();
      return EditorResult.invalid;
    }

    _saving = true;
    notifyListeners();
    try {
      final uploaded = _new.isEmpty ? const <String>[] : await _media.uploadPostImages(session.userId, _new);
      if (isEditing) {
        await _repo.updatePost(original!.id, caption: draft.caption, imageUrls: [..._existing, ...uploaded]);
      } else {
        await _repo.createPost(draft, author: session, imageUrls: uploaded);
      }
      return EditorResult.saved;
    } catch (e) {
      debugPrint('Post could not be saved: $e');
      return EditorResult.failed;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
