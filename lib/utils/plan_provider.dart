import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxmybill/utils/firestore_service.dart';

/// Global Plan Provider - ALWAYS fetches fresh data from Firestore
/// NO CACHING - Every access fetches from backend
class PlanProvider extends ChangeNotifier {
  static const String PLAN_FREE = 'Free';
  static const String PLAN_STARTER = 'Starter';
  static const String PLAN_MAXOne = 'MAX One';
  static const String PLAN_MAXPlus = 'MAX Plus';
  static const String PLAN_MAX = 'MAX Pro';

  StreamSubscription<DocumentSnapshot>? _planSubscription;
  String? _storeId;

  // Cache the current plan for instant access
  String _cachedPlan = PLAN_FREE;
  String _rawPlan = PLAN_FREE; // Store the original plan from Firestore (before expiry check)
  DateTime? _cachedExpiryDate;
  bool _isInitialized = false;
  bool _isTrial = false;

  /// Get cached plan instantly (no async wait)
  /// Returns 'Free' if the plan has expired or has no valid future expiry date
  String get cachedPlan {
    // Check if plan is expired strictly based on expiry date
    if (_rawPlan.toLowerCase() != 'free' && _rawPlan.toLowerCase() != 'starter') {
      if (_cachedExpiryDate == null || DateTime.now().isAfter(_cachedExpiryDate!)) {
        return PLAN_FREE;
      }
    }
    return _cachedPlan;
  }

  /// Get the original plan name without expiry check (for displaying "last plan")
  /// This returns the actual plan stored in Firestore, even if expired
  String get originalPlan => _rawPlan;

  /// Get cached expiry date instantly (no async wait)
  DateTime? get cachedExpiryDate => _cachedExpiryDate;

  /// Check if plan is expiring soon (within 3 days or expired)
  bool get isExpiringSoon {
    if (_cachedExpiryDate == null) return false;
    final days = daysUntilExpiry;
    return days <= 3;
  }

  /// Get days until expiry based on calendar days (negative if expired)
  int get daysUntilExpiry {
    if (_cachedExpiryDate == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(_cachedExpiryDate!.year, _cachedExpiryDate!.month, _cachedExpiryDate!.day);
    return expiryDay.difference(today).inDays;
  }

  /// Check if provider is initialized
  bool get isInitialized => _isInitialized;

  /// Check if the current plan is a trial
  bool get isTrial {
    if (_isPlanFree(cachedPlan)) return false;
    return _isTrial;
  }

  /// Initialize the plan listener - call this once at app startup
  Future<void> initialize() async {
    await _startPlanListener();
    // Fetch and cache the current plan and expiry date
    await _fetchPlanAndExpiry();
    _isInitialized = true;
    notifyListeners();
  }

  /// Force refresh the plan from Firestore and notify all listeners
  /// Call this after subscription purchase to instantly update the app
  Future<void> forceRefresh() async {
    debugPrint('🔄 PlanProvider: Force refreshing subscription status...');
    await _loadPlanAndExpiry();
    debugPrint('✅ PlanProvider: New plan = $_cachedPlan, Expiry = $_cachedExpiryDate');
    notifyListeners();
  }

  static DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final str = v.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  /// Fetch both plan and expiry date together
  Future<void> _loadPlanAndExpiry() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null || !storeDoc.exists) {
        _cachedPlan = PLAN_FREE;
        _rawPlan = PLAN_FREE;
        _cachedExpiryDate = null;
        _isTrial = false;
        return;
      }

