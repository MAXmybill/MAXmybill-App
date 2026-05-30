import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:maxmybill/Colors.dart';
import 'package:maxmybill/Menu/Menu.dart' as menu_page show CreditDetailsPage;
import 'package:maxmybill/Stocks/StockPurchase.dart';
import 'package:maxmybill/utils/firestore_service.dart';
import 'package:maxmybill/services/currency_service.dart';
import 'package:heroicons/heroicons.dart';

class VendorsPage extends StatefulWidget {
  final String uid;
  final VoidCallback onBack;

  const VendorsPage({super.key, required this.uid, required this.onBack});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _vendors = [];
  bool _isLoading = true;
  String _currencySymbol = '';

  @override
  void initState() {
    super.initState();
    _loadVendors();
    _loadCurrency();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _loadCurrency() async {
    final storeId = await FirestoreService().getCurrentStoreId();
    if (storeId == null) return;
    final doc = await FirebaseFirestore.instance.collection('store').doc(storeId).get();
    if (doc.exists && mounted) {
      setState(() => _currencySymbol = CurrencyService.getSymbolWithSpace(doc.data()?['currency']));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC METHODS (PRESERVED)
  // ==========================================

  Future<void> _loadVendors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
      final snapshot = await vendorsCollection.orderBy('createdAt', descending: true).get();

      final baseVendors = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'gstin': data['gstin'] ?? '',
          'address': data['address'] ?? '',
          'totalPurchases': (data['totalPurchases'] ?? 0.0).toDouble(),
          'purchaseCount': data['purchaseCount'] ?? 0,
          'source': data['source'] ?? '',
          'createdAt': data['createdAt'],
          'lastPurchaseDate': data['lastPurchaseDate'],
        };
      }).toList();

      final vendorsWithCredit = await Future.wait(
        baseVendors.map((vendor) async {
          final pendingCredit = await _getPendingCreditTotalForVendor(vendor);
          return {...vendor, 'pendingCredit': pendingCredit};
        }),
      );

