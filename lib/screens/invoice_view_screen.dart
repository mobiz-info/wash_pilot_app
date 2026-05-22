import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


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

  // ── PDF generation ────────────────────────────────────────────────────────
  Future<void> _shareInvoice(BuildContext context) async {
    try {
      final currencySymbol = context.read<AuthProvider>().currencySymbol;

      // Load NotoSans from bundled assets — supports ₹ (U+20B9) and full Unicode.
      // The pdf package's built-in fonts are Latin-only.
      final fontData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final notoFont = pw.Font.ttf(fontData);

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: notoFont,
          bold: notoFont, // variable font — bold weight is embedded
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
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900)),
                    pw.Text(invoiceNumber,
                        style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold)),
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
                        pw.Text(vehicle['type'] ?? '',
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
                  border:
                      pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.indigo900),
                      children: [
                        _pdfCell('Service',
                            isHeader: true,
                            align: pw.Alignment.centerLeft),
                        _pdfCell('Rate', isHeader: true),
                        if (hasAnyDiscount)
                          _pdfCell('Discount', isHeader: true),
                        if (hasAnyDiscount)
                          _pdfCell('Line Total', isHeader: true),
                      ],
                    ),
                    // Data rows
                    for (int i = 0; i < services.length; i++)
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: i.isEven ? PdfColors.grey50 : PdfColors.white,
                        ),
                        children: [
                          _pdfCell(services[i]['name'] ?? '',
                              align: pw.Alignment.centerLeft),
                          _pdfCell(
                              '$currencySymbol ${_fmt(services[i]['rate'])}'),
                          if (hasAnyDiscount)
                            _pdfCell(
                              ((services[i]['discount'] as num?)?.toDouble() ??
                                          0.0) >
                                      0
                                  ? '-$currencySymbol ${_fmt(services[i]['discount'])}'
                                  : '—',
                              color: ((services[i]['discount'] as num?)
                                              ?.toDouble() ??
                                          0) >
                                      0
                                  ? PdfColors.green700
                                  : PdfColors.grey500,
                            ),
                          if (hasAnyDiscount)
                            _pdfCell(
                              '$currencySymbol ${_fmt(
                                (services[i]['rate'] as num).toDouble() -
                                    ((services[i]['discount'] as num?)
                                            ?.toDouble() ??
                                        0),
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
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _pdfSummaryRow(
                            'Subtotal', '$currencySymbol $subtotal'),
                        if ((double.tryParse(discount.toString()) ?? 0) > 0)
                          _pdfSummaryRow(
                            'Total Discount',
                            '-$currencySymbol $discount',
                            valueColor: PdfColors.green700,
                          ),
                        if (taxes.isNotEmpty)
                          for (final tax in taxes)
                            _pdfSummaryRow(
                              tax['name']?.toString() ?? 'Tax',
                              '$currencySymbol ${tax['amount']}',
                            )
                        else if ((double.tryParse(taxAmount.toString()) ?? 0) >
                            0)
                          _pdfSummaryRow(
                              'Tax', '$currencySymbol $taxAmount'),
                        pw.Divider(color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 13)),
                            pw.Text('$currencySymbol $total',
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
                  child: pw.Text('Thank you for your business!',
                      style:
                          const pw.TextStyle(color: PdfColors.grey600)),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$invoiceNumber.pdf');
      await file.writeAsBytes(await pdf.save());
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile],
          text: 'Here is your invoice $invoiceNumber');
    } catch (e) {
      print(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  // PDF helper widgets
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

  pw.Widget _pdfSummaryRow(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor ?? PdfColors.grey900)),
        ],
      ),
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
        title: Text('Invoice Details',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareInvoice(context),
            tooltip: 'Share Invoice PDF',
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
                  Text('INVOICE',
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
                    child: Text('PAID',
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
                      Text('BILLED TO',
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
                      Text('VEHICLE',
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
                      Text(vehicle['type'] ?? '',
                          style: GoogleFonts.inter(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Services ─────────────────────────────────────────────────
              Text('SERVICES',
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
                        child: Text('Service',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 68,
                        child: Text('Rate',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 68,
                        child: Text('Disc.',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 76,
                        child: Text('Net',
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
                              '$currencySymbol${_fmt(services[i]['rate'])}',
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
                              '$currencySymbol${_fmt(
                                (services[i]['rate'] as num).toDouble() -
                                    ((services[i]['discount'] as num?)
                                            ?.toDouble() ??
                                        0),
                              )}',
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
                              '$currencySymbol${_fmt(services[i]['rate'])}',
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
                    Text('Total',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    Text('$currencySymbol${invoiceData['total']}',
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
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text('Share Invoice PDF',
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
                child: Text('Back to Dashboard',
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