      final data = storeDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        _cachedPlan = PLAN_FREE;
        _rawPlan = PLAN_FREE;
        _cachedExpiryDate = null;
        _isTrial = false;
        return;
      }

      // Get expiry date
      final rawExpiry = data['subscriptionExpiryDate'] ?? data['expiryDate'];
      _cachedExpiryDate = _tryParseDate(rawExpiry);

      // Get raw plan from Firestore
      final rawPlanValue = data['plan']?.toString();
      _rawPlan = (rawPlanValue != null && rawPlanValue.trim().isNotEmpty) ? rawPlanValue.trim() : PLAN_FREE;
      
      _isTrial = data['isTrial'] == true;

      // Apply date-based check: paid/trial plans MUST have an active future expiry date
      if (_rawPlan.toLowerCase() != 'free' && _rawPlan.toLowerCase() != 'starter') {
        if (_cachedExpiryDate == null || DateTime.now().isAfter(_cachedExpiryDate!)) {
          _cachedPlan = PLAN_FREE;
        } else {
          _cachedPlan = _rawPlan;
        }
      } else {
        _cachedPlan = _rawPlan;
      }
    } catch (e) {
      debugPrint('Error fetching plan and expiry: $e');
      _cachedPlan = PLAN_FREE;
      _rawPlan = PLAN_FREE;
      _cachedExpiryDate = null;
    }
  }

  /// Backward compatibility alias
  Future<void> _fetchPlanAndExpiry() async {
    await _loadPlanAndExpiry();
  }

  /// Start listening to plan changes in real-time (no caching, direct Firestore stream)
  Future<void> _startPlanListener() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null) {
        notifyListeners();
        return;
      }

      _storeId = storeDoc.id;

      // Cancel existing subscription if any
      await _planSubscription?.cancel();

      // Listen to store document changes in real-time
      // This triggers notifyListeners() on every Firestore change
      _planSubscription = FirebaseFirestore.instance
          .collection('store')
          .doc(storeDoc.id)
          .snapshots()
          .listen((snapshot) async {
        // Update cached plan and expiry date when Firestore changes
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            // Update raw plan (without expiry check)
            final newPlan = data['plan']?.toString() ?? PLAN_FREE;
            _rawPlan = newPlan.isEmpty ? PLAN_FREE : newPlan;

            // Parse expiry date FIRST
            final rawExpiry = data['subscriptionExpiryDate'] ?? data['expiryDate'];
            _cachedExpiryDate = _tryParseDate(rawExpiry);

            // Date-first evaluation for active plan
            if (_rawPlan.toLowerCase() != 'free' && _rawPlan.toLowerCase() != 'starter') {
              if (_cachedExpiryDate == null || DateTime.now().isAfter(_cachedExpiryDate!)) {
                _cachedPlan = PLAN_FREE;
              } else {
                _cachedPlan = _rawPlan;
              }
            } else {
              _cachedPlan = _rawPlan;
            }

            _isTrial = data['isTrial'] == true;
          }
        }
        // Notify all widgets to rebuild
        notifyListeners();
      }, onError: (e) {
        debugPrint('Plan listener error: $e');
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting plan listener: $e');
      notifyListeners();
    }
  }

  /// ALWAYS fetch current plan from Firestore - NO CACHE
  Future<String> getCurrentPlan() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null || !storeDoc.exists) {
        debugPrint('🔍 getCurrentPlan: No store doc, returning Free');
        return PLAN_FREE;
      }

      final data = storeDoc.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('🔍 getCurrentPlan: No data, returning Free');
        return PLAN_FREE;
      }

      String? planValue = data['plan']?.toString();
      if (planValue == null || planValue.trim().isEmpty) {
        debugPrint('🔍 getCurrentPlan: No plan value, returning Free');
        return PLAN_FREE;
      }

      final plan = planValue.trim();
      debugPrint('🔍 getCurrentPlan: Raw plan from Firestore = "$plan"');

      // Check expiry for paid plans (case-insensitive)
      if (!_isPlanFree(plan)) {
        final rawExpiry = data['subscriptionExpiryDate'] ?? data['expiryDate'];
        final expiryDate = _tryParseDate(rawExpiry);
        if (expiryDate == null || DateTime.now().isAfter(expiryDate)) {
          debugPrint('🔍 getCurrentPlan: Plan EXPIRED or no valid expiry ($expiryDate), returning Free');
          return PLAN_FREE; // Expired
        }
      }

      debugPrint('🔍 getCurrentPlan: Returning plan = "$plan"');
      return plan;
    } catch (e) {
      debugPrint('Error fetching plan: $e');
      return PLAN_FREE;
    }
  }

  /// Get current plan synchronously for UI (returns cached value)
  /// Returns cached plan instantly, auto-updated by Firestore listener
  String get currentPlan {
    return cachedPlan;
  }

  void _fetchAndNotify() async {
    // Fetch fresh data and update cache
    _cachedPlan = await getCurrentPlan();
    notifyListeners();
  }

  // ==========================================
  // ASYNC PERMISSION CHECKS - Always fetch fresh
  // ==========================================

  bool _isPlanFree(String plan) {
    final normalized = _normalizedPlanKey(plan);
    return normalized == 'free' || normalized == 'starter';
  }

  String _normalizedPlanKey(String plan) {
    final planLower = plan.toLowerCase().trim();
    if (planLower.contains('max pro') || planLower.contains('premium') || planLower.contains(' pro')) return 'max pro';
    if (planLower.contains('max plus') || planLower.contains(' plus')) return 'max plus';
    if (planLower.contains('max one') || planLower.contains('maxone')) return 'max one';
    if (planLower.contains('max lite') || planLower.contains(' lite')) return 'max lite';
    if (planLower.contains('starter')) return 'starter';
    if (planLower.contains('free')) return 'free';
    return planLower;
  }

  Future<bool> canAccessReportsAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessDaybookAsync() async {
    return true; // Daybook is FREE for everyone
  }

  Future<bool> canAccessQuotationAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessFullBillHistoryAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canEditBillAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canAccessCustomerCreditAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canUseLogoOnBillAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canImportContactsAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canUseBulkInventoryAsync() async {
    final plan = await getCurrentPlan();
    return !_isPlanFree(plan);
  }

  Future<bool> canRemoveWatermarkAsync() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();
      if (storeDoc == null || !storeDoc.exists) return false;
      final data = storeDoc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final rawExpiry = data['subscriptionExpiryDate'] ?? data['expiryDate'];
      final expiryDate = _tryParseDate(rawExpiry);
      if (expiryDate == null) return false;

      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  Future<bool> canAccessStaffManagementAsync() async {
    final plan = await getCurrentPlan();
    final planLower = _normalizedPlanKey(plan);
    debugPrint('🔍 canAccessStaffManagementAsync: plan="$plan", planLower="$planLower"');
    // Starter is the free plan - no staff management
    if (planLower == 'free' || planLower == 'starter') {
      debugPrint('🔍 canAccessStaffManagementAsync: returning FALSE (free/starter)');
      return false;
    }
    final canAccess = planLower == 'max one' || planLower == 'max lite' || planLower == 'max plus' || planLower == 'max pro';
    debugPrint('🔍 canAccessStaffManagementAsync: returning $canAccess');
    return canAccess;
  }

  Future<int> getMaxStaffCountAsync() async {
    final plan = await getCurrentPlan();
    switch (_normalizedPlanKey(plan)) {
      case 'free':
      case 'starter':
        return 0;
      case 'max one':
      case 'max lite':
        return 1; // Admin + 1 Manager
      case 'max plus':
        return 3; // Admin + 3 Staff
      case 'max pro':
        return 15; // Admin + 15 Staff
      default:
        return 0;
    }
  }

  Future<int> getBillHistoryDaysLimitAsync() async {
    final plan = await getCurrentPlan();
    return _isPlanFree(plan) ? 7 : 36500;
  }

  Future<bool> canAddMoreStaffAsync(int currentStaffCount) async {
    final maxStaff = await getMaxStaffCountAsync();
    if (maxStaff == 0) return false;
    return currentStaffCount < maxStaff;
  }

  // ==========================================
  // SYNC METHODS - Use cached plan for instant updates
  // These return results based on cached plan value
  // ==========================================

  bool _isFreePlan() {
    if (_cachedExpiryDate == null || DateTime.now().isAfter(_cachedExpiryDate!)) {
      return true; // Expired or missing expiry date = Free
    }
    final normalized = _normalizedPlanKey(cachedPlan);
    return normalized == 'free' || normalized == 'starter';
  }

  bool canAccessReports() => !_isFreePlan();
  bool canAccessDaybook() => true; // Daybook is FREE
  bool canAccessQuotation() => !_isFreePlan();
  bool canAccessFullBillHistory() => !_isFreePlan();
  bool canEditBill() => !_isFreePlan();
  bool canAccessCustomerCredit() => !_isFreePlan();
  bool canUseLogoOnBill() => !_isFreePlan();
  bool canImportContacts() => !_isFreePlan();
  bool canUseBulkInventory() => !_isFreePlan();
  bool canRemoveWatermark() {
    if (_cachedExpiryDate == null) return false;
    return DateTime.now().isBefore(_cachedExpiryDate!);
  }
  bool canAccessStaffManagement() {
    final planLower = _normalizedPlanKey(cachedPlan);
    return planLower == 'max one' || planLower == 'max lite' || planLower == 'max plus' || planLower == 'max pro';
  }

  int getMaxStaffCount() {
    switch (_normalizedPlanKey(cachedPlan)) {
      case 'free':
      case 'starter':
        return 0;
      case 'max one':
      case 'max lite':
        return 1; // Admin + 1 Manager
      case 'max plus':
        return 3; // Admin + 3 Staff
      case 'max pro':
        return 15; // Admin + 15 Staff
      default:
        return 0;
    }
  }

  int getBillHistoryDaysLimit() {
    return _isFreePlan() ? 7 : 36500;
  }

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }
}

