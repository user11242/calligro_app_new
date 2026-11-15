import 'package:calligro_app/features/community/domain/models/community_models.dart';
import 'package:calligro_app/features/community/presentation/community_scope.dart';
import 'package:calligro_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:calligro_app/features/profile/presentation/profile_scope.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../community/fakes/fake_community.dart';
import '../../community/presentation/community_harness.dart' show settle, drainMessages;
import '../fakes/fake_profile.dart';

/// The REAL edit-profile page on fakes.
void main() {
  late FakeProfileEditor editor;
  late FakePhotoUploader photos;
  String? nextPick;
  final verified = <String>[];
  var verifyAnswer = true;
  final popped = <Object?>[];

  Finder key(String k) => find.byKey(Key(k));
  Finder nameField() => find.descendant(of: key('edit-name'), matching: find.byType(TextField));
  Finder bioField() => find.descendant(of: key('edit-bio'), matching: find.byType(TextField));

  Future<void> open(WidgetTester tester) async {
    final profile = ProfileServices(
      profiles: FakeProfileStore(),
      counts: FakeProfileStore(),
      followLists: FakeProfileStore(),
      courses: FakeProfileStore(),
      reviews: FakeProfileStore(),
      viewer: FakeViewerSource(teacherViewer),
      editor: editor,
      photos: photos,
      phones: FakePhoneChecker(),
      pickPhoto: () async => nextPick,
    );
    final community = CommunityServices(
      repository: FakeCommunityRepository(),
      follows: FakeFollowRepository(),
      users: FakeUserRepository(),
      sessions: FakeSessionSource(const CommunitySession(userId: 't1', role: 'teacher')),
      media: FakeMediaStorage(),
      translator: FakeTranslator(),
      imagePicker: (_) => FakeImagePicker(),
    );
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) =>
          CommunityScope(services: community, child: ProfileScope(services: profile, child: child!)),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open-edit'),
            onPressed: () async => popped.add(await Navigator.push<Object?>(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(verifyPhone: (_, phone) async {
                  verified.add(phone);
                  return verifyAnswer;
                }),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(key('open-edit'));
    await settle(tester);
  }

  setUp(() {
    editor = FakeProfileEditor()..profiles['t1'] = editableAli;
    photos = FakePhotoUploader();
    nextPick = null;
    verified.clear();
    verifyAnswer = true;
    popped.clear();
  });

  testWidgets('shows the current name, bio and (read-only) email', (tester) async {
    await open(tester);
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Ali Hassan');
    expect(tester.widget<TextField>(bioField()).controller!.text, 'Teacher');
    expect(find.text('t1@x.com'), findsOneWidget);
  });

  testWidgets('rename + bio, then save → saved and the page closes with true', (tester) async {
    await open(tester);
    await tester.enterText(nameField(), 'Omar Farouk');
    await tester.enterText(bioField(), 'Calligraphy teacher');
    await tester.pump(const Duration(milliseconds: 700)); // availability check
    await tester.tap(key('save-profile'));
    await settle(tester);
    final (_, draft, photo) = editor.saves.single;
    expect(draft.name, 'Omar Farouk');
    expect(draft.bio, 'Calligraphy teacher');
    expect(photo, 'old.jpg');
    expect(popped, [true]);
    expect(verified, isEmpty, reason: 'phone unchanged → no SMS');
  });

  testWidgets('a taken name shows the error and blocks saving', (tester) async {
    editor.takenNames.add('omar');
    await open(tester);
    await tester.enterText(nameField(), 'Omar');
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.text('Username is already taken.'), findsWidgets);
    await tester.tap(key('save-profile'));
    await settle(tester);
    expect(editor.saves, isEmpty);
  });

  testWidgets('an invalid name is shown immediately', (tester) async {
    await open(tester);
    await tester.enterText(nameField(), 'Al');
    await settle(tester);
    expect(editor.nameChecks, isEmpty);
    await tester.tap(key('save-profile'));
    await settle(tester);
    expect(editor.saves, isEmpty);
  });

  testWidgets('no changes → info message, nothing written, page stays', (tester) async {
    await open(tester);
    await tester.tap(key('save-profile'));
    await settle(tester);
    expect(editor.saves, isEmpty);
    expect(popped, isEmpty);
    await drainMessages(tester);
  });

  testWidgets('a picked photo is uploaded and saved', (tester) async {
    nextPick = '/tmp/new.jpg';
    await open(tester);
    await tester.tap(key('pick-photo'));
    await settle(tester);
    await tester.tap(key('save-profile'));
    await settle(tester);
    expect(photos.uploads, ['/tmp/new.jpg']);
    expect(editor.saves.single.$3, 'https://cdn/t1/new.jpg');
  });

  testWidgets('a failed save shows an error and keeps the page open', (tester) async {
    editor.failSave = true;
    await open(tester);
    await tester.enterText(bioField(), 'changed');
    await tester.tap(key('save-profile'));
    await settle(tester);
    expect(popped, isEmpty);
    expect(find.text('Failed to save changes. Please try again.'), findsWidgets);
    await drainMessages(tester);
  });
}
