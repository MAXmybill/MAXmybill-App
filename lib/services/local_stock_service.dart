import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';

/// Service to manage product stock locally — syncs instantly from Firestore
/// via a real-time snapshot listener, and also supports offline deductions.
class LocalStockService extends ChangeNotifier {
  static final LocalStockService _instance = LocalStockService._internal();
  factory LocalStockService() => _instance;
  LocalStockService._internal();

  static const String _stockPrefix = 'local_stock_';
  static const String _pendingUpdatesKey = 'pending_stock_updates';

  // In-memory cache for fast access
  final Map<String, double> _stockCache = {};
  bool _initialized = false;

  // Real-time Firestore listener
  StreamSubscription<QuerySnapshot>? _productsListener;

  double? _getPrefDouble(SharedPreferences prefs, String key) {
    final value = prefs.get(key);
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  /// Initialize the service and load cached stock from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_stockPrefix)) {
          final productId = key.replaceFirst(_stockPrefix, '');
          final stock = _getPrefDouble(prefs, key);
          if (stock != null) {
            _stockCache[productId] = stock;
          }
        }
      }
      _initialized = true;
      debugPrint('📦 LocalStockService initialized with ${_stockCache.length} cached items');
    } catch (e) {
      debugPrint('❌ Error initializing LocalStockService: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // REAL-TIME BACKEND SYNC
  // ─────────────────────────────────────────────────────────

  /// Start listening to Firestore Products collection.
  /// Call this once after login when the store ID is known.
  /// Every time a product's [currentStock] changes remotely (another device,
  /// bill paid on web, manual adjustment, etc.) the local cache is updated
  /// instantly and [notifyListeners] fires so the UI rebuilds.
  Future<void> startListening(CollectionReference productsCollection) async {
    // Cancel any existing listener first
    await stopListening();

    try {
      _productsListener = productsCollection.snapshots().listen(
        (snapshot) async {
          bool anyChanged = false;
          final prefs = await SharedPreferences.getInstance();

          for (final change in snapshot.docChanges) {
            // Handle added, modified documents (ignore removed)
            if (change.type == DocumentChangeType.removed) continue;

            final data = change.doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final productId = change.doc.id;
            final remoteStock = (data['currentStock'] as num?)?.toDouble();
            if (remoteStock == null) continue;

            // Only update if the backend value differs from our cache
            // (avoids overwriting a pending local deduction with stale data)
            final localStock = _stockCache[productId];
            if (localStock != remoteStock) {
              _stockCache[productId] = remoteStock;
              await prefs.setDouble('$_stockPrefix$productId', remoteStock);
              anyChanged = true;
              debugPrint('🔄 Stock synced from backend: $productId → $remoteStock');
            }
          }

          if (anyChanged) {
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('❌ LocalStockService Firestore listener error: $e');
        },
      );

      debugPrint('✅ LocalStockService: real-time backend sync started');
    } catch (e) {
      debugPrint('❌ LocalStockService: failed to start listener: $e');
    }
  }

  /// Stop the Firestore listener (call on logout or dispose).
  Future<void> stopListening() async {
    await _productsListener?.cancel();
    _productsListener = null;
  }

  // ─────────────────────────────────────────────────────────
  // LOCAL STOCK OPERATIONS
  // ─────────────────────────────────────────────────────────

  /// Update stock locally for a product - NOTIFIES LISTENERS
  Future<void> updateLocalStock(String productId, double quantityChange, {double? currentFirestoreStock}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_stockPrefix$productId';

      // Get current stock from memory cache or SharedPreferences, or use the provided firestore stock
      double currentStock = _stockCache[productId] ?? _getPrefDouble(prefs, key) ?? currentFirestoreStock ?? 0.0;

      // Calculate new stock (never go below 0)
      final newStock = (currentStock + quantityChange).clamp(0.0, 999999.0);

      // Update both memory cache and SharedPreferences
      _stockCache[productId] = newStock;
      await prefs.setDouble(key, newStock);

      debugPrint('📦 Stock updated for $productId: $currentStock -> $newStock (change: $quantityChange)');

      // Track pending update for sync when online
      await _addPendingUpdate(productId, quantityChange);

      // NOTIFY ALL LISTENERS — triggers UI rebuild in SaleAll page!
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating local stock: $e');
    }
  }

  /// Get stock for a product - uses memory cache for instant access
  double getStock(String productId) {
    return _stockCache[productId] ?? 0.0;
  }

  /// Check if stock is cached for a product
  bool hasStock(String productId) {
    return _stockCache.containsKey(productId);
  }

  /// Cache stock value from Firestore (also saves to SharedPreferences)
  Future<void> cacheStock(String productId, double stock) async {
    try {
      // Only update if different (to avoid unnecessary notifications)
      if (_stockCache[productId] != stock) {
        _stockCache[productId] = stock;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('$_stockPrefix$productId', stock);
        notifyListeners(); // Notify all listening widgets to rebuild
      }
    } catch (e) {
      debugPrint('❌ Error caching stock: $e');
    }
  }

  /// Bulk cache stock from Firestore products
  Future<void> cacheStockBulk(Map<String, double> stockMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in stockMap.entries) {
        _stockCache[entry.key] = entry.value;
        await prefs.setDouble('$_stockPrefix${entry.key}', entry.value);
      }

      // Notify after bulk update
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error bulk caching stock: $e');
    }
  }

  /// Refresh stock from Firestore and notify listeners
  Future<void> refreshFromFirestore(Map<String, double> firestoreStock) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in firestoreStock.entries) {
        _stockCache[entry.key] = entry.value;
        await prefs.setDouble('$_stockPrefix${entry.key}', entry.value);
      }

      debugPrint('🔄 Stock refreshed from Firestore: ${firestoreStock.length} products');

      // Clear pending updates since we have fresh data
      await clearPendingUpdates();

      // Notify all listeners to update UI
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error refreshing from Firestore: $e');
    }
  }

  /// Add pending stock update for later sync
  Future<void> _addPendingUpdate(String productId, double quantityChange) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      final updates = List<Map<String, dynamic>>.from(json.decode(updatesJson));

      // Check if update for this product already exists
      final existingIndex = updates.indexWhere((u) => u['productId'] == productId);
      if (existingIndex != -1) {
        // Accumulate the change
        updates[existingIndex]['quantityChange'] =
            ((updates[existingIndex]['quantityChange'] as num).toDouble()) + quantityChange;
      } else {
        // Add new pending update
        updates.add({
          'productId': productId,
          'quantityChange': quantityChange,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      await prefs.setString(_pendingUpdatesKey, json.encode(updates));
    } catch (e) {
      debugPrint('❌ Error adding pending update: $e');
    }
  }

  /// Get all pending stock updates
  Future<List<Map<String, dynamic>>> getPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatesJson = prefs.getString(_pendingUpdatesKey) ?? '[]';
      return List<Map<String, dynamic>>.from(json.decode(updatesJson));
    } catch (e) {
      debugPrint('❌ Error getting pending updates: $e');
      return [];
    }
  }

  /// Clear pending updates after successful sync
  Future<void> clearPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingUpdatesKey);
      debugPrint('✅ Pending stock updates cleared');
    } catch (e) {
      debugPrint('❌ Error clearing pending updates: $e');
    }
  }

  /// Clear all local stock cache
  Future<void> clearAllLocalStock() async {
    try {
      _stockCache.clear();

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_stockPrefix)) {
          await prefs.remove(key);
        }
      }

      debugPrint('✅ All local stock cache cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing local stock: $e');
    }
  }

  /// Get all cached stock as a map
  Map<String, double> getAllCachedStock() {
    return Map.from(_stockCache);
  }
}
