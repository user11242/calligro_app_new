import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Courses Architectural Guardrails', () {
    final domainDir = Directory('lib/features/courses/domain');
    final applicationDir = Directory('lib/features/courses/application');
    final dataDir = Directory('lib/features/courses/data');

    test('domain layer is pure Dart: zero Flutter, Firebase, or In-App Purchase plugin imports', () {
      final domainFiles = domainDir.listSync(recursive: true).whereType<File>();
      for (final file in domainFiles) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        expect(
          content.contains("package:cloud_firestore"),
          isFalse,
          reason: '${file.path} must not import Cloud Firestore',
        );
        expect(
          content.contains("package:firebase_auth"),
          isFalse,
          reason: '${file.path} must not import Firebase Auth',
        );
        expect(
          content.contains("package:in_app_purchase"),
          isFalse,
          reason: '${file.path} must not import In-App Purchase plugin',
        );
        expect(
          content.contains("package:flutter/material.dart"),
          isFalse,
          reason: '${file.path} must not import Flutter Material',
        );
      }
    });

    test('application layer does not import Cloud Firestore or Flutter Material directly', () {
      final appFiles = applicationDir.listSync(recursive: true).whereType<File>();
      for (final file in appFiles) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        expect(
          content.contains("package:cloud_firestore"),
          isFalse,
          reason: '${file.path} must not import Cloud Firestore directly',
        );
        expect(
          content.contains("package:in_app_purchase/"),
          isFalse,
          reason: '${file.path} must not import In-App Purchase plugin directly (use StoreGateway)',
        );
      }
    });

    test('data layer does not depend on presentation', () {
      final dataFiles = dataDir.listSync(recursive: true).whereType<File>();
      for (final file in dataFiles) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        expect(
          content.contains("presentation/"),
          isFalse,
          reason: '${file.path} must not depend on presentation layer',
        );
      }
    });

    test('dead course_checkout_page.dart is not imported anywhere in lib', () {
      final libDir = Directory('lib');
      final allLibFiles = libDir.listSync(recursive: true).whereType<File>();
      for (final file in allLibFiles) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        expect(
          content.contains("course_checkout_page.dart"),
          isFalse,
          reason: '${file.path} imports dead course_checkout_page.dart',
        );
      }
    });

    Iterable<File> dartIn(String dir) =>
        Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

    test('presentation never talks to Firebase or the store directly (only through CourseScope)', () {
      for (final file in dartIn('lib/features/courses/presentation')) {
        if (file.path.endsWith('course_scope.dart')) continue; // the one composition root
        final content = file.readAsStringSync();
        for (final banned in ['FirebaseFirestore.instance', 'FirebaseAuth.instance', 'InAppPurchase.instance', 'FirebaseFunctions']) {
          expect(content.contains(banned), isFalse, reason: '${file.path} uses $banned');
        }
      }
    });

    test('one app-wide purchase flow: nothing else listens to the store', () {
      for (final file in dartIn('lib')) {
        if (file.path.contains('features/courses/data/')) continue;
        final content = file.readAsStringSync();
        expect(content.contains('purchaseStream'), isFalse, reason: '${file.path} listens to the store itself');
        expect(content.contains('completePurchase'), isFalse, reason: '${file.path} finishes purchases itself');
        expect(content.contains('IAPService'), isFalse, reason: '${file.path} still uses the old IAPService');
      }
      expect(File('lib/core/services/iap_service.dart').existsSync(), isFalse);
      // Only CoursePurchases is constructed in lib, and only in the scope.
      final makers = dartIn('lib').where((f) => !f.path.endsWith('course_purchases.dart')).where((f) => f.readAsStringSync().contains('CoursePurchases(')).map((f) => f.path).toList();
      expect(makers, ['lib/features/courses/presentation/course_scope.dart']);
    });

    test('tier products are consumable and finished only after the server (no auto-consume)', () {
      final store = File('lib/features/courses/data/store_gateways.dart').readAsStringSync();
      expect(store.contains('buyNonConsumable'), isFalse);
      expect(store.contains('autoConsume: false'), isTrue);
    });

    test('the data layer reads only real course fields (no invented isPublished / isFree filters)', () {
      for (final file in dartIn('lib/features/courses')) {
        final content = file.readAsStringSync();
        expect(content.contains("'isPublished'"), isFalse, reason: file.path);
        expect(content.contains("'isFree'"), isFalse, reason: file.path);
        expect(content.contains("'coursesCount'"), isFalse, reason: file.path);
      }
    });

    test('app product id matches the server (functions/purchases.js: tier_ + Math.trunc)', () {
      final server = File('functions/purchases.js').readAsStringSync();
      expect(server.contains('"com.yazan.calligro.tier_"'), isTrue);
      expect(server.contains(r'iapProductId || `${PRODUCT_PREFIX}${Math.trunc('), isTrue,
          reason: 'server rule changed — update CoursePolicy.productIdFor');
      final policy = File('lib/features/courses/domain/course_policy.dart').readAsStringSync();
      expect(policy.contains("productPrefix = 'com.yazan.calligro.tier_'"), isTrue);
      expect(policy.contains(r"c.iapProductId ?? '$productPrefix${c.price.truncate()}'"), isTrue);
    });

    test('the courses tests run in CI', () {
      final ci = Directory('.github/workflows').listSync().whereType<File>().map((f) => f.readAsStringSync()).join();
      expect(ci.contains('test/features/courses/'), isTrue);
    });
  });
}

