import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture guard rails for the Profile feature.
///
///   presentation → application → domain ← data
void main() {
  const root = 'lib/features/profile';

  Map<String, String> sources(String dir) => {
        for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
      };

  final domain = sources('$root/domain');
  final application = sources('$root/application');
  final data = sources('$root/data');
  final presentation = sources('$root/presentation');
  final outside = {
    for (final e in sources('lib').entries)
      if (!e.key.startsWith(root)) e.key: e.value,
  };

  void expectNone(Map<String, String> files, Pattern pattern, String why, {Set<String> allow = const {}}) {
    for (final entry in files.entries) {
      if (allow.any(entry.key.endsWith)) continue;
      expect(entry.value.contains(pattern), isFalse, reason: '${entry.key}: $why');
    }
  }

  group('Layering', () {
    test('only the four layers exist', () {
      final top = Directory(root).listSync().whereType<Directory>().map((e) => e.path.split('/').last).toSet();
      expect(top, {'domain', 'application', 'data', 'presentation'});
    });

    test('domain is pure Dart', () {
      expectNone(domain, 'package:flutter/', 'domain must not depend on Flutter');
      expectNone(domain, 'firebase', 'domain must not depend on Firebase');
      expectNone(domain, 'cloud_firestore', 'domain must not depend on Firestore');
      for (final layer in ['/application/', '/data/', '/presentation/']) {
        expectNone(domain, layer, 'domain must not depend on $layer');
      }
    });

    test('application uses only domain interfaces', () {
      expectNone(application, 'cloud_firestore', 'use the repositories');
      expectNone(application, 'firebase_auth', 'use ProfileViewerSource');
      expectNone(application, 'package:flutter/material.dart', 'no widgets in the application layer');
      expectNone(application, '/data/', 'application must not depend on data');
      expectNone(application, '/presentation/', 'application must not depend on presentation');
    });

    test('data does not depend on application or presentation', () {
      expectNone(data, '/application/', 'data must not depend on application');
      expectNone(data, '/presentation/', 'data must not depend on presentation');
    });

    test('the UI never touches Firebase; only ProfileScope picks implementations', () {
      expectNone(presentation, 'FirebaseFirestore.instance', 'no direct Firestore in the UI');
      expectNone(presentation, 'FirebaseAuth.instance', 'use ProfileViewerSource');
      expectNone(presentation, ".collection('", 'no queries in the UI');
      expectNone(presentation, '/data/', 'only profile_scope.dart wires the data layer', allow: {'profile_scope.dart'});
    });
  });

  group('Rules live in ProfilePolicy', () {
    test('the UI does not decide who sees what by comparing ids or roles itself', () {
      expectNone(presentation, "role == 'teacher'", 'use ProfilePolicy / the controller');
      expectNone(presentation, "role == 'admin'", 'use ProfilePolicy / the controller');
      expectNone(presentation, '== c.viewer.userId', 'use ProfilePolicy.isOwn');
    });

    test('commission and email are only shown through the controller\'s owner-only flags', () {
      final header = presentation.entries.firstWhere((e) => e.key.endsWith('profile_header.dart')).value;
      expect(header, contains('if (c.showCommission)'));
      expect(header, contains('if (c.showEmail'));
    });

    test('the phone number never leaves the data layer (only the flag does)', () {
      expectNone({...domain, ...application, ...presentation}, 'phone', 'only countryFlag is exposed');
    });
  });

  group('The old profile screens are gone', () {
    test('no file or import of the old per-role screens remains', () {
      for (final old in [
        'student_profile_tab.dart',
        'teacher_profile_tab.dart',
        'admin_profile_tab.dart',
        'public_student_profile_page.dart',
        'public_teacher_profile_page.dart',
        'follow_list_bottom_sheet.dart',
      ]) {
        expectNone(outside, old, 'use MyProfileTab / PublicProfilePage');
      }
    });

    test('other features open profiles through ProfileNavigation or PublicProfilePage', () {
      expectNone(outside, 'PublicTeacherProfilePage', 'use PublicProfilePage');
      expectNone(outside, 'PublicStudentProfilePage', 'use PublicProfilePage');
    });
  });
}
