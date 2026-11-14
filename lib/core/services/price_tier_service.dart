import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PriceTierService {
  static final PriceTierService _instance = PriceTierService._internal();
  factory PriceTierService() => _instance;
  PriceTierService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _tiersRef =>
      _firestore.collection('app_config').doc('pricing_tiers');

  /// Default list of all tiers (in $10 increments from $60 to $200)
  static final List<Map<String, dynamic>> defaultTiers = [
    {'price': 60, 'enabled': true},
    {'price': 70, 'enabled': true},
    {'price': 80, 'enabled': true},
    {'price': 90, 'enabled': true},
    {'price': 100, 'enabled': true},
    {'price': 110, 'enabled': true},
    {'price': 120, 'enabled': true},
    {'price': 130, 'enabled': true},
    {'price': 140, 'enabled': true},
    {'price': 150, 'enabled': true},
    {'price': 160, 'enabled': true},
    {'price': 170, 'enabled': true},
    {'price': 180, 'enabled': true},
    {'price': 190, 'enabled': true},
    {'price': 200, 'enabled': true},
  ];

  static const Set<int> _excludedPrices = {30, 35, 40, 45, 50, 55, 65, 75, 85, 95};

  /// Get the list of enabled price tiers for teachers to choose when adding a course
  Future<List<int>> getEnabledTiers() async {
    try {
      final doc = await _tiersRef.get();
      if (doc.exists && doc.data() != null && doc.data()!['tiers'] != null) {
        final list = List<Map<String, dynamic>>.from(
          (doc.data()!['tiers'] as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        final enabled = list
            .where((t) => (t['enabled'] as bool?) ?? false)
            .map((t) => (t['price'] as num).toInt())
            .where((p) => !_excludedPrices.contains(p))
            .toList();
        enabled.sort();
        if (enabled.isNotEmpty) return enabled;
      }
    } catch (e) {
      debugPrint('[PriceTierService] Error fetching enabled tiers: $e');
    }

    // Default enabled tiers: 60, 70, 80, 90, 100, 110, ... 200
    final fallback = defaultTiers
        .where((t) => t['enabled'] == true)
        .map((t) => t['price'] as int)
        .where((p) => !_excludedPrices.contains(p))
        .toList();
    fallback.sort();
    return fallback;
  }

  /// Realtime stream of all tiers for the Admin management page
  Stream<List<Map<String, dynamic>>> getTiersStream() {
    return _tiersRef.snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null && snapshot.data()!['tiers'] != null) {
        final raw = snapshot.data()!['tiers'] as List<dynamic>;
        final list = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => !_excludedPrices.contains((e['price'] as num).toInt()))
            .toList();
        list.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        return list;
      }
      return List<Map<String, dynamic>>.from(defaultTiers);
    });
  }

  /// Fetch all tiers (for admin initialization)
  Future<List<Map<String, dynamic>>> getAllTiers() async {
    try {
      final doc = await _tiersRef.get();
      if (doc.exists && doc.data() != null && doc.data()!['tiers'] != null) {
        final raw = doc.data()!['tiers'] as List<dynamic>;
        final list = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => !_excludedPrices.contains((e['price'] as num).toInt()))
            .toList();
        list.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        return list;
      }
    } catch (e) {
      debugPrint('[PriceTierService] Error getting all tiers: $e');
    }
    return List<Map<String, dynamic>>.from(defaultTiers);
  }

  /// Save all tiers list to Firestore
  Future<void> saveTiers(List<Map<String, dynamic>> tiers) async {
    final sorted = List<Map<String, dynamic>>.from(tiers);
    sorted.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    await _tiersRef.set({
      'tiers': sorted,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Toggle status for a specific tier
  Future<void> updateTierStatus(int price, bool enabled) async {
    final currentList = await getAllTiers();
    final index = currentList.indexWhere((t) => (t['price'] as num).toInt() == price);
    if (index != -1) {
      currentList[index]['enabled'] = enabled;
    } else {
      currentList.add({'price': price, 'enabled': enabled});
    }
    await saveTiers(currentList);
  }

  /// Add a custom price tier
  Future<void> addCustomTier(int price, {bool enabled = true}) async {
    final currentList = await getAllTiers();
    if (!currentList.any((t) => (t['price'] as num).toInt() == price)) {
      currentList.add({'price': price, 'enabled': enabled});
      await saveTiers(currentList);
    }
  }
}

