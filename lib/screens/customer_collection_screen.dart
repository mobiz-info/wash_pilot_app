import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'customer_invoices_collection_screen.dart';

class CustomerCollectionScreen extends StatefulWidget {
  const CustomerCollectionScreen({super.key});

  @override
  State<CustomerCollectionScreen> createState() => _CustomerCollectionScreenState();
}

class _CustomerCollectionScreenState extends State<CustomerCollectionScreen> {
  final _customers = ValueNotifier<List<dynamic>>([]);
  final _totalOutstanding = ValueNotifier<double>(0);
  final _loading = ValueNotifier<bool>(true);
  final _error = ValueNotifier<String>('');
  final _search = ValueNotifier<String>('');
  final _branches = ValueNotifier<List<dynamic>>([]);
  final _selectedBranchId = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchOutstanding();
  }

  @override
  void dispose() {
    _customers.dispose();
    _totalOutstanding.dispose();
    _loading.dispose();
    _error.dispose();
    _search.dispose();
    _branches.dispose();
    _selectedBranchId.dispose();
    super.dispose();
  }

  Future<void> _fetchOutstanding() async {
    _loading.value = true;
    _error.value = '';
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      _error.value = 'Not authenticated';
      _loading.value = false;
      return;
    }
    try {
      final res = await ApiService.getCustomerOutstandingList(
        token,
        branchId: _selectedBranchId.value,
      );
      if (res['success'] == true) {
        _customers.value = res['customers'] ?? [];
        _totalOutstanding.value =
            double.tryParse(res['total_outstanding'] ?? '0') ?? 0;
        _loading.value = false;
      } else {
        _error.value = res['message'] ?? 'Failed to load';
        _loading.value = false;
      }
    } catch (e) {
      _error.value = 'Network error: $e';
      _loading.value = false;
    }
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin || auth.token == null) return;

    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (!mounted || res['success'] != true) return;
      _branches.value = res['branches'] ?? [];
    } catch (_) {}
  }

  List<dynamic> get _filteredCustomers {
    if (_search.value.trim().isEmpty) return _customers.value;
    final q = _search.value.toLowerCase();
    return _customers.value.where((c) {
      final name = (c['customer_name'] ?? '').toLowerCase();
      final phone = (c['customer_phone'] ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _loading,
      builder: (context, loading, _) => ValueListenableBuilder<String>(
        valueListenable: _error,
        builder: (context, errorMsg, _) => ValueListenableBuilder<String>(
          valueListenable: _search,
          builder: (context, searchVal, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _customers,
            builder: (context, customersList, _) => ValueListenableBuilder<double>(
              valueListenable: _totalOutstanding,
              builder: (context, totalOutstandingVal, _) {
                final filtered = _filteredCustomers;
                final currencySymbol = context.watch<AuthProvider>().currencySymbol;
                final isCompanyAdmin = context.watch<AuthProvider>().isCompanyAdmin;

                return Scaffold(
                  backgroundColor: const Color(0xFFf8fafc),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    title: Text(
                      context.tr('Collection'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchOutstanding,
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      if (isCompanyAdmin)
                        Container(
                          color: const Color(0xFF000080),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                          child: ValueListenableBuilder<String?>(
                            valueListenable: _selectedBranchId,
                            builder: (context, branchId, _) => _branchDropdown(branchId),
                          ),
                        ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: TextField(
                          onChanged: (v) => _search.value = v,
                          decoration: InputDecoration(
                            hintText: context.tr('Search by customer or phone'),
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF94a3b8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: Color(0xFF94a3b8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFf1f5f9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),

                      if (loading)
                        const Expanded(
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFF000080)),
                          ),
                        )
                      else if (errorMsg.isNotEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  errorMsg,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(color: Colors.red),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchOutstanding,
                                  child: Text(context.tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: searchVal.isNotEmpty ? Colors.grey : Colors.green,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchVal.isNotEmpty
                                      ? 'No results for "$searchVal"'
                                      : 'No outstanding balances!',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748b),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchOutstanding,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final c = filtered[i];
                                final outstanding =
                                    double.tryParse(c['total_outstanding']?.toString() ?? '0') ?? 0;
                                final count = c['invoices_count'] ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF000080).withValues(alpha: 0.12),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF000080).withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CustomerInvoicesCollectionScreen(
                                                customerId: c['customer_id'],
                                                customerName: c['customer_name'],
                                                customerPhone: c['customer_phone'],
                                                totalOutstanding: outstanding,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            _fetchOutstanding();
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 22,
                                                backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                                                child: const Icon(Icons.person, color: Color(0xFF000080)),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      c['customer_name'] ?? '',
                                                      style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                        color: const Color(0xFF1e293b),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      c['customer_phone'] ?? '',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        color: const Color(0xFF94a3b8),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade50,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: Colors.orange.shade100),
                                                      ),
                                                      child: Text(
                                                        '$count ${context.tr('unpaid invoices')}',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.orange.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFfef2f2),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: const Color(0xFFfecaca),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '$currencySymbol${outstanding.toStringAsFixed(2)}',
                                                      style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 14,
                                                        color: const Color(0xFFdc2626),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        context.tr('Collect'),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF000080),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 2),
                                                      const Icon(
                                                        Icons.arrow_forward_ios,
                                                        size: 11,
                                                        color: Color(0xFF000080),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      if (!loading && errorMsg.isEmpty && filtered.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Total Outstanding'),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748b),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '$currencySymbol${totalOutstandingVal.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFdc2626),
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _branchDropdown(String? selectedBranchId) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _branches,
      builder: (context, branchesList, _) => DropdownButtonFormField<String>(
        value: selectedBranchId,
        isExpanded: true,
        menuMaxHeight: 350,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        hint: Text(context.tr('All branches')),
        items: [
          DropdownMenuItem<String>(value: '', child: Text(context.tr('All branches'))),
          ...branchesList.map((branch) {
            final item = Map<String, dynamic>.from(branch as Map);
            return DropdownMenuItem<String>(
              value: item['id']?.toString() ?? '',
              child: Text(item['name']?.toString() ?? ''),
            );
          }),
        ],
        onChanged: (value) {
          _selectedBranchId.value = value == null || value.isEmpty ? null : value;
          _fetchOutstanding();
        },
      ),
    );
  }
}
