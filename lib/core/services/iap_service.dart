import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

class PurchaseResult {
  final PurchaseStatus status;
  final String? receipt;
  final String? productId;
  final String? error;

  PurchaseResult({required this.status, this.receipt, this.productId, this.error});
}

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Products cache
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Stream for UI updates
  final _purchaseController = StreamController<PurchaseResult>.broadcast();
  Stream<PurchaseResult> get purchaseStream => _purchaseController.stream;

  // --- Internal Logging for In-App Debug Console ---
  final List<String> _logs = [];
  final _logController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get logStream => _logController.stream;

  void _addLog(String msg) {
    final timestamp = DateTime.now().toString().split('.').first.split(' ').last;
    final logLine = "[$timestamp] $msg";
    _logs.insert(0, logLine); // Newest first
    if (_logs.length > 50) _logs.removeLast(); // Keep recent 50
    _logController.add(List.from(_logs));
    debugPrint("💰 IAP: $msg");
  }

  static const List<String> _defaultProductIds = [
    'com.yazan.calligro.tier_50',
    'com.yazan.calligro.tier_60',
    'com.yazan.calligro.tier_70',
    'com.yazan.calligro.tier_80',
    'com.yazan.calligro.tier_90',
    'com.yazan.calligro.tier_100',
  ];

  void initialize() {
    _addLog("Initializing IAP Service...");
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () => _subscription.cancel(),
      onError: (error) {
        _addLog("Global Listener Error: $error");
      },
    );
  }

  Future<void> fetchProducts([List<String>? productIds]) async {
    final ids = productIds ?? _defaultProductIds;
    _addLog("Fetching products: $ids");
    
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(ids.toSet())
          .timeout(const Duration(seconds: 15));
      
      if (response.notFoundIDs.isNotEmpty) {
        _addLog("Warning: Products not found: ${response.notFoundIDs}");
      }
      
      _products = response.productDetails;
      _addLog("Success: ${_products.length} products loaded.");
    } catch (e) {
      _addLog("Error during fetch: $e");
      rethrow;
    }
  }

  Future<void> buyCourse(String productId) async {
    _addLog("Attempting to buy $productId");
    
    final bool available = await _iap.isAvailable();
    if (!available) {
      _addLog("Error: App Store is currently unavailable.");
      throw "The App Store is currently unavailable.";
    }

    if (_products.isEmpty) {
      _addLog("Cache empty, performing last-second fetch...");
      await fetchProducts();
    }

    if (_products.isEmpty) {
      _addLog("Error: No products loaded after fetch.");
      throw "No products loaded. Please check your internet and store agreements.";
    }

    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) {
      _addLog("Product $productId not in cache. Fetching specific ID...");
      await fetchProducts([productId]);
      final retryIndex = _products.indexWhere((p) => p.id == productId);
      if (retryIndex == -1) {
        _addLog("Error: Product $productId still not found.");
        throw "Product '$productId' not found.";
      }
      final ProductDetails product = _products[retryIndex];
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return;
    }

    _addLog("Product found! Price: ${_products[index].price}. Launching payment sheet...");
    final ProductDetails product = _products[index];
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      _addLog("Payment sheet launched successfully.");
    } catch (e) {
      _addLog("Purchase Trigger Error: $e");
      throw "Could not contact App Store. Error: $e";
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchase in purchaseDetailsList) {
      _addLog("Status Update: ${purchase.productID} -> ${purchase.status}");
      
      if (purchase.status == PurchaseStatus.pending) {
        _purchaseController.add(PurchaseResult(status: PurchaseStatus.pending, productId: purchase.productID));
      } else if (purchase.status == PurchaseStatus.error) {
        _addLog("Error: ${purchase.error}");
        _purchaseController.add(PurchaseResult(status: PurchaseStatus.error, error: purchase.error?.toString()));
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.purchased || 
                 purchase.status == PurchaseStatus.restored) {
        _addLog("SUCCESS for ${purchase.productID}. Capturing receipt...");
        
        final String? receipt = purchase.verificationData.localVerificationData;
        
        _purchaseController.add(PurchaseResult(
          status: purchase.status,
          receipt: receipt,
          productId: purchase.productID,
        ));

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
          _addLog("Transaction Marked as Complete in App.");
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        _addLog("Canceled by User.");
        _purchaseController.add(PurchaseResult(status: PurchaseStatus.canceled));
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscription.cancel();
    _purchaseController.close();
    _logController.close();
  }
}
