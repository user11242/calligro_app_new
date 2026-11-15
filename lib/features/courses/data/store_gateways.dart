import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/course_repositories.dart';

/// App Store / Google Play via the in_app_purchase plugin.
///
/// Tier products are bought many times (two $100 courses use the same
/// product), so they are CONSUMABLE — and consumed / finished only when
/// [finish] is called, i.e. after the server enrolled the student.
class InAppPurchaseStore implements StoreGateway {
  InAppPurchaseStore({InAppPurchase? iap}) : _injected = iap;
  final InAppPurchase? _injected;
  InAppPurchase get _iap => _injected ?? InAppPurchase.instance;

  final _events = StreamController<StoreEvent>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _products = <String, ProductDetails>{};

  @override
  String get platform => Platform.isAndroid ? 'android' : 'ios';

  @override
  Stream<StoreEvent> get events {
    _sub ??= _iap.purchaseStream.listen(_onUpdates, onError: (Object e) => debugPrint('Store stream error: $e'));
    return _events.stream;
  }

  void _onUpdates(List<PurchaseDetails> updates) {
    for (final p in updates) {
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          _events.add(StoreEvent(
            StoreEventKind.purchased,
            productId: p.productID,
            purchase: StorePurchase(
              productId: p.productID,
              // Apple: the app receipt; Android: the purchase token.
              verificationData: p.verificationData.serverVerificationData,
              transactionId: p.purchaseID,
              native: p,
            ),
          ));
        case PurchaseStatus.pending:
          _events.add(StoreEvent(StoreEventKind.pending, productId: p.productID));
        case PurchaseStatus.canceled:
          _events.add(StoreEvent(StoreEventKind.cancelled, productId: p.productID));
          if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
        case PurchaseStatus.error:
          _events.add(StoreEvent(StoreEventKind.failed, productId: p.productID, message: p.error?.message));
          if (p.pendingCompletePurchase) unawaited(_iap.completePurchase(p));
      }
    }
  }

  @override
  Future<void> buy(String productId) async {
    events; // make sure we are listening before the sheet opens
    if (!await _iap.isAvailable()) throw StateError('The store is not available right now.');
    var product = _products[productId];
    if (product == null) {
      final res = await _iap.queryProductDetails({productId});
      if (res.productDetails.isEmpty) throw StateError('Product $productId is not available in the store.');
      product = _products[productId] = res.productDetails.first;
    }
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product), autoConsume: false);
  }

  @override
  Future<void> finish(StorePurchase purchase) async {
    final p = purchase.native;
    if (p is! PurchaseDetails) return;
    if (Platform.isAndroid) {
      // Consuming also acknowledges, and lets the same tier be bought again.
      final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await android.consumePurchase(p);
    }
    if (p.pendingCompletePurchase) await _iap.completePurchase(p);
  }

  @override
  Future<void> restore() async {
    events;
    await _iap.restorePurchases();
  }
}

/// The tested Cloud Functions in functions/purchases.js.
class CloudFunctionsEnrollment implements EnrollmentGateway {
  CloudFunctionsEnrollment({FirebaseFunctions? functions}) : _injected = functions;
  final FirebaseFunctions? _injected;
  FirebaseFunctions get _fn => _injected ?? FirebaseFunctions.instance;

  Future<void> _call(String name, Map<String, Object?> data) async {
    try {
      await _fn.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (e) {
      throw EnrollmentException(e.code, e.message ?? e.code);
    }
  }

  @override
  Future<void> verifyPurchase({
    required String courseId,
    required String productId,
    required String verificationData,
    required String platform,
  }) =>
      _call('verifyPurchase', {
        'courseId': courseId,
        'productId': productId,
        'platform': platform,
        'receiptData': verificationData,
        if (platform == 'android') 'purchaseToken': verificationData,
      });

  @override
  Future<void> enrollFree(String courseId) => _call('enrollInFreeCourse', {'courseId': courseId});
}

/// Remembers which course each product was bought for, across restarts.
class SharedPrefsIntentStore implements PurchaseIntentStore {
  static const _prefix = 'course_purchase_intent.';

  @override
  Future<void> save(PurchaseIntent intent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_prefix${intent.productId}', jsonEncode({'courseId': intent.courseId, 'uid': intent.uid}));
  }

  @override
  Future<PurchaseIntent?> find(String productId) async {
    final raw = (await SharedPreferences.getInstance()).getString('$_prefix$productId');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return PurchaseIntent(productId: productId, courseId: m['courseId'] as String, uid: m['uid'] as String);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> remove(String productId) async =>
      (await SharedPreferences.getInstance()).remove('$_prefix$productId');
}
