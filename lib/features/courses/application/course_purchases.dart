import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/course_models.dart';
import '../domain/course_policy.dart';
import '../domain/course_repositories.dart';

enum PurchaseStage { idle, buying, verifying, enrolled, cancelled, failed }

enum BuyResult { started, needsAccount, notAllowed, busy, failed }

class PurchaseStatus {
  final PurchaseStage stage;

  /// The server's refusal code ('already-exists', 'failed-precondition', …).
  final String? code;
  final String? message;
  const PurchaseStatus(this.stage, {this.code, this.message});
  static const idle = PurchaseStatus(PurchaseStage.idle);
  bool get isBusy => stage == PurchaseStage.buying || stage == PurchaseStage.verifying;
}

/// The ONE purchase flow of the app (created once in CourseServices).
///
///  buy(course) → remember which course this product is for (persisted) →
///  the store charges → the server verifies and enrols → ONLY THEN the store
///  purchase is finished. If the app dies or the server fails, the store
///  re-delivers the purchase and it is verified again for the remembered course.
///  Screens only read [statusOf]; nothing here belongs to a page.
class CoursePurchases extends ChangeNotifier {
  CoursePurchases({
    required StoreGateway store,
    required EnrollmentGateway enrollment,
    required PurchaseIntentStore intents,
    required String Function() currentUid,
  })  : _store = store,
        _server = enrollment,
        _intents = intents,
        _uid = currentUid;

  final StoreGateway _store;
  final EnrollmentGateway _server;
  final PurchaseIntentStore _intents;
  final String Function() _uid;

  final _status = <String, PurchaseStatus>{};

  /// Charged but not yet enrolled (kept for retry), by course.
  final _awaiting = <String, StorePurchase>{};
  StreamSubscription<StoreEvent>? _sub;
  bool _disposed = false;

  PurchaseStatus statusOf(String courseId) => _status[courseId] ?? PurchaseStatus.idle;

  void start() {
    _sub ??= _store.events.listen(_onEvent);
    unawaited(_store.restore().catchError((Object e) => debugPrint('Store restore failed: $e')));
  }

  Future<BuyResult> buy(Course course) async {
    final uid = _uid();
    if (uid.isEmpty) return BuyResult.needsAccount;
    if (CoursePolicy.action(course, uid) != CourseAction.buy) return BuyResult.notAllowed;
    if (statusOf(course.id).isBusy) return BuyResult.busy;

    final productId = CoursePolicy.productIdFor(course);
    // Latest buy wins: a tier product serves many courses.
    await _intents.save(PurchaseIntent(productId: productId, courseId: course.id, uid: uid));
    _set(course.id, const PurchaseStatus(PurchaseStage.buying));
    try {
      await _store.buy(productId);
      return BuyResult.started;
    } catch (e) {
      await _intents.remove(productId);
      _set(course.id, PurchaseStatus(PurchaseStage.failed, message: '$e'));
      return BuyResult.failed;
    }
  }

  Future<BuyResult> enrollFree(Course course) async {
    final uid = _uid();
    if (uid.isEmpty) return BuyResult.needsAccount;
    if (CoursePolicy.action(course, uid) != CourseAction.enrollFree) return BuyResult.notAllowed;
    if (statusOf(course.id).isBusy) return BuyResult.busy;
    _set(course.id, const PurchaseStatus(PurchaseStage.verifying));
    try {
      await _server.enrollFree(course.id);
      _set(course.id, const PurchaseStatus(PurchaseStage.enrolled));
    } on EnrollmentException catch (e) {
      _set(course.id, PurchaseStatus(PurchaseStage.failed, code: e.code, message: e.message));
    } catch (e) {
      _set(course.id, PurchaseStatus(PurchaseStage.failed, message: '$e'));
    }
    return BuyResult.started;
  }

  /// Retries a charged-but-not-enrolled purchase (or asks the store to re-deliver it).
  Future<void> retry(String courseId) async {
    final purchase = _awaiting[courseId];
    if (purchase != null) {
      await _verify(courseId, purchase);
    } else {
      await _store.restore();
    }
  }

  /// Settings → "Restore purchases": re-deliver unfinished purchases; each is
  /// verified for its remembered course.
  Future<void> restore() => _store.restore();

  /// Back to idle once the screen has shown the result.
  void clear(String courseId) {
    if (_status.remove(courseId) != null) _notify();
  }

  Future<void> _onEvent(StoreEvent event) async {
    if (_disposed) return;
    final intent = await _intents.find(event.productId);
    switch (event.kind) {
      case StoreEventKind.purchased:
        final purchase = event.purchase;
        if (purchase == null) return;
        if (intent == null) {
          // A tier product serves many courses: never guess. Left unfinished, the
          // store re-delivers it (Android refunds it after 3 days if never enrolled).
          debugPrint('Purchase of ${event.productId} has no remembered course — left unfinished.');
          return;
        }
        if (intent.uid != _uid()) {
          debugPrint('Purchase of ${event.productId} belongs to another account — waiting for it.');
          return;
        }
        await _verify(intent.courseId, purchase);
      case StoreEventKind.cancelled:
        if (intent == null) return;
        await _intents.remove(event.productId);
        _set(intent.courseId, const PurchaseStatus(PurchaseStage.cancelled));
      case StoreEventKind.failed:
        if (intent == null) return;
        await _intents.remove(event.productId);
        _set(intent.courseId, PurchaseStatus(PurchaseStage.failed, message: event.message));
      case StoreEventKind.pending:
        if (intent != null) _set(intent.courseId, const PurchaseStatus(PurchaseStage.buying));
    }
  }

  Future<void> _verify(String courseId, StorePurchase purchase) async {
    if (_disposed) return;
    _awaiting[courseId] = purchase;
    _set(courseId, const PurchaseStatus(PurchaseStage.verifying));
    try {
      await _server.verifyPurchase(
        courseId: courseId,
        productId: purchase.productId,
        verificationData: purchase.verificationData,
        platform: _store.platform,
      );
      await _done(courseId, purchase);
      _set(courseId, const PurchaseStatus(PurchaseStage.enrolled));
    } on EnrollmentException catch (e) {
      // The purchase was already used for an enrolment: it is spent — finish it.
      if (e.code == 'already-exists') await _done(courseId, purchase);
      _set(courseId, PurchaseStatus(PurchaseStage.failed, code: e.code, message: e.message));
    } catch (e) {
      // Network / server down: NOT finished — retried later, never lost.
      _set(courseId, PurchaseStatus(PurchaseStage.failed, message: '$e'));
    }
  }

  Future<void> _done(String courseId, StorePurchase purchase) async {
    await _store.finish(purchase);
    await _intents.remove(purchase.productId);
    _awaiting.remove(courseId);
  }

  void _set(String courseId, PurchaseStatus s) {
    if (_disposed) return;
    _status[courseId] = s;
    notifyListeners();
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
