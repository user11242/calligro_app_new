  // lib/main.dart

  import 'package:calligro_app/features/notifications/presentation/notification_services.dart';
import 'package:calligro_app/features/profile/presentation/pages/my_profile_tab.dart';
import 'package:flutter/material.dart';
  import 'package:flutter/foundation.dart';
  import 'dart:convert';
  import 'dart:developer' as developer;
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'package:flutter/services.dart'; // Import for SystemChrome
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_app_check/firebase_app_check.dart';
  import 'dart:ui'; // Import for PlatformDispatcher
  import 'package:calligro_app/screens/splash_screen.dart'; // Import SplashScreen
  import 'package:firebase_crashlytics/firebase_crashlytics.dart';
  import 'package:media_kit/media_kit.dart';
  // --- YOUR FILES ---
  import 'package:calligro_app/firebase_options.dart';
  import 'package:calligro_app/features/auth/data/services/google_auth_service.dart';
  import 'package:flutter_local_notifications/flutter_local_notifications.dart';

  import 'package:flutter_localizations/flutter_localizations.dart';
  import 'package:provider/provider.dart';
  import 'package:calligro_app/l10n/app_localizations.dart';
  import 'package:timeago/timeago.dart' as timeago;
  import 'core/localization/locale_provider.dart';

  import 'package:calligro_app/features/auth/pages/login_page.dart';
  import 'package:calligro_app/features/auth/pages/register_page.dart';
  import 'package:calligro_app/features/auth/pages/forgot_password_page.dart';
  import 'package:calligro_app/screens/auth_wrapper.dart';
  import 'package:calligro_app/screens/on_boarding_page.dart';
  import 'package:calligro_app/features/student/presentation/student_dashboard.dart';
  import 'package:calligro_app/features/teacher/presentation/teacher_dashboard.dart';
  import 'package:calligro_app/features/courses/presentation/create/add_course_dashboard.dart';
  import 'package:calligro_app/features/courses/presentation/pages/course_preview_page.dart';
  import 'package:calligro_app/features/community/presentation/pages/community_page.dart';
  import 'package:calligro_app/features/community/presentation/pages/single_post_page.dart';
  import 'package:calligro_app/features/classroom/presentation/chat/course_chat_page.dart';

  // --- ADMIN IMPORTS ---
  import 'package:calligro_app/features/admin/presentation/admin_dashboard.dart';
  import 'package:calligro_app/features/admin/presentation/pages/admin_users.dart';
  import 'package:calligro_app/features/admin/presentation/pages/admin_pending_teachers.dart';
  import 'package:calligro_app/core/services/deep_link_service.dart';
  import 'package:calligro_app/core/services/security_service.dart';
  import 'package:calligro_app/features/courses/presentation/course_scope.dart';

  // 🔔 Local Notifications setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'calligro_alerts', // id
    'Calligro Alerts', // title
    description: 'Important notifications for Calligro users', // description
    importance: Importance.high,
  );

  // 🔔 Background message handler
  @pragma('vm:entry-point')
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    developer.log("📩🔥 Background Isolate Woken Up!", name: "FCM_BG");
    developer.log("Raw Message Data: ${message.data}", name: "FCM_BG");
    developer.log("Raw Message Notification: ${message.notification?.toMap()}", name: "FCM_BG");


    // If the message contains a notification object, FCM handles it automatically in the tray
    // when the app is in background/terminated. Manual display would cause a duplicate.
    if (message.notification != null) {
      developer.log("FCM OS notification present. Skipping manual display in background.", name: "FCM_BG");
      return;
    }

    final String? title = message.notification?.title ?? message.data['title'];
    final String? body = message.notification?.body ?? message.data['body'];

    developer.log("Extracted Title: $title", name: "FCM_BG");
    developer.log("Extracted Body: $body", name: "FCM_BG");

    if (title != null || body != null) {
      try {
        developer.log("Attempting to initialize local notifications plugin...", name: "FCM_BG");
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      
        await flutterLocalNotificationsPlugin.initialize(
          settings: initializationSettings,
        );

        developer.log("Plugin initialized. Attempting to show notification...", name: "FCM_BG");

        flutterLocalNotificationsPlugin.show(
          id: message.hashCode,
          title: title,
          body: body,
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/launcher_icon',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        developer.log("✅ Successfully commanded OS to show Heads-Up Notification!", name: "FCM_BG");
      } catch (e, stacktrace) {
        developer.log("❌ ERROR in background isolate: $e", name: "FCM_BG", error: e, stackTrace: stacktrace);
      }
    } else {
      developer.log("⚠️ No title or body found. Skipping local UI.", name: "FCM_BG");
    }
  }

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();

    // 0. Lock Orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // (No .env in the app any more: it bundled Twilio/Postmark/Brevo keys that
    // anyone could unpack. Email codes are sent by the server.)

    // 2. Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // 🧪 TESTING MODE: Set to true ONLY when you want to use the local sandbox
    // NEVER push this as 'true' to the App Store!
    bool useFirebaseEmulator = false; 
    
    if (useFirebaseEmulator) {
      try {
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        developer.log("🔥 Connected to Firebase Emulators Sandbox!");
      } catch (e) {
        developer.log("🔥 Error connecting to emulators: $e");
      }
    }

    // ✅ Setup Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // ✅ Initialize App Check (Debug Mode for local testing)
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );

    // 3. Initialize Google Auth Service
    await GoogleAuthService.instance.initialize();

    // 4. Enable Edge-to-Edge Navigation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: false);

    // 🌍 Deep Linking Setup
    DeepLinkService().init();

    // 🛡️ Security Setup (Screenshot Protection)
    await SecurityService().init();

    // 💰 Course purchases: ONE app-wide flow, started at launch so purchases the
    // store re-delivers (after a crash / failed verification) are enrolled.
    CourseServices.appPurchases();

    // 🌍 Register timeago locales
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    timeago.setLocaleMessages('tr_short', timeago.TrShortMessages());

    // 🔔 Local Notifications setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false, // Firebase already handles iOS permissions & foreground rendering natively
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    try {
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) {
              NotificationServices.instance.opener.openData(decoded);
            }
          } catch (e) {
            developer.log("Failed to parse notification payload: $e");
          }
        },
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      developer.log("Failed to initialize local notifications: $e");
    }

    // 🔔 Notifications Setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 🔔 Enable foreground heads-up notifications (crucial for iOS and some Android)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, 
      badge: true, 
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final String? title = message.notification?.title ?? message.data['title'];
      final String? body = message.notification?.body ?? message.data['body'];
      
      debugPrint("📩 Foreground message: $title");
      
      // Android shows nothing for a push while the app is open, so we show it.
      // iOS already shows it (setForegroundNotificationPresentationOptions):
      // showing it here too was the second copy.
      if ((title != null || body != null) && defaultTargetPlatform == TargetPlatform.android) {
        flutterLocalNotificationsPlugin.show(
          id: message.hashCode,
          title: title,
          body: body,
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/launcher_icon',
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📩 App opened from notification (Background): ${message.notification?.title}");
      NotificationServices.instance.opener.openData(message.data);
    });

    // 🔔 Handle taps when the app is completely closed (Terminated State)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("📩 App opened from notification (Terminated): ${initialMessage.notification?.title}");
      // Kept until a dashboard is on screen (NotificationTapHandler), not a fixed delay.
      NotificationServices.instance.opener.openData(initialMessage.data);
    }

    // The app was launched by tapping a notification WE showed (Android, foreground copy).
    try {
      final launch = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null && payload.isNotEmpty) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) NotificationServices.instance.opener.openData(decoded);
      }
    } catch (e) {
      developer.log("Failed to read notification launch details: $e");
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => LocaleProvider(),
        child: const CalligroApp(),
      ),
    );
  }

