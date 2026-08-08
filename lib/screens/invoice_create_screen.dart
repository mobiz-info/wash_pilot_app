import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';
import 'invoice_view_screen.dart';

// ── Oil itemized row for oil / fluid replacement ─────────────────────────────
class _OilItemRow {
  String? selectedOilCategory;
  String? selectedOilProductId;
  String? selectedOilGroupKey;
  double? selectedOilVolume;
  int? selectedOilRunKm;
  double? oilPricePerLitre;
  bool isLoadingOilPrice = false;
  final TextEditingController oilLitresController = TextEditingController();

  double get oilLitres => double.tryParse(oilLitresController.text) ?? 0.0;
  double get lineTotal => (oilPricePerLitre ?? 0.0) * oilLitres;

  void dispose() {
    oilLitresController.dispose();
  }
}

// ── Tyre itemized row for tyre replacement ───────────────────────────────────
class _TyreItemRow {
  String? selectedBrandId;
  String? selectedTyreId;
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '4');
  final TextEditingController odometerController = TextEditingController();
  final TextEditingController nextChangeKmController = TextEditingController();
  double unitPrice = 0.0;
  int runningKm = 40000;

  _TyreItemRow({
    this.selectedBrandId,
    this.selectedTyreId,
    double initialPrice = 0.0,
    int initialQty = 4,
    int initialKm = 40000,
  }) {
    qtyController.text = initialQty.toString();
    unitPrice = initialPrice;
    runningKm = initialKm;
    odometerController.addListener(_onOdometerChanged);
  }

  void _onOdometerChanged() {
    final odo = int.tryParse(odometerController.text) ?? 0;
    if (odo > 0) {
      nextChangeKmController.text = (odo + runningKm).toString();
    }
  }

  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get lineTotal => unitPrice * quantity;

  void dispose() {
    sizeController.dispose();
    qtyController.dispose();
    odometerController.removeListener(_onOdometerChanged);
    odometerController.dispose();
    nextChangeKmController.dispose();
  }
}

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

  // Oil Change (Itemized List - defaults to 1 item)
  final List<_OilItemRow> oilItems = [
    _OilItemRow(),
  ];
  bool oilFilterChanged = false;
  String? selectedOilFilterId;
  double oilFilterPrice = 0.0;
  int? selectedOilFilterRunKm;
  final TextEditingController odometerController = TextEditingController();
  final TextEditingController nextOilChangeKmController = TextEditingController();

  double get oilTotalCharge {
    if (serviceCategory != 'oil_change') return 0.0;
    final itemsCharge = oilItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    return itemsCharge + oilFilterPrice;
  }

  // Tyre Change (Itemized List - defaults to 1 item)
  final List<_TyreItemRow> tyreItems = [
    _TyreItemRow(initialQty: 4),
  ];
  final TextEditingController nextTyreChangeKmController = TextEditingController();

  double get tyreTotalCharge {
    if (serviceCategory != 'tyre_change') return 0.0;
    return tyreItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

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
        final firstOilRunKm = oilItems.isNotEmpty ? oilItems.first.selectedOilRunKm : null;
        final runKm = selectedOilFilterRunKm ?? firstOilRunKm ?? 5000;
        nextOilChangeKmController.text = (odo + runKm).toString();
      }
      if (serviceCategory == 'tyre_change' && nextTyreChangeKmController.text.isEmpty) {
        // Default to +40000 km
        nextTyreChangeKmController.text = (odo + 40000).toString();
      }
    }
  }

  double get rate => (service['rate'] as num).toDouble();

  double get subtotal {
    double base = rate;
    if (serviceCategory == 'oil_change') {
      base += oilTotalCharge;
    } else if (serviceCategory == 'tyre_change') {
      base += tyreTotalCharge;
    }
    return base;
  }

  double get effectiveDiscount {
    if (selectedScheme != null) return schemeDiscount;
    return double.tryParse(discountController.text) ?? 0.0;
  }

  double get total => (subtotal - effectiveDiscount).clamp(0.0, double.infinity);
  double get lineTotal => total;

  String get serviceId => service['id'] as String;
  String get serviceName => service['name'] as String;

  void dispose() {
    voucherController.dispose();
    discountController.dispose();
    for (final item in oilItems) {
      item.dispose();
    }
    odometerController.removeListener(_onOdometerChanged);
    odometerController.dispose();
    nextOilChangeKmController.dispose();
    for (final item in tyreItems) {
      item.dispose();
    }
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

  // Oil Products, Oil Filters, Tyre Brands, Tyres, and Enabled Categories
  List<dynamic> _oilProducts = [];
  List<dynamic> _oilFilters = [];
  List<dynamic> _tyreBrands = [];
  List<dynamic> _tyres = [];
  List<dynamic> _enabledCategories = [];
  String _selectedCategoryFilter = 'all';

  static const List<String> _oilCategories = [
    'Engine Oil',
    'Brake Fluid',
    'Power Steering Oil',
    'Transmission Fluid',
    'Differential Oil',
    'Coolant',
    'Gear Oil',
    'Transfer Case Fluid',
  ];



  // Amount collected
  final _amountCollectedController = TextEditingController(text: '0');

  // Additional Invoice-level discount (Percentage/Amount)
  bool _usePercentageDiscount = false; // false = Amount, true = Percentage
  final TextEditingController _additionalDiscountController = TextEditingController(text: '0');

  // Payment mode selection state
  String _selectedPaymentMode = 'digital_payments';

  // Sales type (Cash = show payment mode, Credit = hide payment mode)
  String _selectedSalesType = 'cash';

  double get totalServicesAmount =>
      _rows.fold(0.0, (s, r) => s + r.subtotal);
  double get totalExtrasAmount => _selectedExtras.fold(
      0.0,
      (s, e) =>
          s +
          (double.tryParse(
                  (e['priceController'] as TextEditingController).text) ??
              0.0));

  double get additionalDiscountAmount {
    final val = double.tryParse(_additionalDiscountController.text) ?? 0.0;
    if (_usePercentageDiscount) {
      return subtotal * (val / 100);
    } else {
      return val;
    }
  }

  double get totalDiscount {
    final itemDiscount = _rows.fold(0.0, (s, r) => s + r.effectiveDiscount);
    return itemDiscount + additionalDiscountAmount;
  }

  // Subtotal = gross amount before discount
  double get subtotal =>
      (totalServicesAmount + totalExtrasAmount).clamp(0.0, double.infinity);

  // Taxable Value = Subtotal after discount
  double get taxableValue => (subtotal - totalDiscount).clamp(0.0, double.infinity);

  // Tax Amount = calculated on Taxable Value (post-discount)
  double get taxAmount {
    if (!_applyGst) return 0.0;
    double t = 0.0;
    for (final tax in _availableTaxes) {
      if (_selectedTaxIds.contains(tax['id'] as String)) {
        final pct = (tax['percent'] as num).toDouble();
        t += taxableValue * (pct / 100.0);
      }
    }
    return t;
  }

  // Total = Taxable Value + Tax Amount
  double get total => (taxableValue + taxAmount).clamp(0.0, double.infinity);

  List<Map<String, dynamic>> get selectedTaxes {
    if (!_applyGst) return [];
    return _availableTaxes
        .where((t) => _selectedTaxIds.contains(t['id'] as String))
        .map((t) {
          final pct = (t['percent'] as num).toDouble();
          final itemTaxAmount = taxableValue * (pct / 100.0);
          return {
            'id': t['id'],
            'name': t['name'],
            'percent': pct,
            'amount': itemTaxAmount.toStringAsFixed(2),
          };
        })
        .toList();
  }

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

  final _uiState = ValueNotifier<int>(0);
  void _updateUi() {
    _uiState.value++;
  }

  @override
  void initState() {
    super.initState();
    _additionalDiscountController.addListener(() {
      _syncAmountCollected();
      _updateUi();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _uiState.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    for (final extra in _selectedExtras) {
      (extra['priceController'] as TextEditingController).dispose();
    }
    _amountCollectedController.dispose();
    _additionalDiscountController.dispose();
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
      Map<String, dynamic>? filterRes;
      Map<String, dynamic>? tyreBrandRes;
      Map<String, dynamic>? tyresListRes;
      try {
        oilRes = await ApiService.getOilProducts(token);
        filterRes = await ApiService.getOilFilters(token);
        tyreBrandRes = await ApiService.getTyreBrands(token);
        tyresListRes = await ApiService.getTyres(token);
      } catch (_) {}

      if (svcRes['success'] == true) {
        _allServices = svcRes['services'] ?? [];
        final rawEnabled = (svcRes['enabled_categories'] as List<dynamic>? ?? []);
        // Only keep categories that have at least one priced service available for this vehicle
        _enabledCategories = rawEnabled.where((slug) {
          return _allServices.any((s) => s['service_type_slug'] == slug && s['has_price'] == true);
        }).toList();
        if (_enabledCategories.isNotEmpty) {
          _selectedCategoryFilter = _enabledCategories.first.toString();
        }
        final rawTaxes = svcRes['taxes'] as List<dynamic>? ?? [];
        _availableTaxes =
            rawTaxes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
        _selectedTaxIds =
            _availableTaxes.map((t) => t['id'] as String).toSet();
        // Auto-enable tax if branch has taxes configured
        if (_availableTaxes.isNotEmpty) {
          _applyGst = true;
        }
      }
      if (extRes['success'] == true) {
        _availableExtras = extRes['extras'] ?? [];
      }
      if (oilRes != null && oilRes['success'] == true) {
        _oilProducts = oilRes['oil_products'] ?? [];
      }
      if (filterRes != null && filterRes['success'] == true) {
        _oilFilters = filterRes['oil_filters'] ?? [];
      }
      if (tyreBrandRes != null && tyreBrandRes['success'] == true) {
        _tyreBrands = tyreBrandRes['tyre_brands'] ?? [];
      }
      if (tyresListRes != null && tyresListRes['success'] == true) {
        _tyres = tyresListRes['tyres'] ?? [];
      }
      _isLoading = false;
      _syncAmountCollected();
      _updateUi();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _updateUi();
    }
  }


  void _syncAmountCollected() {
    _amountCollectedController.text = total.round().toString();
  }

  // ── Add / Remove service rows ─────────────────────────────────────────────
  void _toggleService(Map<String, dynamic> svc) {
    final idx = _rows.indexWhere((r) => r.serviceId == svc['id']);
    if (idx >= 0) {
      _rows[idx].dispose();
      _rows.removeAt(idx);
    } else {
      final row = _ServiceRow(service: svc);
      row.discountController.addListener(() {
        _syncAmountCollected();
        _updateUi();
      });
      _rows.insert(0, row);
      _loadSchemesForRow(row);
    }
    _syncAmountCollected();
    _updateUi();
  }

  bool _isServiceSelected(String serviceId) =>
      _rows.any((r) => r.serviceId == serviceId);

  Future<void> _loadSchemesForRow(_ServiceRow row) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    row.isLoadingSchemes = true;
    _updateUi();

    try {
      final res = await ApiService.getAvailableSchemes(
        widget.customer['id'],
        widget.vehicle['id'],
        row.serviceId,
        token,
      );
      if (!mounted) return;
      row.availableSchemes =
          res['success'] == true ? res['schemes'] ?? [] : [];
      row.isLoadingSchemes = false;
      _updateUi();
    } catch (_) {
      if (!mounted) return;
      row.availableSchemes = [];
      row.isLoadingSchemes = false;
      _updateUi();
    }
  }

  Future<void> _fetchOilPriceForProduct(_OilItemRow item, String oilProductId) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    item.isLoadingOilPrice = true;
    _updateUi();

    try {
      final res = await ApiService.getOilPrice(
        token,
        oilProductId,
        vehicleMakeId: widget.vehicle['make_id']?.toString(),
        vehicleTypeId: widget.vehicle['vehicle_type_id']?.toString(),
      );
      if (!mounted) return;
      item.isLoadingOilPrice = false;
      if (res['success'] == true) {
        if (res['price_per_litre'] != null && (res['price_per_litre'] as num) > 0) {
          item.oilPricePerLitre = (res['price_per_litre'] as num).toDouble();
        }
      }
      _syncAmountCollected();
      _updateUi();
    } catch (_) {
      if (!mounted) return;
      item.isLoadingOilPrice = false;
      _updateUi();
    }
  }

  // ── Scheme selection per row ─────────────────────────────────────────────
  void _selectScheme(_ServiceRow row, Map<String, dynamic>? scheme) {
    row.selectedScheme = scheme;
    row.schemeDiscount = 0.0;
    row.voucherController.clear();
    row.voucherError = null;
    row.voucherSuccess = null;
    row.validatedVoucherId = null;

    if (scheme == null) {
      _syncAmountCollected();
      _updateUi();
      return;
    }

    final st = scheme['scheme_type'] as String;
    if (st == 'Discount') {
      final pct = (scheme['discount_percentage'] as num?)?.toDouble() ?? 0.0;
      row.schemeDiscount = row.rate * pct / 100;
    } else if (st == 'Quantity') {
      // Only apply full discount when the customer is eligible (reached paid_visits)
      // If not yet eligible, discount = 0 but scheme is still recorded for progress tracking
      if (scheme['is_eligible'] == true) {
        row.schemeDiscount = row.rate;
      }
      // else: schemeDiscount stays 0.0 — visit counts toward progress but no free wash yet
    }
    _syncAmountCollected();
    _updateUi();
  }

  Future<void> _validateVoucher(_ServiceRow row) async {
    if (row.selectedScheme == null) return;
    final voucher = row.voucherController.text.trim();
    if (voucher.isEmpty) {
      row.voucherError = 'Please enter a voucher number';
      _updateUi();
      return;
    }

    final token = context.read<AuthProvider>().token!;
    row.voucherValidating = true;
    row.voucherError = null;
    row.voucherSuccess = null;
    _updateUi();

    try {
      final res =
          await ApiService.validateVoucher(row.selectedScheme!['id'], voucher, token);
      if (res['success'] == true) {
        row.schemeDiscount = (res['discount'] as num).toDouble();
        row.voucherSuccess = res['message'] ?? 'Voucher applied!';
        row.validatedVoucherId = res['voucher_id'];
        row.voucherValidating = false;
        _syncAmountCollected();
        _updateUi();
      } else {
        row.voucherError = res['message'] ?? 'Invalid voucher';
        row.voucherValidating = false;
        _updateUi();
      }
    } catch (e) {
      row.voucherError = e.toString();
      row.voucherValidating = false;
      _updateUi();
    }
  }

  // ── Save Invoice ─────────────────────────────────────────────────────────
  Future<void> _saveInvoice() async {
    if (_rows.isEmpty && _selectedExtras.isEmpty) {
      _snack(context.tr('Please select at least one service or extra item'), isError: true);
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
    _isSaving = true;
    _updateUi();

    try {
      // Use the primary scheme from the first row that has one
      final primaryRow = _rows.isEmpty
          ? null
          : _rows.firstWhere((r) => r.selectedScheme != null, orElse: () => _rows.first);
      final primarySchemeId = primaryRow?.selectedScheme?['id'];
      final primaryVoucherId = primaryRow?.validatedVoucherId;

      final services = [
        ..._rows.map((r) {
          Map<String, dynamic>? detail;
          if (r.serviceCategory == 'oil_change') {
            final mappedOilItems = r.oilItems.map((item) {
              final p = _oilProducts.firstWhere((o) => o['id'] == item.selectedOilProductId, orElse: () => <String, dynamic>{});
              return {
                'category': item.selectedOilCategory ?? 'Engine Oil',
                'oil_product_id': item.selectedOilProductId,
                'oil_product': p,
                'oil_litres_used': item.oilLitres,
                'price_per_litre': item.oilPricePerLitre ?? 0.0,
                'line_total': item.lineTotal,
                'oil_run_km': item.selectedOilRunKm,
              };
            }).toList();

            final firstItem = r.oilItems.first;
            final firstP = _oilProducts.firstWhere((item) => item['id'] == firstItem.selectedOilProductId, orElse: () => <String, dynamic>{});

            detail = {
              'service_category': 'oil_change',
              'oil_items': mappedOilItems,
              'oil_product_id': firstItem.selectedOilProductId,
              'oil_product': firstP,
              'oil_litres_used': firstItem.oilLitres,
              'total_oil_charge': r.oilTotalCharge,
              'oil_filter_changed': r.oilFilterChanged,
              'oil_filter_id': r.selectedOilFilterId,
              'oil_filter_price': r.oilFilterPrice,
              'odometer_at_service': int.tryParse(r.odometerController.text),
              'next_oil_change_km': int.tryParse(r.nextOilChangeKmController.text),
            };
          } else if (r.serviceCategory == 'tyre_change') {
            final mappedItems = r.tyreItems.map((item) {
              final tyreObj = _tyres.firstWhere(
                (t) => t['id'] == item.selectedTyreId,
                orElse: () => {},
              );
              final brandObj = _tyreBrands.firstWhere(
                (b) => b['id'] == item.selectedBrandId,
                orElse: () => {},
              );
              return {
                'tyre_brand_id': item.selectedBrandId,
                'tyre_id': item.selectedTyreId,
                'brand': tyreObj['tyre_brand_name'] ?? brandObj['brand'] ?? '',
                'name': tyreObj['name'] ?? '',
                'size': item.sizeController.text.trim().isNotEmpty
                    ? item.sizeController.text.trim()
                    : (tyreObj['size'] ?? ''),
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
                'line_total': item.lineTotal,
                'odometer_at_service': int.tryParse(item.odometerController.text),
                'next_tyre_change_km': int.tryParse(item.nextChangeKmController.text),
              };
            }).toList();

            final firstOdo = r.tyreItems.map((i) => int.tryParse(i.odometerController.text)).firstWhere((val) => val != null && val > 0, orElse: () => null);
            final firstNext = r.tyreItems.map((i) => int.tryParse(i.nextChangeKmController.text)).firstWhere((val) => val != null && val > 0, orElse: () => null);

            detail = {
              'service_category': 'tyre_change',
              'tyre_items': mappedItems,
              'total_tyres_count': r.tyreItems.fold<int>(0, (sum, item) => sum + item.quantity),
              'total_tyre_charge': r.tyreTotalCharge,
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
            'rate': r.subtotal,
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
        'payment_mode': _selectedSalesType == 'cash' ? _selectedPaymentMode : null,
        'sales_type': _selectedSalesType,
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
        _isSaving = false;
        _updateUi();
        _snack(response['message'] ?? 'Failed to save invoice', isError: true);
      }
    } catch (e) {
      _isSaving = false;
      _updateUi();
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
    return ValueListenableBuilder<int>(
      valueListenable: _uiState,
      builder: (context, _, __) {
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
                      if (_rows.isNotEmpty || _selectedExtras.isNotEmpty) ...[
                        _additionalDiscountCard(),
                        const SizedBox(height: 16),
                        _billSummary(),
                        const SizedBox(height: 16),
                        _amountCollectedField(),
                        const SizedBox(height: 16),
                        _salesTypeField(),
                        const SizedBox(height: 16),
                        if (_selectedSalesType == 'cash') ...[
                          _paymentModeField(),
                          const SizedBox(height: 24),
                        ],
                        _saveBtn(),
                        const SizedBox(height: 24),
                      ],

                    ],
                  ),
                ),
        );
      },
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
            _selectedCategoryFilter = category;
            _updateUi();
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
                children: _enabledCategories.map((slug) {
                  final matchingService = _allServices.firstWhere(
                    (s) => s['service_type_slug'] == slug,
                    orElse: () => null,
                  );
                  String name;
                  if (matchingService != null && matchingService['service_type'] != null) {
                    name = matchingService['service_type'].toString();
                  } else {
                    if (slug == 'washing') name = 'Washing';
                    else if (slug == 'oil_change') name = 'Oil Change';
                    else if (slug == 'tyre_change') name = 'Tyre Change';
                    else if (slug == 'wheel_alignment') name = 'Alignment';
                    else {
                      name = slug.toString()
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map((word) => word.isNotEmpty
                              ? '${word[0].toUpperCase()}${word.substring(1)}'
                              : '')
                          .join(' ');
                    }
                  }
                  return _filterChip(slug.toString(), name);
                }).toList(),
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

          // Category-specific details (oil/tyre/alignment details)
          _categoryDetailSection(row),

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

          // Row subtotal, discount & total breakdown
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF000080).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF000080).withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Subtotal'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '$currencySymbol${row.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: const Color(0xFF1e293b),
                      ),
                    ),
                  ],
                ),
                if (row.effectiveDiscount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Discount'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        '− $currencySymbol${row.effectiveDiscount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Total'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF1e293b),
                      ),
                    ),
                    Text(
                      '$currencySymbol${row.total.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: const Color(0xFF000080),
                      ),
                    ),
                  ],
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
                if (row.oilItems.any((i) => i.selectedOilProductId != null || i.oilLitres > 0) || row.selectedOilFilterId != null)
                  GestureDetector(
                    onTap: () {
                      row.oilItems.clear();
                      row.oilItems.add(_OilItemRow());
                      row.selectedOilFilterId = null;
                      row.oilFilterPrice = 0.0;
                      row.selectedOilFilterRunKm = null;
                      row.oilFilterChanged = false;
                      row.odometerController.clear();
                      row.nextOilChangeKmController.clear();
                      _syncAmountCollected();
                      _updateUi();
                    },
                    child: Text(
                      context.tr('Clear'),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Itemized Oil Rows (1 by default)
            for (int i = 0; i < row.oilItems.length; i++) ...[
              Builder(
                builder: (context) {
                  final item = row.oilItems[i];
                  final categoryOils = _oilProducts.where((oil) {
                    final cat = oil['category']?.toString() ?? 'Engine Oil';
                    if (item.selectedOilCategory != null && item.selectedOilCategory!.isNotEmpty) {
                      return cat == item.selectedOilCategory;
                    }
                    return true;
                  }).toList();

                  final uniqueGroupKeys = <String>{};
                  for (var oil in categoryOils) {
                    final brand = oil['brand']?.toString() ?? '';
                    final grade = oil['grade']?.toString() ?? '';
                    final name = oil['name']?.toString() ?? '';
                    final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
                    uniqueGroupKeys.add(key);
                  }

                  List<dynamic> getVariantsForGroup(String? groupKey) {
                    if (groupKey == null) return [];
                    return categoryOils.where((oil) {
                      final brand = oil['brand']?.toString() ?? '';
                      final grade = oil['grade']?.toString() ?? '';
                      final name = oil['name']?.toString() ?? '';
                      final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
                      return key == groupKey;
                    }).toList();
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${context.tr("Oil / Fluid Item")} #${i + 1}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                            ),
                            if (row.oilItems.length > 1)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  item.dispose();
                                  row.oilItems.removeAt(i);
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: item.selectedOilCategory,
                          decoration: InputDecoration(
                            labelText: context.tr('Select Category *'),
                            labelStyle: const TextStyle(fontSize: 12),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          items: _oilCategories.map<DropdownMenuItem<String>>((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(
                                context.tr(cat),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (cat) {
                            item.selectedOilCategory = cat;
                            item.selectedOilGroupKey = null;
                            item.selectedOilVolume = null;
                            item.selectedOilProductId = null;
                            item.selectedOilRunKm = null;
                            item.oilPricePerLitre = null;
                            item.oilLitresController.clear();
                            _syncAmountCollected();
                            _updateUi();
                          },
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _showOilProductSearchPicker(item),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: context.tr('Select Oil Product *'),
                              labelStyle: const TextStyle(fontSize: 12),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              suffixIcon: const Icon(Icons.search, color: Colors.amber, size: 20),
                            ),
                            child: Text(
                              item.selectedOilGroupKey ?? context.tr('Tap to search & select oil product...'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: item.selectedOilGroupKey != null ? FontWeight.w600 : FontWeight.normal,
                                color: item.selectedOilGroupKey != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (item.selectedOilGroupKey != null) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final variants = getVariantsForGroup(item.selectedOilGroupKey);
                              final currentVolume = item.selectedOilVolume;
                              final hasMatch = currentVolume != null &&
                                  variants.any((v) => (v['recommended_qty_litres'] as num).toDouble() == currentVolume);

                              return DropdownButtonFormField<double>(
                                isExpanded: true,
                                value: hasMatch ? currentVolume : null,
                                decoration: InputDecoration(
                                  labelText: context.tr('Select Litres (Volume) *'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  final v = variants.firstWhere(
                                      (o) => (o['recommended_qty_litres'] as num).toDouble() == val,
                                      orElse: () => {});
                                  if (v.isNotEmpty) {
                                    item.selectedOilVolume = val;
                                    item.selectedOilProductId = v['id'];
                                    item.selectedOilRunKm = v['oil_run_km'] as int?;
                                    item.oilPricePerLitre = (v['price_per_litre'] as num).toDouble();
                                    item.oilLitresController.text = val.toString();
                                    row._onOdometerChanged();
                                    _fetchOilPriceForProduct(item, v['id']);
                                  }
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              );
                            },
                          ),
                        ],
                        if (item.isLoadingOilPrice)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.0),
                            child: LinearProgressIndicator(),
                          ),
                        if (item.selectedOilProductId != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: item.oilLitresController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Litres Used *'),
                                    labelStyle: const TextStyle(fontSize: 12),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onChanged: (_) {
                                    _syncAmountCollected();
                                    _updateUi();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(context.tr('Rate / L'), style: TextStyle(fontSize: 10, color: Colors.amber.shade800)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$currencySymbol${(item.oilPricePerLitre ?? 0.0).toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(context.tr('Line Total'), style: TextStyle(fontSize: 10, color: Colors.green.shade800)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],

            // Add Another Oil / Fluid Button
            OutlinedButton.icon(
              onPressed: () {
                row.oilItems.add(_OilItemRow());
                _syncAmountCollected();
                _updateUi();
              },
              icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.amber),
              label: Text(
                context.tr('+ Add Another Oil / Fluid Item'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: row.oilFilterChanged,
                  onChanged: (val) {
                    row.oilFilterChanged = val ?? false;
                    if (!row.oilFilterChanged) {
                      row.selectedOilFilterId = null;
                      row.oilFilterPrice = 0.0;
                      row.selectedOilFilterRunKm = null;
                    }
                    _syncAmountCollected();
                    _updateUi();
                  },
                ),
                Text(context.tr('Filter Changed'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            // ── Oil Filter Searchable Selector (Only when Filter Changed is selected) ──
            if (row.oilFilterChanged && _oilFilters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  String? filterDisplayName;
                  if (row.selectedOilFilterId != null) {
                    final f = _oilFilters.firstWhere((item) => item['id'] == row.selectedOilFilterId, orElse: () => {});
                    if (f.isNotEmpty) {
                      final b = f['brand_name']?.toString() ?? '';
                      final n = f['name']?.toString() ?? '';
                      final p = (f['price'] as num?)?.toDouble() ?? 0.0;
                      final k = f['running_km'] ?? 5000;
                      filterDisplayName = '$b - $n (${CountryConfig.currencySymbol}${p.toStringAsFixed(0)} · $k KM)';
                    }
                  }

                  return InkWell(
                    onTap: () => _showOilFilterSearchPicker(row),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.tr('Select Oil Filter (Optional)'),
                        labelStyle: const TextStyle(fontSize: 14),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: const Icon(Icons.search, color: Colors.blue),
                      ),
                      child: Text(
                        filterDisplayName ?? context.tr('Tap to search & select oil filter...'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: filterDisplayName != null ? FontWeight.w600 : FontWeight.normal,
                          color: filterDisplayName != null ? Colors.black87 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (row.selectedOilFilterId != null && row.oilFilterPrice > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.tr("Filter Price")}: ${CountryConfig.currencySymbol}${row.oilFilterPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                    if (row.selectedOilFilterRunKm != null)
                      Text(
                        '${context.tr("Filter Run KM")}: ${row.selectedOilFilterRunKm} KM',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                      ),
                  ],
                ),
              ],
            ],
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.disc_full, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Tyre Details'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ],
                ),
                Text(
                  '${context.tr("Total Charge")}: $currencySymbol${row.tyreTotalCharge.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green.shade800),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Itemized Tyre Rows (1 by default)
            for (int i = 0; i < row.tyreItems.length; i++) ...[
              Builder(
                builder: (context) {
                  final item = row.tyreItems[i];
                  final filteredTyres = _tyres.where((t) {
                    if (item.selectedBrandId == null || item.selectedBrandId!.isEmpty) return true;
                    return t['tyre_brand_id']?.toString() == item.selectedBrandId;
                  }).toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${context.tr("Tyre Item")} #${i + 1}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade800),
                            ),
                            if (row.tyreItems.length > 1)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  item.dispose();
                                  row.tyreItems.removeAt(i);
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Brand & Size Dropdowns
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: item.selectedBrandId,
                                decoration: InputDecoration(
                                  labelText: context.tr('Select Brand *'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(context.tr('-- Select Brand --'), style: const TextStyle(fontSize: 12)),
                                  ),
                                  ..._tyreBrands.map<DropdownMenuItem<String>>((b) {
                                    return DropdownMenuItem<String>(
                                      value: b['id'] as String,
                                      child: Text(b['brand'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  item.selectedBrandId = val;
                                  item.selectedTyreId = null;
                                  item.unitPrice = 0.0;
                                  item.sizeController.clear();
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: item.selectedTyreId,
                                decoration: InputDecoration(
                                  labelText: context.tr('Select Size *'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(context.tr('-- Select Size --'), style: const TextStyle(fontSize: 12)),
                                  ),
                                  ...filteredTyres.map<DropdownMenuItem<String>>((t) {
                                    final brandName = t['tyre_brand_name']?.toString() ?? '';
                                    final sizeStr = t['size']?.toString() ?? '';
                                    final priceVal = (t['price'] as num?)?.toDouble() ?? 0.0;
                                    final stockVal = t['stock_qty'] ?? 0;
                                    final label = '$sizeStr ($currencySymbol${priceVal.toStringAsFixed(0)} · $stockVal in stock)';

                                    return DropdownMenuItem<String>(
                                      value: t['id'] as String,
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  item.selectedTyreId = val;
                                  if (val != null) {
                                    final selectedTyre = filteredTyres.firstWhere((t) => t['id'] == val, orElse: () => {});
                                    if (selectedTyre.isNotEmpty) {
                                      item.unitPrice = (selectedTyre['price'] as num?)?.toDouble() ?? 0.0;
                                      item.runningKm = selectedTyre['running_km'] as int? ?? 40000;
                                      item.sizeController.text = selectedTyre['size']?.toString() ?? '';
                                    }
                                  }
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Qty, Autofilled Price & Line Total
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: item.qtyController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: context.tr('Qty *'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onChanged: (_) {
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('Price (Autofill)'), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currencySymbol${item.unitPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.tr('Line Total'), style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Each Tyre Item Odometer & Next Change
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: item.odometerController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: context.tr('Odometer (KM)'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: item.nextChangeKmController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: context.tr('Next Change (KM)'),
                                  labelStyle: const TextStyle(fontSize: 12),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Add Another Tyre Button
            OutlinedButton.icon(
              onPressed: () {
                row.tyreItems.add(_TyreItemRow(initialQty: 4));
                _syncAmountCollected();
                _updateUi();
              },
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(context.tr('+ Add Another Tyre Brand / Size'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF000080),
                side: const BorderSide(color: Color(0xFF000080)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
                        onChanged: (val) {
                          row.alignmentDone = val ?? true;
                          _updateUi();
                        },
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
                        onChanged: (val) {
                          row.balancingDone = val ?? true;
                          _updateUi();
                        },
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
            onChanged: (_) {
              _syncAmountCollected();
              _updateUi();
            },
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
                  _applyGst = val ?? false;
                  _syncAmountCollected();
                  _updateUi();
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
                      if (val == true) {
                        _selectedTaxIds.add(id);
                      } else {
                        _selectedTaxIds.remove(id);
                      }
                      _syncAmountCollected();
                      _updateUi();
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
    final selectedTaxRows = selectedTaxes
        .map((t) {
          final name = t['name'] as String;
          final pct = (t['percent'] as num).toDouble();
          final amt = double.tryParse(t['amount'].toString()) ?? 0.0;
          return MapEntry('$name (${pct.toStringAsFixed(1)}%)', amt);
        })
        .toList();

    return _card(
      title: 'Bill Summary',
      child: Column(
        children: [
          // Per-service lines
          for (final row in _rows) ...[
            _summaryRow(context.tr(row.serviceName), '$currencySymbol${row.rate.toStringAsFixed(2)}'),
            if (row.serviceCategory == 'oil_change') ...[
              for (final item in row.oilItems) ...[
                Builder(
                  builder: (context) {
                    if (item.lineTotal <= 0) return const SizedBox.shrink();
                    final p = _oilProducts.firstWhere((o) => o['id'] == item.selectedOilProductId, orElse: () => {});
                    final brand = p['brand']?.toString() ?? '';
                    final grade = p['grade']?.toString() ?? '';
                    final cat = item.selectedOilCategory ?? 'Oil';
                    final oilLabel = brand.isNotEmpty
                        ? '  + $cat ($brand $grade ${item.oilLitres}L)'
                        : '  + $cat (${item.oilLitres}L)';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: _summaryRow(
                        oilLabel,
                        '+$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                        valueColor: Colors.amber.shade900,
                      ),
                    );
                  },
                ),
              ],
              Builder(
                builder: (context) {
                  if (!row.oilFilterChanged || row.oilFilterPrice <= 0) return const SizedBox.shrink();
                  final f = _oilFilters.firstWhere((item) => item['id'] == row.selectedOilFilterId, orElse: () => {});
                  final fBrand = f['brand_name']?.toString() ?? '';
                  final fName = f['name']?.toString() ?? '';
                  final filterLabel = (fBrand.isNotEmpty || fName.isNotEmpty)
                      ? '  + Oil Filter ($fBrand $fName)'
                      : '  + Oil Filter';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: _summaryRow(
                      filterLabel,
                      '+$currencySymbol${row.oilFilterPrice.toStringAsFixed(2)}',
                      valueColor: Colors.blue.shade900,
                    ),
                  );
                },
              ),
            ],
            if (row.serviceCategory == 'tyre_change') ...[
              for (final item in row.tyreItems) ...[
                Builder(
                  builder: (context) {
                    if (item.lineTotal <= 0) return const SizedBox.shrink();
                    final brandObj = _tyreBrands.firstWhere((b) => b['id'] == item.selectedBrandId, orElse: () => {});
                    final brandName = brandObj['brand']?.toString() ?? '';
                    final size = item.sizeController.text.trim();
                    final labelParts = [if (brandName.isNotEmpty) brandName, if (size.isNotEmpty) size].join(' ');
                    final label = labelParts.isNotEmpty
                        ? '  + Tyre ($labelParts x${item.quantity})'
                        : '  + Tyre (x${item.quantity})';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: _summaryRow(
                        label,
                        '+$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                        valueColor: Colors.blue.shade900,
                      ),
                    );
                  },
                ),
              ],
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
          if (_rows.length > 1 || _selectedExtras.isNotEmpty)
            _summaryRow(
              context.tr('Subtotal'),
              '$currencySymbol${subtotal.toStringAsFixed(2)}',
              isBold: true,
            ),
          if (additionalDiscountAmount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              _usePercentageDiscount
                  ? '  ${context.tr('Additional Discount')} (${_additionalDiscountController.text}%)'
                  : '  ${context.tr('Additional Discount')}',
              '-$currencySymbol${additionalDiscountAmount.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          ],
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

  // ── Additional Discount ───────────────────────────────────────────────────
  Widget _additionalDiscountCard() {
    return _card(
      title: 'Additional Discount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _usePercentageDiscount,
                    activeColor: const Color(0xFF000080),
                    onChanged: (val) {
                      _usePercentageDiscount = val ?? false;
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                  Text(
                    context.tr('Amount'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF1e293b),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _usePercentageDiscount,
                    activeColor: const Color(0xFF000080),
                    onChanged: (val) {
                      _usePercentageDiscount = val ?? true;
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                  Text(
                    context.tr('Percentage'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF1e293b),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _additionalDiscountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
            decoration: InputDecoration(
              labelText: _usePercentageDiscount
                  ? context.tr('Discount Percentage (%)')
                  : context.tr('Discount Amount'),
              prefixText: _usePercentageDiscount ? null : '$currencySymbol ',
              suffixText: _usePercentageDiscount ? '%' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sales Type selector ────────────────────────────────────────────────────
  Widget _salesTypeField() {
    return _card(
      title: 'Sales Type',
      child: Row(
        children: [
          _salesTypeOption('cash', 'Cash', Icons.money),
          _salesTypeOption('credit', 'Credit', Icons.credit_score),
        ],
      ),
    );
  }

  Widget _salesTypeOption(String type, String label, IconData icon) {
    final isSelected = _selectedSalesType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _selectedSalesType = type;
          if (type == 'credit') {
            // Credit: amount collected must be 0
            _amountCollectedController.text = '0';
          } else {
            // Cash: restore amount collected to invoice total
            _syncAmountCollected();
          }
          _updateUi();
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
              color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200,
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
                  fontSize: 13,
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
          _selectedPaymentMode = mode;
          _updateUi();
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
              final categoryName = (extra['service_type_name'] ?? '').toString();
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: const Color(0xFF1e293b),
                            ),
                          ),
                          if (categoryName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF000080).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                categoryName,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF000080),
                                ),
                              ),
                            ),
                          ],
                        ],
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
                        onChanged: (_) {
                          _syncAmountCollected();
                          _updateUi();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        controller.dispose();
                        _selectedExtras.remove(extraMap);
                        _syncAmountCollected();
                        _updateUi();
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

    final searchController = TextEditingController();
    String modalCategoryFilter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();

            // Extract unique categories available in remainingExtras
            final Map<String, String> categoryNames = {};
            for (final ext in remainingExtras) {
              final id = ext['service_type_id']?.toString() ?? 'general';
              final name = (ext['service_type_name']?.toString() ?? '').trim();
              categoryNames[id] = name.isNotEmpty ? name : 'General';
            }

            final filteredExtras = remainingExtras.where((ext) {
              final name = (ext['name']?.toString() ?? '').toLowerCase();
              final catId = ext['service_type_id']?.toString() ?? 'general';
              final matchesQuery = name.contains(query);
              final matchesCategory = modalCategoryFilter == 'all' || catId == modalCategoryFilter;
              return matchesQuery && matchesCategory;
            }).toList();

            // Group filtered extras by category name
            final Map<String, List<dynamic>> grouped = {};
            for (final ext in filteredExtras) {
              final cat = (ext['service_type_name']?.toString() ?? '').trim();
              final key = cat.isNotEmpty ? cat : 'General';
              grouped.putIfAbsent(key, () => []).add(ext);
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Extra'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFF000080),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: context.tr('Search extra item...'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (categoryNames.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              context.tr('All'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: modalCategoryFilter == 'all' ? Colors.white : const Color(0xFF1E293B),
                                fontWeight: modalCategoryFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: modalCategoryFilter == 'all',
                            selectedColor: const Color(0xFF000080),
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (selected) {
                              if (selected) setModalState(() => modalCategoryFilter = 'all');
                            },
                          ),
                          const SizedBox(width: 6),
                          ...categoryNames.entries.map((entry) {
                            final isSel = modalCategoryFilter == entry.key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  entry.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isSel ? Colors.white : const Color(0xFF1E293B),
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFF000080),
                                backgroundColor: const Color(0xFFF1F5F9),
                                onSelected: (selected) {
                                  if (selected) setModalState(() => modalCategoryFilter = entry.key);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Expanded(
                    child: filteredExtras.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No extras found'),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: grouped.keys.length,
                            itemBuilder: (context, catIdx) {
                              final catName = grouped.keys.elementAt(catIdx);
                              final catItems = grouped[catName]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF000080).withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      catName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: const Color(0xFF000080),
                                      ),
                                    ),
                                  ),
                                  ...catItems.map((ext) {
                                    final name = ext['name'] ?? '';
                                    final catLabel = ext['service_type_name'] ?? '';
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                                        child: const Icon(Icons.stars, color: Color(0xFF000080), size: 18),
                                      ),
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      subtitle: catLabel.isNotEmpty
                                          ? Text(
                                              catLabel,
                                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                            )
                                          : null,
                                      trailing: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF000080).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add, color: Color(0xFF000080), size: 16),
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        final controller = TextEditingController(text: '0');
                                        controller.addListener(() {
                                          _syncAmountCollected();
                                          _updateUi();
                                        });
                                        _selectedExtras.add({
                                          'extra': ext,
                                          'priceController': controller,
                                        });
                                        _syncAmountCollected();
                                        _updateUi();
                                      },
                                    );
                                  }),
                                ],
                              );
                            },
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



  void _showOilProductSearchPicker(_OilItemRow item) {
    String selectedCategory = item.selectedOilCategory ?? 'Engine Oil';
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter products by selected category
            final categoryOils = _oilProducts.where((oil) {
              final cat = oil['category']?.toString() ?? 'Engine Oil';
              return cat == selectedCategory;
            }).toList();

            final uniqueGroupKeys = <String>{};
            for (var oil in categoryOils) {
              final brand = oil['brand']?.toString() ?? '';
              final grade = oil['grade']?.toString() ?? '';
              final name = oil['name']?.toString() ?? '';
              final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
              uniqueGroupKeys.add(key);
            }
            final sortedGroupKeys = uniqueGroupKeys.toList()..sort();

            List<dynamic> getVariantsForGroup(String? groupKey) {
              if (groupKey == null) return [];
              return categoryOils.where((oil) {
                final brand = oil['brand']?.toString() ?? '';
                final grade = oil['grade']?.toString() ?? '';
                final name = oil['name']?.toString() ?? '';
                final key = [brand, grade, name].where((s) => s.isNotEmpty).join(' • ');
                return key == groupKey;
              }).toList();
            }

            final query = searchController.text.trim().toLowerCase();
            final filteredKeys = sortedGroupKeys.where((k) => k.toLowerCase().contains(query)).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Product'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _oilCategories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              context.tr(cat),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF000080),
                            backgroundColor: Colors.grey.shade100,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedCategory = cat;
                                  item.selectedOilCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: context.tr('Search brand, grade or product name...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredKeys.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                context.tr('No products found in ${context.tr(selectedCategory)}'),
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredKeys.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final key = filteredKeys[index];
                              final isSelected = item.selectedOilGroupKey == key;
                              final variants = getVariantsForGroup(key);

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xFF000080).withValues(alpha: 0.08),
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? const Color(0xFF000080) : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.oil_barrel,
                                    size: 18,
                                    color: isSelected ? Colors.white : const Color(0xFF000080),
                                  ),
                                ),
                                title: Text(
                                  key,
                                  style: GoogleFonts.inter(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${variants.length} volume variant(s)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF000080))
                                    : const Icon(Icons.chevron_right, size: 18),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  item.selectedOilCategory = selectedCategory;
                                  item.selectedOilGroupKey = key;
                                  item.selectedOilVolume = null;
                                  item.selectedOilProductId = null;
                                  item.selectedOilRunKm = null;
                                  item.oilPricePerLitre = null;
                                  item.oilLitresController.clear();

                                  if (variants.length == 1) {
                                    final v = variants.first;
                                    final vol = (v['recommended_qty_litres'] as num).toDouble();
                                    item.selectedOilVolume = vol;
                                    item.selectedOilProductId = v['id'];
                                    item.selectedOilRunKm = v['oil_run_km'] as int?;
                                    item.oilPricePerLitre = (v['price_per_litre'] as num).toDouble();
                                    item.oilLitresController.text = vol.toString();
                                    _fetchOilPriceForProduct(item, v['id']);
                                  }
                                  _syncAmountCollected();
                                  _updateUi();
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
      },
    );
  }

  void _showOilFilterSearchPicker(_ServiceRow row) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredFilters = _oilFilters.where((f) {
              final brand = (f['brand_name']?.toString() ?? '').toLowerCase();
              final name = (f['name']?.toString() ?? '').toLowerCase();
              return brand.contains(query) || name.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Oil Filter'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: context.tr('Search brand or filter part no...'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (row.selectedOilFilterId != null) ...[
                    ListTile(
                      leading: const Icon(Icons.clear_all, color: Colors.red),
                      title: Text(
                        context.tr('Clear Filter Selection'),
                        style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        row.selectedOilFilterId = null;
                        row.oilFilterPrice = 0.0;
                        row.selectedOilFilterRunKm = null;
                        _syncAmountCollected();
                        _updateUi();
                      },
                    ),
                    const Divider(height: 1),
                  ],
                  Expanded(
                    child: filteredFilters.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No oil filters found'),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredFilters.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final filter = filteredFilters[index];
                              final filterId = filter['id'] as String;
                              final isSelected = row.selectedOilFilterId == filterId;
                              final brand = filter['brand_name']?.toString() ?? '';
                              final name = filter['name']?.toString() ?? '';
                              final price = (filter['price'] as num?)?.toDouble() ?? 0.0;
                              final km = filter['running_km'] ?? 5000;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.filter_alt,
                                    size: 18,
                                    color: isSelected ? Colors.white : Colors.blue.shade800,
                                  ),
                                ),
                                title: Text(
                                  '$brand - $name',
                                  style: GoogleFonts.inter(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Price: ${CountryConfig.currencySymbol}${price.toStringAsFixed(2)}  •  Lifespan: $km KM',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.blue)
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  row.selectedOilFilterId = filterId;
                                  row.oilFilterPrice = price;
                                  row.selectedOilFilterRunKm = km as int?;
                                  row._onOdometerChanged();
                                  _syncAmountCollected();
                                  _updateUi();
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
