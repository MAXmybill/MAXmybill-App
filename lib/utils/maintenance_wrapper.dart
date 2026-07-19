import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
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
  Timer? _timer;

  bool _isAdmin = false;
  bool _isMaintenanceActive = false;
  bool _hasShownPreviewPopup = false;
  bool _hasShownOneMinWarning = false;

  bool _enabled = false;
  DateTime? _startedAt;
  DateTime? _endAt;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _setupMaintenanceListener();
    _startTimer();
  }

  @override
  void dispose() {
    _maintenanceSub?.cancel();
    _authSub?.cancel();
    _timer?.cancel();
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
            _enabled = false;
            _startedAt = null;
            _endAt = null;
            _message = '';
            _isMaintenanceActive = false;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final enabled = data['enabled'] ?? false;
      final startedAt = _parseDateTime(data['startedAt']);
      final endAt = _parseDateTime(data['endAt']);
      final message = data['message'] ?? 'We are currently performing maintenance to improve our services.';

      if (mounted) {
        setState(() {
          // If schedule has changed, reset warning triggers
          if (_startedAt != startedAt || _enabled != enabled) {
            _hasShownOneMinWarning = false;
            _hasShownPreviewPopup = false;
          }

          _enabled = enabled;
          _startedAt = startedAt;
          _endAt = endAt;
          _message = message;
        });
      }
    });
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkMaintenanceStatus();
    });
  }

  void _checkMaintenanceStatus() {
    if (_isAdmin || !_enabled || _startedAt == null || _endAt == null) {
      if (mounted && _isMaintenanceActive) {
        setState(() {
          _isMaintenanceActive = false;
        });
      }
      return;
    }

    final now = DateTime.now();

    // Check if maintenance is currently active
    final isActive = now.isAfter(_startedAt!) && now.isBefore(_endAt!);

    if (mounted && isActive != _isMaintenanceActive) {
      setState(() {
        _isMaintenanceActive = isActive;
      });
    }

    // 1-minute warning check
    if (!isActive && now.isBefore(_startedAt!)) {
      final difference = _startedAt!.difference(now);
      if (difference.inSeconds <= 60 && difference.inSeconds > 0 && !_hasShownOneMinWarning) {
        _hasShownOneMinWarning = true;
        _showOneMinuteWarningDialog(difference.inSeconds);
      }
    }

    // Scheduled maintenance preview check (when opening the app)
    if (!isActive && now.isBefore(_startedAt!) && !_hasShownPreviewPopup) {
      _hasShownPreviewPopup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showScheduledMaintenancePopup();
      });
    }
  }

  void _showOneMinuteWarningDialog(int secondsRemaining) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              HeroIcon(HeroIcons.exclamationTriangle, color: kOrange, size: 24),
              SizedBox(width: 8),
              Text(
                'Maintenance Starting Soon',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The application will undergo scheduled maintenance in less than 1 minute.',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBlack87),
              ),
              const SizedBox(height: 8),
              Text(
                'Kindly save your progress and exit the app to avoid data loss.',
                style: TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }

  void _showScheduledMaintenancePopup() {
    if (!mounted || _startedAt == null || _endAt == null) return;
    
    final formattedStart = DateFormat('dd MMM yyyy, hh:mm a').format(_startedAt!);
    final formattedEnd = DateFormat('hh:mm a').format(_endAt!);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              HeroIcon(HeroIcons.calendarDays, color: kPrimaryColor, size: 24),
              SizedBox(width: 8),
              Text(
                'Scheduled Maintenance',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A maintenance window has been scheduled for:',
                style: TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kGreyBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: Row(
                  children: [
                    const HeroIcon(HeroIcons.clock, color: kPrimaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$formattedStart to $formattedEnd',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kBlack87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _message,
                style: const TextStyle(fontSize: 12, color: kBlack87, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMaintenanceActive && !_isAdmin) {
      return _buildMaintenanceBlockScreen();
    }
    return widget.child;
  }

  Widget _buildMaintenanceBlockScreen() {
    final formattedEnd = _endAt != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(_endAt!) 
        : 'soon';

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
                    : 'We are currently performing maintenance to improve your experience. Please check back later.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: kBlack54,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGrey200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HeroIcon(HeroIcons.clock, color: kOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated end time: $formattedEnd',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kBlack87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