// ─────────────────────────────────────────────────────────────────────────────
// CalligroApp — Stable root widget
// Uses Selector (not Consumer) so that locale changes update ONLY the locale
// property of MaterialApp. The MaterialApp widget itself is NEVER recreated,
// which means the Navigator and every route on the stack remain intact even
// when LocaleProvider.notifyListeners() fires (e.g. on startup from
// _loadLocale(), or when the user changes language in settings).
// ─────────────────────────────────────────────────────────────────────────────
class CalligroApp extends StatelessWidget {
  const CalligroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LocaleProvider, Locale?>(
      selector: (_, provider) => provider.locale,
      builder: (context, locale, child) {
        return MaterialApp(
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.black,
            canvasColor: Colors.black,
          ),
          navigatorKey: DeepLinkService().navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/': (context) => const AuthWrapper(),
            // --- AUTH ---
            '/onBoarding': (context) => const OnboardingPage(),
            '/LoginPage': (context) => const LoginPage(),
            '/RegisterPage': (context) => const RegisterPage(),
            '/forgotPassword': (context) => const ForgotPasswordPage(),
            // --- DASHBOARDS ---
            '/studentDashboard': (context) => const StudentDashboardPage(),
            '/teacherDashboard': (context) => const TeacherDashboardPage(),
            // --- ADMIN ---
            '/adminDashboard': (context) => const AdminDashboardPage(),
            '/adminUsers': (context) => AdminUsersPage(),
            '/adminPendingTeachers': (context) => AdminPendingTeachersPage(),
            // --- TEACHER FEATURES ---
            '/addCourse': (context) => const AddCourseDashboardPage(),
            // --- PROFILE ---
            '/ProfilePage': (context) => const MyProfileTab(),
            // --- COMMUNITY ---
            '/community': (context) => CommunityPage(
              onProfileTap: (userId, userRole) {
                Navigator.of(context).pushNamed('/ProfilePage');
              },
            ),
            // --- COURSE ---
            '/coursePreview': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
              return CoursePreviewPage(
                courseId: args['courseId'],
                courseData: args['courseData'],
              );
            },
            '/postDetails': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
              return SinglePostPage(postId: args['postId']);
            },
            '/courseChat': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
              final teacherId = args['teacherId']?.toString() ?? '';
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final rawName = args['courseName']?.toString() ?? '';
              return CourseChatPage(
                courseId: args['courseId'].toString(),
                courseName: rawName.isNotEmpty
                    ? rawName
                    : AppLocalizations.of(context)!.courseGroupChat,
                courseTeacherId: teacherId.isNotEmpty ? teacherId : null,
                isTeacher: currentUid != null && currentUid == teacherId,
              );
            },
          },
        );
      },
    );
  }
}
