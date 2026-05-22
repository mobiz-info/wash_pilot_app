import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
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
      TextEditingController(text: '0.00');

  _ServiceRow({required this.service});

  double get rate => (service['rate'] as num).toDouble();

  double get effectiveDiscount {
    if (selectedScheme != null) return schemeDiscount;
    return double.tryParse(discountController.text) ?? 0.0;
  }

  double get lineTotal => (rate - effectiveDiscount).clamp(0.0, double.infinity);

  String get serviceId => service['id'] as String;
  String get serviceName => service['name'] as String;

  void dispose() {
    voucherController.dispose();
    discountController.dispose();
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
      return '₹';
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

  // Selected service rows (each row = one service line)
  final List<_ServiceRow> _rows = [];

  // Amount collected
  final _amountCollectedController = TextEditingController(text: '0.00');

  // ── Computed totals ──────────────────────────────────────────────────────
  double get totalServicesAmount => _rows.fold(0.0, (s, r) => s + r.rate);
  double get totalDiscount => _rows.fold(0.0, (s, r) => s + r.effectiveDiscount);
  double get subtotal => (totalServicesAmount - totalDiscount).clamp(0.0, double.infinity);
  double get taxAmount {
    double t = 0;
    for (final tax in _availableTaxes) {
      if (_selectedTaxIds.contains(tax['id'] as String)) {
        t += subtotal * ((tax['percent'] as num).toDouble() / 100);
      }
    }
    return t;
  }

  double get total => subtotal + taxAmount;

  List<Map<String, dynamic>> get selectedTaxes => _availableTaxes
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
      .toList();

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
      setState(() {
        if (svcRes['success'] == true) {
          _allServices = svcRes['services'] ?? [];
          final rawTaxes = svcRes['taxes'] as List<dynamic>? ?? [];
          _availableTaxes =
              rawTaxes.map((t) => Map<String, dynamic>.from(t as Map)).toList();
          _selectedTaxIds =
              _availableTaxes.map((t) => t['id'] as String).toSet();
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
    _amountCollectedController.text = total.toStringAsFixed(2);
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
    } else if (st == 'Quantity' && scheme['is_eligible'] == true) {
      setState(() => row.schemeDiscount = row.rate);
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
      _snack('Please select at least one service', isError: true);
      return;
    }

    // Validate Voucher schemes
    for (final row in _rows) {
      if (row.selectedScheme != null &&
          row.selectedScheme!['scheme_type'] == 'Voucher' &&
          row.validatedVoucherId == null) {
        _snack(
          'Please validate the voucher for "${row.serviceName}"',
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

      final services = _rows
          .map((r) => {
                'id': r.serviceId,
                'name': r.serviceName,
                'rate': r.rate,
                'discount': r.effectiveDiscount,
              })
          .toList();

      final invoiceData = {
        'customer_id': widget.customer['id'],
        'vehicle_id': widget.vehicle['id'],
        'subtotal': subtotal,
        'discount': totalDiscount,
        'tax_amount': taxAmount,
        'total': total,
        'amount_collected':
            double.tryParse(_amountCollectedController.text) ?? 0.0,
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
          'Create Invoice',
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
                  if (_rows.isNotEmpty) ...[
                    _billSummary(),
                    const SizedBox(height: 16),
                    _amountCollectedField(),
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
                Text(
                  '${widget.vehicle['no']} · ${widget.vehicle['type']}',
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

  // ── Service multi-select card ─────────────────────────────────────────────
  Widget _serviceSelectionCard() {
    return _card(
      title: 'Select Services',
      badge: _rows.isEmpty ? null : '${_rows.length} selected',
      badgeColor: const Color(0xFF000080),
      child: _allServices.isEmpty
          ? Center(
              child: Text(
                'No services available',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            )
          : Column(
              children: _allServices.map((svc) {
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
                                name,
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
                                  svc['service_type'] as String,
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
                              'No price',
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
                    'No schemes available for this service',
                    style: GoogleFonts.inter(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Available Schemes',
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
                  'Line Total',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF1e293b),
                  ),
                ),
                if (row.effectiveDiscount > 0)
                  Text(
                    '$currencySymbol${row.rate.toStringAsFixed(2)} − $currencySymbol${row.effectiveDiscount.toStringAsFixed(2)} = ',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                Text(
                  '$currencySymbol${row.lineTotal.toStringAsFixed(2)}',
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
                'Remove Service',
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

  // ── Scheme chip (compact selection) ──────────────────────────────────────
  Widget _schemeChip(_ServiceRow row, Map<String, dynamic> scheme) {
    final isSelected = row.selectedScheme?['id'] == scheme['id'];
    final schemeType = scheme['scheme_type'] as String;
    final isEligible = scheme['is_eligible'] as bool? ?? true;
    final visitsCount = scheme['visits_count'] as int? ?? 0;
    final paidVisits = scheme['paid_visits'] as int? ?? 1;

    // Disable quantity scheme if another row already uses it
    final lockedByOtherRow = schemeType == 'Quantity' &&
        !isSelected &&
        _quantitySchemeUsedId == scheme['id'];

    final canSelect = isEligible && !lockedByOtherRow;

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
                        scheme['name'] as String,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: canSelect
                              ? const Color(0xFF1e293b)
                              : Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        scheme['description'] as String? ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (lockedByOtherRow)
                        Text(
                          'Already applied to another service',
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
                        ? (lockedByOtherRow ? 'Used' : 'FREE')
                        : 'Need ${(paidVisits - visitsCount).clamp(0, paidVisits)} more',
                    isEligible && !lockedByOtherRow ? Colors.green : Colors.orange,
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
              'Progress: $current / $target washes',
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
          'Manual Discount',
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
          'Enter Voucher Number',
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
                  hintText: 'Enter voucher number',
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
                  : Text('Apply',
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
      title: 'Taxes',
      child: Column(
        children: _availableTaxes.map((tax) {
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
                  '$name (${percent.toStringAsFixed(1)}%)',
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
        }).toList(),
      ),
    );
  }

  // ── Bill summary ──────────────────────────────────────────────────────────
  Widget _billSummary() {
    final selectedTaxRows = _availableTaxes
        .where((t) => _selectedTaxIds.contains(t['id'] as String))
        .map((t) {
          final name = t['name'] as String;
          final pct = (t['percent'] as num).toDouble();
          return MapEntry(name, subtotal * pct / 100);
        })
        .toList();

    return _card(
      title: 'Bill Summary',
      child: Column(
        children: [
          // Per-service lines
          for (final row in _rows) ...[
            _summaryRow(row.serviceName, '$currencySymbol${row.rate.toStringAsFixed(2)}'),
            if (row.effectiveDiscount > 0) ...[
              const SizedBox(height: 4),
              _summaryRow(
                row.selectedScheme != null
                    ? '  Scheme Discount (${row.serviceName})'
                    : '  Manual Discount (${row.serviceName})',
                '-$currencySymbol${row.effectiveDiscount.toStringAsFixed(2)}',
                valueColor: Colors.green,
              ),
            ],
            const SizedBox(height: 6),
          ],
          if (_rows.length > 1)
            _summaryRow(
              'Services Subtotal',
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
                'Total Amount',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF1e293b),
                ),
              ),
              Text(
                '$currencySymbol${total.toStringAsFixed(2)}',
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
            'Collected',
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
        'Save Invoice',
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
                  title,
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
