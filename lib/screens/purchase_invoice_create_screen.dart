import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class PurchaseInvoiceCreateScreen extends StatefulWidget {
  const PurchaseInvoiceCreateScreen({super.key});

  @override
  State<PurchaseInvoiceCreateScreen> createState() =>
      _PurchaseInvoiceCreateScreenState();
}

class _PurchaseInvoiceCreateScreenState
    extends State<PurchaseInvoiceCreateScreen> {
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  final ValueNotifier<List<dynamic>> _suppliersNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _stockGroupsNotifier = ValueNotifier([]);
  // Map: group_id -> list of stock items
  final Map<String, List<dynamic>> _stocksByGroup = {};

  final ValueNotifier<Map<String, dynamic>?> _selectedSupplierNotifier =
      ValueNotifier(null);
  final ValueNotifier<DateTime> _invoiceDateNotifier =
      ValueNotifier(DateTime.now());

  final TextEditingController _invNumberController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _amountPaidController =
      TextEditingController(text: '0.00');

  // Item rows: each row is a Map with keys: stock_group, stock, hsn, rate, qty, tax_percent, total
  final ValueNotifier<List<Map<String, dynamic>>> _itemRowsNotifier =
      ValueNotifier([]);

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
    _suppliersNotifier.dispose();
    _stockGroupsNotifier.dispose();
    _selectedSupplierNotifier.dispose();
    _invoiceDateNotifier.dispose();
    _invNumberController.dispose();
    _remarksController.dispose();
    _amountPaidController.dispose();
    _itemRowsNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingNotifier.value = true;
    _errorMessageNotifier.value = '';

    try {
      final results = await Future.wait([
        ApiService.getSuppliers(token),
        ApiService.getStockGroups(token),
      ]);

      final suppRes = results[0];
      final groupRes = results[1];

      _suppliersNotifier.value = suppRes['suppliers'] ?? [];
      _stockGroupsNotifier.value =
          groupRes['stock_groups'] ?? groupRes['groups'] ?? [];

      // Auto-generate invoice number
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      _invNumberController.text = 'PINV-${ts.substring(ts.length - 6)}';

      // Add first empty item row
      _addItemRow();

      _isLoadingNotifier.value = false;
    } catch (e) {
      _errorMessageNotifier.value = e.toString();
      _isLoadingNotifier.value = false;
    }
  }

  Future<List<dynamic>> _fetchStocksByGroup(String groupId) async {
    if (_stocksByGroup.containsKey(groupId)) {
      return _stocksByGroup[groupId]!;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null) return [];
    try {
      final res = await ApiService.getStockList(token);
      final allStocks = (res['stocks'] ?? []) as List<dynamic>;
      final filtered = allStocks.where((s) {
        final stock = Map<String, dynamic>.from(s as Map);
        return stock['stock_group_id']?.toString() == groupId ||
            stock['group_id']?.toString() == groupId;
      }).toList();
      _stocksByGroup[groupId] = filtered;
      return filtered;
    } catch (_) {
      return [];
    }
  }

  void _addItemRow() {
    final rows = List<Map<String, dynamic>>.from(_itemRowsNotifier.value);
    rows.add({
      'stock_group': null,
      'stocks': <dynamic>[],
      'stocks_loading': false,
      'stock': null,
      'hsn': '',
      'rate_controller': TextEditingController(),
      'qty_controller': TextEditingController(text: '1'),
      'tax_controller': TextEditingController(),
      'total': 0.0,
    });
    _itemRowsNotifier.value = rows;
  }

  void _removeRow(int index) {
    final rows = List<Map<String, dynamic>>.from(_itemRowsNotifier.value);
    if (rows.length > 1) {
      rows.removeAt(index);
      _itemRowsNotifier.value = rows;
    }
  }

  double _calcRowTotal(Map<String, dynamic> row) {
    final rate =
        double.tryParse(row['rate_controller'].text.trim()) ?? 0.0;
    final qty =
        double.tryParse(row['qty_controller'].text.trim()) ?? 0.0;
    final tax =
        double.tryParse(row['tax_controller'].text.trim()) ?? 0.0;
    final sub = rate * qty;
    return sub + (sub * tax / 100.0);
  }

  double get _grandTotal {
    double sum = 0;
    for (final row in _itemRowsNotifier.value) {
      sum += _calcRowTotal(row);
    }
    return sum;
  }

  double get _subtotal {
    double sum = 0;
    for (final row in _itemRowsNotifier.value) {
      final rate =
          double.tryParse(row['rate_controller'].text.trim()) ?? 0.0;
      final qty =
          double.tryParse(row['qty_controller'].text.trim()) ?? 0.0;
      sum += rate * qty;
    }
    return sum;
  }

  double get _taxTotal => _grandTotal - _subtotal;

  double get _balanceToPay {
    final paid =
        double.tryParse(_amountPaidController.text.trim()) ?? 0.0;
    final bal = _grandTotal - paid;
    return bal < 0 ? 0.0 : bal;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDateNotifier.value,
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
      _invoiceDateNotifier.value = picked;
    }
  }

  void _showSupplierSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final search = ValueNotifier<String>('');
        return StatefulBuilder(builder: (ctx, setInner) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.65,
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Select Supplier'),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF000080),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.tr('Search suppliers...'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => search.value = v.toLowerCase(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: search,
                    builder: (_, q, __) {
                      final suppliers = _suppliersNotifier.value
                          .where((s) => (s['name'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(q))
                          .toList();
                      if (suppliers.isEmpty) {
                        return Center(
                          child: Text(
                            context.tr('No suppliers found'),
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (_, i) {
                          final s =
                              Map<String, dynamic>.from(suppliers[i] as Map);
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8EAF6),
                              child: Icon(Icons.business,
                                  color: Color(0xFF000080), size: 18),
                            ),
                            title: Text(s['name'] ?? '',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            subtitle: (s['payables'] != null &&
                                    s['payables'].toString() != '0')
                                ? Text(
                                    'Payables: ${s['payables']}',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.red.shade600),
                                  )
                                : null,
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              _selectedSupplierNotifier.value = s;
                              Navigator.pop(ctx);
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
        });
      },
    );
  }

  Future<void> _submitInvoice() async {
    if (_selectedSupplierNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a Supplier')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_invNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please enter Invoice Number')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validItems = <Map<String, dynamic>>[];
    for (final row in _itemRowsNotifier.value) {
      if (row['stock'] != null) {
        validItems.add({
          'stock_id': row['stock']['id'],
          'hsn_code': row['hsn'],
          'rate':
              double.tryParse(row['rate_controller'].text.trim()) ?? 0.0,
          'qty': double.tryParse(row['qty_controller'].text.trim()) ?? 1.0,
          'tax_percent':
              double.tryParse(row['tax_controller'].text.trim()) ?? 0.0,
        });
      }
    }

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select at least one Stock Item')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _isSavingNotifier.value = true;
    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final res = await ApiService.createPurchaseInvoice(
        {
          'supplier_id': _selectedSupplierNotifier.value!['id'],
          'purchase_inv_number': _invNumberController.text.trim(),
          'invoice_date':
              DateFormat('yyyy-MM-dd').format(_invoiceDateNotifier.value),
          'amount_paid':
              double.tryParse(_amountPaidController.text.trim()) ?? 0.0,
          'remarks': _remarksController.text.trim(),
          'items': validItems,
        },
        token,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  res['message'] ?? context.tr('Purchase Entry Saved')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  res['message'] ?? context.tr('Error saving purchase')),
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
          context.tr('New Purchase Entry'),
          style:
              GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
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
                      Text(errorMsg,
                          style:
                              GoogleFonts.inter(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchInitialData,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white),
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
                    // ── Header Section ───────────────────────────────
                    _buildSection(
                      title: context.tr('Invoice Details'),
                      icon: Icons.receipt_long_outlined,
                      children: [
                        // Supplier selector
                        _buildLabel(context.tr('Supplier *')),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: _selectedSupplierNotifier,
                          builder: (_, supplier, __) => InkWell(
                            onTap: _showSupplierSelector,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.business_outlined,
                                      size: 20,
                                      color: Colors.grey.shade600),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      supplier != null
                                          ? supplier['name'] ?? ''
                                          : context.tr('Select Supplier'),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: supplier != null
                                            ? Colors.black87
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Invoice Number
                        _buildTextFieldWidget(
                          context,
                          _invNumberController,
                          context.tr('Invoice Number *'),
                          Icons.tag_outlined,
                        ),
                        const SizedBox(height: 14),

                        // Invoice Date
                        ValueListenableBuilder<DateTime>(
                          valueListenable: _invoiceDateNotifier,
                          builder: (_, date, __) => _buildClickableField(
                            context,
                            label: context.tr('Invoice Date *'),
                            icon: Icons.calendar_today_outlined,
                            value: DateFormat('dd-MM-yyyy').format(date),
                            onTap: _pickDate,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Items Section ─────────────────────────────────
                    _buildSection(
                      title: context.tr('Purchased Items'),
                      icon: Icons.inventory_2_outlined,
                      children: [
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: _itemRowsNotifier,
                          builder: (_, rows, __) {
                            return Column(
                              children: [
                                ...List.generate(rows.length, (index) {
                                  return _buildItemRow(index, rows[index]);
                                }),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _addItemRow,
                                  icon: const Icon(Icons.add,
                                      color: Color(0xFF000080)),
                                  label: Text(
                                    context.tr('Add Another Item'),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF000080),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFF000080)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Totals Card ───────────────────────────────────
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: _itemRowsNotifier,
                      builder: (_, rows, __) {
                        final sub = _subtotal;
                        final tax = _taxTotal;
                        final grand = _grandTotal;
                        final balance = _balanceToPay;

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
                            children: [
                              _buildTotalRow(
                                  context.tr('Subtotal'), sub, auth),
                              const SizedBox(height: 8),
                              _buildTotalRow(
                                  context.tr('Tax Total'), tax, auth,
                                  accent: Colors.orange.shade700),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.tr('Grand Total'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${auth.currencySymbol}${grand.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF000080),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Amount paid
                              _buildLabel(
                                  context.tr('Amount Paid')),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _amountPaidController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: GoogleFonts.inter(fontSize: 15),
                                onChanged: (_) {
                                  // Rebuild to refresh balance
                                  _refreshTotals();
                                },
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.payments_outlined,
                                      color: Colors.grey.shade600),
                                  filled: true,
                                  fillColor: const Color(0xFFFAFAFA),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF000080), width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Balance
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: balance > 0
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: balance > 0
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.tr('Balance to Pay'),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: balance > 0
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      '${auth.currencySymbol}${balance.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: balance > 0
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
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

                    const SizedBox(height: 16),

                    // ── Remarks ───────────────────────────────────────
                    _buildSection(
                      title: context.tr('Additional Info'),
                      icon: Icons.notes_outlined,
                      children: [
                        _buildTextFieldWidget(
                          context,
                          _remarksController,
                          context.tr('Remarks (Optional)'),
                          Icons.comment_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Save Button ───────────────────────────────────
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSavingNotifier,
                      builder: (_, isSaving, __) => ElevatedButton(
                        onPressed: isSaving ? null : _submitInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                context.tr('Save Purchase Entry'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Item Row Widget ────────────────────────────────────────────────────────
  Widget _buildItemRow(int index, Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000080).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF000080), width: 4),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF000080).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Item ${index + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF000080),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.red.shade50,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _removeRow(index),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline,
                            color: Colors.red.shade600, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stock Group Dropdown
              _buildLabel(context.tr('Stock Group *')),
              const SizedBox(height: 6),
              ValueListenableBuilder<List<dynamic>>(
                valueListenable: _stockGroupsNotifier,
                builder: (_, groups, __) {
                  final currentGroupId =
                      (row['stock_group'] as Map<String, dynamic>?)?['id']
                          ?.toString();
                  return DropdownButtonFormField<String>(
                    value: currentGroupId,
                    icon: Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined,
                          color: Colors.grey.shade600),
                      hintText: context.tr('Select Stock Group'),
                      hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade500, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF000080), width: 1.5),
                      ),
                    ),
                    items: groups.map((g) {
                      final grp =
                          Map<String, dynamic>.from(g as Map);
                      return DropdownMenuItem<String>(
                        value: grp['id']?.toString(),
                        child: Text(
                          grp['name'] ?? '',
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (groupId) async {
                      if (groupId == null) return;
                      final grp = groups.firstWhere(
                          (g) => g['id']?.toString() == groupId,
                          orElse: () => <String, dynamic>{});
                      final rows = List<Map<String, dynamic>>.from(
                          _itemRowsNotifier.value);
                      rows[index]['stock_group'] = grp;
                      rows[index]['stock'] = null;
                      rows[index]['stocks'] = <dynamic>[];
                      rows[index]['stocks_loading'] = true;
                      _itemRowsNotifier.value = List.from(rows);

                      final stocks = await _fetchStocksByGroup(groupId);
                      final updatedRows =
                          List<Map<String, dynamic>>.from(
                              _itemRowsNotifier.value);
                      updatedRows[index]['stocks'] = stocks;
                      updatedRows[index]['stocks_loading'] = false;
                      _itemRowsNotifier.value = List.from(updatedRows);
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Stock Item – searchable via bottom sheet
              _buildLabel(context.tr('Stock Item *')),
              const SizedBox(height: 6),
              _buildStockItemSelector(index, row),
              const SizedBox(height: 12),

              // Rate / Qty / Tax  in a row
              Row(
                children: [
                  Expanded(
                    child: _buildInlineField(
                      controller: row['rate_controller'],
                      label: context.tr('Rate'),
                      icon: Icons.attach_money,
                      onChanged: (_) => _refreshTotals(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInlineField(
                      controller: row['qty_controller'],
                      label: context.tr('Qty'),
                      icon: Icons.production_quantity_limits,
                      onChanged: (_) => _refreshTotals(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInlineField(
                      controller: row['tax_controller'],
                      label: context.tr('Tax %'),
                      icon: Icons.percent,
                      onChanged: (_) => _refreshTotals(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Line total
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000080).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calculate_outlined,
                          size: 14,
                          color: const Color(0xFF000080)),
                      const SizedBox(width: 6),
                      Text(
                        '${context.read<AuthProvider>().currencySymbol}${_calcRowTotal(row).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF000080),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItemSelector(int index, Map<String, dynamic> row) {
    final isLoading = row['stocks_loading'] == true;
    final stocks = (row['stocks'] as List<dynamic>?) ?? [];
    final selectedStock = row['stock'] as Map<String, dynamic>?;

    if (isLoading) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF000080)),
            ),
            const SizedBox(width: 12),
            Text(
              context.tr('Loading stock items...'),
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (stocks.isEmpty && row['stock_group'] == null) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          context.tr('Select a Stock Group first'),
          style: GoogleFonts.inter(
              fontSize: 14, color: Colors.grey.shade400),
        ),
      );
    }

    // Show searchable selector via InkWell → BottomSheet
    return InkWell(
      onTap: stocks.isEmpty
          ? null
          : () {
              _showStockItemSelector(index, stocks);
            },
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
                selectedStock != null
                    ? selectedStock['item_name'] ?? ''
                    : stocks.isEmpty
                        ? context.tr('No items in this group')
                        : context.tr('Select Stock Item'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: selectedStock != null
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
    );
  }

  void _showStockItemSelector(int index, List<dynamic> stocks) {
    final search = ValueNotifier<String>('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Select Stock Item'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF000080),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('Search stock items...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => search.value = v.toLowerCase(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: search,
                builder: (_, q, __) {
                  final filtered = stocks.where((s) {
                    final name = (s['item_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        context.tr('No stock items found'),
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = Map<String, dynamic>.from(
                          filtered[i] as Map);
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EAF6),
                          child: Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF000080), size: 18),
                        ),
                        title: Text(
                          s['item_name'] ?? '',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: (s['hsn_code'] ?? '').toString().isNotEmpty
                            ? Text(
                                'HSN: ${s['hsn_code']}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right,
                            size: 18),
                        onTap: () {
                          final rows =
                              List<Map<String, dynamic>>.from(
                                  _itemRowsNotifier.value);
                          rows[index]['stock'] = s;
                          rows[index]['hsn'] =
                              s['hsn_code']?.toString() ?? '';
                          // Pre-fill tax percentage from stock item (CGST+SGST or IGST)
                          final dynamic taxVal = s['tax_percent'] ??
                              ((s['cgst_percent'] != null || s['sgst_percent'] != null)
                                  ? ((s['cgst_percent'] ?? 0) + (s['sgst_percent'] ?? 0))
                                  : s['igst_percent']);
                          if (taxVal != null) {
                            rows[index]['tax_controller'].text = taxVal.toString();
                          }
                          _itemRowsNotifier.value = List.from(rows);
                          Navigator.pop(ctx);
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

  void _refreshTotals() {
    // Trigger rebuild to refresh total display
    _itemRowsNotifier.value = List.from(_itemRowsNotifier.value);
  }

  // ── Helper Widgets (matching expense_screen pattern) ──────────────────────

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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    style:
                        GoogleFonts.inter(fontSize: 15, color: Colors.black87),
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

  Widget _buildTextFieldWidget(
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              borderSide:
                  const BorderSide(color: Color(0xFF000080), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade500),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF000080), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(
      String label, double amount, AuthProvider auth,
      {Color? accent}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          '${auth.currencySymbol}${amount.toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accent ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
