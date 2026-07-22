import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';
import 'invoice_view_screen.dart';

// ── Per-service row state ────────────────────────────────────────────────────
class _ServiceRow {
  final Map<String, dynamic> service;
  Map<String, dynamic>? selectedScheme;
  double schemeDiscount = 0.0;
  List<dynamic> availableSchemes = [];
  bool isLoadingSchemes = false;

  // Voucher state (per row)
  final TextEditingController voucherController = TextEditingController();
  String? voucherError;
  String? voucherSuccess;
  bool voucherValidating = false;
  String? validatedVoucherId;

  // Manual discount (shown only when no scheme selected on this row)
  final TextEditingController discountController =
      TextEditingController(text: '0');

  // ── Category-specific Inputs ──
  String get serviceCategory => service['service_type_slug']?.toString() ?? '';

  // Oil Change
  String? selectedOilProductId;
  String? selectedOilGroupKey;
  double? selectedOilVolume;
  int? selectedOilRunKm;
  double? oilPricePerLitre;
  bool isLoadingOilPrice = false;
  final TextEditingController oilLitresController = TextEditingController();
  bool oilFilterChanged = false;
  final TextEditingController odometerController = TextEditingController();
  final TextEditingController nextOilChangeKmController = TextEditingController();

  double get oilLitres => double.tryParse(oilLitresController.text) ?? 0.0;
  double get oilTotalCharge => (oilPricePerLitre ?? 0.0) * oilLitres;

  // Tyre Change
  String? selectedTyreBrandId;
  final TextEditingController tyreSizeController = TextEditingController();
  int tyresChangedCount = 4;
  final TextEditingController nextTyreChangeKmController = TextEditingController();

  // Wheel Alignment
  bool alignmentDone = true;
  bool balancingDone = true;
  final TextEditingController alignmentNotesController = TextEditingController();

  _ServiceRow({required this.service}) {
    // If odometer controller is updated, auto-calculate next oil/tyre change km if blank
    odometerController.addListener(_onOdometerChanged);
  }

  void _onOdometerChanged() {
    final odo = int.tryParse(odometerController.text) ?? 0;
    if (odo > 0) {
      if (serviceCategory == 'oil_change') {
        final runKm = selectedOilRunKm ?? 5000;
        nextOilChangeKmController.text = (odo + runKm).toString();
      }
      if (serviceCategory == 'tyre_change' && nextTyreChangeKmController.text.isEmpty) {
        // Default to +40000 km
        nextTyreChangeKmController.text = (odo + 40000).toString();
      }
    }
  }

  double get rate => (service['rate'] as num).toDouble();

  double get effectiveDiscount {
    if (selectedScheme != null) return schemeDiscount;
    return double.tryParse(discountController.text) ?? 0.0;
  }

  double get lineTotal {
    double base = rate;
    if (serviceCategory == 'oil_change') {
      base += oilTotalCharge;
    }
    return (base - effectiveDiscount).clamp(0.0, double.infinity);
  }

  String get serviceId => service['id'] as String;
  String get serviceName => service['name'] as String;

  void dispose() {
    voucherController.dispose();
    discountController.dispose();
    oilLitresController.dispose();
    odometerController.removeListener(_onOdometerChanged);
    odometerController.dispose();
    nextOilChangeKmController.dispose();
    tyreSizeController.dispose();
    nextTyreChangeKmController.dispose();
    alignmentNotesController.dispose();
  }
}


