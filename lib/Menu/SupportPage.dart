import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maxmybill/Colors.dart' as colors;
import 'package:maxmybill/utils/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportPage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final VoidCallback onBack;

  const SupportPage({
    super.key,
    required this.uid,
    this.userEmail,
    required this.onBack,
  });

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _storeId;
  String _storeName = 'Loading...';
  String _storePhone = '';
  String _storeDisplayNumber = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    try {
      // 1. Try getCurrentStoreDoc for fast / cached store document
      final doc = await FirestoreService().getCurrentStoreDoc();
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final storeId = await FirestoreService().getCurrentStoreId();
        final name = (data['businessName'] ?? data['name'] ?? data['storeName'] ?? 'Store').toString().trim();
        final phone = (data['businessPhone'] ??
                data['phoneNumber'] ??
                data['ownerPhone'] ??
                data['personalPhone'] ??
                data['phone'] ??
                FirebaseAuth.instance.currentUser?.phoneNumber ??
                '')
            .toString()
            .trim();
        final sNum = (data['storeId'] ?? storeId ?? doc.id).toString().trim();

        setState(() {
          _storeId = storeId ?? doc.id;
          _storeName = name.isNotEmpty ? name : 'Store';
          _storePhone = phone;
          _storeDisplayNumber = sNum;
        });
        return;
      }

      // 2. Fallback by ID
      final storeId = await FirestoreService().getCurrentStoreId();
      if (storeId != null && mounted) {
        setState(() => _storeId = storeId);

        final storeDoc = await FirebaseFirestore.instance
            .collection('store')
            .doc(storeId)
            .get();

        if (mounted && storeDoc.exists) {
          final data = storeDoc.data() ?? {};
          final name = (data['businessName'] ?? data['name'] ?? data['storeName'] ?? 'Store').toString().trim();
          final phone = (data['businessPhone'] ??
                  data['phoneNumber'] ??
                  data['ownerPhone'] ??
                  data['personalPhone'] ??
                  data['phone'] ??
                  FirebaseAuth.instance.currentUser?.phoneNumber ??
                  '')
              .toString()
              .trim();
          final sNum = (data['storeId'] ?? storeId).toString().trim();

          setState(() {
            _storeName = name.isNotEmpty ? name : 'Store';
            _storePhone = phone;
            _storeDisplayNumber = sNum;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading store info: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitSupportRequest() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store information not loaded')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('support_requests')
          .add({
        'uid': widget.uid,
        'storeId': _storeId,
        'storeName': _storeName,
        'email': widget.userEmail ?? user.email,
        'subject': _subjectController.text,
        'message': _messageController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'responses': [],
      });

      if (mounted) {
        _subjectController.clear();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openWhatsAppSupport() async {
    const supportPhone = '919994593969';
    final name = _storeName.isNotEmpty && _storeName != 'Loading...' ? _storeName : 'My Store';
    final storeNumber = _storePhone.isNotEmpty
        ? _storePhone
        : (_storeDisplayNumber.isNotEmpty ? _storeDisplayNumber : (_storeId ?? 'N/A'));

    final buffer = StringBuffer();
    buffer.writeln('Hello MAXmybill Support,');
    buffer.writeln('I need help with my store.');
    buffer.writeln('');
    buffer.writeln('Store Name: $name');
    buffer.writeln('Store Number: $storeNumber');
    if (_storeDisplayNumber.isNotEmpty && _storeDisplayNumber != storeNumber) {
      buffer.writeln('Store ID: $_storeDisplayNumber');
    }
    buffer.writeln('');
    buffer.writeln('Please assist me.');

    final message = buffer.toString();
    final encodedMsg = Uri.encodeComponent(message);

    // Try direct WhatsApp scheme first, fallback to https://wa.me
    final whatsappUri = Uri.parse('whatsapp://send?phone=$supportPhone&text=$encodedMsg');
    final webUri = Uri.parse('https://wa.me/$supportPhone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp. Contact: +91 99945 93969'),
              backgroundColor: colors.kErrorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: colors.kGreyBg,
        appBar: AppBar(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: const Text('Help & Support',
              style: TextStyle(color: colors.kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: colors.kPrimaryColor,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: colors.kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: InkWell(
                  onTap: _openWhatsAppSupport,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.chat_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'WhatsApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: colors.kWhite,
            unselectedLabelColor: colors.kWhite.withValues(alpha: 0.7),
            indicatorColor: colors.kWhite,
            tabs: const [
              Tab(text: 'New Request'),
              Tab(text: 'My Requests'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildNewRequestTab(),
            _buildMyRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppSupportCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openWhatsAppSupport,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'WhatsApp Support',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'INSTANT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '+91 99945 93969',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _storeName != 'Loading...'
                              ? '$_storeName • ${_storePhone.isNotEmpty ? _storePhone : (_storeDisplayNumber.isNotEmpty ? 'ID: $_storeDisplayNumber' : 'Store')}'
                              : 'Chat directly with our team on WhatsApp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _openWhatsAppSupport,
                    icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF128C7E)),
                    label: const Text(
                      'Chat on WhatsApp Now',
                      style: TextStyle(
                        color: Color(0xFF128C7E),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWhatsAppSupportCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: colors.kGrey200, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR SUBMIT IN-APP TICKET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colors.kBlack54.withValues(alpha: 0.6),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: colors.kGrey200, thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.kPrimaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.kPrimaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeroIcon(
                      HeroIcons.exclamationCircle,
                      size: 20,
                      color: colors.kPrimaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tell us how we can help',
                        style: TextStyle(
                          color: colors.kPrimaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Describe your issue in detail and we\'ll get back to you as soon as possible.',
                  style: TextStyle(
                    color: colors.kBlack54,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Subject',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colors.kBlack87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              hintText: 'e.g., Issue with bill creation',
              hintStyle: const TextStyle(color: colors.kBlack54, fontSize: 14),
              filled: true,
              fillColor: colors.kWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kGrey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kGrey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kPrimaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          const Text(
            'Message',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colors.kBlack87,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail...',
              hintStyle: const TextStyle(color: colors.kBlack54, fontSize: 14),
              filled: true,
              fillColor: colors.kWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kGrey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kGrey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: colors.kPrimaryColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.kWhite),
                      ),
                    )
                  : const HeroIcon(HeroIcons.paperAirplane, size: 18, color: colors.kWhite),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Request',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.kWhite,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.kPrimaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMyRequestsTab() {
    if (_storeId == null) {
      return const Center(
        child: CircularProgressIndicator(color: colors.kPrimaryColor),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .where('uid', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colors.kPrimaryColor));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: colors.kErrorColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.kGreyBg,
                      shape: BoxShape.circle,
                    ),
                    child: const HeroIcon(
                      HeroIcons.inbox,
                      size: 40,
                      color: colors.kBlack54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No support requests yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.kBlack87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new support request to get help from our team',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.kBlack54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openWhatsAppSupport,
                    icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Chat on WhatsApp (+91 99945 93969)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter by storeId and sort locally
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['storeId'] == _storeId;
        }).toList();

        // Sort by createdAt descending
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.kGreyBg,
                      shape: BoxShape.circle,
                    ),
                    child: const HeroIcon(
                      HeroIcons.inbox,
                      size: 40,
                      color: colors.kBlack54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No support requests yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.kBlack87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new support request to get help from our team',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.kBlack54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openWhatsAppSupport,
                    icon: const Icon(Icons.chat_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Chat on WhatsApp (+91 99945 93969)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildRequestCard(
              title: data['subject'] ?? 'Untitled',
              message: data['message'] ?? '',
              status: data['status'] ?? 'pending',
              createdAt: data['createdAt'] as Timestamp?,
              responses: data['responses'] ?? [],
              adminResponse: data['adminResponse'] as String?,
              respondedAt: data['respondedAt'] as Timestamp?,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard({
    required String title,
    required String message,
    required String status,
    Timestamp? createdAt,
    required List responses,
    String? adminResponse,
    Timestamp? respondedAt,
  }) {
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);
    final timeAgo = _getTimeAgo(createdAt);
    final latestResponse = _getLatestResponseText(responses, adminResponse);
    final responseTime = _getTimeAgo(respondedAt);
    final responseCount = _getResponseCount(responses, adminResponse);

    return Container(
      decoration: BoxDecoration(
        color: colors.kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.kGrey200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.kBlack87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: colors.kBlack54,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (latestResponse != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.kGoogleGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.kGoogleGreen.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HeroIcon(HeroIcons.checkCircle, size: 12, color: colors.kGoogleGreen),
                            const SizedBox(width: 6),
                            const Text(
                              'Admin response',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: colors.kGoogleGreen,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const Spacer(),
                            if (respondedAt != null)
                              Text(
                                responseTime,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: colors.kBlack54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          latestResponse,
                          style: const TextStyle(
                            fontSize: 12,
                            color: colors.kBlack87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 10,
                        color: colors.kBlack54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (responseCount > 0)
                      Row(
                        children: [
                          const HeroIcon(HeroIcons.checkCircle, size: 12, color: colors.kGoogleGreen),
                          const SizedBox(width: 4),
                          Text(
                            '$responseCount response${responseCount > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: colors.kGoogleGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _getLatestResponseText(List responses, String? adminResponse) {
    if (adminResponse != null && adminResponse.trim().isNotEmpty) {
      return adminResponse.trim();
    }

    if (responses.isEmpty) return null;

    final last = responses.last;
    if (last is String && last.trim().isNotEmpty) {
      return last.trim();
    }

    if (last is Map) {
      final data = Map<String, dynamic>.from(last);
      final value = data['message'] ?? data['text'] ?? data['content'] ?? data['response'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return null;
  }

  int _getResponseCount(List responses, String? adminResponse) {
    if (responses.isNotEmpty) return responses.length;
    if (adminResponse != null && adminResponse.trim().isNotEmpty) return 1;
    return 0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'in_progress':
        return const Color(0xFF2196F3);
      case 'resolved':
        return colors.kGoogleGreen;
      default:
        return colors.kBlack54;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'now';
    try {
      final postTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(postTime);

      if (difference.inSeconds < 60) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('dd MMM').format(postTime);
      }
    } catch (e) {
      return 'now';
    }
  }
}

