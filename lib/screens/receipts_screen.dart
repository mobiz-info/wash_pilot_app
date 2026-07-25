import 'dart:io';

import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final _loading = ValueNotifier<bool>(true);
  final _error = ValueNotifier<String>('');
  final _search = ValueNotifier<String>('');
  final _receipts = ValueNotifier<List<dynamic>>([]);
  final _totalCollected = ValueNotifier<double>(0);
  late final ValueNotifier<DateTime?> _fromDate;
  late final ValueNotifier<DateTime?> _toDate;
  final _branches = ValueNotifier<List<dynamic>>([]);
  final _selectedBranchId = ValueNotifier<String?>(null);
  final _selectedPaymentMode = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = ValueNotifier<DateTime?>(DateTime(now.year, now.month, now.day));
    _toDate = ValueNotifier<DateTime?>(DateTime(now.year, now.month, now.day));
    _loadBranches();
    _fetchReceipts();
  }

  @override
  void dispose() {
    _loading.dispose();
    _error.dispose();
    _search.dispose();
    _receipts.dispose();
    _totalCollected.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    _branches.dispose();
    _selectedBranchId.dispose();
    _selectedPaymentMode.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate.value ?? DateTime.now())
        : (_toDate.value ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF000080),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    if (isFrom) {
      _fromDate.value = picked;
      if (_toDate.value != null && _toDate.value!.isBefore(picked)) _toDate.value = picked;
    } else {
      _toDate.value = picked;
      if (_fromDate.value != null && _fromDate.value!.isAfter(picked)) _fromDate.value = picked;
    }
    _fetchReceipts();
  }

  Future<void> _fetchReceipts() async {
    _loading.value = true;
    _error.value = '';

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      _error.value = 'Not authenticated';
      _loading.value = false;
      return;
    }

    try {
      final res = await ApiService.getReceiptList(
        token,
        fromDate: _fromDate.value != null ? _formatApiDate(_fromDate.value!) : null,
        toDate: _toDate.value != null ? _formatApiDate(_toDate.value!) : null,
        branchId: _selectedBranchId.value,
        paymentMode: _selectedPaymentMode.value,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        _receipts.value = res['receipts'] ?? [];
        _totalCollected.value =
            double.tryParse(res['total_collected']?.toString() ?? '0') ?? 0;
      } else {
        _error.value = res['message'] ?? 'Failed to load receipts';
      }
      _loading.value = false;
    } catch (e) {
      if (!mounted) return;
      _error.value = 'Network error: $e';
      _loading.value = false;
    }
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin || auth.token == null) return;

    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (!mounted || res['success'] != true) return;
      _branches.value = res['branches'] ?? [];
    } catch (_) {
      // Branch filter is optional; receipts can still load all branches.
    }
  }

  List<dynamic> get _filteredReceipts {
    final q = _search.value.trim().toLowerCase();
    if (q.isEmpty) return _receipts.value;

    return _receipts.value.where((item) {
      final receipt = item as Map;
      final searchable = [
        _value(receipt['receipt_number']),
        _nested(receipt, 'invoice', 'invoice_number'),
        _nested(receipt, 'customer', 'name'),
        _nested(receipt, 'customer', 'phone'),
        _nested(receipt, 'vehicle', 'number'),
      ].join(' ').toLowerCase();
      return searchable.contains(q);
    }).toList();
  }

  String _value(dynamic value) => value?.toString() ?? '';

  String _nested(Map data, String parent, String key) {
    final value = data[parent];
    if (value is Map) return _value(value[key]);
    return '';
  }

  double _amount(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0;

  String _formatAmount(dynamic value) => _amount(value).toStringAsFixed(2);

  String _formatDate(String raw) {
    try {
      final date = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String _paymentMode(String value) {
    if (value.isEmpty) return 'Cash';
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _shareReceipt(Map<String, dynamic> receipt) async {
    try {
      final pdf = pw.Document();
      final receiptNo = _value(receipt['receipt_number']);
      final invoiceNo = _nested(receipt, 'invoice', 'invoice_number');
      final customerName = _nested(receipt, 'customer', 'name');
      final customerPhone = _nested(receipt, 'customer', 'phone');
      final vehicleNumber = _nested(receipt, 'vehicle', 'number');
      final vehicleModel = _nested(receipt, 'vehicle', 'model');
      final paymentMode = _paymentMode(_value(receipt['payment_mode']));

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        receiptNo,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        '${_formatDate(_value(receipt['date']))} ${_value(receipt['time'])}',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RECEIVED FROM',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customerName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        customerPhone,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'VEHICLE',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        vehicleNumber,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        vehicleModel,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 28),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _pdfRow('Invoice', '#$invoiceNo'),
                    pw.SizedBox(height: 8),
                    _pdfRow('Payment Mode', paymentMode),
                    pw.SizedBox(height: 8),
                    _pdfRow(
                      'Amount Received',
                      '${CountryConfig.currencySymbol}${_formatAmount(receipt['amount'])}',
                      bold: true,
                    ),
                    pw.SizedBox(height: 8),
                    _pdfRow(
                      'Balance',
                      '${CountryConfig.currencySymbol}${_formatAmount((receipt['invoice'] as Map?)?['balance'])}',
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Thank you!',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$receiptNo.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Receipt $receiptNo');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error: $e')), backgroundColor: Colors.red),
      );
    }
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: bold ? 16 : 12,
            color: bold ? PdfColors.indigo900 : PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _loading,
      builder: (context, loading, _) => ValueListenableBuilder<String>(
        valueListenable: _error,
        builder: (context, errorMsg, _) => ValueListenableBuilder<String>(
          valueListenable: _search,
          builder: (context, searchVal, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _receipts,
            builder: (context, receiptsList, _) => ValueListenableBuilder<double>(
              valueListenable: _totalCollected,
              builder: (context, totalCollectedVal, _) {
                final filtered = _filteredReceipts;

                return Scaffold(
                  backgroundColor: const Color(0xFFF8FAFC),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    title: Text(
                      context.tr('Receipts'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _fetchReceipts,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      Container(
                        color: const Color(0xFF000080),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ValueListenableBuilder<DateTime?>(
                                    valueListenable: _fromDate,
                                    builder: (context, fromDateVal, _) => _datePicker(
                                      label: 'From',
                                      date: fromDateVal,
                                      isFrom: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ValueListenableBuilder<DateTime?>(
                                    valueListenable: _toDate,
                                    builder: (context, toDateVal, _) => _datePicker(
                                      label: 'To',
                                      date: toDateVal,
                                      isFrom: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: _fetchReceipts,
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.search,
                                      color: Color(0xFF000080),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (context.watch<AuthProvider>().isCompanyAdmin) ...[
                              const SizedBox(height: 12),
                              ValueListenableBuilder<String?>(
                                valueListenable: _selectedBranchId,
                                builder: (context, branchId, _) => _branchDropdown(branchId),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ValueListenableBuilder<String?>(
                              valueListenable: _selectedPaymentMode,
                              builder: (context, paymentModeVal, _) => _paymentModeDropdown(paymentModeVal),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: TextField(
                          onChanged: (value) => _search.value = value,
                          decoration: InputDecoration(
                            hintText: context.tr('Search receipt, customer, invoice or vehicle'),
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (loading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFF000080)),
                          ),
                        )
                      else if (errorMsg.isNotEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  errorMsg,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchReceipts,
                                  child: Text(context.tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 72,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchVal.isNotEmpty
                                      ? 'No results for "$searchVal"'
                                      : 'No receipts found',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchReceipts,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, index) {
                                final receipt = Map<String, dynamic>.from(
                                  filtered[index] as Map,
                                );
                                return _receiptCard(receipt);
                              },
                            ),
                          ),
                        ),
                      if (!loading && errorMsg.isEmpty && filtered.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Total Collected'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                context.tr('${CountryConfig.currencySymbol}${totalCollectedVal.toStringAsFixed(2)}'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade700,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _branchDropdown(String? selectedBranchId) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _branches,
      builder: (context, branchesList, _) => DropdownButtonFormField<String>(
        value: selectedBranchId,
        isExpanded: true,
        menuMaxHeight: 350,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        hint: Text(context.tr('All branches')),
        items: [
          DropdownMenuItem<String>(value: '', child: Text(context.tr('All branches'))),
          ...branchesList.map((branch) {
            final item = Map<String, dynamic>.from(branch as Map);
            return DropdownMenuItem<String>(
              value: item['id']?.toString() ?? '',
              child: Text(item['name']?.toString() ?? ''),
            );
          }),
        ],
        onChanged: (value) {
          _selectedBranchId.value = value == null || value.isEmpty ? null : value;
          _fetchReceipts();
        },
      ),
    );
  }

  Widget _paymentModeDropdown(String? selectedPaymentMode) {
    return DropdownButtonFormField<String>(
      value: selectedPaymentMode,
      isExpanded: true,
      menuMaxHeight: 350,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      hint: Text(context.tr('All payment modes')),
      items: [
        DropdownMenuItem<String>(value: '', child: Text(context.tr('All payment modes'))),
        DropdownMenuItem<String>(value: 'cash', child: Text(context.tr('Cash'))),
        DropdownMenuItem<String>(value: 'card', child: Text(context.tr('Card'))),
        DropdownMenuItem<String>(value: 'digital_payments', child: Text(context.tr('Digital payments'))),
      ],
      onChanged: (value) {
        _selectedPaymentMode.value = value == null || value.isEmpty ? null : value;
        _fetchReceipts();
      },
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? date,
    required bool isFrom,
  }) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
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
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date != null ? _displayDate(date) : 'Select',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
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

  Widget _receiptCard(Map<String, dynamic> receipt) {
    final receiptNo = _value(receipt['receipt_number']);
    final invoiceNo = _nested(receipt, 'invoice', 'invoice_number');
    final customerName = _nested(receipt, 'customer', 'name');
    final customerPhone = _nested(receipt, 'customer', 'phone');
    final vehicleNumber = _nested(receipt, 'vehicle', 'number');
    final paymentMode = _paymentMode(_value(receipt['payment_mode']));
    final branchName = _value(receipt['branch']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiptNo,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('$customerName • $customerPhone'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    context.tr('${CountryConfig.currencySymbol}${_formatAmount(receipt['amount'])}'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.receipt_outlined, '#$invoiceNo'),
                _chip(Icons.directions_car_outlined, vehicleNumber),
                _chip(
                  Icons.calendar_today_outlined,
                  _formatDate(_value(receipt['date'])),
                ),
                _chip(Icons.payments_outlined, paymentMode),
                if (branchName.isNotEmpty)
                  _chip(Icons.store_outlined, branchName),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _shareReceipt(receipt),
                icon: const Icon(Icons.share, size: 18),
                label: Text(
                  context.tr('Share Receipt'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
