import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class StockItemFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const StockItemFormScreen({super.key, this.item});

  @override
  State<StockItemFormScreen> createState() => _StockItemFormScreenState();
}

class _StockItemFormScreenState extends State<StockItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingDropdowns = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _hsnCodeController;
  late TextEditingController _barcodeController;
  late TextEditingController _criticalLevelController;
  late TextEditingController _profitMarginController;
  late TextEditingController _cgstController;
  late TextEditingController _sgstController;
  late TextEditingController _igstController;

  String? _selectedUnit;
  String? _selectedExpenseHeadId;
  String? _selectedGroupId;
  String? _selectedSubGroupId;
  bool _isTrading = true;
  bool _isOperational = false;

  List<dynamic> _expenseHeads = [];
  List<dynamic> _stockGroups = [];
  List<dynamic> _currentSubGroups = [];

  final List<Map<String, String>> _unitChoices = [
    {'value': 'Litre', 'display': 'Litre'},
    {'value': 'Piece', 'display': 'Piece / Pcs'},
    {'value': 'Box', 'display': 'Box'},
    {'value': 'Kilogram', 'display': 'KG'},
    {'value': 'Meter', 'display': 'Meter'},
    {'value': 'Bottle', 'display': 'Bottle'},
    {'value': 'Can', 'display': 'Can'},
    {'value': 'Gallon', 'display': 'Gallon'},
    {'value': 'Pack', 'display': 'Pack'},
    {'value': 'Set', 'display': 'Set'},
    {'value': 'Pair', 'display': 'Pair'},
    {'value': 'Barrel', 'display': 'Barrel'},
    {'value': 'Roll', 'display': 'Roll'},
  ];

  bool get isEdit => widget.item != null;

  Map<String, dynamic>? get _selectedGroupObj {
    if (_selectedGroupId == null) return null;
    final found = _stockGroups.firstWhere(
      (g) => g['id']?.toString() == _selectedGroupId,
      orElse: () => null,
    );
    return found != null ? Map<String, dynamic>.from(found) : null;
  }

  Map<String, dynamic>? get _selectedSubGroupObj {
    if (_selectedSubGroupId == null) return null;
    final found = _currentSubGroups.firstWhere(
      (sg) => sg['id']?.toString() == _selectedSubGroupId,
      orElse: () => null,
    );
    return found != null ? Map<String, dynamic>.from(found) : null;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _nameController = TextEditingController(text: item?['item_name'] ?? '');
    _brandController = TextEditingController(text: item?['brand'] ?? '');
    _hsnCodeController = TextEditingController(text: item?['hsn_code'] ?? '');
    _barcodeController = TextEditingController(text: item?['barcode'] ?? '');
    _criticalLevelController = TextEditingController(
      text: item?['critical_level'] != null ? item!['critical_level'].toString() : '0.0',
    );
    _profitMarginController = TextEditingController(
      text: item?['profit_margin_percent'] != null ? item!['profit_margin_percent'].toString() : '0.0',
    );
    _cgstController = TextEditingController(
      text: item?['cgst_percent'] != null ? item!['cgst_percent'].toString() : '0.0',
    );
    _sgstController = TextEditingController(
      text: item?['sgst_percent'] != null ? item!['sgst_percent'].toString() : '0.0',
    );
    _igstController = TextEditingController(
      text: item?['igst_percent'] != null ? item!['igst_percent'].toString() : '0.0',
    );

    _selectedUnit = item?['unit'] ?? item?['base_unit'];
    _selectedExpenseHeadId = item?['expense_head_id']?.toString();
    _selectedGroupId = item?['group_id']?.toString() ?? item?['group']?['id']?.toString();
    _selectedSubGroupId = item?['sub_group_id']?.toString() ?? item?['sub_group']?['id']?.toString();
    _isTrading = item?['is_trading'] ?? true;
    _isOperational = item?['is_operational'] ?? false;

    _fetchDropdownData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _hsnCodeController.dispose();
    _barcodeController.dispose();
    _criticalLevelController.dispose();
    _profitMarginController.dispose();
    _cgstController.dispose();
    _sgstController.dispose();
    _igstController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() => _isLoadingDropdowns = false);
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.getExpenseHeads(token).catchError((_) => <String, dynamic>{}),
        ApiService.getStockGroups(token).catchError((_) => <String, dynamic>{}),
      ]);

      if (mounted) {
        setState(() {
          if (results[0]['success'] == true) {
            _expenseHeads = results[0]['expense_heads'] ?? [];
          }
          if (results[1]['success'] == true) {
            _stockGroups = results[1]['groups'] ?? results[1]['stock_groups'] ?? [];
            _updateSubGroups();
          }
          _isLoadingDropdowns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  void _updateSubGroups() {
    if (_selectedGroupId == null) {
      _currentSubGroups = [];
      _selectedSubGroupId = null;
      return;
    }

    final group = _stockGroups.firstWhere(
      (g) => g['id']?.toString() == _selectedGroupId?.toString(),
      orElse: () => null,
    );

    if (group != null && group['sub_groups'] != null) {
      _currentSubGroups = List<dynamic>.from(group['sub_groups']);
      if (!_currentSubGroups.any((sg) => sg['id']?.toString() == _selectedSubGroupId?.toString())) {
        _selectedSubGroupId = null;
      }
    } else {
      _currentSubGroups = [];
      _selectedSubGroupId = null;
    }
  }

  void _showStockGroupSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            final filtered = _stockGroups.where((g) {
              final name = (g['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Stock Group'),
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: context.tr('Search stock groups...'),
                      hintStyle: GoogleFonts.inter(fontSize: 12.5.sp, color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      setInnerState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(
                            context.tr('None / ---------'),
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          trailing: _selectedGroupId == null
                              ? const Icon(Icons.check, color: Color(0xFF2563EB), size: 18)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedGroupId = null;
                              _updateSubGroups();
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                        const Divider(height: 1),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                context.tr('No stock groups found'),
                                style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        else
                          ...filtered.map((g) {
                            final idStr = g['id']?.toString();
                            final isSelected = idStr == _selectedGroupId;
                            return ListTile(
                              dense: true,
                              title: Text(
                                g['name'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Color(0xFF2563EB) : Color(0xFF1E293B),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: Color(0xFF2563EB), size: 18)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedGroupId = idStr;
                                  _updateSubGroups();
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSubGroupSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setInnerState) {
            final filtered = _currentSubGroups.where((sg) {
              final name = (sg['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Sub Group'),
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: context.tr('Search sub groups...'),
                      hintStyle: GoogleFonts.inter(fontSize: 12.5.sp, color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      setInnerState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(
                            context.tr('None / ---------'),
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          trailing: _selectedSubGroupId == null
                              ? const Icon(Icons.check, color: Color(0xFF2563EB), size: 18)
                              : null,
                          onTap: () {
                            setState(() => _selectedSubGroupId = null);
                            Navigator.pop(ctx);
                          },
                        ),
                        const Divider(height: 1),
                        if (_selectedGroupId == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                context.tr('Please select a Stock Item Group first'),
                                style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.amber.shade800),
                              ),
                            ),
                          )
                        else if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Text(
                                context.tr('No sub groups found for this group'),
                                style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade500),
                              ),
                            ),
                          )
                        else
                          ...filtered.map((sg) {
                            final idStr = sg['id']?.toString();
                            final isSelected = idStr == _selectedSubGroupId;
                            return ListTile(
                              dense: true,
                              title: Text(
                                sg['name'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Color(0xFF2563EB) : Color(0xFF1E293B),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: Color(0xFF2563EB), size: 18)
                                  : null,
                              onTap: () {
                                setState(() => _selectedSubGroupId = idStr);
                                Navigator.pop(ctx);
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveStockItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUnit == null || _selectedUnit!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a Base Unit')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'item_name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'unit': _selectedUnit,
      'group_id': _selectedGroupId,
      'sub_group_id': _selectedSubGroupId,
      'expense_head_id': _selectedExpenseHeadId,
      'hsn_code': _hsnCodeController.text.trim(),
      'barcode': _barcodeController.text.trim(),
      'is_trading': _isTrading,
      'is_operational': _isOperational,
      'critical_level': double.tryParse(_criticalLevelController.text.trim()) ?? 0.0,
      'profit_margin_percent': double.tryParse(_profitMarginController.text.trim()) ?? 0.0,
      'cgst_percent': double.tryParse(_cgstController.text.trim()) ?? 0.0,
      'sgst_percent': double.tryParse(_sgstController.text.trim()) ?? 0.0,
      'igst_percent': double.tryParse(_igstController.text.trim()) ?? 0.0,
    };

    try {
      final res = isEdit
          ? await ApiService.editStock(token, widget.item!['id'], payload)
          : await ApiService.createStock(token, payload);

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? context.tr('Stock item updated successfully!')
                  : context.tr('Stock item created successfully!'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? context.tr('Failed to save stock item')),
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

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText != null ? context.tr(hintText) : null,
      hintStyle: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false, String? optionalNote}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 12.sp, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
          children: [
            TextSpan(text: context.tr(label)),
            if (isRequired)
              TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            if (optionalNote != null)
              TextSpan(
                text: ' (${context.tr(optionalNote)})',
                style: GoogleFonts.inter(fontSize: 10.5.sp, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEdit ? context.tr('Edit Stock Item') : context.tr('Create Stock Item'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        backgroundColor: Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingDropdowns
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Form(
                key: _formKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Stock Item Group (Searchable Selector)
                      _buildFieldLabel('Stock Item Group'),
                      InkWell(
                        onTap: _showStockGroupSelector,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedGroupObj != null ? _selectedGroupObj!['name'] : context.tr('---------'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color: _selectedGroupObj != null ? Color(0xFF1E293B) : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Sub Group (Searchable Selector)
                      _buildFieldLabel('Sub Group'),
                      InkWell(
                        onTap: _showSubGroupSelector,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedSubGroupObj != null ? _selectedSubGroupObj!['name'] : context.tr('---------'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    color: _selectedSubGroupObj != null ? Color(0xFF1E293B) : Colors.grey.shade500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Item Name *
                      _buildFieldLabel('Item Name', isRequired: true),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(hintText: 'Enter Item name'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.tr('Please enter item name');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Base Unit *
                      _buildFieldLabel('Base Unit', isRequired: true),
                      DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        decoration: _inputDecoration(hintText: 'Select Base Unit'),
                        style: GoogleFonts.inter(fontSize: 13.sp, color: Color(0xFF1E293B)),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(context.tr('Select Base Unit'), style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade500)),
                          ),
                          ..._unitChoices.map((u) {
                            return DropdownMenuItem<String>(
                              value: u['value'],
                              child: Text(context.tr(u['display']!), style: TextStyle(fontSize: 13.sp)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedUnit = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Brand
                      _buildFieldLabel('Brand', optionalNote: 'non mandatory'),
                      TextFormField(
                        controller: _brandController,
                        decoration: _inputDecoration(hintText: 'Enter Brand name'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                      SizedBox(height: 12),

                      // 5. HSN Code
                      _buildFieldLabel('HSN Code', optionalNote: 'non mandatory'),
                      TextFormField(
                        controller: _hsnCodeController,
                        decoration: _inputDecoration(hintText: 'Enter Hsn code'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                      SizedBox(height: 12),

                      // 6. Barcode
                      _buildFieldLabel('Barcode', optionalNote: 'non mandatory'),
                      TextFormField(
                        controller: _barcodeController,
                        decoration: _inputDecoration(hintText: 'Enter Barcode'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                      SizedBox(height: 14),

                      // 7. Trading & Operational Checkboxes
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _isTrading = !_isTrading),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isTrading,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) => setState(() => _isTrading = val ?? false),
                                  ),
                                  Text(
                                    context.tr('Trading Item'),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _isOperational = !_isOperational),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isOperational,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) => setState(() => _isOperational = val ?? false),
                                  ),
                                  Text(
                                    context.tr('Operational Item'),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 8. Tax % Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.percent, color: Color(0xFF2563EB), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('Tax %'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildFieldLabel('CGST (%)'),
                            TextFormField(
                              controller: _cgstController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecoration(hintText: '0.0'),
                              style: GoogleFonts.inter(fontSize: 13.sp),
                            ),
                            SizedBox(height: 10),
                            _buildFieldLabel('SGST / SCGT (%)'),
                            TextFormField(
                              controller: _sgstController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecoration(hintText: '0.0'),
                              style: GoogleFonts.inter(fontSize: 13.sp),
                            ),
                            SizedBox(height: 10),
                            _buildFieldLabel('IGST (%)'),
                            TextFormField(
                              controller: _igstController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: _inputDecoration(hintText: '0.0'),
                              style: GoogleFonts.inter(fontSize: 13.sp),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 9. Profit Margin (%)
                      _buildFieldLabel('Profit Margin (%)'),
                      TextFormField(
                        controller: _profitMarginController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration(hintText: '0.0'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                      SizedBox(height: 12),

                      // 10. Critical Level (non mandatory)
                      _buildFieldLabel('Critical Level', optionalNote: 'non mandatory'),
                      TextFormField(
                        controller: _criticalLevelController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration(hintText: '0.0'),
                        style: GoogleFonts.inter(fontSize: 13.sp),
                      ),
                      SizedBox(height: 12),

                      // 11. Default Expense Head
                      _buildFieldLabel('Default Expense Head'),
                      DropdownButtonFormField<String>(
                        value: _selectedExpenseHeadId,
                        isExpanded: true,
                        decoration: _inputDecoration(hintText: '---------'),
                        style: GoogleFonts.inter(fontSize: 13.sp, color: Color(0xFF1E293B)),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(context.tr('---------'), style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade500)),
                          ),
                          ..._expenseHeads.map((h) {
                            final head = Map<String, dynamic>.from(h as Map);
                            return DropdownMenuItem<String>(
                              value: head['id']?.toString(),
                              child: Text(head['name'] ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedExpenseHeadId = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // 12. Bottom Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 44.h,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveStockItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: _isSaving
                              ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.check_circle_outline, size: 18),
                          label: Text(
                            isEdit ? context.tr('Save Changes') : context.tr('Save Stock Item'),
                            style: GoogleFonts.inter(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40.h,
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            context.tr('Cancel'),
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
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
}
