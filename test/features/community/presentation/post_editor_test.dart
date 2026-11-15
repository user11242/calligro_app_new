import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/pages/add_post_page.dart';
import 'package:calligro_app/features/community/presentation/pages/edit_post_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';
import 'community_harness.dart';

/// The real add / edit post screens on fakes.
void main() {
  late CommunityHarness h;

  Future<void> openAdd(WidgetTester tester, [CommunitySession session = studentSession]) async {
    h.sessions.session = session;
    await h.pumpPushed(tester, AddPostPage(session: session));
  }

  Finder key(String k) => find.byKey(Key(k));

  setUp(() => h = CommunityHarness());

  group('new post', () {
    testWidgets('publishes the caption as the viewer, then closes with true', (tester) async {
      await openAdd(tester);
      await tester.enterText(key('caption-field'), '  Naskh exercise  ');
      await tester.tap(key('submit-post'));
      await settle(tester);
      final post = h.repo.posts.values.single;
      expect(post.caption, 'Naskh exercise');
      expect(post.authorId, 's1');
      expect(h.popped, [true]);
    });

    testWidgets('an empty post is refused and nothing is written', (tester) async {
      await openAdd(tester);
      await tester.tap(key('submit-post'));
      await settle(tester);
      expect(h.repo.calls, isNot(contains('createPost')));
      expect(find.text('You cannot create an empty post.'), findsOneWidget);
      expect(h.popped, isEmpty);
      await drainMessages(tester);
    });

    testWidgets('photos: picker asks for the free slots; images are uploaded and attached', (tester) async {
      h.picker.next = ['/tmp/a.jpg', '/tmp/b.jpg'];
      await openAdd(tester);
      await tester.tap(key('add-photo'));
      await settle(tester);
      expect(h.picker.requests, [5]);
      expect(key('new-image-0'), findsOneWidget);
      expect(key('new-image-1'), findsOneWidget);

      await tester.tap(find.descendant(of: key('new-image-0'), matching: key('remove-image')));
      await settle(tester);
      expect(key('new-image-1'), findsNothing);

      await tester.tap(key('submit-post'));
      await settle(tester);
      expect(h.repo.posts.values.single.imageUrls, ['https://cdn/s1/b.jpg']);
    });

    testWidgets('at 5 photos the picker is not opened again', (tester) async {
      h.picker.next = List.generate(5, (i) => '/tmp/$i.jpg');
      await openAdd(tester);
      await tester.tap(key('add-photo'));
      await settle(tester);
      await tester.tap(key('add-photo'));
      await settle(tester);
      expect(h.picker.requests, [5], reason: 'second tap only shows the limit message');
      await drainMessages(tester);
    });

    testWidgets('a failed upload keeps the editor open with the text', (tester) async {
      h.media.fail = true;
      h.picker.next = ['/tmp/a.jpg'];
      await openAdd(tester);
      await tester.enterText(key('caption-field'), 'Keep me');
      await tester.tap(key('add-photo'));
      await settle(tester);
      await tester.tap(key('submit-post'));
      await settle(tester);
      expect(h.repo.posts, isEmpty);
      expect(h.popped, isEmpty);
      expect(tester.widget<TextField>(key('caption-field')).controller!.text, 'Keep me');
      await drainMessages(tester);
    });

    testWidgets('students do not get admin options', (tester) async {
      await openAdd(tester);
      expect(key('toggle-pin'), findsNothing);
      expect(key('toggle-hide'), findsNothing);
      expect(key('toggle-link'), findsNothing);
    });

    testWidgets('admins can pin, hide and attach a link', (tester) async {
      await openAdd(tester, adminSession);
      await tester.enterText(key('caption-field'), 'Announcement');
      await tester.tap(key('toggle-pin'));
      await tester.tap(key('toggle-hide'));
      await tester.tap(key('toggle-link'));
      await settle(tester);
      await tester.enterText(key('link-url'), 'calligroacademy.com');
      await tester.tap(key('submit-post'));
      await settle(tester);
      final post = h.repo.posts.values.single;
      expect(post.isPinned, isTrue);
      expect(post.isHidden, isTrue);
      expect(post.linkUrl, 'https://calligroacademy.com');
    });
  });

  group('edit post', () {
    setUp(() => h.repo.addPost(postBy('s1', id: 'p1', caption: 'Old', images: ['https://cdn/old.jpg'])));

    Future<void> openEdit(WidgetTester tester) async {
      h.sessions.session = studentSession;
      await h.pumpPushed(tester, EditPostPage(post: h.repo.posts['p1']!, session: studentSession));
    }

    testWidgets('starts with the post\'s caption and images; saves changes', (tester) async {
      await openEdit(tester);
      expect(tester.widget<TextField>(key('caption-field')).controller!.text, 'Old');
      expect(key('existing-image-0'), findsOneWidget);
      await tester.enterText(key('caption-field'), 'New');
      await tester.tap(key('submit-post'));
      await settle(tester);
      expect(h.repo.posts['p1']!.caption, 'New');
      expect(h.repo.posts['p1']!.imageUrls, ['https://cdn/old.jpg']);
      expect(h.repo.posts['p1']!.isEdited, isTrue);
      expect(h.popped, [true]);
    });

    testWidgets('removing every image and the caption is refused (no empty posts)', (tester) async {
      await openEdit(tester);
      await tester.enterText(key('caption-field'), '');
      await tester.tap(find.descendant(of: key('existing-image-0'), matching: key('remove-image')));
      await settle(tester);
      await tester.tap(key('submit-post'));
      await settle(tester);
      expect(h.repo.calls, isNot(contains('updatePost')));
      expect(h.repo.posts['p1']!.caption, 'Old');
      await drainMessages(tester);
    });

    testWidgets('no admin options while editing', (tester) async {
      await openEdit(tester);
      expect(key('toggle-pin'), findsNothing);
    });
  });
}
