import 'dart:io';
import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;


class InvoiceViewScreen extends StatelessWidget {
  final String invoiceId;
  final String invoiceNumber;
  final Map<String, dynamic> invoiceData;
  final Map<String, dynamic> customer;
  final Map<String, dynamic> vehicle;

  const InvoiceViewScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.invoiceData,
    required this.customer,
    required this.vehicle,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmt(dynamic value) {
    final d = (value is num)
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  // ── PDF helper widgets ───────────────────────────────────────────────────
  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerRight,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: align,
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 11,
            fontWeight: (isHeader || bold)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: isHeader ? PdfColors.white : (color ?? PdfColors.grey900),
          )),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor ?? PdfColors.grey900)),
        ],
      ),
    );
  }

  // ── PDF generation ────────────────────────────────────────────────────────
  Future<Uint8List> _getInvoicePdfBytes(BuildContext context) async {
    final cleanInvoiceNo = invoiceNumber.replaceAll('/', '_');
    final pdfUrl = "http://68.183.94.11:78/media/invoices/invoice-$cleanInvoiceNo.pdf";
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    final localPdf = await _generateInvoicePdf(context);
    return localPdf.save();
  }

  Future<pw.Document> _generateInvoicePdf(BuildContext context) async {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;

    // Load NotoSans from bundled assets — supports ₹ (U+20B9) and full Unicode.
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final notoFont = pw.Font.ttf(fontData);

    final pdf = pw.Document(
      title: invoiceNumber,
      theme: pw.ThemeData.withFont(
        base: notoFont,
        bold: notoFont,
      ),
    );

    final services  = invoiceData['services']   as List<dynamic>? ?? [];
    final taxes     = invoiceData['taxes']       as List<dynamic>? ?? [];
    final subtotal  = invoiceData['subtotal']    ?? '0.00';
    final discount  = invoiceData['discount']    ?? '0.00';
    final taxAmount = invoiceData['tax_amount']  ?? '0.00';
    final total     = invoiceData['total']       ?? '0.00';

    final bool hasAnyDiscount = services.any(
      (s) => ((s['discount'] as num?)?.toDouble() ?? 0.0) > 0,
    );

    pw.ImageProvider? logoImage;
    try {
      final logoUrl = invoiceData['company_logo'] as String? ?? context.read<AuthProvider>().companyLogo ?? '';
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

    final String customerBranch = customer['branch']?.toString() ?? '';
    final String invoiceBranch = invoiceData['branch']?.toString() ?? '';
    final String authBranch = context.read<AuthProvider>().branchName ?? '';
    final String branchName = customerBranch.isNotEmpty 
        ? customerBranch 
        : (invoiceBranch.isNotEmpty 
            ? invoiceBranch 
            : (authBranch.isNotEmpty ? authBranch : 'our service'));

    final companyName = context.read<AuthProvider>().companyName ?? 'Wash Pilot';
    final branchAddress = invoiceData['branch_address']?.toString() ?? '';
    final branchPhone = invoiceData['branch_phone']?.toString() ?? '';
    final branchEmail = invoiceData['branch_email']?.toString() ?? '';
    final branchGst = invoiceData['branch_gst']?.toString() ?? '';
    final dateStr = invoiceData['date']?.toString() ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) {
          return pw.Column(
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
                      pw.Text(invoiceNumber,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      pw.Text(
                          invoiceData['invoice_type'] == 'creditinvoice' ? 'Credit Invoice' : 'Cash Invoice',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (dateStr.isNotEmpty)
                        pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.indigo900, thickness: 2),
              pw.SizedBox(height: 16),

              // Customer & Vehicle
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5)),
                      pw.SizedBox(height: 4),
                      pw.Text(customer['name'],
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      if ((customer['phone'] ?? '').toString().isNotEmpty)
                        pw.Text(customer['phone'],
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('VEHICLE',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5)),
                      pw.SizedBox(height: 4),
                      pw.Text(vehicle['no'],
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          (vehicle['vehicle_type'] != null && vehicle['vehicle_type'].toString().isNotEmpty)
                              ? "${vehicle['vehicle_type']} - ${vehicle['type']}"
                              : (vehicle['type'] ?? ''),
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Services table
              pw.Text('SERVICES',
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 6),
              pw.Table(
                columnWidths: hasAnyDiscount
                    ? {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FixedColumnWidth(70),
                        2: const pw.FixedColumnWidth(70),
                        3: const pw.FixedColumnWidth(80),
                      }
                    : {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FixedColumnWidth(80),
                      },
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                    children: [
                      _pdfCell('Service', isHeader: true, align: pw.Alignment.centerLeft),
                      _pdfCell('Rate', isHeader: true),
                      if (hasAnyDiscount) _pdfCell('Discount', isHeader: true),
                      if (hasAnyDiscount) _pdfCell('Line Total', isHeader: true),
                    ],
                  ),
                  // Data rows
                  for (int i = 0; i < services.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isEven ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        _pdfCell(services[i]['name'] ?? '', align: pw.Alignment.centerLeft),
                        _pdfCell('$currencySymbol${_fmt(services[i]['rate'])}'),
                        if (hasAnyDiscount)
                          _pdfCell(
                            ((services[i]['discount'] as num?)?.toDouble() ?? 0.0) > 0
                                ? '-$currencySymbol${_fmt(services[i]['discount'])}'
                                : '—',
                            color: ((services[i]['discount'] as num?)?.toDouble() ?? 0) > 0
                                ? PdfColors.green700
                                : PdfColors.grey500,
                          ),
                        if (hasAnyDiscount)
                          _pdfCell(
                            '$currencySymbol${_fmt(
                              (services[i]['rate'] as num).toDouble() -
                                  ((services[i]['discount'] as num?)?.toDouble() ?? 0),
                            )}',
                            bold: true,
                          ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Bill summary box (right-aligned)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 260,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _pdfSummaryRow('Subtotal', '$currencySymbol$subtotal'),
                      if ((double.tryParse(discount.toString()) ?? 0) > 0)
                        _pdfSummaryRow(
                          'Total Discount',
                          '-$currencySymbol$discount',
                          valueColor: PdfColors.green700,
                        ),
                      if (taxes.isNotEmpty)
                        for (final tax in taxes)
                          _pdfSummaryRow(
                            tax['name']?.toString() ?? 'Tax',
                            '$currencySymbol${tax['amount']}',
                          )
                      else if ((double.tryParse(taxAmount.toString()) ?? 0) > 0)
                        _pdfSummaryRow('Tax', '$currencySymbol$taxAmount'),
                      pw.Divider(color: PdfColors.grey400),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                          pw.Text('$currencySymbol$total',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                  color: PdfColors.indigo900)),
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
                    pw.Text('Thanks for choosing $branchName',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Powered by Mobiz Technologies',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  String _getCleanedWhatsAppNumber(Map<String, dynamic> customer) {
    String phone = (customer['whatsapp_number']?.toString().isNotEmpty == true)
        ? customer['whatsapp_number'].toString()
        : (customer['phone']?.toString() ?? '');
    
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    return cleaned;
  }

  // ── Share Invoice ────────────────────────────────────────────────────────
  void _shareInvoice(BuildContext context) {
    _showShareOptions(context);
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      final token = context.read<AuthProvider>().token;
      if (token != null && invoiceId.isNotEmpty) {
        // Show loading progress
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('Invoice sent automatically via WhatsApp API')),
                backgroundColor: Colors.green,
              ),
            );
            return; // Finished!
          }
        } catch (_) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Dismiss loading dialog
          }
        }
      }

      final currencySymbol = context.read<AuthProvider>().currencySymbol;
      final services = invoiceData['services'] as List<dynamic>? ?? [];
      final total = invoiceData['total'] ?? '0.00';
      final collected = invoiceData['amount_collected'] ?? '0.00';

      final servicesStr = services.map((s) => "- ${s['name']}: $currencySymbol${_fmt(s['rate'])}").join("\n");

      final cleanInvoiceNo = invoiceNumber.replaceAll('/', '_');
      final pdfUrl = "http://68.183.94.11:78/media/invoices/invoice-$cleanInvoiceNo.pdf";

      final branchName = invoiceData['branch']?.toString() ?? context.read<AuthProvider>().branchName ?? 'our branch';
      final companyName = context.read<AuthProvider>().companyName ?? 'Wash Pilot';
      final companyLogo = context.read<AuthProvider>().companyLogo ?? '';
      final logoSuffix = companyLogo.isNotEmpty ? "\n\nCompany Logo: $companyLogo" : "";

      final doubleTot = double.tryParse(total.toString()) ?? 0.0;
      final doubleColl = double.tryParse(collected.toString()) ?? 0.0;
      final balanceVal = doubleTot - doubleColl;

      final messageText = 
          "Dear ${customer['name']},\n\n"
          "Your invoice *$invoiceNumber* has been generated successfully at $companyName.\n\n"
          "*Invoice Details:*\n"
          "Vehicle: ${vehicle['no']}\n"
          "Services:\n$servicesStr\n"
          "Total: $currencySymbol$total\n"
          "Paid: $currencySymbol$collected\n"
          "Balance: $currencySymbol${_fmt(balanceVal)}\n\n"
          "Please find the attached PDF invoice for your reference:\n"
          "$pdfUrl\n\n"
          "Thank you for choosing $branchName!\n"
          "Powered by Mobiz Technologies$logoSuffix";

      final cleanedPhone = _getCleanedWhatsAppNumber(customer);
      if (cleanedPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('No phone number available for this customer')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final whatsappUrl = Uri.parse(
        "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(messageText)}"
      );

      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error launching WhatsApp: $e'))),
        );
      }
    }
  }

  Future<void> _sharePdfFile(BuildContext context) async {
    try {
      final currencySymbol = context.read<AuthProvider>().currencySymbol;
      final services = invoiceData['services'] as List<dynamic>? ?? [];
      final total = invoiceData['total'] ?? '0.00';
      final collected = invoiceData['amount_collected'] ?? '0.00';

      final servicesStr = services.map((s) => "- ${s['name']}: $currencySymbol${_fmt(s['rate'])}").join("\n");
      final cleanInvoiceNo = invoiceNumber.replaceAll('/', '_');
      final pdfUrl = "http://68.183.94.11:78/media/invoices/invoice-$cleanInvoiceNo.pdf";

      final branchName = invoiceData['branch']?.toString() ?? context.read<AuthProvider>().branchName ?? 'our branch';
      final companyName = context.read<AuthProvider>().companyName ?? 'Wash Pilot';
      final companyLogo = context.read<AuthProvider>().companyLogo ?? '';
      final logoSuffix = companyLogo.isNotEmpty ? "\n\nCompany Logo: $companyLogo" : "";

      final doubleTot = double.tryParse(total.toString()) ?? 0.0;
      final doubleColl = double.tryParse(collected.toString()) ?? 0.0;
      final balanceVal = doubleTot - doubleColl;

      final messageText = 
          "Dear ${customer['name']},\n\n"
          "Your invoice *$invoiceNumber* has been generated successfully at $companyName.\n\n"
          "*Invoice Details:*\n"
          "Vehicle: ${vehicle['no']}\n"
          "Services:\n$servicesStr\n"
          "Total: $currencySymbol$total\n"
          "Paid: $currencySymbol$collected\n"
          "Balance: $currencySymbol${_fmt(balanceVal)}\n\n"
          "Please find the attached PDF invoice for your reference:\n"
          "$pdfUrl\n\n"
          "Thank you for choosing $branchName!\n"
          "Powered by Mobiz Technologies$logoSuffix";

      final pdfBytes = await _getInvoicePdfBytes(context);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$cleanInvoiceNo.pdf');
      await file.writeAsBytes(pdfBytes);
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: messageText);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error generating PDF: $e'))),
        );
      }
    }
  }

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
                    context.tr('Share Invoice'),
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
                    context.tr('Share via WhatsApp (Direct Chat)'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    context.tr('Opens chat with pre-filled summary'),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _shareViaWhatsApp(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                  ),
                  title: Text(
                    context.tr('Share PDF Document'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    context.tr('Generates PDF and opens sharing menu'),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _sharePdfFile(context);
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



  // ── Screen UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final taxes          = invoiceData['taxes']    as List<dynamic>? ?? [];
    final services       = invoiceData['services'] as List<dynamic>? ?? [];
    final currencySymbol = context.watch<AuthProvider>().currencySymbol;

    final bool hasAnyDiscount =
        services.any((s) => ((s['discount'] as num?)?.toDouble() ?? 0.0) > 0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(context.tr('Invoice Details'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareInvoice(context),
            tooltip: context.tr('Share Invoice'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Invoice header ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('INVOICE'),
                      style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF000080),
                          letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(context.tr('PAID'),
                        style: GoogleFonts.inter(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(invoiceNumber,
                  style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider()),

              // ── Customer & Vehicle ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('BILLED TO'),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(customer['name'],
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(customer['phone'] ?? '',
                          style: GoogleFonts.inter(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.tr('VEHICLE'),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                       Text(vehicle['no'],
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                          (vehicle['vehicle_type'] != null && vehicle['vehicle_type'].toString().isNotEmpty)
                              ? "${vehicle['vehicle_type']} - ${vehicle['type']}"
                              : (vehicle['type'] ?? ''),
                          style: GoogleFonts.inter(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Services ─────────────────────────────────────────────────
              Text(context.tr('SERVICES'),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),

              // Column headers when discounts exist
              if (hasAnyDiscount)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                        child: Text(context.tr('Service'),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 68,
                        child: Text(context.tr('Rate'),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 68,
                        child: Text(context.tr('Disc.'),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 76,
                        child: Text(context.tr('Net'),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),

              // Service rows
              for (int i = 0; i < services.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: i.isEven
                        ? Colors.grey.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: hasAnyDiscount
                      ? Row(children: [
                          Expanded(
                            child: Text(services[i]['name'] ?? '',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: const Color(0xFF1e293b))),
                          ),
                          SizedBox(
                            width: 68,
                            child: Text(
                              context.tr('$currencySymbol${_fmt(services[i]['rate'])}'),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700),
                            ),
                          ),
                          SizedBox(
                            width: 68,
                            child: Text(
                              ((services[i]['discount'] as num?)
                                              ?.toDouble() ??
                                          0) >
                                      0
                                  ? '-$currencySymbol${_fmt(services[i]['discount'])}'
                                  : '—',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: ((services[i]['discount'] as num?)
                                                ?.toDouble() ??
                                            0) >
                                        0
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 76,
                            child: Text(
                              context.tr('$currencySymbol${_fmt(
                                (services[i]['rate'] as num).toDouble() -
                                    ((services[i]['discount'] as num?)
                                            ?.toDouble() ??
                                        0),
                              )}'),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF000080)),
                            ),
                          ),
                        ])
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(services[i]['name'] ?? '',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: const Color(0xFF1e293b))),
                            Text(
                              context.tr('$currencySymbol${_fmt(services[i]['rate'])}'),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: const Color(0xFF000080)),
                            ),
                          ],
                        ),
                ),
              ],

              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider()),

              // ── Totals summary ────────────────────────────────────────────
              _summaryRow('Subtotal',
                  '$currencySymbol${invoiceData['subtotal']}'),
              if ((double.tryParse(
                          invoiceData['discount']?.toString() ?? '0') ??
                      0) >
                  0) ...[
                const SizedBox(height: 8),
                _summaryRow(
                  'Total Discount',
                  '-$currencySymbol${invoiceData['discount']}',
                  valueColor: Colors.green.shade600,
                ),
              ],
              if (taxes.isNotEmpty)
                for (final tax in taxes) ...[
                  const SizedBox(height: 8),
                  _summaryRow(
                    tax['name']?.toString() ?? 'Tax',
                    '$currencySymbol${tax['amount']}',
                  ),
                ]
              else if ((double.tryParse(
                          invoiceData['tax_amount']?.toString() ?? '0') ??
                      0) >
                  0) ...[
                const SizedBox(height: 8),
                _summaryRow(
                    'Tax', '$currencySymbol${invoiceData['tax_amount']}'),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF000080).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('Total'),
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(context.tr('$currencySymbol${invoiceData['total']}'),
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: const Color(0xFF000080))),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Buttons ───────────────────────────────────────────────────
              ElevatedButton.icon(
                onPressed: () => _shareInvoice(context),
                icon: const Icon(Icons.share),
                label: Text(context.tr('Share Invoice'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('Back to Dashboard'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.grey.shade600, fontSize: 13)),
        Text(value,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? const Color(0xFF1e293b))),
      ],
    );
  }
}
