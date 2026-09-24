import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';
import 'invoice_view_screen.dart';


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

// ── Battery itemized row for battery replacement ──────────────────────────────
class _BatteryItemRow {
  String? selectedBatteryId;
  String makeName = '';
  String ampereName = '';
  String segmentName = '';
  double warrantyYears = 1.0;
  double defaultPrice = 0.0;
  final TextEditingController priceController = TextEditingController();
  final TextEditingController warrantyController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  _BatteryItemRow({
    this.selectedBatteryId,
    this.makeName = '',
    this.ampereName = '',
    this.segmentName = '',
    this.warrantyYears = 1.0,
    double initialPrice = 0.0,
  }) {
    defaultPrice = initialPrice;
    priceController.text = initialPrice > 0 ? initialPrice.toStringAsFixed(2) : '0.00';
    warrantyController.text = warrantyYears.toString();
  }

  double get price => double.tryParse(priceController.text) ?? defaultPrice;
  int get quantity => int.tryParse(qtyController.text) ?? 1;
  double get lineTotal => price * quantity;
  String get displayName => '$makeName $ampereName ($segmentName)';

  void dispose() {
    priceController.dispose();
    warrantyController.dispose();
    qtyController.dispose();
  }
}

// ── Trading/Stock Itemized row for inventory/stock items ──────────────────────
class _TradingItemRow {
  Map<String, dynamic>? selectedStockItem;
  final TextEditingController rateController = TextEditingController(text: '0.00');
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController discountController = TextEditingController(text: '0.00');
  double currentStock = 0.0;
  String unitName = 'Pcs';
  bool isOperational = false;

  double get rate => isOperational ? 0.0 : (double.tryParse(rateController.text) ?? 0.0);
  double get qty => double.tryParse(qtyController.text) ?? 1.0;
  double get discount => isOperational ? 0.0 : (double.tryParse(discountController.text) ?? 0.0);
  double get netTaxable => isOperational ? 0.0 : ((rate * qty) - discount).clamp(0.0, double.infinity);
  double get lineTotal => netTaxable;

