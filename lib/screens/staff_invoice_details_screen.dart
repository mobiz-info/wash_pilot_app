import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import 'invoice_view_screen.dart';

class StaffInvoiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> staffData;
  final String fromDateStr;
  final String toDateStr;

  const StaffInvoiceDetailsScreen({
    super.key,
    required this.staffData,
    required this.fromDateStr,
    required this.toDateStr,
  });

  @override
  State<StaffInvoiceDetailsScreen> createState() => _StaffInvoiceDetailsScreenState();
}

class _StaffInvoiceDetailsScreenState extends State<StaffInvoiceDetailsScreen> {
  final _searchController = TextEditingController();
  final _searchQuery = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchQuery.value = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  String _fmt(dynamic val) {
    if (val == null) return '0.00';
    final d = double.tryParse(val.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  void _openInvoiceView(BuildContext context, Map<String, dynamic> inv) {
    final invId = (inv['id'] ?? '').toString();
    final invNo = (inv['invoice_number'] ?? '').toString();
    final custName = (inv['customer_name'] ?? 'N/A').toString();
    final custPhone = (inv['customer_phone'] ?? '').toString();
    final vehNo = (inv['vehicle_number'] ?? 'N/A').toString();
    final vehType = (inv['vehicle_type'] ?? '').toString();
    final invTotal = (inv['total'] ?? '0.00').toString();
    final invSubtotal = (inv['subtotal'] ?? invTotal).toString();
    final invDiscount = (inv['discount'] ?? '0.00').toString();
    final invTaxAmount = (inv['tax_amount'] ?? '0.00').toString();
    final invAmountCollected = (inv['amount_collected'] ?? invTotal).toString();

    final invoiceData = <String, dynamic>{
      'id': invId,
      'invoice_number': invNo,
      'date': inv['date'],
      'subtotal': invSubtotal,
      'discount': invDiscount,
      'tax_amount': invTaxAmount,
      'total': invTotal,
      'amount_collected': invAmountCollected,
      'invoice_type': inv['invoice_type'] ?? 'cashinvoice',
      'services': inv['services'] ?? [],
      'trading_items': inv['trading_items'] ?? [],
      'taxes': inv['taxes'] ?? [],
      'company_logo': inv['company_logo'] ?? '',
      'branch_logo': inv['branch_logo'] ?? '',
      'branch': inv['branch'] ?? '',
    };

    final customer = <String, dynamic>{
      'name': custName,
      'phone': custPhone,
    };

    final vehicle = <String, dynamic>{
      'no': vehNo,
      'type': vehType,
      'vehicle_type': vehType,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceViewScreen(
          invoiceId: invId,
          invoiceNumber: invNo,
          invoiceData: invoiceData,
          customer: customer,
          vehicle: vehicle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    final staff = widget.staffData;
    final name = (staff['name'] ?? '').toString();
    final empId = (staff['employee_id'] ?? '').toString();
    final desig = (staff['designation'] ?? '').toString();
    final branchName = (staff['branch_name'] ?? '').toString();
    final invCount = staff['invoice_count'] ?? 0;
    final totalIncome = staff['total_income'] ?? 0.0;
    final splitIncome = staff['split_income'] ?? 0.0;
    final allInvoices = (staff['invoices'] as List<dynamic>? ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          context.tr('Staff Invoices'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Staff Profile Banner Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF000080),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor: Colors.white,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: GoogleFonts.inter(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF000080),
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (empId.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    empId,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              if (desig.isNotEmpty)
                                Text(
                                  '$desig • ',
                                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.white70),
                                ),
                              if (branchName.isNotEmpty)
                                Text(
                                  branchName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF93C5FD),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Range: ${widget.fromDateStr} to ${widget.toDateStr}',
                            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                // KPI Summary Row inside banner
                Row(
                  children: [
                    Expanded(
                      child: _headerKpiBox(
                        label: context.tr('Attributed Share'),
                        value: '$currencySymbol ${_fmt(splitIncome)}',
                        accentColor: const Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _headerKpiBox(
                        label: context.tr('Total Invoice Revenue'),
                        value: '$currencySymbol ${_fmt(totalIncome)}',
                        accentColor: const Color(0xFF60A5FA),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _headerKpiBox(
                        label: context.tr('Invoices'),
                        value: '$invCount',
                        accentColor: const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('Search by invoice, customer, vehicle...'),
                hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                suffixIcon: ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (context, q, _) {
                    if (q.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    );
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFF000080), width: 1.5),
                ),
              ),
            ),
          ),

          // Invoices List
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (context, query, _) {
                final filtered = allInvoices.where((inv) {
                  if (query.isEmpty) return true;
                  final invNo = (inv['invoice_number'] ?? '').toString().toLowerCase();
                  final cust = (inv['customer_name'] ?? '').toString().toLowerCase();
                  final veh = (inv['vehicle_number'] ?? '').toString().toLowerCase();
                  return invNo.contains(query) || cust.contains(query) || veh.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 50.sp, color: Colors.grey.shade300),
                          SizedBox(height: 12.h),
                          Text(
                            context.tr('No assigned invoices found.'),
                            style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.r),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final inv = filtered[index] as Map<String, dynamic>;
                    final invNo = (inv['invoice_number'] ?? '').toString();
                    final invDate = (inv['date'] ?? '').toString();
                    final custName = (inv['customer_name'] ?? 'N/A').toString();
                    final vehNo = (inv['vehicle_number'] ?? 'N/A').toString();
                    final totalVal = inv['total'] ?? '0.00';
                    final shareVal = inv['share_amount'] ?? '0.00';
                    final staffCnt = inv['assigned_staff_count'] ?? 1;

                    return GestureDetector(
                      onTap: () => _openInvoiceView(context, inv),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF000080).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    invNo,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF000080),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 12.sp, color: Colors.grey.shade500),
                                    SizedBox(width: 4.w),
                                    Text(
                                      invDate,
                                      style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 16.sp, color: const Color(0xFF64748B)),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(
                                    custName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(Icons.directions_car_outlined, size: 16.sp, color: const Color(0xFF64748B)),
                                SizedBox(width: 6.w),
                                Text(
                                  vehNo,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    '$staffCnt staff(s) assigned',
                                    style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.grey.shade200),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Staff Share Amount'),
                                      style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      '$currencySymbol ${_fmt(shareVal)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      context.tr('Invoice Total'),
                                      style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500),
                                    ),
                                    Text(
                                      '$currencySymbol ${_fmt(totalVal)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000080),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey.shade400),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerKpiBox({
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w800, color: accentColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
