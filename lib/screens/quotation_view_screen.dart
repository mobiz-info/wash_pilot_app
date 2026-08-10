import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class QuotationViewScreen extends StatefulWidget {
  final String quotationId;
  final Map<String, dynamic>? initialData;

  const QuotationViewScreen({
    super.key,
    required this.quotationId,
    this.initialData,
  });

  @override
  State<QuotationViewScreen> createState() => _QuotationViewScreenState();
}

class _QuotationViewScreenState extends State<QuotationViewScreen> {
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return CountryConfig.currencySymbol;
    }
  }

  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _quotation;

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _quotation = Map<String, dynamic>.from(widget.initialData!);
      _isLoading = false;
    } else {
      _loadQuotationDetails();
    }
  }

  Future<void> _loadQuotationDetails() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getQuotationDetail(widget.quotationId, token);
      if (res['success'] == true && res['quotation'] != null) {
        setState(() {
          _quotation = Map<String, dynamic>.from(res['quotation'] as Map);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load quotation';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Share Text Summary via WhatsApp / System ──────────────────────────────
  void _shareTextSummary() {
    if (_quotation == null) return;
    final q = _quotation!;
    final items = (q['items'] as List<dynamic>? ?? []);
    final extras = (q['extras'] as List<dynamic>? ?? []);

    final buffer = StringBuffer();
    buffer.writeln('📋 *QUOTATION: ${q['quotation_number']}*');
    buffer.writeln('📅 Date: ${q['date']}');
    buffer.writeln('----------------------------------');
    buffer.writeln('👤 *Customer Details:*');
    buffer.writeln('Name: ${q['customer_name']}');
    buffer.writeln('Phone: ${q['customer_phone']}');
    buffer.writeln('Vehicle: ${q['vehicle_number']} (${q['vehicle_type'] ?? ''} ${q['vehicle_model'] ?? ''})');
    buffer.writeln('----------------------------------');

    if (items.isNotEmpty) {
      buffer.writeln('🛠️ *Services & Stock Items:*');
      for (final it in items) {
        buffer.writeln('• ${it['service_name']}');
        if (it['stock_item_name'] != null && it['stock_item_name'].toString().isNotEmpty) {
          buffer.writeln('  Stock: ${it['stock_item_name']}');
        }
        buffer.writeln('  Warranty: ${it['warranty_years']} yrs | Free Topup: ${it['free_topup']} | Rate: $currencySymbol${it['rate']}');
      }
      buffer.writeln('----------------------------------');
    }

    if (extras.isNotEmpty) {
      buffer.writeln('✨ *Extras:*');
      for (final ex in extras) {
        buffer.writeln('• ${ex['name']}: $currencySymbol${ex['price']}');
      }
      buffer.writeln('----------------------------------');
    }

    if (q['additional_services'] != null && q['additional_services'].toString().trim().isNotEmpty) {
      buffer.writeln('📝 *Additional Service Notes:* ${q['additional_services']}');
    }
    if (q['additional_days_needed'] != null && _parseDouble(q['additional_days_needed']) > 0) {
      buffer.writeln('⏱️ *Additional Days Needed:* ${q['additional_days_needed']} days');
    }
    buffer.writeln('----------------------------------');
    buffer.writeln('💵 *Subtotal:* $currencySymbol${_parseDouble(q['subtotal']).toStringAsFixed(2)}');
    if (_parseDouble(q['discount']) > 0) {
      buffer.writeln('🏷️ *Discount:* -$currencySymbol${_parseDouble(q['discount']).toStringAsFixed(2)}');
    }
    if (_parseDouble(q['tax_amount']) > 0) {
      buffer.writeln('🏛️ *Tax (${q['tax_percentage']}%):* $currencySymbol${_parseDouble(q['tax_amount']).toStringAsFixed(2)}');
    }
    buffer.writeln('💰 *Grand Total:* $currencySymbol${_parseDouble(q['grand_total']).toStringAsFixed(2)}');
    buffer.writeln('----------------------------------');
    buffer.writeln('Thank you for choosing us!');

    Share.share(buffer.toString());
  }

  // ── Build PDF Document Bytes ──────────────────────────────────────────────
  Future<Uint8List> _buildQuotationPdfBytes(BuildContext context) async {
    final q = _quotation!;
    final companyName = context.read<AuthProvider>().companyName ?? ApiService.appName;
    final branchName = q['branch_name'] ?? context.read<AuthProvider>().branchName ?? '';
    final branchLogoUrl = q['branch_logo'] ?? '';
    final companyLogoUrl = q['company_logo'] ?? '';

    pw.MemoryImage? logoImage;
    try {
      final logoUrl = branchLogoUrl.isNotEmpty ? branchLogoUrl : companyLogoUrl;
      if (logoUrl.isNotEmpty) {
        final res = await http.get(Uri.parse(logoUrl));
        if (res.statusCode == 200) {
          logoImage = pw.MemoryImage(res.bodyBytes);
        }
      }
    } catch (_) {}

    final items = (q['items'] as List<dynamic>? ?? []);
    final extras = (q['extras'] as List<dynamic>? ?? []);
    final subtotal = _parseDouble(q['subtotal']);
    final discount = _parseDouble(q['discount']);
    final taxAmount = _parseDouble(q['tax_amount']);
    final taxPercent = _parseDouble(q['tax_percentage']);
    final grandTotal = _parseDouble(q['grand_total']);
    final qNumber = q['quotation_number'] ?? '';
    final dateStr = q['date'] ?? '';

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Image(logoImage, width: 50, height: 50, fit: pw.BoxFit.contain),
                          pw.SizedBox(width: 12),
                        ],
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(companyName.toUpperCase(),
                                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                              if (branchName.isNotEmpty)
                                pw.Text(branchName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('QUOTATION',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 4),
                      pw.Text(qNumber,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      if (dateStr.isNotEmpty)
                        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.indigo900, thickness: 1.5),
              pw.SizedBox(height: 16),

              // Customer & Vehicle Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('QUOTATION FOR',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(q['customer_name'] ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if ((q['customer_phone'] ?? '').toString().isNotEmpty)
                        pw.Text(q['customer_phone'] ?? '', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('VEHICLE DETAILS',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(q['vehicle_number'] ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        '${q['vehicle_type'] ?? ''} ${(q['vehicle_model'] ?? '').toString().isNotEmpty ? "• ${q['vehicle_model']}" : ""}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Services Table
              if (items.isNotEmpty) ...[
                pw.Text('SERVICES & STOCK ITEMS',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FixedColumnWidth(80),
                    2: pw.FixedColumnWidth(80),
                  },
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Service / Item', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Warranty', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    for (int i = 0; i < items.length; i++)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.grey50 : PdfColors.white),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(items[i]['service_name'] ?? '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                if (items[i]['stock_item_name'] != null && items[i]['stock_item_name'].toString().isNotEmpty)
                                  pw.Text('Stock Item: ${items[i]['stock_item_name']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                if (items[i]['free_topup'] != null && items[i]['free_topup'].toString().isNotEmpty)
                                  pw.Text('Free Topup: ${items[i]['free_topup']}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              ],
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${items[i]['warranty_years']} yrs', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('$currencySymbol${_parseDouble(items[i]['rate']).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],

              // Extras Table
              if (extras.isNotEmpty) ...[
                pw.Text('EXTRAS', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FixedColumnWidth(80),
                  },
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      ],
                    ),
                    for (final ex in extras)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(ex['name'] ?? '', style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$currencySymbol${_parseDouble(ex['price']).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],

              // Additional Services / Notes
              if (q['additional_services'] != null && q['additional_services'].toString().trim().isNotEmpty) ...[
                pw.Text('ADDITIONAL SERVICES / NOTES:', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(q['additional_services'].toString(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
              ],

              // Financial Summary Box
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('$currencySymbol${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      if (discount > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
                            pw.Text('-$currencySymbol${discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          ],
                        ),
                      ],
                      if (taxAmount > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax ($taxPercent%)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            pw.Text('$currencySymbol${taxAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                      pw.Divider(color: PdfColors.grey300),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          pw.Text('$currencySymbol${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Thank you for choosing $branchName!',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 2),
                    pw.Text('Powered by Mobiz Technologies', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── Share PDF Document File ───────────────────────────────────────────────
  Future<void> _shareQuotationPdf(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final pdfBytes = await _buildQuotationPdfBytes(context);
      if (mounted) Navigator.pop(context); // Dismiss loader

      final qNum = (_quotation?['quotation_number'] ?? 'quotation').replaceAll('/', '_');
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$qNum.pdf');
      await file.writeAsBytes(pdfBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Quotation Document: $qNum');
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Print PDF Document ───────────────────────────────────────────────────
  Future<void> _printQuotationPdf(BuildContext context) async {
    try {
      final pdfBytes = await _buildQuotationPdfBytes(context);
      final qNum = (_quotation?['quotation_number'] ?? 'quotation').replaceAll('/', '_');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '$qNum.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Show Share Options Bottom Sheet ───────────────────────────────────────
  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    context.tr('Share Quotation'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color: const Color(0xFF000080),
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                  ),
                  title: Text(
                    context.tr('Share Quotation PDF Document'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    context.tr('Generates PDF file and opens sharing menu'),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _shareQuotationPdf(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.print_outlined, color: Color(0xFF000080)),
                  ),
                  title: Text(
                    context.tr('Print Quotation PDF'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    context.tr('Opens print preview and printer selection'),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _printQuotationPdf(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                  ),
                  title: Text(
                    context.tr('Share Text Summary'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    context.tr('Shares pre-filled quotation summary text'),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _shareTextSummary();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _backToDashboard() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(context.tr('Quotation Preview'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: context.tr('Share PDF'),
            onPressed: _quotation != null ? () => _shareQuotationPdf(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: context.tr('Share Options'),
            onPressed: _quotation != null ? () => _showShareOptions(context) : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _quotation == null
                  ? Center(child: Text(context.tr('Quotation not found')))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Paper Preview Card
                          _buildQuotationCard(),
                          const SizedBox(height: 24),

                          // Action Buttons: Share & Back to Dashboard
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showShareOptions(context),
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  label: Text(context.tr('Share Quotation'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _backToDashboard,
                                  icon: const Icon(Icons.home_outlined, color: Color(0xFF000080)),
                                  label: Text(context.tr('Back to Dashboard'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF000080),
                                    side: const BorderSide(color: Color(0xFF000080), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildQuotationCard() {
    final q = _quotation!;
    final items = (q['items'] as List<dynamic>? ?? []);
    final extras = (q['extras'] as List<dynamic>? ?? []);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Logo & Quotation Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ApiService.appName,
                    style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w800, color: const Color(0xFF000080)),
                  ),
                  if (q['branch_name'] != null && q['branch_name'].toString().isNotEmpty)
                    Text(
                      q['branch_name'] ?? '',
                      style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF000080).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q['quotation_number'] ?? '',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080), fontSize: 14.sp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${context.tr("Date")}: ${q['date'] ?? ''}', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade500)),
          const Divider(height: 24),

          // Customer & Vehicle Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Customer & Vehicle Information'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: const Color(0xFF000080)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(q['customer_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15.sp)),
                    Text(q['customer_phone'] ?? '', style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${q['vehicle_number'] ?? ''} ${(q['vehicle_type'] != null && q['vehicle_type'].toString().isNotEmpty) ? "· ${q['vehicle_type']}" : ""} ${(q['vehicle_model'] != null && q['vehicle_model'].toString().isNotEmpty) ? "· ${q['vehicle_model']}" : ""}',
                  style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Items Table
          if (items.isNotEmpty) ...[
            Text(
              context.tr('Services & Stock Items'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('Service / Stock'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('Warranty'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('Rate'), textAlign: TextAlign.right, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp))),
                  ],
                ),
                ...items.map((it) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it['service_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp)),
                            if (it['stock_item_name'] != null && it['stock_item_name'].toString().isNotEmpty)
                              Text('Stock: ${it['stock_item_name']}', style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600)),
                            Text('Topup: ${it['free_topup']}', style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${it['warranty_years']} yrs', style: GoogleFonts.inter(fontSize: 12.sp)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('$currencySymbol${_parseDouble(it['rate']).toStringAsFixed(2)}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Extras Table
          if (extras.isNotEmpty) ...[
            Text(
              context.tr('Extras'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ...extras.map((ex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ex['name'] ?? '', style: GoogleFonts.inter(fontSize: 13.sp)),
                    Text('$currencySymbol${_parseDouble(ex['price']).toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Additional Service Notes & Days Needed
          if (q['additional_services'] != null && q['additional_services'].toString().trim().isNotEmpty) ...[
            Text(
              context.tr('Additional Service Notes'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(q['additional_services'], style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade800)),
            const SizedBox(height: 12),
          ],
          if (q['additional_days_needed'] != null && _parseDouble(q['additional_days_needed']) > 0) ...[
            Row(
              children: [
                Text('${context.tr("Additional Days Needed")}: ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                Text('${q['additional_days_needed']} days', style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF000080), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 24),

          // Financial Summary
          _summaryRow(context.tr('Subtotal'), '$currencySymbol${_parseDouble(q["subtotal"]).toStringAsFixed(2)}'),
          if (_parseDouble(q['discount']) > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(context.tr('Discount'), '-$currencySymbol${_parseDouble(q["discount"]).toStringAsFixed(2)}'),
          ],
          if (_parseDouble(q['tax_amount']) > 0) ...[
            const SizedBox(height: 6),
            _summaryRow('${context.tr("Tax")} (${q["tax_percentage"]}%)', '$currencySymbol${_parseDouble(q["tax_amount"]).toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Grand Total'), style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF000080))),
              Text('$currencySymbol${_parseDouble(q["grand_total"]).toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF000080))),
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
        Text(label, style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade600)),
        Text(value, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
