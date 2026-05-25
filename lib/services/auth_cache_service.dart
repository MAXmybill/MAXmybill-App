import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Caches the last login session to a local persistent storage (Hive).
/// 
/// This service ensures that users remain logged in even if:
/// - Network connectivity is temporarily lost
/// - Firebase auth persistence fails
/// - The app is killed and restarted
/// 
/// It works alongside Firebase Auth, not replacing it, but providing a reliable fallback.
class AuthCacheService {
  AuthCacheService._internal();

  static final AuthCacheService instance = AuthCacheService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _boxName = 'auth_cache';
  static const String _uidKey = 'cached_uid';
  static const String _emailKey = 'cached_email';
  static const String _displayNameKey = 'cached_display_name';
  static const String _timestampKey = 'cached_timestamp';
  static const int _cacheDurationDays = 30; // Cache valid for 30 days

  /// Initialize the auth cache (call this once in main.dart)
  Future<void> initialize() async {
    try {
      await Hive.openBox(_boxName);
      debugPrint('✅ AuthCacheService initialized');
    } catch (e) {
      debugPrint('❌ AuthCacheService init error: $e');
    }
  }

  /// Cache the current user's login information
  Future<void> cacheCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        await clearCache();
        return;
      }

      final box = Hive.box(_boxName);
      await box.putAll({
        _uidKey: user.uid,
        _emailKey: user.email ?? '',
        _displayNameKey: user.displayName ?? '',
        _timestampKey: DateTime.now().toIso8601String(),
      });

      debugPrint('✅ User cached: ${user.email}');
    } catch (e) {
      debugPrint('❌ Error caching user: $e');
    }
  }

  /// Get cached user data
  CachedUserData? getCachedUser() {
    try {
      final box = Hive.box(_boxName);
      final uid = box.get(_uidKey);
      final email = box.get(_emailKey);

      if (uid == null || uid.isEmpty) {
        return null;
      }

      // Check if cache has expired
      final timestamp = box.get(_timestampKey);
      if (timestamp != null) {
        try {
          final cachedAt = DateTime.parse(timestamp);
          final now = DateTime.now();
          if (now.difference(cachedAt).inDays > _cacheDurationDays) {
            debugPrint('⏰ Auth cache expired, clearing');
            clearCache();
            return null;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing cache timestamp: $e');
        }
      }

      return CachedUserData(
        uid: uid,
        email: email ?? '',
        displayName: box.get(_displayNameKey) ?? '',
      );
    } catch (e) {
      debugPrint('❌ Error retrieving cached user: $e');
      return null;
    }
  }

  /// Verify if cached user is still valid by checking Firestore
  /// This is a safety check to ensure the account still exists and is active
  Future<bool> verifyCachedUser(String uid) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found in Firestore');
        return false;
      }

      final userData = userDoc.data();
      final isActive = userData?['isActive'] ?? false;
      
      if (!isActive) {
        debugPrint('⚠️ User account is not active');
        return false;
      }

      debugPrint('✅ Cached user verified in Firestore');
      return true;
    } catch (e) {
      debugPrint('⚠️ Error verifying cached user (might be offline): $e');
      // Return true here because we're offline and should allow the cached user
      // The verification will happen again when network is restored
      return true;
    }
  }

  /// Check if user has an active Firebase session
  /// Returns false if no current user or on error
  Future<bool> hasActiveFirebaseSession() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Refresh to ensure token is fresh
        await user.reload();
        debugPrint('✅ Active Firebase session found: ${user.email}');
        return true;
      }
      debugPrint('ℹ️ No active Firebase session');
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking Firebase session: $e');
      return false;
    }
  }

  /// Get the best available user data (Firebase first, fallback to cache)
  Future<UserSessionData?> getReliableUserData() async {
    // Try Firebase first (most reliable)
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          // Cache it for future use
          await cacheCurrentUser();
          
          debugPrint('✅ Using active Firebase session');
          return UserSessionData(
            uid: currentUser.uid,
            email: currentUser.email ?? '',
            displayName: currentUser.displayName ?? '',
            source: SessionSource.firebase,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Firebase session check error: $e');
    }

    // Fallback to cached data
    final cached = getCachedUser();
    if (cached != null) {
      // Verify the cached user is still valid
      final isValid = await verifyCachedUser(cached.uid);
      if (isValid) {
        debugPrint('✅ Using cached session (fallback)');
        return UserSessionData(
          uid: cached.uid,
          email: cached.email,
          displayName: cached.displayName,
          source: SessionSource.cache,
        );
      }
    }

    debugPrint('❌ No valid session found (Firebase or cache)');
    return null;
  }

  /// Clear all cached user data
  Future<void> clearCache() async {
    try {
      final box = Hive.box(_boxName);
      await box.clear();
      debugPrint('✅ Auth cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Check if this is the first app launch after installation
  Future<bool> isFirstLaunch() async {
    try {
      final box = Hive.box(_boxName);
      final hasLaunchedBefore = box.containsKey('app_launched_before');
      
      if (!hasLaunchedBefore) {
        await box.put('app_launched_before', true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking first launch: $e');
      return false;
    }
  }
}

class CachedUserData {
  final String uid;
  final String email;
  final String displayName;

  CachedUserData({
    required this.uid,
    required this.email,
    required this.displayName,
  });
}

class UserSessionData {
  final String uid;
  final String email;
  final String displayName;
  final SessionSource source;

  UserSessionData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.source,
  });
}

enum SessionSource {
  firebase,
  cache,
}

