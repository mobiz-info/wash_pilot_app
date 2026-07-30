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
        _history.value = res['history'] ?? [];
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
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error.isNotEmpty
                      ? Center(child: Text(error, style: const TextStyle(color: Colors.red)))
                      : SingleChildScrollView(
                          padding: REdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSummaryCard(nextSvc),
                              SizedBox(height: 16.h),
                              Text(
                                context.tr('Recent Service Jobs'),
                                style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                              ),
                              SizedBox(height: 10.h),
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

  Widget _buildSummaryCard(Map<String, dynamic> nextService) {
    final int odo = nextService['current_odometer_km'] ?? 0;
    final int? nextOil = nextService['next_oil_change_km'];
    final int? nextTyre = nextService['next_tyre_change_km'];
    final String? lastOilDate = nextService['last_oil_change_date'];
    final String? lastTyreDate = nextService['last_tyre_change_date'];

    return Container(
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10.r, offset: Offset(0, 3.h))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Vehicle Health Summary'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF000080)),
          ),
          SizedBox(height: 12.h),
          _summaryRow(Icons.speed, 'Current Odometer', odo > 0 ? '$odo km' : 'Not recorded'),
          const Divider(),
          _summaryRow(Icons.oil_barrel, 'Oil Status', nextOil != null ? 'Next due at $nextOil km\n(Last: ${lastOilDate ?? "N/A"})' : 'Not scheduled'),
          const Divider(),
          _summaryRow(Icons.circle_outlined, 'Tyre Status', nextTyre != null ? 'Next due at $nextTyre km\n(Last: ${lastTyreDate ?? "N/A"})' : 'Not scheduled'),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String val) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 20.r, color: const Color(0xFF000080)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(label), style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(context.tr(val), style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final category = job['category']?.toString() ?? 'washing';
    final serviceName = job['service_name'] ?? 'Car Wash';
    final date = job['date'] ?? '';
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
                  Container(
                    padding: REdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 20.r),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(serviceName),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14.sp, color: const Color(0xFF1e293b)),
                      ),
                      Text(
                        '#$invoiceNumber · $date',
                        style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${context.read<AuthProvider>().currencySymbol}${job['rate']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.sp, color: const Color(0xFF000080)),
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
            SizedBox(height: 10.h),
            Container(
              padding: REdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailItem('Alignment', job['alignment_done'] == true ? 'Done' : 'Skipped'),
                  _detailItem('Balancing', job['balancing_done'] == true ? 'Done' : 'Skipped'),
                  _detailItem('Odometer', job['odometer'] != null ? '${job['odometer']} km' : null),
                  _detailItem('Remarks', job['notes']),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailItem(String label, dynamic val) {
    if (val == null || val.toString().trim().isEmpty) return const SizedBox.shrink();
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
