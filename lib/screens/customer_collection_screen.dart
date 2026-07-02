import 'package:flutter/material.dart';
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
  List<dynamic> _customers = [];
  double _totalOutstanding = 0;
  bool _loading = true;
  String _error = '';
  String _search = '';
  List<dynamic> _branches = [];
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchOutstanding();
  }

  Future<void> _fetchOutstanding() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() {
        _error = 'Not authenticated';
        _loading = false;
      });
      return;
    }
    try {
      final res = await ApiService.getCustomerOutstandingList(
        token,
        branchId: _selectedBranchId,
      );
      if (res['success'] == true) {
        setState(() {
          _customers = res['customers'] ?? [];
          _totalOutstanding =
              double.tryParse(res['total_outstanding'] ?? '0') ?? 0;
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin || auth.token == null) return;

    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (!mounted || res['success'] != true) return;
      setState(() => _branches = res['branches'] ?? []);
    } catch (_) {}
  }

  List<dynamic> get _filteredCustomers {
    if (_search.trim().isEmpty) return _customers;
    final q = _search.toLowerCase();
    return _customers.where((c) {
      final name = (c['customer_name'] ?? '').toLowerCase();
      final phone = (c['customer_phone'] ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
          // Filter section (only shown if company admin has branch choices)
          if (isCompanyAdmin)
            Container(
              color: const Color(0xFF000080),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: _branchDropdown(),
            ),
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
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

          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF000080)),
              ),
            )
          else if (_error.isNotEmpty)
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
                      _error,
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
                      color: _search.isNotEmpty ? Colors.grey : Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _search.isNotEmpty
                          ? 'No results for "$_search"'
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

          // Total outstanding footer
          if (!_loading && _error.isEmpty && filtered.isNotEmpty)
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
                    '$currencySymbol${_totalOutstanding.toStringAsFixed(2)}',
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
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
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
        ..._branches.map((branch) {
          final item = Map<String, dynamic>.from(branch as Map);
          return DropdownMenuItem<String>(
            value: item['id']?.toString() ?? '',
            child: Text(item['name']?.toString() ?? ''),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value == null || value.isEmpty ? null : value;
        });
        _fetchOutstanding();
      },
    );
  }
}
