import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Community Architectural Guardrails', () {
    test('domain layer is pure Dart (no Flutter, Firebase or Storage imports)', () {
      final domainDir = Directory('lib/features/community/domain');
      expect(domainDir.existsSync(), isTrue);

      final files = domainDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          content.contains("package:flutter/"),
          isFalse,
          reason: '${file.path} must not import Flutter',
        );
        expect(
          content.contains("package:cloud_firestore/"),
          isFalse,
          reason: '${file.path} must not import Cloud Firestore',
        );
        expect(
          content.contains("package:firebase_storage/"),
          isFalse,
          reason: '${file.path} must not import Firebase Storage',
        );
        expect(
          content.contains("package:firebase_auth/"),
          isFalse,
          reason: '${file.path} must not import Firebase Auth',
        );
      }
    });

    test('application layer does not import Cloud Firestore or Flutter widgets directly', () {
      final appDir = Directory('lib/features/community/application');
      expect(appDir.existsSync(), isTrue);

      final files = appDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          content.contains("package:cloud_firestore/"),
          isFalse,
          reason: '${file.path} must not import Cloud Firestore directly',
        );
        expect(
          content.contains("package:firebase_storage/"),
          isFalse,
          reason: '${file.path} must not import Firebase Storage directly',
        );
      }
    });

    test('data layer does not depend on presentation', () {
      final dataDir = Directory('lib/features/community/data');
      expect(dataDir.existsSync(), isTrue);

      final files = dataDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          content.contains("presentation/"),
          isFalse,
          reason: '${file.path} must not import presentation',
        );
      }
    });
  });
}

