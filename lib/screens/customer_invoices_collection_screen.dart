import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CustomerInvoicesCollectionScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final double totalOutstanding;

  const CustomerInvoicesCollectionScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.totalOutstanding,
  });

  @override
  State<CustomerInvoicesCollectionScreen> createState() =>
      _CustomerInvoicesCollectionScreenState();
}

class _CustomerInvoicesCollectionScreenState
    extends State<CustomerInvoicesCollectionScreen> {
  List<dynamic> _invoices = [];
  bool _loading = true;
  String _error = '';
  bool _collecting = false;

  final _amountController = TextEditingController();
  String _selectedPaymentMode = 'cash'; // 'cash', 'card', 'digital_payments'

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalOutstanding.toStringAsFixed(2);
    _fetchCustomerInvoices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerInvoices() async {
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
      final res = await ApiService.getOutstandingList(token);
      if (res['success'] == true) {
        final allInvoices = res['invoices'] as List<dynamic>? ?? [];
        setState(() {
          _invoices = allInvoices.where((inv) {
            final cust = inv['customer'];
            return cust != null && cust['id'] == widget.customerId;
          }).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load invoices';
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

  Future<void> _collectPayment() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Enter a valid amount')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amt > widget.totalOutstanding) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Amount exceeds outstanding balance'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _collecting = true);
    final token = context.read<AuthProvider>().token ?? '';

    try {
      final res = await ApiService.collectCustomerOutstanding(
        customerId: widget.customerId,
        amount: amt,
        paymentMode: _selectedPaymentMode,
        token: token,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${context.tr('Collected')} ${widget.totalOutstanding - amt == 0 ? 'full' : ''} payment of ${_amountController.text} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _collecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to collect payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _collecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = context.watch<AuthProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        title: Text(
          context.tr('Customer Invoices'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Customer details card
          Container(
            width: double.infinity,
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.person, color: Color(0xFF000080)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customerName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.customerPhone,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.tr('Total Due'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade200,
                        ),
                      ),
                      Text(
                        '$currencySymbol${widget.totalOutstanding.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.red.shade100,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Invoices List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF000080),
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _invoices.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No outstanding invoices found.'),
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final inv = _invoices[index];
                              final outstanding = double.tryParse(
                                      inv['outstanding']?.toString() ?? '0') ??
                                  0;
                              final total = double.tryParse(
                                      inv['total']?.toString() ?? '0') ??
                                  0;
                              final collected = double.tryParse(
                                      inv['amount_collected']?.toString() ??
                                          '0') ??
                                  0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Invoice #${inv['invoice_number']}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: const Color(0xFF1e293b),
                                          ),
                                        ),
                                        Text(
                                          '$currencySymbol${outstanding.toStringAsFixed(2)}',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: const Color(0xFFdc2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.directions_car_outlined,
                                          size: 14,
                                          color: Color(0xFF64748b),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          inv['vehicle']['number'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF64748b),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: Color(0xFF64748b),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          inv['date'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF64748b),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          context.tr(
                                              'Collected: $currencySymbol${collected.toStringAsFixed(2)}'),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF16a34a),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          context.tr(
                                              'Total: $currencySymbol${total.toStringAsFixed(2)}'),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF64748b),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),

          // Bottom payment entry panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Amount to Collect'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              prefixText: '$currencySymbol ',
                              hintText: context.tr('0.00'),
                              filled: true,
                              fillColor: const Color(0xFFf8fafc),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFd1d5db)),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Payment Mode'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedPaymentMode,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFf8fafc),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFd1d5db)),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text(context.tr('Cash')),
                              ),
                              DropdownMenuItem(
                                value: 'card',
                                child: Text(context.tr('Card')),
                              ),
                              DropdownMenuItem(
                                value: 'digital_payments',
                                child: Text(context.tr('Digital payments')),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedPaymentMode = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _collecting ? null : _collectPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _collecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          context.tr('Collect Payment'),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
