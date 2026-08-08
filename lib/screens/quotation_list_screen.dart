import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'quotation_search_screen.dart';
import 'quotation_create_screen.dart';
import 'quotation_view_screen.dart';

class QuotationListScreen extends StatefulWidget {
  const QuotationListScreen({super.key});

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return CountryConfig.currencySymbol;
    }
  }

  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _allQuotations = [];
  List<dynamic> _filteredQuotations = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadQuotations();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredQuotations = List.from(_allQuotations);
      });
    } else {
      setState(() {
        _filteredQuotations = _allQuotations.where((q) {
          final qNum = (q['quotation_number'] ?? '').toString().toLowerCase();
          final cName = (q['customer_name'] ?? '').toString().toLowerCase();
          final cPhone = (q['customer_phone'] ?? '').toString().toLowerCase();
          final vNum = (q['vehicle_number'] ?? '').toString().toLowerCase();
          return qNum.contains(query) || cName.contains(query) || cPhone.contains(query) || vNum.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadQuotations() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getQuotationList(token);
      if (res['success'] == true) {
        final rawList = res['quotations'] as List<dynamic>? ?? [];
        final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() {
          _allQuotations = list;
          _filteredQuotations = List.from(list);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load quotations';
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

  Future<void> _openEditQuotation(String quotationId) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.getQuotationDetail(quotationId, token);
      if (mounted) Navigator.pop(context); // dismiss loader

      if (res['success'] == true && res['quotation'] != null) {
        final qDetail = Map<String, dynamic>.from(res['quotation'] as Map);
        final customer = {
          'id': qDetail['customer_id'],
          'name': qDetail['customer_name'],
          'phone': qDetail['customer_phone'],
          'type': qDetail['customer_type'],
        };
        final vehicle = {
          'id': qDetail['vehicle_id'],
          'no': qDetail['vehicle_number'],
          'type': qDetail['vehicle_type'],
        };

        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationCreateScreen(
              customer: customer,
              vehicle: vehicle,
              existingQuotation: qDetail,
            ),
          ),
        );
        if (updated == true || updated != null) {
          _loadQuotations();
        }
      } else {
        _snack(res['message'] ?? 'Failed to fetch quotation details', isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack(e.toString(), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Quotations'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuotationSearchScreen()),
          );
          if (result == true || result != null) {
            _loadQuotations();
          }
        },
        backgroundColor: const Color(0xFF000080),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('Create Quotation'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search Header Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('Search by quotation #, customer, vehicle...'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF000080)),
                  onPressed: _loadQuotations,
                ),
              ],
            ),
          ),

          // Quotation List Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                    : _filteredQuotations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.request_quote_outlined, size: 72, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  context.tr('No quotations found'),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const QuotationSearchScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: Text(context.tr('Create First Quotation')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000080),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadQuotations,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredQuotations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final q = _filteredQuotations[index];
                                return _buildQuotationCard(q);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Widget _buildQuotationCard(Map<String, dynamic> q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Quotation # & Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF000080).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q['quotation_number'] ?? '',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF000080), fontSize: 14.sp),
                ),
              ),
              Text(
                '$currencySymbol${_parseDouble(q['grand_total']).toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF000080), fontSize: 18.sp),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer Details
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                q['customer_name'] ?? '',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15.sp, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(width: 8),
              Text(
                '(${q['customer_phone'] ?? ''})',
                style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Vehicle & Branch details
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                q['vehicle_number'] ?? '',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp, color: const Color(0xFF334155)),
              ),
              if (q['branch_name'] != null && q['branch_name'].toString().isNotEmpty) ...[
                Text(' · ', style: TextStyle(color: Colors.grey.shade400)),
                Text(
                  q['branch_name'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          Text(
            '${context.tr("Date")}: ${q['created_at'] ?? ''}',
            style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade500),
          ),
          const Divider(height: 20),

          // Action Buttons: View & Edit
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuotationViewScreen(quotationId: q['id']),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF000080)),
                label: Text(context.tr('View'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF000080),
                  side: const BorderSide(color: Color(0xFF000080)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openEditQuotation(q['id']),
                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                label: Text(context.tr('Edit'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
