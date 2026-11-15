import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture guard rails for the Community feature.
///
///   presentation → application → domain ← data
///
/// They fail when a change breaks the layering (which is what keeps the
/// community testable), bypasses the tested rules, or lets other features go
/// around the community data layer.
void main() {
  const root = 'lib/features/community';

  Map<String, String> sources(String dir) => {
        for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
      };

  final domain = sources('$root/domain');
  final application = sources('$root/application');
  final data = sources('$root/data');
  final presentation = sources('$root/presentation');

  void expectNone(Map<String, String> files, Pattern pattern, String why, {Set<String> allow = const {}}) {
    for (final entry in files.entries) {
      if (allow.any(entry.key.endsWith)) continue;
      expect(entry.value.contains(pattern), isFalse, reason: '${entry.key}: $why');
    }
  }

  group('Layering', () {
    test('only the four layers exist (the old services/, pages/, widgets/ are gone)', () {
      final top = Directory(root).listSync().whereType<Directory>().map((e) => e.path.split('/').last).toSet();
      expect(top, {'domain', 'application', 'data', 'presentation'});
      for (final layer in [domain, application, data, presentation]) {
        expect(layer, isNotEmpty);
      }
    });

    test('domain is pure Dart: no Flutter, Firebase or other layers', () {
      expectNone(domain, 'package:flutter/', 'domain must not depend on Flutter');
      expectNone(domain, 'firebase', 'domain must not depend on Firebase');
      expectNone(domain, 'cloud_firestore', 'domain must not depend on Firestore');
      for (final layer in ['/application/', '/data/', '/presentation/']) {
        expectNone(domain, layer, 'domain must not depend on $layer');
      }
    });

    test('application uses only domain interfaces (no Firebase, widgets, data or UI)', () {
      expectNone(application, 'cloud_firestore', 'use CommunityRepository');
      expectNone(application, 'firebase_auth', 'use CommunitySessionSource');
      expectNone(application, 'firebase_storage', 'use CommunityMediaStorage');
      expectNone(application, 'package:flutter/material.dart', 'no widgets in the application layer');
      expectNone(application, 'package:flutter/widgets.dart', 'no widgets in the application layer');
      expectNone(application, '/data/', 'application must not depend on data');
      expectNone(application, '/presentation/', 'application must not depend on presentation');
    });

    test('data does not depend on application or presentation', () {
      expectNone(data, '/application/', 'data must not depend on application');
      expectNone(data, '/presentation/', 'data must not depend on presentation');
    });

    test('the UI never touches Firebase; only CommunityScope picks the real implementations', () {
      expectNone(presentation, 'cloud_firestore', 'use the controllers / CommunityRepository',
          allow: {'community_scope.dart'});
      expectNone(presentation, 'firebase_auth', 'use CommunitySessionSource', allow: {'community_scope.dart'});
      expectNone(presentation, 'firebase_storage', 'use CommunityMediaStorage');
      expectNone(presentation, '/data/', 'only community_scope.dart wires the data layer',
          allow: {'community_scope.dart'});
      expectNone(presentation, 'FirebaseFirestore.instance', 'no direct Firestore access in the UI');
    });

    test('screens and widgets do not write to repositories directly (controllers do)', () {
      final writes = RegExp(r'\.(repository|follows)\.(create|update|delete|set|add|edit|report|block|unblock)\w*\(');
      for (final e in presentation.entries) {
        expect(writes.hasMatch(e.value), isFalse, reason: '${e.key}: go through a controller');
      }
    });
  });

  group('Rules live in CommunityPolicy', () {
    test('the 5-image limit is not hard-coded anywhere else', () {
      final outside = {...application, ...data, ...presentation};
      expectNone(outside, RegExp(r'max\w*\s*=\s*5\b'), 'use CommunityPolicy.maxImagesPerPost');
      expectNone(outside, RegExp(r'(length|Count)\s*[<>]=?\s*5\b'), 'use CommunityPolicy.maxImagesPerPost');
    });

    test('role checks for menus / permissions go through the controllers', () {
      expectNone(presentation, "role == 'admin'", 'use CommunityPolicy (via the controller can* getters)');
      expectNone(presentation, ".isAdmin", 'use CommunityPolicy (via the controller can* getters)');
    });
  });

  group('Other features use the community through its public API', () {
    final outside = {
      for (final e in sources('lib').entries)
        if (!e.key.startsWith(root)) e.key: e.value,
    };

    test('no old community services or paths are imported anywhere', () {
      expectNone(outside, 'community/services/', 'the old services were removed');
      expectNone(outside, "community/pages/", 'moved to community/presentation/pages');
      expectNone(outside, "community/widgets/", 'moved to community/presentation/widgets');
    });

    test('only the admin service uses the community data layer (to delete posts like the author does)', () {
      expectNone(outside, 'features/community/data/', 'use community presentation widgets / CommunityScope',
          allow: {'admin/data/services/admin_service.dart'});
    });

    test('nobody outside the community data layer writes posts, likes or comments', () {
      final writes = RegExp(
          r"collection\('community_posts'\)(?:(?!;).)*\.(add|set|update|delete)\(",
          dotAll: true);
      for (final e in outside.entries) {
        // The profile-sync batches in the teacher profile pages update name/photo only (allowed by firestore.rules).
        if (e.key.endsWith('edit_profile_page.dart') || e.key.endsWith('teacher_setup_page.dart')) continue;
        expect(writes.hasMatch(e.value), isFalse, reason: '${e.key}: write through FirestoreCommunityRepository');
      }
    });
  });

  group('Server rules match the data layer', () {
    final rules = File('firestore.rules').readAsStringSync();
    final storage = File('storage.rules').readAsStringSync();

    test('the collections the data layer uses are the ones the rules protect', () {
      final repo = data.entries.firstWhere((e) => e.key.endsWith('firestore_community_repository.dart')).value;
      for (final collection in ['community_posts', 'comments', 'replies', 'saved_posts', 'reports']) {
        expect(repo, contains("'$collection'"), reason: 'data layer uses $collection');
        expect(rules, contains('/$collection/'), reason: 'firestore.rules must protect $collection');
      }
      expect(storage, contains('match /community_posts/{userId}/'), reason: 'post images are protected');
    });

    test('storage has no catch-all write (it would re-open every folder)', () {
      final catchAll = RegExp(r'match /\{allPaths=\*\*\} \{[^}]*allow write', dotAll: true);
      expect(catchAll.hasMatch(storage), isFalse);
    });

    test('the like rule checks the liker, not just the counter', () {
      expect(rules, contains('isMyLikeToggle()'));
    });
  });
}
