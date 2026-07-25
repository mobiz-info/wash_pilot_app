import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _invoices = ValueNotifier<List<dynamic>>([]);
  final _totalOutstanding = ValueNotifier<double>(0);
  final _loading = ValueNotifier<bool>(true);
  final _error = ValueNotifier<String>('');
  final _search = ValueNotifier<String>('');
  final _fromDate = ValueNotifier<DateTime?>(null);
  final _toDate = ValueNotifier<DateTime?>(null);
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
    _invoices.dispose();
    _totalOutstanding.dispose();
    _loading.dispose();
    _error.dispose();
    _search.dispose();
    _fromDate.dispose();
    _toDate.dispose();
    _branches.dispose();
    _selectedBranchId.dispose();
    super.dispose();
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
        ? (_fromDate.value ?? DateTime.now())
        : (_toDate.value ?? DateTime.now());
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
    if (isFrom) {
      _fromDate.value = picked;
      if (_toDate.value != null && _toDate.value!.isBefore(picked)) _toDate.value = picked;
    } else {
      _toDate.value = picked;
      if (_fromDate.value != null && _fromDate.value!.isAfter(picked)) _fromDate.value = picked;
    }
    _fetchOutstanding();
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
      final res = await ApiService.getOutstandingList(
        token,
        fromDate: _fromDate.value != null ? _formatDate(_fromDate.value!) : null,
        toDate: _toDate.value != null ? _formatDate(_toDate.value!) : null,
        branchId: _selectedBranchId.value,
      );
      if (res['success'] == true) {
        _invoices.value = res['invoices'] ?? [];
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
    } catch (_) {
      // Branch filter is optional; outstanding can still load all branches.
    }
  }

  List<dynamic> get _filteredInvoices {
    if (_search.value.trim().isEmpty) return _invoices.value;
    final q = _search.value.toLowerCase();
    return _invoices.value.where((inv) {
      final name = (inv['customer']['name'] ?? '').toLowerCase();
      final phone = (inv['customer']['phone'] ?? '').toLowerCase();
      final num = (inv['invoice_number'] ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || num.contains(q);
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
            valueListenable: _invoices,
            builder: (context, invoicesList, _) => ValueListenableBuilder<double>(
              valueListenable: _totalOutstanding,
              builder: (context, totalOutstandingVal, _) {
                final filtered = _filteredInvoices;
                final currencySymbol = context.watch<AuthProvider>().currencySymbol;

                return Scaffold(
                  backgroundColor: const Color(0xFFf8fafc),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    title: Text(
                      context.tr('Outstanding'),
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
                                  child: ValueListenableBuilder<DateTime?>(
                                    valueListenable: _fromDate,
                                    builder: (context, fromDateVal, _) => _datePicker(
                                      label: 'From',
                                      date: fromDateVal,
                                      isFrom: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ValueListenableBuilder<DateTime?>(
                                    valueListenable: _toDate,
                                    builder: (context, toDateVal, _) => _datePicker(
                                      label: 'To',
                                      date: toDateVal,
                                      isFrom: false,
                                    ),
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
                              ValueListenableBuilder<String?>(
                                valueListenable: _selectedBranchId,
                                builder: (context, branchId, _) => _branchDropdown(branchId),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Search bar
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: TextField(
                          onChanged: (v) => _search.value = v,
                          decoration: InputDecoration(
                            hintText: context.tr('Search by customer, phone or invoice #'),
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
                                  style: const TextStyle(color: Colors.red),
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
                                                context.tr('$currencySymbol${outstanding.toStringAsFixed(2)}'),
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
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  context.tr('Collected: $currencySymbol${collected.toStringAsFixed(2)}'),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF16a34a),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  context.tr('Total: $currencySymbol${total.toStringAsFixed(2)}'),
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
                                      ],
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748b),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                context.tr('$currencySymbol${totalOutstandingVal.toStringAsFixed(2)}'),
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
