import 'course_draft.dart';
import 'course_models.dart';

/// Reading courses. Every query works on real course documents with the
/// indexes the project has (no invented fields, no composite indexes).
abstract interface class CourseRepository {
  Stream<Course?> watchCourse(String courseId);

  /// The catalogue, newest first (courses without createdAt last).
  Stream<List<Course>> watchCatalog();

  /// Courses [uid] is enrolled in, newest first.
  Stream<List<Course>> watchEnrolled(String uid);

  /// Courses [teacherId] teaches (teacher's own tabs), newest first, live.
  Stream<List<Course>> watchTeaching(String teacherId);

  /// Newest courses (home page "explore").
  Stream<List<Course>> watchLatest({int limit = 10});

  /// Read once per teacher and cached.
  Future<CourseTeacherSummary?> teacherSummary(String teacherId);
}

/// Creating courses (teachers). Kept apart from reading: students never need it.
abstract interface class CourseAuthoring {
  /// The teacher as the course document needs them, read fresh from the
  /// server (payout details may have just been saved). null = no such user.
  Future<CourseAuthor?> author(String uid);

  /// Writes the public course document AND its private meeting settings in
  /// one atomic batch (never a course without its classroom password).
  /// Returns the new course id.
  Future<String> create(
    CourseDraft draft,
    CourseAuthor author, {
    String generatedName = '',
    String meetLink = '',
    String classroomPassword = '',
  });
}

/// A completed store charge waiting for server verification.
class StorePurchase {
  final String productId;

  /// Apple: the receipt; Android: the purchase token.
  final String verificationData;
  final String? transactionId;

  /// The plugin's own object, needed to finish / consume the purchase.
  final Object? native;

  const StorePurchase({required this.productId, required this.verificationData, this.transactionId, this.native});
}

enum StoreEventKind { purchased, cancelled, failed, pending }

class StoreEvent {
  final StoreEventKind kind;
  final String productId;
  final StorePurchase? purchase;
  final String? message;
  const StoreEvent(this.kind, {this.productId = '', this.purchase, this.message});
}

/// The App Store / Google Play, behind an interface.
abstract interface class StoreGateway {
  Stream<StoreEvent> get events;
  String get platform; // 'ios' | 'android'
  Future<void> buy(String productId);

  /// Finish (iOS) / consume (Android) — ONLY after the server enrolled the student.
  Future<void> finish(StorePurchase purchase);

  /// Ask the store to re-deliver unfinished purchases (app start, settings).
  Future<void> restore();
}

/// Which course a store product was bought for (a tier product serves many
/// courses). Persisted so a purchase re-delivered after a crash still knows.
class PurchaseIntent {
  final String productId;
  final String courseId;
  final String uid;
  const PurchaseIntent({required this.productId, required this.courseId, required this.uid});
}

abstract interface class PurchaseIntentStore {
  Future<void> save(PurchaseIntent intent);
  Future<PurchaseIntent?> find(String productId);
  Future<void> remove(String productId);
}

/// A refusal from the server, with its callable error code
/// ('already-exists', 'failed-precondition', 'permission-denied', …).
class EnrollmentException implements Exception {
  final String code;
  final String message;
  const EnrollmentException(this.code, this.message);
  @override
  String toString() => message;
}

/// The tested Cloud Functions (functions/purchases.js).
abstract interface class EnrollmentGateway {
  Future<void> verifyPurchase({
    required String courseId,
    required String productId,
    required String verificationData,
    required String platform,
  });
  Future<void> enrollFree(String courseId);
}
