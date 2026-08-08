import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _quotation = widget.initialData;
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
          _quotation = res['quotation'];
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

  void _shareQuotation() {
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
    if (q['additional_days_needed'] != null && (q['additional_days_needed'] as num) > 0) {
      buffer.writeln('⏱️ *Additional Days Needed:* ${q['additional_days_needed']} days');
    }
    buffer.writeln('----------------------------------');
    buffer.writeln('💵 *Subtotal:* $currencySymbol${q['subtotal']}');
    if ((q['discount'] as num?) != null && (q['discount'] as num) > 0) {
      buffer.writeln('🏷️ *Discount:* -$currencySymbol${q['discount']}');
    }
    if ((q['tax_amount'] as num?) != null && (q['tax_amount'] as num) > 0) {
      buffer.writeln('🏛️ *Tax (${q['tax_percentage']}%):* $currencySymbol${q['tax_amount']}');
    }
    buffer.writeln('💰 *Grand Total:* $currencySymbol${q['grand_total']}');
    buffer.writeln('----------------------------------');
    buffer.writeln('Thank you for choosing us!');

    Share.share(buffer.toString());
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
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: context.tr('Share Quotation'),
            onPressed: _quotation != null ? _shareQuotation : null,
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
                                  onPressed: _shareQuotation,
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
                        child: Text('$currencySymbol${it['rate']}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
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
                    Text('$currencySymbol${ex['price']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
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
          if (q['additional_days_needed'] != null && (q['additional_days_needed'] as num) > 0) ...[
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
          _summaryRow(context.tr('Subtotal'), '$currencySymbol${q['subtotal']}'),
          if ((q['discount'] as num?) != null && (q['discount'] as num) > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(context.tr('Discount'), '-$currencySymbol${q['discount']}'),
          ],
          if ((q['tax_amount'] as num?) != null && (q['tax_amount'] as num) > 0) ...[
            const SizedBox(height: 6),
            _summaryRow('${context.tr("Tax")} (${q["tax_percentage"]}%)', '$currencySymbol${q["tax_amount"]}'),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('Grand Total'), style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF000080))),
              Text('$currencySymbol${q['grand_total']}', style: GoogleFonts.inter(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF000080))),
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
