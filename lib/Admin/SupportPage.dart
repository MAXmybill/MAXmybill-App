import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxmybill/Colors.dart';
import 'package:intl/intl.dart';

class SupportPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const SupportPage({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _responseController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _responseController.dispose();
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
        title: const Text(
          'Support Request',
          style: TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('support_requests')
            .doc(widget.requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            );
          }

          final requestData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGrey200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store and Date Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From Store',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: kBlack54,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                requestData['storeName'] ?? 'Unknown Store',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: kBlack87,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatDate(requestData['createdAt']),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: kBlack54,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildStatusBadge(
                                requestData['status'] ?? 'pending',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: kGrey100),
                      const SizedBox(height: 16),
                      // Subject
                      Text(
                        'Subject',
                        style: const TextStyle(
                          fontSize: 9,
                          color: kBlack54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        requestData['subject'] ?? 'No subject',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kBlack87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Message
                      Text(
                        'Message',
                        style: const TextStyle(
                          fontSize: 9,
                          color: kBlack54,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kGreyBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          requestData['message'] ?? 'No message',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kBlack87,
                            height: 1.6,
                          ),
                        ),
                      ),
                      if (requestData['category'] != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: kPrimaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                requestData['category'] ?? 'General',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: kPrimaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: kGreyBg,
                    borderRadius: BorderRadius.circular(12),
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
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HeroIcon(HeroIcons.chatBubbleLeftRight, size: 14),
                            SizedBox(width: 6),
                            Text('Current', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HeroIcon(HeroIcons.clock, size: 14),
                            SizedBox(width: 6),
                            Text('History', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Tab View
                SizedBox(
                  height: MediaQuery.of(context).size.height - 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCurrentTab(requestData),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentTab(Map<String, dynamic> requestData) {
    final status = requestData['status'] ?? 'pending';

    return Column(
      children: [
        // Admin Response Section
        Expanded(
          child:
              requestData['adminResponse'] != null &&
                  requestData['adminResponse'].toString().isNotEmpty
              ? Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kGoogleGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: kGoogleGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const HeroIcon(
                              HeroIcons.checkCircle,
                              size: 20,
                              color: kGoogleGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Response',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: kBlack54,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (requestData['respondedAt'] != null)
                                Text(
                                  _formatDate(requestData['respondedAt']),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: kGoogleGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kGrey50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          requestData['adminResponse'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: kBlack87,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HeroIcon(
                          HeroIcons.chatBubbleOvalLeftEllipsis,
                          size: 48,
                          color: kGrey300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No response yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: kBlack54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Response Input Section
        if (status != 'resolved')
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kGrey200)),
              color: kWhite,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _responseController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type your response here...',
                    hintStyle: const TextStyle(color: kBlack54),
                    filled: true,
                    fillColor: kGreyBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGrey200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kGrey200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: kPrimaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const HeroIcon(
                          HeroIcons.checkCircle,
                          size: 18,
                          color: kWhite,
                        ),
                        label: const Text(
                          'Supported',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGoogleGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitResponse(status: 'resolved'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const HeroIcon(
                          HeroIcons.clock,
                          size: 18,
                          color: kWhite,
                        ),
                        label: const Text(
                          'In Progress',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitResponse(status: 'in_progress'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final currentUid = widget.requestData['uid']?.toString();
    final currentStoreId = widget.requestData['storeId']?.toString();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HeroIcon(HeroIcons.clock, size: 48, color: kGrey300),
                const SizedBox(height: 12),
                const Text(
                  'No support history',
                  style: TextStyle(
                    fontSize: 13,
                    color: kBlack54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docId = doc.id;

          if (docId == widget.requestId) {
            return false;
          }

          final docUid = data['uid']?.toString();
          final docStoreId = data['storeId']?.toString();

          if (currentUid != null && currentUid.isNotEmpty) {
            return docUid == currentUid;
          }

          if (currentStoreId != null && currentStoreId.isNotEmpty) {
            return docStoreId == currentStoreId;
          }

          return false;
        }).toList();

        requests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HeroIcon(HeroIcons.clock, size: 48, color: kGrey300),
                const SizedBox(height: 12),
                const Text(
                  'No support history for this request',
                  style: TextStyle(
                    fontSize: 13,
                    color: kBlack54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final statusColor = status == 'pending'
                ? Colors.orange
                : (status == 'in_progress' ? kPrimaryColor : kGoogleGreen);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGrey200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['subject'] ?? 'No subject',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: kBlack87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(data['createdAt']),
                    style: const TextStyle(
                      fontSize: 10,
                      color: kBlack54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (data['adminResponse'] != null &&
                      data['adminResponse'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kGrey50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Response:',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: kBlack54,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['adminResponse'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kBlack87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'pending'
        ? Colors.orange
        : (status == 'in_progress' ? kPrimaryColor : kGoogleGreen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      if (dateValue is Timestamp) {
        return DateFormat('dd MMM yyyy, hh:mm a').format(dateValue.toDate());
      } else if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return DateFormat('dd MMM yyyy, hh:mm a').format(date);
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return 'Invalid Date';
  }

  Future<void> _submitResponse({required String status}) async {
    final responseText = _responseController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final updates = <String, dynamic>{
        'status': status,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (responseText.isNotEmpty) {
        updates['adminResponse'] = responseText;
        updates['respondedAt'] = FieldValue.serverTimestamp();
        updates['responses'] = FieldValue.arrayUnion([
          {
            'message': responseText,
            'status': status,
            'respondedAt': Timestamp.now(),
            'by': 'admin',
          },
        ]);
      }

      await FirebaseFirestore.instance
          .collection('support_requests')
          .doc(widget.requestId)
          .update(updates);

      if (mounted) {
        _responseController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request marked as ${status.replaceAll('_', ' ')}'),
            backgroundColor: kGoogleGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit response'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
