import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  bool _isLoading = false;
  List<dynamic> _invoices = [];
  String _errorMessage = '';

  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _fetchInvoices();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => context.tr(
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1]);

  String _formatDisplayDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      return _displayDate(d);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.listInvoices(
        token,
        fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
        toDate: _toDate != null ? _formatDate(_toDate!) : null,
      );
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _invoices = res['invoices'] as List<dynamic>;
        } else {
          _errorMessage = res['message'] ?? context.tr('Failed to load invoices');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080), onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
    _fetchInvoices();
  }

  // ── PDF Generation & Share/Download/Print ──────────────────────────
  Future<pw.Document> _generateInvoicePdf(Map<String, dynamic> inv) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final notoFont = pw.Font.ttf(fontData);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: notoFont,
        bold: notoFont,
      ),
    );
    final services = inv['services'] as List<dynamic>? ?? [];

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(inv['invoice_number'],
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
              pw.Text(_formatDisplayDate(inv['date']),
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ]),
          ]),
          pw.Divider(height: 30),

          // Customer & Vehicle
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BILLED TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
              pw.SizedBox(height: 4),
              pw.Text(inv['customer']['name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(inv['customer']['phone'], style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('VEHICLE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
              pw.SizedBox(height: 4),
              pw.Text(inv['vehicle']['number'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(inv['vehicle']['model'], style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            ]),
          ]),
          pw.SizedBox(height: 24),

          // Services table
          pw.Text('SERVICES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey500)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Service', 'Rate ($currencySymbol)'],
            data: services.map((s) => [s['name'], s['rate']]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellHeight: 28,
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),

          // Totals
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Subtotal:  $currencySymbol${inv['subtotal']}'),
              pw.Text('Discount:  $currencySymbol${inv['discount']}'),
              pw.Text('Tax:       $currencySymbol${inv['tax_amount']}'),
              pw.Divider(),
              pw.Text('Total:     $currencySymbol${inv['total']}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 4),
              pw.Text('Collected: $currencySymbol${inv['amount_collected']}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.green700)),
            ]),
          ),
          pw.Spacer(),
          pw.Center(child: pw.Text('Thank you for choosing us!',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))),
        ],
      ),
    ));
    return pdf;
  }

  Future<void> _shareInvoice(Map<String, dynamic> inv) async {
    try {
      final pdf = await _generateInvoicePdf(inv);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${inv['invoice_number'].replaceAll('/', '_')}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice ${inv['invoice_number']}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadInvoice(Map<String, dynamic> inv) async {
    try {
      final pdf = await _generateInvoicePdf(inv);
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception(context.tr('Could not find download directory'));
      }

      final filename = '${inv['invoice_number'].replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Invoice downloaded successfully')}: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Failed to download invoice')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printInvoice(Map<String, dynamic> inv) async {
    try {
      final pdf = await _generateInvoicePdf(inv);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${inv['invoice_number'].replaceAll('/', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Failed to print invoice')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalAmount = _invoices.fold<double>(
      0, (sum, inv) => sum + (double.tryParse(inv['total'].toString()) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Bills'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchInvoices),
        ],
      ),
      body: Column(
        children: [
          // Date Filter
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                Expanded(child: _datePicker(label: 'From', date: _fromDate, isFrom: true)),
                const SizedBox(width: 12),
                Expanded(child: _datePicker(label: 'To', date: _toDate, isFrom: false)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _fetchInvoices,
                  child: Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.search, color: Color(0xFF000080)),
                  ),
                ),
              ],
            ),
          ),

          // Summary bar
          if (!_isLoading && _invoices.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(context.tr('${_invoices.length} invoice${_invoices.length == 1 ? '' : 's'}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                  ]),
                  Text(context.tr('Total: $currencySymbol${totalAmount.toStringAsFixed(2)}'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF000080), fontSize: 14)),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _invoices.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchInvoices,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _invoices.length,
                              itemBuilder: (ctx, i) => _invoiceCard(_invoices[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker({required String label, required DateTime? date, required bool isFrom}) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 15, color: Color(0xFF000080)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              Text(date != null ? _displayDate(date) : 'Select',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1e293b))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _invoiceCard(Map<String, dynamic> inv) {
    final services = inv['services'] as List<dynamic>? ?? [];
    final total = double.tryParse(inv['total'].toString()) ?? 0;
    final collected = double.tryParse(inv['amount_collected'].toString()) ?? 0;
    final isFullyPaid = collected >= total;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF000080).withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv['invoice_number'],
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF000080))),
                    const SizedBox(height: 2),
                    Text(_formatDisplayDate(inv['date']),
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFullyPaid ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isFullyPaid ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Text(isFullyPaid ? '✓ ${context.tr('Paid')}' : '⏳ ${context.tr('Partial')}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isFullyPaid ? Colors.green.shade700 : Colors.orange.shade700)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer & Vehicle row
                Row(
                  children: [
                    Expanded(
                      child: _infoChip(Icons.person_outline, inv['customer']['name'], inv['customer']['phone']),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoChip(Icons.directions_car_outlined, inv['vehicle']['number'], inv['vehicle']['model']),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Services
                if (services.isNotEmpty) ...[
                  Text(context.tr('Services'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  ...services.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr(s['name']), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                            Text(context.tr('$currencySymbol${s['rate']}'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      )),
                  const Divider(height: 20),
                ],

                // Totals
                _totalRow('Subtotal', inv['subtotal']),
                _totalRow('Discount', inv['discount'], isNegative: true),
                _totalRow('Tax', inv['tax_amount']),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Total'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(context.tr('$currencySymbol${inv['total']}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF000080))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Collected'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
                    Text(context.tr('$currencySymbol${inv['amount_collected']}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green.shade700)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadInvoice(inv),
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(context.tr('Download'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF000080),
                          side: const BorderSide(color: Color(0xFF000080)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printInvoice(inv),
                        icon: const Icon(Icons.print, size: 16),
                        label: Text(context.tr('Print'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF000080),
                          side: const BorderSide(color: Color(0xFF000080)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareInvoice(inv),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(context.tr('Share'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF1e293b)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _totalRow(String label, dynamic value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(context.tr(label), style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        Text(context.tr('${isNegative ? '-' : ''}$currencySymbol$value'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13,
                color: isNegative ? Colors.red.shade400 : Colors.grey.shade800)),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      Text(context.tr('No invoices found'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
      Text(context.tr('for the selected date range.'), style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13)),
    ]));
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 60, color: Colors.red.shade200),
      const SizedBox(height: 16),
      Text(context.tr(_errorMessage), textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red, fontSize: 14)),
    ]));
  }
}
