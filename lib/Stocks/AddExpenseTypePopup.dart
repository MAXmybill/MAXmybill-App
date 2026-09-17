import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxmybill/utils/firestore_service.dart';
import 'package:maxmybill/utils/translation_helper.dart';
import 'package:maxmybill/Colors.dart';
import 'package:heroicons/heroicons.dart';

class AddExpenseTypePopup extends StatefulWidget {
  final String uid;
  final String? userEmail;
  final List<String>? existingTypes;

  const AddExpenseTypePopup({
    super.key,
    required this.uid,
    this.userEmail,
    this.existingTypes,
  });

  @override
  State<AddExpenseTypePopup> createState() => _AddExpenseTypePopupState();
}

class _AddExpenseTypePopupState extends State<AddExpenseTypePopup> {
  final TextEditingController _typeController = TextEditingController();
  bool _isLoading = false;
  static const List<String> _defaultSuggestions = ['Fixed Expense', 'Variable Expense', 'Salary'];
  List<String> _existingTypes = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingTypes != null) {
      _existingTypes = List.from(widget.existingTypes!);
    }
    _loadExistingTypes();
  }

  Future<void> _loadExistingTypes() async {
    try {
      final col = await FirestoreService().getStoreCollection('expenseCategories');
      final snap = await col.get();
      if (mounted) {
        final names = snap.docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>?;
              return (data?['name'] ?? '').toString().trim();
            })
            .where((n) => n.isNotEmpty)
            .toList();
        setState(() {
          final merged = <String>{..._existingTypes, ...names};
          _existingTypes = merged.toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading existing types: $e");
    }
  }

  List<String> get _availableSuggestions {
    final existingLower = _existingTypes.map((e) => e.trim().toLowerCase()).toSet();
    return _defaultSuggestions.where((s) => !existingLower.contains(s.toLowerCase())).toList();
  }

  @override
  void dispose() {
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _saveType() async {
    final typeName = _typeController.text.trim();
    if (typeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('enter_expense_type'))),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final typesCollection = await FirestoreService().getStoreCollection('expenseCategories');
      final existingType = await typesCollection.where('name', isEqualTo: typeName).get();
      if (existingType.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('expense_type_exists'))),
        );
        setState(() => _isLoading = false);
        return;
      }
      await FirestoreService().addDocument('expenseCategories', {
        'name': typeName,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'ownerUid': widget.uid,
        'uid': widget.uid,
        'ownerEmail': widget.userEmail,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('expense_type_added_success'))),
      );
      Navigator.pop(context, typeName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_adding_expense_type'))),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final unusedSuggestions = _availableSuggestions;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Expense Type',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const HeroIcon(HeroIcons.xMark, size: 24, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Select (only shown if there are unused suggestions)
            if (unusedSuggestions.isNotEmpty) ...[
              _buildQuickSelect(unusedSuggestions),
              const SizedBox(height: 18),
            ],

            // Input Field
            _buildExpenseTypeInput(),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveType,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Add',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Quick Select Chips ---
  Widget _buildQuickSelect(List<String> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Select",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: kBlack54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _typeController,
          builder: (context, value, _) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((s) {
                final bool isSel = value.text.trim() == s;
                return GestureDetector(
                  onTap: () {
                    _typeController.text = s;
                    _typeController.selection = TextSelection.fromPosition(
                      TextPosition(offset: s.length),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSel ? kPrimaryColor : kGreyBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? kPrimaryColor : kGrey200),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSel ? kWhite : kBlack54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // --- Custom Input Field ---
  Widget _buildExpenseTypeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<TextEditingValue>(
      valueListenable: _typeController,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextFormField(
          controller: _typeController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          decoration: InputDecoration(
            label: const Text.rich(
              TextSpan(
                text: 'Expense Type Name',
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: kOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
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
        const SizedBox(height: 6),
        Text(
          "e.g. Fixed Expense, Variable Expense, Salary",
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
