import 'dart:async';

import 'package:calligro_app/features/courses/domain/course_draft.dart';
import 'package:calligro_app/features/courses/domain/course_models.dart';
import 'package:calligro_app/features/courses/domain/course_repositories.dart';

/// Emits [read]() on listen and after every change.
Stream<T> _live<T>(Stream<void> changes, T Function() read) {
  StreamSubscription<void>? sub;
  late final StreamController<T> c;
  c = StreamController<T>(
    onListen: () {
      c.add(read());
      sub = changes.listen((_) => c.add(read()));
    },
    onCancel: () => sub?.cancel(),
  );
  return c.stream;
}

class FakeCourseRepository implements CourseRepository {
  final courses = <String, Course>{};
  final teachers = <String, CourseTeacherSummary>{};
  final summaryReads = <String>[];
  final _changes = StreamController<void>.broadcast(sync: true);

  void put(Course c) {
    courses[c.id] = c;
    _changes.add(null);
  }

  List<Course> get _all => courses.values.toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  @override
  Stream<Course?> watchCourse(String courseId) => _live(_changes.stream, () => courses[courseId]);
  @override
  Stream<List<Course>> watchCatalog() => _live(_changes.stream, () => _all);
  @override
  Stream<List<Course>> watchEnrolled(String uid) =>
      _live(_changes.stream, () => _all.where((c) => c.enrolledStudents.contains(uid)).toList());
  @override
  Stream<List<Course>> watchTeaching(String teacherId) =>
      _live(_changes.stream, () => _all.where((c) => c.teacherId == teacherId).toList());
  @override
  Stream<List<Course>> watchLatest({int limit = 10}) => _live(_changes.stream, () => _all.take(limit).toList());
  @override
  Future<CourseTeacherSummary?> teacherSummary(String teacherId) async {
    summaryReads.add(teacherId);
    return teachers[teacherId];
  }
}

class FakeStore implements StoreGateway {
  final _events = StreamController<StoreEvent>.broadcast();
  final bought = <String>[];
  final finished = <StorePurchase>[];
  int restores = 0;
  Object? failBuy;

  @override
  String platform = 'ios';
  @override
  Stream<StoreEvent> get events => _events.stream;

  @override
  Future<void> buy(String productId) async {
    if (failBuy != null) throw failBuy!;
    bought.add(productId);
  }

  @override
  Future<void> finish(StorePurchase purchase) async => finished.add(purchase);
  @override
  Future<void> restore() async => restores++;

  // What the store does next:
  void deliver(String productId, {String data = 'receipt'}) => _events.add(StoreEvent(StoreEventKind.purchased,
      productId: productId, purchase: StorePurchase(productId: productId, verificationData: data)));
  void cancel(String productId) => _events.add(StoreEvent(StoreEventKind.cancelled, productId: productId));
  void fail(String productId, String msg) => _events.add(StoreEvent(StoreEventKind.failed, productId: productId, message: msg));
}

class FakeEnrollment implements EnrollmentGateway {
  final verifications = <({String courseId, String productId, String data, String platform})>[];
  final freeEnrolments = <String>[];
  EnrollmentException? refuse;
  Object? crash;

  @override
  Future<void> verifyPurchase({
    required String courseId,
    required String productId,
    required String verificationData,
    required String platform,
  }) async {
    verifications.add((courseId: courseId, productId: productId, data: verificationData, platform: platform));
    if (crash != null) throw crash!;
    if (refuse != null) throw refuse!;
  }

  @override
  Future<void> enrollFree(String courseId) async {
    freeEnrolments.add(courseId);
    if (crash != null) throw crash!;
    if (refuse != null) throw refuse!;
  }
}

/// Like SharedPreferences: survives a "restart" when the same instance is reused.
class MemoryIntentStore implements PurchaseIntentStore {
  final saved = <String, PurchaseIntent>{};
  @override
  Future<void> save(PurchaseIntent intent) async => saved[intent.productId] = intent;
  @override
  Future<PurchaseIntent?> find(String productId) async => saved[productId];
  @override
  Future<void> remove(String productId) async => saved.remove(productId);
}

/// Creating courses, in memory. Optionally adds the created course to [repo]
/// so lists update as they would with Firestore.
class FakeAuthoring implements CourseAuthoring {
  FakeAuthoring({this.repo});
  final FakeCourseRepository? repo;
  final authors = <String, CourseAuthor>{};
  final created = <({CourseDraft draft, CourseAuthor author, String generatedName, String meetLink, String password})>[];
  final authorReads = <String>[];
  Object? failCreate;
  Completer<void>? holdCreate;

  @override
  Future<CourseAuthor?> author(String uid) async {
    authorReads.add(uid);
    return authors[uid];
  }

  @override
  Future<String> create(CourseDraft draft, CourseAuthor author,
      {String generatedName = '', String meetLink = '', String classroomPassword = ''}) async {
    if (holdCreate != null) await holdCreate!.future;
    if (failCreate != null) throw failCreate!;
    created.add((draft: draft, author: author, generatedName: generatedName, meetLink: meetLink, password: classroomPassword));
    final id = 'new${created.length}';
    repo?.put(Course.fromMap(id, draft.toDocument(author, createdAt: DateTime(2026, 11, 15), generatedName: generatedName)));
    return id;
  }
}
