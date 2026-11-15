import 'package:calligro_app/features/community/application/single_post_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

void main() {
  late FakeCommunityRepository repo;
  late FakeUserRepository users;

  SinglePostController make(CommunitySession session, {String id = 'p1'}) =>
      SinglePostController(repository: repo, users: users, session: session, postId: id)..start();

  setUp(() {
    repo = FakeCommunityRepository();
    users = FakeUserRepository()..users['t1'] = const CommunityUser(id: 't1', name: 'Ustadh Ali', role: 'teacher');
  });

  test('loads the post live, with the author\'s current name', () async {
    repo.addPost(postBy('t1', id: 'p1', caption: 'Thuluth'));
    final c = make(studentSession);
    expect(c.isLoading, isTrue);
    await pumpEventQueue();
    expect(c.isLoading, isFalse);
    expect(c.post!.caption, 'Thuluth');
    expect(c.post!.authorName, 'Ustadh Ali');
    expect(c.post!.authorRole, 'teacher');

    repo.addPost(postBy('t1', id: 'p1', caption: 'Edited'));
    await pumpEventQueue();
    expect(c.post!.caption, 'Edited');
    expect(users.lookups, hasLength(1), reason: 'author looked up once, not on every change');
    c.dispose();
  });

  test('a missing or deleted post shows "nothing to show"', () async {
    final c = make(studentSession, id: 'nope');
    await pumpEventQueue();
    expect(c.isLoading, isFalse);
    expect(c.post, isNull);
  });

  test('a hidden post opened by link is not shown to other students', () async {
    repo.addPost(postBy('t1', id: 'p1', hidden: true));
    final student = make(studentSession);
    final author = make(const CommunitySession(userId: 't1', role: 'teacher'));
    final admin = make(adminSession);
    await pumpEventQueue();
    expect(student.post, isNull);
    expect(author.post, isNotNull);
    expect(admin.post, isNotNull);
  });

  test('a failed author lookup still shows the post with its stored name', () async {
    users.failing.add('getUsers');
    repo.addPost(postBy('t1', id: 'p1'));
    final c = make(guestSession);
    await pumpEventQueue();
    expect(c.post!.authorName, 'Author t1');
  });

  test('stream errors end loading with no post', () async {
    repo.failing.add('watchPost');
    final c = make(studentSession);
    await pumpEventQueue();
    expect(c.isLoading, isFalse);
    expect(c.post, isNull);
  });
}