      if (mounted) {
        setState(() {
          _vendors = vendorsWithCredit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading vendors: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVendors {
    if (_searchQuery.isEmpty) return _vendors;
    return _vendors.where((vendor) {
      final name = (vendor['name'] ?? '').toString().toLowerCase();
      final phone = (vendor['phone'] ?? '').toString().toLowerCase();
      final gstin = (vendor['gstin'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          gstin.contains(_searchQuery);
    }).toList();
  }

  String _formatMoney(double value, {int decimals = 0}) {
    if (!value.isFinite) return '${_currencySymbol}0';
    final pattern = decimals == 0 ? '0' : '0.${'0' * decimals}';
    final formatted = NumberFormat(pattern).format(value);
    return '$_currencySymbol$formatted';
  }

  // ==========================================
  // UI BUILD METHODS (ENTERPRISE FLAT)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: kGreyBg,
        appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
          title: const Text('Suppliers',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
            onPressed: widget.onBack,
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
        children: [
          // ENTERPRISE SEARCH HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: kWhite,
              border: Border(bottom: BorderSide(color: kGrey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
                      controller: _searchController,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
                      decoration: InputDecoration(
                        hintText: "Search vendors...",
                        hintStyle: TextStyle(color: kBlack54, fontSize: 14),
                        prefixIcon: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
                        ),
                        labelStyle: TextStyle(color: hasText ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
                        floatingLabelStyle: TextStyle(color: hasText ? kPrimaryColor : kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    
);
      },
    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _showAddVendorDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const HeroIcon(HeroIcons.userPlus, color: kWhite, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // SUMMARY STATS ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: kWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildStat('Vendors', _vendors.length.toString(), HeroIcons.users)),
                Expanded(child: _buildStat(
                  'Total Spent',
                  _formatMoney(_vendors.fold(0.0, (sum, v) => sum + ((v['totalPurchases'] ?? 0).toDouble()))),
                  HeroIcons.banknotes,
                )),
                Expanded(child: _buildStat(
                  'Credit',
                  _formatMoney(_vendors.fold(0.0, (sum, v) => sum + ((v['pendingCredit'] ?? 0).toDouble()))),
                  HeroIcons.wallet,
                )),
                Expanded(child: _buildStat(
                  'Bills',
                  _vendors.fold(0, (sum, v) => sum + ((v['purchaseCount'] ?? 0) as int)).toString(),
                  HeroIcons.documentText,
                )),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // VENDORS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                : _filteredVendors.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: _loadVendors,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _filteredVendors.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildVendorCard(_filteredVendors[index]);
                },
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStat(String label, String value, HeroIcons icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HeroIcon(icon, color: kPrimaryColor, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87),
        ),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final totalPurchases = vendor['totalPurchases'] as double;
    final purchaseCount = vendor['purchaseCount'] as int;
    final pendingCredit = (vendor['pendingCredit'] ?? 0.0).toDouble();
    final isFromStockPurchase = vendor['source'] == 'stock_purchase';
    final phone = (vendor['phone'] ?? '').toString();
    final gstin = (vendor['gstin'] ?? '').toString();

    String lastPurchaseText = '';
    if (vendor['lastPurchaseDate'] != null) {
      try {
        final lastDate = (vendor['lastPurchaseDate'] as Timestamp).toDate();
        lastPurchaseText = DateFormat('dd MMM yyyy').format(lastDate);
      } catch (_) {}
    }

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
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => VendorDetailsPage(vendor: vendor, currencySymbol: _currencySymbol, uid: widget.uid)),
          ).then((_) => _loadVendors()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(children: [
              // Row 1: vendor name | supplier badge or last purchase date
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const HeroIcon(HeroIcons.buildingStorefront, size: 14, color: kOrange),
                  const SizedBox(width: 5),
                  Text(
                    (vendor['name'] ?? 'Unknown').toString().length > 22
                        ? '${(vendor['name'] ?? 'Unknown').toString().substring(0, 22)}…'
                        : (vendor['name'] ?? 'Unknown').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: kOrange, fontSize: 13),
                  ),
                ]),
                if (isFromStockPurchase)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kGoogleGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Supplier', style: TextStyle(fontSize: 8, color: kGoogleGreen, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  )
                else if (lastPurchaseText.isNotEmpty)
                  Text('Last: $lastPurchaseText', style: const TextStyle(fontSize: 10.5, color: Colors.black, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              // Row 2: phone (or gstin) | total spent
              Row(children: [
                Expanded(child: Row(children: [
                  const HeroIcon(HeroIcons.devicePhoneMobile, size: 12, color: kBlack54),
                  const SizedBox(width: 4),
                  Text(phone.isNotEmpty ? phone : (gstin.isNotEmpty ? gstin : '--'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                ])),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_currencySymbol${totalPurchases.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kGoogleGreen)),
                    if (pendingCredit > 0)
                      Text('Credit $_currencySymbol${pendingCredit.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: kErrorColor)),
                  ],
                ),
              ]),
              const Divider(height: 20, color: kGreyBg),
              // Row 3: bills count | popup menu + chevron
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total bills', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kBlack54, letterSpacing: 0.5)),
                  Text('$purchaseCount ${purchaseCount == 1 ? 'bill' : 'bills'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: kBlack87)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _buildPopupMenu(vendor),
                  const SizedBox(width: 4),
                  const HeroIcon(HeroIcons.chevronRight, color: kPrimaryColor, size: 16),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(Map<String, dynamic> vendor) {
    return PopupMenuButton<String>(
      icon: const HeroIcon(HeroIcons.ellipsisVertical, color: kGrey400, size: 20),
      elevation: 0,
      offset: const Offset(0, 40),
      color: kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kPrimaryColor, width: 1),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          _showEditVendorDialog(context, vendor);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context, vendor);
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem('edit', HeroIcons.pencilSquare, 'Edit Profile', kPrimaryColor),
        const PopupMenuDivider(height: 1),
        _buildPopupItem('delete', HeroIcons.trash, 'Remove Vendor', kErrorColor),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, HeroIcons icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: 50,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: HeroIcon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(HeroIcons.users, size: 64, color: kGrey300),
          const SizedBox(height: 16),
          const Text(
            'No suppliers found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kBlack87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Suppliers will be added automatically\nduring product purchases.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kBlack54),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showAddVendorDialog(BuildContext context) {
    final nameCtrl = TextEditingController(), phoneCtrl = TextEditingController(), gstinCtrl = TextEditingController(), addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("Identity"),
              _buildDialogField(nameCtrl, 'Vendor Name *', HeroIcons.user),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', HeroIcons.devicePhoneMobile, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("Tax & Location"),
              _buildDialogField(gstinCtrl, 'GSTIN (Optional)', HeroIcons.documentText),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', HeroIcons.mapPin, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'totalPurchases': 0.0,
                  'purchaseCount': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Add Vendor', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  void _showEditVendorDialog(BuildContext context, Map<String, dynamic> vendor) {
    final nameCtrl = TextEditingController(text: vendor['name']), phoneCtrl = TextEditingController(text: vendor['phone']), gstinCtrl = TextEditingController(text: vendor['gstin']), addressCtrl = TextEditingController(text: vendor['address']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Edit Vendor Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel("Identity"),
              _buildDialogField(nameCtrl, 'Vendor Name', HeroIcons.user),
              const SizedBox(height: 12),
              _buildDialogField(phoneCtrl, 'Phone Number', HeroIcons.devicePhoneMobile, type: TextInputType.phone),
              const SizedBox(height: 20),
              _buildSectionLabel("Tax & Location"),
              _buildDialogField(gstinCtrl, 'GSTIN', HeroIcons.documentText),
              const SizedBox(height: 12),
              _buildDialogField(addressCtrl, 'Physical Address', HeroIcons.mapPin, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Save changes', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, Map<String, dynamic> vendor) async {
    final outstandingCredit = await _getOutstandingCredit(vendor);
    if (outstandingCredit > 0.009) {
      if (!mounted) return;
      await _showDeleteBlockedDialog(context, vendor, outstandingCredit);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Remove Vendor?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text('Are you sure you want to remove "${vendor['name']}"? This action cannot be undone.', style: const TextStyle(color: kBlack54, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54))),
          ElevatedButton(
            onPressed: () async {
              try {
                final vendorsCollection = await FirestoreService().getStoreCollection('vendors');
                await vendorsCollection.doc(vendor['id']).delete();
                if (mounted) { Navigator.pop(context); _loadVendors(); }
              } catch (e) { debugPrint(e.toString()); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: kErrorColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Delete", style: TextStyle(color: kWhite,fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<double> _getOutstandingCredit(Map<String, dynamic> vendor) async {
    try {
      return await _getPendingCreditTotalForVendor(vendor);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _showDeleteBlockedDialog(BuildContext context, Map<String, dynamic> vendor, double dueAmount) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Delete blocked', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text(
          '"${vendor['name'] ?? 'This supplier'}" has pending credit of $_currencySymbol${dueAmount.toStringAsFixed(2)}. Clear credit before deleting.',
          style: const TextStyle(color: kBlack54, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5))));
 
  Widget _buildNoResults() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HeroIcon(HeroIcons.magnifyingGlass, size: 64, color: kGrey300), const SizedBox(height: 16), Text('No results for "$_searchQuery"', style: const TextStyle(color: kBlack54))]));

  Widget _buildDialogField(TextEditingController ctrl, String label, HeroIcons icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
          decoration: InputDecoration(
            hintText: label,
            prefixIcon: HeroIcon(icon, color: hasText ? kPrimaryColor : kBlack54, size: 18),
            filled: true, fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hasText ? kPrimaryColor : kGrey200, width: hasText ? 1.5 : 1.0)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 2.0)),
          ),
        );
      },
    );
  }
}

// ==========================================
// VENDOR DETAILS PAGE
// ==========================================
Future<List<Map<String, dynamic>>> _fetchSupplierPurchases(Map<String, dynamic> vendor) async {
  final col = await FirestoreService().getStoreCollection('stockPurchases');
  final supplierName = (vendor['name'] ?? '').toString();
  final supplierNameNorm = supplierName.trim().toLowerCase();
  final supplierPhone = (vendor['phone'] ?? '').toString().trim();
  final vendorId = (vendor['id'] ?? '').toString().trim();

  final Map<String, Map<String, dynamic>> byId = {};

  void addDocs(Iterable<QueryDocumentSnapshot> docs) {
    for (final d in docs) {
      byId[d.id] = {'id': d.id, ...d.data() as Map<String, dynamic>};
    }
  }

  if (vendorId.isNotEmpty) {
    try {
      final snap = await col.where('vendorId', isEqualTo: vendorId).orderBy('timestamp', descending: true).get();
      addDocs(snap.docs);
    } catch (_) {}
  }

  if (supplierName.isNotEmpty) {
    try {
      final snap = await col.where('supplierName', isEqualTo: supplierName).orderBy('timestamp', descending: true).get();
      addDocs(snap.docs);
    } catch (_) {
      try {
        final snap = await col.where('supplierName', isEqualTo: supplierName).get();
        addDocs(snap.docs);
      } catch (_) {}
    }
  }

  if (byId.isEmpty && supplierPhone.isNotEmpty) {
    try {
      final snap = await col.where('supplierPhone', isEqualTo: supplierPhone).get();
      addDocs(snap.docs);
    } catch (_) {}
  }

  if (byId.isEmpty) {
    try {
      final snap = await col.get();
      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final n = (data['supplierName'] ?? '').toString().trim().toLowerCase();
        final p = (data['supplierPhone'] ?? '').toString().trim();
        final vId = (data['vendorId'] ?? '').toString().trim();
        return (supplierNameNorm.isNotEmpty && n == supplierNameNorm) ||
            (supplierPhone.isNotEmpty && p == supplierPhone) ||
            (vendorId.isNotEmpty && vId == vendorId);
      });
      addDocs(docs);
    } catch (_) {}
  }

  final result = byId.values.toList();
  result.sort((a, b) {
    final tsA = a['timestamp'] as Timestamp?;
    final tsB = b['timestamp'] as Timestamp?;
    if (tsA == null && tsB == null) return 0;
    if (tsA == null) return 1;
    if (tsB == null) return -1;
    return tsB.compareTo(tsA);
  });

  return result;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0.0;
  final cleaned = value.toString().replaceAll(RegExp(r'[^0-9.-]'), '');
  return double.tryParse(cleaned) ?? 0.0;
}

double _remainingCreditFromNote(Map<String, dynamic> note) {
  final explicitRemaining = _toDouble(note['remainingAmount'] ?? note['balanceAmount']);
  if (explicitRemaining > 0) return explicitRemaining;

  final amount = _toDouble(note['amount'] ?? note['totalAmount'] ?? note['creditAmount']);
  final paid = _toDouble(note['paidAmount']);
  final computed = amount - paid;
  return computed > 0 ? computed : 0.0;
}

Future<List<Map<String, dynamic>>> _fetchSupplierCreditNotes(Map<String, dynamic> vendor) async {
  final col = await FirestoreService().getStoreCollection('purchaseCreditNotes');
  final supplierName = (vendor['name'] ?? '').toString().trim();
  final supplierNameNorm = supplierName.toLowerCase();
  final supplierPhone = (vendor['phone'] ?? '').toString().trim();

  final Map<String, Map<String, dynamic>> byId = {};

  void addDocs(Iterable<QueryDocumentSnapshot> docs) {
    for (final d in docs) {
      byId[d.id] = {'id': d.id, ...d.data() as Map<String, dynamic>};
    }
  }

  if (supplierName.isNotEmpty) {
    try {
      final snap = await col.where('supplierName', isEqualTo: supplierName).orderBy('timestamp', descending: true).get();
      addDocs(snap.docs);
    } catch (_) {
      try {
        final snap = await col.where('supplierName', isEqualTo: supplierName).get();
        addDocs(snap.docs);
      } catch (_) {}
    }
  }

  if (byId.isEmpty && supplierPhone.isNotEmpty) {
    try {
      final snap = await col.where('supplierPhone', isEqualTo: supplierPhone).get();
      addDocs(snap.docs);
    } catch (_) {}
  }

  if (byId.isEmpty) {
    try {
      final snap = await col.get();
      final docs = snap.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final n = (data['supplierName'] ?? '').toString().trim().toLowerCase();
        final p = (data['supplierPhone'] ?? '').toString().trim();
        return (supplierNameNorm.isNotEmpty && n == supplierNameNorm) ||
            (supplierPhone.isNotEmpty && p == supplierPhone);
      });
      addDocs(docs);
    } catch (_) {}
  }

  final notes = byId.values.where((n) {
    final status = (n['status'] ?? '').toString();
    if (status == 'Used' || status == 'Settled') return false;
    return _remainingCreditFromNote(n) > 0.009;
  }).toList();

  notes.sort((a, b) {
    final tsA = a['timestamp'] as Timestamp?;
    final tsB = b['timestamp'] as Timestamp?;
    if (tsA == null && tsB == null) return 0;
    if (tsA == null) return 1;
    if (tsB == null) return -1;
    return tsB.compareTo(tsA);
  });

  return notes;
}

Future<double> _getPendingCreditTotalForVendor(Map<String, dynamic> vendor) async {
  final notes = await _fetchSupplierCreditNotes(vendor);
  return notes.fold<double>(0.0, (sum, n) => sum + _remainingCreditFromNote(n));
}

class VendorDetailsPage extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final String currencySymbol;
  final String uid;

