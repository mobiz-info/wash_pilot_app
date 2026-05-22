import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<dynamic> _invoices = [];
  double _totalOutstanding = 0;
  bool _loading = true;
  String _error = '';
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  List<dynamic> _branches = [];
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _loadBranches();
    _fetchOutstanding();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF000080),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
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
      final res = await ApiService.getOutstandingList(
        token,
        fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
        toDate: _toDate != null ? _formatDate(_toDate!) : null,
        branchId: _selectedBranchId,
      );
      if (res['success'] == true) {
        setState(() {
          _invoices = res['invoices'] ?? [];
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
    } catch (_) {
      // Branch filter is optional; outstanding can still load all branches.
    }
  }

  List<dynamic> get _filteredInvoices {
    if (_search.trim().isEmpty) return _invoices;
    final q = _search.toLowerCase();
    return _invoices.where((inv) {
      final name = (inv['customer']['name'] ?? '').toLowerCase();
      final phone = (inv['customer']['phone'] ?? '').toLowerCase();
      final num = (inv['invoice_number'] ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || num.contains(q);
    }).toList();
  }

  void _showCollectModal(Map inv) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    final outstanding = double.tryParse(inv['outstanding']) ?? 0;
    final amtController = TextEditingController(
      text: outstanding.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Collect Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1e293b),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Invoice #${inv['invoice_number']}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
              ),
              const SizedBox(height: 16),
              // Outstanding info
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFfef2f2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFfecaca)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748b),
                      ),
                    ),
                    Text(
                      '$currencySymbol${outstanding.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFdc2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Amount to Collect ($currencySymbol)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: amtController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  prefixText: '$currencySymbol ',
                  hintText: '0.00',
                  filled: true,
                  fillColor: const Color(0xFFf8fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFd1d5db)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF000080),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: StatefulBuilder(
                  builder: (ctx, setModalState) {
                    bool collecting = false;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000080),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: collecting
                          ? null
                          : () async {
                              final amt = double.tryParse(
                                amtController.text.trim(),
                              );
                              if (amt == null || amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid amount'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (amt > outstanding) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Amount exceeds outstanding $currencySymbol${outstanding.toStringAsFixed(2)}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => collecting = true);
                              try {
                                final token =
                                    context.read<AuthProvider>().token ?? '';
                                final res = await ApiService.collectPayment(
                                  invoiceId: inv['id'],
                                  amount: amt,
                                  token: token,
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                                if (res['success'] == true) {
                                  final settled = res['fully_settled'] == true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        settled
                                            ? '✓ Invoice fully settled!'
                                            : '$currencySymbol${amt.toStringAsFixed(2)} collected. Remaining: $currencySymbol${res['remaining_outstanding']}',
                                      ),
                                      backgroundColor: settled
                                          ? Colors.green
                                          : Colors.blue,
                                    ),
                                  );
                                  _fetchOutstanding();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Failed'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      child: collecting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirm Collection',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInvoices;
    final currencySymbol = context.watch<AuthProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        title: const Text(
          'Outstanding',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _datePicker(
                        label: 'From',
                        date: _fromDate,
                        isFrom: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _datePicker(
                        label: 'To',
                        date: _toDate,
                        isFrom: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _fetchOutstanding,
                      child: Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Color(0xFF000080),
                        ),
                      ),
                    ),
                  ],
                ),
                if (context.watch<AuthProvider>().isCompanyAdmin) ...[
                  const SizedBox(height: 12),
                  _branchDropdown(),
                ],
              ],
            ),
          ),
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by customer, phone or invoice #',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94a3b8),
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
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchOutstanding,
                      child: const Text('Retry'),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748b),
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
                    final inv = filtered[i];
                    final outstanding =
                        double.tryParse(inv['outstanding']) ?? 0;
                    final total = double.tryParse(inv['total']) ?? 0;
                    final collected =
                        double.tryParse(inv['amount_collected']) ?? 0;
                    final progress = total > 0 ? collected / total : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer + invoice header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inv['customer']['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF1e293b),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        inv['customer']['phone'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94a3b8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: Color(0xFFdc2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Invoice details row
                            Row(
                              children: [
                                _chip(
                                  Icons.receipt_outlined,
                                  '#${inv['invoice_number']}',
                                ),
                                const SizedBox(width: 8),
                                _chip(
                                  Icons.directions_car_outlined,
                                  inv['vehicle']['number'] ?? '',
                                ),
                                const SizedBox(width: 8),
                                _chip(
                                  Icons.calendar_today_outlined,
                                  inv['date'] ?? '',
                                ),
                                if ((inv['branch'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  _chip(
                                    Icons.store_outlined,
                                    inv['branch'] ?? '',
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Payment progress bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Collected: $currencySymbol${collected.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF16a34a),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Total: $currencySymbol${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748b),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFe2e8f0),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFF16a34a),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Collect button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showCollectModal(inv),
                                icon: const Icon(
                                  Icons.currency_rupee,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Collect Payment',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000080),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                  const Text(
                    'Total Outstanding',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748b),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$currencySymbol${_totalOutstanding.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFdc2626),
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
      hint: const Text('All branches'),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('All branches')),
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

  Widget _datePicker({
    required String label,
    required DateTime? date,
    required bool isFrom,
  }) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF000080),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date != null ? _displayDate(date) : 'Select',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1e293b),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94a3b8)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)),
        ),
      ],
    );
  }
}
