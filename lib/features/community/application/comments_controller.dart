import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/community_models.dart';
import '../domain/policies/community_policy.dart';
import '../domain/repositories/community_repositories.dart';

enum SendResult { sent, invalid, needsAccount, busy, failed }

/// Comments sheet: live comments, write a comment or a reply, edit / delete.
class CommentsController extends ChangeNotifier {
  CommentsController({
    required CommunityRepository repository,
    required this.session,
    required this.postId,
    required this.postAuthorId,
  }) : _repo = repository;

  final CommunityRepository _repo;
  final CommunitySession session;
  final String postId;
  final String postAuthorId;
  StreamSubscription<List<CommunityComment>>? _sub;
  bool _disposed = false;

  List<CommunityComment> _comments = const [];
  List<CommunityComment> get comments => _comments;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool _isSending = false;
  bool get isSending => _isSending;

  CommunityComment? _replyRoot;
  String? _replyName;

  /// "Replying to @name" — null when writing a top-level comment.
  String? get replyingToName => _replyName;

  bool get canWrite => CommunityPolicy.canInteract(session);

  void start() {
    _sub ??= _repo.watchComments(postId).listen((c) {
      _comments = c;
      _isLoading = false;
      _notify();
    }, onError: (Object _) {
      _isLoading = false;
      _notify();
    });
  }

  /// Replies always attach to the top-level comment [root]; [toName] is who is answered.
  bool replyTo(CommunityComment root, {required String toName}) {
    if (!canWrite) return false;
    _replyRoot = root;
    _replyName = toName;
    _notify();
    return true;
  }

  void cancelReply() {
    _replyRoot = null;
    _replyName = null;
    _notify();
  }

  Future<SendResult> send(String text) async {
    if (!canWrite) return SendResult.needsAccount;
    if (CommunityPolicy.validateText(text) != null) return SendResult.invalid;
    if (_isSending) return SendResult.busy;
    _isSending = true;
    _notify();
    try {
      final root = _replyRoot;
      if (root != null) {
        await _repo.addReply(postId, root.id, author: session, text: text.trim());
        _replyRoot = null;
        _replyName = null;
      } else {
        await _repo.addComment(postId, author: session, text: text.trim());
      }
      return SendResult.sent;
    } catch (e) {
      debugPrint('Comment could not be sent: $e');
      return SendResult.failed;
    } finally {
      _isSending = false;
      _notify();
    }
  }

  Stream<List<CommunityComment>> watchReplies(String commentId) => _repo.watchReplies(postId, commentId);

  bool canEdit(CommunityComment c) => CommunityPolicy.canEditComment(session, c);
  bool canDelete(CommunityComment c) => CommunityPolicy.canDeleteComment(session, c, postAuthorId: postAuthorId);
  bool canEditReply(CommunityComment r) => CommunityPolicy.canEditComment(session, r);
  bool canDeleteReply(CommunityComment r, {required CommunityComment parent}) =>
      CommunityPolicy.canDeleteReply(session, r, commentAuthorId: parent.authorId);

  Future<bool> editComment(CommunityComment c, String text) =>
      _guarded(canEdit(c) && CommunityPolicy.validateText(text) == null, () => _repo.editComment(postId, c.id, text.trim()));

  Future<bool> deleteComment(CommunityComment c) => _guarded(canDelete(c), () => _repo.deleteComment(postId, c.id));

  Future<bool> editReply(CommunityComment reply, {required CommunityComment parent, required String text}) => _guarded(
      canEditReply(reply) && CommunityPolicy.validateText(text) == null,
      () => _repo.editReply(postId, parent.id, reply.id, text.trim()));

  Future<bool> deleteReply(CommunityComment reply, {required CommunityComment parent}) =>
      _guarded(canDeleteReply(reply, parent: parent), () => _repo.deleteReply(postId, parent.id, reply.id));

  Future<bool> _guarded(bool allowed, Future<void> Function() action) async {
    if (!allowed) return false;
    try {
      await action();
      return true;
    } catch (e) {
      debugPrint('Comment action failed: $e');
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
