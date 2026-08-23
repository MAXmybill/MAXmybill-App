
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Centralized service to manage and fetch dynamic subscription plan pricing
/// configured exclusively by the Superadmin (Company Role).
class SubscriptionPricingService {
  static final SubscriptionPricingService _instance = SubscriptionPricingService._internal();
  factory SubscriptionPricingService() => _instance;
  SubscriptionPricingService._internal();

  static const String collectionName = 'system_config';
  static const String documentName = 'subscription_plans';

  // Default baseline pricing in INR
  static const Map<String, Map<String, int>> defaultPrices = {
    'Starter': {'1': 0, '12': 0},
    'MAX One': {'1': 199, '12': 1910},
    'MAX Plus': {'1': 499, '12': 4790},
    'MAX Pro': {'1': 999, '12': 9590},
  };

  Map<String, Map<String, int>> _cachedPrices = Map.from(defaultPrices);

  Map<String, Map<String, int>> get prices => _cachedPrices;

  int getPrice(String planName, int durationMonths) {
    final planPrices = _cachedPrices[planName] ?? defaultPrices[planName];
    if (planPrices == null) return 0;
    return planPrices[durationMonths.toString()] ?? planPrices['1'] ?? 0;
  }

  /// Load pricing once from Firestore
  Future<Map<String, Map<String, int>>> loadPrices() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(documentName)
          .get();

      if (doc.exists && doc.data() != null) {
        _parseAndCacheDoc(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error loading dynamic subscription prices: $e');
    }
    return _cachedPrices;
  }

  /// Listen to real-time pricing updates from Superadmin
  Stream<Map<String, Map<String, int>>> streamPrices() {
    return FirebaseFirestore.instance
        .collection(collectionName)
        .doc(documentName)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _parseAndCacheDoc(snapshot.data()!);
      }
      return _cachedPrices;
    });
  }

  void _parseAndCacheDoc(Map<String, dynamic> data) {
    final plansData = data['plans'] as Map<String, dynamic>?;
    if (plansData != null) {
      final Map<String, Map<String, int>> updated = {};
      defaultPrices.forEach((planName, defaultMap) {
        if (plansData.containsKey(planName)) {
          final planConfig = plansData[planName] as Map<String, dynamic>;
          final monthly = (planConfig['priceMonthly'] as num?)?.toInt() ?? defaultMap['1']!;
          final yearly = (planConfig['priceYearly'] as num?)?.toInt() ?? defaultMap['12']!;
          updated[planName] = {'1': monthly, '12': yearly};
        } else {
          updated[planName] = Map.from(defaultMap);
        }
      });
      _cachedPrices = updated;
    }
  }

  /// Update plan prices in Firestore (Superadmin Company Role only)
  Future<void> updatePlanPrices({
    required Map<String, Map<String, int>> newPrices,
    String? updatedBy,
  }) async {
    final Map<String, dynamic> payloadPlans = {};

    newPrices.forEach((planName, priceMap) {
      payloadPlans[planName] = {
        'name': planName,
        'priceMonthly': priceMap['1'] ?? 0,
        'priceYearly': priceMap['12'] ?? 0,
      };
    });

    await FirebaseFirestore.instance.collection(collectionName).doc(documentName).set({
      'plans': payloadPlans,
      'baseCurrency': 'INR',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy ?? 'superadmin',
    }, SetOptions(merge: true));

    _cachedPrices = Map.from(newPrices);
  }
}
