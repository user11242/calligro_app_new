import 'package:calligro_app/features/community/application/community_feed_controller.dart';
import 'package:calligro_app/features/community/domain/models/community_filter.dart';
import 'package:calligro_app/features/community/domain/models/community_post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community_repository.dart';
import '../fakes/fake_follow_repository.dart';

void main() {
  group('Community Feed Widget Tests', () {
    late FakeCommunityRepository fakeRepo;
    late FakeFollowRepository fakeFollow;
    late CommunityFeedController controller;

    setUp(() {
      fakeRepo = FakeCommunityRepository();
      fakeFollow = FakeFollowRepository();

      controller = CommunityFeedController(
        repository: fakeRepo,
        followRepository: fakeFollow,
        currentUserId: 'u_student',
      );
    });

    Widget createFeedScreen() {
      return MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.isLoading) {
                return const Center(child: CircularProgressIndicator(key: Key('loading-indicator')));
              }
              if (controller.posts.isEmpty) {
                return const Center(child: Text('No posts yet in this section', key: Key('empty-feed')));
              }
              return Column(
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CommunityFilter.values.map((filter) {
                        final isSelected = controller.selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            key: Key('chip-${filter.name}'),
                            label: Text(filter.displayName),
                            selected: isSelected,
                            onSelected: (_) => controller.setFilter(filter),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Posts List
                  Expanded(
                    child: ListView.builder(
                      itemCount: controller.posts.length,
                      itemBuilder: (context, index) {
                        final post = controller.posts[index];
                        return ListTile(
                          key: Key('post-item-${post.id}'),
                          title: Text(post.authorName),
                          subtitle: Text(post.caption),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    testWidgets('shows empty state when feed has no posts', (tester) async {
      await controller.init();
      await tester.pumpWidget(createFeedScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty-feed')), findsOneWidget);
    });

    testWidgets('renders feed posts and switches filter cleanly', (tester) async {
      fakeRepo.posts.addAll([
        CommunityPost(
          id: 'p_1',
          authorId: 'u_teacher',
          authorName: 'Ustadha Fatima',
          authorRole: 'teacher',
          caption: 'Masterclass preview',
          createdAt: DateTime.now(),
        ),
        CommunityPost(
          id: 'p_2',
          authorId: 'u_student',
          authorName: 'My Account',
          authorRole: 'student',
          caption: 'My pen stroke homework',
          createdAt: DateTime.now(),
        ),
      ]);

      await controller.init();
      await tester.pumpWidget(createFeedScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post-item-p_1')), findsOneWidget);
      expect(find.byKey(const Key('post-item-p_2')), findsOneWidget);

      // Select 'My Posts' chip
      await tester.tap(find.byKey(const Key('chip-myPosts')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post-item-p_2')), findsOneWidget);
      expect(find.byKey(const Key('post-item-p_1')), findsNothing);
    });
  });
}

