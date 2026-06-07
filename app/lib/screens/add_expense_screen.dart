import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Add an expense with optional receipt photo (FR-7).
///
/// The receipt is sent as a base64 data URL — simple and dependency-free for
/// Phase 2. Move to object storage (S3/GridFS) before scale.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendor = TextEditingController();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  Uint8List? _receiptBytes;
  bool _busy = false;

  static const _categories = ['Fuel', 'Tolls', 'Parking', 'Maintenance', 'Supplies', 'Other'];

  @override
  void dispose() {
    _vendor.dispose();
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1280,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _receiptBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().addExpense({
        'date': _date.toUtc().toIso8601String(),
        'vendor': _vendor.text.trim(),
        'category': _category.text.trim(),
        'amount': double.parse(_amount.text),
        if (_receiptBytes != null)
          'receiptImageUrl': 'data:image/jpeg;base64,${base64Encode(_receiptBytes!)}',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'Enter an amount greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vendor,
              decoration: const InputDecoration(
                labelText: 'Vendor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _categories
                  .map((c) => ChoiceChip(
                        label: Text(c),
                        selected: _category.text == c,
                        onSelected: (_) => setState(() => _category.text = c),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.all(Radius.circular(4))),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(_date.toLocal().toString().substring(0, 10)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 16),
            Text('Receipt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_receiptBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_receiptBytes!, height: 160, fit: BoxFit.cover),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickReceipt(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickReceipt(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
