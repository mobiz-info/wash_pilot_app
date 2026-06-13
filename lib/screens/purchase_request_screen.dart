import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class PurchaseRequestScreen extends StatefulWidget {
  const PurchaseRequestScreen({super.key});

  @override
  State<PurchaseRequestScreen> createState() => _PurchaseRequestScreenState();
}

class _PurchaseRequestScreenState extends State<PurchaseRequestScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _purchaseRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchPurchaseRequests();
  }

  Future<void> _fetchPurchaseRequests() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.getPurchaseRequests(token);
      if (res['success'] == true) {
        setState(() {
          _purchaseRequests = res['purchase_requests'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load purchase requests';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToCreateRequest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPurchaseRequestScreen()),
    );
    if (result == true) {
      _fetchPurchaseRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Purchase Requests'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchPurchaseRequests,
            icon: const Icon(Icons.refresh),
          )
        ],
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
                          onPressed: _fetchPurchaseRequests,
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
              : _purchaseRequests.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('No purchase requests found'),
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPurchaseRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _purchaseRequests.length,
                        itemBuilder: (ctx, i) {
                          final purchase = Map<String, dynamic>.from(_purchaseRequests[i] as Map);
                          final materialName = purchase['material_name'] ?? '';
                          final unitDisplay = purchase['unit_display'] ?? '';
                          final qty = purchase['qty'] ?? 0;
                          final status = purchase['status'] ?? 'PENDING';
                          final requestedBy = purchase['requested_by_name'] ?? '';
                          final remarks = purchase['remarks'] ?? '';
                          
                          // Format Date
                          String dateStr = '';
                          try {
                            final dt = DateTime.parse(purchase['date']);
                            dateStr = DateFormat('dd MMM yyyy').format(dt);
                          } catch (_) {
                            dateStr = purchase['date'] ?? '';
                          }

                          // Status Styling
                          Color statusColor = Colors.orange;
                          Color statusBg = const Color(0xFFFFF3E0);
                          if (status == 'APPROVED') {
                            statusColor = Colors.green;
                            statusBg = const Color(0xFFE8F5E9);
                          } else if (status == 'REJECTED') {
                            statusColor = Colors.red;
                            statusBg = const Color(0xFFFFEBEE);
                          }

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
                                          materialName,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          context.tr(status),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${context.tr("Quantity")}: $qty $unitDisplay',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF000080),
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 6),
                                          Text(
                                            requestedBy,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (remarks.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.notes, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            remarks,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateRequest,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddPurchaseRequestScreen extends StatefulWidget {
  const AddPurchaseRequestScreen({super.key});

  @override
  State<AddPurchaseRequestScreen> createState() => _AddPurchaseRequestScreenState();
}

class _AddPurchaseRequestScreenState extends State<AddPurchaseRequestScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _stocks = [];

  // Form fields
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _selectedStock;
  final _qtyController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStocks();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchStocks() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getStockList(token);
      if (res['success'] == true) {
        setState(() {
          _stocks = res['stocks'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load stock list';
          _isLoading = false;
        });
      }
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
      firstDate: DateTime(2025),
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

  void _showStockSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _StockSelectorBottomSheet(
          stocks: _stocks,
          onSelected: (stock) {
            setState(() {
              _selectedStock = stock;
            });
          },
          onStockCreated: (newStock) {
            setState(() {
              _stocks.add(newStock);
              _stocks.sort((a, b) => (a['item_name'] ?? '').toString().compareTo((b['item_name'] ?? '').toString()));
              _selectedStock = newStock;
            });
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    if (_selectedStock == null) {
      _showSnackBar(context.tr('Please select a material'), Colors.orange);
      return;
    }

    final qtyStr = _qtyController.text.trim();
    if (qtyStr.isEmpty) {
      _showSnackBar(context.tr('Please enter quantity'), Colors.orange);
      return;
    }

    final qty = double.tryParse(qtyStr);
    if (qty == null || qty <= 0) {
      _showSnackBar(context.tr('Please enter a valid quantity'), Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'material_id': _selectedStock!['id'],
        'qty': qty,
        'remarks': _remarksController.text.trim(),
      };

      final res = await ApiService.createPurchaseRequest(token, payload);
      if (res['success'] == true) {
        if (mounted) {
          _showSnackBar(context.tr('Purchase request submitted successfully!'), Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showSnackBar(res['message'] ?? context.tr('Failed to submit purchase request'), Colors.red);
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), Colors.red);
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Submit Purchase Request'),
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
                          onPressed: _fetchStocks,
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
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Selector Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Date'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMMM yyyy').format(_selectedDate),
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      const Icon(Icons.calendar_today, color: Color(0xFF000080)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Material Selector Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Select Material'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _showStockSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedStock != null
                                            ? '${_selectedStock!['item_name']} (${_selectedStock!['unit_display']})'
                                            : context.tr('Choose stock material...'),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: _selectedStock != null ? FontWeight.w600 : FontWeight.normal,
                                          color: _selectedStock != null ? Colors.black : Colors.grey.shade600,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Color(0xFF000080)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quantity and Remarks Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Quantity'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: context.tr('Enter quantity requested'),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  suffixText: _selectedStock != null ? _selectedStock!['unit'] : '',
                                ),
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                context.tr('Remarks / Notes'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _remarksController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: context.tr('Enter any remarks (optional)...'),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Save Button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                context.tr('Submit Purchase Request'),
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StockSelectorBottomSheet extends StatefulWidget {
  final List<dynamic> stocks;
  final ValueChanged<Map<String, dynamic>> onSelected;
  final ValueChanged<Map<String, dynamic>> onStockCreated;

  const _StockSelectorBottomSheet({
    required this.stocks,
    required this.onSelected,
    required this.onStockCreated,
  });

  @override
  State<_StockSelectorBottomSheet> createState() => _StockSelectorBottomSheetState();
}

class _StockSelectorBottomSheetState extends State<_StockSelectorBottomSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _filteredStocks = [];

  @override
  void initState() {
    super.initState();
    _filteredStocks = List.from(widget.stocks);
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
        _filteredStocks = List.from(widget.stocks);
      } else {
        _filteredStocks = widget.stocks.where((s) {
          final name = (s['item_name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addNewStock() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final nameController = TextEditingController();
    String selectedUnit = 'Litre';
    final formKey = GlobalKey<FormState>();

    final List<Map<String, String>> unitChoices = [
      {'value': 'Litre', 'display': 'Litre (Ltr)'},
      {'value': 'Millilitre', 'display': 'Millilitre (ml)'},
      {'value': 'Kilogram', 'display': 'Kilogram (Kg)'},
      {'value': 'Gram', 'display': 'Gram (g)'},
      {'value': 'Piece', 'display': 'Piece (Pcs)'},
      {'value': 'Box', 'display': 'Box'},
      {'value': 'Packet', 'display': 'Packet'},
      {'value': 'Bottle', 'display': 'Bottle'},
      {'value': 'Can', 'display': 'Can'},
      {'value': 'Roll', 'display': 'Roll'},
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Add Stock Item'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Item Name *'),
                        labelStyle: GoogleFonts.inter(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('Please enter item name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: InputDecoration(
                        labelText: context.tr('Unit *'),
                        labelStyle: GoogleFonts.inter(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: unitChoices.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['value'],
                          child: Text(context.tr(u['display']!)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          selectedUnit = val;
                        }
                      },
                    ),
                  ],
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
                              final res = await ApiService.createStock(
                                token,
                                nameController.text.trim(),
                                selectedUnit,
                              );
                              if (res['success'] == true && res['stock'] != null) {
                                Navigator.pop(context, Map<String, dynamic>.from(res['stock']));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? context.tr('Failed to create stock item')),
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
      widget.onStockCreated(result);
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
                context.tr('Select Material'),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (context.read<AuthProvider>().isCompanyAdmin)
                    IconButton(
                      onPressed: _addNewStock,
                      icon: const Icon(Icons.add, color: Color(0xFF000080)),
                      tooltip: context.tr('Add Stock Item'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search materials...'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _filteredStocks.isEmpty
                ? Center(child: Text(context.tr('No materials found')))
                : ListView.builder(
                    itemCount: _filteredStocks.length,
                    itemBuilder: (context, index) {
                      final item = Map<String, dynamic>.from(_filteredStocks[index] as Map);
                      return ListTile(
                        title: Text(
                          item['item_name'] ?? '',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(item['unit_display'] ?? ''),
                        onTap: () {
                          widget.onSelected(item);
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
