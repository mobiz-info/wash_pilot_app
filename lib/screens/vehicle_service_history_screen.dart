import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _history = [];
  Map<String, dynamic> _nextService = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getVehicleServiceHistory(widget.vehicleId, token);
      if (res['success'] == true) {
        setState(() {
          _history = res['history'] ?? [];
          _nextService = res['next_service'] ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load history';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('Recent Service Jobs'),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                      ),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        _buildEmptyState()
                      else
                        ..._history.map((job) => _buildJobCard(job as Map<String, dynamic>)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    final int odo = _nextService['current_odometer_km'] ?? 0;
    final int? nextOil = _nextService['next_oil_change_km'];
    final int? nextTyre = _nextService['next_tyre_change_km'];
    final String? lastOilDate = _nextService['last_oil_change_date'];
    final String? lastTyreDate = _nextService['last_tyre_change_date'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Vehicle Health Summary'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF000080)),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF000080)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(label), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(context.tr(val), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, color: categoryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(serviceName),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1e293b)),
                      ),
                      Text(
                        '#$invoiceNumber · $date',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${context.read<AuthProvider>().currencySymbol}${job['rate']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF000080)),
              ),
            ],
          ),

          // Custom details per category
          if (category == 'oil_change') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailItem('Brand', job['tyre_brand']),
                  _detailItem('Size', job['tyre_size']),
                  _detailItem('Qty Changed', job['tyres_count'] > 0 ? '${job['tyres_count']}' : null),
                  _detailItem('Next Schedule due', job['next_tyre_change_km'] != null ? 'at ${job['next_tyre_change_km']} km' : null),
                ],
              ),
            ),
          ] else if (category == 'wheel_alignment') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr(label), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
          Text(context.tr(val.toString()), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            context.tr('No service history found for this vehicle.'),
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
