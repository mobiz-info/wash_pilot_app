import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'staff_invoice_details_screen.dart';

class StaffIncomeReportScreen extends StatefulWidget {

  const StaffIncomeReportScreen({super.key});

  @override
  State<StaffIncomeReportScreen> createState() => _StaffIncomeReportScreenState();
}

class _StaffIncomeReportScreenState extends State<StaffIncomeReportScreen> {
  final _fromDate = ValueNotifier<DateTime>(DateTime.now());
  final _toDate = ValueNotifier<DateTime>(DateTime.now());

  final _isLoading = ValueNotifier<bool>(false);
  final _data = ValueNotifier<Map<String, dynamic>?>(null);
  final _error = ValueNotifier<String>('');
  final _branches = ValueNotifier<List<dynamic>>([]);
  final _selectedBranchId = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadData();
  }

  @override
  void dispose() {
    _fromDate.dispose();
    _toDate.dispose();
    _isLoading.dispose();
    _data.dispose();
    _error.dispose();
    _branches.dispose();
    _selectedBranchId.dispose();
    super.dispose();
  }

  String get _fromStr => DateFormat('dd-MM-yyyy').format(_fromDate.value);
  String get _toStr => DateFormat('dd-MM-yyyy').format(_toDate.value);

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin || auth.token == null) return;
    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (mounted && res['success'] == true) {
        _branches.value = res['branches'] ?? [];
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    _isLoading.value = true;
    _error.value = '';
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getStaffIncomeReport(
        token,
        _fromStr,
        _toStr,
        branchId: _selectedBranchId.value,
      );
      if (res['success'] == true) {
        _data.value = res;
      } else {
        _error.value = res['message'] ?? 'Failed to load report';
      }
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate.value : _toDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (isFrom) {
        _fromDate.value = picked;
      } else {
        _toDate.value = picked;
      }
      _loadData();
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return '0.00';
    final d = double.tryParse(val.toString()) ?? 0.0;
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          context.tr('Staff Income Report'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, _) {
          return Column(
            children: [
              _buildFilterHeader(),
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF000080)),
                  ),
                )
              else
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _error,
                    builder: (context, error, _) {
                      if (error.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              error,
                              style: GoogleFonts.inter(color: Colors.red, fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return ValueListenableBuilder<Map<String, dynamic>?>(
                        valueListenable: _data,
                        builder: (context, data, _) {
                          if (data == null) {
                            return const SizedBox.shrink();
                          }
                          final summary = data['summary'] as Map<String, dynamic>? ?? {};
                          final staffs = (data['staffs'] as List<dynamic>? ?? []);

                          return RefreshIndicator(
                            onRefresh: _loadData,
                            color: const Color(0xFF000080),
                            child: ListView(
                              padding: EdgeInsets.all(16.r),
                              children: [
                                _buildKpiGrid(summary, currencySymbol),
                                SizedBox(height: 16.h),
                                Text(
                                  context.tr('Staff Performance Breakdown'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                if (staffs.isEmpty)
                                  Container(
                                    padding: EdgeInsets.all(32.r),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: Text(
                                      context.tr('No staff revenue records found in selected range.'),
                                      style: GoogleFonts.inter(color: Colors.grey.shade500),
                                    ),
                                  )
                                else
                                  ...staffs.map((st) => _buildStaffCard(st, currencySymbol)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader() {
    final auth = context.read<AuthProvider>();
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _fromDate,
                  builder: (context, date, _) {
                    return _dateButton(
                      label: context.tr('From'),
                      dateStr: DateFormat('dd MMM yyyy').format(date),
                      onTap: () => _pickDate(isFrom: true),
                    );
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _toDate,
                  builder: (context, date, _) {
                    return _dateButton(
                      label: context.tr('To'),
                      dateStr: DateFormat('dd MMM yyyy').format(date),
                      onTap: () => _pickDate(isFrom: false),
                    );
                  },
                ),
              ),
            ],
          ),
          if (auth.isCompanyAdmin) ...[
            SizedBox(height: 8.h),
            ValueListenableBuilder<List<dynamic>>(
              valueListenable: _branches,
              builder: (context, branchList, _) {
                if (branchList.isEmpty) return const SizedBox.shrink();
                return ValueListenableBuilder<String?>(
                  valueListenable: _selectedBranchId,
                  builder: (context, selId, _) {
                    return DropdownButtonFormField<String?>(
                      value: selId,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Branch'),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(context.tr('All Branches')),
                        ),
                        ...branchList.map((b) {
                          return DropdownMenuItem<String?>(
                            value: b['id'].toString(),
                            child: Text(b['name'].toString()),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        _selectedBranchId.value = val;
                        _loadData();
                      },
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required String dateStr,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16.sp, color: const Color(0xFF000080)),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.grey.shade600)),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> summary, String currencySymbol) {
    final totalStaffs = summary['total_staffs'] ?? 0;
    final totalInvoices = summary['total_invoices'] ?? 0;
    final grandTotal = summary['grand_total_income'] ?? '0.00';
    final grandSplit = summary['grand_split_income'] ?? '0.00';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10.w,
      mainAxisSpacing: 10.h,
      childAspectRatio: 1.6,
      children: [
        _kpiCard(context.tr('Active Staffs'), '$totalStaffs', Icons.people_alt_outlined, const Color(0xFF000080), const Color(0xFFEFF6FF)),
        _kpiCard(context.tr('Invoices Handled'), '$totalInvoices', Icons.receipt_long_outlined, const Color(0xFF10B981), const Color(0xFFECFDF5)),
        _kpiCard(context.tr('Total Invoice Value'), '$currencySymbol ${_fmt(grandTotal)}', Icons.monetization_on_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
        _kpiCard(context.tr('Attributed Share'), '$currencySymbol ${_fmt(grandSplit)}', Icons.pie_chart_outline, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8.r)),
                child: Icon(icon, color: color, size: 18.sp),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff, String currencySymbol) {
    final name = (staff['name'] ?? '').toString();
    final empId = (staff['employee_id'] ?? '').toString();
    final desig = (staff['designation'] ?? '').toString();
    final branchName = (staff['branch_name'] ?? '').toString();
    final invCount = staff['invoice_count'] ?? 0;
    final splitIncome = staff['split_income'] ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StaffInvoiceDetailsScreen(
              staffData: staff,
              fromDateStr: _fromStr,
              toDateStr: _toStr,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: const Color(0xFF000080),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                        ),
                      ),
                      if (empId.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6.r)),
                          child: Text(empId, style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      if (desig.isNotEmpty)
                        Text('$desig • ', style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600)),
                      if (branchName.isNotEmpty)
                        Text(branchName, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF000080), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currencySymbol ${_fmt(splitIncome)}',
                  style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                ),
                Text(
                  '$invCount invoices',
                  style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500),
                ),
              ],
            ),
            SizedBox(width: 6.w),
            Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

}
