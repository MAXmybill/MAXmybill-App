import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxmybill/Colors.dart';
import 'package:maxmybill/Stocks/AddProduct.dart';
import 'package:maxmybill/Menu/Menu.dart' hide kPrimaryColor;
import 'package:shared_preferences/shared_preferences.dart';

class SignupTourPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const SignupTourPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<SignupTourPage> createState() => _SignupTourPageState();
}

class _SignupTourPageState extends State<SignupTourPage> {
  void _skipTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTourActive', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(
          builder: (context) => MenuPage(uid: widget.uid, userEmail: widget.userEmail),
        ),
        (route) => false,
      );
    }
  }

  void _startTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTourActive', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (context) => AddProductPage(
            uid: widget.uid, 
            userEmail: widget.userEmail,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Removes the back button
        actions: [
          TextButton(
            onPressed: _skipTour,
            child: const Text(
              "Skip Tour",
              style: TextStyle(
                color: kBlack54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EE6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const HeroIcon(
                HeroIcons.sparkles,
                color: Color(0xFF6B4EE6),
                size: 80,
                style: HeroIconStyle.solid,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Welcome to MAXmybill!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kBlack87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EE6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "⭐ 15-Day Free MAX Plus Trial Active",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Let's get your store set up in 3 quick steps:\n\n1. Add a Product\n2. Create a Bill\n3. Connect a Printer",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: kBlack54,
                height: 1.6,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startTour,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Start Guided Tour",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
