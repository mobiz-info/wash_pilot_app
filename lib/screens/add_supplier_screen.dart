import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class AddSupplierScreen extends StatefulWidget {
  final Map<String, dynamic>? supplier; // null = add, non-null = edit

  const AddSupplierScreen({super.key, this.supplier});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();

  // Credit fields
  final _creditLimitController = TextEditingController();
  final _creditDaysController = TextEditingController();
  final _noOfInvoicesController = TextEditingController();

  String _supplierType = 'cash'; // cash | credit | bill_to_bill
  bool _isSaving = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    if (s != null) {
      _nameController.text = s['name'] ?? '';
      _phoneController.text = s['phone_no'] ?? '';
      _gstController.text = s['gst_no'] ?? '';
      _addressController.text = s['address'] ?? '';
      _supplierType = s['supplier_type'] ?? 'cash';
      _creditLimitController.text = s['credit_limit']?.toString() ?? '';
      _creditDaysController.text = s['credit_days']?.toString() ?? '';
      _noOfInvoicesController.text = s['no_of_invoices']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    _creditLimitController.dispose();
    _creditDaysController.dispose();
    _noOfInvoicesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        if (_isEditing) 'id': widget.supplier!['id'],
        'name': _nameController.text.trim(),
        'phone_no': _phoneController.text.trim(),
        'gst_no': _gstController.text.trim(),
        'address': _addressController.text.trim(),
        'supplier_type': _supplierType,
        'is_active': widget.supplier?['is_active'] ?? true,
        if (_supplierType == 'credit') ...{
          'credit_limit': double.tryParse(_creditLimitController.text.trim()) ?? 0,
          'credit_days': int.tryParse(_creditDaysController.text.trim()) ?? 0,
          'no_of_invoices': int.tryParse(_noOfInvoicesController.text.trim()) ?? 0,
        },
      };

      final res = await ApiService.createSupplier(token, payload);
      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? context.tr('Failed to save supplier')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr(_isEditing ? 'Edit Supplier' : 'Add Supplier'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Basic Info Card ─────────────────────────────────────────
              _sectionCard(
                title: context.tr('Supplier Information'),
                icon: Icons.business,
                children: [
                  _field(
                    controller: _nameController,
                    label: context.tr('Supplier Name *'),
                    icon: Icons.badge_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? context.tr('Please enter a name') : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _phoneController,
                    label: context.tr('Phone Number *'),
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? context.tr('Please enter a phone number') : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _gstController,
                    label: context.tr('Tax Details (Optional)'),
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _addressController,
                    label: context.tr('Address *'),
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? context.tr('Please enter address') : null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Supplier Type Card ──────────────────────────────────────
              _sectionCard(
                title: context.tr('Supplier Type'),
                icon: Icons.account_balance_wallet_outlined,
                children: [
                  _supplierTypeRadio('cash', context.tr('Cash'), Icons.money),
                  const SizedBox(height: 8),
                  _supplierTypeRadio('credit', context.tr('Credit'), Icons.credit_score),
                  const SizedBox(height: 8),
                  _supplierTypeRadio('bill_to_bill', context.tr('Bill to Bill'), Icons.receipt_long),

                  // Credit fields
                  if (_supplierType == 'credit') ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Credit Details'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFF000080),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _creditLimitController,
                      label: context.tr('Credit Limit *'),
                      icon: Icons.price_change_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) {
                        if (_supplierType != 'credit') return null;
                        if (v == null || v.trim().isEmpty) return context.tr('Please enter credit limit');
                        if (double.tryParse(v.trim()) == null) return context.tr('Invalid amount');
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _creditDaysController,
                      label: context.tr('Credit Days *'),
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (_supplierType != 'credit') return null;
                        if (v == null || v.trim().isEmpty) return context.tr('Please enter credit days');
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _noOfInvoicesController,
                      label: context.tr('No. of Invoices *'),
                      icon: Icons.description_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (_supplierType != 'credit') return null;
                        if (v == null || v.trim().isEmpty) return context.tr('Please enter no. of invoices');
                        return null;
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 28),

              // ── Save Button ─────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  context.tr(_isEditing ? 'Update Supplier' : 'Add Supplier'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supplierTypeRadio(String value, String label, IconData icon) {
    final isSelected = _supplierType == value;
    return GestureDetector(
      onTap: () => setState(() => _supplierType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF000080).withValues(alpha: 0.07)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF000080) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF000080) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.circle, color: Colors.white, size: 10)
                  : null,
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF000080) : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF000080) : Colors.black87,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF000080),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF000080)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF000080), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
