import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:maxmybill/Menu/KnowledgePage.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Map<String, dynamic>? _pendingKnowledgePayload;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static Map<String, dynamic>? consumePendingKnowledgePayload() {
    final payload = _pendingKnowledgePayload;
    _pendingKnowledgePayload = null;
    return payload;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    if (type != 'knowledge') return;

    final payload = Map<String, dynamic>.from(data);
    _pendingKnowledgePayload = payload;

    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    _pendingKnowledgePayload = null;
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => KnowledgePage(
          onBack: () {
            if (navigator.canPop()) {
              navigator.pop();
            }
          },
        ),
      ),
    );
  }

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    try {
      // Check if device has internet connectivity before attempting FCM
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      
      // Skip FCM initialization if offline
      if (result.isEmpty || result.contains(ConnectivityResult.none)) {
        debugPrint('⚠️ No internet connection, skipping FCM initialization for offline mode');
        return;
      }

      // Request permission for notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');

        // Get FCM token
        String? token = await _messaging.getToken();
        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          await _saveTokenToFirestore(token);
        }

        await subscribeToKnowledgeTopic();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

        // Handle taps while app is running/backgrounded
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationTap(message.data);
        });

        // Handle taps that launched the app from a terminated state
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage.data);
        }
      } else {
        debugPrint('❌ User declined notification permission');
      }
    } catch (e) {
      debugPrint('⚠️ FCM initialization skipped (likely offline): $e');
      // Don't rethrow - allow app to continue in offline mode
    }
  }

  /// Save FCM token to Firestore for the current user
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      // Save to a global tokens collection
      await _firestore.collection('fcm_tokens').doc(token).set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved to Firestore');
    } catch (e) {
      debugPrint('⚠️ Could not save FCM token (likely offline): $e');
      // Don't rethrow - app should continue even if token can't be saved
    }
  }

  /// Send notification to all usewhen knowledge is posted
  Future<void> sendKnowledgeNotification({
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      // Get all FCM tokens from Firestore
      final tokensSnapshot = await _firestore.collection('fcm_tokens').get();

      if (tokensSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No FCM tokens found');
        return;
      }

      // Create notification payload
      // Notification title should be the article title, and body should contain the article content
      final notification = {
        'title': title,
        'body': content,
        'data': {
          'type': 'knowledge',
          'route': 'knowledge',
          'title': title,
          'content': content,
          'category': category,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      // Save notification to Firestore to trigger Cloud Function
      // You'll need to set up a Cloud Function to actually send the FCM messages
      await _firestore.collection('notifications').add({
        'notification': notification,
        'tokens': tokensSnapshot.docs.map((doc) => doc['token']).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      debugPrint('✅ Notification queued for ${tokensSnapshot.docs.length} devices');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  /// Subscribe to knowledge updates topic
  Future<void> subscribeToKnowledgeTopic() async {
    try {
      await _messaging.subscribeToTopic('knowledge_updates');
      debugPrint('✅ Subscribed to knowledge updates');
    } catch (e) {
      debugPrint('⚠️ Could not subscribe to topic (likely offline): $e');
      // Don't rethrow - app should continue even if subscription fails
    }
  }

  /// Unsubscribe from knowledge updates topic
  Future<void> unsubscribeFromKnowledgeTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('knowledge_updates');
      debugPrint('✅ Unsubscribed from knowledge updates');
    } catch (e) {
      debugPrint('⚠️ Could not unsubscribe from topic (likely offline): $e');
      // Don't rethrow - app should continue even if unsubscription fails
    }
  }
}

