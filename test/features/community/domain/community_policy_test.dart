import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/domain/policies/community_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  final mine = postBy('s1');
  final theirs = postBy('t1', role: 'teacher');

  group('creating and editing', () {
    test('a post needs a caption, an image or a link; at most 5 images', () {
      expect(CommunityPolicy.maxImagesPerPost, 5);
      expect(CommunityPolicy.validateNewPost(const NewPost(caption: '   ')), CommunityValidationError.emptyPost);
      expect(CommunityPolicy.validateNewPost(const NewPost(caption: 'hi')), isNull);
      expect(CommunityPolicy.validateNewPost(const NewPost(imagePaths: ['a'])), isNull);
      expect(CommunityPolicy.validateNewPost(const NewPost(linkUrl: 'https://x')), isNull);
      expect(CommunityPolicy.validateNewPost(const NewPost(linkUrl: '  ')), CommunityValidationError.emptyPost);
      expect(CommunityPolicy.validateNewPost(const NewPost(imagePaths: ['1', '2', '3', '4', '5', '6'])),
          CommunityValidationError.tooManyImages);
    });

    test('an edit may not leave the post empty or exceed 5 images', () {
      expect(CommunityPolicy.validateEdit(caption: '', imageCount: 0), CommunityValidationError.emptyPost);
      expect(CommunityPolicy.validateEdit(caption: '', imageCount: 1), isNull);
      expect(CommunityPolicy.validateEdit(caption: 'x', imageCount: 6), CommunityValidationError.tooManyImages);
    });

    test('links get https:// when missing; blank links are dropped', () {
      expect(CommunityPolicy.normalizeLink(' calligro.app '), 'https://calligro.app');
      expect(CommunityPolicy.normalizeLink('http://x.io'), 'http://x.io');
      expect(CommunityPolicy.normalizeLink('https://x.io'), 'https://x.io');
      expect(CommunityPolicy.normalizeLink('  '), isNull);
      expect(CommunityPolicy.sanitizeForAuthor(const NewPost(linkUrl: 'x.io'), adminSession).linkUrl, 'https://x.io');
    });

    test('comment text must not be blank', () {
      expect(CommunityPolicy.validateText(' \n '), CommunityValidationError.emptyText);
      expect(CommunityPolicy.validateText('ok'), isNull);
    });

    test('only admins keep links, pins and hidden flags; captions are trimmed', () {
      const raw = NewPost(caption: '  hi  ', linkUrl: ' https://x ', linkTitle: ' X ', isPinned: true, isHidden: true);
      final forStudent = CommunityPolicy.sanitizeForAuthor(raw, studentSession);
      expect([forStudent.caption, forStudent.linkUrl, forStudent.isPinned, forStudent.isHidden], ['hi', null, false, false]);
      final forAdmin = CommunityPolicy.sanitizeForAuthor(raw, adminSession);
      expect([forAdmin.linkUrl, forAdmin.linkTitle, forAdmin.isPinned, forAdmin.isHidden], ['https://x', 'X', true, true]);
      final blankLink = CommunityPolicy.sanitizeForAuthor(const NewPost(linkUrl: ' ', linkTitle: 'T'), adminSession);
      expect([blankLink.linkUrl, blankLink.linkTitle], [null, null], reason: 'no title without a link');
    });
  });

  group('post actions (who sees which menu item)', () {
    test('edit: author only (not even admins)', () {
      expect(CommunityPolicy.canEdit(studentSession, mine), isTrue);
      expect(CommunityPolicy.canEdit(studentSession, theirs), isFalse);
      expect(CommunityPolicy.canEdit(adminSession, theirs), isFalse);
      expect(CommunityPolicy.canEdit(guestSession, postBy('')), isFalse, reason: 'a guest is nobody');
    });

    test('delete: author or admin', () {
      expect(CommunityPolicy.canDelete(studentSession, mine), isTrue);
      expect(CommunityPolicy.canDelete(adminSession, theirs), isTrue);
      expect(CommunityPolicy.canDelete(studentSession, theirs), isFalse);
      expect(CommunityPolicy.canDelete(guestSession, theirs), isFalse);
    });

    test('pin / hide: admins only', () {
      expect(CommunityPolicy.canPinOrHide(adminSession), isTrue);
      expect(CommunityPolicy.canPinOrHide(teacherSession), isFalse);
    });

    test('report / block: someone else\'s post, signed in, not an admin', () {
      expect(CommunityPolicy.canReportOrBlock(studentSession, theirs), isTrue);
      expect(CommunityPolicy.canReportOrBlock(studentSession, mine), isFalse);
      expect(CommunityPolicy.canReportOrBlock(adminSession, theirs), isFalse);
      expect(CommunityPolicy.canReportOrBlock(guestSession, theirs), isFalse);
    });

    test('guests may read but not interact', () {
      expect(CommunityPolicy.canInteract(guestSession), isFalse);
      expect(CommunityPolicy.canInteract(studentSession), isTrue);
    });
  });

  group('comments', () {
    const c = CommunityComment(id: 'c1', authorId: 's2');
    test('edit: the comment author only', () {
      expect(CommunityPolicy.canEditComment(const CommunitySession(userId: 's2'), c), isTrue);
      expect(CommunityPolicy.canEditComment(adminSession, c), isFalse);
    });

    test('delete comment: its author, the post author, or an admin', () {
      expect(CommunityPolicy.canDeleteComment(const CommunitySession(userId: 's2'), c, postAuthorId: 't1'), isTrue);
      expect(CommunityPolicy.canDeleteComment(teacherSession, c, postAuthorId: 't1'), isTrue);
      expect(CommunityPolicy.canDeleteComment(adminSession, c, postAuthorId: 't1'), isTrue);
      expect(CommunityPolicy.canDeleteComment(studentSession, c, postAuthorId: 't1'), isFalse);
      expect(CommunityPolicy.canDeleteComment(guestSession, c, postAuthorId: ''), isFalse);
    });

    test('delete reply: its author, the parent comment author, or an admin (as firestore.rules)', () {
      const r = CommunityComment(id: 'r1', authorId: 's3');
      expect(CommunityPolicy.canDeleteReply(const CommunitySession(userId: 's3'), r, commentAuthorId: 's2'), isTrue);
      expect(CommunityPolicy.canDeleteReply(const CommunitySession(userId: 's2'), r, commentAuthorId: 's2'), isTrue);
      expect(CommunityPolicy.canDeleteReply(adminSession, r, commentAuthorId: 's2'), isTrue);
      expect(CommunityPolicy.canDeleteReply(teacherSession, r, commentAuthorId: 's2'), isFalse,
          reason: 'the post author is not allowed by the rules');
    });
  });

  group('feed visibility', () {
    final hidden = postBy('t1', id: 'h', hidden: true);
    test('hidden posts: only admins and their author see them', () {
      expect(CommunityPolicy.isVisible(hidden, studentSession), isFalse);
      expect(CommunityPolicy.isVisible(hidden, guestSession), isFalse);
      expect(CommunityPolicy.isVisible(hidden, adminSession), isTrue);
      expect(CommunityPolicy.isVisible(hidden, teacherSession), isTrue);
    });

    test('posts by blocked users disappear', () {
      expect(CommunityPolicy.isVisible(theirs, studentSession, blockedUserIds: {'t1'}), isFalse);
      expect(CommunityPolicy.isVisible(theirs, studentSession, blockedUserIds: {'x'}), isTrue);
    });

    test('main feed drops hidden, blocked and pinned posts', () {
      final posts = [mine, theirs, hidden, postBy('s9', id: 'pin', pinned: true)];
      final feed = CommunityPolicy.mainFeed(posts, studentSession, blockedUserIds: {'t1'});
      expect(feed.map((p) => p.id), ['p1']);
      expect(CommunityPolicy.mainFeed(posts, studentSession, excludePinned: false).map((p) => p.id), ['p1', 'p1', 'pin']);
    });

    test('Friends, My Posts and Saved need an account', () {
      for (final f in CommunityFilter.values) {
        expect(CommunityPolicy.requiresAccount(f),
            [CommunityFilter.friends, CommunityFilter.myPosts, CommunityFilter.saved].contains(f),
            reason: f.name);
      }
    });

    test('legacy filter labels round-trip', () {
      for (final f in CommunityFilter.values) {
        expect(CommunityFilter.fromLabel(f.label), f);
      }
      expect(CommunityFilter.fromLabel('nonsense'), CommunityFilter.all);
    });
  });
}
