import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<List<dynamic>> _expensesNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _branchesNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _selectedFilterBranchIdNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _fromDateNotifier = ValueNotifier(null);
  final ValueNotifier<DateTime?> _toDateNotifier = ValueNotifier(null);
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBranches();
      _fetchExpenses();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoadingNotifier.dispose();
    _expensesNotifier.dispose();
    _branchesNotifier.dispose();
    _selectedFilterBranchIdNotifier.dispose();
    _fromDateNotifier.dispose();
    _toDateNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin) return;
    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (res['success'] == true && res['branches'] != null) {
        _branchesNotifier.value = List.from(res['branches']);
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingNotifier.value = true;
    try {
      final fromDateStr = _fromDateNotifier.value != null
          ? DateFormat('yyyy-MM-dd').format(_fromDateNotifier.value!)
          : null;
      final toDateStr = _toDateNotifier.value != null
          ? DateFormat('yyyy-MM-dd').format(_toDateNotifier.value!)
          : null;

      final res = await ApiService.getAllExpenses(
        token,
        search: _searchController.text.trim(),
        branchId: _selectedFilterBranchIdNotifier.value,
        fromDate: fromDateStr,
        toDate: toDateStr,
      );
      if (res['success'] == true && res['expenses'] != null) {
        _expensesNotifier.value = List.from(res['expenses']);
      } else {
        _expensesNotifier.value = [];
      }
    } catch (e) {
      debugPrint("Error loading expenses: $e");
      _expensesNotifier.value = [];
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDateNotifier.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _fromDateNotifier.value = picked;
      _fetchExpenses();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDateNotifier.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _toDateNotifier.value = picked;
      _fetchExpenses();
    }
  }

  void _clearDateFilters() {
    _fromDateNotifier.value = null;
    _toDateNotifier.value = null;
    _selectedFilterBranchIdNotifier.value = null;
    _fetchExpenses();
  }

  void _navigateToAddExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
    ).then((result) {
      if (result == true) {
        _fetchExpenses();
      }
    });
  }

  Future<void> _deleteExpense(String id) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ctx.tr('Delete Expense'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade700),
        ),
        content: Text(
          ctx.tr('Are you sure you want to delete this expense?'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(ctx.tr('Delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.deleteExpenseEntry(token, id);
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('Expense deleted successfully')),
                backgroundColor: Colors.green,
              ),
            );
          }
          _fetchExpenses();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message'] ?? context.tr('Failed to delete expense')),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  double _calculateTotalAmount(List<dynamic> expenses) {
    double total = 0.0;
    for (var e in expenses) {
      final amt = double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0;
      total += amt;
    }
    return total;
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    Color? color,
    Color? backgroundColor,
  }) {
    final textColor = color ?? Colors.grey.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          context.tr('Expenses'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000080),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: context.tr('Refresh'),
            onPressed: _fetchExpenses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddExpense,
        backgroundColor: const Color(0xFF000080),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.tr('Add Expense'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExpenses,
        color: const Color(0xFF000080),
        child: Column(
          children: [
            // Search Bar & Summary Header
            Container(
              color: const Color(0xFF000080),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('Search expenses...'),
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  // Filters Row (Branch & Dates)
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // From Date
                      Expanded(
                        child: ValueListenableBuilder<DateTime?>(
                          valueListenable: _fromDateNotifier,
                          builder: (context, fromDate, child) {
                            return InkWell(
                              onTap: _pickFromDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        fromDate != null ? DateFormat('dd-MM-yyyy').format(fromDate) : context.tr('From Date'),
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // To Date
                      Expanded(
                        child: ValueListenableBuilder<DateTime?>(
                          valueListenable: _toDateNotifier,
                          builder: (context, toDate, child) {
                            return InkWell(
                              onTap: _pickToDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        toDate != null ? DateFormat('dd-MM-yyyy').format(toDate) : context.tr('To Date'),
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Clear Button
                      ValueListenableBuilder<DateTime?>(
                        valueListenable: _fromDateNotifier,
                        builder: (context, fromDate, child) {
                          return ValueListenableBuilder<DateTime?>(
                            valueListenable: _toDateNotifier,
                            builder: (context, toDate, child) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: _selectedFilterBranchIdNotifier,
                                builder: (context, branchId, child) {
                                  if (fromDate == null && toDate == null && branchId == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: InkWell(
                                      onTap: _clearDateFilters,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  if (auth.isCompanyAdmin) ...[
                    const SizedBox(height: 8),
                    ValueListenableBuilder<List<dynamic>>(
                      valueListenable: _branchesNotifier,
                      builder: (context, branches, child) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: _selectedFilterBranchIdNotifier,
                          builder: (context, selectedBranchId, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: selectedBranchId,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF000080),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  hint: Text(
                                    context.tr('All Branches'),
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                                  ),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        context.tr('All Branches'),
                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                                      ),
                                    ),
                                    ...branches.map((b) {
                                      final branch = Map<String, dynamic>.from(b as Map);
                                      return DropdownMenuItem<String?>(
                                        value: branch['id']?.toString(),
                                        child: Text(
                                          branch['name'] ?? '',
                                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    _selectedFilterBranchIdNotifier.value = val;
                                    _fetchExpenses();
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _expensesNotifier,
                    builder: (context, expenses, child) {
                      final totalAmount = _calculateTotalAmount(expenses);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('Total Expenses'),
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${auth.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${expenses.length} ${context.tr("Entries")}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF000080),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Expenses List
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingNotifier,
                builder: (context, isLoading, child) {
                  if (isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF000080)),
                    );
                  }

                  return ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _expensesNotifier,
                    builder: (context, expenses, child) {
                      if (expenses.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('No expenses recorded yet'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _navigateToAddExpense,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: Text(
                                  context.tr('Add Expense'),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000080),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final item = Map<String, dynamic>.from(expenses[index] as Map);
                          final headName = (item['expense_head_name'] ?? 'General').toString();
                          final expenseName = (item['expense_name'] ?? '').toString();
                          final amountStr = (item['amount'] ?? '0.00').toString();
                          final rawDateStr = (item['expense_date'] ?? '').toString();
                          String formattedDateStr = rawDateStr;
                          if (rawDateStr.isNotEmpty) {
                            try {
                              final dt = DateTime.parse(rawDateStr);
                              formattedDateStr = DateFormat('dd-MM-yyyy').format(dt);
                            } catch (_) {}
                          }
                          final branchName = (item['branch_name'] ?? '').toString();
                          final supplierName = (item['supplier_name'] ?? '').toString();
                          final remarks = (item['remarks'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF000080).withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(0xFF000080),
                                      width: 4,
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top Header Row (Head Badge & Amount + Delete Button)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: REdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF000080).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(20.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.label_outlined, size: 13.r, color: const Color(0xFF000080)),
                                                SizedBox(width: 4.w),
                                                Flexible(
                                                  child: Text(
                                                    headName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF000080),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          '${auth.currencySymbol}$amountStr',
                                          style: GoogleFonts.inter(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Material(
                                          color: Colors.red.shade50,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            onTap: () => _deleteExpense(item['id'].toString()),
                                            customBorder: const CircleBorder(),
                                            child: Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red.shade700,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Expense Item Name & Date Chip
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            expenseName.isNotEmpty ? expenseName : headName,
                                            style: GoogleFonts.inter(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        if (formattedDateStr.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          _buildDetailChip(
                                            icon: Icons.calendar_today_outlined,
                                            label: formattedDateStr,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Details Chips (Branch, Supplier)
                                    if ((auth.isCompanyAdmin && branchName != 'N/A' && branchName.isNotEmpty) || (supplierName != 'N/A' && supplierName.isNotEmpty))
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (auth.isCompanyAdmin && branchName != 'N/A' && branchName.isNotEmpty)
                                            _buildDetailChip(
                                              icon: Icons.storefront_outlined,
                                              label: branchName,
                                            ),
                                          if (supplierName != 'N/A' && supplierName.isNotEmpty)
                                            _buildDetailChip(
                                              icon: Icons.business_outlined,
                                              label: supplierName,
                                              color: Colors.amber.shade900,
                                              backgroundColor: Colors.amber.shade50,
                                            ),
                                        ],
                                      ),

                                    // Remarks if present
                                    if (remarks.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                remarks,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
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
      ),
    );
  }
}


class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  final ValueNotifier<List<dynamic>> _expenseHeadsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _branchesNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _staffsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _stocksNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _suppliersNotifier = ValueNotifier([]);

  final ValueNotifier<List<String>> _headItemsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isCustomExpenseNameNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingHeadItemsNotifier = ValueNotifier(false);

  final ValueNotifier<DateTime> _selectedDateNotifier = ValueNotifier(DateTime.now());
  final ValueNotifier<Map<String, dynamic>?> _selectedExpenseHeadNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _selectedBranchIdNotifier = ValueNotifier(null);
  final ValueNotifier<String?> _selectedSupplierIdNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _hasSupplierNotifier = ValueNotifier(false);

  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  @override
  void dispose() {
    _isLoadingNotifier.dispose();
    _isSavingNotifier.dispose();
    _errorMessageNotifier.dispose();
    _expenseHeadsNotifier.dispose();
    _branchesNotifier.dispose();
    _staffsNotifier.dispose();
    _stocksNotifier.dispose();
    _suppliersNotifier.dispose();
    _headItemsNotifier.dispose();
    _isCustomExpenseNameNotifier.dispose();
    _isLoadingHeadItemsNotifier.dispose();
    _selectedDateNotifier.dispose();
    _selectedExpenseHeadNotifier.dispose();
    _selectedBranchIdNotifier.dispose();
    _selectedSupplierIdNotifier.dispose();
    _hasSupplierNotifier.dispose();
    _expenseNameController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    _isLoadingNotifier.value = true;
    _errorMessageNotifier.value = '';

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final inventoryProvider = context.read<InventoryProvider>();

      await Future.wait([
        expenseProvider.fetchExpenseHeads(token),
        expenseProvider.fetchSuppliers(token),
        inventoryProvider.fetchStockItems(token),
      ]);

      List<dynamic> branches = [];
      if (auth.isCompanyAdmin) {
        final branchRes = await ApiService.getCompanyBranches(token);
        if (branchRes['success'] == true) {
          branches = branchRes['branches'] ?? [];
        }
      }

      List<dynamic> staffs = [];
      try {
        final staffRes = await ApiService.getStaffList(token);
        if (staffRes['success'] == true) {
          staffs = staffRes['staffs'] ?? [];
        }
      } catch (_) {}

      _expenseHeadsNotifier.value = expenseProvider.expenseHeads;
      _suppliersNotifier.value = expenseProvider.suppliers;
      _stocksNotifier.value = inventoryProvider.stockItems;
      _branchesNotifier.value = branches;
      _staffsNotifier.value = staffs;

      if (branches.isNotEmpty) {
        _selectedBranchIdNotifier.value = branches.first['id']?.toString();
      }
      _isLoadingNotifier.value = false;
    } catch (e) {
      _errorMessageNotifier.value = e.toString();
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateNotifier.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF000080),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _selectedDateNotifier.value = picked;
    }
  }

  Future<void> _fetchItemsForHead(Map<String, dynamic> head) async {
    _expenseNameController.clear();
    _isCustomExpenseNameNotifier.value = false;
    _headItemsNotifier.value = [];
    final headId = head['id']?.toString();
    if (headId == null) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingHeadItemsNotifier.value = true;
    try {
      final res = await ApiService.getExpenseItemsByHead(token, headId);
      if (res['success'] == true && res['items'] != null) {
        final List<String> items = List<String>.from(res['items']);
        _headItemsNotifier.value = items;
      }
    } catch (e) {
      debugPrint("Error fetching expense items: $e");
    } finally {
      _isLoadingHeadItemsNotifier.value = false;
    }
  }

  void _showExpenseHeadSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _ExpenseHeadBottomSheet(
          expenseHeads: _expenseHeadsNotifier.value,
          onSelected: (head) {
            _selectedExpenseHeadNotifier.value = head;
            _fetchItemsForHead(head);
          },
          onHeadCreated: (newHead) {
            final list = List.from(_expenseHeadsNotifier.value);
            list.add(newHead);
            list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
            _expenseHeadsNotifier.value = list;
            _selectedExpenseHeadNotifier.value = newHead;
            _fetchItemsForHead(newHead);
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (_selectedExpenseHeadNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select an Expense Head'))),
      );
      return;
    }

    final expenseName = _expenseNameController.text.trim();
    if (expenseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter or select an Expense Name'))),
      );
      return;
    }

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter a valid amount'))),
      );
      return;
    }

    String? branchId;
    if (auth.isCompanyAdmin) {
      branchId = _selectedBranchIdNotifier.value;
      if (branchId == null || branchId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Please select a Branch'))),
        );
        return;
      }
    }

    final hasSupplier = _hasSupplierNotifier.value;
    final supplierId = hasSupplier ? _selectedSupplierIdNotifier.value : null;
    final paidAmountStr = _paidAmountController.text.trim();
    final paidAmount = (hasSupplier && paidAmountStr.isNotEmpty) ? double.tryParse(paidAmountStr) : amount;

    final payload = <String, dynamic>{
      'expense_head_id': _selectedExpenseHeadNotifier.value!['id'].toString(),
      'expense_name': expenseName,
      'amount': amount,
      'expense_date': DateFormat('yyyy-MM-dd').format(_selectedDateNotifier.value),
      'date': DateFormat('yyyy-MM-dd').format(_selectedDateNotifier.value),
      'branch_id': branchId,
      'supplier_id': supplierId,
      'paid_amount': paidAmount,
      'remarks': _remarkController.text.trim(),
    };

    _isSavingNotifier.value = true;
    try {
      final res = await ApiService.createExpenseEntry(token, payload);

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Expense Saved Successfully')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? context.tr('Failed to save expense')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isSavingNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(
          context.tr('Add Expense'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000080),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingNotifier,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF000080)),
            );
          }

          return ValueListenableBuilder<String>(
            valueListenable: _errorMessageNotifier,
            builder: (context, errorMsg, child) {
              if (errorMsg.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMsg, style: GoogleFonts.inter(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchInitialData,
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSection(
                      title: context.tr('Expense Details'),
                      icon: Icons.receipt_long_outlined,
                      children: [
                        if (auth.isCompanyAdmin) ...[
                          ValueListenableBuilder<List<dynamic>>(
                            valueListenable: _branchesNotifier,
                            builder: (context, branches, child) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: _selectedBranchIdNotifier,
                                builder: (context, selectedBranchId, child) {
                                  return _buildDropdownField(
                                    context,
                                    label: context.tr('Branch *'),
                                    icon: Icons.storefront,
                                    hintText: context.tr('Select Branch'),
                                    value: selectedBranchId,
                                    items: branches.map((b) {
                                      final branch = Map<String, dynamic>.from(b as Map);
                                      return DropdownMenuItem<String>(
                                        value: branch['id']?.toString(),
                                        child: Text(
                                          branch['name'] ?? '',
                                          style: GoogleFonts.inter(fontSize: 15),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      _selectedBranchIdNotifier.value = val;
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Date Selector
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _selectedDateNotifier,
                          builder: (context, selectedDate, child) {
                            return _buildClickableField(
                              context,
                              label: context.tr('Date *'),
                              icon: Icons.calendar_today_outlined,
                              value: DateFormat('dd-MM-yyyy').format(selectedDate),
                              onTap: () => _pickDate(),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Expense Head Selector
                        ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: _selectedExpenseHeadNotifier,
                          builder: (context, selectedExpenseHead, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context.tr('Expense Head *')),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _showExpenseHeadSelector(),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            selectedExpenseHead != null
                                                ? selectedExpenseHead['name'] ?? ''
                                                : context.tr('Select Expense Head'),
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: selectedExpenseHead != null
                                                  ? Colors.black87
                                                  : Colors.grey.shade500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Expense Item Dropdown
                                _buildExpenseNameField(selectedExpenseHead),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Amount
                        _buildTextField(
                          context,
                          _amountController,
                          context.tr('Amount *'),
                          Icons.money,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 14),

                        // Has Supplier Checkbox
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasSupplierNotifier,
                          builder: (context, hasSupplier, child) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  context.tr('Has Supplier / Credit Supplier Payment'),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF000080),
                                  ),
                                ),
                                value: hasSupplier,
                                activeColor: const Color(0xFF000080),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  _hasSupplierNotifier.value = val ?? false;
                                  if (val == false) {
                                    _selectedSupplierIdNotifier.value = null;
                                  }
                                },
                              ),
                            );
                          },
                        ),

                        // Supplier (Optional) & Paid Amount (Visible when Has Supplier is checked)
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasSupplierNotifier,
                          builder: (context, hasSupplier, child) {
                            if (!hasSupplier) return const SizedBox.shrink();

                            return Column(
                              children: [
                                ValueListenableBuilder<List<dynamic>>(
                                  valueListenable: _suppliersNotifier,
                                  builder: (context, suppliers, child) {
                                    return ValueListenableBuilder<String?>(
                                      valueListenable: _selectedSupplierIdNotifier,
                                      builder: (context, selectedSupplierId, child) {
                                        return _buildDropdownField(
                                          context,
                                          label: context.tr('Supplier (Optional)'),
                                          icon: Icons.business,
                                          hintText: context.tr('Select Supplier'),
                                          value: selectedSupplierId,
                                          items: suppliers.map((s) {
                                            final sup = Map<String, dynamic>.from(s as Map);
                                            return DropdownMenuItem<String>(
                                              value: sup['id']?.toString(),
                                              child: Text(
                                                sup['name'] ?? '',
                                                style: GoogleFonts.inter(fontSize: 15),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            _selectedSupplierIdNotifier.value = val;
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Paid Amount
                                _buildTextField(
                                  context,
                                  _paidAmountController,
                                  context.tr('Paid Amount'),
                                  Icons.money,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                                const SizedBox(height: 14),
                              ],
                            );
                          },
                        ),

                        // Remark
                        _buildTextField(
                          context,
                          _remarkController,
                          context.tr('Remark'),
                          Icons.comment_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSavingNotifier,
                      builder: (context, isSaving, child) {
                        return ElevatedButton(
                          onPressed: isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.tr('Save Expense'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF000080), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF000080),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildClickableField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String hintText,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF000080), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF000080), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseNameField(Map<String, dynamic>? selectedExpenseHead) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingHeadItemsNotifier,
      builder: (context, isLoadingItems, child) {
        if (isLoadingItems) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(context.tr('Select Stock / Expense Item *')),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF000080)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr('Loading expense items...'),
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ValueListenableBuilder<List<String>>(
          valueListenable: _headItemsNotifier,
          builder: (context, headItems, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: _isCustomExpenseNameNotifier,
              builder: (context, isCustom, child) {
                final List<dynamic> stocks = _stocksNotifier.value;
                final stockNames = stocks.where((s) {
                  final stock = Map<String, dynamic>.from(s as Map);
                  return stock['expense_head_id']?.toString() == selectedExpenseHead?['id']?.toString();
                }).map((s) => (s['item_name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();

                final combinedSet = <String>{...headItems, ...stockNames};
                final combinedItems = combinedSet.toList()..sort();

                if (combinedItems.isNotEmpty && !isCustom) {
                  final String? currentValue = combinedItems.contains(_expenseNameController.text)
                      ? _expenseNameController.text
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDropdownField(
                        context,
                        label: context.tr('Select Stock / Expense Item *'),
                        icon: Icons.shopping_bag_outlined,
                        hintText: context.tr('Select Expense Item'),
                        value: currentValue,
                        items: [
                          ...combinedItems.map((name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(fontSize: 15),
                                ),
                              )),
                          DropdownMenuItem<String>(
                            value: '__CUSTOM__',
                            child: Text(
                              '+ ${context.tr("Custom Expense Name")}',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__CUSTOM__') {
                            _expenseNameController.clear();
                            _isCustomExpenseNameNotifier.value = true;
                          } else {
                            _expenseNameController.text = val ?? '';
                          }
                        },
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      context,
                      _expenseNameController,
                      context.tr('Expense Name *'),
                      Icons.edit_note,
                    ),
                    if (combinedItems.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            _expenseNameController.clear();
                            _isCustomExpenseNameNotifier.value = false;
                          },
                          icon: const Icon(Icons.list, size: 16),
                          label: Text(context.tr('Select from list')),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}


class _ExpenseHeadBottomSheet extends StatelessWidget {
  final List<dynamic> expenseHeads;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final ValueChanged<Map<String, dynamic>> onHeadCreated;

  _ExpenseHeadBottomSheet({
    required this.expenseHeads,
    required this.onSelected,
    required this.onHeadCreated,
  }) {
    _filteredHeadsNotifier.value = List.from(expenseHeads);
    _searchController.addListener(_filter);
  }

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<dynamic>> _filteredHeadsNotifier = ValueNotifier([]);

  void _filter() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredHeadsNotifier.value = List.from(expenseHeads);
    } else {
      _filteredHeadsNotifier.value = expenseHeads.where((h) {
        final name = (h['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    }
  }

  Future<void> _addNewExpenseHead(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final ValueNotifier<bool> isCreatingNotifier = ValueNotifier(false);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            ctx.tr('Add Expense Head'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ctx.tr('Expense Head Name *'),
                labelStyle: GoogleFonts.inter(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return ctx.tr('Name is required');
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('Cancel')),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isCreatingNotifier,
              builder: (ctx, isCreating, child) {
                return ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          isCreatingNotifier.value = true;
                          try {
                            final res = await ApiService.createExpenseHead(token, controller.text.trim());
                            if (res['success'] == true && res['expense_head'] != null) {
                              if (ctx.mounted) Navigator.pop(ctx, Map<String, dynamic>.from(res['expense_head']));
                            } else {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? ctx.tr('Failed to create expense head'))),
                                );
                              }
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          } finally {
                            isCreatingNotifier.value = false;
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                  ),
                  child: isCreating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(ctx.tr('Add')),
                );
              },
            ),
          ],
        );
      },
    );

    if (result != null && context.mounted) {
      onHeadCreated(result);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Select Expense Head'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000080),
                ),
              ),
              Row(
                children: [
                  if (context.read<AuthProvider>().isCompanyAdmin)
                    IconButton(
                      onPressed: () => _addNewExpenseHead(context),
                      icon: const Icon(Icons.add, color: Color(0xFF000080)),
                      tooltip: context.tr('Add Expense Head'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search expense heads...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder<List<dynamic>>(
              valueListenable: _filteredHeadsNotifier,
              builder: (context, filteredHeads, child) {
                if (filteredHeads.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('No expense heads found'),
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredHeads.length,
                  itemBuilder: (context, index) {
                    final head = Map<String, dynamic>.from(filteredHeads[index] as Map);
                    return ListTile(
                      title: Text(
                        head['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        onSelected(head);
                        Navigator.pop(context);
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
}
