import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/pages/community_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';
import 'community_harness.dart';

/// The real feed tab on fakes.
void main() {
  late CommunityHarness h;

  Future<void> show(WidgetTester tester, [CommunitySession session = studentSession]) async {
    h.sessions.session = session;
    await h.pump(tester, const CommunityPage());
  }

  List<String> cardIds(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String> && '${(w.key as ValueKey<String>).value}'.startsWith('card-')))
      .map((w) => (w.key as ValueKey<String>).value.substring(5))
      .toList();

  setUp(() {
    h = CommunityHarness();
    h.repo
      ..addPost(postBy('s2', id: 'old', day: 1))
      ..addPost(postBy('t1', id: 'teach', role: 'teacher', day: 2))
      ..addPost(postBy('s2', id: 'new', day: 3))
      ..addPost(postBy('a1', id: 'pin', role: 'admin', day: 0, pinned: true));
  });

  testWidgets('pinned post on top (once), then newest first', (tester) async {
    await show(tester);
    expect(cardIds(tester), ['pin', 'new', 'teach', 'old']);
  });

  testWidgets('author names are refreshed from their profile', (tester) async {
    h.users.users['s2'] = const CommunityUser(id: 's2', name: 'Sara Renamed');
    await show(tester);
    expect(find.text('Sara Renamed'), findsNWidgets(2));
  });

  testWidgets('Teachers tab shows only teacher posts', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('filter-teachers')));
    await settle(tester);
    expect(cardIds(tester), ['pin', 'teach']);
  });

  testWidgets('My Posts with none shows the empty message', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('filter-myPosts')));
    await settle(tester);
    expect(find.byKey(const Key('feed-empty')), findsOneWidget);
  });

  testWidgets('Friends shows people I follow', (tester) async {
    h.follows.following['s1'] = {'t1'};
    await show(tester);
    await tester.tap(find.byKey(const Key('filter-friends')));
    await settle(tester);
    expect(cardIds(tester), ['pin', 'teach']);
  });

  testWidgets('guests tapping Friends get the sign-in prompt and stay on All', (tester) async {
    await show(tester, guestSession);
    await tester.tap(find.byKey(const Key('filter-friends')));
    await settle(tester);
    expect(signInPrompt, findsOneWidget);
    expect(cardIds(tester), ['pin', 'new', 'teach', 'old']);
  });

  testWidgets('blocked authors disappear live', (tester) async {
    await show(tester);
    h.repo.blocked['s1'] = ['s2'];
    h.repo.addPost(h.repo.posts['teach']!); // any change → streams re-emit
    await settle(tester);
    expect(cardIds(tester), ['pin', 'teach']);
  });

  testWidgets('hidden posts: not shown to students', (tester) async {
    h.repo.addPost(postBy('t1', id: 'hid', day: 9, hidden: true));
    await show(tester);
    expect(cardIds(tester), isNot(contains('hid')));
  });

  testWidgets('a feed error shows the error message', (tester) async {
    h.repo.failing.add('watchFeed');
    await show(tester);
    expect(find.text('Error loading posts.'), findsOneWidget);
  });

  testWidgets('new posts appear live', (tester) async {
    await show(tester);
    h.repo.addPost(postBy('s2', id: 'newest', day: 10));
    await settle(tester);
    expect(cardIds(tester).take(2), ['pin', 'newest']);
  });

  testWidgets('the create bar opens the editor; publishing adds the post to the feed', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('create-post-bar')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('caption-field')), 'Hello community');
    await tester.tap(find.byKey(const Key('submit-post')));
    await settle(tester);
    expect(find.byKey(const Key('caption-field')), findsNothing, reason: 'editor closed');
    expect(find.text('Hello community'), findsOneWidget);
  });

  testWidgets('guests tapping the create bar get the sign-in prompt', (tester) async {
    await show(tester, guestSession);
    await tester.tap(find.byKey(const Key('create-post-bar')));
    await settle(tester);
    expect(signInPrompt, findsOneWidget);
    expect(find.byKey(const Key('caption-field')), findsNothing);
  });
}
