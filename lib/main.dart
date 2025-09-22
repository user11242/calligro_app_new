import 'package:calligro_app/features/admin/admin_dashboard.dart';
import 'package:calligro_app/features/admin/pages/admin_pending_teachers.dart';
import 'package:calligro_app/features/admin/pages/admin_users.dart';
import 'package:calligro_app/features/auth/pages/forgot_password_page.dart';
import 'package:calligro_app/features/auth/pages/register_page.dart';
import 'package:calligro_app/features/student/pages/home_page.dart';
import 'package:calligro_app/features/auth/pages/login_page.dart';
import 'package:calligro_app/features/student/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/features/teacher/teacher_dashboard.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ dotenv
import 'package:calligro_app/features/teacher/pages/add_course/add_course_dashboard.dart';

// 🔔 Background message handler (must be top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 Background message received: ${message.notification?.title}");
}

Future<void> _saveTokenToFirestore(String token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final userDoc =
        await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
    final role = userDoc.data()?['role'];

    // ✅ Save token only for admins
    if (role == "admin") {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
        "fcmToken": token,
      });
      debugPrint("✅ FCM Token saved for ADMIN: ${user.uid}");
    } else {
      debugPrint("⚠️ Not an admin, token not saved for user: ${user.uid}");
    }
  } else {
    debugPrint("⚠️ No logged-in user, token not saved");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Load env before Firebase
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();

  // ✅ Enable phone auth debug logging (helpful for OTP issues)
  FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: false);

  // 🔔 Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 🔔 Request notification permissions (iOS + Android 13+)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  debugPrint("📌 User granted permission: ${settings.authorizationStatus}");

  // 🔔 Get the current FCM token
  String? token = await messaging.getToken();
  if (token != null) {
    debugPrint("📌 Initial FCM Token: $token");
    await _saveTokenToFirestore(token);
  }

  // 🔄 Automatically update token on refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint("🔄 FCM Token refreshed: $newToken");
    await _saveTokenToFirestore(newToken);
  });

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: "/LoginPage",
    routes: {
      '/': (context) => HomePage(),
      '/LoginPage': (context) => LoginPage(),
      '/RegisterPage': (context) => RegisterPage(),
      '/ProfilePage': (context) => ProfilePage(),
      '/forgotPassword': (context) => ForgotPasswordPage(),
      '/adminDashboard': (context) => AdminDashboardPage(),
      '/adminUsers': (context) => AdminUsersPage(),
      '/adminPendingTeachers': (context) => AdminPendingTeachersPage(),
      '/teacherDashboard':(context) => TeacherDashboardPage(),
      '/addCourse':(context) => AddCourseDashboardPage(),
    },
  ));

  // 🔔 Foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("📩 Foreground message: ${message.notification?.title}");
  });

  // 🔔 App opened via notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("📩 App opened from notification: ${message.notification?.title}");
  });
}
