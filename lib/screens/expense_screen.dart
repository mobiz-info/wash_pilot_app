import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _expenseHeads = [];
  List<dynamic> _branches = [];
  List<dynamic> _stocks = [];
  List<dynamic> _staffs = [];

  // Form State
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedExpenseHead;
  String? _selectedBranchId;

  final _expenseNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Fetch Expense Heads
      final headRes = await ApiService.getExpenseHeads(token);
      List<dynamic> heads = [];
      if (headRes['success'] == true) {
        heads = headRes['expense_heads'] ?? [];
      } else {
        throw Exception(headRes['message'] ?? 'Failed to load expense heads');
      }

      // 2. Fetch Branches if Company Admin
      List<dynamic> branches = [];
      if (auth.isCompanyAdmin) {
        final branchRes = await ApiService.getCompanyBranches(token);
        if (branchRes['success'] == true) {
          branches = branchRes['branches'] ?? [];
        } else {
          throw Exception(branchRes['message'] ?? 'Failed to load branches');
        }
      }

      // 3. Fetch Staff list
      List<dynamic> staffs = [];
      try {
        final staffRes = await ApiService.getStaffList(token);
        if (staffRes['success'] == true) {
          staffs = staffRes['staffs'] ?? [];
        }
      } catch (_) {}

      // 4. Fetch Stock list
      List<dynamic> stocks = [];
      try {
        final stockRes = await ApiService.getStockList(token);
        if (stockRes['success'] == true) {
          stocks = stockRes['stocks'] ?? [];
        }
      } catch (_) {}

      setState(() {
        _expenseHeads = heads;
        _branches = branches;
        _staffs = staffs;
        _stocks = stocks;
        // Default to first branch if available
        if (branches.isNotEmpty) {
          _selectedBranchId = branches.first['id']?.toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showExpenseHeadSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ExpenseHeadBottomSheet(
          expenseHeads: _expenseHeads,
          onSelected: (head) {
            setState(() {
              _selectedExpenseHead = head;
              _expenseNameController.clear();
            });
          },
          onHeadCreated: (newHead) {
            setState(() {
              _expenseHeads.add(newHead);
              _expenseHeads.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
              _selectedExpenseHead = newHead;
              _expenseNameController.clear();
            });
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    if (auth.isCompanyAdmin && (_selectedBranchId == null || _selectedBranchId!.isEmpty)) {
      _showSnackBar(context.tr('Please select a branch'), Colors.orange);
      return;
    }

    if (_selectedExpenseHead == null) {
      _showSnackBar(context.tr('Please select an expense head'), Colors.orange);
      return;
    }

    final expenseName = _expenseNameController.text.trim();
    if (expenseName.isEmpty) {
      _showSnackBar(context.tr('Please enter expense name'), Colors.orange);
      return;
    }

    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      _showSnackBar(context.tr('Please enter amount'), Colors.orange);
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showSnackBar(context.tr('Please enter a valid amount'), Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final payload = {
        'expense_head_id': _selectedExpenseHead!['id'],
        'expense_name': expenseName,
        'amount': amount,
        'date': formattedDate,
        'remarks': _remarkController.text.trim(),
        if (auth.isCompanyAdmin) 'branch_id': _selectedBranchId,
      };

      final res = await ApiService.createExpenseEntry(token, payload);
      if (res['success'] == true) {
        if (mounted) {
          _showSnackBar(context.tr('Expense created successfully!'), Colors.green);
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          _showSnackBar(res['message'] ?? context.tr('Failed to create expense'), Colors.red);
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), Colors.red);
        setState(() => _isSaving = false);
        print(e.toString());
      }
    }
  }

  void _showSnackBar(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
    print(msg);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchInitialData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(context.tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
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
                            Container(
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
                                  value: _selectedBranchId,
                                  items: _branches.map((b) {
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
                                    setState(() {
                                      _selectedBranchId = val;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Date Selector
                          _buildLabel(context.tr('Date *')),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
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
                                    DateFormat('dd-MM-yyyy').format(_selectedDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Expense Head (Searchable Dropdown)
                          _buildLabel(context.tr('Expense Head *')),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _showExpenseHeadSelector,
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
                                      _selectedExpenseHead != null
                                          ? _selectedExpenseHead!['name'] ?? ''
                                          : context.tr('Select Expense Head'),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: _selectedExpenseHead != null
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

                          // Expense Name
                          _buildExpenseNameField(),
                          const SizedBox(height: 14),

                          // Amount
                          _buildTextField(
                            _amountController,
                            context.tr('Amount *'),
                            Icons.attach_money,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          const SizedBox(height: 14),

                          // Remark
                          _buildTextField(
                            _remarkController,
                            context.tr('Remark'),
                            Icons.comment_outlined,
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: _isSaving
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
                      ),
                    ],
                  ),
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

  Widget _buildDisabledField({
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

  Widget _buildDropdownField({
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

  Widget _buildExpenseNameField() {
    if (_selectedExpenseHead == null) {
      return _buildDisabledField(
        label: context.tr('Expense Name *'),
        icon: Icons.edit_note,
        hintText: context.tr('Select Expense Head first'),
      );
    }

    final headName = (_selectedExpenseHead!['name'] ?? '').toString().toLowerCase().trim();
    final isSalary = headName == 'salary' || headName.contains('salary');

    if (isSalary) {
      final String? currentValue = _staffs.any((s) {
        final staff = Map<String, dynamic>.from(s as Map);
        return (staff['name'] ?? '').toString() == _expenseNameController.text;
      }) ? _expenseNameController.text : null;

      return _buildDropdownField(
        label: context.tr('Select Employee *'),
        icon: Icons.person_outline,
        hintText: context.tr('Select Employee'),
        value: currentValue,
        items: _staffs.map((s) {
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
          setState(() {
            _expenseNameController.text = val ?? '';
          });
        },
      );
    } else {
      final filteredStocks = _stocks.where((s) {
        final stock = Map<String, dynamic>.from(s as Map);
        return stock['expense_head_id']?.toString() == _selectedExpenseHead!['id']?.toString();
      }).toList();

      if (filteredStocks.isNotEmpty) {
        final String? currentValue = filteredStocks.any((s) {
          final stock = Map<String, dynamic>.from(s as Map);
          return (stock['item_name'] ?? '').toString() == _expenseNameController.text;
        }) ? _expenseNameController.text : null;

        return _buildDropdownField(
          label: context.tr('Select Stock Item *'),
          icon: Icons.shopping_bag_outlined,
          hintText: context.tr('Select Stock Item'),
          value: currentValue,
          items: filteredStocks.map((s) {
            final stock = Map<String, dynamic>.from(s as Map);
            final name = (stock['item_name'] ?? '').toString();
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: GoogleFonts.inter(fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _expenseNameController.text = val ?? '';
            });
          },
        );
      } else {
        return _buildTextField(
          _expenseNameController,
          context.tr('Expense Name *'),
          Icons.edit_note,
        );
      }
    }
  }
}

class _ExpenseHeadBottomSheet extends StatefulWidget {
  final List<dynamic> expenseHeads;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final ValueChanged<Map<String, dynamic>> onHeadCreated;

  const _ExpenseHeadBottomSheet({
    required this.expenseHeads,
    required this.onSelected,
    required this.onHeadCreated,
  });

  @override
  State<_ExpenseHeadBottomSheet> createState() => _ExpenseHeadBottomSheetState();
}

class _ExpenseHeadBottomSheetState extends State<_ExpenseHeadBottomSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _filteredHeads = [];

  @override
  void initState() {
    super.initState();
    _filteredHeads = List.from(widget.expenseHeads);
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredHeads = List.from(widget.expenseHeads);
      } else {
        _filteredHeads = widget.expenseHeads.where((h) {
          final name = (h['name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addNewExpenseHead() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Add Expense Head'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Expense Head Name *'),
                    labelStyle: GoogleFonts.inter(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Please enter a name');
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isCreating = true);
                            try {
                              final res = await ApiService.createExpenseHead(
                                token,
                                controller.text.trim(),
                              );
                              if (res['success'] == true && res['expense_head'] != null) {
                                Navigator.pop(context, Map<String, dynamic>.from(res['expense_head']));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? context.tr('Failed to create expense head')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setDialogState(() => isCreating = false);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                              setDialogState(() => isCreating = false);
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
                      : Text(context.tr('Add')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      widget.onHeadCreated(result);
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
                      onPressed: _addNewExpenseHead,
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
            child: _filteredHeads.isEmpty
                ? Center(
                    child: Text(
                      context.tr('No expense heads found'),
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredHeads.length,
                    itemBuilder: (context, index) {
                      final head = Map<String, dynamic>.from(_filteredHeads[index] as Map);
                      return ListTile(
                        title: Text(
                          head['name'] ?? '',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          widget.onSelected(head);
                          Navigator.pop(context);
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
