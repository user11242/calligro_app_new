import 'package:calligro_app/features/community/data/firestore_community_adapters.dart';
import 'package:calligro_app/features/community/data/firestore_community_repository.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the REAL database schema (the same paths and field names the old
/// CommunityService used, which firestore.rules, the web portal and Cloud Functions rely on).
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreCommunityRepository repo;

  const student = CommunitySession(userId: 's1', name: 'Student One', photoUrl: 'https://img/s1', role: 'student');
  const teacher = CommunitySession(userId: 't1', name: 'Teacher', photoUrl: 'https://img/t1', role: 'teacher');
  const admin = CommunitySession(userId: 'a1', name: 'Admin', role: 'admin');

  Future<Map<String, dynamic>> doc(String path) async => (await db.doc(path).get()).data() ?? {};

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FirestoreCommunityRepository(firestore: db);
    await db.doc('users/s1').set({'name': 'Student One', 'role': 'student', 'postCount': 0});
    await db.doc('students/s1').set({'postCount': 0});
    await db.doc('users/t1').set({'name': 'Teacher', 'role': 'teacher', 'postCount': 2});
    await db.doc('teachers/t1').set({'postCount': 2});
    await db.doc('users/a1').set({'name': 'Admin', 'role': 'admin'});
  });

  Future<String> onlyPostId() async => (await db.collection('community_posts').get()).docs.single.id;

  // ═══════════════════════════════════════════════════════════════════════
  group('createPost', () {
    test('writes the exact post schema with a server timestamp, and bumps post counts', () async {
      await repo.createPost(const NewPost(caption: '  Naskh practice  '), author: student, imageUrls: ['https://u/1']);
      final id = await onlyPostId();
      final p = await doc('community_posts/$id');
      expect(p['userId'], 's1');
      expect(p['userName'], 'Student One');
      expect(p['userImageUrl'], 'https://img/s1');
      expect(p['userRole'], 'student');
      expect(p['caption'], 'Naskh practice');
      expect(p['imageUrls'], ['https://u/1']);
      expect(p['timestamp'], isA<Timestamp>(), reason: 'the feed orders by timestamp — a missing one hides the post');
      expect(p['likesCount'], 0);
      expect(p['commentsCount'], 0);
      expect(p['likes'], <String, dynamic>{});
      expect(p.containsKey('linkUrl'), isFalse);
      expect(p.containsKey('isPinned'), isFalse);
      expect((await doc('users/s1'))['postCount'], 1);
      expect((await doc('students/s1'))['postCount'], 1);
    });

    test('a teacher post bumps teachers/{uid}.postCount', () async {
      await repo.createPost(const NewPost(caption: 'x'), author: teacher, imageUrls: const []);
      expect((await doc('teachers/t1'))['postCount'], 3);
    });

    test('link / pin / hidden are kept for admins only', () async {
      const fancy = NewPost(caption: 'news', linkUrl: ' https://calligro.app ', linkTitle: 'Site', isPinned: true, isHidden: true);
      await repo.createPost(fancy, author: student, imageUrls: const []);
      final studentPost = await doc('community_posts/${await onlyPostId()}');
      expect(studentPost.keys, isNot(containsAll(['linkUrl', 'linkTitle', 'isPinned', 'isHidden'])));

      await db.doc('community_posts/${await onlyPostId()}').delete();
      await repo.createPost(fancy, author: admin, imageUrls: const []);
      final adminPost = await doc('community_posts/${await onlyPostId()}');
      expect(adminPost['linkUrl'], 'https://calligro.app');
      expect(adminPost['linkTitle'], 'Site');
      expect(adminPost['isPinned'], isTrue);
      expect(adminPost['isHidden'], isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('reading', () {
    test('maps every field back into the model', () async {
      await db.doc('community_posts/p1').set({
        'userId': 't1',
        'userName': 'Teacher',
        'userImageUrl': 'https://img/t1',
        'userRole': 'teacher',
        'caption': 'hello',
        'imageUrls': ['a', 'b'],
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        'likesCount': 2,
        'likes': {'s1': true, 'x': true},
        'commentsCount': 3,
        'isEdited': true,
        'isPinned': true,
        'isHidden': true,
        'linkUrl': 'https://l',
        'linkTitle': 'L',
      });
      final p = (await repo.watchPost('p1').first)!;
      expect(p.authorId, 't1');
      expect(p.authorName, 'Teacher');
      expect(p.authorPhotoUrl, 'https://img/t1');
      expect(p.authorRole, 'teacher');
      expect(p.imageUrls, ['a', 'b']);
      expect(p.createdAt!.isAtSameMomentAs(DateTime.utc(2026, 1, 2)), isTrue);
      expect(p.likesCount, 2);
      expect(p.likerIds, {'s1', 'x'});
      expect(p.isLikedBy('s1'), isTrue);
      expect(p.commentsCount, 3);
      expect([p.isEdited, p.isPinned, p.isHidden], [true, true, true]);
      expect(p.linkUrl, 'https://l');
    });

    test('a deleted post reads as null', () async {
      expect(await repo.watchPost('nope').first, isNull);
    });

    test('feed tabs: All / Teachers / My Posts / Friends / Saved / Popular', () async {
      Future<void> post(String id, String user, String role, int likes, int day) => db.doc('community_posts/$id').set({
            'userId': user,
            'userRole': role,
            'likesCount': likes,
            'timestamp': Timestamp.fromDate(DateTime(2026, 1, day)),
          });
      await post('p1', 's1', 'student', 5, 1);
      await post('p2', 't1', 'teacher', 1, 2);
      await post('p3', 's2', 'student', 9, 3);
      List<String> ids(List<dynamic> posts) => posts.map((p) => p.id as String).toList();

      expect(ids(await repo.watchFeed(CommunityFilter.all, currentUserId: 's1').first), ['p3', 'p2', 'p1']);
      expect(ids(await repo.watchFeed(CommunityFilter.teachers, currentUserId: 's1').first), ['p2']);
      expect(ids(await repo.watchFeed(CommunityFilter.myPosts, currentUserId: 's1').first), ['p1']);
      expect(ids(await repo.watchFeed(CommunityFilter.popular, currentUserId: 's1').first), ['p3', 'p1', 'p2']);
      expect(ids(await repo.watchFeed(CommunityFilter.friends, currentUserId: 's1', followingIds: ['t1']).first), ['p2']);
      expect(await repo.watchFeed(CommunityFilter.friends, currentUserId: 's1').first, isEmpty);
      expect(ids(await repo.watchFeed(CommunityFilter.saved, currentUserId: 's1', savedPostIds: ['p3']).first), ['p3']);
      expect(await repo.watchFeed(CommunityFilter.saved, currentUserId: 's1').first, isEmpty);
      expect(await repo.watchFeed(CommunityFilter.myPosts, currentUserId: '').first, isEmpty, reason: 'guest');
    });

    test('liked posts and posts by id (missing ids are just absent)', () async {
      await db.doc('community_posts/p1').set({'userId': 't1', 'likes': {'s1': true}});
      await db.doc('community_posts/p2').set({'userId': 't1', 'likes': {'x': true}});
      expect((await repo.watchLikedPosts('s1').first).map((p) => p.id), ['p1']);
      expect(await repo.watchLikedPosts('').first, isEmpty);
      expect((await repo.watchPostsByIds(['p2', 'gone']).first).map((p) => p.id), ['p2']);
      expect(await repo.watchPostsByIds(const []).first, isEmpty);
    });

    test('pinned posts and a user\'s posts', () async {
      await db.doc('community_posts/p1').set({'userId': 's1', 'isPinned': true, 'timestamp': Timestamp.now()});
      await db.doc('community_posts/p2').set({'userId': 's1', 'timestamp': Timestamp.now()});
      expect((await repo.watchPinnedPosts().first).map((p) => p.id), ['p1']);
      expect((await repo.watchUserPosts('s1').first).map((p) => p.id).toSet(), {'p1', 'p2'});
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('likes, pin, hide, edit', () {
    setUp(() => db.doc('community_posts/p1').set({'userId': 't1', 'likesCount': 0, 'likes': <String, dynamic>{}}));

    test('like adds me to likes and +1; unlike removes me and -1', () async {
      await repo.setLiked('p1', userId: 's1', like: true);
      var p = await doc('community_posts/p1');
      expect(p['likes'], {'s1': true});
      expect(p['likesCount'], 1);
      await repo.setLiked('p1', userId: 's1', like: false);
      p = await doc('community_posts/p1');
      expect(p['likes'], <String, dynamic>{});
      expect(p['likesCount'], 0);
    });

    test('pin / hide / edit', () async {
      await repo.setPinned('p1', true);
      await repo.setHidden('p1', true);
      await repo.updatePost('p1', caption: 'new', imageUrls: ['k']);
      final p = await doc('community_posts/p1');
      expect([p['isPinned'], p['isHidden'], p['caption'], p['imageUrls'], p['isEdited']], [true, true, 'new', ['k'], true]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('comments and replies', () {
    setUp(() => db.doc('community_posts/p1').set({'userId': 't1', 'commentsCount': 0}));

    test('comment schema (userPhotoUrl, text, server timestamp) and +1 on the post', () async {
      await repo.addComment('p1', author: student, text: 'Beautiful');
      final c = (await db.collection('community_posts/p1/comments').get()).docs.single;
      expect(c.data()['userId'], 's1');
      expect(c.data()['userName'], 'Student One');
      expect(c.data()['userPhotoUrl'], 'https://img/s1');
      expect(c.data()['userRole'], 'student');
      expect(c.data()['text'], 'Beautiful');
      expect(c.data()['timestamp'], isA<Timestamp>());
      expect((await doc('community_posts/p1'))['commentsCount'], 1);

      final read = (await repo.watchComments('p1').first).single;
      expect(read.authorPhotoUrl, 'https://img/s1', reason: 'avatars come from userPhotoUrl');
      expect(read.text, 'Beautiful');
    });

    test('edit marks isEdited; delete removes it and -1', () async {
      await repo.addComment('p1', author: student, text: 'a');
      final id = (await db.collection('community_posts/p1/comments').get()).docs.single.id;
      await repo.editComment('p1', id, 'b');
      expect((await doc('community_posts/p1/comments/$id'))['isEdited'], isTrue);
      await repo.deleteComment('p1', id);
      expect((await db.collection('community_posts/p1/comments').get()).docs, isEmpty);
      expect((await doc('community_posts/p1'))['commentsCount'], 0);
    });

    test('replies: +1 on the comment and the post; edit; delete -1 on both; oldest first', () async {
      await db.doc('community_posts/p1/comments/c1').set({'userId': 't1', 'replyCount': 0});
      await repo.addReply('p1', 'c1', author: student, text: 'first');
      await repo.addReply('p1', 'c1', author: teacher, text: 'second');
      expect((await doc('community_posts/p1/comments/c1'))['replyCount'], 2);
      expect((await doc('community_posts/p1'))['commentsCount'], 2);
      final replies = await repo.watchReplies('p1', 'c1').first;
      expect(replies.map((r) => r.text), ['first', 'second']);
      await repo.editReply('p1', 'c1', replies.first.id, 'edited');
      expect((await doc('community_posts/p1/comments/c1/replies/${replies.first.id}'))['isEdited'], isTrue);
      await repo.deleteReply('p1', 'c1', replies.first.id);
      expect((await doc('community_posts/p1/comments/c1'))['replyCount'], 1);
      expect((await doc('community_posts/p1'))['commentsCount'], 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('deletePost', () {
    test('removes comments, replies, the author\'s own save, and decrements post counts', () async {
      await db.doc('users/t1/saved_posts/p1').set({'timestamp': Timestamp.now()});
      await db.doc('community_posts/p1').set({'userId': 't1', 'imageUrls': ['https://img/1']});
      await db.doc('community_posts/p1/comments/c1').set({'text': 'x'});
      await db.doc('community_posts/p1/comments/c1/replies/r1').set({'text': 'y'});
      final post = (await repo.watchPost('p1').first)!;
      final toDelete = await repo.deletePost(post);
      expect(toDelete, ['https://img/1'], reason: 'the caller removes these from storage');
      expect((await db.doc('community_posts/p1').get()).exists, isFalse);
      expect((await db.collection('community_posts/p1/comments').get()).docs, isEmpty);
      expect((await db.collection('community_posts/p1/comments/c1/replies').get()).docs, isEmpty);
      expect((await db.doc('users/t1/saved_posts/p1').get()).exists, isFalse);
      expect((await doc('users/t1'))['postCount'], 1);
      expect((await doc('teachers/t1'))['postCount'], 1);
    });

    test('never decrements a post count below zero', () async {
      await db.doc('community_posts/p1').set({'userId': 's1'});
      await repo.deletePost((await repo.watchPost('p1').first)!);
      expect((await doc('users/s1'))['postCount'], 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('saved, report, block', () {
    test('save / unsave under users/{uid}/saved_posts', () async {
      await repo.setSaved('p1', userId: 's1', saved: true);
      expect(await repo.getSavedPostIds('s1'), ['p1']);
      expect(await repo.watchSavedPostIds('s1').first, ['p1']);
      await repo.setSaved('p1', userId: 's1', saved: false);
      expect(await repo.getSavedPostIds('s1'), isEmpty);
      expect(await repo.getSavedPostIds(''), isEmpty);
    });

    test('reports go to the `reports` collection (read by admins, allowed by rules)', () async {
      await repo.reportPost(const CommunityPost(id: 'p1', authorId: 't1'), reporterId: 's1');
      final r = (await db.collection('reports').get()).docs.single.data();
      expect(r['postId'], 'p1');
      expect(r['reportedUserId'], 't1');
      expect(r['reportedByUserId'], 's1');
      expect(r['status'], 'pending');
      expect(r['timestamp'], isA<Timestamp>());
      expect((await db.collection('community_reports').get()).docs, isEmpty);
    });

    test('block / unblock use the users/{uid}.blockedUsers array, and it can be watched', () async {
      await repo.blockUser('s1', blockedUserId: 't1');
      expect((await doc('users/s1'))['blockedUsers'], ['t1']);
      expect(await repo.watchBlockedUserIds('s1').first, ['t1']);
      await repo.unblockUser('s1', blockedUserId: 't1');
      expect((await doc('users/s1'))['blockedUsers'], isEmpty);
      expect(await repo.watchBlockedUserIds('').first, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('follows', () {
    late FirestoreFollowRepository follows;
    setUp(() async {
      follows = FirestoreFollowRepository(firestore: db);
      await db.doc('users/s1').update({'followingCount': 0});
      await db.doc('users/t1').update({'followerCount': 0});
    });

    test('follow writes both sides and both counters; unfollow undoes it', () async {
      await follows.setFollowing(userId: 's1', targetUserId: 't1', follow: true);
      expect((await db.doc('users/t1/followers/s1').get()).data()!['followerId'], 's1');
      expect((await db.doc('users/s1/following/t1').get()).exists, isTrue);
      expect((await doc('users/t1'))['followerCount'], 1);
      expect((await doc('users/s1'))['followingCount'], 1);
      expect(await follows.watchIsFollowing(userId: 's1', targetUserId: 't1').first, isTrue);
      expect(await follows.getFollowingIds('s1'), ['t1']);

      await follows.setFollowing(userId: 's1', targetUserId: 't1', follow: false);
      expect((await db.doc('users/t1/followers/s1').get()).exists, isFalse);
      expect((await doc('users/t1'))['followerCount'], 0);
      expect(await follows.watchIsFollowing(userId: 's1', targetUserId: 't1').first, isFalse);
    });

    test('following yourself is refused', () async {
      await expectLater(follows.setFollowing(userId: 's1', targetUserId: 's1', follow: true), throwsArgumentError);
    });

    test('guests follow nobody', () async {
      expect(await follows.watchIsFollowing(userId: '', targetUserId: 't1').first, isFalse);
      expect(await follows.getFollowingIds(''), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('users and session', () {
    test('getUsers skips missing users; search is a case-insensitive prefix on name_lower', () async {
      // Fresh db: the fake (unlike Firestore) throws on docs that lack the orderBy field.
      db = FakeFirebaseFirestore();
      await db.doc('users/u1').set({'name': 'Ali Hassan', 'name_lower': 'ali hassan', 'photoUrl': 'p', 'role': 'teacher'});
      await db.doc('users/u2').set({'name': 'Alia', 'name_lower': 'alia'});
      await db.doc('users/u3').set({'name': 'Omar', 'name_lower': 'omar'});
      final users = FirestoreCommunityUserRepository(firestore: db);
      final got = await users.getUsers(['u1', 'missing']);
      expect(got.single.name, 'Ali Hassan');
      expect(got.single.role, 'teacher');
      expect((await users.searchByName('  ALI ')).map((u) => u.id).toSet(), {'u1', 'u2'});
      expect(await users.searchByName('   '), isEmpty);
    });

    test('session: profile from users/{uid}; guest when signed out', () async {
      await db.doc('users/u1').set({'name': 'Ali', 'photoUrl': 'p', 'role': 'admin'});
      final signedIn = FirebaseCommunitySessionSource(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')), firestore: db);
      final s = await signedIn.currentSession();
      expect([s.userId, s.name, s.photoUrl, s.role, s.isAdmin], ['u1', 'Ali', 'p', 'admin', true]);
      final out = await FirebaseCommunitySessionSource(auth: MockFirebaseAuth(), firestore: db).currentSession();
      expect(out.isGuest, isTrue);
    });
  });
}
