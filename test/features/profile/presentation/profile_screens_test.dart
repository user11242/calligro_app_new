import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/community_scope.dart';
import 'package:calligro_app/features/profile/domain/profile_models.dart';
import 'package:calligro_app/features/profile/presentation/pages/my_profile_tab.dart';
import 'package:calligro_app/features/profile/presentation/pages/public_profile_page.dart';
import 'package:calligro_app/features/profile/presentation/profile_scope.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../community/fakes/fake_community.dart';
import '../../community/presentation/community_harness.dart' show settle;
import '../fakes/fake_profile.dart';

/// The REAL profile screens on in-memory fakes (profiles + the community parts they embed).
void main() {
  late FakeProfileStore store;
  late FakeViewerSource viewers;
  late FakeCommunityRepository posts;
  late FakeFollowRepository follows;
  final ownProfileTaps = <String>[];

  Finder key(String k) => find.byKey(Key(k));

  Future<void> pump(WidgetTester tester, Widget screen, {ProfileViewer viewer = studentViewer}) async {
    viewers.viewer = viewer;
    final community = CommunityServices(
      repository: posts,
      follows: follows,
      users: FakeUserRepository(),
      sessions: FakeSessionSource(
          viewer.isGuest ? CommunitySession.guest : CommunitySession(userId: viewer.userId, role: viewer.role)),
      media: FakeMediaStorage(),
      translator: FakeTranslator(),
      imagePicker: (_) => FakeImagePicker(),
    );
    final profile = ProfileServices(
      profiles: store,
      counts: store,
      followLists: store,
      courses: store,
      reviews: store,
      viewer: viewers,
    );
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) =>
          CommunityScope(services: community, child: ProfileScope(services: profile, child: child!)),
      routes: {'/LoginPage': (_) => const Scaffold(body: Text('LOGIN PAGE'))},
      home: screen,
    ));
    await settle(tester);
  }

  Future<void> pumpPublic(WidgetTester tester, String userId, {ProfileViewer viewer = studentViewer}) => pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-profile'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfilePage(userId: userId, onDashboardProfileTap: (id, _) => ownProfileTaps.add(id)),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        viewer: viewer,
      ).then((_) async {
        await tester.tap(key('open-profile'));
        await settle(tester);
      });

  String tabText(WidgetTester tester, ProfileTab t) =>
      (tester.widget<Tab>(key('tab-${t.name}'))).text!;

  setUp(() {
    ownProfileTaps.clear();
    viewers = FakeViewerSource(studentViewer);
    posts = FakeCommunityRepository();
    follows = FakeFollowRepository();
    store = FakeProfileStore()
      ..put(sara)
      ..put(ali)
      ..put(boss)
      ..posts['s1'] = 1
      ..posts['t1'] = 2
      ..saved['s1'] = 1
      ..liked['s1'] = 0
      ..courses['t1'] = [
        const TeacherCourse(id: 'c1', raw: {'courseName': 'Thuluth 101'}, studentCount: 3, enrolledStudentIds: ['s1']),
      ]
      ..reviews['t1'] = [
        TeacherReview(id: 'r1', studentName: 'Sara', courseName: 'Naskh', rating: 4, text: 'Patient teacher', createdAt: DateTime(2026, 2, 1)),
      ]
      ..followers['t1'] = [
        const FollowListEntry(id: 's2', name: 'Omar'),
        const FollowListEntry(id: 's1', name: 'Sara'),
      ];
    posts
      ..addPost(postBy('t1', id: 'tp', role: 'teacher', caption: 'Teacher post'))
      ..addPost(postBy('s1', id: 'sp', caption: 'Sara post'));
    posts.saved['s1'] = {'tp'};
  });

  group('MyProfileTab', () {
    testWidgets('student: header, counts, Saved / Liked tabs with counts, settings', (tester) async {
      await pump(tester, const MyProfileTab());
      expect(find.text('Sara'), findsOneWidget);
      expect(key('badge-student'), findsOneWidget);
      expect(find.text('Learning Naskh'), findsOneWidget);
      expect(find.descendant(of: key('stat-posts'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: key('stat-followers'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: key('stat-following'), matching: find.text('5')), findsOneWidget);
      expect(tabText(tester, ProfileTab.saved), 'Saved (1)');
      expect(tabText(tester, ProfileTab.liked), 'Liked (0)');
      expect(key('profile-settings'), findsOneWidget);
      expect(key('follow-button'), findsNothing);
      expect(find.text('Teacher post'), findsOneWidget, reason: 'the Saved tab shows the saved post');
    });

    testWidgets('teacher: teacher badge, own commission, rating, languages, flag', (tester) async {
      await pump(tester, const MyProfileTab(), viewer: teacherViewer);
      expect(key('badge-teacher'), findsOneWidget);
      expect(key('badge-commission'), findsOneWidget);
      expect(find.textContaining('60%'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget, reason: 'languages shown in their own script');
      expect(find.text('🇯🇴'), findsOneWidget);
      expect(find.byKey(const Key('tab-courses')), findsNothing, reason: 'own tab: Saved / Liked');
    });

    testWidgets('teacher without a commission yet: "waiting for admin" badge', (tester) async {
      store.put(const UserProfile(id: 't1', role: 'teacher', name: 'New Teacher'));
      await pump(tester, const MyProfileTab(), viewer: teacherViewer);
      expect(key('badge-commission-pending'), findsOneWidget);
    });

    testWidgets('admin: admin badge, email, My Posts tab first', (tester) async {
      store.posts['a1'] = 0;
      await pump(tester, const MyProfileTab(), viewer: adminViewer);
      expect(key('badge-admin'), findsOneWidget);
      expect(find.text('admin@calligro.com'), findsOneWidget);
      expect(tabText(tester, ProfileTab.myPosts), 'My Posts (0)');
    });

    testWidgets('guest: sign-in screen', (tester) async {
      await pump(tester, const MyProfileTab(), viewer: guestViewer);
      await tester.tap(key('guest-login'));
      await settle(tester);
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    });

    testWidgets('live: a rename shows immediately', (tester) async {
      await pump(tester, const MyProfileTab());
      store.put(const UserProfile(id: 's1', role: 'student', name: 'Sara Renamed'));
      await settle(tester);
      expect(find.text('Sara Renamed'), findsOneWidget);
    });
  });

  group('PublicProfilePage', () {
    testWidgets('a teacher seen by a student: Courses / Reviews / Posts, follow, no private data', (tester) async {
      await pumpPublic(tester, 't1');
      expect(find.text('Ustadh Ali'), findsOneWidget);
      expect(tabText(tester, ProfileTab.courses), 'Courses (1)');
      expect(tabText(tester, ProfileTab.posts), 'Posts (2)');
      expect(key('course-c1'), findsOneWidget);
      expect(key('enrolled-badge'), findsOneWidget, reason: 's1 is enrolled');
      expect(key('follow-button'), findsOneWidget);
      expect(key('badge-commission'), findsNothing);
      expect(key('profile-settings'), findsNothing);

      await tester.tap(key('tab-reviews'));
      await settle(tester);
      expect(find.text('Patient teacher'), findsOneWidget);

      await tester.tap(key('tab-posts'));
      await settle(tester);
      expect(find.text('Teacher post'), findsOneWidget);
    });

    testWidgets('someone not enrolled sees no "enrolled" badge (guests may view teachers)', (tester) async {
      await pumpPublic(tester, 't1', viewer: guestViewer);
      expect(key('course-c1'), findsOneWidget);
      expect(key('enrolled-badge'), findsNothing);
      expect(key('follow-button'), findsNothing, reason: 'guests cannot follow');
    });

    testWidgets('follow from the profile', (tester) async {
      await pumpPublic(tester, 't1');
      await tester.tap(key('follow-button'));
      await settle(tester);
      expect(follows.following['s1'], {'t1'});
    });

    testWidgets('a student\'s page: no tab bar, their posts listed', (tester) async {
      await pumpPublic(tester, 's1', viewer: teacherViewer);
      expect(key('profile-tabs'), findsNothing);
      expect(find.text('Sara post'), findsOneWidget);
      expect(find.text('Student Profile'), findsOneWidget);
    });

    testWidgets('an admin seen by others gets the verified mark', (tester) async {
      await pumpPublic(tester, 'a1');
      expect(key('admin-verified'), findsOneWidget);
      expect(key('profile-email'), findsNothing, reason: 'email is private');
    });

    testWidgets('a teacher on their own public page: no follow button', (tester) async {
      await pumpPublic(tester, 't1', viewer: teacherViewer);
      expect(key('follow-button'), findsNothing);
      expect(key('tab-courses'), findsOneWidget);
    });

    testWidgets('unknown user: "user not found"', (tester) async {
      await pumpPublic(tester, 'ghost');
      expect(key('profile-not-found'), findsOneWidget);
    });

    testWidgets('a teacher with nothing yet: empty courses and reviews', (tester) async {
      store
        ..courses['t1'] = []
        ..reviews['t1'] = []
        ..changed();
      await pumpPublic(tester, 't1');
      expect(key('no-courses'), findsOneWidget);
      await tester.tap(key('tab-reviews'));
      await settle(tester);
      expect(key('no-reviews'), findsOneWidget);
    });
  });

  group('followers list', () {
    testWidgets('opens from the header, me first; tapping someone opens their profile', (tester) async {
      store.put(const UserProfile(id: 's2', role: 'student', name: 'Omar'));
      await pumpPublic(tester, 't1');
      await tester.tap(key('stat-followers'));
      await settle(tester);
      final names = tester.widgetList<ListTile>(find.byType(ListTile)).map((t) => (t.key as ValueKey<String>).value).toList();
      expect(names, ['person-s1', 'person-s2']);

      await tester.tap(key('person-s2'));
      await settle(tester);
      expect(find.text('Omar'), findsOneWidget);
      expect(find.text('Student Profile'), findsOneWidget);
    });

    testWidgets('tapping yourself on someone\'s page goes to your own profile tab', (tester) async {
      await pumpPublic(tester, 't1');
      await tester.tap(key('stat-followers'));
      await settle(tester);
      await tester.tap(key('person-s1'));
      await settle(tester);
      expect(ownProfileTaps, ['s1']);
      expect(key('open-profile'), findsOneWidget, reason: 'the public page was closed');
    });
  });
}
