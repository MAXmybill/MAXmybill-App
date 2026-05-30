import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxmybill/services/notification_service.dart';
import 'package:maxmybill/Colors.dart';

class KnowledgeEditorPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;

  const KnowledgeEditorPage({super.key, this.docId, this.data});

  @override
  State<KnowledgeEditorPage> createState() => _KnowledgeEditorPageState();
}

class _KnowledgeEditorPageState extends State<KnowledgeEditorPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late String _category;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.data?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.data?['content'] ?? '');
    _category = widget.data?['category'] ?? 'General';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;
    return Scaffold(
      backgroundColor: kGreyBg,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        title: Text(isEdit ? 'Edit Article' : 'New Article', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(_titleCtrl, 'Article Title', HeroIcons.pencil),
                  const SizedBox(height: 12),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 12),
                  _buildField(_contentCtrl, 'Content', HeroIcons.pencilSquare, maxLines: 6),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEdit)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: kErrorColor, backgroundColor: kWhite),
                      onPressed: _isLoading ? null : _deleteArticle,
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                if (isEdit) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor, elevation: 0),
                    onPressed: _isLoading ? null : _saveArticle,
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: kWhite, strokeWidth: 2)) : Text(isEdit ? 'Save' : 'Post', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, HeroIcons icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Padding(padding: const EdgeInsets.all(12.0), child: HeroIcon(icon, color: kPrimaryColor, size: 18)),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kGrey200)),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: kGreyBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGrey200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          icon: const HeroIcon(HeroIcons.chevronDown, color: kBlack54, size: 20),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kBlack87),
          items: ['General', 'Tutorial', 'Updates', 'Tips'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _category = v ?? 'General'),
        ),
      ),
    );
  }

  Future<void> _saveArticle() async {
    final titleText = _titleCtrl.text.trim();
    final contentText = _contentCtrl.text.trim();
    if (titleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title'), backgroundColor: kErrorColor));
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      'title': titleText,
      'content': contentText,
      'category': _category,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.docId == null) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('knowledge').add(payload);
        await NotificationService().sendKnowledgeNotification(title: titleText, content: contentText, category: _category);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article posted successfully'), backgroundColor: kGoogleGreen));
        }
      } else {
        await FirebaseFirestore.instance.collection('knowledge').doc(widget.docId).update(payload);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article updated successfully'), backgroundColor: kGoogleGreen));
        }
      }
    } catch (e) {
      debugPrint('Error saving article: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: kErrorColor));
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteArticle() async {
    if (widget.docId == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete this article?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: kErrorColor)))]
    ));

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('knowledge').doc(widget.docId).delete();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Article deleted successfully'), backgroundColor: kGoogleGreen));
      }
    } catch (e) {
      debugPrint('Error deleting article: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: kErrorColor));
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }
}

