import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class SupplierPayablesScreen extends StatefulWidget {
  const SupplierPayablesScreen({super.key});

  @override
  State<SupplierPayablesScreen> createState() => _SupplierPayablesScreenState();
}

class _SupplierPayablesScreenState extends State<SupplierPayablesScreen> {
  final ValueNotifier<List<dynamic>> _suppliersNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<String> _errorNotifier = ValueNotifier('');
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPayables();
    });
  }

  @override
  void dispose() {
    _suppliersNotifier.dispose();
    _isLoadingNotifier.dispose();
    _errorNotifier.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadPayables() async {
    _isLoadingNotifier.value = true;
    _errorNotifier.value = '';

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      _errorNotifier.value = context.tr('Not authenticated');
      _isLoadingNotifier.value = false;
      return;
    }

    try {
      final res = await ApiService.getSupplierPayables(token);
      if (res['success'] == true) {
        _suppliersNotifier.value = res['suppliers'] ?? [];
        _isLoadingNotifier.value = false;
      } else {
        _errorNotifier.value = res['message'] ?? (mounted ? context.tr('Failed to load payables') : 'Failed to load payables');
        _isLoadingNotifier.value = false;
      }
    } catch (e) {
      _errorNotifier.value = e.toString();
      _isLoadingNotifier.value = false;
    }
  }

  List<dynamic> _getFilteredSuppliers(List<dynamic> suppliers, String query) {
    if (query.trim().isEmpty) return suppliers;
    final q = query.toLowerCase().trim();
    return suppliers.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final phone = (s['phone_no'] ?? '').toString().toLowerCase();
      final gst = (s['gst_no'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || gst.contains(q);
    }).toList();
  }

  double _calculateTotalPayables(List<dynamic> suppliers) {
    double total = 0;
    for (final s in suppliers) {
      total += double.tryParse(s['payables']?.toString() ?? '0') ?? 0.0;
    }
    return total;
  }

  void _showPayModal(Map<String, dynamic> supplier) {
    final outstandingPayable = double.tryParse(supplier['payables']?.toString() ?? '0') ?? 0.0;

    final amountController = TextEditingController(text: outstandingPayable.toStringAsFixed(2));
    final bankController = TextEditingController();
    final chequeNoController = TextEditingController();
    final chequeDateController = TextEditingController();
    final remarksController = TextEditingController();

    final paymentModeNotifier = ValueNotifier<String>('CASH');
    final selectedDateNotifier = ValueNotifier<DateTime>(DateTime.now());
    final isSavingNotifier = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_outlined, color: Color(0xFF000080)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('Record Payment'),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Supplier Banner Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF000080),
                        radius: 20,
                        child: Icon(Icons.business, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier['name'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if ((supplier['phone_no'] ?? '').isNotEmpty)
                              Text(
                                'Ph: ${supplier['phone_no']}',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            context.tr('Payable'),
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${context.read<AuthProvider>().currencySymbol}${outstandingPayable.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Payment Mode Selector
                _buildLabel(context.tr('Payment Mode')),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: paymentModeNotifier,
                  builder: (_, currentMode, __) {
                    return Row(
                      children: [
                        _buildModeChip('CASH', context.tr('Cash'), Icons.money, currentMode, paymentModeNotifier),
                        const SizedBox(width: 8),
                        _buildModeChip('DIGITAL', context.tr('Digital'), Icons.qr_code_scanner, currentMode, paymentModeNotifier),
                        const SizedBox(width: 8),
                        _buildModeChip('CHEQUE', context.tr('Cheque'), Icons.account_balance, currentMode, paymentModeNotifier),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Cheque details if Cheque selected
                ValueListenableBuilder<String>(
                  valueListenable: paymentModeNotifier,
                  builder: (_, mode, __) {
                    if (mode != 'CHEQUE') return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            context,
                            bankController,
                            context.tr('Bank Name'),
                            Icons.account_balance_outlined,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  context,
                                  chequeNoController,
                                  context.tr('Cheque No'),
                                  Icons.tag,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildClickableField(
                                  context,
                                  label: context.tr('Cheque Date'),
                                  icon: Icons.calendar_today,
                                  value: chequeDateController.text.isNotEmpty
                                      ? chequeDateController.text
                                      : context.tr('Select Date'),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: modalCtx,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (d != null) {
                                      chequeDateController.text = DateFormat('yyyy-MM-dd').format(d);
                                      paymentModeNotifier.value = paymentModeNotifier.value;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Amount Paid & Payment Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        context,
                        amountController,
                        context.tr('Amount Paid *'),
                        Icons.payments,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: selectedDateNotifier,
                        builder: (_, pDate, __) {
                          return _buildClickableField(
                            context,
                            label: context.tr('Date'),
                            icon: Icons.calendar_today,
                            value: DateFormat('dd-MM-yyyy').format(pDate),
                            onTap: () async {
                              final d = await showDatePicker(
                                context: modalCtx,
                                initialDate: pDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) {
                                selectedDateNotifier.value = d;
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Remarks
                _buildTextField(
                  context,
                  remarksController,
                  context.tr('Remarks (Optional)'),
                  Icons.notes,
                ),

                const SizedBox(height: 20),

                // Submit Button
                ValueListenableBuilder<bool>(
                  valueListenable: isSavingNotifier,
                  builder: (_, isSaving, __) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final token = context.read<AuthProvider>().token;
                                if (token == null) return;
                                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                                if (amt <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('Please enter valid amount'))),
                                  );
                                  return;
                                }

                                isSavingNotifier.value = true;
                                try {
                                  final payRes = await ApiService.createSupplierPayment({
                                    'supplier_id': supplier['id'],
                                    'amount_paid': amt,
                                    'payment_date': DateFormat('yyyy-MM-dd').format(selectedDateNotifier.value),
                                    'payment_mode': paymentModeNotifier.value,
                                    'bank_name': bankController.text.trim(),
                                    'cheque_number': chequeNoController.text.trim(),
                                    'cheque_date': chequeDateController.text.trim(),
                                    'remarks': remarksController.text.trim(),
                                  }, token);

                                  if (payRes['success'] == true) {
                                    if (modalCtx.mounted) Navigator.pop(modalCtx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(payRes['message'] ?? context.tr('Payment recorded successfully')),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _loadPayables();
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(payRes['message'] ?? context.tr('Error recording payment')),
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
                                } finally {
                                  isSavingNotifier.value = false;
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                context.tr('Save Payment'),
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeChip(
    String mode,
    String label,
    IconData icon,
    String currentMode,
    ValueNotifier<String> modeNotifier,
  ) {
    final isSelected = currentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => modeNotifier.value = mode,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF000080) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF000080) : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey.shade700),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.watch<AuthProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          context.tr('Supplier Payables'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF000080),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayables,
            tooltip: context.tr('Refresh'),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingNotifier,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF000080)),
            );
          }

          return ValueListenableBuilder<String>(
            valueListenable: _errorNotifier,
            builder: (context, errorMsg, _) {
              if (errorMsg.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(errorMsg, style: GoogleFonts.inter(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPayables,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                );
              }

              return ValueListenableBuilder<List<dynamic>>(
                valueListenable: _suppliersNotifier,
                builder: (context, suppliersList, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: _searchNotifier,
                    builder: (context, searchQuery, _) {
                      final filteredSuppliers = _getFilteredSuppliers(suppliersList, searchQuery);
                      final totalPayablesAmount = _calculateTotalPayables(suppliersList);

                      return Column(
                        children: [
                          // Top Summary Banner Card
                          Container(
                            width: double.infinity,
                            color: const Color(0xFF000080),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('Total Supplier Payables'),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$currencySymbol${totalPayablesAmount.toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
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
                                      '${suppliersList.length} ${context.tr("Suppliers")}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF000080),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Search Bar
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              onChanged: (v) => _searchNotifier.value = v,
                              decoration: InputDecoration(
                                hintText: context.tr('Search supplier by name, phone or GST...'),
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),

                          // Supplier List
                          Expanded(
                            child: filteredSuppliers.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.business_outlined,
                                          size: 54,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          searchQuery.isNotEmpty
                                              ? context.tr('No matching suppliers found')
                                              : context.tr('No supplier payables!'),
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadPayables,
                                    color: const Color(0xFF000080),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: filteredSuppliers.length,
                                      itemBuilder: (context, index) {
                                        final s = Map<String, dynamic>.from(filteredSuppliers[index] as Map);
                                        final payables = double.tryParse(s['payables']?.toString() ?? '0') ?? 0.0;
                                        final phone = s['phone_no']?.toString() ?? '';
                                        final gst = s['gst_no']?.toString() ?? '';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF000080).withValues(alpha: 0.04),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                                                      child: const Icon(Icons.business_rounded, color: Color(0xFF000080), size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            s['name'] ?? '',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF0F172A),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          if (phone.isNotEmpty)
                                                            Row(
                                                              children: [
                                                                Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade600),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  phone,
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: 13,
                                                                    color: Colors.grey.shade600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (gst.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                'GST: $gst',
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 11,
                                                                  color: Colors.grey.shade500,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    ElevatedButton.icon(
                                                      onPressed: () => _showPayModal(s),
                                                      icon: const Icon(Icons.handshake_outlined, size: 16),
                                                      label: Text(
                                                        context.tr('Pay Now'),
                                                        style: GoogleFonts.inter(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF000080),
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Divider(height: 20),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      context.tr('Outstanding Payables'),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: payables > 0 ? Colors.red.shade50 : Colors.green.shade50,
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: payables > 0 ? Colors.red.shade200 : Colors.green.shade200,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        '$currencySymbol${payables.toStringAsFixed(2)}',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w800,
                                                          color: payables > 0 ? Colors.red.shade700 : Colors.green.shade700,
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
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
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
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
}
