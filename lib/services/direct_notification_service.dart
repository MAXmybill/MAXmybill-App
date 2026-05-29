import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DirectNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Your Firebase Server Key (Legacy API) from Firebase Console
  // Get it from: Firebase Console > Project Settings > Cloud Messaging > Server Key
  // Note: This should be a long key starting with "AAAA..." or similar
  static const String _serverKey = 'BOeob5NWHkyOVa7bGwW8TyzbeuG0vSE8d4m_qacgcMPELpMd326L93r-cUmlFnf-WQM0NEQpBDnemmaEsRIk5ew';

  // Singleton pattern
  static final DirectNotificationService _instance = DirectNotificationService._internal();
  factory DirectNotificationService() => _instance;
  DirectNotificationService._internal();

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    try {
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

        // Subscribe to topic
        await _messaging.subscribeToTopic('knowledge_updates');
        debugPrint('✅ Subscribed to knowledge_updates topic');

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
      } else {
        debugPrint('❌ User declined notification permission');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
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
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Send notification using FCM HTTP API (direct method)
  Future<void> sendKnowledgeNotificationDirect({
    required String title,
    required String content,
    required String category,
  }) async {
    try {
      // Send to topic (more efficient than individual tokens)
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode({
          'to': '/topics/knowledge_updates',
          'notification': {
            // Use article title as notification title and article content as body
            'title': title,
            'body': content,
            'sound': 'default',
            'badge': '1',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'data': {
            'type': 'knowledge',
          'route': 'knowledge',
            'title': title,
            'content': content,
            'category': category,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'priority': 'high',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notification sent successfully');
        final responseData = jsonDecode(response.body);
        debugPrint('Response: $responseData');
      } else {
        debugPrint('❌ Failed to send notification: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  /// Alternative: Save to Firestore for Cloud Function to process
  Future<void> sendKnowledgeNotificationViaFirestore({
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
}