  void dispose() {
    rateController.dispose();
    qtyController.dispose();
    discountController.dispose();
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

  // Battery Change (Itemized List)
  final List<_BatteryItemRow> batteryItems = [];

  double get batteryTotalCharge {
    if (serviceCategory != 'battery_change' && serviceCategory != 'battery' && !serviceName.toLowerCase().contains('battery')) return 0.0;
    return batteryItems.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  // Wheel Alignment
  bool alignmentDone = true;
  bool balancingDone = true;
  final TextEditingController alignmentNotesController = TextEditingController();
  final TextEditingController nextAlignmentKmController = TextEditingController();

  // Smoke Test Renewal Period (6 or 12 months)
  int smokeTestPeriodMonths = 6;
  bool isSmokeTestPeriodInitialized = false;

  // Car Detailing Warranty & Price Edit
  final TextEditingController warrantyValueController = TextEditingController(text: '6');
  String warrantyUnit = 'month';
  final TextEditingController customRateController;

  _ServiceRow({required this.service})
      : customRateController = TextEditingController(
          text: ((service['rate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        ) {
    // If odometer controller is updated, auto-calculate next oil/tyre change km if blank
    odometerController.addListener(_onOdometerChanged);
  }

  bool get isDetailingCategory {
    final cat = serviceCategory.toLowerCase();
    final typeName = (service['service_type'] ?? service['service_category'] ?? '').toString().toLowerCase();
    final name = serviceName.toLowerCase();
    return cat == 'car_detailing' ||
        cat == 'detailing' ||
        typeName.contains('detail') ||
        name.contains('detail') ||
        name.contains('coating') ||
        name.contains('ceramic') ||
        name.contains('polishing') ||
        name.contains('ppf') ||
        name.contains('borophine') ||
        name.contains('graphene');
  }

  bool get isWheelAlignmentCategory {
    final name = serviceName.toLowerCase();

    // Pure Wheel Balancing (Alloy Wheel / Normal Wheel / Wheel Balancing) without alignment -> return false
    if (name.contains('balancing') && !name.contains('alignment')) {
      return false;
    }

    if (name.contains('alignment')) {
      return true;
    }

    final cat = serviceCategory.toLowerCase();
    return cat == 'wheel_alignment' && !name.contains('balancing');
  }

  bool get isWheelBalancingOrAlignmentCategory {
    final cat = serviceCategory.toLowerCase();
    final name = serviceName.toLowerCase();
    return cat.contains('wheel') ||
        cat.contains('alignment') ||
        cat.contains('balancing') ||
        name.contains('wheel') ||
        name.contains('alignment') ||
        name.contains('balancing');
  }

  bool get isCarwashOrCleaningCategory {
    final cat = serviceCategory.toLowerCase();
    final typeName = (service['service_type'] ?? service['service_category'] ?? '').toString().toLowerCase();
    final name = serviceName.toLowerCase();
    return cat == 'car_wash' ||
        cat == 'washing' ||
        cat == 'cleaning' ||
        cat == 'carwash' ||
        cat == 'wash' ||
        cat == 'clean' ||
        typeName.contains('wash') ||
        typeName.contains('clean') ||
        name.contains('wash') ||
        name.contains('clean') ||
        name.contains('washing') ||
        name.contains('cleaning') ||
        name.contains('foam') ||
        name.contains('steam') ||
        name.contains('vacuum');
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

  double get rate {
    if (serviceCategory != 'tyre_change' &&
        serviceCategory != 'battery_change' &&
        serviceCategory != 'battery' &&
        !serviceName.toLowerCase().contains('battery')) {
      final custom = double.tryParse(customRateController.text);
      if (custom != null && custom >= 0) return custom;
    }
    return (service['rate'] as num?)?.toDouble() ?? 0.0;
  }

  double get subtotal {
    double base = rate;
    if (serviceCategory == 'oil_change') {
      base += oilTotalCharge;
    } else if (serviceCategory == 'tyre_change') {
      base += tyreTotalCharge;
    } else if (serviceCategory == 'battery_change' || serviceCategory == 'battery' || serviceName.toLowerCase().contains('battery')) {
      base += batteryTotalCharge;
    }
    return base;
  }

  double get effectiveDiscount {
    if (selectedScheme != null) return schemeDiscount;
    return double.tryParse(discountController.text) ?? 0.0;
  }

  double get total => (subtotal - effectiveDiscount).clamp(0.0, double.infinity);
  double get lineTotal => total;

  String get serviceId => service['id']?.toString() ?? '';
  String get serviceName => service['name']?.toString() ?? '';

  void dispose() {
    customRateController.dispose();
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
    nextAlignmentKmController.dispose();
    warrantyValueController.dispose();
  }
}



class InvoiceCreateScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> vehicle;
  final String? bookingId;
  final Map<String, dynamic>? invoiceToEdit;

  const InvoiceCreateScreen({
    super.key,
    required this.customer,
    required this.vehicle,
    this.bookingId,
    this.invoiceToEdit,
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
  DateTime _selectedInvoiceDate = DateTime.now();

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

  // Oil Products, Oil Filters, Tyre Brands, Tyres, Batteries and Enabled Categories
  List<dynamic> _oilProducts = [];
  List<dynamic> _oilFilters = [];
  List<dynamic> _tyreBrands = [];
  List<dynamic> _tyres = [];
  List<dynamic> _batteries = [];
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



  // Branch Staff State
  bool _addStaffs = false;
  List<Map<String, dynamic>> _availableStaffs = [];
  final List<Map<String, dynamic>> _selectedStaffs = [];

  // Trading Items State
  bool _addTradingItems = false;
  final List<_TradingItemRow> _tradingRows = [];
  List<dynamic> _availableStockItems = [];

  // Checkbox section flags
  bool _addExtras = false;
  bool _addRemarks = false;
  final TextEditingController _remarksController = TextEditingController();
  bool _addReminders = false;
  bool _addCustomReminders = false;
  final List<TextEditingController> _reminderDaysControllers = [];

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
  double get totalTradingItemsAmount =>
      _addTradingItems ? _tradingRows.fold(0.0, (s, r) => s + r.netTaxable) : 0.0;
  double get totalExtrasAmount => _addExtras
      ? _selectedExtras.fold(0.0, (s, e) {
          final qtyController = e['qtyController'] as TextEditingController?;
          final rateController = e['rateController'] as TextEditingController?;
          final priceController = e['priceController'] as TextEditingController?;

          final qty = qtyController != null ? (double.tryParse(qtyController.text) ?? 1.0) : 1.0;
          final rate = rateController != null
              ? (double.tryParse(rateController.text) ?? 0.0)
              : (priceController != null ? (double.tryParse(priceController.text) ?? 0.0) : 0.0);
          return s + (qty * rate);
        })
      : 0.0;

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
    final tradingDiscount = _addTradingItems ? _tradingRows.fold(0.0, (s, r) => s + r.discount) : 0.0;
    return itemDiscount + tradingDiscount + additionalDiscountAmount;
  }

  // Subtotal = gross amount before discount
  double get subtotal =>
      (totalServicesAmount + totalTradingItemsAmount + totalExtrasAmount).clamp(0.0, double.infinity);

  // Taxable Value = Subtotal after discount
  double get taxableValue => (subtotal - totalDiscount).clamp(0.0, double.infinity);

  // Tax Amount = calculated on Taxable Value (post-discount)
  double get taxAmount {
    if (!_applyGst) return 0.0;
    double t = 0.0;
    for (final tax in _availableTaxes) {
      if (_selectedTaxIds.contains(tax['id']?.toString() ?? '')) {
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
        .where((t) => _selectedTaxIds.contains(t['id']?.toString() ?? ''))
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
        return row.selectedScheme!['id']?.toString() ?? '';
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
    for (final tRow in _tradingRows) {
      tRow.dispose();
    }
    final Set<TextEditingController> extraControllersToDispose = {};
    for (final extra in _selectedExtras) {
      if (extra['qtyController'] is TextEditingController) {
        extraControllersToDispose.add(extra['qtyController'] as TextEditingController);
      }
      if (extra['rateController'] is TextEditingController) {
        extraControllersToDispose.add(extra['rateController'] as TextEditingController);
      }
      if (extra['remarkController'] is TextEditingController) {
        extraControllersToDispose.add(extra['remarkController'] as TextEditingController);
      }
      if (extra['priceController'] is TextEditingController) {
        extraControllersToDispose.add(extra['priceController'] as TextEditingController);
      }
    }
    for (final c in extraControllersToDispose) {
      c.dispose();
    }
    _remarksController.dispose();
    for (final controller in _reminderDaysControllers) {
      controller.dispose();
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
        widget.customer['id']?.toString() ?? '',
        widget.vehicle['id']?.toString() ?? '',
        token,
      );
      final extRes = await ApiService.getExtrasList(token);

      Map<String, dynamic>? oilRes;
      Map<String, dynamic>? filterRes;
      Map<String, dynamic>? tyreBrandRes;
      Map<String, dynamic>? tyresListRes;
      Map<String, dynamic>? batteryRes;
      try {
        oilRes = await ApiService.getOilProducts(token);
        filterRes = await ApiService.getOilFilters(token);
        tyreBrandRes = await ApiService.getTyreBrands(token);
        tyresListRes = await ApiService.getTyres(token);
        batteryRes = await ApiService.getBatteries(token);
      } catch (_) {}

      if (svcRes['success'] == true) {
        if (svcRes['wheel_type'] != null && (widget.vehicle['wheel_type'] == null || widget.vehicle['wheel_type'].toString().isEmpty)) {
          widget.vehicle['wheel_type'] = svcRes['wheel_type'];
        }
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
            _availableTaxes.map((t) => t['id']?.toString() ?? '').toSet();
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
      if (batteryRes != null && batteryRes['success'] == true) {
        _batteries = batteryRes['batteries'] ?? [];
      }
      try {
        final staffRes = await ApiService.getStaffList(token);
        if (staffRes['success'] == true) {
          _availableStaffs = (staffRes['staffs'] as List<dynamic>? ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map))
              .toList();
        }
      } catch (_) {}
      try {
        final formRes = await ApiService.getFormData(token);
        if (formRes['success'] == true) {
          _availableStockItems = formRes['stock_items'] ?? [];
        }
      } catch (_) {}

      if (widget.invoiceToEdit != null) {
        final editInv = widget.invoiceToEdit!;
        if (editInv['date'] != null) {
          try {
            _selectedInvoiceDate = DateTime.parse(editInv['date'].toString());
          } catch (_) {}
        }
        if (editInv['discount'] != null) {
          _additionalDiscountController.text = (double.tryParse(editInv['discount'].toString()) ?? 0.0).toStringAsFixed(2);
        }
        if (editInv['amount_collected'] != null) {
          _amountCollectedController.text = (double.tryParse(editInv['amount_collected'].toString()) ?? 0.0).toStringAsFixed(0);
        }
        if (editInv['invoice_type'] == 'creditinvoice') {
          _selectedSalesType = 'credit';
        } else {
          _selectedSalesType = 'cash';
        }
        if (editInv['remarks'] != null && editInv['remarks'].toString().trim().isNotEmpty) {
          _addRemarks = true;
          _remarksController.text = editInv['remarks'].toString();
        }
        final existingServices = editInv['services'] as List<dynamic>? ?? editInv['items'] as List<dynamic>? ?? [];
        for (final item in existingServices) {
          final svcName = (item['name'] ?? item['service_name'] ?? '').toString();
          // service_id is the actual FK id from the service table; id may be invoice_item.id
          final svcFkId = item['service_id']?.toString() ?? item['id']?.toString();
          final itemRate = double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
          final itemDisc = double.tryParse(item['discount']?.toString() ?? '') ?? 0.0;

          Map<String, dynamic> matchedSvc = {};
          // Try matching by service FK id first, then fall back to name match
          if (svcFkId != null && svcFkId.isNotEmpty) {
            matchedSvc = _allServices.firstWhere(
              (s) => s['id'].toString() == svcFkId,
              orElse: () => <String, dynamic>{},
            );
          }
          if (matchedSvc.isEmpty) {
            matchedSvc = _allServices.firstWhere(
              (s) => s['name'].toString().toLowerCase() == svcName.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
          }
          // If still not found, build a placeholder so the service still shows
          if (matchedSvc.isEmpty) {
            matchedSvc = {
              'id': svcFkId ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
              'name': svcName,
              'rate': itemRate,
              'has_price': itemRate > 0,
              'service_type_slug': item['service_category'] ?? 'car_wash',
            };
          }

          final row = _ServiceRow(service: matchedSvc);
          final detailMap = item['service_detail'] as Map<String, dynamic>? ?? {};
          final savedPeriod = detailMap['smoke_test_period_months'] ?? item['smoke_test_period_months'];
          if (savedPeriod != null) {
            final p = int.tryParse(savedPeriod.toString());
            if (p != null) {
              row.smokeTestPeriodMonths = p;
              row.isSmokeTestPeriodInitialized = true;
            }
          }
          // Always set the actual rate from the saved invoice
          row.customRateController.text = itemRate.toStringAsFixed(2);
          if (itemDisc > 0) {
            row.discountController.text = itemDisc.toStringAsFixed(2);
          }
          row.discountController.addListener(() {
            _syncAmountCollected();
            _updateUi();
          });
          row.customRateController.addListener(() {
            _syncAmountCollected();
            _updateUi();
          });
          _rows.add(row);
        }

        final existingTrading = editInv['trading_items'] as List<dynamic>? ?? [];
        if (existingTrading.isNotEmpty) {
          _addTradingItems = true;
          for (final t in existingTrading) {
            final tRow = _TradingItemRow();
            tRow.rateController.text = double.tryParse(t['rate']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00';
            tRow.qtyController.text = (t['qty'] ?? 1).toString();
            tRow.discountController.text = double.tryParse(t['discount']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00';
            tRow.isOperational = (t['is_operational'] == true);
            if (t['id'] != null) {
              final stockMatch = _availableStockItems.firstWhere(
                (st) => st['id'].toString() == t['id'].toString(),
                orElse: () => null,
              );
              if (stockMatch != null) {
                tRow.selectedStockItem = stockMatch;
              }
            }
            _tradingRows.add(tRow);
          }
        }

        final existingStaffs = editInv['assigned_staffs'] as List<dynamic>? ?? editInv['staffs'] as List<dynamic>? ?? [];
        if (existingStaffs.isNotEmpty) {
          _addStaffs = true;
          for (final st in existingStaffs) {
            final stId = st['id']?.toString();
            if (stId != null) {
              final match = _availableStaffs.firstWhere(
                (s) => s['id'].toString() == stId,
                orElse: () => <String, dynamic>{},
              );
              if (match.isNotEmpty && !_selectedStaffs.any((s) => s['id'] == match['id'])) {
                _selectedStaffs.add(match);
              }
            }
          }
        }
      }

      _isLoading = false;
      if (widget.invoiceToEdit != null && widget.invoiceToEdit!['amount_collected'] != null) {
        _amountCollectedController.text = (double.tryParse(widget.invoiceToEdit!['amount_collected'].toString()) ?? 0.0).toStringAsFixed(0);
      } else {
        _syncAmountCollected();
      }
      _updateUi();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _updateUi();
    }
  }


  void _syncAmountCollected() {
    // When editing an existing invoice, don't auto-overwrite the saved collected amount
    if (widget.invoiceToEdit != null) return;
    _amountCollectedController.text = total.round().toString();
  }

  bool get _hasWheelAlignmentService => _rows.any((r) => r.isWheelBalancingOrAlignmentCategory);
  bool get _hasDetailingService => _rows.any((r) => r.isDetailingCategory);
  bool get _hasOilChangeService => _rows.any((r) => r.serviceCategory == 'oil_change');

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
      row.customRateController.addListener(() {
        _syncAmountCollected();
        _updateUi();
      });
      _rows.insert(0, row);
      _loadSchemesForRow(row);
    }
    if (_hasWheelAlignmentService || _hasOilChangeService) {
      _addCustomReminders = true;
      if (_reminderDaysControllers.isEmpty) {
        _reminderDaysControllers.add(TextEditingController(text: ''));
      }
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
        widget.customer['id']?.toString() ?? '',
        widget.vehicle['id']?.toString() ?? '',
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

      // Mandatory validation for Wheel Alignment details
      if (row.isWheelAlignmentCategory) {
        final odoStr = row.odometerController.text.trim();
        final nextKmStr = row.nextAlignmentKmController.text.trim();
        if (odoStr.isEmpty || int.tryParse(odoStr) == null || int.tryParse(odoStr)! <= 0) {
          _snack(
            context.tr('Please enter Current Odometer (KM) for Wheel Alignment'),
            isError: true,
          );
          return;
        }
        if (nextKmStr.isEmpty || int.tryParse(nextKmStr) == null || int.tryParse(nextKmStr)! <= 0) {
          _snack(
            context.tr('Please enter Next Alignment Due (KM) for Wheel Alignment'),
            isError: true,
          );
          return;
        }

        if (!_addCustomReminders ||
            !_reminderDaysControllers.any((c) => (int.tryParse(c.text.trim()) ?? 0) > 0)) {
          _snack(
            context.tr('Please enter at least one valid Custom Reminder Day for Wheel Alignment'),
            isError: true,
          );
          return;
        }
      }

      // Mandatory validation for Oil Change details
      if (row.serviceCategory == 'oil_change') {
        final odoStr = row.odometerController.text.trim();
        final nextKmStr = row.nextOilChangeKmController.text.trim();
        if (odoStr.isEmpty || int.tryParse(odoStr) == null || int.tryParse(odoStr)! <= 0) {
          _snack(
            context.tr('Please enter Current Odometer (KM) for Oil Change'),
            isError: true,
          );
          return;
        }
        if (nextKmStr.isEmpty || int.tryParse(nextKmStr) == null || int.tryParse(nextKmStr)! <= 0) {
          _snack(
            context.tr('Please enter Next Oil Change Due (KM) for Oil Change'),
            isError: true,
          );
          return;
        }

        if (!_addCustomReminders ||
            !_reminderDaysControllers.any((c) => (int.tryParse(c.text.trim()) ?? 0) > 0)) {
          _snack(
            context.tr('Please enter at least one valid Custom Reminder Day for Oil Change'),
            isError: true,
          );
          return;
        }
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

            detail = {
              'service_category': 'tyre_change',
              'tyre_items': mappedItems,
              'total_tyres_count': r.tyreItems.fold<int>(0, (sum, item) => sum + item.quantity),
              'total_tyre_charge': r.tyreTotalCharge,
              'odometer_at_service': int.tryParse(r.odometerController.text),
              'next_tyre_change_km': int.tryParse(r.nextTyreChangeKmController.text),
            };
          } else if (r.isWheelAlignmentCategory) {
            detail = {
              'service_category': 'wheel_alignment',
              'alignment_done': r.alignmentDone,
              'balancing_done': r.balancingDone,
              'alignment_notes': r.alignmentNotesController.text.trim(),
              'odometer_at_service': int.tryParse(r.odometerController.text),
              'next_alignment_km': int.tryParse(r.nextAlignmentKmController.text),
            };
          } else if (r.serviceCategory == 'smoke_test' || r.serviceCategory == 'pollution_test' || r.serviceName.toLowerCase().contains('smoke') || r.serviceName.toLowerCase().contains('pollution')) {
            detail = {
              'service_category': 'smoke_test',
              'smoke_test_period_months': r.smokeTestPeriodMonths,
            };
          } else if (r.isDetailingCategory) {
            final wVal = int.tryParse(r.warrantyValueController.text.trim());
            final wUnit = r.warrantyUnit;
            final unitText = wUnit == 'year' ? (wVal == 1 ? 'Year' : 'Years') : (wVal == 1 ? 'Month' : 'Months');
            detail = {
              'service_category': 'car_detailing',
              'warranty_value': wVal,
              'warranty_unit': wUnit,
              'warranty_text': wVal != null ? '$wVal $unitText' : '',
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
        ..._selectedExtras.map((e) {
          final qtyVal = double.tryParse((e['qtyController'] as TextEditingController?)?.text ?? '1') ?? 1.0;
          final rateVal = double.tryParse((e['rateController'] as TextEditingController?)?.text ?? (e['priceController'] as TextEditingController?)?.text ?? '0') ?? 0.0;
          final remarkVal = (e['remarkController'] as TextEditingController?)?.text.trim() ?? '';
          
          String extraName = e['extra']['name'] as String;
          if (remarkVal.isNotEmpty) {
            extraName = '$extraName ($remarkVal)';
          }

          return {
            'id': e['extra']['id'],
            'name': extraName,
            'rate': rateVal,
            'qty': qtyVal,
            'remark': remarkVal,
            'discount': 0.0,
          };
        }),
      ];


      final tradingItemsPayload = _addTradingItems
          ? _tradingRows.where((r) => r.selectedStockItem != null).map((r) => {
                'id': r.selectedStockItem!['id'],
                'item_name': r.selectedStockItem!['item_name'],
                'rate': r.rate,
                'qty': r.qty,
                'discount': r.discount,
                'net_taxable': r.netTaxable,
                'is_operational': r.isOperational,
              }).toList()
          : [];

      final customRemindersPayload = _addCustomReminders
          ? _reminderDaysControllers
              .map((c) => int.tryParse(c.text.trim()) ?? 0)
              .where((days) => days > 0)
              .map((days) => {'days_after': days})
              .toList()
          : [];

      final invoiceData = {
        'customer_id': widget.customer['id'],
        'vehicle_id': widget.vehicle['id'],
        'date': "${_selectedInvoiceDate.year}-${_selectedInvoiceDate.month.toString().padLeft(2, '0')}-${_selectedInvoiceDate.day.toString().padLeft(2, '0')}",
        'invoice_date': "${_selectedInvoiceDate.year}-${_selectedInvoiceDate.month.toString().padLeft(2, '0')}-${_selectedInvoiceDate.day.toString().padLeft(2, '0')}",
        'subtotal': subtotal,
        'discount': totalDiscount,
        'tax_amount': taxAmount,
        'total': total,
        'amount_collected':
            double.tryParse(_amountCollectedController.text) ?? 0.0,
        'payment_mode': _selectedSalesType == 'cash' ? _selectedPaymentMode : null,
        'sales_type': _selectedSalesType,
        'services': services,
        'trading_items': tradingItemsPayload,
        if (_addRemarks && _remarksController.text.trim().isNotEmpty)
          'remarks': _remarksController.text.trim(),
        if (_addStaffs && _selectedStaffs.isNotEmpty)
          'staff_ids': _selectedStaffs.map((s) => s['id']).toList(),
        if (_addStaffs && _selectedStaffs.isNotEmpty)
          'staffs': _selectedStaffs.map((s) => {'id': s['id'], 'name': s['name']}).toList(),
        if (_addCustomReminders && customRemindersPayload.isNotEmpty)
          'reminders_enabled': true,
        if (_addCustomReminders && customRemindersPayload.isNotEmpty)
          'reminders': customRemindersPayload,
        if (!_addCustomReminders && _addReminders)
          'reminders_enabled': true,
        if (widget.bookingId != null) 'booking_id': widget.bookingId,
        if (primarySchemeId != null) 'scheme_id': primarySchemeId,
        if (primaryVoucherId != null) 'voucher_id': primaryVoucherId,
      };

      final response = widget.invoiceToEdit != null
          ? await ApiService.updateInvoice(
              widget.invoiceToEdit!['id'] ?? widget.invoiceToEdit!['invoice_id'],
              invoiceData,
              token,
            )
          : await ApiService.createInvoice(invoiceData, token);
      if (!mounted) return;

      if (response['success'] == true) {
        if (widget.invoiceToEdit != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Invoice updated successfully')),
              backgroundColor: Colors.green,
            ),
          );
        }
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
                'company_seal': response['company_seal'] ?? '',
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

  void _showWheelTypePickerModal() {
    String selectedType = 'normal_wheel';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: Color(0xFF000080)),
                      SizedBox(width: 8),
                      Text(
                        context.tr('Select Vehicle Wheel Type'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Color(0xFF000080)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    "${context.tr('Vehicle')}: ${widget.vehicle['no'] ?? widget.vehicle['number'] ?? ''}",
                    style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 16),
                  RadioListTile<String>(
                    title: Text(context.tr('Alloy Wheel (Alignment Vehicle)'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    value: 'alloy_wheel',
                    groupValue: selectedType,
                    activeColor: Color(0xFF000080),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(context.tr('Normal Wheel'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    value: 'normal_wheel',
                    groupValue: selectedType,
                    activeColor: Color(0xFF000080),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        widget.vehicle['wheel_type'] = selectedType;
                        final token = context.read<AuthProvider>().token;
                        if (token != null) {
                          try {
                            await ApiService.editCustomer({
                              'customer_id': widget.customer['id'],
                              'name': widget.customer['name'],
                              'phone': widget.customer['phone'],
                              'customer_type_id': widget.customer['customer_type_id'] ?? '',
                              'updated_vehicles': [
                                {
                                  'id': widget.vehicle['id'],
                                  'vehicle_number': widget.vehicle['no'] ?? widget.vehicle['number'] ?? '',
                                  'wheel_type': selectedType,
                                }
                              ],
                            }, token);
                          } catch (_) {}
                        }
                        _loadAll();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF000080),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(context.tr('Save Wheel Type'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp)),
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
              widget.invoiceToEdit != null
                  ? context.tr('Edit Invoice')
                  : context.tr('Create Invoice'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Color(0xFF000080),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty && _allServices.isEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _customerCard(),
                      const SizedBox(height: 16),
                      _invoiceDateCard(),
                      const SizedBox(height: 16),
                      _serviceSelectionCard(),
                      const SizedBox(height: 16),
                      // Per-row scheme + discount sections
                      for (final row in _rows) ...[
                        _serviceRowCard(row),
                        const SizedBox(height: 12),
                      ],
                      _staffSelectionCard(),
                      const SizedBox(height: 16),
                      _tradingItemsCard(),
                      const SizedBox(height: 16),
                      if (_availableExtras.isNotEmpty) ...[
                        _extrasCard(),
                        const SizedBox(height: 16),
                      ],
                      _remarksCard(),
                      const SizedBox(height: 16),
                      _customRemindersCard(),
                      const SizedBox(height: 16),
                      
                      if (_availableTaxes.isNotEmpty) ...[
                        _taxSelectionSection(),
                        const SizedBox(height: 16),
                      ],
                      if (_rows.isNotEmpty || _tradingRows.isNotEmpty || _selectedExtras.isNotEmpty) ...[
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF000080).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Color(0xFF000080), size: 22),
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
                    fontSize: 15.sp,
                    color: Color(0xFF1e293b),
                  ),
                ),
                if (widget.customer['branch'] != null && widget.customer['branch'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Text(
                      "${context.tr('Branch')}: ${widget.customer['branch']}",
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Builder(
                  builder: (context) {
                    final emission = (widget.vehicle['emission_standard'] ?? widget.vehicle['emission_standard_name'] ?? '').toString().trim();
                    final vehicleInfo = (widget.vehicle['vehicle_type'] != null && widget.vehicle['vehicle_type'].toString().isNotEmpty)
                        ? "${widget.vehicle['no'] ?? widget.vehicle['number'] ?? ''} · ${widget.vehicle['vehicle_type']} - ${widget.vehicle['type']}"
                        : "${widget.vehicle['no'] ?? widget.vehicle['number'] ?? ''} · ${widget.vehicle['type']}";
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicleInfo,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (emission.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            "${context.tr('Emission')}: $emission",
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight:FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    );
                  }
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
            color: isSelected ? Colors.white : Color(0xFF1E293B),
            fontSize: 12.sp,
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

  Widget _invoiceDateCard() {
    final formattedDate =
        "${_selectedInvoiceDate.day.toString().padLeft(2, '0')}-${_selectedInvoiceDate.month.toString().padLeft(2, '0')}-${_selectedInvoiceDate.year}";

    return _card(
      title: 'Invoice Date',
      titleIcon: Icons.calendar_today_rounded,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedInvoiceDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF000080),
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF1E293B),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            _selectedInvoiceDate = picked;
            _updateUi();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: Color(0xFF000080), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF000080).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.tr('Change Date'),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF000080),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Service multi-select card ─────────────────────────────────────────────
  Widget _serviceSelectionCard() {
    final vehicleWheelType = (widget.vehicle['wheel_type'] ?? '').toString().toLowerCase().trim();

    // Filter services based on priced status & wheel_type matching for wheel alignment
    final allPriced = _allServices.where((svc) {
      if (svc['has_price'] != true) return false;

      final slug = (svc['service_type_slug'] ?? '').toString();
      if (slug == 'wheel_alignment') {
        final name = (svc['name'] ?? '').toString().toLowerCase();
        if (vehicleWheelType == 'alloy_wheel') {
          return !name.contains('normal wheel');
        } else if (vehicleWheelType == 'normal_wheel') {
          return !name.contains('alloy wheel') && !name.contains('alignment vehicle');
        }
      }
      return true;
    }).toList();
    
    // Filter services based on category filter
    final pricedServices = allPriced.where((svc) {
      if (_selectedCategoryFilter == 'all') return true;
      return svc['service_type_slug'] == _selectedCategoryFilter;
    }).toList();

    final isWheelTypeMissing = _selectedCategoryFilter == 'wheel_alignment' &&
        (vehicleWheelType.isEmpty || vehicleWheelType == 'none' || (vehicleWheelType != 'alloy_wheel' && vehicleWheelType != 'normal_wheel'));

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
          if (isWheelTypeMissing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('Wheel Type Not Selected'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    context.tr('Wheel type (Alloy Wheel / Normal Wheel) is not set for this vehicle. Please update the wheel type in customer vehicle section to view wheel alignment services.'),
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.amber.shade900),
                  ),
                  SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showWheelTypePickerModal,
                      icon: Icon(Icons.edit, size: 16),
                      label: Text(context.tr('Add / Select Wheel Type'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF000080),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (pricedServices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.tr('No services available'),
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
            )
          else
            Column(
                  children: pricedServices.map((svc) {
                    final id = svc['id']?.toString() ?? '';
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
                              ? Color(0xFF000080).withValues(alpha: 0.05)
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
                                    ? Color(0xFF000080)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? Color(0xFF000080)
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
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
                                      fontSize: 14.sp,
                                      color: hasPrice
                                          ? Color(0xFF1e293b)
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (svc['service_type'] != null)
                                    Text(
                                      context.tr(svc['service_type'] as String),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
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
                                    fontSize: 10.sp,
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
                                  fontSize: 15.sp,
                                  color: Color(0xFF000080),
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
                        color: Colors.grey.shade600, fontSize: 12.sp),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              context.tr('Available Schemes'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12.sp,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF000080).withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF000080).withValues(alpha: 0.12)),
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
                        fontSize: 13.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '$currencySymbol${row.subtotal.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                  ],
                ),
                if (row.effectiveDiscount > 0) ...[
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Discount'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.sp,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        '− $currencySymbol${row.effectiveDiscount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Total'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                    Text(
                      '$currencySymbol${row.total.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.sp,
                        color: Color(0xFF000080),
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
              icon: Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 16),
              label: Text(
                context.tr('Remove Service'),
                style: GoogleFonts.inter(color: Colors.red, fontSize: 12.sp),
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
          color: Colors.blue.shade50.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: const Color(0xFF000080), size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('Service Price'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: const Color(0xFF000080)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.customRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080), fontSize: 15.sp),
              decoration: InputDecoration(
                labelText: context.tr('Service Price'),
                hintText: 'Enter price',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF000080))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) {
                _syncAmountCollected();
                _updateUi();
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.oil_barrel, color: const Color(0xFF000080), size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('Oil Change Odometer Details'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: const Color(0xFF000080)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Odometer & Next Oil Change (KM) inputs (Required)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.odometerController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: '${context.tr("Current Odometer (KM)")} *',
                      hintText: 'e.g. 10000',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.nextOilChangeKmController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
                    decoration: InputDecoration(
                      labelText: '${context.tr("Next Oil Change (KM)")} *',
                      hintText: 'e.g. 15000',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        margin: EdgeInsets.only(top: 12),
        padding: EdgeInsets.all(12),
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
                    SizedBox(width: 8),
                    Text(
                      context.tr('Tyre Details'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.blue.shade900),
                    ),
                  ],
                ),
                Text(
                  '${context.tr("Total Charge")}: $currencySymbol${row.tyreTotalCharge.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.green.shade800),
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
                    margin: EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: Offset(0, 1)),
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
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.blue.shade800),
                            ),
                            if (row.tyreItems.length > 1)
                              IconButton(
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
                                  labelStyle: TextStyle(fontSize: 12.sp),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(context.tr('-- Select Brand --'), style: TextStyle(fontSize: 12.sp)),
                                  ),
                                  ..._tyreBrands.map<DropdownMenuItem<String>>((b) {
                                    return DropdownMenuItem<String>(
                                      value: b['id']?.toString(),
                                      child: Text(b['brand'] as String, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
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
                                  labelStyle: TextStyle(fontSize: 12.sp),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(context.tr('-- Select Size --'), style: TextStyle(fontSize: 12.sp)),
                                  ),
                                  ...filteredTyres.map<DropdownMenuItem<String>>((t) {
                                    final sizeStr = t['size']?.toString() ?? '';
                                    final priceVal = (t['price'] as num?)?.toDouble() ?? 0.0;
                                    final stockVal = t['stock_qty'] ?? 0;
                                    final label = '$sizeStr ($currencySymbol${priceVal.toStringAsFixed(0)} · $stockVal in stock)';

                                    return DropdownMenuItem<String>(
                                      value: t['id']?.toString(),
                                      child: Text(
                                        label,
                                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
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
                                  labelStyle: TextStyle(fontSize: 12.sp),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    Text(context.tr('Price (Autofill)'), style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600)),
                                    SizedBox(height: 2),
                                    Text(
                                      '$currencySymbol${item.unitPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Color(0xFF1e293b)),
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
                                    Text(context.tr('Line Total'), style: TextStyle(fontSize: 10.sp, color: Colors.blue.shade700)),
                                    SizedBox(height: 2),
                                    Text(
                                      '$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
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
                                  labelStyle: TextStyle(fontSize: 12.sp),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  labelStyle: TextStyle(fontSize: 12.sp),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              icon: Icon(Icons.add_circle_outline, size: 18),
              label: Text(context.tr('+ Add Another Tyre Brand / Size'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF000080),
                side: BorderSide(color: Color(0xFF000080)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    } else if (row.isWheelBalancingOrAlignmentCategory) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.indigo.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('Service Price'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.indigo.shade900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.customRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080), fontSize: 15.sp),
              decoration: InputDecoration(
                labelText: context.tr('Service Price'),
                hintText: 'Enter price',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF000080))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) {
                _syncAmountCollected();
                _updateUi();
              },
            ),
            if (row.isWheelAlignmentCategory) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.indigo.shade800, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Wheel Alignment & Balancing Details'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.indigo.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.odometerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: '${context.tr("Current Odometer (KM)")} *',
                        hintText: 'e.g. 10000',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: row.nextAlignmentKmController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                      decoration: InputDecoration(
                        labelText: '${context.tr("Next Alignment Due (KM)")} *',
                        hintText: 'e.g. 15000',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else if (row.serviceCategory == 'smoke_test' || row.serviceCategory == 'pollution_test' || row.serviceName.toLowerCase().contains('smoke') || row.serviceName.toLowerCase().contains('pollution')) {
      final modelName = (widget.vehicle['type'] ?? '').toString().toUpperCase();
      final emission = (widget.vehicle['emission_standard'] ?? '').toString().toUpperCase();
      final combined = '$modelName $emission';
      
      final bs3Keywords = ['BS-1', 'BS-2', 'BS-3', 'BS 1', 'BS 2', 'BS 3', 'BS1', 'BS2', 'BS3', 'BS -1', 'BS -2', 'BS -3'];
      if (!row.isSmokeTestPeriodInitialized) {
        final defaultValidity = bs3Keywords.any((k) => combined.contains(k)) ? 6 : 12;
        row.smokeTestPeriodMonths = defaultValidity;
        row.isSmokeTestPeriodInitialized = true;
      }
      final validityMonths = row.smokeTestPeriodMonths;

      final nextDate = DateTime.now().add(Duration(days: validityMonths == 6 ? 180 : 365));
      final nextDateStr = "${nextDate.day.toString().padLeft(2, '0')}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.year}";
      final reminder1Date = nextDate.subtract(const Duration(days: 15));
      final reminder2Date = nextDate.subtract(const Duration(days: 3));
      String fmtDate(DateTime d) => "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

      return Container(
        margin: EdgeInsets.only(top: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.purple.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('Service Price'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.purple.shade900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.customRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080), fontSize: 15.sp),
              decoration: InputDecoration(
                labelText: context.tr('Service Price'),
                hintText: 'Enter price',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF000080))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) {
                _syncAmountCollected();
                _updateUi();
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: Colors.purple, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Smoke Test Renewal Validity'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.purple.shade900),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: row.smokeTestPeriodMonths == 6 ? 6 : 12,
                      dropdownColor: Colors.purple.shade900,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.white),
                      items: [
                        DropdownMenuItem<int>(
                          value: 6,
                          child: Text(context.tr('6 Months'), style: const TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem<int>(
                          value: 12,
                          child: Text(context.tr('1 Year'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            row.smokeTestPeriodMonths = val;
                            row.isSmokeTestPeriodInitialized = true;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Next Renewal Date
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.purple.shade700),
                  SizedBox(width: 8),
                  Text(
                    "${context.tr('Next Renewal Date')}: ",
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade700),
                  ),
                  Text(
                    nextDateStr,
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                  ),  
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 1st Reminder Date
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined, size: 14, color: Colors.purple.shade700),
                  SizedBox(width: 8),
                  Text(
                    "${context.tr('1st Reminder')}: ",
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade700),
                  ),
                  Text(
                    fmtDate(reminder1Date),
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                  ),
                  SizedBox(width: 6),
                  Text(
                    context.tr('(15 days before)'),
                    style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.purple.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 2nd Reminder Date
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, size: 14, color: Colors.purple.shade700),
                  SizedBox(width: 8),
                  Text(
                    "${context.tr('2nd Reminder')}: ",
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.purple.shade700),
                  ),
                  Text(
                    fmtDate(reminder2Date),
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                  ),
                  SizedBox(width: 6),
                  Text(
                    context.tr('(3 days before)'),
                    style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.purple.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (row.isDetailingCategory) {
      return Container(
        margin: EdgeInsets.only(top: 12),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.blue.shade800, size: 20),
                SizedBox(width: 8),
                Text(
                  context.tr('Service Price'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.blue.shade900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.customRateController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Color(0xFF000080), fontSize: 15.sp),
              decoration: InputDecoration(
                labelText: context.tr('Service Price'),
                hintText: 'Enter price',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF000080))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) {
                _syncAmountCollected();
                _updateUi();
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 20),
                SizedBox(width: 8),
                Text(
                  context.tr('Warranty Details'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.blue.shade900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.warrantyValueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Warranty Period'),
                      hintText: '',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF000080))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => _updateUi(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(context.tr('Month'), style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: row.warrantyUnit == 'month' ? FontWeight.bold : FontWeight.normal)),
                        selected: row.warrantyUnit == 'month',
                        selectedColor: Color(0xFF000080),
                        labelStyle: TextStyle(color: row.warrantyUnit == 'month' ? Colors.white : Colors.black87),
                        onSelected: (sel) {
                          if (sel) {
                            row.warrantyUnit = 'month';
                            _updateUi();
                          }
                        },
                      ),
                      SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(context.tr('Year'), style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: row.warrantyUnit == 'year' ? FontWeight.bold : FontWeight.normal)),
                        selected: row.warrantyUnit == 'year',
                        selectedColor: Color(0xFF000080),
                        labelStyle: TextStyle(color: row.warrantyUnit == 'year' ? Colors.white : Colors.black87),
                        onSelected: (sel) {
                          if (sel) {
                            row.warrantyUnit = 'year';
                            _updateUi();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (row.warrantyValueController.text.trim().isNotEmpty) ...[
              SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final val = int.tryParse(row.warrantyValueController.text.trim()) ?? 0;
                  final unitStr = row.warrantyUnit == 'year' ? (val == 1 ? 'Year' : 'Years') : (val == 1 ? 'Month' : 'Months');
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          "${context.tr('Warranty')}: $val ${context.tr(unitStr)}",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.blue.shade900),
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
    } else if (row.serviceCategory == 'battery_service' || row.serviceCategory == 'battery_change' || row.serviceCategory == 'battery' || row.serviceName.toLowerCase().contains('battery')) {
      return Container(
        margin: EdgeInsets.only(top: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF000080).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFF000080).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.battery_charging_full, color: Color(0xFF000080), size: 20),
                    SizedBox(width: 8),
                    Text(
                      context.tr('Battery Details'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Color(0xFF000080)),
                    ),
                  ],
                ),
                if (row.batteryItems.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      row.batteryItems.clear();
                      _syncAmountCollected();
                      _updateUi();
                    },
                    child: Text(
                      context.tr('Clear'),
                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (row.batteryItems.isEmpty) ...[
              InkWell(
                onTap: () => _openBatterySearchPickerForRow(row),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF000080).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, color: Color(0xFF000080), size: 18),
                      SizedBox(width: 8),
                      Text(
                        context.tr('Select Battery from Master...'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Color(0xFF000080)),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              for (int i = 0; i < row.batteryItems.length; i++) ...[
                Builder(
                  builder: (context) {
                    final item = row.batteryItems[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFF000080).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.displayName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Color(0xFF1e293b)),
                                ),
                              ),
                              IconButton(
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  item.dispose();
                                  row.batteryItems.removeAt(i);
                                  _syncAmountCollected();
                                  _updateUi();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF000080).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('Make: ${item.makeName}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                                if (item.ampereName.isNotEmpty)
                                  Text('•  Ampere: ${item.ampereName}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                                if (item.segmentName.isNotEmpty)
                                  Text('•  Segment: ${item.segmentName}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 75,
                                child: TextFormField(
                                  controller: item.qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: context.tr('Qty *'),
                                    labelStyle: TextStyle(fontSize: 11.sp),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  onChanged: (_) {
                                    _syncAmountCollected();
                                    _updateUi();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: item.warrantyController,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Warranty (Yrs)'),
                                    labelStyle: TextStyle(fontSize: 11.sp),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: item.priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                                  decoration: InputDecoration(
                                    labelText: context.tr('Price ($currencySymbol) *'),
                                    labelStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onChanged: (_) {
                                    _syncAmountCollected();
                                    _updateUi();
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => _openBatterySearchPickerForRow(row),
                                icon: Icon(Icons.swap_horiz, size: 16, color: Color(0xFF000080)),
                                label: Text(context.tr('Change Battery'), style: TextStyle(fontSize: 11.sp, color: Color(0xFF000080), fontWeight: FontWeight.bold)),
                              ),
                              Text(
                                'Line Total: $currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Color(0xFF10b981)),
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
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.teal.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: Colors.teal.shade800, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.tr('Service Price'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Colors.teal.shade900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.customRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080), fontSize: 15.sp),
              decoration: InputDecoration(
                labelText: context.tr('Service Price'),
                hintText: 'Enter price',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF000080))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (_) {
                _syncAmountCollected();
                _updateUi();
              },
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
                  ? Color(0xFF000080).withValues(alpha: 0.05)
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
                  padding: EdgeInsets.all(7),
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
                          fontSize: 13.sp,
                          color: canSelect
                              ? Color(0xFF1e293b)
                              : Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        context.tr(scheme['description'] as String? ?? ''),
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (lockedByOtherRow)
                        Text(
                          context.tr('Already applied to another service'),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
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
                  value: scheme['id']?.toString() ?? '',
                  groupValue: row.selectedScheme?['id']?.toString(),
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
          fontSize: 10.sp,
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
                fontSize: 11.sp,
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
              GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13.sp),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: row.discountController,
            keyboardType:
                TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp),
            decoration: InputDecoration(
              prefixText: '$currencySymbol ',
              contentPadding: EdgeInsets.symmetric(
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
            fontSize: 13.sp,
            color: Color(0xFF000080),
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
                backgroundColor: Color(0xFF000080),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
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
            padding: EdgeInsets.only(top: 6),
            child: Text(row.voucherError!,
                style: GoogleFonts.inter(color: Colors.red, fontSize: 12.sp)),
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
                      fontSize: 12.sp,
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e293b),
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
              final id = tax['id']?.toString() ?? '';
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
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                  ),
                  Text(
                    _rows.isEmpty
                        ? '$currencySymbol 0.00'
                        : '$currencySymbol${(subtotal * percent / 100).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 13.sp, color: Colors.grey.shade700),
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
            if (row.serviceCategory == 'battery_service' || row.serviceCategory == 'battery_change' || row.serviceCategory == 'battery' || row.serviceName.toLowerCase().contains('battery')) ...[
              for (final item in row.batteryItems) ...[
                Builder(
                  builder: (context) {
                    if (item.lineTotal <= 0) return const SizedBox.shrink();
                    final name = item.displayName.isNotEmpty ? item.displayName : 'Battery';
                    final label = '  + Battery ($name x${item.quantity})';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: _summaryRow(
                        label,
                        '+$currencySymbol${item.lineTotal.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF000080),
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
          // Per-trading item lines
          if (_addTradingItems) ...[
            for (final tRow in _tradingRows) ...[
              if (tRow.selectedStockItem != null && !tRow.isOperational) ...[
                _summaryRow(
                  '${tRow.selectedStockItem!['item_name']} (x${tRow.qty})',
                  '$currencySymbol${tRow.netTaxable.toStringAsFixed(2)}',
                ),
                if (tRow.discount > 0)
                  _summaryRow(
                    '  ${context.tr('Item Discount')}',
                    '-$currencySymbol${tRow.discount.toStringAsFixed(2)}',
                    valueColor: Colors.green,
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ],
          // Per-extra lines
          if (_addExtras) ...[
            for (final e in _selectedExtras) ...[
              () {
                final qty = double.tryParse((e['qtyController'] as TextEditingController?)?.text ?? '1') ?? 1.0;
                final rate = double.tryParse((e['rateController'] as TextEditingController?)?.text ?? (e['priceController'] as TextEditingController?)?.text ?? '0') ?? 0.0;
                final remark = (e['remarkController'] as TextEditingController?)?.text.trim() ?? '';
                final lineTotal = qty * rate;
                
                String label = e['extra']['name'] as String;
                if (qty > 1) {
                  label = '$label (x${qty % 1 == 0 ? qty.toInt() : qty})';
                }
                if (remark.isNotEmpty) {
                  label = '$label - $remark';
                }
                return _summaryRow(
                  label,
                  '$currencySymbol${lineTotal.toStringAsFixed(2)}',
                );
              }(),
              const SizedBox(height: 6),
            ],
          ],
          if (_rows.length > 1 || _tradingRows.isNotEmpty || _selectedExtras.isNotEmpty)
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
                  fontSize: 17.sp,
                  color: Color(0xFF1e293b),
                ),
              ),
              Text(
                context.tr('$currencySymbol${total.toStringAsFixed(2)}'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                  color: Color(0xFF000080),
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
              fontSize: 14.sp,
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _amountCollectedController,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
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
                contentPadding: EdgeInsets.symmetric(
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
                      fontSize: 13.sp,
                      color: Color(0xFF1e293b),
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
                      fontSize: 13.sp,
                      color: Color(0xFF1e293b),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _additionalDiscountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.sp),
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
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xFF000080).withValues(alpha: 0.08)
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
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Color(0xFF000080) : Colors.grey.shade700,
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
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Color(0xFF000080).withValues(alpha: 0.08)
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
                  fontSize: 11.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Color(0xFF000080) : Colors.grey.shade700,
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
          : Icon(Icons.check_circle_outline),
      label: Text(
        context.tr('Save Invoice'),
        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15.sp),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF000080),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showStockItemSearchSheet(_TradingItemRow row) {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filteredItems = _availableStockItems.where((item) {
              final name = (item['item_name'] ?? '').toString().toLowerCase();
              final brand = (item['brand'] ?? '').toString().toLowerCase();
              final group = (item['group_name'] ?? '').toString().toLowerCase();
              final subGroup = (item['sub_group_name'] ?? '').toString().toLowerCase();
              return query.isEmpty ||
                  name.contains(query) ||
                  brand.contains(query) ||
                  group.contains(query) ||
                  subGroup.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFF000080)),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('Select Stock Item'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              color: Color(0xFF000080),
                            ),
                          ),
                        ],
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
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('Search item name, brand, group...'),
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
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() {});
                    },
                  ),
                  SizedBox(height: 12),
                  Text(
                    '${filteredItems.length} ${context.tr('items found')}',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No stock items found'),
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isSelected = row.selectedStockItem != null &&
                                  row.selectedStockItem!['id'].toString() == item['id'].toString();
                              final itemName = item['item_name'].toString();
                              final brand = (item['brand'] ?? '').toString();
                              final groupName = (item['group_name'] ?? '').toString();
                              final subGroupName = (item['sub_group_name'] ?? '').toString();
                              final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                              final unitName = (item['unit_name'] ?? 'Pcs').toString();
                              final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                              final marginPercent = (item['profit_margin_percent'] as num?)?.toDouble() ?? 0.0;

                              String categoryText = '';
                              if (groupName.isNotEmpty && subGroupName.isNotEmpty) {
                                categoryText = '$groupName > $subGroupName';
                              } else if (groupName.isNotEmpty) {
                                categoryText = groupName;
                              }

                              return InkWell(
                                onTap: () {
                                  row.selectedStockItem = Map<String, dynamic>.from(item as Map);
                                  row.currentStock = qty;
                                  row.selectedStockItem = Map<String, dynamic>.from(item as Map);
                                  row.currentStock = qty;
                                  row.unitName = unitName;
                                  row.isOperational = false;
                                  if (rate > 0) {
                                    row.rateController.text = rate.toStringAsFixed(2);
                                  } else {
                                    row.rateController.text = '0.00';
                                  }
                                  row.discountController.text = '0.00';


                                  _syncAmountCollected();
                                  _updateUi();
                                  Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFF000080).withOpacity(0.06) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF000080).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.inventory_2_outlined, color: Color(0xFF000080), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    itemName,
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14.sp,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                if (brand.isNotEmpty) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      brand,
                                                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (categoryText.isNotEmpty) ...[
                                              SizedBox(height: 2),
                                              Text(
                                                categoryText,
                                                style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600),
                                              ),
                                            ],
                                            SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: qty > 0 ? Colors.green.shade50 : Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: qty > 0 ? Colors.green.shade300 : Colors.orange.shade300, width: 0.5),
                                                  ),
                                                  child: Text(
                                                    '${context.tr('Stock')}: ${qty.toStringAsFixed(0)} $unitName',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w600,
                                                      color: qty > 0 ? Colors.green.shade800 : Colors.orange.shade800,
                                                    ),
                                                  ),
                                                ),
                                                if (rate > 0) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '₹${rate.toStringAsFixed(2)}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF000080),
                                                    ),
                                                  ),
                                                ],
                                                if (marginPercent > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.blue.shade300, width: 0.5),
                                                    ),
                                                    child: Text(
                                                      '+${marginPercent.toStringAsFixed(0)}% margin',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.sp,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.blue.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: Color(0xFF000080), size: 20),
                                    ],
                                  ),
                                ),
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

  Widget _staffSelectionCard() {
    return _card(
      title: 'Add Staffs',
      titleWidget: Row(
        children: [
          Checkbox(
            value: _addStaffs,
            activeColor: const Color(0xFF000080),
            onChanged: (val) {
              _addStaffs = val ?? false;
              _updateUi();
            },
          ),
          Expanded(
            child: Text(
              context.tr('Add Staffs'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
                color: const Color(0xFF000080),
              ),
            ),
          ),
          if (_addStaffs)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF000080), size: 24),
              onPressed: _showStaffSearchSheet,
              tooltip: context.tr('+ Select Staff'),
            ),
        ],
      ),
      child: !_addStaffs
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _showStaffSearchSheet,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: Text(context.tr('+ Select Staffs')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (_selectedStaffs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedStaffs.map((staff) {
                      final staffName = (staff['name'] ?? '').toString();
                      final empId = (staff['employee_id'] ?? '').toString();
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: const Color(0xFF000080),
                          child: Text(
                            staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                          ),
                        ),
                        label: Text(
                          empId.isNotEmpty ? '$staffName ($empId)' : staffName,
                          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        ),
                        backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.red),
                        onDeleted: () {
                          _selectedStaffs.removeWhere((s) => s['id'] == staff['id']);
                          _updateUi();
                        },
                        side: BorderSide(color: const Color(0xFF000080).withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
    );
  }

  void _showStaffSearchSheet() {
    final searchController = TextEditingController();
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
            final query = searchController.text.trim().toLowerCase();
            final filteredStaffs = _availableStaffs.where((s) {
              final name = (s['name'] ?? '').toString().toLowerCase();
              final empId = (s['employee_id'] ?? '').toString().toLowerCase();
              final branch = (s['branch_name'] ?? '').toString().toLowerCase();
              return query.isEmpty ||
                  name.contains(query) ||
                  empId.contains(query) ||
                  branch.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: Color(0xFF000080)),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('Select Branch Staffs'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                              color: const Color(0xFF000080),
                            ),
                          ),
                        ],
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
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('Search staff name or ID...'),
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
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${filteredStaffs.length} ${context.tr('staff members found')}',
                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredStaffs.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No staff members found for this branch'),
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredStaffs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final staff = filteredStaffs[index];
                              final staffId = staff['id'].toString();
                              final isSelected = _selectedStaffs.any((s) => s['id'].toString() == staffId);
                              final staffName = (staff['name'] ?? '').toString();
                              final empId = (staff['employee_id'] ?? '').toString();
                              final branchName = (staff['branch_name'] ?? '').toString();

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: const Color(0xFF000080),
                                title: Text(
                                  staffName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp),
                                ),
                                subtitle: Text(
                                  empId.isNotEmpty ? '$empId · $branchName' : branchName,
                                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: const Color(0xFF000080).withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: const Color(0xFF000080), size: 20),
                                ),
                                onChanged: (bool? checked) {
                                  if (checked == true) {
                                    if (!isSelected) {
                                      _selectedStaffs.add(staff);
                                    }
                                  } else {
                                    _selectedStaffs.removeWhere((s) => s['id'].toString() == staffId);
                                  }
                                  setModalState(() {});
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

  Widget _tradingItemsCard() {
    return _card(
      title: 'Stock Items',
      titleWidget: Row(
        children: [
          Checkbox(
            value: _addTradingItems,
            activeColor: const Color(0xFF000080),
            onChanged: (val) {
              _addTradingItems = val ?? false;
              if (_addTradingItems && _tradingRows.isEmpty) {
                _tradingRows.insert(0, _TradingItemRow());
              }
              _syncAmountCollected();
              _updateUi();
            },
          ),
          Expanded(
            child: Text(
              context.tr('Add Stock Items'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 14.sp,
                color: Color(0xFF000080),
              ),
            ),
          ),
          if (_addTradingItems)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF000080), size: 26),
              onPressed: () {
                _tradingRows.insert(0, _TradingItemRow());
                _updateUi();
              },
              tooltip: context.tr('+ Add Stock Item'),
            ),
        ],
      ),
      child: !_addTradingItems
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _tradingRows.insert(0, _TradingItemRow());
                    _updateUi();
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: Text(context.tr('+ Add Stock Item')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _tradingRows.length; i++) ...[
                  _tradingItemRowWidget(_tradingRows[i], i),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _tradingItemRowWidget(_TradingItemRow row, int index) {
    final bool isTrading = (row.selectedStockItem?['is_trading'] as bool?) ?? true;
    final bool isOperationalItem = (row.selectedStockItem?['is_operational'] as bool?) ?? false;
    final bool isDualUse = isTrading && isOperationalItem;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: row.isOperational ? Colors.amber.shade50.withOpacity(0.5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: row.isOperational ? Colors.amber.shade300 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showStockItemSearchSheet(row),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('1. Select Stock Item'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF000080)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF000080), size: 20),
                    ),
                    child: Text(
                      row.selectedStockItem != null
                          ? '${row.selectedStockItem!['item_name']}${row.selectedStockItem!['brand'] != null && row.selectedStockItem!['brand'].toString().isNotEmpty ? " (${row.selectedStockItem!['brand']})" : ""}'
                          : context.tr('Tap to search & select stock item...'),
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: row.selectedStockItem != null ? FontWeight.w700 : FontWeight.w400,
                        color: row.selectedStockItem != null ? Colors.black87 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  row.dispose();
                  _tradingRows.removeAt(index);
                  _syncAmountCollected();
                  _updateUi();
                },
              ),
            ],
          ),
          if (row.selectedStockItem != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                row.isOperational = !row.isOperational;
                if (row.isOperational) {
                  row.rateController.text = '0.00';
                  row.discountController.text = '0.00';
                } else {
                  final rate = (row.selectedStockItem!['rate'] as num?)?.toDouble() ?? 0.0;
                  if (rate > 0) row.rateController.text = rate.toStringAsFixed(2);
                }
                _syncAmountCollected();
                _updateUi();
              },
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: row.isOperational,
                      activeColor: const Color(0xFF000080),
                      onChanged: (val) {
                        row.isOperational = val ?? false;
                        if (row.isOperational) {
                          row.rateController.text = '0.00';
                          row.discountController.text = '0.00';
                        } else {
                          final rate = (row.selectedStockItem!['rate'] as num?)?.toDouble() ?? 0.0;
                          if (rate > 0) row.rateController.text = rate.toStringAsFixed(2);
                        }
                        _syncAmountCollected();
                        _updateUi();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Operational / Internal Use'),
                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Color(0xFF000080)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (row.isOperational) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.amber.shade900, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('Operational Consumable'),
                      style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Stock: ${row.currentStock.toStringAsFixed(1)} ${row.unitName}',
                      style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Qty Consumed'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) {
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.rateController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Rate'),
                      prefixText: '$currencySymbol ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) {
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Current Stock'),
                        style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.grey.shade700),
                      ),
                      Text(
                        '${row.currentStock.toStringAsFixed(1)} ${row.unitName}',
                        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Qty'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) {
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Discount'),
                      prefixText: '$currencySymbol ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (_) {
                      _syncAmountCollected();
                      _updateUi();
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Net Taxable:'),
                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade800),
                ),
                Text(
                  '$currencySymbol ${row.netTaxable.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Color(0xFF000080)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _extrasCard() {
    return _card(
      title: 'Add Extras',
      titleWidget: Row(
        children: [
          Checkbox(
            value: _addExtras,
            activeColor: const Color(0xFF000080),
            onChanged: (val) {
              _addExtras = val ?? false;
              _syncAmountCollected();
              _updateUi();
            },
          ),
          Text(
            context.tr('Add Extras'),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
              color: Color(0xFF000080),
            ),
          ),
        ],
      ),
      child: !_addExtras
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedExtras.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.tr('No extras added yet'),
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._selectedExtras.map((extraMap) {
                    final extra = extraMap['extra'] as Map<String, dynamic>;
                    final name = extra['name'] as String;
                    final categoryName = (extra['service_type_name'] ?? '').toString();

                    final qtyController = extraMap['qtyController'] as TextEditingController? ??
                        (extraMap['qtyController'] = TextEditingController(text: '1')
                          ..addListener(() {
                            _syncAmountCollected();
                            _updateUi();
                          }));
                    final rateController = extraMap['rateController'] as TextEditingController? ??
                        (extraMap['rateController'] = (extraMap['priceController'] as TextEditingController? ?? TextEditingController(text: '0'))
                          ..addListener(() {
                            _syncAmountCollected();
                            _updateUi();
                          }));
                    final remarkController = extraMap['remarkController'] as TextEditingController? ??
                        (extraMap['remarkController'] = TextEditingController()
                          ..addListener(() {
                            _updateUi();
                          }));

                    final qty = double.tryParse(qtyController.text) ?? 1.0;
                    final rate = double.tryParse(rateController.text) ?? 0.0;
                    final itemTotal = qty * rate;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name & Category + Total & Delete button
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.sp,
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
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF000080),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Item Line Total Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF000080).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$currencySymbol ${itemTotal.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: const Color(0xFF000080),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  _selectedExtras.remove(extraMap);
                                  _syncAmountCollected();
                                  _updateUi();

                                  final Set<TextEditingController> controllersToDispose = {};
                                  if (extraMap['qtyController'] is TextEditingController) {
                                    controllersToDispose.add(extraMap['qtyController'] as TextEditingController);
                                  }
                                  if (extraMap['rateController'] is TextEditingController) {
                                    controllersToDispose.add(extraMap['rateController'] as TextEditingController);
                                  }
                                  if (extraMap['remarkController'] is TextEditingController) {
                                    controllersToDispose.add(extraMap['remarkController'] as TextEditingController);
                                  }
                                  if (extraMap['priceController'] is TextEditingController) {
                                    controllersToDispose.add(extraMap['priceController'] as TextEditingController);
                                  }
                                  for (final c in controllersToDispose) {
                                    c.dispose();
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Inputs Row: Qty & Rate
                          Row(
                            children: [
                              // Qty Field
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Qty'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: qtyController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.sp),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (_) {
                                        _syncAmountCollected();
                                        _updateUi();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Rate Field
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Rate'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: rateController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.sp),
                                      decoration: InputDecoration(
                                        prefixText: '$currencySymbol ',
                                        prefixStyle: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade700),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onChanged: (_) {
                                        _syncAmountCollected();
                                        _updateUi();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Remark Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Remark'),
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: remarkController,
                                style: GoogleFonts.inter(fontSize: 12.sp),
                                decoration: InputDecoration(
                                  hintText: context.tr('Add remark / note (optional)'),
                                  hintStyle: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade400),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) {
                                  _updateUi();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showAddExtraSelector,
                  icon: Icon(Icons.add, size: 16),
                  label: Text(context.tr('Add Extra Item')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF000080),
                    elevation: 0,
                    side: BorderSide(color: Color(0xFF000080)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _remarksCard() {
    return _card(
      title: 'Add Remarks',
      titleWidget: Row(
        children: [
          Checkbox(
            value: _addRemarks,
            activeColor: const Color(0xFF000080),
            onChanged: (val) {
              _addRemarks = val ?? false;
              _updateUi();
            },
          ),
          Text(
            context.tr('Add Remarks'),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
              color: Color(0xFF000080),
            ),
          ),
        ],
      ),
      child: !_addRemarks
          ? const SizedBox.shrink()
          : TextField(
              controller: _remarksController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: context.tr('Enter invoice remarks / notes...'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
    );
  }

  Widget _customRemindersCard() {
    final bool isReminderLocked = _hasWheelAlignmentService || _hasDetailingService || _hasOilChangeService;
    if (isReminderLocked) {
      _addCustomReminders = true;
      if (_reminderDaysControllers.isEmpty) {
        _reminderDaysControllers.add(TextEditingController(text: ''));
      }
    }

    return _card(
      title: 'Add Custom Reminders',
      titleWidget: Row(
        children: [
          Checkbox(
            value: _addCustomReminders,
            activeColor: const Color(0xFF000080),
            onChanged: isReminderLocked ? null : (val) {
              _addCustomReminders = val ?? false;
              if (_addCustomReminders && _reminderDaysControllers.isEmpty) {
                _reminderDaysControllers.add(TextEditingController(text: ''));
              }
              _updateUi();
            },
          ),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 12.sp,
                color: Color(0xFF000080),
              ),
              children: [
                TextSpan(text: context.tr('Add Custom Reminders')),
                if (isReminderLocked)
                  TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      child: !_addCustomReminders
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // if (isWheelLocked)
                //   Container(
                //     margin: const EdgeInsets.only(bottom: 12),
                //     padding: const EdgeInsets.all(10),
                //     decoration: BoxDecoration(
                //       color: Colors.blue.shade50,
                //       borderRadius: BorderRadius.circular(8),
                //       border: Border.all(color: Colors.blue.shade200),
                //     ),
                //     child: Row(
                //       children: [
                //         const Icon(Icons.notifications_active_outlined, color: Colors.blue, size: 18),
                //         const SizedBox(width: 8),
                //         Expanded(
                //           child: Text(
                //             context.tr('Custom reminders automatically enabled for Wheel Alignment & Balancing.'),
                //             style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                for (int i = 0; i < _reminderDaysControllers.length; i++) ...[
                  _reminderRowWidget(i),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    _reminderDaysControllers.add(TextEditingController(text: '120'));
                    _updateUi();
                  },
                  icon: const Icon(Icons.add_alarm, size: 16),
                  label: Text(context.tr('+ Add Reminder Days')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _reminderRowWidget(int index) {
    final controller = _reminderDaysControllers[index];
    final days = int.tryParse(controller.text.trim()) ?? 0;
    final scheduledDate = DateTime.now().add(Duration(days: days));
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = days > 0
        ? '${scheduledDate.day} ${monthNames[scheduledDate.month - 1]} ${scheduledDate.year}'
        : 'Invalid days';

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: context.tr('Reminder Days'),
                hintText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => _updateUi(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF000080).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Send Date'),
                  style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.grey.shade600),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Color(0xFF000080)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              controller.dispose();
              _reminderDaysControllers.removeAt(index);
              _updateUi();
            },
          ),
        ],
      ),
    );
  }



  // ── Battery Search Picker for Service Row ─────────────────────────────────
  void _openBatterySearchPickerForRow(_ServiceRow row) {
    final searchCtrl = TextEditingController();
    List<dynamic> localList = List.from(_batteries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
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
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('Select Battery'),
                          style: GoogleFonts.inter(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000080),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: context.tr('Search make, ampere, segment...'),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (query) {
                        setModalState(() {
                          final q = query.toLowerCase();
                          localList = _batteries.where((b) {
                            final name = (b['display_name'] ?? '').toString().toLowerCase();
                            final make = (b['make_name'] ?? '').toString().toLowerCase();
                            final amp = (b['ampere_name'] ?? '').toString().toLowerCase();
                            final seg = (b['segment_name'] ?? '').toString().toLowerCase();
                            return name.contains(q) || make.contains(q) || amp.contains(q) || seg.contains(q);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: localList.isEmpty
                          ? Center(
                              child: Text(
                                context.tr('No batteries found'),
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            )
                          : ListView.separated(
                              itemCount: localList.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final item = localList[idx];
                                final displayName = item['display_name'] ?? '';
                                final warranty = item['warranty_years'] ?? 1.0;
                                final price = (item['price'] as num?)?.toDouble() ?? 0.0;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(0xFF000080).withValues(alpha: 0.1),
                                    child: Icon(Icons.battery_charging_full, color: Color(0xFF000080)),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Warranty: $warranty Yrs · Stock: ${item['stock_qty'] ?? 0}',
                                    style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                                  ),
                                  trailing: Text(
                                    '$currencySymbol${price.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                      color: Color(0xFF10b981),
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _showBatteryPriceEditDialogForRow(row, item);
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

  void _showBatteryPriceEditDialogForRow(_ServiceRow row, Map<String, dynamic> battery) {
    final defaultPrice = (battery['price'] as num?)?.toDouble() ?? 0.0;
    final priceCtrl = TextEditingController(text: defaultPrice > 0 ? defaultPrice.toStringAsFixed(2) : '0.00');

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.battery_charging_full, color: Color(0xFF000080)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  battery['display_name'] ?? 'Battery Details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF000080).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Make: ${battery['make_name'] ?? ''}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    Text('Ampere: ${battery['ampere_name'] ?? ''}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    Text('Segment: ${battery['segment_name'] ?? ''}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    Text('Warranty: ${battery['warranty_years'] ?? 1.0} Years', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    Text('Default Price: $currencySymbol${defaultPrice.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Color(0xFF000080))),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('Battery Price ($currencySymbol) - Editable:', style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Color(0xFF000080))),
              SizedBox(height: 6),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp, color: Color(0xFF000080)),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Color(0xFF000080))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final finalPrice = double.tryParse(priceCtrl.text) ?? defaultPrice;
                Navigator.pop(dlgCtx);

                for (final item in row.batteryItems) {
                  item.dispose();
                }
                row.batteryItems.clear();

                final bRow = _BatteryItemRow(
                  selectedBatteryId: battery['id']?.toString(),
                  makeName: battery['make_name']?.toString() ?? '',
                  ampereName: battery['ampere_name']?.toString() ?? '',
                  segmentName: battery['segment_name']?.toString() ?? '',
                  warrantyYears: (battery['warranty_years'] as num?)?.toDouble() ?? 1.0,
                  initialPrice: finalPrice,
                );

                bRow.priceController.addListener(() {
                  _syncAmountCollected();
                  _updateUi();
                });

                row.batteryItems.add(bRow);
                _syncAmountCollected();
                _updateUi();
              },
              icon: Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
              label: Text(context.tr('Confirm Battery'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF000080),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
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
                          fontSize: 16.sp,
                          color: Color(0xFF000080),
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
                  SizedBox(height: 10),
                  if (categoryNames.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              context.tr('All'),
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: modalCategoryFilter == 'all' ? Colors.white : Color(0xFF1E293B),
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
                                    fontSize: 12.sp,
                                    color: isSel ? Colors.white : Color(0xFF1E293B),
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
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    margin: EdgeInsets.only(top: 8, bottom: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF000080).withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      catName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp,
                                        color: Color(0xFF000080),
                                      ),
                                    ),
                                  ),
                                  ...catItems.map((ext) {
                                    final name = ext['name'] ?? '';
                                    final catLabel = ext['service_type_name'] ?? '';
                                    return ListTile(
                                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      leading: CircleAvatar(
                                        backgroundColor: Color(0xFF000080).withValues(alpha: 0.08),
                                        child: Icon(Icons.stars, color: Color(0xFF000080), size: 18),
                                      ),
                                      title: Text(
                                        name,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.sp),
                                      ),
                                      subtitle: catLabel.isNotEmpty
                                          ? Text(
                                              catLabel,
                                              style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600),
                                            )
                                          : null,
                                      trailing: Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF000080).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.add, color: Color(0xFF000080), size: 16),
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
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Product'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
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
                                fontSize: 11.sp,
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
                                selectedTileColor: Color(0xFF000080).withValues(alpha: 0.08),
                                leading: CircleAvatar(
                                  backgroundColor: isSelected ? Color(0xFF000080) : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.oil_barrel,
                                    size: 18,
                                    color: isSelected ? Colors.white : Color(0xFF000080),
                                  ),
                                ),
                                title: Text(
                                  key,
                                  style: GoogleFonts.inter(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                subtitle: Text(
                                  '${variants.length} volume variant(s)',
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: Color(0xFF000080))
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
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Select Oil Filter'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16.sp),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
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
                  SizedBox(height: 12),
                  if (row.selectedOilFilterId != null) ...[
                    ListTile(
                      leading: Icon(Icons.clear_all, color: Colors.red),
                      title: Text(
                        context.tr('Clear Filter Selection'),
                        style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13.sp),
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
                                    fontSize: 14.sp,
                                  ),
                                ),
                                subtitle: Text(
                                  'Price: ${CountryConfig.currencySymbol}${price.toStringAsFixed(2)}  •  Lifespan: $km KM',
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: Colors.blue)
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
    Widget? titleWidget,
    String? badge,
    Color? badgeColor,
    IconData? titleIcon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                child: titleWidget ??
                    Text(
                      context.tr(title),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                        color: Color(0xFF000080),
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
                      fontSize: 11.sp,
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
            color: isBold ? Color(0xFF1e293b) : Colors.grey.shade600,
            fontSize: 13.sp,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13.sp,
            color: valueColor ?? Color(0xFF1e293b),
          ),
        ),
      ],
    );
  }
}
