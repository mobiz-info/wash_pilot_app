import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/auth_provider.dart';
import '../providers/invoice_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  late final ValueNotifier<DateTime?> _fromDateNotifier;
  late final ValueNotifier<DateTime?> _toDateNotifier;
  late final ValueNotifier<String?> _paymentModeNotifier;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _fromDateNotifier = ValueNotifier(today);
    _toDateNotifier = ValueNotifier(today);
    _paymentModeNotifier = ValueNotifier(null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInvoices(context);
    });
  }

  @override
  void dispose() {
    _fromDateNotifier.dispose();
    _toDateNotifier.dispose();
    _paymentModeNotifier.dispose();
    super.dispose();
  }


  String currencySymbol(BuildContext context) {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return CountryConfig.currencySymbol;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(BuildContext context, DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(context, d.month)} ${d.year}';

  String _monthName(BuildContext context, int m) => context.tr(
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1]);

  String _formatDisplayDate(BuildContext context, String raw) {
    try {
      final d = DateTime.parse(raw);
      return _displayDate(context, d);
    } catch (_) {
      return raw;
    }
  }

  String _fmt(dynamic value) {
    final d = (value is num)
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  Future<void> _fetchInvoices(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    context.read<InvoiceProvider>().fetchInvoices(
      token,
      fromDate: _fromDateNotifier.value != null ? _formatDate(_fromDateNotifier.value!) : null,
      toDate: _toDateNotifier.value != null ? _formatDate(_toDateNotifier.value!) : null,
      paymentMode: _paymentModeNotifier.value,
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isFrom}) async {
    final initial = isFrom ? (_fromDateNotifier.value ?? DateTime.now()) : (_toDateNotifier.value ?? DateTime.now());
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

    if (isFrom) {
      _fromDateNotifier.value = picked;
      if (_toDateNotifier.value != null && _toDateNotifier.value!.isBefore(picked)) {
        _toDateNotifier.value = picked;
      }
    } else {
      _toDateNotifier.value = picked;
      if (_fromDateNotifier.value != null && _fromDateNotifier.value!.isAfter(picked)) {
        _fromDateNotifier.value = picked;
      }
    }
    _fetchInvoices(context);
  }

  // ── PDF Generation & Share/Download/Print ──────────────────────────
  Future<Uint8List> _getInvoicePdfBytes(BuildContext context, Map<String, dynamic> inv) async {
    final invoiceNumber = inv['invoice_number'] as String? ?? '';
    final cleanInvoiceNo = invoiceNumber.replaceAll('/', '_');
    final pdfUrl = "http://68.183.94.11:78/media/invoices/invoice-$cleanInvoiceNo.pdf";
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    final localPdf = await _generateInvoicePdf(context, inv);
    return localPdf.save();
  }

  Future<pw.Document> _generateInvoicePdf(BuildContext context, Map<String, dynamic> inv) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final notoFont = pw.Font.ttf(fontData);

    final pdf = pw.Document(
      title: inv['invoice_number']?.toString() ?? 'Invoice',
      theme: pw.ThemeData.withFont(
        base: notoFont,
        bold: notoFont,
      ),
    );
    final services = inv['services'] as List<dynamic>? ?? [];

    pw.ImageProvider? logoImage;
    try {
      final logoUrl = inv['company_logo'] as String? ?? '';
      if (logoUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      }
    } catch (_) {}

    if (logoImage == null) {
      try {
        final logoData = await rootBundle.load('assets/icons/Wash-Pilot_Blue-Icon.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}
    }

    final String invBranch = inv['branch']?.toString() ?? '';
    final String authBranch = context.read<AuthProvider>().branchName ?? '';
    final String branchName = invBranch.isNotEmpty
        ? invBranch
        : (authBranch.isNotEmpty ? authBranch : 'our service');

    final companyName = context.read<AuthProvider>().companyName ?? 'Mobiz Autocare Pro';
    final branchAddress = inv['branch_address']?.toString() ?? '';
    final branchPhone = inv['branch_phone']?.toString() ?? '';
    final branchEmail = inv['branch_email']?.toString() ?? '';
    final branchGst = inv['branch_gst']?.toString() ?? '';
    final dateStr = inv['date']?.toString() ?? '';
    final symbol = currencySymbol(context);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null) ...[
                      pw.Image(logoImage, width: 55, height: 55, fit: pw.BoxFit.contain),
                      pw.SizedBox(width: 12),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(companyName.toUpperCase(),
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          pw.Text(branchName,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                          if (branchAddress.isNotEmpty)
                            pw.Text(branchAddress, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          if (branchPhone.isNotEmpty)
                            pw.Text("Phone: $branchPhone", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          if (branchEmail.isNotEmpty)
                            pw.Text("Email: $branchEmail", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          if (branchGst.isNotEmpty)
                            pw.Text("GSTIN: $branchGst", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
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
                  pw.Text('INVOICE',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.SizedBox(height: 4),
                  pw.Text(inv['invoice_number'],
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                  pw.Text(inv['invoice_type'] == 'creditinvoice' ? 'Credit Invoice' : 'Cash Invoice',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (dateStr.isNotEmpty)
                    pw.Text(_formatDisplayDate(context, dateStr), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
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
            headers: ['Service', 'Rate ($symbol)'],
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
              pw.Text('Subtotal:  $symbol${inv['subtotal']}'),
              pw.Text('Discount:  $symbol${inv['discount']}'),
              pw.Text('Tax:       $symbol${inv['tax_amount']}'),
              pw.Divider(),
              pw.Text('Total:     $symbol${inv['total']}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 4),
              pw.Text('Collected: $symbol${inv['amount_collected']}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.green700)),
            ]),
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('Thanks for choosing $branchName',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 4),
                pw.Text('Powered by Mobiz Technologies',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
          ),
        ],
      ),
    ));
    return pdf;
  }

  String _getCleanedWhatsAppNumber(Map<String, dynamic> customer) {
    String phone = (customer['whatsapp_number']?.toString().isNotEmpty == true)
        ? customer['whatsapp_number'].toString()
        : (customer['phone']?.toString() ?? '');
    
    return CountryConfig.formatPhoneForWhatsapp(phone);
  }


  void _shareInvoice(BuildContext context, Map<String, dynamic> inv) {
    _showShareOptions(context, inv);
  }

  Future<void> _shareViaWhatsApp(BuildContext context, Map<String, dynamic> inv) async {
    try {
      final token = context.read<AuthProvider>().token;
      final invoiceId = inv['id']?.toString() ?? '';

      if (token != null && invoiceId.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000080)),
            ),
          ),
        );

        try {
          final res = await ApiService.sendInvoiceWhatsApp(invoiceId, token);
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Dismiss loading dialog
          }

          if (res['success'] == true && res['action'] == 'auto') {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('Invoice sent automatically via WhatsApp API')),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return;
          }
        } catch (_) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Dismiss loading dialog
          }
        }
      }

      final customer = inv['customer'] as Map<String, dynamic>? ?? {};
      final vehicle = inv['vehicle'] as Map<String, dynamic>? ?? {};
      final services = inv['services'] as List<dynamic>? ?? [];
      final symbol = currencySymbol(context);
      final total = _fmt(inv['total']);
      final collected = _fmt(inv['amount_collected']);
      final invoiceNumber = inv['invoice_number'] as String? ?? '';

      final servicesStr = services.map((s) => "- ${s['name']}: $symbol${_fmt(s['rate'])}").join("\n");

      final branchName = inv['branch']?.toString() ?? context.read<AuthProvider>().branchName ?? 'our branch';
      final companyName = context.read<AuthProvider>().companyName ?? 'Mobiz Autocare Pro';

      final doubleTot = double.tryParse(total.toString()) ?? 0.0;
      final doubleColl = double.tryParse(collected.toString()) ?? 0.0;
      final balanceVal = doubleTot - doubleColl;

      final messageText = 
          "Dear ${customer['name']},\n\n"
          "Your invoice *$invoiceNumber* has been generated successfully at $companyName.\n\n"
          "*Invoice Details:*\n"
          "Vehicle: ${vehicle['number'] ?? vehicle['no'] ?? ''}\n"
          "Services:\n$servicesStr\n"
          "Total: $symbol$total\n"
          "Paid: $symbol$collected\n"
          "Balance: $symbol${_fmt(balanceVal)}\n\n"
          "Thank you for choosing $branchName!\n"
          "Powered by Mobiz Technologies";

      final cleanedPhone = _getCleanedWhatsAppNumber(customer);
      if (cleanedPhone.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('No phone number available for this customer')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final whatsappUrl = Uri.parse(
        "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(messageText)}"
      );

      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error launching WhatsApp: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sharePdfFile(BuildContext context, Map<String, dynamic> inv) async {
    try {
      final customer = inv['customer'] as Map<String, dynamic>? ?? {};
      final vehicle = inv['vehicle'] as Map<String, dynamic>? ?? {};
      final services = inv['services'] as List<dynamic>? ?? [];
      final symbol = currencySymbol(context);
      final total = _fmt(inv['total']);
      final collected = _fmt(inv['amount_collected']);
      final invoiceNumber = inv['invoice_number'] as String? ?? '';

      final servicesStr = services.map((s) => "- ${s['name']}: $symbol${_fmt(s['rate'])}").join("\n");

      final branchName = inv['branch']?.toString() ?? context.read<AuthProvider>().branchName ?? 'our branch';
      final companyName = context.read<AuthProvider>().companyName ?? 'Mobiz Autocare Pro';

      final doubleTot = double.tryParse(total.toString()) ?? 0.0;
      final doubleColl = double.tryParse(collected.toString()) ?? 0.0;
      final balanceVal = doubleTot - doubleColl;

      final messageText = 
          "Dear ${customer['name']},\n\n"
          "Your invoice *$invoiceNumber* has been generated successfully at $companyName.\n\n"
          "*Invoice Details:*\n"
          "Vehicle: ${vehicle['number'] ?? vehicle['no'] ?? ''}\n"
          "Services:\n$servicesStr\n"
          "Total: $symbol$total\n"
          "Paid: $symbol$collected\n"
          "Balance: $symbol${_fmt(balanceVal)}\n\n"
          "Thank you for choosing $branchName!\n"
          "Powered by Mobiz Technologies";

      final pdfBytes = await _getInvoicePdfBytes(context, inv);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${inv['invoice_number'].replaceAll('/', '_')}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: messageText);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showShareOptions(BuildContext context, Map<String, dynamic> inv) {
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
                    bc.tr('Share Invoice'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: const Color(0xFF000080),
                    ),
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                  ),
                  title: Text(
                    bc.tr('Share via WhatsApp (Direct Chat)'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    bc.tr('Opens chat with pre-filled summary'),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _shareViaWhatsApp(context, inv);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                  ),
                  title: Text(
                    bc.tr('Share PDF Document'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    bc.tr('Generates PDF and opens sharing menu'),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _sharePdfFile(context, inv);
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

  Future<void> _downloadInvoice(BuildContext context, Map<String, dynamic> inv) async {
    try {
      final pdfBytes = await _getInvoicePdfBytes(context, inv);
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
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Invoice downloaded successfully')}: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('Failed to download invoice')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printInvoice(BuildContext context, Map<String, dynamic> inv) async {
    try {
      final pdfBytes = await _getInvoicePdfBytes(context, inv);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: '${inv['invoice_number'].replaceAll('/', '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
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
    final invoiceProvider = context.watch<InvoiceProvider>();
    final invoices = invoiceProvider.invoices;
    final isLoading = invoiceProvider.isLoadingList;
    final errorMessage = invoiceProvider.listErrorMessage ?? '';
    final symbol = currencySymbol(context);

    final totalAmount = invoices.fold<double>(
      0, (sum, inv) => sum + (double.tryParse(inv['total'].toString()) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Bills'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _fetchInvoices(context)),
        ],
      ),
      body: Column(
        children: [
          // Date Filter
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _fromDateNotifier,
                        builder: (context, fromDate, child) {
                          return _datePicker(context, label: 'From', date: fromDate, isFrom: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder<DateTime?>(
                        valueListenable: _toDateNotifier,
                        builder: (context, toDate, child) {
                          return _datePicker(context, label: 'To', date: toDate, isFrom: false);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _fetchInvoices(context),
                      child: Container(
                        height: 48, width: 48,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.search, color: Color(0xFF000080)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _paymentModeDropdown(context),
              ],
            ),
          ),

          // Summary bar
          if (!isLoading && invoices.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(context.tr('${invoices.length} invoice${invoices.length == 1 ? '' : 's'}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13)),
                  ]),
                  Text(context.tr('Total: $symbol${totalAmount.toStringAsFixed(2)}'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF000080), fontSize: 14)),
                ],
              ),
            ),

          // List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? _buildError(context, errorMessage)
                    : invoices.isEmpty
                        ? _buildEmpty(context)
                        : RefreshIndicator(
                            onRefresh: () => _fetchInvoices(context),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: invoices.length,
                              itemBuilder: (ctx, i) => _invoiceCard(ctx, invoices[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(BuildContext context, {required String label, required DateTime? date, required bool isFrom}) {
    return GestureDetector(
      onTap: () => _pickDate(context, isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 15, color: Color(0xFF000080)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              Text(date != null ? _displayDate(context, date) : 'Select',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1e293b))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _invoiceCard(BuildContext context, Map<String, dynamic> inv) {
    final services = inv['services'] as List<dynamic>? ?? [];
    final total = double.tryParse(inv['total'].toString()) ?? 0;
    final collected = double.tryParse(inv['amount_collected'].toString()) ?? 0;
    final isFullyPaid = collected >= total;
    final symbol = currencySymbol(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF000080).withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv['invoice_number'],
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF000080))),
                    const SizedBox(height: 2),
                    Text(_formatDisplayDate(context, inv['date']),
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: inv['invoice_type'] == 'creditinvoice' ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: inv['invoice_type'] == 'creditinvoice' ? Colors.red.shade200 : Colors.green.shade200),
                      ),
                      child: Text(inv['invoice_type'] == 'creditinvoice' ? context.tr('Credit') : context.tr('Cash'),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: inv['invoice_type'] == 'creditinvoice' ? Colors.red.shade700 : Colors.green.shade700)),
                    ),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 16),

                // Services List
                ...services.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr(s['name']), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                          Text(context.tr('$symbol${s['rate']}'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    )),
                const Divider(height: 20),

                // Totals
                _totalRow(context, 'Subtotal', inv['subtotal']),
                _totalRow(context, 'Discount', inv['discount'], isNegative: true),
                _totalRow(context, 'Tax', inv['tax_amount']),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Total'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(context.tr('$symbol${inv['total']}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF000080))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Collected'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12)),
                    Text(context.tr('$symbol${inv['amount_collected']}'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green.shade700)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadInvoice(context, inv),
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
                        onPressed: () => _printInvoice(context, inv),
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
                        onPressed: () => _shareInvoice(context, inv),
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

  Widget _totalRow(BuildContext context, String label, dynamic value, {bool isNegative = false}) {
    final symbol = currencySymbol(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(context.tr(label), style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        Text(context.tr('${isNegative ? '-' : ''}$symbol$value'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13,
                color: isNegative ? Colors.red.shade400 : Colors.grey.shade800)),
      ]),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      Text(context.tr('No invoices found'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
      Text(context.tr('for the selected date range.'), style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13)),
    ]));
  }

  Widget _buildError(BuildContext context, [String? message]) {
    final msg = message ?? '';
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 60, color: Colors.red.shade200),
      const SizedBox(height: 16),
      Text(context.tr(msg), textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red, fontSize: 14)),
    ]));
  }

  Widget _paymentModeDropdown(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _paymentModeNotifier,
      builder: (context, selectedPaymentMode, child) {
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
            _paymentModeNotifier.value = value == null || value.isEmpty ? null : value;
            _fetchInvoices(context);
          },
        );
      },
    );
  }
}
