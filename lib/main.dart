  // lib/main.dart

  import 'package:flutter/material.dart';
  import 'dart:developer' as developer;
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'package:flutter/services.dart'; // Import for SystemChrome
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_app_check/firebase_app_check.dart';
  import 'package:flutter_dotenv/flutter_dotenv.dart';
  import 'package:calligro_app/screens/splash_screen.dart'; // Import SplashScreen
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
  import 'package:calligro_app/features/student/student_dashboard.dart';
  import 'package:calligro_app/features/teacher/teacher_dashboard.dart';
  import 'package:calligro_app/features/teacher/pages/add_course/add_course_dashboard.dart';
  import 'package:calligro_app/features/teacher/tabs/teacher_profile_tab.dart'; // Ensure this path is correct
  import 'package:calligro_app/features/student/pages/course_preview_page.dart';
  import 'package:calligro_app/features/community/pages/community_page.dart';
  import 'package:calligro_app/features/community/pages/single_post_page.dart';

  // --- ADMIN IMPORTS ---
  import 'package:calligro_app/features/admin/admin_dashboard.dart';
  import 'package:calligro_app/features/admin/pages/admin_users.dart';
  import 'package:calligro_app/features/admin/pages/admin_pending_teachers.dart';
  import 'package:calligro_app/core/services/deep_link_service.dart';
  import 'package:calligro_app/core/services/security_service.dart';
  import 'package:calligro_app/core/services/iap_service.dart';

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

    // 0. Lock Orientation
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // 1. Load Environment Variables
    await dotenv.load(fileName: ".env");

    // 2. Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // ✅ Initialize App Check (Debug Mode for local testing)
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.debug,
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

    // 💰 IAP Setup
    IAPService().initialize();
    IAPService().fetchProducts([
      'com.yazan.calligro.tier_50',
      'com.yazan.calligro.tier_60',
      'com.yazan.calligro.tier_70',
      'com.yazan.calligro.tier_80',
      'com.yazan.calligro.tier_90',
      'com.yazan.calligro.tier_100',
    ]);

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
      
      // Explicitly show local notification in foreground as Firebase sometimes suppresses it
      if (title != null || body != null) {
        flutterLocalNotificationsPlugin.show(
          id: message.hashCode,
          title: title,
          body: body,
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
      DeepLinkService().handleFcmData(message.data);
    });

    // 🔔 Handle taps when the app is completely closed (Terminated State)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("📩 App opened from notification (Terminated): ${initialMessage.notification?.title}");
      // Add a short delay to ensure the Navigator has mounted after runApp
      Future.delayed(const Duration(milliseconds: 800), () {
        DeepLinkService().handleFcmData(initialMessage.data);
      });
    }

    runApp(
      ChangeNotifierProvider(
        create: (context) => LocaleProvider(),
        child: Consumer<LocaleProvider>(
          builder: (context, provider, child) {
            return MaterialApp(
              navigatorKey: DeepLinkService().navigatorKey, // ✅ Navigation without context
              debugShowCheckedModeBanner: false,
              locale: provider.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('ar'), Locale('tr')],
              // ✅ Start with Splash Screen -> AuthWrapper -> Home/Onboarding
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
                // '/': (context) => const StudentDashboardPage(), // Removed to rely on AuthWrapper via Splash
                '/studentDashboard': (context) => const StudentDashboardPage(),
                '/teacherDashboard': (context) => const TeacherDashboardPage(),

                // --- ADMIN ---
                '/adminDashboard': (context) => const AdminDashboardPage(),
                '/adminUsers': (context) => AdminUsersPage(),
                '/adminPendingTeachers': (context) => AdminPendingTeachersPage(),

                // --- TEACHER FEATURES ---
                '/addCourse': (context) => const AddCourseDashboardPage(),

                // --- PROFILE ---
                '/ProfilePage': (context) => const TeacherProfileTab(
                  userName: "User",
                  userEmail: "",
                  userProfileImage: "",
                  courseCount: "0",
                  studentCount: "0",
                  earnings: "0",
                ),

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
              },
            );
          },
        ),
      ),
    );
  }
