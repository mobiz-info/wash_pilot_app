import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../config/country_config.dart';
import 'expense_screen.dart';

class PurchaseRequestScreen extends StatefulWidget {
  const PurchaseRequestScreen({super.key});

  @override
  State<PurchaseRequestScreen> createState() => _PurchaseRequestScreenState();
}

class _PurchaseRequestScreenState extends State<PurchaseRequestScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  final _purchaseExpenses = ValueNotifier<List<dynamic>>([]);

  @override
  void initState() {
    super.initState();
    _fetchPurchaseExpenses();
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _errorMessage.dispose();
    _purchaseExpenses.dispose();
    super.dispose();
  }

  Future<void> _fetchPurchaseExpenses() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final res = await ApiService.getPurchaseExpensesList(token);
      if (res['success'] == true) {
        _purchaseExpenses.value = res['purchase_expenses'] ?? [];
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load purchase expenses';
        _isLoading.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  void _navigateToAddPurchaseExpense() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseScreen()),
    );
    _fetchPurchaseExpenses();
  }

  Future<void> _showPaymentUpdateDialog(Map<String, dynamic> expense) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final maxBalance = double.tryParse(expense['balance_amount']?.toString() ?? '0') ?? 0;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Add Payment'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr("Remaining Balance")}: ${CountryConfig.currencySymbol}${maxBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Payment Amount *'),
                        labelStyle: GoogleFonts.inter(),
                        prefixText: CountryConfig.currencySymbol,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('Please enter amount');
                        }
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) {
                          return context.tr('Please enter a valid amount');
                        }
                        if (val > maxBalance) {
                          return context.tr('Amount cannot exceed remaining balance');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context, false),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final amount = double.parse(controller.text.trim());
                              final res = await ApiService.updatePurchaseExpensePayment(
                                token,
                                expense['id'],
                                amount,
                              );
                              if (res['success'] == true) {
                                Navigator.pop(context, true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? context.tr('Failed to update payment')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setDialogState(() => isSaving = false);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.tr('Pay')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Payment recorded successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      _fetchPurchaseExpenses();
    }
  }

  String _formatDisplayDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Purchase Expenses'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchPurchaseExpenses,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, loading, _) => ValueListenableBuilder<String>(
          valueListenable: _errorMessage,
          builder: (context, errMsg, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _purchaseExpenses,
            builder: (context, expenses, _) => loading
              ? const Center(child: CircularProgressIndicator())
              : errMsg.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(errMsg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchPurchaseExpenses,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                              child: Text(context.tr('Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : expenses.isEmpty
                      ? Center(child: Text(context.tr('No purchase expenses found'), style: GoogleFonts.inter(color: Colors.grey, fontSize: 15)))
                      : RefreshIndicator(
                          onRefresh: _fetchPurchaseExpenses,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: expenses.length,
                            itemBuilder: (ctx, i) {
                              final expense = Map<String, dynamic>.from(expenses[i] as Map);
                          final name = expense['expense_name'] ?? '';
                          final branch = expense['branch_name'] ?? '';
                          final supplier = expense['supplier_name'] ?? '';
                          final dateStr = _formatDisplayDate(expense['expense_date'] ?? '');
                          final remarks = expense['remarks'] ?? '';
                          
                          final total = double.tryParse(expense['amount']?.toString() ?? '0') ?? 0;
                          final paid = double.tryParse(expense['paid_amount']?.toString() ?? '0') ?? 0;
                          final balance = double.tryParse(expense['balance_amount']?.toString() ?? '0') ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
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
                                        child: Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF000080).withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          branch,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF000080),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.business_outlined, size: 15, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${context.tr("Supplier")}: $supplier',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey.shade600),
                                      const SizedBox(width: 6),
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (remarks.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.notes, size: 15, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            remarks,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(context.tr('Total'), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${CountryConfig.currencySymbol}${total.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(context.tr('Paid'), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${CountryConfig.currencySymbol}${paid.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(context.tr('Balance'), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${CountryConfig.currencySymbol}${balance.toStringAsFixed(2)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: balance > 0 ? Colors.red.shade700 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (balance > 0) ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showPaymentUpdateDialog(expense),
                                        icon: const Icon(Icons.payment, size: 18),
                                        label: Text(context.tr('Record Payment')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF000080),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPurchaseExpense,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
