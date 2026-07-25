import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class ExpenseScreen extends StatelessWidget {
  ExpenseScreen({super.key}) {
    // We defer initial load to building phase via addPostFrameCallback inside the build method
  }

  // ValueNotifiers for screen states
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  // Form selections and data sources
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

  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  Future<void> _fetchInitialData(BuildContext context) async {
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

  Future<void> _pickDate(BuildContext context) async {
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

  Future<void> _fetchItemsForHead(BuildContext context, Map<String, dynamic> head) async {
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

  void _showExpenseHeadSelector(BuildContext context) {
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
            _fetchItemsForHead(context, head);
          },
          onHeadCreated: (newHead) {
            final list = List.from(_expenseHeadsNotifier.value);
            list.add(newHead);
            list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
            _expenseHeadsNotifier.value = list;
            _selectedExpenseHeadNotifier.value = newHead;
            _fetchItemsForHead(context, newHead);
          },
        );
      },
    );
  }

  Future<void> _save(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (auth.isCompanyAdmin && (_selectedBranchIdNotifier.value == null || _selectedBranchIdNotifier.value!.isEmpty)) {
      _showSnackBar(context, context.tr('Please select a branch'), Colors.orange);
      return;
    }

    if (_selectedExpenseHeadNotifier.value == null) {
      _showSnackBar(context, context.tr('Please select an expense head'), Colors.orange);
      return;
    }

    final expenseName = _expenseNameController.text.trim();
    if (expenseName.isEmpty) {
      _showSnackBar(context, context.tr('Please enter expense name'), Colors.orange);
      return;
    }

    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      _showSnackBar(context, context.tr('Please enter amount'), Colors.orange);
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showSnackBar(context, context.tr('Please enter a valid amount'), Colors.orange);
      return;
    }

    final headName = (_selectedExpenseHeadNotifier.value!['name'] ?? '').toString().toLowerCase().trim();
    final isPurchase = headName == 'purchase';

    if (isPurchase) {
      final paidAmountStr = _paidAmountController.text.trim();
      if (paidAmountStr.isEmpty) {
        _showSnackBar(context, context.tr('Please enter paid amount'), Colors.orange);
        return;
      }
      final paidAmount = double.tryParse(paidAmountStr);
      if (paidAmount == null || paidAmount < 0) {
        _showSnackBar(context, context.tr('Please enter a valid paid amount'), Colors.orange);
        return;
      }
    }

    _isSavingNotifier.value = true;

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDateNotifier.value);
      final payload = {
        'expense_head_id': _selectedExpenseHeadNotifier.value!['id'],
        'expense_name': expenseName,
        'amount': amount,
        'date': formattedDate,
        'remarks': _remarkController.text.trim(),
        if (auth.isCompanyAdmin) 'branch_id': _selectedBranchIdNotifier.value,
        if (isPurchase) 'supplier_id': _selectedSupplierIdNotifier.value,
        if (isPurchase) 'paid_amount': double.tryParse(_paidAmountController.text.trim()),
      };

      final res = await ApiService.createExpenseEntry(token, payload);
      if (res['success'] == true) {
        if (context.mounted) {
          _showSnackBar(context, context.tr('Expense created successfully!'), Colors.green);
          Navigator.pop(context);
        }
      } else {
        if (context.mounted) {
          _showSnackBar(context, res['message'] ?? context.tr('Failed to create expense'), Colors.red);
          _isSavingNotifier.value = false;
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, e.toString(), Colors.red);
        _isSavingNotifier.value = false;
      }
    }
  }

  void _showSnackBar(BuildContext context, String msg, Color bg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData(context);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Add Expense'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingNotifier,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ValueListenableBuilder<String>(
            valueListenable: _errorMessageNotifier,
            builder: (context, errorMsg, child) {
              if (errorMsg.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMsg,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _fetchInitialData(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(context.tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: _selectedExpenseHeadNotifier,
                builder: (context, selectedExpenseHead, child) {
                  final headName = (selectedExpenseHead != null ? selectedExpenseHead['name'] ?? '' : '').toString().toLowerCase().trim();
                  final isPurchase = headName == 'purchase';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSection(
                          title: context.tr('Expense Details'),
                          icon: Icons.account_balance_wallet_outlined,
                          children: [
                            // Branch Selection (Company Admin only)
                            if (auth.isCompanyAdmin) ...[
                              _buildLabel(context.tr('Branch *')),
                              const SizedBox(height: 6),
                              ValueListenableBuilder<List<dynamic>>(
                                valueListenable: _branchesNotifier,
                                builder: (context, branches, child) {
                                  return ValueListenableBuilder<String?>(
                                    valueListenable: _selectedBranchIdNotifier,
                                    builder: (context, selectedBranchId, child) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            menuMaxHeight: 350,
                                            value: selectedBranchId,
                                            items: branches.map((b) {
                                              final branch = Map<String, dynamic>.from(b as Map);
                                              return DropdownMenuItem<String>(
                                                value: branch['id']?.toString(),
                                                child: Text(
                                                  branch['name'] ?? '',
                                                  style: GoogleFonts.inter(),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              _selectedBranchIdNotifier.value = val;
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Date Selector
                            _buildLabel(context.tr('Date *')),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _pickDate(context),
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: _selectedDateNotifier,
                                builder: (context, selectedDate, child) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade500),
                                        const SizedBox(width: 10),
                                        Text(
                                          DateFormat('dd-MM-yyyy').format(selectedDate),
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Expense Head (Searchable Dropdown)
                            _buildLabel(context.tr('Expense Head *')),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showExpenseHeadSelector(context),
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
                                              : Colors.grey.shade50,
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

                            // Expense Name Dropdown or Text Field
                            _buildExpenseNameField(context, selectedExpenseHead),
                            const SizedBox(height: 14),

                            // Supplier (Optional)
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

                            // Amount
                            _buildTextField(
                              context,
                              _amountController,
                              context.tr('Amount *'),
                              Icons.money,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        const SizedBox(height: 32),
                        ValueListenableBuilder<bool>(
                          valueListenable: _isSavingNotifier,
                          builder: (context, isSaving, child) {
                            return ElevatedButton(
                              onPressed: isSaving ? null : () => _save(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000080),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
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
              borderSide: const BorderSide(color: Color(0xFF000080)),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          enabled: false,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade500),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    menuMaxHeight: 350,
                    hint: Text(
                      hintText ?? '',
                      style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15),
                    ),
                    value: value,
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseNameField(BuildContext context, Map<String, dynamic>? selectedExpenseHead) {
    if (selectedExpenseHead == null) {
      return _buildDisabledField(
        context,
        label: context.tr('Expense Name *'),
        icon: Icons.edit_note,
        hintText: context.tr('Select Expense Head first'),
      );
    }

    final headName = (selectedExpenseHead['name'] ?? '').toString().toLowerCase().trim();
    final isSalary = headName == 'salary' || headName.contains('salary');

    if (isSalary) {
      return ValueListenableBuilder<List<dynamic>>(
        valueListenable: _staffsNotifier,
        builder: (context, staffs, child) {
          final String? currentValue = staffs.any((s) {
            final staff = Map<String, dynamic>.from(s as Map);
            return (staff['name'] ?? '').toString() == _expenseNameController.text;
          }) ? _expenseNameController.text : null;

          return _buildDropdownField(
            context,
            label: context.tr('Select Employee *'),
            icon: Icons.person_outline,
            hintText: context.tr('Select Employee'),
            value: currentValue,
            items: staffs.map((s) {
              final staff = Map<String, dynamic>.from(s as Map);
              final name = (staff['name'] ?? '').toString();
              return DropdownMenuItem<String>(
                value: name,
                child: Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 15),
                ),
              );
            }).toList(),
            onChanged: (val) {
              _expenseNameController.text = val ?? '';
            },
          );
        },
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingHeadItemsNotifier,
      builder: (context, isLoadingItems, child) {
        if (isLoadingItems) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(context.tr('Select Expense / Stock Item *')),
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
                  return stock['expense_head_id']?.toString() == selectedExpenseHead['id']?.toString();
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
                        label: context.tr('Select Expense / Stock Item *'),
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return ctx.tr('Please enter a name');
                }
                return null;
              },
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: isCreatingNotifier,
              builder: (context, isCreating, child) {
                return TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(ctx),
                  child: Text(ctx.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isCreatingNotifier,
              builder: (context, isCreating, child) {
                return ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            isCreatingNotifier.value = true;
                            try {
                              final res = await ApiService.createExpenseHead(
                                token,
                                controller.text.trim(),
                              );
                              if (res['success'] == true && res['expense_head'] != null) {
                                Navigator.pop(ctx, Map<String, dynamic>.from(res['expense_head']));
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? ctx.tr('Failed to create expense head')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                isCreatingNotifier.value = false;
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                              isCreatingNotifier.value = false;
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    if (result != null) {
      onHeadCreated(result);
      Navigator.pop(context); // Close bottom sheet
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
