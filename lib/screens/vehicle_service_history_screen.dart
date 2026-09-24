import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class VehicleServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final String vehicleNumber;

  const VehicleServiceHistoryScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
  });

  @override
  State<VehicleServiceHistoryScreen> createState() => _VehicleServiceHistoryScreenState();
}

class _VehicleServiceHistoryScreenState extends State<VehicleServiceHistoryScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  final _history = ValueNotifier<List<dynamic>>([]);
  final _nextService = ValueNotifier<Map<String, dynamic>>({});

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _errorMessage.dispose();
    _history.dispose();
    _nextService.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getVehicleServiceHistory(widget.vehicleId, token);
      if (res['success'] == true) {
        final List<dynamic> list = List.from(res['history'] ?? []);
        list.sort((a, b) {
          final dateA = a['date']?.toString() ?? '';
          final dateB = b['date']?.toString() ?? '';
          final invA = a['invoice_number']?.toString() ?? '';
          final invB = b['invoice_number']?.toString() ?? '';
          final comp = dateB.compareTo(dateA);
          if (comp == 0) {
            return invB.compareTo(invA);
          }
          return comp;
        });
        _history.value = list;
        _nextService.value = res['next_service'] ?? {};
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load history';
        _isLoading.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, loading, _) => ValueListenableBuilder<String>(
        valueListenable: _errorMessage,
        builder: (context, error, _) => ValueListenableBuilder<List<dynamic>>(
          valueListenable: _history,
          builder: (context, history, _) => ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: _nextService,
            builder: (context, nextSvc, _) => Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                title: Text(
                  '${context.tr('Service History')} — ${widget.vehicleNumber}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                backgroundColor: Color(0xFF000080),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: loading
                  ? Center(child: CircularProgressIndicator())
                  : error.isNotEmpty
                      ? Center(child: Text(error, style: TextStyle(color: Colors.red)))
                      : SingleChildScrollView(
                          padding: REdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (history.isEmpty)
                                _buildEmptyState()
                              else
                                ...history.map((job) => _buildJobCard(job as Map<String, dynamic>)),
                            ],
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final category = job['category']?.toString() ?? 'washing';
    final serviceName = job['service_name'] ?? 'Car Wash';
    final rawDate = job['date']?.toString() ?? '';
    final formattedInvoiceDate = _formatDateStr(rawDate);
    final invoiceNumber = job['invoice_number'] ?? '';

    Color categoryColor = Colors.blue;
    IconData categoryIcon = Icons.local_car_wash;

    if (category == 'oil_change') {
      categoryColor = Colors.amber;
      categoryIcon = Icons.oil_barrel;
    } else if (category == 'tyre_change') {
      categoryColor = Colors.red;
      categoryIcon = Icons.circle_outlined;
    } else if (category == 'wheel_alignment') {
      categoryColor = Colors.green;
      categoryIcon = Icons.build_circle_outlined;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Container(
                  //   padding: REdgeInsets.all(8),
                  //   decoration: BoxDecoration(
                  //     color: categoryColor.withOpacity(0.08),
                  //     shape: BoxShape.circle,
                  //   ),
                  //   child: Icon(categoryIcon, color: categoryColor, size: 20.r),
                  // ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(serviceName),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.sp, color: Color(0xFF1e293b)),
                      ),
                      Text(
                        '$invoiceNumber · $formattedInvoiceDate',
                        style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${context.read<AuthProvider>().currencySymbol}${job['rate']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Color(0xFF000080)),
              ),
            ],
          ),

          // Custom details per category
          if (category == 'oil_change') ...[
            SizedBox(height: 10.h),
            Container(
              padding: REdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailItem('Oil Product', job['oil_product']),
                  _detailItem('Quantity', job['oil_litres'] > 0 ? '${job['oil_litres']} L' : null),
                  _detailItem('Filter Replaced', job['oil_filter_changed'] == true ? 'Yes' : 'No'),
                  _detailItem('Odometer reading', job['odometer'] != null ? '${job['odometer']} km' : null),
                  _detailItem('Next Schedule due', job['next_oil_change_km'] != null ? 'at ${job['next_oil_change_km']} km' : null),
                ],
              ),
            ),
          ] else if (category == 'tyre_change') ...[
            SizedBox(height: 10.h),
            Container(
              padding: REdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job['tyre_items'] is List && (job['tyre_items'] as List).isNotEmpty)
                    for (final item in (job['tyre_items'] as List))
                      _detailItem(
                        item['position'] ?? 'Tyre',
                        '${item['brand'] ?? ""} ${item['name'] ?? ""} ${item['size'] ?? ""} x${item['quantity'] ?? 1}',
                      )
                  else ...[
                    _detailItem('Brand', job['tyre_brand']),
                    _detailItem('Size', job['tyre_size']),
                    _detailItem('Qty Changed', (job['tyres_count'] != null && job['tyres_count'] > 0) ? '${job['tyres_count']}' : null),
                  ],
                  _detailItem('Next Schedule due', job['next_tyre_change_km'] != null ? 'at ${job['next_tyre_change_km']} km' : null),
                ],
              ),
            ),
          ] else if (category == 'wheel_alignment') ...[
            if (job['odometer'] != null || (job['notes'] != null && job['notes'].toString().isNotEmpty)) ...[
              SizedBox(height: 10.h),
              Container(
                padding: REdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8.r)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailItem('Odometer', job['odometer'] != null ? '${job['odometer']} km' : null),
                    _detailItem('Remarks', job['notes']),
                  ],
                ),
              ),
            ],
          ],

          // Reminder dates section
          _buildRemindersCard(job),
        ],
      ),
    );
  }

  String _formatDateStr(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3 && parts[0].length == 4) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildRemindersCard(Map<String, dynamic> job) {
    final List<dynamic> reminders = job['reminders'] is List ? (job['reminders'] as List) : [];
    final String? nextSmokeDate = job['next_smoke_test_date']?.toString();
    final String? reminder1Date = job['reminder_1_date']?.toString();
    final String? reminder2Date = job['reminder_2_date']?.toString();
    final dynamic nextOilKm = job['next_oil_change_km'];
    final dynamic nextAlignKm = job['next_alignment_km'];
    final dynamic nextTyreKm = job['next_tyre_change_km'];

    final bool hasReminders = reminders.isNotEmpty ||
        (nextSmokeDate != null && nextSmokeDate.isNotEmpty) ||
        (reminder1Date != null && reminder1Date.isNotEmpty) ||
        (reminder2Date != null && reminder2Date.isNotEmpty) ||
        nextOilKm != null ||
        nextAlignKm != null ||
        nextTyreKm != null;

    if (!hasReminders) return const SizedBox.shrink();

    final Set<String> shownDates = {};

    return Container(
      margin: EdgeInsets.only(top: 10.h),
      padding: REdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 16.r, color: const Color(0xFF000080)),
              SizedBox(width: 6.w),
              Text(
                context.tr('Service Reminders'),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000080),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          if (nextSmokeDate != null && nextSmokeDate.isNotEmpty) ...[
            _reminderDateRow('Next Renewal Date', _formatDateStr(nextSmokeDate), color: Colors.purple.shade900),
            if (reminder1Date != null && reminder1Date.isNotEmpty)
              _reminderDateRow('1st Reminder (15 days before)', _formatDateStr(reminder1Date), color: Colors.purple.shade700),
            if (reminder2Date != null && reminder2Date.isNotEmpty)
              _reminderDateRow('2nd Reminder (3 days before)', _formatDateStr(reminder2Date), color: Colors.purple.shade700),
          ],
          if (nextOilKm != null)
            _reminderDateRow('Next Oil Change Due', '$nextOilKm km', color: Colors.amber.shade900),
          if (nextAlignKm != null)
            _reminderDateRow('Next Alignment Due', '$nextAlignKm km', color: Colors.green.shade900),
          if (nextTyreKm != null)
            _reminderDateRow('Next Tyre Change Due', '$nextTyreKm km', color: Colors.red.shade900),

          for (final rem in reminders) ...[
            if (rem['scheduled_date'] != null && rem['scheduled_date'].toString().isNotEmpty) ...[
              if (rem['scheduled_date'] != reminder1Date &&
                  rem['scheduled_date'] != reminder2Date &&
                  rem['scheduled_date'] != nextSmokeDate &&
                  !shownDates.contains(rem['scheduled_date'].toString())) ...[
                Builder(
                  builder: (ctx) {
                    shownDates.add(rem['scheduled_date'].toString());
                    return _reminderDateRow(
                      'Scheduled Reminder ${rem['reminder_no'] ?? 1}${rem['is_sent'] == true ? ' (Sent)' : ''}',
                      _formatDateStr(rem['scheduled_date'].toString()),
                      color: rem['is_sent'] == true ? Colors.grey.shade700 : const Color(0xFF000080),
                    );
                  },
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _reminderDateRow(String label, String dateVal, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.tr(label),
            style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade700),
          ),
          Text(
            dateVal,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, dynamic val) {
    if (val == null || val.toString().trim().isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr(label), style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600)),
          Text(context.tr(val.toString()), style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: REdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.history, size: 60.r, color: Colors.grey.shade300),
          SizedBox(height: 12.h),
          Text(
            context.tr('No service history found for this vehicle.'),
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}
