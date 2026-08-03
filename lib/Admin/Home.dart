import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
// notification logic moved to KnowledgeEditorPage
import 'KnowledgeEditorPage.dart';
import 'SupportPage.dart';
import 'package:maxmybill/Auth/LoginPage.dart';
import 'package:maxmybill/Colors.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const HomePage({super.key, required this.uid, this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text('Admin Console',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.arrowRightOnRectangle, color: kWhite, size: 22),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                  );
                }
              } catch (e) {
                debugPrint('Logout error: $e');
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            color: kWhite,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGrey200),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kPrimaryColor,
                ),
                dividerColor: Colors.transparent,
                labelColor: kWhite,
                unselectedLabelColor: kBlack54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.2),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.buildingStorefront, size: 14), SizedBox(width: 4), Text('Stores')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.bookOpen, size: 14), SizedBox(width: 4), Text('Knowledge')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [HeroIcon(HeroIcons.lifebuoy, size: 14), SizedBox(width: 4), Text('Support')])),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StoresTab(adminEmail: widget.userEmail),
          const KnowledgeTab(),
          const SupportTab(),
        ],
      ),
    );
  }
}

// ==========================================
// STORES TAB (REMASTERED)
// ==========================================
class StoresTab extends StatelessWidget {
  final String? adminEmail;
  const StoresTab({super.key, this.adminEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('store').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(HeroIcons.buildingStorefront, 'No stores registered yet.');
        }

        final stores = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final store = stores[index];
            final data = store.data() as Map<String, dynamic>;
            final businessName = data['businessName'] ?? 'Unknown Store';
            final ownerName = data['ownerName'] ?? 'N/A';
            final plan = data['plan'] ?? 'Free';
            final isActive = data['isActive'] ?? true;

            return Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StoreDetailPage(storeId: store.id, storeData: data))),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 48, width: 48,
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                    businessName.isNotEmpty ? businessName[0].toUpperCase() : 'S',
                                    style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w900, fontSize: 18)
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(businessName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kBlack87)),
                                  const SizedBox(height: 2),
                                  Text(ownerName, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            _buildPlanBadge(plan),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: kGrey100)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusBadge(isActive),
                            const HeroIcon(HeroIcons.chevronRight, size: 12, color: kGrey400),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanBadge(String plan) {
    bool isPremium = plan.toLowerCase() == 'MAX Pro' || plan.toLowerCase() == 'MAX Plus';
    Color c = isPremium ? Colors.amber.shade800 : kBlack54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPremium ? Colors.amber.shade50 : kGreyBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPremium ? Colors.amber.shade100 : kGrey200),
      ),
      child: Text(plan,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c, letterSpacing: 0.5)),
    );
  }

  Widget _buildStatusBadge(bool active) {
    Color c = active ? kGoogleGreen : kErrorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(active ? 'Active' : 'Deactivated',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ==========================================
// KNOWLEDGE TAB (REMASTERED)
// ==========================================
class KnowledgeTab extends StatelessWidget {
  const KnowledgeTab({super.key});

  String _getRelativeTime(dynamic timestamp) {
    if (timestamp == null) return 'now';
    
    try {
      DateTime postTime;
      if (timestamp is Timestamp) {
        postTime = timestamp.toDate();
      } else {
        return 'now';
      }

      final now = DateTime.now();
      final difference = now.difference(postTime);

      if (difference.inSeconds < 60) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return DateFormat('dd MMM').format(postTime);
      }
    } catch (e) {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('knowledge').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(HeroIcons.lightBulb, 'Knowledge base is empty.');
          }

          final posts = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              return Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => KnowledgeEditorPage(docId: posts[index].id, data: data))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top small meta row (time / actions)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getRelativeTime(data['createdAt']), style: const TextStyle(fontSize: 11, color: kBlack54)),
                              Container(
                                width: 28, height: 20,
                                decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(10)),
                                child: const Center(child: HeroIcon(HeroIcons.chevronUp, size: 14, color: kBlack54)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title row
                          Text(data['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 13)),
                          const SizedBox(height: 6),
                          // Content line below
                          Text(data['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kBlack54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const KnowledgeEditorPage())),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        label: const Text('Post Article', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
        icon: const HeroIcon(HeroIcons.plus, color: kWhite, size: 20),
      ),
    );
  }
}

// ==========================================
// SUPPORT TAB
// ==========================================
class SupportTab extends StatelessWidget {
  const SupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('support_requests').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(HeroIcons.lifebuoy, 'No support requests pending.');
          }

          // Filter and sort locally to avoid composite index requirement
          var requests = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            return status != 'resolved';
          }).toList();

          // Sort by status then by createdAt
          requests.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aStatus = aData['status'] ?? 'pending';
            final bStatus = bData['status'] ?? 'pending';
            
            // First sort by status
            int statusCompare = aStatus.compareTo(bStatus);
            if (statusCompare != 0) return statusCompare;
            
            // Then sort by createdAt descending
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (requests.isEmpty) {
            return _buildEmptyState(HeroIcons.lifebuoy, 'No support requests pending.');
          }

           return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final status = data['status'] ?? 'pending';
              final statusColor = status == 'pending' ? Colors.orange : (status == 'in_progress' ? kPrimaryColor : kGoogleGreen);

              return Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGrey200),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SupportPage(requestId: requestId, requestData: data))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top meta row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getRelativeTime(data['createdAt']), style: const TextStyle(fontSize: 11, color: kBlack54)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.2)),
                                ),
                                child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Store/User info
                          Text(data['storeName'] ?? 'Unknown Store', style: const TextStyle(fontWeight: FontWeight.w800, color: kBlack87, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(data['subject'] ?? 'No subject', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kBlack54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getRelativeTime(dynamic timestamp) {
    if (timestamp == null) return 'now';
    
    try {
      DateTime postTime;
      if (timestamp is Timestamp) {
        postTime = timestamp.toDate();
      } else {
        return 'now';
      }

      final now = DateTime.now();
      final difference = now.difference(postTime);

      if (difference.inSeconds < 60) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else {
        return DateFormat('dd MMM').format(postTime);
      }
    } catch (e) {
      return 'now';
    }
  }
}

// ==========================================
// STORE DETAIL PAGE (REMASTERED)
// ==========================================
class StoreDetailPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;

  const StoreDetailPage({super.key, required this.storeId, required this.storeData});

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: Text(widget.storeData['businessName'] ?? 'Store Details',
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
        backgroundColor: kPrimaryColor, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('store').doc(widget.storeId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          // Fallback to widget.storeData if the stream hasn't loaded yet
          final storeData = snapshot.hasData ? (snapshot.data!.data() as Map<String, dynamic>? ?? {}) : widget.storeData;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enterprise Overview Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderTag(storeData['plan'] ?? 'Free'),
                      _buildHeaderTag(storeData['isActive'] == true ? 'Active' : 'Inactive'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Preview Revenue', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  const Text('0.00', style: TextStyle(color: kWhite, fontSize: 32, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionLabel('REAL-TIME ANALYTICS'),
            Row(
              children: [
                Expanded(child: _buildEnterpriseStat(widget.storeId, 'Products', 'Products', HeroIcons.archiveBox, kPrimaryColor)),
                const SizedBox(width: 12),
                Expanded(child: _buildEnterpriseStat(widget.storeId, 'Sales', 'sales', HeroIcons.banknotes, kGoogleGreen)),
                const SizedBox(width: 12),
                Expanded(child: _buildEnterpriseStat(widget.storeId, 'Customers', 'customers', HeroIcons.users, kOrange)),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionLabel('Business Identity'),
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              child: Column(
                children: [
                  _detailRow(HeroIcons.user, 'Legal Owner', storeData['ownerName']),
                  _detailRow(HeroIcons.envelope, 'System Email', storeData['ownerEmail']),
                  _detailRow(HeroIcons.phone, 'Direct Phone', storeData['ownerPhone'] ?? storeData['businessPhone']),
                  _detailRow(HeroIcons.mapPin, 'Business Address', storeData['businessLocation']),
                  _detailRow(HeroIcons.documentText, 'Tax', storeData['gstin']),
                  _detailRow(HeroIcons.briefcase, 'License', storeData['licenseNumber'], isLast: true),


                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionLabel('Subscription Details'),
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              child: Column(
                children: [
                  _editableDetailRow(
                    context,
                    icon: HeroIcons.calendar,
                    label: 'Subscription Start',
                    value: _formatDate(storeData['subscriptionStartDate']),
                    onEdit: () => _editDate(context, 'subscriptionStartDate', storeData['subscriptionStartDate']),
                  ),
                  _editableDetailRow(
                    context,
                    icon: HeroIcons.calendarDays,
                    label: 'Subscription Expiry',
                    value: _formatDate(storeData['subscriptionExpiryDate']),
                    onEdit: () => _editDate(context, 'subscriptionExpiryDate', storeData['subscriptionExpiryDate']),
                  ),
                  _editableDetailRow(
                    context,
                    icon: HeroIcons.academicCap,
                    label: 'Current Plan',
                    value: storeData['plan'] ?? 'Free',
                    onEdit: () => _showChangePlanDialog(context, storeData),
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editableDetailRow(BuildContext context, {required HeroIcons icon, required String label, required String value, required VoidCallback onEdit, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: kGrey100))),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)),
          child: HeroIcon(icon, color: kPrimaryColor, size: 18),
        ),
        title: Text(label, style: const TextStyle(fontSize: 8, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
        trailing: IconButton(
          icon: const HeroIcon(HeroIcons.pencil, size: 18, color: kPrimaryColor),
          onPressed: onEdit,
          tooltip: 'Edit',
        ),
      ),
    );
  }

  void _editDate(BuildContext context, String fieldName, dynamic currentDate) async {
    DateTime initialDate = DateTime.now();

    // Parse current date if available
    if (currentDate != null) {
      try {
        if (currentDate is Timestamp) {
          initialDate = currentDate.toDate();
        } else if (currentDate is String) {
          initialDate = DateTime.parse(currentDate);
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('store').doc(widget.storeId).update({
          fieldName: pickedDate.toIso8601String(),
          'dateUpdatedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${fieldName == 'subscriptionStartDate' ? 'Start' : 'Expiry'} date updated successfully!'),
              backgroundColor: kGoogleGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating date: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update date'), backgroundColor: kErrorColor),
          );
        }
      }
    }
  }

  void _showChangePlanDialog(BuildContext context, Map<String, dynamic> storeData) {
    String currentPlan = storeData['plan'] ?? 'Free';
    String selectedPlan = currentPlan;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Change Plan', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select new plan:', style: TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...['Free', 'MAX One', 'MAX Plus', 'MAX Pro'].map((plan) => RadioListTile<String>(
                title: Text(plan, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                value: plan,
                groupValue: selectedPlan,
                activeColor: kPrimaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() => selectedPlan = value!);
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w900, fontSize: 12)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('store').doc(widget.storeId).update({
                    'plan': selectedPlan,
                    'planUpdatedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Plan updated to $selectedPlan successfully!'),
                        backgroundColor: kGoogleGreen,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating plan: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update plan'), backgroundColor: kErrorColor),
                    );
                  }
                }
              },
              child: const Text('Update Plan', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.5)),
  );

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not Set';
    try {
      if (dateValue is Timestamp) {
        return DateFormat('dd MMM yyyy').format(dateValue.toDate());
      } else if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return DateFormat('dd MMM yyyy').format(date);
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return 'Invalid Date';
  }

  Widget _buildHeaderTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: kWhite.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: kWhite, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildEnterpriseStat(String sId, String label, String collection, HeroIcons icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('store').doc(sId).collection(collection).snapshots(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? '${snapshot.data!.docs.length}' : '...';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), child: HeroIcon(icon, color: color, size: 20)),
              const SizedBox(height: 10),
              Text(count, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kBlack87)),
              Text(label, style: const TextStyle(color: kBlack54, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(HeroIcons icon, String label, String? value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: kGrey100))),
      child: ListTile(
        dense: true,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(8)), child: HeroIcon(icon, color: kPrimaryColor, size: 18)),
        title: Text(label, style: const TextStyle(fontSize: 8, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        subtitle: Text(value ?? 'Not Set', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87)),
      ),
    );
  }
}

Widget _buildEmptyState(HeroIcons icon, String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HeroIcon(icon, size: 64, color: kGrey300),
        const SizedBox(height: 16),
        Text(msg, style: const TextStyle(color: kBlack54, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    ),
  );
}
