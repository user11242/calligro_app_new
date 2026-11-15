import 'package:calligro_app/features/community/application/saved_posts_store.dart';
import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/community_scope.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_community.dart';

/// The REAL community screens running on in-memory fakes.
/// The scope sits above the Navigator, so pushed pages and sheets see the fakes too.
class CommunityHarness {
  CommunityHarness({CommunitySession session = studentSession}) : sessions = FakeSessionSource(session);

  final repo = FakeCommunityRepository();
  final follows = FakeFollowRepository();
  final users = FakeUserRepository();
  final media = FakeMediaStorage();
  final picker = FakeImagePicker();
  final translator = FakeTranslator();
  final FakeSessionSource sessions;

  /// Set by [pump]: the last route popped with a result (e.g. editor → true).
  final popped = <Object?>[];

  CommunitySession get session => sessions.session;

  late final CommunityServices services = CommunityServices(
    repository: repo,
    follows: follows,
    users: users,
    sessions: sessions,
    media: media,
    translator: translator,
    imagePicker: (_) => picker,
  );

  SavedPostsStore savedStore() => SavedPostsStore(repository: repo, userId: session.userId)..start();

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => CommunityScope(services: services, child: child!),
      routes: {'/LoginPage': (_) => const Scaffold(body: Text('LOGIN PAGE'))},
      home: screen,
    ));
    await settle(tester);
  }

  /// Opens [page] on top of a launcher so its `Navigator.pop(result)` can be observed.
  Future<void> pumpPushed(WidgetTester tester, Widget page) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () async =>
                  popped.add(await Navigator.push<Object?>(context, MaterialPageRoute(builder: (_) => page))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
  }
}

/// Lets streams, futures and short animations finish (pumpAndSettle would spin on progress indicators).
Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the auto-dismissing success/error banners time out so no timer is left pending.
Future<void> drainMessages(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await settle(tester);
}

/// The sign-in prompt guests get (GuestGuard).
Finder get signInPrompt => find.byIcon(Icons.lock_outline);
