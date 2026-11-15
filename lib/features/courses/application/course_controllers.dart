import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/course_models.dart';
import '../domain/course_policy.dart';
import '../domain/course_repositories.dart';

/// Course page: the live course, its teacher (read once) and the main action.
class CoursePreviewController extends ChangeNotifier {
  CoursePreviewController({
    required CourseRepository repository,
    required this.courseId,
    required this.uid,
    Course? initial,
  })  : _repo = repository,
        _course = initial;

  final CourseRepository _repo;
  final String courseId;
  final String uid;
  StreamSubscription<Course?>? _sub;
  bool _disposed = false;

  Course? _course;
  Course? get course => _course;
  bool _loading = true;
  bool get isLoading => _loading && _course == null;
  bool get notFound => !_loading && _course == null;
  CourseTeacherSummary? _teacher;
  CourseTeacherSummary? get teacher => _teacher;
  bool _teacherRequested = false;

  CourseAction? get action => _course == null ? null : CoursePolicy.action(_course!, uid);

  void start() {
    _sub ??= _repo.watchCourse(courseId).listen((c) {
      _course = c;
      _loading = false;
      if (c != null && !_teacherRequested && c.teacherId.isNotEmpty) {
        _teacherRequested = true;
        _repo.teacherSummary(c.teacherId).then((t) {
          _teacher = t;
          _notify();
        }).catchError((Object e) => debugPrint('Teacher summary failed: $e'));
      }
      _notify();
    }, onError: (Object e) {
      debugPrint('Course $courseId could not be loaded: $e');
      _loading = false;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// A live list of courses (catalogue, my courses, latest).
class CourseListController extends ChangeNotifier {
  CourseListController(this._source);
  final Stream<List<Course>> _source;
  StreamSubscription<List<Course>>? _sub;
  bool _disposed = false;

  List<Course> _all = const [];
  List<Course> get all => _all;
  bool _loading = true;
  bool get isLoading => _loading;
  bool _hasError = false;
  bool get hasError => _hasError;

  void start() {
    _sub ??= _source.listen((list) {
      _all = list;
      _loading = false;
      _hasError = false;
      _notify();
    }, onError: (Object e) {
      debugPrint('Course list failed: $e');
      _loading = false;
      _hasError = true;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

/// The catalogue: visibility (started courses hidden), chip filter and search.
class CourseCatalogController extends CourseListController {
  CourseCatalogController({required CourseRepository repository, required this.uid, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(repository.watchCatalog());

  final String uid;
  final DateTime Function() _now;

  CourseFilter _filter = CourseFilter.all;
  CourseFilter get filter => _filter;
  String _query = '';
  String get query => _query;

  set filter(CourseFilter f) {
    _filter = f;
    _notify();
  }

  set query(String q) {
    _query = q;
    _notify();
  }

  /// [displayTitle]: the translated title the user sees (searchable too).
  List<Course> visible({String Function(Course)? displayTitle}) {
    final now = _now();
    return [
      for (final c in all)
        if (CoursePolicy.isVisibleInCatalog(c, uid, now: now) &&
            CoursePolicy.matches(c, _filter, uid) &&
            CoursePolicy.matchesSearch(c, _query, extraText: displayTitle?.call(c) ?? ''))
          c,
    ];
  }
}
