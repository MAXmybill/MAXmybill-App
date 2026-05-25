import 'package:flutter/material.dart';

const Color kPremiumLockBorder = Color(0xFFE7C977);
const Color kPremiumLockIcon = kPremiumLockBorder;

class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/diamond.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class PremiumLockIconWrapper extends StatelessWidget {
  const PremiumLockIconWrapper({
    super.key,
    required this.child,
    required this.isLocked,
    this.badgeSize = 12,
  });

  final Widget child;
  final bool isLocked;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -3,
          top: -4,
          child: PremiumLockBadge(size: badgeSize),
        ),
      ],
    );
  }
}

BorderSide premiumLockBorderSide(bool isLocked) {
  return BorderSide(color: isLocked ? kPremiumLockBorder : const Color(0xFFE5E7EB));
}