// ── Main screen ───────────────────────────────────────────────────────────────
class InvoiceCreateScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> vehicle;
  final String? bookingId;

  const InvoiceCreateScreen({
    super.key,
    required this.customer,
    required this.vehicle,
    this.bookingId,
  });

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
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

  // All services available for selection
  List<dynamic> _allServices = [];

  // Taxes (company-level, applied on whole invoice subtotal)
  List<Map<String, dynamic>> _availableTaxes = [];
  Set<String> _selectedTaxIds = {};
  bool _applyGst = false;

  // Selected service rows (each row = one service line)
  final List<_ServiceRow> _rows = [];

  // Available extras
  List<dynamic> _availableExtras = [];
  // Selected extras
  final List<Map<String, dynamic>> _selectedExtras = [];

  // Oil Products, Tyre Brands, and Enabled Categories
  List<dynamic> _oilProducts = [];
  List<dynamic> _tyreBrands = [];
  List<dynamic> _enabledCategories = [];
  String _selectedCategoryFilter = 'all';



  // Amount collected
  final _amountCollectedController = TextEditingController(text: '0');

  // Payment mode selection state
  String _selectedPaymentMode = 'digital_payments';

  double get totalServicesAmount => _rows.fold(
      0.0,
      (s, r) =>
          s + r.rate + (r.serviceCategory == 'oil_change' ? r.oilTotalCharge : 0.0));
  double get totalExtrasAmount => _selectedExtras.fold(
      0.0,
      (s, e) =>
          s +
          (double.tryParse(
                  (e['priceController'] as TextEditingController).text) ??
              0.0));
  double get totalDiscount => _rows.fold(0.0, (s, r) => s + r.effectiveDiscount);
  double get subtotal =>
      (totalServicesAmount + totalExtrasAmount - totalDiscount)
          .clamp(0.0, double.infinity);
  double get taxAmount {
    if (!_applyGst) return 0;
    double t = 0;
    for (final tax in _availableTaxes) {
      if (_selectedTaxIds.contains(tax['id'] as String)) {
        t += subtotal * ((tax['percent'] as num).toDouble() / 100);
      }
    }
    return t;
  }

  double get total => subtotal + taxAmount;

  List<Map<String, dynamic>> get selectedTaxes => _applyGst
      ? _availableTaxes
          .where((t) => _selectedTaxIds.contains(t['id'] as String))
          .map((t) {
            final pct = (t['percent'] as num).toDouble();
            return {
              'id': t['id'],
              'name': t['name'],
              'percent': pct,
              'amount': (subtotal * pct / 100).toStringAsFixed(2),
            };
          })
          .toList()
      : [];

  // Determine if any row already uses a Quantity (free wash) scheme
  String? get _quantitySchemeUsedId {
    for (final row in _rows) {
      if (row.selectedScheme != null &&
          row.selectedScheme!['scheme_type'] == 'Quantity') {
        return row.selectedScheme!['id'] as String;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    for (final extra in _selectedExtras) {
      (extra['priceController'] as TextEditingController).dispose();
    }
    _amountCollectedController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final svcRes = await ApiService.getInvoiceServices(
        widget.customer['id'],
        widget.vehicle['id'],
        token,
      );
      final extRes = await ApiService.getExtrasList(token);

      Map<String, dynamic>? oilRes;
      Map<String, dynamic>? tyreRes;
      try {
        oilRes = await ApiService.getOilProducts(token);
        tyreRes = await ApiService.getTyreBrands(token);
      } catch (_) {}

      setState(() {
        if (svcRes['success'] == true) {
          _allServices = svcRes['services'] ?? [];
          _enabledCategories = svcRes['enabled_categories'] ?? [];
          final rawTaxes = svcRes['taxes'] as List<dynamic>? ?? [];
          _availableTaxes =
              rawTaxes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
          _selectedTaxIds =
              _availableTaxes.map((t) => t['id'] as String).toSet();
        }
        if (extRes['success'] == true) {
          _availableExtras = extRes['extras'] ?? [];
        }
        if (oilRes != null && oilRes['success'] == true) {
          _oilProducts = oilRes['oil_products'] ?? [];
        }
        if (tyreRes != null && tyreRes['success'] == true) {
          _tyreBrands = tyreRes['tyre_brands'] ?? [];
        }
        _isLoading = false;
        _syncAmountCollected();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }


  void _syncAmountCollected() {
    _amountCollectedController.text = total.round().toString();
  }

  // ── Add / Remove service rows ─────────────────────────────────────────────
  void _toggleService(Map<String, dynamic> svc) {
    setState(() {
      final idx = _rows.indexWhere((r) => r.serviceId == svc['id']);
      if (idx >= 0) {
        _rows[idx].dispose();
        _rows.removeAt(idx);
      } else {
        final row = _ServiceRow(service: svc);
        row.discountController.addListener(() => setState(() {
              _syncAmountCollected();
            }));
        _rows.add(row);
        _loadSchemesForRow(row);
      }
      _syncAmountCollected();
    });
  }

  bool _isServiceSelected(String serviceId) =>
      _rows.any((r) => r.serviceId == serviceId);

  Future<void> _loadSchemesForRow(_ServiceRow row) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => row.isLoadingSchemes = true);

    try {
      final res = await ApiService.getAvailableSchemes(
        widget.customer['id'],
        widget.vehicle['id'],
        row.serviceId,
        token,
      );
      if (!mounted) return;
      setState(() {
        row.availableSchemes =
            res['success'] == true ? res['schemes'] ?? [] : [];
        row.isLoadingSchemes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        row.availableSchemes = [];
        row.isLoadingSchemes = false;
      });
    }
  }

  Future<void> _fetchOilPriceForProduct(_ServiceRow row, String oilProductId) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => row.isLoadingOilPrice = true);

    try {
      final res = await ApiService.getOilPrice(
        token,
        oilProductId,
        vehicleMakeId: widget.vehicle['make_id']?.toString(),
        vehicleTypeId: widget.vehicle['vehicle_type_id']?.toString(),
      );
      if (!mounted) return;
      setState(() {
        row.isLoadingOilPrice = false;
        if (res['success'] == true) {
          if (res['price_per_litre'] != null && (res['price_per_litre'] as num) > 0) {
            row.oilPricePerLitre = (res['price_per_litre'] as num).toDouble();
          }
        }
        _syncAmountCollected();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => row.isLoadingOilPrice = false);
    }
  }

  // ── Scheme selection per row ─────────────────────────────────────────────
  void _selectScheme(_ServiceRow row, Map<String, dynamic>? scheme) {
    setState(() {
      row.selectedScheme = scheme;
      row.schemeDiscount = 0.0;
      row.voucherController.clear();
      row.voucherError = null;
      row.voucherSuccess = null;
      row.validatedVoucherId = null;
    });

    if (scheme == null) {
      _syncAmountCollected();
      return;
    }

    final st = scheme['scheme_type'] as String;
    if (st == 'Discount') {
      final pct = (scheme['discount_percentage'] as num?)?.toDouble() ?? 0.0;
      setState(() => row.schemeDiscount = row.rate * pct / 100);
    } else if (st == 'Quantity') {
      // Only apply full discount when the customer is eligible (reached paid_visits)
      // If not yet eligible, discount = 0 but scheme is still recorded for progress tracking
      if (scheme['is_eligible'] == true) {
        setState(() => row.schemeDiscount = row.rate);
      }
      // else: schemeDiscount stays 0.0 — visit counts toward progress but no free wash yet
    }
    _syncAmountCollected();
  }

  Future<void> _validateVoucher(_ServiceRow row) async {
    if (row.selectedScheme == null) return;
    final voucher = row.voucherController.text.trim();
    if (voucher.isEmpty) {
      setState(() => row.voucherError = 'Please enter a voucher number');
      return;
    }

    final token = context.read<AuthProvider>().token!;
    setState(() {
      row.voucherValidating = true;
      row.voucherError = null;
      row.voucherSuccess = null;
    });

    try {
      final res =
          await ApiService.validateVoucher(row.selectedScheme!['id'], voucher, token);
      if (res['success'] == true) {
        setState(() {
          row.schemeDiscount = (res['discount'] as num).toDouble();
          row.voucherSuccess = res['message'] ?? 'Voucher applied!';
          row.validatedVoucherId = res['voucher_id'];
          row.voucherValidating = false;
        });
        _syncAmountCollected();
      } else {
        setState(() {
          row.voucherError = res['message'] ?? 'Invalid voucher';
          row.voucherValidating = false;
        });
      }
    } catch (e) {
      setState(() {
        row.voucherError = e.toString();
        row.voucherValidating = false;
      });
    }
  }

  // ── Save Invoice ─────────────────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    if (_rows.isEmpty) {
      _snack(context.tr('Please select at least one service'), isError: true);
      return;
    }

    // Validate Voucher schemes
    for (final row in _rows) {
      if (row.selectedScheme != null &&
          row.selectedScheme!['scheme_type'] == 'Voucher' &&
          row.validatedVoucherId == null) {
        _snack(
          '${context.tr('Please validate the voucher for')} "${context.tr(row.serviceName)}"',
          isError: true,
        );
        return;
      }
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => _isSaving = true);

    try {
      // Use the primary scheme from the first row that has one
      final primaryRow =
          _rows.firstWhere((r) => r.selectedScheme != null, orElse: () => _rows.first);
      final primarySchemeId = primaryRow.selectedScheme?['id'];
      final primaryVoucherId = primaryRow.validatedVoucherId;

      final services = [
        ..._rows.map((r) {
          Map<String, dynamic>? detail;
          if (r.serviceCategory == 'oil_change') {
            detail = {
              'service_category': 'oil_change',
              'oil_product_id': r.selectedOilProductId,
              'oil_litres_used': double.tryParse(r.oilLitresController.text),
              'oil_filter_changed': r.oilFilterChanged,
              'odometer_at_service': int.tryParse(r.odometerController.text),
              'next_oil_change_km': int.tryParse(r.nextOilChangeKmController.text),
            };
          } else if (r.serviceCategory == 'tyre_change') {
            detail = {
              'service_category': 'tyre_change',
              'tyre_brand_id': r.selectedTyreBrandId,
              'tyre_size': r.tyreSizeController.text.trim(),
              'tyres_changed_count': r.tyresChangedCount,
              'odometer_at_service': int.tryParse(r.odometerController.text),
              'next_tyre_change_km': int.tryParse(r.nextTyreChangeKmController.text),
            };
          } else if (r.serviceCategory == 'wheel_alignment') {
            detail = {
              'service_category': 'wheel_alignment',
              'alignment_done': r.alignmentDone,
              'balancing_done': r.balancingDone,
              'alignment_notes': r.alignmentNotesController.text.trim(),
              'odometer_at_service': int.tryParse(r.odometerController.text),
            };
          }
          return {
            'id': r.serviceId,
            'name': r.serviceName,
            'rate': r.rate + (r.serviceCategory == 'oil_change' ? r.oilTotalCharge : 0.0),
            'discount': r.effectiveDiscount,
            if (detail != null) 'service_detail': detail,
          };
        }),
        ..._selectedExtras.map((e) => {
              'id': null,
              'name': e['extra']['name'],
              'rate': double.tryParse((e['priceController'] as TextEditingController).text) ?? 0.0,
              'discount': 0.0,
            }),
      ];


      final invoiceData = {
        'customer_id': widget.customer['id'],
        'vehicle_id': widget.vehicle['id'],
        'subtotal': subtotal,
        'discount': totalDiscount,
        'tax_amount': taxAmount,
        'total': total,
        'amount_collected':
            double.tryParse(_amountCollectedController.text) ?? 0.0,
        'payment_mode': _selectedPaymentMode,
        'services': services,
        if (widget.bookingId != null) 'booking_id': widget.bookingId,
        if (primarySchemeId != null) 'scheme_id': primarySchemeId,
        if (primaryVoucherId != null) 'voucher_id': primaryVoucherId,
      };

      final response = await ApiService.createInvoice(invoiceData, token);
      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceViewScreen(
              invoiceId: response['invoice_id'],
              invoiceNumber: response['invoice_number'],
              invoiceData: {
                ...invoiceData,
                'subtotal': subtotal.toStringAsFixed(2),
                'discount': totalDiscount.toStringAsFixed(2),
                'tax_amount': taxAmount.toStringAsFixed(2),
                'total': total.toStringAsFixed(2),
                'taxes': selectedTaxes,
                'company_logo': response['company_logo'] ?? '',
                'branch_logo': response['branch_logo'] ?? '',
                'branch': response['branch'] ?? '',
              },
              customer: widget.customer,
              vehicle: widget.vehicle,
            ),
          ),
        );
      } else {
        setState(() => _isSaving = false);
        _snack(response['message'] ?? 'Failed to save invoice', isError: true);
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

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Create Invoice'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _allServices.isEmpty
          ? Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _customerCard(),
                  const SizedBox(height: 16),
                  _serviceSelectionCard(),
                 
                  const SizedBox(height: 16),
                  // Per-row scheme + discount sections
                  for (final row in _rows) ...[
                    _serviceRowCard(row),
                    const SizedBox(height: 12),
                  ],
                  if (_availableTaxes.isNotEmpty) ...[
                    _taxSelectionSection(),
                    const SizedBox(height: 16),
                  ],
                  if (_availableExtras.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _extrasCard(),
                  ],
                  if (_rows.isNotEmpty) ...[
                    _billSummary(),
                    const SizedBox(height: 16),
                    _amountCollectedField(),
                    const SizedBox(height: 16),
                    _paymentModeField(),
                    const SizedBox(height: 24),
                    _saveBtn(),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Customer card ─────────────────────────────────────────────────────────
  Widget _customerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF000080).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF000080), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer['name'],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: const Color(0xFF1e293b),
                  ),
                ),
                if (widget.customer['branch'] != null && widget.customer['branch'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Text(
                      "${context.tr('Branch')}: ${widget.customer['branch']}",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  (widget.vehicle['vehicle_type'] != null && widget.vehicle['vehicle_type'].toString().isNotEmpty)
                      ? "${widget.vehicle['no']} · ${widget.vehicle['vehicle_type']} - ${widget.vehicle['type']}"
                      : "${widget.vehicle['no']} · ${widget.vehicle['type']}",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String category, String label) {
    final isSelected = _selectedCategoryFilter == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          context.tr(label),
          style: GoogleFonts.inter(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF000080),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategoryFilter = category;
            });
          }
        },
      ),
    );
  }

  // ── Service multi-select card ─────────────────────────────────────────────
  Widget _serviceSelectionCard() {
    // Filter services based on priced status
    final allPriced = _allServices.where((svc) => svc['has_price'] == true).toList();
    
    // Filter services based on category filter
    final pricedServices = allPriced.where((svc) {
      if (_selectedCategoryFilter == 'all') return true;
      return svc['service_type_slug'] == _selectedCategoryFilter;
    }).toList();

    return _card(
      title: 'Select Service',
      badge: _rows.isEmpty ? null : '${_rows.length} selected',
      badgeColor: const Color(0xFF000080),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Filter Chips
          if (_enabledCategories.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All'),
                  ..._enabledCategories.map((slug) {
                    String name = slug.toString();
                    if (slug == 'washing') name = 'Washing';
                    else if (slug == 'oil_change') name = 'Oil Change';
                    else if (slug == 'tyre_change') name = 'Tyre Change';
                    else if (slug == 'wheel_alignment') name = 'Alignment';
                    return _filterChip(slug.toString(), name);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          pricedServices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      context.tr('No services available'),
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: pricedServices.map((svc) {
                    final id = svc['id'] as String;
                    final name = svc['name'] as String;
                    final rate = (svc['rate'] as num).toDouble();
                    final isSelected = _isServiceSelected(id);
                    final hasPrice = svc['has_price'] == true;

                    return GestureDetector(
                      onTap: hasPrice ? () => _toggleService(svc) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF000080).withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF000080)
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF000080)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF000080)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr(name),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: hasPrice
                                          ? const Color(0xFF1e293b)
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (svc['service_type'] != null)
                                    Text(
                                      context.tr(svc['service_type'] as String),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!hasPrice)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text(
                                  context.tr('No price'),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '$currencySymbol${rate.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: const Color(0xFF000080),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }


  // ── Per-service row card (scheme + discount) ──────────────────────────────
  Widget _serviceRowCard(_ServiceRow row) {
    return _card(
      title: row.serviceName,
      titleIcon: Icons.local_car_wash_outlined,
      badge: '$currencySymbol${row.rate.toStringAsFixed(2)}',
      badgeColor: Colors.grey.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Schemes section
          if (row.isLoadingSchemes)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (row.availableSchemes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('No schemes available for this service'),
                    style: GoogleFonts.inter(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              context.tr('Available Schemes'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            ...row.availableSchemes.map((scheme) =>
                _schemeChip(row, scheme as Map<String, dynamic>)),
          ],

          // Manual discount (only when no scheme on this row)
          if (row.selectedScheme == null) ...[
            const SizedBox(height: 12),
            _manualDiscountRow(row),
          ],

          // Voucher input if selected scheme is Voucher type
          if (row.selectedScheme != null &&
              row.selectedScheme!['scheme_type'] == 'Voucher') ...[
            const SizedBox(height: 12),
            _voucherInput(row),
          ],

          // Category-specific details (oil/tyre/alignment details)
          _categoryDetailSection(row),

          // Row subtotal
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF000080).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Line Total'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF1e293b),
                  ),
                ),
                if (row.effectiveDiscount > 0)
                  Text(
                    context.tr('$currencySymbol${row.rate.toStringAsFixed(2)} − $currencySymbol${row.effectiveDiscount.toStringAsFixed(2)} = '),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                Text(
                  context.tr('$currencySymbol${row.lineTotal.toStringAsFixed(2)}'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: const Color(0xFF000080),
                  ),
                ),
              ],
            ),
          ),

          // Remove button
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _toggleService(row.service),
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 16),
              label: Text(
                context.tr('Remove Service'),
                style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryDetailSection(_ServiceRow row) {
    if (row.serviceCategory == 'oil_change') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.oil_barrel, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Oil Change Details'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                    ),
                  ],
                ),
                if (row.selectedOilProductId != null || row.oilLitresController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        row.selectedOilProductId = null;
                        row.oilPricePerLitre = null;
                        row.oilLitresController.clear();
                        row.oilFilterChanged = false;
                        row.odometerController.clear();
                        row.nextOilChangeKmController.clear();
                        _syncAmountCollected();
                      });
                    },
                    child: Text(
                      context.tr('Clear'),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                // Group unique products by brand/grade/name
                final uniqueGroupKeys = <String>{};
                for (var oil in _oilProducts) {
                  final brand = oil['brand']?.toString() ?? '';
                  final grade = oil['grade']?.toString() ?? '';
                  final name = oil['name']?.toString() ?? '';
                  final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
                  uniqueGroupKeys.add(key);
                }
                final sortedGroupKeys = uniqueGroupKeys.toList()..sort();

                List<dynamic> getVariantsForGroup(String? groupKey) {
                  if (groupKey == null) return [];
                  return _oilProducts.where((oil) {
                    final brand = oil['brand']?.toString() ?? '';
                    final grade = oil['grade']?.toString() ?? '';
                    final name = oil['name']?.toString() ?? '';
                    final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
                    return key == groupKey;
                  }).toList();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: row.selectedOilGroupKey,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Oil Product *'),
                        labelStyle: const TextStyle(fontSize: 14),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: sortedGroupKeys.map<DropdownMenuItem<String>>((key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(
                            key,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          row.selectedOilGroupKey = val;
                          row.selectedOilVolume = null;
                          row.selectedOilProductId = null;
                          row.selectedOilRunKm = null;
                          row.oilPricePerLitre = null;
                          row.oilLitresController.clear();

                          final variants = getVariantsForGroup(val);
                          if (variants.length == 1) {
                            final v = variants.first;
                            final vol = (v['recommended_qty_litres'] as num).toDouble();
                            row.selectedOilVolume = vol;
                            row.selectedOilProductId = v['id'];
                            row.selectedOilRunKm = v['oil_run_km'] as int?;
                            row.oilPricePerLitre = (v['price_per_litre'] as num).toDouble();
                            row.oilLitresController.text = vol.toString();
                            row._onOdometerChanged();
                            _fetchOilPriceForProduct(row, v['id']);
                          }
                          _syncAmountCollected();
                        });
                      },
                    ),
                    if (row.selectedOilGroupKey != null) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final variants = getVariantsForGroup(row.selectedOilGroupKey);
                          final currentVolume = row.selectedOilVolume;
                          final hasMatch = currentVolume != null &&
                              variants.any((v) => (v['recommended_qty_litres'] as num).toDouble() == currentVolume);

                          return DropdownButtonFormField<double>(
                            isExpanded: true,
                            value: hasMatch ? currentVolume : null,
                            decoration: InputDecoration(
                              labelText: context.tr('Select Litres (Volume) *'),
                              labelStyle: const TextStyle(fontSize: 12),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: variants.map<DropdownMenuItem<double>>((v) {
                              final vol = (v['recommended_qty_litres'] as num).toDouble();
                              return DropdownMenuItem<double>(
                                value: vol,
                                child: Text(
                                  '$vol L',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                final v = variants.firstWhere(
                                    (item) => (item['recommended_qty_litres'] as num).toDouble() == val,
                                    orElse: () => {});
                                if (v.isNotEmpty) {
                                  row.selectedOilVolume = val;
                                  row.selectedOilProductId = v['id'];
                                  row.selectedOilRunKm = v['oil_run_km'] as int?;
                                  row.oilPricePerLitre = (v['price_per_litre'] as num).toDouble();
                                  row.oilLitresController.text = val.toString();
                                  row._onOdometerChanged();
                                  _fetchOilPriceForProduct(row, v['id']);
                                }
                                _syncAmountCollected();
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
            if (row.isLoadingOilPrice)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(),
              ),
            if (row.selectedOilProductId != null) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final p = _oilProducts.firstWhere((item) => item['id'] == row.selectedOilProductId, orElse: () => {});
                  final brand = p['brand']?.toString() ?? '';
                  final grade = p['grade']?.toString() ?? '';
                  final name = p['name']?.toString() ?? '';
                  final stockVal = p['stock_qty'] != null ? (p['stock_qty'] as num).toInt() : 0;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (brand.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade400),
                                ),
                                child: Text(
                                  'Brand: $brand',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                            if (grade.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Text(
                                  'Grade: $grade',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ),
                            if (name.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'Name: $name',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Text(
                                'Stock: $stockVal units',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${context.tr("Rate")}: ${CountryConfig.currencySymbol}${(row.oilPricePerLitre ?? 0.0).toStringAsFixed(2)} / L',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                            ),
                            if (row.oilLitres > 0)
                              Text(
                                '${context.tr("Oil Charge")}: ${CountryConfig.currencySymbol}${row.oilTotalCharge.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
            // Row(
            //   children: [
            //     Expanded(
            //       child: Row(
            //         children: [
            //           Checkbox(
            //             value: row.oilFilterChanged,
            //             onChanged: (val) => setState(() => row.oilFilterChanged = val ?? false),
            //           ),
            //           Text(context.tr('Filter Changed'), style: const TextStyle(fontSize: 12)),
            //         ],
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Odometer (KM)'),
                      labelStyle: const TextStyle(fontSize: 14),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: row.nextOilChangeKmController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Next Change (KM)'),
                      labelStyle: const TextStyle(fontSize: 14),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (row.serviceCategory == 'tyre_change') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle_outlined, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('Tyre Change Details'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: row.selectedTyreBrandId,
              decoration: InputDecoration(
                labelText: context.tr('Select Tyre Brand *'),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _tyreBrands.map<DropdownMenuItem<String>>((tyre) {
                return DropdownMenuItem<String>(
                  value: tyre['id'] as String,
                  child: Text(tyre['brand'] as String, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) => setState(() => row.selectedTyreBrandId = val),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.tyreSizeController,
                    decoration: InputDecoration(
                      labelText: context.tr('Size (e.g. 195/65 R15)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: DropdownButtonFormField<int>(
                    value: row.tyresChangedCount,
                    decoration: InputDecoration(
                      labelText: context.tr('Qty'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: [1, 2, 3, 4, 5].map<DropdownMenuItem<int>>((int val) {
                      return DropdownMenuItem<int>(
                        value: val,
                        child: Text(val.toString()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => row.tyresChangedCount = val ?? 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Odometer (KM)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: row.nextTyreChangeKmController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Next Change (KM)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (row.serviceCategory == 'wheel_alignment') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('Alignment & Balancing Details'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: row.alignmentDone,
                        onChanged: (val) => setState(() => row.alignmentDone = val ?? true),
                      ),
                      Text(context.tr('Alignment Done'), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: row.balancingDone,
                        onChanged: (val) => setState(() => row.balancingDone = val ?? true),
                      ),
                      Text(context.tr('Balancing Done'), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: row.odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Odometer (KM)'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: row.alignmentNotesController,
              decoration: InputDecoration(
                labelText: context.tr('Notes / Remarks'),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }


  // ── Scheme chip (compact selection) ──────────────────────────────────────
  Widget _schemeChip(_ServiceRow row, Map<String, dynamic> scheme) {
    final isSelected = row.selectedScheme?['id'] == scheme['id'];
    final schemeType = scheme['scheme_type'] as String;
    final isEligible = scheme['is_eligible'] as bool? ?? true;
    final visitsCount = scheme['visits_count'] as int? ?? 0;
    final paidVisits = scheme['paid_visits'] as int? ?? 1;

    // Disable quantity scheme only if another row already uses it
    // (A qty scheme can always be selected to track progress; discount only applies when eligible)
    final lockedByOtherRow = schemeType == 'Quantity' &&
        !isSelected &&
        _quantitySchemeUsedId == scheme['id'];

    // Qty schemes are always selectable for progress tracking
    // Other scheme types (Discount/Voucher) only selectable when eligible
    final canSelect = schemeType == 'Quantity'
        ? !lockedByOtherRow
        : isEligible && !lockedByOtherRow;

    IconData icon;
    Color iconColor;
    if (schemeType == 'Quantity') {
      icon = Icons.card_giftcard;
      iconColor = Colors.green;
    } else if (schemeType == 'Discount') {
      icon = Icons.local_offer_outlined;
      iconColor = Colors.orange;
    } else {
      icon = Icons.confirmation_number_outlined;
      iconColor = Colors.purple;
    }

    return GestureDetector(
      onTap: canSelect
          ? () => isSelected
                ? _selectScheme(row, null)
                : _selectScheme(row, scheme)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: !canSelect
              ? Colors.grey.shade50
              : isSelected
                  ? const Color(0xFF000080).withValues(alpha: 0.05)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !canSelect
                ? Colors.grey.shade200
                : isSelected
                    ? const Color(0xFF000080)
                    : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: canSelect
                        ? iconColor.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    icon,
                    color: canSelect ? iconColor : Colors.grey,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(scheme['name'] as String),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: canSelect
                              ? const Color(0xFF1e293b)
                              : Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        context.tr(scheme['description'] as String? ?? ''),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (lockedByOtherRow)
                        Text(
                          context.tr('Already applied to another service'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (schemeType == 'Quantity')
                  _statusBadge(
                    isEligible
                        ? (lockedByOtherRow ? 'Used' : 'FREE! 🎉')
                        : '$visitsCount / $paidVisits',
                    isEligible && !lockedByOtherRow ? Colors.green : Colors.blue,
                  ),
                const SizedBox(width: 8),
                Radio<String>(
                  value: scheme['id'] as String,
                  groupValue: row.selectedScheme?['id'] as String?,
                  activeColor: const Color(0xFF000080),
                  onChanged: canSelect
                      ? (v) => isSelected
                            ? _selectScheme(row, null)
                            : _selectScheme(row, scheme)
                      : null,
                ),
              ],
            ),
            // Progress bar for Quantity
            if (schemeType == 'Quantity') ...[
              const SizedBox(height: 8),
              _progressBar(current: visitsCount, target: paidVisits),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _progressBar({required int current, required int target}) {
    final progress = (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('Progress: $current / $target washes'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.green : Colors.blue,
            ),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ── Manual discount per row ───────────────────────────────────────────────
  Widget _manualDiscountRow(_ServiceRow row) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.tr('Manual Discount'),
          style:
              GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: row.discountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            decoration: InputDecoration(
              prefixText: '$currencySymbol ',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (_) => setState(() => _syncAmountCollected()),
          ),
        ),
      ],
    );
  }

  // ── Voucher input per row ─────────────────────────────────────────────────
  Widget _voucherInput(_ServiceRow row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Enter Voucher Number'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: const Color(0xFF000080),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.voucherController,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: context.tr('Enter voucher number'),
                  hintStyle:
                      GoogleFonts.inter(color: Colors.grey.shade400),
                  suffixIcon:
                      const Icon(Icons.qr_code_scanner, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: row.voucherValidating
                  ? null
                  : () => _validateVoucher(row),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: row.voucherValidating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(context.tr('Apply'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (row.voucherError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(row.voucherError!,
                style: GoogleFonts.inter(color: Colors.red, fontSize: 12)),
          ),
        if (row.voucherSuccess != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  row.voucherSuccess!,
                  style: GoogleFonts.inter(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Tax section ───────────────────────────────────────────────────────────
  Widget _taxSelectionSection() {
    return _card(
      title: 'Tax',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _applyGst,
                activeColor: const Color(0xFF000080),
                onChanged: (val) {
                  setState(() {
                    _applyGst = val ?? false;
                    _syncAmountCollected();
                  });
                },
              ),
              Expanded(
                child: Text(
                  context.tr('TAX'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1e293b),
                  ),
                ),
              ),
            ],
          ),
          if (_applyGst) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            ..._availableTaxes.map((tax) {
              final id = tax['id'] as String;
              final name = tax['name'] as String;
              final percent = (tax['percent'] as num).toDouble();
              final isSelected = _selectedTaxIds.contains(id);
              return Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF000080),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTaxIds.add(id);
                        } else {
                          _selectedTaxIds.remove(id);
                        }
                        _syncAmountCollected();
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      context.tr('$name (${percent.toStringAsFixed(1)}%)'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1e293b),
                      ),
                    ),
                  ),
                  Text(
                    _rows.isEmpty
                        ? '$currencySymbol 0.00'
                        : '$currencySymbol${(subtotal * percent / 100).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Bill summary ──────────────────────────────────────────────────────────
  Widget _billSummary() {
    final selectedTaxRows = _applyGst
        ? _availableTaxes
            .where((t) => _selectedTaxIds.contains(t['id'] as String))
            .map((t) {
              final name = t['name'] as String;
              final pct = (t['percent'] as num).toDouble();
              return MapEntry(name, subtotal * pct / 100);
            })
            .toList()
        : <MapEntry<String, double>>[];

    return _card(
      title: 'Bill Summary',
      child: Column(
        children: [
          // Per-service lines
          for (final row in _rows) ...[
            _summaryRow(context.tr(row.serviceName), '$currencySymbol${row.rate.toStringAsFixed(2)}'),
            if (row.serviceCategory == 'oil_change' && row.oilTotalCharge > 0) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final p = _oilProducts.firstWhere((item) => item['id'] == row.selectedOilProductId, orElse: () => {});
                  final brand = p['brand']?.toString() ?? '';
                  final grade = p['grade']?.toString() ?? '';
                  final oilLabel = brand.isNotEmpty
                      ? '  + Oil ($brand $grade ${row.oilLitres}L)'
                      : '  + Oil (${row.oilLitres}L)';
                  return _summaryRow(
                    oilLabel,
                    '+$currencySymbol${row.oilTotalCharge.toStringAsFixed(2)}',
                    valueColor: Colors.amber.shade900,
                  );
                },
              ),
            ],
            if (row.effectiveDiscount > 0) ...[
              const SizedBox(height: 4),
              _summaryRow(
                row.selectedScheme != null
                    ? '  ${context.tr('Scheme Discount')} (${context.tr(row.serviceName)})'
                    : '  ${context.tr('Manual Discount')} (${context.tr(row.serviceName)})',
                '-$currencySymbol${row.effectiveDiscount.toStringAsFixed(2)}',
                valueColor: Colors.green,
              ),
            ],
            const SizedBox(height: 6),
          ],
          // Per-extra lines
          for (final e in _selectedExtras) ...[
            _summaryRow(
              e['extra']['name'] as String,
              '$currencySymbol${(double.tryParse((e['priceController'] as TextEditingController).text) ?? 0.0).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 6),
          ],
          if (_rows.length > 1)
            _summaryRow(
              context.tr('Services Subtotal'),
              '$currencySymbol${subtotal.toStringAsFixed(2)}',
              isBold: true,
            ),
          // Taxes
          for (final entry in selectedTaxRows) ...[
            const SizedBox(height: 6),
            _summaryRow(
                entry.key, '$currencySymbol${entry.value.toStringAsFixed(2)}'),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Total Amount'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF1e293b),
                ),
              ),
              Text(
                context.tr('$currencySymbol${total.toStringAsFixed(2)}'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: const Color(0xFF000080),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Amount collected ──────────────────────────────────────────────────────
  Widget _amountCollectedField() {
    return _card(
      title: 'Amount Collected',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr('Collected'),
            style: GoogleFonts.inter(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _amountCollectedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.green.shade700,
              ),
              decoration: InputDecoration(
                prefixText: '$currencySymbol ',
                prefixStyle: GoogleFonts.inter(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Mode selector ──────────────────────────────────────────────────
  Widget _paymentModeField() {
    return _card(
      title: 'Payment Mode',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _paymentModeOption('digital_payments', 'Digital payments', Icons.qr_code_scanner),
              _paymentModeOption('cash', 'Cash', Icons.money),
              _paymentModeOption('card', 'Card', Icons.credit_card),
             
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentModeOption(String mode, String label, IconData icon) {
    final isSelected = _selectedPaymentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPaymentMode = mode;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF000080).withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF000080)
                  : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF000080) : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(label),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF000080) : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _saveBtn() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _saveInvoice,
      icon: _isSaving
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.check_circle_outline),
      label: Text(
        context.tr('Save Invoice'),
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _extrasCard() {
    return _card(
      title: 'Add Extras',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedExtras.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr('No extras added yet'),
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._selectedExtras.map((extraMap) {
              final extra = extraMap['extra'] as Map<String, dynamic>;
              final name = extra['name'] as String;
              final controller = extraMap['priceController'] as TextEditingController;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF1e293b),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                        decoration: InputDecoration(
                          prefixText: '$currencySymbol ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => setState(() => _syncAmountCollected()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          controller.dispose();
                          _selectedExtras.remove(extraMap);
                          _syncAmountCollected();
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddExtraSelector,
            icon: const Icon(Icons.add, size: 16),
            label: Text(context.tr('Add Extra Item')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF000080),
              elevation: 0,
              side: const BorderSide(color: Color(0xFF000080)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExtraSelector() {
    final remainingExtras = _availableExtras.where((ext) {
      return !_selectedExtras.any((se) => se['extra']['id'] == ext['id']);
    }).toList();

    if (remainingExtras.isEmpty) {
      _snack(context.tr('All available extras already added'), isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.tr('Select Extra'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF000080)),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: remainingExtras.length,
                  itemBuilder: (context, index) {
                    final ext = remainingExtras[index];
                    return ListTile(
                      leading: const Icon(Icons.add, color: Color(0xFF000080)),
                      title: Text(ext['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          final controller = TextEditingController(text: '0');
                          controller.addListener(() => setState(() {
                                _syncAmountCollected();
                              }));
                          _selectedExtras.add({
                            'extra': ext,
                            'priceController': controller,
                          });
                          _syncAmountCollected();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    required Widget child,
    String? badge,
    Color? badgeColor,
    IconData? titleIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Icon(titleIcon, color: const Color(0xFF000080), size: 16),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  context.tr(title),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF000080),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? const Color(0xFF000080),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: isBold ? const Color(0xFF1e293b) : Colors.grey.shade600,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
            color: valueColor ?? const Color(0xFF1e293b),
          ),
        ),
      ],
    );
  }
}
