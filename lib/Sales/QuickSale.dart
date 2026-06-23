import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxmybill/Sales/Bill.dart';
import 'package:maxmybill/Sales/Invoice.dart';
import 'package:provider/provider.dart';
import 'package:maxmybill/models/cart_item.dart';
import 'package:maxmybill/models/sale.dart';
import 'package:maxmybill/Sales/Quotation.dart' show QuotationPage;
import 'package:maxmybill/Sales/components/common_widgets.dart';
import 'package:maxmybill/utils/firestore_service.dart';
import 'package:maxmybill/utils/translation_helper.dart';
import 'package:maxmybill/services/number_generator_service.dart';
import 'package:maxmybill/services/sale_sync_service.dart';
import 'package:maxmybill/services/local_stock_service.dart';
import 'package:maxmybill/Colors.dart';

class QuickSalePage extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<CartItem>? initialCartItems;
  final Function(List<CartItem>)? onCartChanged;
  final String? savedOrderId;
  final bool isQuotationMode; // NEW: Quotation mode flag

  // New parametefor customer info
  final String? customerPhone;
  final String? customerName;
  final String? customerGST;
  final void Function(String?, String?, String?)? onCustomerChanged;

  const QuickSalePage({
    super.key,
    required this.uid,
    this.userEmail,
    this.initialCartItems,
    this.onCartChanged,
    this.savedOrderId,
    this.isQuotationMode = false, // Default to false
    this.customerPhone,
    this.customerName,
    this.customerGST,
    this.onCustomerChanged,
  });

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class QuickSaleItem {
  final String productId;
  final String name;
  final double price;
  double
  quantity; // Changed from int to double to support decimal quantities (e.g., 0.5 kg)

  QuickSaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;
}

class _QuickSalePageState extends State<QuickSalePage> {
  final List<QuickSaleItem> _items = [];
  String _input = '';
  int _counter = 1;
  int? editingIndex;
  int _productIdCounter = 1;
  bool _isProcessing = false; // Prevents double-click on save/quotation buttons

  // Billing mode: 'item' for item-wise, 'productCode' for product code wise
  String _billingMode = 'productCode';

  // Default tax settings
  String _defaultTaxType = 'Add Tax at Billing';
  double _defaultTaxPercentage = 0.0;
  String _defaultTaxName = '';

  // Customer selection
  String? _selectedCustomerPhone;
  String? _selectedCustomerName;
  String? _selectedCustomerGST;

  // Currency symbol
  String _currencySymbol = 'Rs ';

  @override
  void initState() {
    super.initState();
    _loadDefaultTaxSettings();
    _loadCurrencySymbol();
    // Use initial customer info from parent
    _selectedCustomerPhone = widget.customerPhone;
    _selectedCustomerName = widget.customerName;
    _selectedCustomerGST = widget.customerGST;
    if (widget.initialCartItems != null) {
      for (var item in widget.initialCartItems!) {
        _items.add(
          QuickSaleItem(
            productId: item.productId.isNotEmpty
                ? item.productId
                : 'qs_${_productIdCounter++}',
            name: item.name,
            price: item.price,
            quantity: item.quantity,
          ),
        );
      }
      _counter = _items.length + 1;
    }
  }

  @override
  void didUpdateWidget(QuickSalePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync cart from parent when initialCartItems change
    final newItems = widget.initialCartItems;
    final oldItems = oldWidget.initialCartItems;

    if (newItems != null && newItems != oldItems) {
      // Cart was updated from parent - check if content actually changed
      bool contentChanged = false;

      if (_items.length != newItems.length) {
        contentChanged = true;
      } else {
        // Check each item for changes in quantity, price, or name
        for (int i = 0; i < _items.length; i++) {
          final currentItem = _items[i];
          final newItem = newItems.firstWhere(
            (item) => item.productId == currentItem.productId,
            orElse: () => newItems[i], // fallback to position if ID not found
          );

          if (currentItem.name != newItem.name ||
              currentItem.price != newItem.price ||
              currentItem.quantity != newItem.quantity) {
            contentChanged = true;
            break;
          }
        }
      }

      if (contentChanged) {
        setState(() {
          _items.clear();
          for (var item in newItems) {
            _items.add(
              QuickSaleItem(
                productId: item.productId.isNotEmpty
                    ? item.productId
                    : 'qs_${_productIdCounter++}',
                name: item.name,
                price: item.price,
                quantity: item.quantity,
              ),
            );
          }
          _counter = _items.length + 1;
        });
      }
    } else if (newItems == null && oldItems != null) {
      // Parent explicitly cleared the cart
      setState(() {
        _items.clear();
        _counter = 1;
      });
    }

    // Sync customer info
    if (widget.customerPhone != oldWidget.customerPhone ||
        widget.customerName != oldWidget.customerName ||
        widget.customerGST != oldWidget.customerGST) {
      _selectedCustomerPhone = widget.customerPhone;
      _selectedCustomerName = widget.customerName;
      _selectedCustomerGST = widget.customerGST;
    }
  }

