import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calligro_app/features/auth/data/services/fcm_service.dart';

import 'fcm_service_test.mocks.dart';

@GenerateMocks([FirebaseMessaging])
void main() {
  group('Layer 2: FcmService Tests (Coverage)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseMessaging mockMessaging;
    late FcmService fcmService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockMessaging = MockFirebaseMessaging();
      
      fcmService = FcmService.forTest(
        firestore: fakeFirestore,
        messaging: mockMessaging,
      );
      
      SharedPreferences.setMockInitialValues({'selected_language_code': 'fr'});
    });

    test('saveUserFcmToken() updates firestore if permitted', () async {
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
      )).thenAnswer((_) async => const NotificationSettings(
            authorizationStatus: AuthorizationStatus.authorized,
            alert: AppleNotificationSetting.enabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.enabled,
            carPlay: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            sound: AppleNotificationSetting.enabled,
            timeSensitive: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.disabled,
            notificationCenter: AppleNotificationSetting.disabled,
            showPreviews: AppleShowPreviewSetting.always,
            providesAppNotificationSettings: AppleNotificationSetting.enabled,
          ));
          
      when(mockMessaging.getToken()).thenAnswer((_) async => 'fake_token');

      await fcmService.saveUserFcmToken('u1');

      final userDoc = await fakeFirestore.collection('users').doc('u1').get();
      expect(userDoc.data()?['fcmToken'], 'fake_token');
      expect(userDoc.data()?['preferredLanguage'], 'fr');
    });

    test('saveUserFcmToken() returns early if denied', () async {
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
      )).thenAnswer((_) async => const NotificationSettings(
            authorizationStatus: AuthorizationStatus.denied,
            alert: AppleNotificationSetting.disabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.disabled,
            carPlay: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            sound: AppleNotificationSetting.disabled,
            timeSensitive: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.disabled,
            notificationCenter: AppleNotificationSetting.disabled,
            showPreviews: AppleShowPreviewSetting.never,
            providesAppNotificationSettings: AppleNotificationSetting.disabled,
          ));

      await fcmService.saveUserFcmToken('u1');

      final userDoc = await fakeFirestore.collection('users').doc('u1').get();
      expect(userDoc.exists, false);
    });

    // THE BUG: the time zone was never saved on this (the main) path, so moved-class
    // notifications fell back to the course's time zone, labelled "(UTC+3)".
    test('the phone\'s time zone is saved on every start, even when notifications are denied', () async {
      await fakeFirestore.collection('users').doc('u2').set({'role': 'student'});
      when(mockMessaging.requestPermission(
        alert: anyNamed('alert'),
        badge: anyNamed('badge'),
        sound: anyNamed('sound'),
      )).thenAnswer((_) async => const NotificationSettings(
            authorizationStatus: AuthorizationStatus.denied,
            alert: AppleNotificationSetting.disabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.disabled,
            carPlay: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            sound: AppleNotificationSetting.disabled,
            timeSensitive: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.disabled,
            notificationCenter: AppleNotificationSetting.disabled,
            showPreviews: AppleShowPreviewSetting.never,
            providesAppNotificationSettings: AppleNotificationSetting.disabled,
          ));
      await fcmService.saveUserFcmToken('u2');
      final data = (await fakeFirestore.collection('users').doc('u2').get()).data()!;
      expect(data['utcOffsetMinutes'], DateTime.now().timeZoneOffset.inMinutes);
    });

    test('saveTimeZone: an explicit offset is stored; no profile → nothing is created', () async {
      await fakeFirestore.collection('users').doc('u3').set({'role': 'student'});
      await fcmService.saveTimeZone('u3', offset: const Duration(hours: 3));
      expect((await fakeFirestore.collection('users').doc('u3').get()).data()!['utcOffsetMinutes'], 180);
      await fcmService.saveTimeZone('nobody', offset: const Duration(hours: 3));
      expect((await fakeFirestore.collection('users').doc('nobody').get()).exists, isFalse);
    });
  });
}
