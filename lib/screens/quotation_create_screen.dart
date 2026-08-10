import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'quotation_view_screen.dart';

class _QuotationItemRow {
  final Map<String, dynamic> service;
  final Map<String, dynamic>? stockItem;
  final double warrantyYears;
  final double rate;
  final int freeTopup;

  _QuotationItemRow({
    required this.service,
    this.stockItem,
    required this.warrantyYears,
    required this.rate,
    required this.freeTopup,
  });

  String get serviceName => service['name']?.toString() ?? '';
  String get serviceId => service['id']?.toString() ?? '';
  String get stockItemName => stockItem?['item_name']?.toString() ?? 'N/A';
  String? get stockItemId => stockItem?['id']?.toString();
}

class _QuotationExtraRow {
  final String name;
  final double price;

  _QuotationExtraRow({required this.name, required this.price});
}

class QuotationCreateScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic>? existingQuotation;

  const QuotationCreateScreen({
    super.key,
    required this.customer,
    required this.vehicle,
    this.existingQuotation,
  });

  @override
  State<QuotationCreateScreen> createState() => _QuotationCreateScreenState();
}

class _QuotationCreateScreenState extends State<QuotationCreateScreen> {
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return CountryConfig.currencySymbol;
    }
  }

  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _allServices = [];
  List<dynamic> _filteredServices = [];
  List<dynamic> _enabledCategories = [];
  String _selectedCategoryFilter = 'all';

  List<dynamic> _allStockItems = [];

  // Active form inputs for adding an item
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedStockItem;

  final TextEditingController _warrantyController = TextEditingController(text: '1');
  final TextEditingController _rateController = TextEditingController(text: '0');
  final TextEditingController _freeTopupController = TextEditingController(text: '0');

  // Lists of added items and extras
  final List<_QuotationItemRow> _items = [];
  final List<_QuotationExtraRow> _extras = [];

  // Extras input controllers
  final TextEditingController _extraNameController = TextEditingController();
  final TextEditingController _extraPriceController = TextEditingController();

  // Additional fields
  final TextEditingController _additionalServiceController = TextEditingController();
  final TextEditingController _additionalDaysController = TextEditingController(text: '0');

  // Tax & Discount
  double _taxPercent = 0.0;
  final TextEditingController _discountController = TextEditingController(text: '0');

  double get itemsSubtotal => _items.fold(0.0, (sum, item) => sum + item.rate);
  double get extrasSubtotal => _extras.fold(0.0, (sum, extra) => sum + extra.price);
  double get subtotal => itemsSubtotal + extrasSubtotal;

  double get discountAmount => double.tryParse(_discountController.text) ?? 0.0;
  double get taxableValue => (subtotal - discountAmount).clamp(0.0, double.infinity);
  double get taxAmount => taxableValue * (_taxPercent / 100.0);
  double get grandTotal => (taxableValue + taxAmount).clamp(0.0, double.infinity);

  bool get isEditing => widget.existingQuotation != null;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_updateUi);
    _loadData();
  }

  @override
  void dispose() {
    _warrantyController.dispose();
    _rateController.dispose();
    _freeTopupController.dispose();
    _extraNameController.dispose();
    _extraPriceController.dispose();
    _additionalServiceController.dispose();
    _additionalDaysController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _updateUi() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final svcRes = await ApiService.getInvoiceServices(
        widget.customer['id'],
        widget.vehicle['id'],
        token,
      );
      final stockRes = await ApiService.getStockList(token);

      if (svcRes['success'] == true) {
        _allServices = svcRes['services'] ?? [];
        _filteredServices = List.from(_allServices);
        _enabledCategories = (svcRes['enabled_categories'] as List<dynamic>? ?? []);

        final rawTaxes = svcRes['taxes'] as List<dynamic>? ?? [];
        if (rawTaxes.isNotEmpty) {
          _taxPercent = (rawTaxes.first['percent'] as num?)?.toDouble() ?? 0.0;
        }
      }
      if (stockRes['success'] == true) {
        _allStockItems = stockRes['stocks'] ?? [];
      }

      // Pre-fill existing quotation data if editing
      if (isEditing && widget.existingQuotation != null) {
        final eq = widget.existingQuotation!;
        _additionalServiceController.text = eq['additional_services'] ?? '';
        _additionalDaysController.text = (eq['additional_days_needed'] ?? 0).toString();
        _discountController.text = (eq['discount'] ?? 0).toString();
        _taxPercent = (eq['tax_percentage'] as num?)?.toDouble() ?? _taxPercent;

        final rawItems = eq['items'] as List<dynamic>? ?? [];
        for (final it in rawItems) {
          final sId = it['service_id']?.toString();
          final matchingSvc = _allServices.firstWhere(
            (s) => s['id']?.toString() == sId,
            orElse: () => {'id': sId, 'name': it['service_name'] ?? ''},
          );
          final stkId = it['stock_item_id']?.toString();
          final matchingStk = _allStockItems.firstWhere(
            (s) => s['id']?.toString() == stkId,
            orElse: () => {'id': stkId, 'item_name': it['stock_item_name'] ?? ''},
          );

          _items.add(_QuotationItemRow(
            service: matchingSvc,
            stockItem: matchingStk,
            warrantyYears: (it['warranty_years'] as num?)?.toDouble() ?? 0.0,
            rate: (it['rate'] as num?)?.toDouble() ?? 0.0,
            freeTopup: int.tryParse(it['free_topup']?.toString() ?? '0') ?? 0,
          ));
        }

        final rawExtras = eq['extras'] as List<dynamic>? ?? [];
        for (final ex in rawExtras) {
          _extras.add(_QuotationExtraRow(
            name: ex['name'] ?? '',
            price: (ex['price'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }

      _isLoading = false;
      _updateUi();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _updateUi();
    }
  }

  void _filterServicesByCategory(String slug) {
    setState(() {
      _selectedCategoryFilter = slug;
      if (slug == 'all') {
        _filteredServices = List.from(_allServices);
      } else {
        _filteredServices = _allServices.where((s) => s['service_type_slug'] == slug).toList();
      }
      _selectedService = null;
    });
  }

  // ── Stock Item Search Picker Bottom Sheet ─────────────────────────────────
  void _openStockSearchPicker() {
    final searchCtrl = TextEditingController();
    List<dynamic> localList = List.from(_allStockItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: 400.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Select Stock Item'),
                      style: GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: context.tr('Search stock item...'),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (query) {
                        setModalState(() {
                          localList = _allStockItems.where((s) {
                            final name = (s['item_name'] ?? '').toString().toLowerCase();
                            return name.contains(query.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: localList.isEmpty
                          ? Center(child: Text(context.tr('No stock items found'), style: TextStyle(color: Colors.grey.shade500)))
                          : ListView.separated(
                              itemCount: localList.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final item = localList[idx];
                                return ListTile(
                                  title: Text(item['item_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    'Unit: ${item['unit_display'] ?? item['unit'] ?? ''} · Stock: ${item['quantity'] ?? 0}',
                                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedStockItem = item;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Add Item Entry ────────────────────────────────────────────────────────
  void _addItem() {
    if (_selectedService == null) {
      _snack(context.tr('Please select a service'), isError: true);
      return;
    }

    final warranty = double.tryParse(_warrantyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final freeTopup = int.tryParse(_freeTopupController.text) ?? 0;

    setState(() {
      _items.add(_QuotationItemRow(
        service: _selectedService!,
        stockItem: _selectedStockItem,
        warrantyYears: warranty,
        rate: rate,
        freeTopup: freeTopup,
      ));

      _selectedStockItem = null;
      _rateController.text = '0';
      _warrantyController.text = '1';
      _freeTopupController.text = '0';
    });
  }

  void _resetStockSelectionForAnother() {
    setState(() {
      _selectedStockItem = null;
      _rateController.text = '0';
      _warrantyController.text = '1';
      _freeTopupController.text = '0';
    });
  }

  // ── Add Extra Entry ───────────────────────────────────────────────────────
  void _addExtra() {
    final name = _extraNameController.text.trim();
    final price = double.tryParse(_extraPriceController.text) ?? 0.0;

    if (name.isEmpty) {
      _snack(context.tr('Please enter extra item name'), isError: true);
      return;
    }
    if (price <= 0) {
      _snack(context.tr('Please enter a valid price for extra item'), isError: true);
      return;
    }

    setState(() {
      _extras.add(_QuotationExtraRow(name: name, price: price));
      _extraNameController.clear();
      _extraPriceController.clear();
    });
  }

  // ── Save / Update Quotation ───────────────────────────────────────────────
  Future<void> _saveQuotation() async {
    if (_items.isEmpty && _extras.isEmpty) {
      _snack(context.tr('Please add at least one service item or extra'), isError: true);
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'customer_id': widget.customer['id'],
        'vehicle_id': widget.vehicle['id'],
        'items': _items.map((it) => {
          'service_id': it.serviceId,
          'service_name': it.serviceName,
          'stock_item_id': it.stockItemId,
          'stock_item_name': it.stockItemName,
          'warranty_years': it.warrantyYears,
          'rate': it.rate,
          'free_topup': it.freeTopup.toString(),
        }).toList(),
        'extras': _extras.map((ex) => {
          'name': ex.name,
          'price': ex.price,
        }).toList(),
        'additional_services': _additionalServiceController.text.trim(),
        'additional_days_needed': int.tryParse(_additionalDaysController.text) ?? 0,
        'subtotal': subtotal,
        'tax_percentage': _taxPercent,
        'tax_amount': taxAmount,
        'discount': discountAmount,
        'grand_total': grandTotal,
      };

      final response = isEditing
          ? await ApiService.updateQuotation(widget.existingQuotation!['id'], data, token)
          : await ApiService.createQuotation(data, token);

      setState(() => _isSaving = false);

      if (response['success'] == true) {
        final qId = response['quotation_id'] ?? widget.existingQuotation?['id'];
        _snack(isEditing ? context.tr('Quotation updated successfully') : context.tr('Quotation saved successfully'));

        if (!mounted) return;
        // Direct navigation to Quotation Preview Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationViewScreen(quotationId: qId),
          ),
        );
      } else {
        _snack(response['message'] ?? context.tr('Failed to save quotation'), isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _snack(e.toString(), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          isEditing ? context.tr('Edit Quotation') : context.tr('Create Quotation'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer & Vehicle Header
                      _buildHeaderCard(),
                      const SizedBox(height: 16),

                      // Service Selection & Category Tabs
                      _buildServiceStockSection(),
                      const SizedBox(height: 16),

                      // Added Items List
                      if (_items.isNotEmpty) ...[
                        _buildItemsListCard(),
                        const SizedBox(height: 16),
                      ],

                      // Extras Section
                      _buildExtrasSection(),
                      const SizedBox(height: 16),

                      // Additional Service & Days Needed
                      _buildAdditionalFieldsCard(),
                      const SizedBox(height: 16),

                      // Quotation Summary
                      _buildSummaryCard(),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveQuotation,
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _isSaving
                                ? (isEditing ? context.tr('Updating Quotation...') : context.tr('Saving Quotation...'))
                                : (isEditing ? context.tr('Update & View Quotation') : context.tr('Save & View Quotation')),
                            style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF000080).withValues(alpha: 0.1),
            child: const Icon(Icons.directions_car, color: Color(0xFF000080)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer['name'] ?? '',
                  style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                ),
                Text(
                  '${widget.customer['phone'] ?? ''}  •  ${widget.vehicle['no'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStockSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Service Category under Services'),
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
          ),
          const SizedBox(height: 10),

          // Category Pills Filter (Same as Create Invoice Page)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(context.tr('ALL')),
                  selected: _selectedCategoryFilter == 'all',
                  selectedColor: const Color(0xFF000080),
                  labelStyle: TextStyle(color: _selectedCategoryFilter == 'all' ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    if (selected) _filterServicesByCategory('all');
                  },
                ),
                const SizedBox(width: 8),
                ..._enabledCategories.map((slug) {
                  final title = slug.toString().replaceAll('_', ' ').toUpperCase();
                  final isSel = _selectedCategoryFilter == slug.toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(context.tr(title)),
                      selected: isSel,
                      selectedColor: const Color(0xFF000080),
                      labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                      onSelected: (selected) {
                        if (selected) _filterServicesByCategory(slug.toString());
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Service Dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedService,
            decoration: InputDecoration(
              labelText: context.tr('Select Service'),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF000080)),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            items: _filteredServices.map((svc) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: svc as Map<String, dynamic>,
                child: Text(svc['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (svc) {
              setState(() {
                _selectedService = svc;
                if (svc != null && svc['rate'] != null) {
                  _rateController.text = (svc['rate'] as num).toDouble().toString();
                }
              });
            },
          ),
          const SizedBox(height: 14),

          // Searchable Stock Item Dropdown
          if (_selectedService != null) ...[
            InkWell(
              onTap: _openStockSearchPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedStockItem != null
                            ? _selectedStockItem!['item_name'] ?? ''
                            : context.tr('Select Stock Item (Searchable)'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: _selectedStockItem != null ? Colors.black : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF000080)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Warranty Years, Rate, Numeric Free Topup Inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _warrantyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Warranty (Years)'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Rate ($currencySymbol)'),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Numeric Free Top-up
            TextField(
              controller: _freeTopupController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Free Top Up (Numeric)'),
                hintText: 'e.g. 1 or 2',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: Text(context.tr('Add Item'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000080),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetStockSelectionForAnother,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.tr('Add Another Stock'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF000080),
                      side: const BorderSide(color: Color(0xFF000080)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsListCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Added Items (${_items.length})'),
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.serviceName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp),
                          ),
                          if (item.stockItem != null)
                            Text(
                              '${context.tr('Stock')}: ${item.stockItemName}',
                              style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade700),
                            ),
                          Text(
                            '${context.tr('Warranty')}: ${item.warrantyYears} yrs  •  ${context.tr('Free Topup')}: ${item.freeTopup}',
                            style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$currencySymbol${item.rate.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF000080)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _items.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.more_horiz, color: Color(0xFF000080), size: 20),
              const SizedBox(width: 8),
              Text(
                context.tr('Extras'),
                style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _extraNameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Extra Name'),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _extraPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: context.tr('Price ($currencySymbol)'),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addExtra,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('Add')),
              ),
            ],
          ),

          if (_extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _extras.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ex = _extras[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ex.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                      Row(
                        children: [
                          Text('$currencySymbol${ex.price.toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                            onPressed: () {
                              setState(() {
                                _extras.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalFieldsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Additional Information'),
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _additionalServiceController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.tr('Additional Service Field'),
              hintText: context.tr('Enter any custom service or notes...'),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _additionalDaysController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('Additional Days Needed (Numeric)'),
              hintText: 'e.g. 2',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Quotation Summary'),
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
          ),
          const SizedBox(height: 12),
          _summaryRow(context.tr('Subtotal'), '$currencySymbol${subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Discount'), style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w600)),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    prefixText: currencySymbol,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_taxPercent > 0) ...[
            _summaryRow(context.tr('Tax ($_taxPercent%)'), '$currencySymbol${taxAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
          ],

          const Divider(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Grand Total'), style: GoogleFonts.inter(fontSize: 17.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080))),
              Text('$currencySymbol${grandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: const Color(0xFF000080))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey.shade700)),
        Text(value, style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