  const VendorDetailsPage({super.key, required this.vendor, required this.currencySymbol, required this.uid});

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  late Map<String, dynamic> _vendor;
  List<Map<String, dynamic>> _purchases = [];
  double _pendingCredit = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vendor = Map<String, dynamic>.from(widget.vendor);
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      if (mounted) {
        setState(() {
          _purchases = [];
          _isLoading = true;
        });
      }

      final purchases = await _fetchSupplierPurchases(_vendor);
      final pendingCredit = await _getPendingCreditTotalForVendor(_vendor);

      if (mounted) {
        setState(() {
          _purchases = purchases;
          _pendingCredit = pendingCredit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor purchases: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_vendor['name'] ?? 'Vendor').toString();
    final phone = (_vendor['phone'] ?? '').toString();
    final gstin = (_vendor['gstin'] ?? '').toString();
    final address = (_vendor['address'] ?? '').toString();
    final totalPurchases = (_vendor['totalPurchases'] ?? 0.0).toDouble();
    final purchaseCount = (_vendor['purchaseCount'] ?? 0) as int;
    final totalCredit = _pendingCredit;

    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: Text(name, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.trash, color: kWhite, size: 20),
            onPressed: () => _showDeleteDialog(context),
          ),
          IconButton(
            icon: const HeroIcon(HeroIcons.pencilSquare, color: kWhite, size: 20),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kPrimaryColor,
        onRefresh: _loadPurchases,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Vendor Info Card
            Container(
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: kOrange.withValues(alpha: 0.12),
                    radius: 24,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'V',
                        style: const TextStyle(color: kOrange, fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kBlack87)),
                    if (phone.isNotEmpty) Row(children: [
                      const HeroIcon(HeroIcons.devicePhoneMobile, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                    ]),
                    if (gstin.isNotEmpty) Row(children: [
                      const HeroIcon(HeroIcons.documentText, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Text('GSTIN: $gstin', style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500)),
                    ]),
                    if (address.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const HeroIcon(HeroIcons.mapPin, size: 12, color: kBlack54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(address, style: const TextStyle(fontSize: 12, color: kBlack54, fontWeight: FontWeight.w500))),
                    ]),
                  ])),
                ]),
                const Divider(height: 20, color: kGreyBg),
                // Summary stats row
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _buildStat(_purchases.length == 1 ? 'Bill' : 'Bills', _isLoading ? purchaseCount.toString() : _purchases.length.toString(), kPrimaryColor),
                  _buildStat('Total Spent', '${widget.currencySymbol}${totalPurchases.toStringAsFixed(0)}', kGoogleGreen),
                  _buildStat('Credit', '${widget.currencySymbol}${totalCredit.toStringAsFixed(0)}', kErrorColor),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            _buildHistoryTile(
              title: 'Purchase History',
              subtitle: 'View all purchase bills for this supplier',
              icon: HeroIcons.archiveBox,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => SupplierPurchaseHistoryPage(
                    vendor: _vendor,
                    currencySymbol: widget.currencySymbol,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildHistoryTile(
              title: 'Credit History',
              subtitle: 'View bills with pending credit and settle quickly',
              icon: HeroIcons.wallet,
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => SupplierCreditHistoryPage(
                    vendor: _vendor,
                    currencySymbol: widget.currencySymbol,
                    uid: widget.uid,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile({required String title, required String subtitle, required HeroIcons icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HeroIcon(icon, size: 16, color: kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kBlack87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kBlack54)),
                  ],
                ),
              ),
              const HeroIcon(HeroIcons.chevronRight, size: 16, color: kPrimaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlack54, letterSpacing: 0.5)),
    ]);
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _vendor['name']);
    final phoneCtrl = TextEditingController(text: _vendor['phone']);
    final gstinCtrl = TextEditingController(text: _vendor['gstin']);
    final addressCtrl = TextEditingController(text: _vendor['address']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Edit Vendor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildField(nameCtrl, 'Vendor Name'),
          const SizedBox(height: 12),
          _buildField(phoneCtrl, 'Phone', type: TextInputType.phone),
          const SizedBox(height: 12),
          _buildField(gstinCtrl, 'GSTIN'),
          const SizedBox(height: 12),
          _buildField(addressCtrl, 'Address', maxLines: 2),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kBlack54, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final col = await FirestoreService().getStoreCollection('vendors');
                await col.doc(_vendor['id']).update({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'gstin': gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  setState(() {
                    _vendor['name'] = nameCtrl.text.trim();
                    _vendor['phone'] = phoneCtrl.text.trim();
                    _vendor['gstin'] = gstinCtrl.text.trim();
                    _vendor['address'] = addressCtrl.text.trim();
                  });
                  Navigator.pop(ctx);
                }
              } catch (e) { debugPrint(e.toString()); }
            },
            child: const Text('Save', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: kGreyBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final outstandingCredit = await _getOutstandingCredit();
    if (outstandingCredit > 0.009) {
      if (!mounted) return;
      await _showDeleteBlockedDialog(context, outstandingCredit);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Delete Supplier?', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text(
          'Are you sure you want to delete "${_vendor['name'] ?? 'this supplier'}"? This action cannot be undone.',
          style: const TextStyle(color: kBlack54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: kBlack54)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final col = await FirestoreService().getStoreCollection('vendors');
                await col.doc(_vendor['id']).delete();
                if (!mounted) return;
                Navigator.pop(ctx);
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e'), backgroundColor: kErrorColor),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kErrorColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<double> _getOutstandingCredit() async {
    try {
      return await _getPendingCreditTotalForVendor(_vendor);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _showDeleteBlockedDialog(BuildContext context, double dueAmount) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kWhite,
        title: const Text('Delete blocked', style: TextStyle(fontWeight: FontWeight.w800, color: kBlack87)),
        content: Text(
          '"${_vendor['name'] ?? 'This supplier'}" has pending credit of ${widget.currencySymbol}${dueAmount.toStringAsFixed(2)}. Clear credit before deleting.',
          style: const TextStyle(color: kBlack54, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK', style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class SupplierPurchaseHistoryPage extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final String currencySymbol;

  const SupplierPurchaseHistoryPage({super.key, required this.vendor, required this.currencySymbol});

  @override
  State<SupplierPurchaseHistoryPage> createState() => _SupplierPurchaseHistoryPageState();
}

class _SupplierPurchaseHistoryPageState extends State<SupplierPurchaseHistoryPage> {
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final purchases = await _fetchSupplierPurchases(widget.vendor);
      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorName = (widget.vendor['name'] ?? 'Supplier').toString();
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: const Text('Purchase History', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: kPrimaryColor,
        onRefresh: _loadPurchases,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(vendorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kBlack87)),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kPrimaryColor)))
            else if (_purchases.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No purchase history found', style: TextStyle(color: kBlack54))))
            else
              ..._purchases.map((p) {
                final ts = p['timestamp'] as Timestamp?;
                final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';
                final amount = (p['totalAmount'] ?? 0.0).toDouble();
                final invoiceNumber = (p['invoiceNumber'] ?? 'N/A').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => StockPurchaseDetailsPage(
                            purchaseId: p['id'].toString(),
                            purchaseData: p,
                            currencySymbol: widget.currencySymbol,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const HeroIcon(HeroIcons.documentText, size: 16, color: kPrimaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kPrimaryColor)),
                                  Text(dateStr, style: const TextStyle(fontSize: 11, color: kBlack54)),
                                ],
                              ),
                            ),
                            Text('${widget.currencySymbol}${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: kGoogleGreen)),
                            const SizedBox(width: 8),
                            const HeroIcon(HeroIcons.chevronRight, size: 16, color: kPrimaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class SupplierCreditHistoryPage extends StatefulWidget {
  final Map<String, dynamic> vendor;
  final String currencySymbol;
  final String uid;

  const SupplierCreditHistoryPage({super.key, required this.vendor, required this.currencySymbol, required this.uid});

  @override
  State<SupplierCreditHistoryPage> createState() => _SupplierCreditHistoryPageState();
}

class _SupplierCreditHistoryPageState extends State<SupplierCreditHistoryPage> {
  List<Map<String, dynamic>> _creditBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreditBills();
  }

  Future<void> _loadCreditBills() async {
    setState(() => _isLoading = true);
    try {
      final bills = await _fetchSupplierCreditNotes(widget.vendor);

      if (!mounted) return;
      setState(() {
        _creditBills = bills;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: const Text('Credit History', style: TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kPrimaryColor,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20), onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: kPrimaryColor,
        onRefresh: _loadCreditBills,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: kPrimaryColor)))
            else if (_creditBills.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No credit bills found', style: TextStyle(color: kBlack54))))
            else
              ..._creditBills.map((p) {
                final ts = p['timestamp'] as Timestamp?;
                final dateStr = ts != null ? DateFormat('dd MMM yyyy').format(ts.toDate()) : 'N/A';
                final credit = _remainingCreditFromNote(p);
                final invoiceNumber = (p['invoiceNumber'] ?? p['purchaseNumber'] ?? p['creditNoteNumber'] ?? 'N/A').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => menu_page.CreditDetailsPage(
                            uid: widget.uid,
                            onBack: () => Navigator.pop(context),
                            initialTabIndex: 1,
                            initialSearchQuery: invoiceNumber,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const HeroIcon(HeroIcons.receiptPercent, size: 16, color: kErrorColor),
                                const SizedBox(width: 8),
                                Expanded(child: Text(invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimaryColor))),
                                Text(dateStr, style: const TextStyle(fontSize: 11, color: kBlack54)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Credit: ${widget.currencySymbol}${credit.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: kErrorColor)),
                                const Row(
                                  children: [
                                    Text('Open credit tracker', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryColor)),
                                    SizedBox(width: 6),
                                    HeroIcon(HeroIcons.chevronRight, size: 16, color: kPrimaryColor),
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
              }),
          ],
        ),
      ),
    );
  }
}

