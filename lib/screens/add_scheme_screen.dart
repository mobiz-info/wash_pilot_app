import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AddSchemeScreen extends StatefulWidget {
  const AddSchemeScreen({super.key});

  @override
  State<AddSchemeScreen> createState() => _AddSchemeScreenState();
}

class _AddSchemeScreenState extends State<AddSchemeScreen> {
  final _nameController = TextEditingController();
  final _paidController = TextEditingController();
  final _freeController = TextEditingController();
  final _discountController = TextEditingController();
  final _voucherNumberController = TextEditingController();
  final _voucherDiscountController = TextEditingController();

  final _loading = ValueNotifier<bool>(true);
  final _saving = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String>('');
  final _options = ValueNotifier<Map<String, dynamic>>({});
  final _schemeTypeId = ValueNotifier<String?>(null);
  final _startDate = ValueNotifier<DateTime>(DateTime.now());
  final _endDate = ValueNotifier<DateTime>(DateTime.now().add(const Duration(days: 30)));
  final Set<String> _serviceIds = {};
  final Set<String> _customerTypeIds = {};
  final Set<String> _vehicleTypeIds = {};
  final List<Map<String, String>> _vouchers = [];
  final _formNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _paidController.dispose();
    _freeController.dispose();
    _discountController.dispose();
    _voucherNumberController.dispose();
    _voucherDiscountController.dispose();
    _loading.dispose();
    _saving.dispose();
    _error.dispose();
    _options.dispose();
    _schemeTypeId.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _formNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _loading.value = true;
    _error.value = '';
    try {
      final res = await ApiService.getSchemeOptions(token);
      if (!mounted) return;
      if (res['success'] == true) {
        final types = List<dynamic>.from(res['scheme_types'] ?? []);
        _options.value = res;
        _schemeTypeId.value = types.isNotEmpty
            ? Map<String, dynamic>.from(types.first as Map)['id']?.toString()
            : null;
        _loading.value = false;
      } else {
        _error.value = res['message'] ?? 'Failed to load options';
        _loading.value = false;
      }
    } catch (e) {
      if (!mounted) return;
      _error.value = 'Network error: $e';
      _loading.value = false;
    }
  }

  String _apiDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  String get _selectedTypeName {
    for (final item in List<dynamic>.from(_options.value['scheme_types'] ?? [])) {
      final type = Map<String, dynamic>.from(item as Map);
      if (type['id']?.toString() == _schemeTypeId.value) {
        return type['name']?.toString() ?? '';
      }
    }
    return '';
  }

  bool get _isQuantity => _selectedTypeName.toLowerCase().contains('quantity');
  bool get _isDiscount => _selectedTypeName.toLowerCase().contains('discount');
  bool get _isVoucher => _selectedTypeName.toLowerCase().contains('voucher');

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate.value : _endDate.value,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080)),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (isStart) {
      _startDate.value = picked;
      if (_endDate.value.isBefore(picked)) _endDate.value = picked;
    } else {
      _endDate.value = picked;
    }
  }

  void _addVoucher() {
    final number = _voucherNumberController.text.trim();
    final discount = _voucherDiscountController.text.trim();
    if (number.isEmpty || discount.isEmpty) return;
    _vouchers.add({'voucher_number': number, 'discount': discount});
    _voucherNumberController.clear();
    _voucherDiscountController.clear();
    _formNotifier.value++;
  }

  Future<void> _save() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    if (_nameController.text.trim().isEmpty || _schemeTypeId.value == null) {
      _showError('Enter scheme name and type');
      return;
    }

    _saving.value = true;
    try {
      final res = await ApiService.createScheme({
        'name': _nameController.text.trim(),
        'scheme_type_id': _schemeTypeId.value,
        'start_date': _apiDate(_startDate.value),
        'end_date': _apiDate(_endDate.value),
        'service_ids': _serviceIds.toList(),
        'customer_type_ids': _customerTypeIds.toList(),
        'vehicle_type_ids': _vehicleTypeIds.toList(),
        'paid_visits': _paidController.text.trim(),
        'free_visits': _freeController.text.trim(),
        'discount_percentage': _discountController.text.trim(),
        'vouchers': _vouchers,
      }, token);

      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Scheme created')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh list
      } else {
        _showError(res['message'] ?? 'Failed to create scheme');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: $e');
    } finally {
      if (mounted) _saving.value = false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        title: Text(
          context.tr('Add Scheme'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _loading,
        builder: (context, isLoading, _) => ValueListenableBuilder<String>(
          valueListenable: _error,
          builder: (context, err, _) {
            if (isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF000080)),
              );
            }
            if (err.isNotEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      err,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadOptions, child: Text(context.tr('Retry'))),
                  ],
                ),
              );
            }
            return ValueListenableBuilder<int>(
              valueListenable: _formNotifier,
              builder: (context, _, __) => _buildForm(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _textField(_nameController, 'Scheme Name', Icons.local_offer_outlined),
        const SizedBox(height: 12),
        ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: _options,
          builder: (context, opts, _) => ValueListenableBuilder<String?>(
            valueListenable: _schemeTypeId,
            builder: (context, typeId, _) => _schemeTypeDropdown(opts, typeId),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _startDate,
                builder: (context, startD, _) => _dateTile(
                  'Start',
                  startD,
                  () => _pickDate(isStart: true),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _endDate,
                builder: (context, endD, _) => _dateTile(
                  'End',
                  endD,
                  () => _pickDate(isStart: false),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isQuantity) ...[
          Row(
            children: [
              Expanded(
                child: _textField(
                  _paidController,
                  'Paid Visits',
                  Icons.local_car_wash,
                  isNumber: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  _freeController,
                  'Free Visits',
                  Icons.redeem,
                  isNumber: true,
                ),
              ),
            ],
          ),
        ] else if (_isDiscount) ...[
          _textField(
            _discountController,
            'Discount Percentage',
            Icons.percent,
            isNumber: true,
          ),
        ] else if (_isVoucher) ...[
          Row(
            children: [
              Expanded(
                child: _textField(
                  _voucherNumberController,
                  'Voucher No',
                  Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  _voucherDiscountController,
                  'Discount',
                  Icons.payments_outlined,
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addVoucher,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add Voucher')),
          ),
          ..._vouchers.asMap().entries.map((entry) {
            final voucher = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(voucher['voucher_number'] ?? ''),
              subtitle: Text(context.tr('Discount: ${voucher['discount']}')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  _vouchers.removeAt(entry.key);
                  _formNotifier.value++;
                },
              ),
            );
          }),
        ],
        const SizedBox(height: 16),
        _optionChips('Services', _options.value['services'] ?? [], _serviceIds),
        const SizedBox(height: 14),
        _optionChips(
          'Customer Types',
          _options.value['customer_types'] ?? [],
          _customerTypeIds,
        ),
        const SizedBox(height: 14),
        _optionChips(
          'Vehicle Types',
          _options.value['vehicle_types'] ?? [],
          _vehicleTypeIds,
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ValueListenableBuilder<bool>(
            valueListenable: _saving,
            builder: (context, isSaving, _) => ElevatedButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Saving...' : 'Save Scheme'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _schemeTypeDropdown(Map<String, dynamic> opts, String? currentTypeId) {
    final types = List<dynamic>.from(opts['scheme_types'] ?? []);
    return DropdownButtonFormField<String>(
      value: currentTypeId,
      isExpanded: true,
      menuMaxHeight: 350,
      decoration: _inputDecoration('Scheme Type', Icons.category_outlined),
      items: types.map((item) {
        final type = Map<String, dynamic>.from(item as Map);
        return DropdownMenuItem<String>(
          value: type['id']?.toString(),
          child: Text(type['name']?.toString() ?? ''),
        );
      }).toList(),
      onChanged: (value) {
        _schemeTypeId.value = value;
        _formNotifier.value++;
      },
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF000080),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    _displayDate(date),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionChips(
    String title,
    List<dynamic> items,
    Set<String> selectedIds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            context.tr('All $title'),
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final option = Map<String, dynamic>.from(item as Map);
              final id = option['id']?.toString() ?? '';
              final selected = selectedIds.contains(id);
              return FilterChip(
                label: Text(option['name']?.toString() ?? ''),
                selected: selected,
                selectedColor: const Color(0xFFEFF6FF),
                checkmarkColor: const Color(0xFF000080),
                onSelected: (value) {
                  if (value) {
                    selectedIds.add(id);
                  } else {
                    selectedIds.remove(id);
                  }
                  _formNotifier.value++;
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
