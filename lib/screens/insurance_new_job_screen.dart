import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'invoice_create_screen.dart';

class InsuranceNewJobScreen extends StatefulWidget {
  const InsuranceNewJobScreen({super.key});

  @override
  State<InsuranceNewJobScreen> createState() => _InsuranceNewJobScreenState();
}

class _InsuranceNewJobScreenState extends State<InsuranceNewJobScreen> {
  final _searchController = TextEditingController();
  final _searchResults = ValueNotifier<List<dynamic>>([]);
  final _isSearching = ValueNotifier<bool>(false);
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchResults.dispose();
    _isSearching.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = value.trim();
    if (text.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
    } else {
      _searchResults.value = [];
    }
  }

  Future<void> _search(String q) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isSearching.value = true;
    try {
      final res = await ApiService.insuranceCustomerSearch(token, search: q);
      if (res['success'] == true) {
        _searchResults.value = List<dynamic>.from(res['customers'] ?? []);
      }
    } catch (_) {
      _searchResults.value = [];
    } finally {
      _isSearching.value = false;
    }
  }

  void _openInvoiceCreate(Map<String, dynamic> customer, {Map<String, dynamic>? vehicle}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceCreateScreen(
          customer: customer,
          vehicle: vehicle ?? {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Insurance — New Job',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: const Color(0xFF000080),
            padding: REdgeInsets.fromLTRB(16, 0, 16, 20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or vehicle…',
                hintStyle: GoogleFonts.inter(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: REdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Results ─────────────────────────────────────────────────────
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSearching,
              builder: (_, searching, __) {
                if (searching) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _searchResults,
                  builder: (_, results, __) {
                    if (_searchController.text.trim().isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.search,
                        title: 'Search for a Customer',
                        subtitle: 'Enter name, phone, or vehicle number above',
                      );
                    }
                    if (results.isEmpty) {
                      return Column(
                        children: [
                          _buildEmptyState(
                            icon: Icons.person_search_outlined,
                            title: 'No customer found',
                            subtitle: 'Try a different search term or add a new customer',
                          ),
                          Padding(
                            padding: REdgeInsets.symmetric(horizontal: 24),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final created = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddCustomerScreen()),
                                );
                                if (created is Map<String, dynamic>) {
                                  _openInvoiceCreate(created);
                                }
                              },
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text('Add New Customer',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000080),
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 50.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: REdgeInsets.all(16),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, i) {
                        final c = results[i] as Map<String, dynamic>;
                        final vehicles = (c['vehicles'] as List<dynamic>? ?? []);
                        return _CustomerResultCard(
                          customer: c,
                          vehicles: vehicles,
                          onTapCustomer: () => _openInvoiceCreate(c),
                          onTapVehicle: (v) => _openInvoiceCreate(c, vehicle: v),
                        );
                      },
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: REdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64.r, color: Colors.grey.shade300),
            SizedBox(height: 16.h),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
            SizedBox(height: 8.h),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13.sp, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _CustomerResultCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<dynamic> vehicles;
  final VoidCallback onTapCustomer;
  final void Function(Map<String, dynamic>) onTapVehicle;

  const _CustomerResultCard({
    required this.customer,
    required this.vehicles,
    required this.onTapCustomer,
    required this.onTapVehicle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8.r,
              offset: Offset(0, 2.h)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Customer info row ──────────────────────────────────────────
          InkWell(
            onTap: onTapCustomer,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
            child: Padding(
              padding: REdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: const Color(0xFF000080).withOpacity(0.1),
                    child: Text(
                      (customer['name'] ?? '?').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF000080),
                          fontSize: 16.sp),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name'] ?? '',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                              color: const Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          customer['phone'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 13.sp, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: REdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text('New Job',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp)),
                  ),
                ],
              ),
            ),
          ),

          // ── Vehicle pills ──────────────────────────────────────────────
          if (vehicles.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: REdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select vehicle:',
                      style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 6.h,
                    children: vehicles.map((v) {
                      final vMap = v as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => onTapVehicle(vMap),
                        child: Container(
                          padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080).withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                                color: const Color(0xFF000080).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car,
                                  size: 14.r,
                                  color: const Color(0xFF000080)),
                              SizedBox(width: 4.w),
                              Text(vMap['vehicle_number'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF000080))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