  Future<void> _loadDefaultTaxSettings() async {
    try {
      // Import FirestoreService at the top if not already imported
      final firestoreService = FirestoreService();

      // Load default tax type from store-scoped settings
      final settingsCollection = await firestoreService.getStoreCollection(
        'settings',
      );
      final settingsDoc = await settingsCollection.doc('taxSettings').get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>?;
        _defaultTaxType = data?['defaultTaxType'] ?? 'Add Tax at Billing';
        debugPrint('📊 Quick Bill Tax Type loaded: $_defaultTaxType');
      }

      // Only load active tax when the tax type actually applies tax
      final taxApplied =
          _defaultTaxType != 'No Tax Applied' &&
          _defaultTaxType != 'Exempt from Tax';

      if (taxApplied) {
        // Load first active tax for quick sale from store-scoped taxes
        final taxesCollection = await firestoreService.getStoreCollection(
          'taxes',
        );
        final taxesSnapshot = await taxesCollection
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (taxesSnapshot.docs.isNotEmpty) {
          final taxData =
              taxesSnapshot.docs.first.data() as Map<String, dynamic>;
          _defaultTaxPercentage = (taxData['percentage'] ?? 0.0).toDouble();
          _defaultTaxName = taxData['name'] ?? '';
          debugPrint(
            '📊 Quick Bill Tax loaded: $_defaultTaxName at $_defaultTaxPercentage%',
          );
        } else {
          _defaultTaxPercentage = 0.0;
          _defaultTaxName = '';
          debugPrint('📊 No active tax found for Quick Bill');
        }
      } else {
        _defaultTaxPercentage = 0.0;
        _defaultTaxName = '';
        debugPrint('📊 Tax not applied — defaultTaxType is: $_defaultTaxType');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading tax settings: $e');
    }
  }

