import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:maxmybill/Colors.dart';

class MaintenanceWrapper extends StatefulWidget {
  final Widget child;

  const MaintenanceWrapper({super.key, required this.child});

  @override
  State<MaintenanceWrapper> createState() => _MaintenanceWrapperState();
}

class _MaintenanceWrapperState extends State<MaintenanceWrapper> {
  StreamSubscription<DocumentSnapshot>? _maintenanceSub;
  StreamSubscription<User?>? _authSub;

  bool _isAdmin = false;
  
  bool _isUnderMaintenance = false;
  String _minAppVersion = '1.0.0';
  bool _forceUpdate = false;
  String _message = '';

  String _currentAppVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _setupAuthListener();
    _setupMaintenanceListener();
  }
  
  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentAppVersion = info.version;
      });
    }
  }

  @override
  void dispose() {
    _maintenanceSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _isAdmin = user != null && user.email?.toLowerCase() == 'maxmybillapp@gmail.com';
        });
      }
    });
  }

  void _setupMaintenanceListener() {
    _maintenanceSub = FirebaseFirestore.instance
        .collection('settings')
        .doc('maintenance')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _isUnderMaintenance = false;
            _message = '';
            _forceUpdate = false;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final isUnderMaintenance = data['isUnderMaintenance'] ?? false;
      final minVersion = data['minAppVersion'] ?? '1.0.0';
      final forceUp = data['forceUpdate'] ?? false;
      final message = data['message'] ?? '';

      if (mounted) {
        setState(() {
          _isUnderMaintenance = isUnderMaintenance;
          _minAppVersion = minVersion;
          _forceUpdate = forceUp;
          _message = message;
        });
      }
    });
  }

  int _compareVersions(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      int p1 = i < v1Parts.length ? v1Parts[i] : 0;
      int p2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnderMaintenance && !_isAdmin) {
      return _buildMaintenanceBlockScreen();
    }

    if (_forceUpdate && !_isAdmin && _compareVersions(_minAppVersion, _currentAppVersion) > 0) {
      return _buildForceUpdateScreen();
    }

    if (_message.isNotEmpty) {
      return Column(
        children: [
          Material(
            color: kOrange.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kOrange, width: 2)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const HeroIcon(HeroIcons.megaphone, color: kOrange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message,
                        style: const TextStyle(
                          color: kOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      );
    }

    return widget.child;
  }

  Widget _buildMaintenanceBlockScreen() {
    return Scaffold(
      backgroundColor: kGreyBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const HeroIcon(
                  HeroIcons.wrenchScrewdriver,
                  size: 64,
                  color: kPrimaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Under Maintenance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kBlack87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _message.isNotEmpty
                    ? _message
                    : 'We are currently performing scheduled maintenance to improve your experience. Please check back later.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: kBlack54,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForceUpdateScreen() {
    return Scaffold(
      backgroundColor: kGreyBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kGoogleGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const HeroIcon(
                  HeroIcons.arrowDownTray,
                  size: 64,
                  color: kGoogleGreen,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kBlack87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A new version of the app is available and required to continue. Please update your app to the latest version.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: kBlack54,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGoogleGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  // In a real app, use url_launcher to open app store/play store
                },
                child: const Text('Update Now', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
