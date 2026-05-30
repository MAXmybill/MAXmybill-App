import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'LoginPage.dart';
import 'BusinessDetailsPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxmybill/Sales/NewSale.dart';
import 'package:maxmybill/Menu/KnowledgePage.dart';
import 'package:maxmybill/Admin/Home.dart';
import 'package:maxmybill/utils/plan_provider.dart';
import 'package:maxmybill/services/in_app_update_service.dart';
import 'package:maxmybill/services/single_session_service.dart';
import 'package:maxmybill/services/notification_service.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:maxmybill/services/auth_cache_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription<ForceSignOutReason>? _forceLogoutSub;

  @override
  void initState() {
    super.initState();
    debugPrint('Splash screen started at: ${DateTime.now()}');

    // Listen for forced logout events and redirect to login with a message.
    _forceLogoutSub = ForceSignOutBus.instance.stream.listen((reason) {
      if (!mounted) return;
      final message = reason == ForceSignOutReason.loggedInOnAnotherDevice
          ? 'You were logged out because this account was used to sign in on another device.'
          : 'You have been logged out.';

      // Ensure we land on login.
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );

      // Show confirmation message after navigation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });

    // Check for in-app updates (Android only, skip on web)
    if (!kIsWeb) {
      InAppUpdateService.checkForUpdate();
    }

    // Navigate after 2 seconds (reduced from 5 for better UX on web)
    Timer(Duration(seconds: kIsWeb ? 2 : 5), () {
      debugPrint('Splash screen ended at: ${DateTime.now()}');
      if (!mounted) return;
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    try {
      // Check internet connectivity
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      final isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
      
      // Try to get reliable user data (Firebase first, then cache as fallback)
      final sessionData = await AuthCacheService.instance.getReliableUserData();
      
      if (sessionData != null) {
        debugPrint('📱 Session found (${sessionData.source}): ${sessionData.email}');
        
        // Start single-session enforcement for logged-in users (non-blocking, timeout protected)
        // IMPORTANT: do NOT overwrite active session on splash; only listen.
        if (!isOffline) {
          try {
            await SingleSessionService.instance.startSessionListener(uid: sessionData.uid).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⚠️ Session listener timeout');
                return null;
              },
            );
          } catch (e) {
            debugPrint('⚠️ Could not start session listener: $e');
            // Continue anyway - app can still work
          }
        }

        // Check if the logged-in user is admin
        final userEmail = sessionData.email.toLowerCase();
        if (userEmail == 'maxmybillapp@gmail.com') {
          // Initialize PlanProvider in background (non-blocking)
          final planProvider = Provider.of<PlanProvider>(context, listen: false);
          planProvider.initialize(); // Don't await - let it run in background

          // Unsubscribe from knowledge topic (non-blocking)
          NotificationService().unsubscribeFromKnowledgeTopic().catchError((e) {
            debugPrint('⚠️ Could not unsubscribe from topic: $e');
          });

          if (!mounted) return;

          final pendingKnowledge = NotificationService.consumePendingKnowledgePayload();

          // Navigate to Admin Home page
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => HomePage(
                uid: sessionData.uid,
                userEmail: sessionData.email,
              ),
            ),
          );

          if (pendingKnowledge != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => KnowledgePage(
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              );
            });
          }
          return;
        }

        // Check if user has completed business registration
        // Use timeout to prevent blocking if offline
        bool userDocExists = true;
        if (!isOffline) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(sessionData.uid)
                .get()
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () {
                    debugPrint('⚠️ Firestore query timeout - assuming user registered (offline)');
                    throw TimeoutException('Firestore operation timed out');
                  },
                );
            userDocExists = userDoc.exists;
          } catch (e) {
            if (e is TimeoutException) {
              debugPrint('⚠️ Firestore timeout, assuming user is registered');
              userDocExists = true; // Assume registered if we can't check
            } else {
              debugPrint('⚠️ Error checking user registration: $e');
              userDocExists = true; // Assume registered if error occurs
            }
          }
        } else {
          // Offline mode - assume user is registered if they have a session
          debugPrint('🔓 Offline mode - skipping registration check');
          userDocExists = true;
        }

        if (!userDocExists) {
          // User started registration but didn't complete - redirect to BusinessDetailsPage
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(
              builder: (_) => BusinessDetailsPage(
                uid: sessionData.uid,
                email: sessionData.email,
                displayName: sessionData.displayName,
              ),
            ),
          );
          return;
        }

        // User has completed registration (or offline, so assume completed) - proceed normally
        // Initialize PlanProvider in background (non-blocking)
        final planProvider = Provider.of<PlanProvider>(context, listen: false);
        planProvider.initialize(); // Don't await - let it run in background

        // Subscribe to knowledge topic (non-blocking)
        NotificationService().subscribeToKnowledgeTopic().catchError((e) {
          debugPrint('⚠️ Could not subscribe to topic: $e');
        });

        if (!mounted) return;

        final pendingKnowledge = NotificationService.consumePendingKnowledgePayload();
        // Navigate to NewSalePage for regular users
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) => NewSalePage(
              uid: sessionData.uid,
              userEmail: sessionData.email,
            ),
          ),
        );

        if (pendingKnowledge != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => KnowledgePage(
                  onBack: () => Navigator.pop(context),
                ),
              ),
            );
          });
        }
      } else {
        // User is NOT logged in
        debugPrint('🔓 No session found, showing login');
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error in splash navigation: $e');
      // Fallback: show login page
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _forceLogoutSub?.cancel();
    super.dispose();
  }

  /// Request Bluetooth and location permissions for printer connectivity
  /// This is now a public static method that can be called when needed
  static Future<bool> requestBluetoothPermissions() async {
    // Skip on web - Bluetooth not supported
    if (kIsWeb) {
      debugPrint('⚠️ Bluetooth not supported on web');
      return false;
    }

    try {
      // Request Bluetooth permissions (Android 12+)
      final bluetoothStatus = await Permission.bluetooth.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Request location permission (required for Bluetooth scanning on Android)
      final locationStatus = await Permission.location.request();

      // If all permissions granted, enable Bluetooth
      if (bluetoothStatus.isGranted && scanStatus.isGranted && connectStatus.isGranted && locationStatus.isGranted) {
        try {
          await FlutterBluePlus.turnOn();
          debugPrint('✅ Bluetooth enabled successfully');
          return true;
        } catch (e) {
          debugPrint('⚠️ Error enabling Bluetooth: $e');
          return true; // Still return true if permissions granted
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size to determine device type
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final diagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight);

    // Determine if device is tablet/iPad (diagonal > 7 inches assuming ~160 dpi)
    // Typically tablets have diagonal > 1100 pixels
    final isTablet = diagonal > 1100 || screenWidth > 600;

    // Choose appropriate splash image with correct file extension
    final splashImage = isTablet ? 'assets/MAX_my_bill_tab.png' : 'assets/MAX_my_bill_mobile.png';

    return Scaffold(
      backgroundColor: const Color(0xff4456E0),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                splashImage,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.asset(
                      'assets/diamond.gif',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}