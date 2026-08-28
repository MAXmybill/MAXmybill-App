import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:maxmybill/Colors.dart';
import 'package:maxmybill/utils/plan_provider.dart';
import 'package:maxmybill/Auth/SubscriptionPlanPage.dart';

class PlanExpiryPopup extends StatelessWidget {
  final String uid;
  final PlanProvider planProvider;

  const PlanExpiryPopup({
    super.key,
    required this.uid,
    required this.planProvider,
  });

  static bool _isDialogOpen = false;

  /// Tracks whether the popup was already shown in the current app session
  static bool hasShownThisSession = false;

  /// Check if the plan is expiring within 3 days (or expired) and show the popup once per session
  static Future<void> checkAndShow(
    BuildContext context, {
    required String uid,
    bool force = false,
  }) async {
    // Only show once per app session (unless forced)
    if (hasShownThisSession && !force) return;
    if (_isDialogOpen) return;

    final planProvider = context.read<PlanProvider>();
    if (!planProvider.isInitialized) {
      await planProvider.initialize();
    }

    final expiryDate = planProvider.cachedExpiryDate;
    if (expiryDate == null) return;

    // Do not show for permanent free plan with no previous paid plan
    final rawPlan = planProvider.originalPlan.trim().toLowerCase();
    final cachedPlan = planProvider.cachedPlan.trim().toLowerCase();
    if (rawPlan == 'free' && cachedPlan == 'free') {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysLeft = expiryDay.difference(today).inDays;

    // Trigger popup if expiring within 3 days (3, 2, 1, 0, or expired)
    if (daysLeft <= 3 && context.mounted) {
      hasShownThisSession = true; // Mark as shown for this app session
      _isDialogOpen = true;
      try {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => PlanExpiryPopup(
            uid: uid,
            planProvider: planProvider,
          ),
        );
      } finally {
        _isDialogOpen = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiryDate = planProvider.cachedExpiryDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = expiryDate != null
        ? DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
        : today;
    final daysLeft = expiryDay.difference(today).inDays;

    final String planName = (planProvider.originalPlan.isNotEmpty && planProvider.originalPlan.toLowerCase() != 'free')
        ? planProvider.originalPlan
        : (planProvider.cachedPlan.isNotEmpty ? planProvider.cachedPlan : 'Premium');

    final String formattedDate = expiryDate != null
        ? DateFormat('dd MMM yyyy').format(expiryDate)
        : 'Soon';

    // Dynamic messaging and styling based on daysLeft
    String badgeText;
    String titleText;
    String descriptionText;
    Color badgeColor;
    HeroIcons iconData;

    if (daysLeft < 0) {
      badgeText = 'PLAN EXPIRED';
      titleText = 'Your Plan Has Expired';
      descriptionText = 'Your $planName subscription expired on $formattedDate. Renew now to restore full access to unlimited billing, multiple staff accounts, inventory management, and reports.';
      badgeColor = kErrorColor;
      iconData = HeroIcons.exclamationTriangle;
    } else if (daysLeft == 0) {
      badgeText = 'EXPIRES TODAY';
      titleText = 'Plan Expires Today!';
      descriptionText = 'Your $planName subscription expires today ($formattedDate). Renew immediately to avoid any interruption in your daily billing operations.';
      badgeColor = kErrorColor;
      iconData = HeroIcons.clock;
    } else if (daysLeft == 1) {
      badgeText = 'EXPIRES TOMORROW';
      titleText = 'Plan Expires Tomorrow!';
      descriptionText = 'Your $planName subscription will expire tomorrow ($formattedDate). Renew today to keep enjoying all premium features seamlessly.';
      badgeColor = kOrange;
      iconData = HeroIcons.clock;
    } else if (daysLeft == 2) {
      badgeText = '2 DAYS REMAINING';
      titleText = 'Plan Expiring in 2 Days';
      descriptionText = 'You have only 2 days remaining on your $planName plan (valid till $formattedDate). Renew now for uninterrupted service.';
      badgeColor = kOrange;
      iconData = HeroIcons.clock;
    } else {
      // 3 days
      badgeText = '3 DAYS REMAINING';
      titleText = 'Plan Expiring in 3 Days';
      descriptionText = 'Your $planName subscription is expiring in 3 days on $formattedDate. Renew now to stay on top of your business.';
      badgeColor = kOrange;
      iconData = HeroIcons.clock;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  // Icon badge container
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: HeroIcon(
                        iconData,
                        color: badgeColor,
                        size: 30,
                      ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFF3F4F6),
                      ),
                      child: const Center(
                        child: HeroIcon(HeroIcons.xMark, color: kBlack54, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Pill chip badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontFamily: 'Lato',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: kBlack87,
                  fontFamily: 'NotoSans',
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                descriptionText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: kBlack54,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Plan summary card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGrey200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Current Plan",
                            style: TextStyle(
                              fontSize: 11,
                              color: kBlack54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const HeroIcon(HeroIcons.sparkles, size: 15, color: kPrimaryColor),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  planName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: kBlack87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: kGrey200,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Expiry Date",
                            style: TextStyle(
                              fontSize: 11,
                              color: kBlack54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              HeroIcon(HeroIcons.calendar, size: 15, color: badgeColor),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Feature benefit chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeaturePill("Unlimited Billing", HeroIcons.bolt),
                  _buildFeaturePill("Staff Logins", HeroIcons.users),
                  _buildFeaturePill("Cloud Reports", HeroIcons.chartBar),
                ],
              ),

              const SizedBox(height: 18),

              // Renew Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SubscriptionPlanPage(
                          uid: uid,
                          currentPlan: planProvider.cachedPlan,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeroIcon(
                        daysLeft < 0 ? HeroIcons.arrowPath : HeroIcons.bolt,
                        color: kWhite,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        daysLeft < 0 ? 'Renew Subscription Now' : 'Renew / Extend Plan',
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Dismiss / Remind Me Later
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Remind Me Later',
                  style: TextStyle(
                    color: kBlack54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String label, HeroIcons icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeroIcon(icon, size: 11, color: kPrimaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kBlack87,
            ),
          ),
        ],
      ),
    );
  }
}
