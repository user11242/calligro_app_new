import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/models/community_post.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

enum LikeResult { done, failed, ignored, needsAccount }

/// State + actions of ONE post card: like (optimistic), delete, pin, hide,
/// report, block. Menu visibility comes from [CommunityPolicy].
class PostController extends ChangeNotifier {
  PostController({
    required CommunityPost post,
    required this.session,
    required CommunityRepository repository,
    required CommunityMediaStorage media,
  })  : _post = post,
        _repo = repository,
        _media = media,
        _isLiked = post.isLikedBy(session.userId),
        _likesCount = post.likesCount,
        _likerIds = post.likerIds;

  final CommunitySession session;
  final CommunityRepository _repo;
  final CommunityMediaStorage _media;

  CommunityPost _post;
  CommunityPost get post => _post;

  bool _isLiked;
  bool get isLiked => _isLiked;
  int _likesCount;
  int get likesCount => _likesCount;
  Set<String> _likerIds;
  Set<String> get likerIds => _likerIds;
  bool _likeInFlight = false;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;
  String? _lastError;
  String? get lastError => _lastError;

  bool get canInteract => CommunityPolicy.canInteract(session);
  bool get canEdit => CommunityPolicy.canEdit(session, _post);
  bool get canDelete => CommunityPolicy.canDelete(session, _post);
  bool get canPinOrHide => CommunityPolicy.canPinOrHide(session);
  bool get canReportOrBlock => CommunityPolicy.canReportOrBlock(session, _post);

  /// A newer copy arrived from the server (stream). Never overrides a like in flight.
  void syncPost(CommunityPost post) {
    _post = post;
    if (!_likeInFlight) {
      _isLiked = post.isLikedBy(session.userId);
      _likesCount = post.likesCount;
      _likerIds = post.likerIds;
    }
    notifyListeners();
  }

  Future<LikeResult> toggleLike() async {
    if (!canInteract) return LikeResult.needsAccount;
    if (_likeInFlight) return LikeResult.ignored;
    final before = (_isLiked, _likesCount, _likerIds);
    final like = !_isLiked;
    _likeInFlight = true;
    _isLiked = like;
    _likesCount = like ? _likesCount + 1 : (_likesCount > 0 ? _likesCount - 1 : 0);
    _likerIds = like ? {..._likerIds, session.userId} : ({..._likerIds}..remove(session.userId));
    notifyListeners();
    try {
      await _repo.setLiked(_post.id, userId: session.userId, like: like);
      return LikeResult.done;
    } catch (e) {
      _isLiked = before.$1;
      _likesCount = before.$2;
      _likerIds = before.$3;
      _lastError = '$e';
      return LikeResult.failed;
    } finally {
      _likeInFlight = false;
      notifyListeners();
    }
  }

  /// Deletes the post (comments, replies, counters) and then its images.
  Future<bool> delete() async {
    if (!canDelete || _isDeleting) return false;
    _isDeleting = true;
    notifyListeners();
    try {
      final images = await _repo.deletePost(_post);
      for (final url in images) {
        await _media.deleteByUrl(url);
      }
      return true;
    } catch (e) {
      _lastError = '$e';
      return false;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  Future<bool> togglePinned() => _adminFlag(
      () => _repo.setPinned(_post.id, !_post.isPinned), () => _post = _post.copyWith(isPinned: !_post.isPinned));

  Future<bool> toggleHidden() => _adminFlag(
      () => _repo.setHidden(_post.id, !_post.isHidden), () => _post = _post.copyWith(isHidden: !_post.isHidden));

  Future<bool> _adminFlag(Future<void> Function() write, void Function() apply) async {
    if (!canPinOrHide) return false;
    return _run(() async {
      await write();
      apply();
    });
  }

  Future<bool> report() async {
    if (!canReportOrBlock) return false;
    return _run(() => _repo.reportPost(_post, reporterId: session.userId));
  }

  Future<bool> blockAuthor() async {
    if (!canReportOrBlock) return false;
    return _run(() => _repo.blockUser(session.userId, blockedUserId: _post.authorId));
  }

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      return false;
    }
  }
}

/// "Translate" under a caption: detect the language once, offer the others.
class CaptionTranslationController extends ChangeNotifier {
  CaptionTranslationController({required this.text, required CommunityTranslator translator}) : _translator = translator;

  static const languages = ['en', 'ar', 'tr'];

  final String text;
  final CommunityTranslator _translator;
  String? _sourceLanguage;
  String? _translated;
  bool _showing = false;
  bool _busy = false;

  bool get isTranslating => _busy;
  bool get isShowingTranslation => _showing && _translated != null;
  String get displayText => isShowingTranslation ? _translated! : text;

  Future<List<String>> targetLanguages() async {
    _sourceLanguage ??= await _translator.identifyLanguage(text);
    return languages.where((l) => l != _sourceLanguage).toList();
  }

  Future<void> translateTo(String language) async {
    _busy = true;
    notifyListeners();
    try {
      _translated = await _translator.translate(text, targetLanguage: language);
      _showing = true;
    } catch (e) {
      debugPrint('Translation failed: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void showOriginal() {
    _showing = false;
    notifyListeners();
  }
}