  Future<void> _loadCurrencySymbol() async {
    try {
      final doc = await FirestoreService().getCurrentStoreDoc();
      if (doc != null && doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _currencySymbol = _getCurrencyShortForm(data?['currency'] ?? 'INR');
        });
      }
    } catch (e) {
      debugPrint('Error loading currency: $e');
    }
  }

  String _getCurrencyShortForm(String code) {
    const currencyShortForms = {
      'INR': 'Rs ',
      'USD': '\$ ',
      'EUR': '€ ',
      'GBP': '£ ',
      'JPY': '¥ ',
      'CNY': '¥ ',
      'AUD': 'A\$ ',
      'CAD': 'C\$ ',
      'CHF': 'Fr ',
      'HKD': 'HK\$ ',
      'SGD': 'S\$ ',
      'SEK': 'kr ',
      'KRW': '₩ ',
      'NOK': 'kr ',
      'NZD': 'NZ\$ ',
      'MXN': 'Mex\$ ',
      'BRL': 'R\$ ',
      'ZAR': 'R ',
      'RUB': '₽ ',
      'TRY': '₺ ',
      'PLN': 'zł ',
      'THB': '฿ ',
      'IDR': 'Rp ',
      'MYR': 'RM ',
      'PHP': '₱ ',
      'CZK': 'Kč ',
      'ILS': '₪ ',
      'CLP': '\$ ',
      'PKR': 'Rs ',
      'AED': 'AED ',
      'SAR': 'SR ',
      'TWD': 'NT\$ ',
      'DKK': 'kr ',
      'COP': '\$ ',
      'ARS': '\$ ',
      'VND': '₫ ',
      'EGP': 'E£ ',
      'BDT': '৳ ',
      'QAR': 'QR ',
      'KWD': 'KD ',
      'NGN': '₦ ',
      'UAH': '₴ ',
      'PEN': 'S/ ',
      'RON': 'lei ',
      'HUF': 'Ft ',
      'BGN': 'лв ',
      'HRK': 'kn ',
      'LKR': 'Rs ',
      'NPR': 'Rs ',
      'KES': 'KSh ',
      'GHS': 'GH₵ ',
      'MMK': 'K ',
      'OMR': 'OMR ',
      'BHD': 'BD ',
      'JOD': 'JD ',
      'LBP': 'L£ ',
      'MAD': 'MAD ',
      'TND': 'DT ',
      'DZD': 'DA ',
      'IQD': 'IQD ',
    };
    return currencyShortForms[code] ?? '$code ';
  }

  bool get _isTaxEnabled =>
      _defaultTaxType != 'No Tax Applied' &&
      _defaultTaxType != 'Exempt from Tax' &&
      _defaultTaxPercentage > 0;

  double get _total => _items.fold(0.0, (acc, item) => acc + item.total);

  // Get total with tax applied based on quick billing tax settings
  double get _totalWithTax {
    if (!_isTaxEnabled) return _total;

    double totalWithTax = 0.0;
    for (var item in _cartItems) {
      totalWithTax += item.totalWithTax;
    }
    return totalWithTax;
  }

  // Get total tax amount
  double get _totalTaxAmount {
    if (!_isTaxEnabled) return 0.0;

    double totalTax = 0.0;
    for (var item in _cartItems) {
      totalTax += item.taxAmount;
    }
    return totalTax;
  }

  List<CartItem> get _cartItems => _items
      .map(
        (item) => CartItem(
          productId: item.productId,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          taxName: _isTaxEnabled ? _defaultTaxName : null,
          taxPercentage: _isTaxEnabled ? _defaultTaxPercentage : null,
          taxType: _defaultTaxType,
        ),
      )
      .toList();

  void _notifyChange() => widget.onCartChanged?.call(_cartItems);

  void _handleInput(String val) {
    setState(() {
      if (val == '.' && _input.contains('.')) return;
      _input += val;
    });
  }

  void _handleMultiply() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('x')) _input += 'x';
    });
  }

  void _handleProductCodeMultiply() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('x')) _input += 'x';
    });
  }

  void _handleBackspace() {
    setState(() {
      if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
    });
  }

  void _addItem() {
    if (_input.isEmpty) return;
    try {
      double price;
      double qty;
      if (_input.contains('x')) {
        final parts = _input.split('x');
        if (parts.length != 2) return;
        price = double.parse(parts[0].trim());
        qty = double.tryParse(parts[1].trim()) ?? 1.0;
      } else {
        price = double.parse(_input);
        qty = 1.0;
      }
      setState(() {
        _items.add(
          QuickSaleItem(
            productId:
                'qs_${DateTime.now().millisecondsSinceEpoch}_${_productIdCounter++}',
            name: 'item$_counter',
            price: price,
            quantity: qty,
          ),
        );
        _counter++;
        _input = '';
      });
      _notifyChange();
      CommonWidgets.showSnackBar(
        context,
        'Item added: ${price.toStringAsFixed(1)} x $qty',
        bgColor: const Color(0xFF4CAF50),
      );
    } catch (e) {
      CommonWidgets.showSnackBar(
        context,
        'Invalid input format',
        bgColor: const Color(0xFFFF5252),
      );
    }
  }

  // Product Code wise billing - lookup product by code and add to cart
  Future<void> _addItemByProductCode() async {
    if (_input.isEmpty) return;

    try {
      String productCode;
      double qty;

      // Parse input: "101x5" means product code 101 with quantity 5
      if (_input.contains('x')) {
        final parts = _input.split('x');
        if (parts.length != 2 || parts[0].trim().isEmpty) {
          CommonWidgets.showSnackBar(
            context,
            'Format: ProductCode x Quantity (e.g., 1001x5)',
            bgColor: const Color(0xFFFF5252),
          );
          return;
        }
        productCode = parts[0].trim();
        // If quantity part is empty or invalid, default to 1
        final qtyPart = parts[1].trim();
        qty = qtyPart.isEmpty ? 1.0 : (double.tryParse(qtyPart) ?? 1.0);
        if (qty <= 0) qty = 1.0;
      } else {
        productCode = _input.trim();
        qty = 1.0;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Lookup product by product code from Firestore
      final productsCollection = await FirestoreService().getStoreCollection(
        'Products',
      );

      // Try exact match first
      var querySnapshot = await productsCollection
          .where('productCode', isEqualTo: productCode)
          .limit(1)
          .get();

      // If not found by productCode, try by barcode
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await productsCollection
            .where('barcode', isEqualTo: productCode)
            .limit(1)
            .get();
      }

      if (mounted) Navigator.pop(context); // Close loading

      if (querySnapshot.docs.isEmpty) {
        CommonWidgets.showSnackBar(
          context,
          'Product code "$productCode" not found',
          bgColor: const Color(0xFFFF5252),
        );
        return;
      }

      final productDoc = querySnapshot.docs.first;
      final productData = productDoc.data() as Map<String, dynamic>;

      // Get product details - itemName is the correct field
      final String productName =
          (productData['itemName'] ?? productData['name'] ?? 'Unknown')
              .toString();
      final double productPrice = (productData['price'] ?? 0.0).toDouble();
      final bool stockEnabled = productData['stockEnabled'] == true;
      final double currentStock = (productData['currentStock'] ?? 0.0)
          .toDouble();

      // Check for expired product
      final expiryDateStr = productData['expiryDate'] as String?;
      bool isExpired = false;
      if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
        try {
          final expiryDate = DateTime.parse(expiryDateStr);
          isExpired = expiryDate.isBefore(DateTime.now());
        } catch (_) {}
      }

      if (isExpired) {
        CommonWidgets.showSnackBar(
          context,
          'Product "$productName" has expired and cannot be added to the cart',
          bgColor: const Color(0xFFFF5252),
        );
        return;
      }

      // Check if stock tracking is enabled and validate stock
      if (stockEnabled) {
        // Calculate already added quantity for this product in cart
        double alreadyInCart = 0.0;
        for (var item in _items) {
          if (item.productId == productDoc.id) {
            alreadyInCart += item.quantity;
          }
        }

        final double availableStock = currentStock - alreadyInCart;

        if (qty > availableStock) {
          CommonWidgets.showSnackBar(
            context,
            'Insufficient stock! Available: $availableStock, Requested: $qty',
            bgColor: const Color(0xFFFF5252),
          );
          return;
        }
      }

      setState(() {
        // Check if product already exists in cart
        int existingIndex = _items.indexWhere(
          (item) => item.productId == productDoc.id,
        );

        if (existingIndex != -1) {
          // Product exists, increment quantity
          _items[existingIndex].quantity += qty;
        } else {
          // Product doesn't exist, add new item
          _items.add(
            QuickSaleItem(
              productId: productDoc.id,
              name: productName,
              price: productPrice,
              quantity: qty,
            ),
          );
          _counter++;
        }
        _input = '';
      });
      _notifyChange();

      CommonWidgets.showSnackBar(
        context,
        '$productName x $qty added',
        bgColor: const Color(0xFF4CAF50),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      CommonWidgets.showSnackBar(
        context,
        'Error: ${e.toString()}',
        bgColor: const Color(0xFFFF5252),
      );
    }
  }

  void _clearOrder() {
    setState(() {
      _items.clear();
      _input = '';
      _counter = 1;
      editingIndex = null;
    });
    _notifyChange();
  }

  void _removeItem(int idx) {
    setState(() => _items.removeAt(idx));
    _notifyChange();
  }

  void _startEditQuantity(int idx) {
    setState(() {
      editingIndex = idx;
      _input = _items[idx].quantity.toString();
    });
  }

  void _confirmEditQuantity() {
    if (editingIndex != null) {
      final qty = double.tryParse(_input);
      if (qty != null && qty > 0) {
        setState(() {
          _items[editingIndex!].quantity = qty;
          editingIndex = null;
          _input = '';
        });
        _notifyChange();
        CommonWidgets.showSnackBar(
          context,
          'Quantity updated to $qty',
          bgColor: const Color(0xFF4CAF50),
        );
      } else {
        CommonWidgets.showSnackBar(
          context,
          'Invalid quantity',
          bgColor: const Color(0xFFFF5252),
        );
      }
    }
  }

  void _handleEnter() {
    if (_billingMode == 'productCode') {
      _addItemByProductCode();
    } else {
      _addItem();
    }
  }

  void _handleAdd() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('+')) _input += '+';
    });
  }

  void _handleSubtract() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('-')) _input += '-';
    });
  }

  void _handleDivide() {
    setState(() {
      if (_input.isNotEmpty && !_input.endsWith('/')) _input += '/';
    });
  }

  Future<void> _directPrintWithCash() async {
    if (_isProcessing) return; // Prevent double-click
    if (_items.isEmpty) {
      CommonWidgets.showSnackBar(
        context,
        'Cart is empty!',
        bgColor: const Color(0xFFFF9800),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Generate invoice number
      final invoiceNumber =
          await NumberGeneratorService.generateInvoiceNumber();

      // Fetch business details
      final businessDetails = await _fetchBusinessDetails();
      final staffName = await _fetchStaffName(widget.uid);
      final businessName = businessDetails['businessName'];
      final businessLocation = businessDetails['location'];
      final businessPhone = businessDetails['businessPhone'];

      // Calculate tax information
      final Map<String, double> taxMap = {};
      for (var item in _cartItems) {
        if (item.taxAmount > 0 && item.taxName != null) {
          taxMap[item.taxName!] =
              (taxMap[item.taxName!] ?? 0.0) + item.taxAmount;
        }
      }
      final taxList = taxMap.entries
          .map((e) => {'name': e.key, 'amount': e.value})
          .toList();
      final totalTax = taxMap.values.fold(0.0, (a, b) => a + b);

      final subtotalAmount = _cartItems.fold(0.0, (acc, item) {
        if (item.taxType == 'Price includes Tax') {
          return acc + (item.basePrice * item.quantity);
        } else {
          return acc + item.total;
        }
      });
      final totalWithTax = _cartItems.fold(
        0.0,
        (acc, item) => acc + item.totalWithTax,
      );

      // Base sale data
      final baseSaleData = {
        'invoiceNumber': invoiceNumber,
        'items': _cartItems
            .map(
              (e) => {
                'productId': e.productId,
                'name': e.name,
                'quantity': e.quantity,
                'price': e.price,
                'total': e.total,
                'taxName': e.taxName,
                'taxPercentage': e.taxPercentage ?? 0,
                'taxAmount': e.taxAmount,
                'taxType': e.taxType,
                'totalWithTax': e.totalWithTax,
              },
            )
            .toList(),
        'subtotal': subtotalAmount,
        'discount': 0.0,
        'total': totalWithTax,
        'taxes': taxList,
        'totalTax': totalTax,
        'paymentMode': 'Cash',
        'cashReceived': totalWithTax,
        'change': 0.0,
        'creditAmount': 0.0,
        'date': DateTime.now().toIso8601String(),
        'staffId': widget.uid,
        'staffName': staffName ?? 'Staff',
        'businessLocation': businessLocation ?? 'Location',
        'businessPhone': businessPhone ?? '',
        'businessName': businessName ?? 'Business',
      };

      final saleSyncService = context.read<SaleSyncService>();
      final sale = Sale(id: invoiceNumber, data: baseSaleData, isSynced: false);
      final syncedNow = await saleSyncService.saveSale(sale);

      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted && !syncedNow) {
        CommonWidgets.showSnackBar(
          context,
          'Saved offline. Will sync automatically when internet returns.',
          bgColor: const Color(0xFFFF9800),
        );
      }

      // Navigate to Invoice
      if (mounted) {
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (_) => InvoicePage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              businessName: businessName ?? 'Business',
              businessLocation: businessLocation ?? 'Location',
              businessPhone: businessPhone ?? '',
              invoiceNumber: invoiceNumber,
              dateTime: DateTime.now(),
              items: _cartItems
                  .map(
                    (e) => {
                      'name': e.name,
                      'quantity': e.quantity,
                      'price': e.price,
                      'total': e.totalWithTax,
                      'taxPercentage': e.taxPercentage ?? 0,
                      'taxAmount': e.taxAmount,
                    },
                  )
                  .toList(),
              subtotal: subtotalAmount,
              discount: 0.0,
              taxes: taxList,
              total: totalWithTax,
              paymentMode: 'Cash',
              cashReceived: totalWithTax,
            ),
          ),
        ).then((_) {
          // Clear cart after invoice
          setState(() {
            _items.clear();
            _input = '';
            _counter = 1;
            editingIndex = null;
          });
          _notifyChange();
        });
      }
    } catch (e) {
      debugPrint('Error in direct print: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        CommonWidgets.showSnackBar(
          context,
          'Error: ${e.toString()}',
          bgColor: kErrorColor,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, String?>> _fetchBusinessDetails() async {
    try {
      debugPrint('🔍 Fetching business details for uid: ${widget.uid}');

      final firestoreService = FirestoreService();
      final storeDoc = await firestoreService.getCurrentStoreDoc();

      debugPrint('📄 Store doc exists: ${storeDoc?.exists}');

      if (storeDoc != null && storeDoc.exists) {
        final data = storeDoc.data() as Map<String, dynamic>?;
        debugPrint('📦 Store data: $data');
        debugPrint('🏢 Business Name: ${data?['businessName']}');
        debugPrint(
          '📍 Location: ${data?['location']} or ${data?['businessLocation']}',
        );
        debugPrint('📞 Phone: ${data?['businessPhone']}');

        return {
          'businessName': data?['businessName'] as String?,
          'location':
              data?['location'] as String? ??
              data?['businessLocation'] as String?,
          'businessPhone': data?['businessPhone'] as String?,
        };
      }

      debugPrint('⚠️ Returning null business details - store doc not found');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    } catch (e) {
      debugPrint('❌ Error fetching business details: $e');
      return {'businessName': null, 'location': null, 'businessPhone': null};
    }
  }

  Future<String?> _fetchStaffName(String uid) async {
    try {
      debugPrint('👤 Fetching staff name for uid: $uid');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final staffName = userDoc.data()?['name'];
      debugPrint('👤 Staff name: $staffName');
      return staffName;
    } catch (e) {
      debugPrint('❌ Error fetching staff name: $e');
      return null;
    }
  }

  // Generate quotation from cart items
  Future<void> _generateQuotation() async {
    if (_isProcessing) return; // Prevent double-click
    if (_items.isEmpty) {
      CommonWidgets.showSnackBar(
        context,
        'Please add items to create quotation',
        bgColor: Colors.orange,
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Use _cartItems which includes tax info
      final cartItems = _cartItems;

      // Calculate total with tax
      final total = _totalWithTax;

      // Close loading
      if (mounted) Navigator.pop(context);

      // Navigate to Quotation page
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => QuotationPage(
              uid: widget.uid,
              userEmail: widget.userEmail,
              cartItems: cartItems,
              totalAmount: total,
              customerPhone: _selectedCustomerPhone,
              customerName: _selectedCustomerName,
              customerGST: _selectedCustomerGST,
            ),
          ),
        ).then((_) {
          // Clear cart after quotation is created
          setState(() {
            _items.clear();
            _input = '';
            _counter = 1;
          });
          _notifyChange();
        });
      }
    } catch (e) {
      debugPrint('Error generating quotation: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading
        CommonWidgets.showSnackBar(
          context,
          'Error: ${e.toString()}',
          bgColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateProductStock() async {
    final localStockService = context.read<LocalStockService>();
    for (var item in _cartItems) {
      if (item.productId.isNotEmpty && !item.productId.startsWith('qs_')) {
        try {
          final productRef = await FirestoreService().getStoreCollection(
            'Products',
          );
          final doc = await productRef.doc(item.productId).get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final currentStock = (data['currentStock'] ?? 0.0).toDouble();
            final newStock = currentStock - item.quantity;
            await productRef.doc(item.productId).update({
              'currentStock': newStock,
            });
            localStockService.cacheStock(item.productId, newStock.toInt());
          }
        } catch (e) {
          debugPrint('Error updating stock for ${item.productId}: $e');
        }
      }
    }
  }
  //
  // double get _total => _items.fold(0.0, (sum, item) => sum + item.total);
  //
  // List<CartItem> get _cartItems => _items
  //     .map((item) => CartItem(
  //   productId: item.productId,
  //   name: item.name,
  //   price: item.price,
  //   quantity: item.quantity,
  //   taxName: _defaultTaxPercentage > 0 ? _defaultTaxName : null,
  //   taxPercentage: _defaultTaxPercentage > 0 ? _defaultTaxPercentage : null,
  //   taxType: _defaultTaxType,
  // ))
  //     .toList();
  //
  // void _notifyChange() => widget.onCartChanged?.call(_cartItems);
  //
  // void _handleInput(String val) {
  //   setState(() {
  //     if (val == '.' && _input.contains('.')) return;
  //     _input += val;
  //   });
  // }
  //
  // void _handleMultiply() {
  //   setState(() {
  //     if (_input.isNotEmpty && !_input.endsWith('x')) _input += 'x';
  //   });
  // }
  //
  // void _handleBackspace() {
  //   setState(() {
  //     if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
  //   });
  // }
  //
  // void _addItem() {
  //   if (_input.isEmpty) return;
  //   try {
  //     double price;
  //     int qty;
  //     if (_input.contains('x')) {
  //       final parts = _input.split('x');
  //       if (parts.length != 2) return;
  //       price = double.parse(parts[0].trim());
  //       qty = int.tryParse(parts[1].trim()) ?? 1;
  //     } else {
  //       price = double.parse(_input);
  //       qty = 1;
  //     }
  //     setState(() {
  //       _items.insert(
  //           0,
  //           QuickSaleItem(
  //             productId: 'qs_${DateTime.now().millisecondsSinceEpoch}_${_productIdCounter++}',
  //             name: 'item$_counter',
  //             price: price,
  //             quantity: qty,
  //           ));
  //       _counter++;
  //       _input = '';
  //     });
  //     _notifyChange();
  //     CommonWidgets.showSnackBar(
  //       context,
  //       'Item added:   a0${price.toStringAsFixed(1)} x $qty',
  //       bgColor: const Color(0xFF4CAF50),
  //     );
  //   } catch (e) {
  //     CommonWidgets.showSnackBar(
  //       context,
  //       'Invalid input format',
  //       bgColor: const Color(0xFFFF5252),
  //     );
  //   }
  // }
  //
  // void _clearOrder() {
  //   setState(() {
  //     _items.clear();
  //     _input = '';
  //     _counter = 1;
  //     editingIndex = null;
  //   });
  //   _notifyChange();
  // }
  //
  // void _removeItem(int idx) {
  //   setState(() => _items.removeAt(idx));
  //   _notifyChange();
  // }
  //
  // void _startEditQuantity(int idx) {
  //   setState(() {
  //     editingIndex = idx;
  //     _input = _items[idx].quantity.toString();
  //   });
  // }
  //
  // void _confirmEditQuantity() {
  //   if (editingIndex != null) {
  //     final qty = int.tryParse(_input);
  //     if (qty != null && qty > 0) {
  //       setState(() {
  //         _items[editingIndex!].quantity = qty;
  //         editingIndex = null;
  //         _input = '';
  //       });
  //       _notifyChange();
  //       CommonWidgets.showSnackBar(
  //         context,
  //         'Quantity updated to $qty',
  //         bgColor: const Color(0xFF4CAF50),
  //       );
  //     } else {
  //       CommonWidgets.showSnackBar(
  //         context,
  //         'Invalid quantity',
  //         bgColor: const Color(0xFFFF5252),
  //       );
  //     }
  //   }
  // }
  //
  // void _handleEnter() {
  //   _addItem();
  // }
  //
  // void _handleAdd() {
  //   setState(() {
  //     if (_input.isNotEmpty && !_input.endsWith('+')) _input += '+';
  //   });
  // }
  //
  // void _handleSubtract() {
  //   setState(() {
  //     if (_input.isNotEmpty && !_input.endsWith('-')) _input += '-';
  //   });
  // }
  //
  // void _handleDivide() {
  //   setState(() {
  //     if (_input.isNotEmpty && !_input.endsWith('/')) _input += '/';
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    // ALWAYS show calculator UI in Quick Bill tab
    // Only the bottom action buttons change based on quotation mode
    return Column(
      children: [
        // Spacer to push content to bottom
        const Spacer(),

        // Fixed components at bottom: Input + Keypad + Action Buttons
        Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Billing Mode Toggle
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _billingMode = 'item'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _billingMode == 'item'
                                ? kPrimaryColor
                                : Colors.grey.shade200,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Quick Price',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _billingMode == 'item'
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _billingMode = 'productCode'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _billingMode == 'productCode'
                                ? Color(0xffffab36)
                                : Colors.grey.shade200,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Quick Product',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _billingMode == 'productCode'
                                    ? Colors.black
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Input Display with hint based on mode
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF2F7CF6),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_input.isEmpty)
                        Text(
                          _billingMode == 'productCode'
                              ? 'Product Code x Qty (e.g., 1001 x 5)'
                              : 'Price x Qty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _input,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (editingIndex != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: ElevatedButton(
                            onPressed: _confirmEditQuantity,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2F7CF6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: Text(
                              context.tr('update'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Calculator Keypad
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _numBtn('7'),
                        const SizedBox(width: 6),
                        _numBtn('8'),
                        const SizedBox(width: 6),
                        _numBtn('9'),
                        const SizedBox(width: 6),
                        _actBtn(Icons.backspace_outlined, _handleBackspace),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _numBtn('4'),
                        const SizedBox(width: 6),
                        _numBtn('5'),
                        const SizedBox(width: 6),
                        _numBtn('6'),
                        const SizedBox(width: 6),
                        _opBtn(
                          _billingMode == 'productCode' ? '×' : '×',
                          _billingMode == 'productCode'
                              ? _handleProductCodeMultiply
                              : _handleMultiply,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _numBtn('1'),
                                  const SizedBox(width: 6),
                                  _numBtn('2'),
                                  const SizedBox(width: 6),
                                  _numBtn('3'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _numBtn('0'),
                                  const SizedBox(width: 6),
                                  _numBtn('00'),
                                  const SizedBox(width: 6),
                                  _numBtn('•'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        editingIndex == null
                            ? _addBtn()
                            : SizedBox(
                                width:
                                    (MediaQuery.of(context).size.width - 48) /
                                    4,
                                height: 118,
                                child: GestureDetector(
                                  onTap: _confirmEditQuantity,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2F7CF6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Update',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Qty',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons - Hide in quotation mode (parent provides floating bottom bar)
              !widget.isQuotationMode
                  ? CommonWidgets.buildActionButtons(
                      context: context,
                      onSaveOrder: () {
                        if (_items.isEmpty) {
                          CommonWidgets.showSnackBar(
                            context,
                            'Cart is empty!',
                            bgColor: const Color(0xFFFF9800),
                          );
                          return;
                        }
                        CommonWidgets.showSaveOrderDialog(
                          context: context,
                          uid: widget.uid,
                          cartItems: _cartItems,
                          totalBill: _totalWithTax,
                          savedOrderId: widget.savedOrderId,
                          savedOrderName:
                              null, // QuickSale doesn't track order names yet
                          savedOrderPhone: _selectedCustomerPhone,
                          onSuccess: (orderName, orderId) {
                            setState(() {
                              _items.clear();
                              _input = '';
                              _counter = 1;
                              editingIndex = null;
                            });
                            _notifyChange(); // Notify parent that cart is now empty
                          },
                        );
                      },
                      onCustomer: () {
                        CommonWidgets.showCustomerSelectionDialog(
                          context: context,
                          onCustomerSelected: (phone, name, gst) {
                            setState(() {
                              _selectedCustomerPhone = phone;
                              _selectedCustomerName = name;
                              _selectedCustomerGST = gst;
                            });
                            // Notify parent about customer selection
                            widget.onCustomerChanged?.call(phone, name, gst);
                          },
                          selectedCustomerPhone: _selectedCustomerPhone,
                        );
                      },
                      customerName: _selectedCustomerName,
                      onBill: () {
                        if (_items.isNotEmpty) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => BillPage(
                                uid: widget.uid,
                                userEmail: widget.userEmail,
                                cartItems: _cartItems,
                                totalAmount: _totalWithTax,
                                savedOrderId: widget.savedOrderId,
                                customerPhone: _selectedCustomerPhone,
                                customerName: _selectedCustomerName,
                                customerGST: _selectedCustomerGST,
                              ),
                            ),
                          );
                        }
                      },
                      totalBill: _totalWithTax,
                      currencySymbol: _currencySymbol,
                    )
                  : const SizedBox.shrink(), // Hide buttons in quotation mode - parent provides floating bar
            ],
          ),
        ),
      ],
    );
  }

  // Build quotation-specific action buttons
  Widget _buildQuotationActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Add Customer Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                CommonWidgets.showCustomerSelectionDialog(
                  context: context,
                  onCustomerSelected: (phone, name, gst) {
                    setState(() {
                      _selectedCustomerPhone = phone;
                      _selectedCustomerName = name;
                      _selectedCustomerGST = gst;
                    });
                    // Notify parent about customer selection
                    if (widget.onCustomerChanged != null) {
                      widget.onCustomerChanged!(phone, name, gst);
                    }
                  },
                  selectedCustomerPhone: _selectedCustomerPhone,
                );
              },
              icon: Icon(
                _selectedCustomerName != null ? Icons.person : Icons.person_add,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                _selectedCustomerName ?? 'Customer',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Create Quotation Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (_items.isEmpty) {
                        CommonWidgets.showSnackBar(
                          context,
                          'Please add items first',
                          bgColor: Colors.orange,
                        );
                        return;
                      }
                      _generateQuotation();
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.description,
                      color: Colors.white,
                      size: 20,
                    ),
              label: const Text(
                'Quotation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numBtn(String num) => Expanded(
    child: GestureDetector(
      onTap: () => _handleInput(num == '•' ? '.' : num),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            num,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _opBtn(String op, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            op,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _actBtn(IconData icon, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Icon(icon, size: 22, color: Colors.black87)),
      ),
    ),
  );

  Widget _addBtn() => SizedBox(
    width: (MediaQuery.of(context).size.width - 48) / 4,
    height: 118,
    child: GestureDetector(
      onTap: _handleEnter,
      child: Container(
        decoration: BoxDecoration(
          color: _billingMode == 'item' ? kPrimaryColor : Color(0xffffab36),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _billingMode == 'productCode' ? 'Add' : 'Add',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _billingMode == 'productCode'
                      ? Colors.black
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _billingMode == 'productCode' ? 'Product' : 'Item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _billingMode == 'productCode'
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Dynamic button widgets with adaptive height
  Widget _numBtnDynamic(String num, double height) => Expanded(
    child: GestureDetector(
      onTap: () => _handleInput(num == '•' ? '.' : num),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            num,
            style: TextStyle(
              fontSize: height * 0.38,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _opBtnDynamic(String op, VoidCallback onTap, double height) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                op,
                style: TextStyle(
                  fontSize: height * 0.38,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _actBtnDynamic(IconData icon, VoidCallback onTap, double height) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, size: height * 0.38, color: Colors.black87),
            ),
          ),
        ),
      );

  Widget _addBtnDynamic(double height) => SizedBox(
    width: (MediaQuery.of(context).size.width - 48) / 4,
    height: height,
    child: GestureDetector(
      onTap: _addItem,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F7CF6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Add',
                style: TextStyle(
                  fontSize: height * 0.13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Item',
                style: TextStyle(
                  fontSize: height * 0.13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
