import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class StockItemScreen extends StatefulWidget {
  const StockItemScreen({super.key});

  @override
  State<StockItemScreen> createState() => _StockItemScreenState();
}

class _StockItemScreenState extends State<StockItemScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _stocks = [];
  List<dynamic> _filteredStocks = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStocks();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStocks() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.getStockList(token);
      if (res['success'] == true) {
        setState(() {
          _stocks = res['stocks'] ?? [];
          _filteredStocks = List.from(_stocks);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load stock items';
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

  void _filter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStocks = List.from(_stocks);
      } else {
        _filteredStocks = _stocks.where((s) {
          final name = (s['item_name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addNewStockItem() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    List<dynamic> expenseHeads = [];
    try {
      final headRes = await ApiService.getExpenseHeads(token);
      if (headRes['success'] == true) {
        expenseHeads = headRes['expense_heads'] ?? [];
      }
    } catch (_) {}

    final nameController = TextEditingController();
    String selectedUnit = 'Litre';
    String? selectedExpenseHeadId;
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
                child: SingleChildScrollView(
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedExpenseHeadId,
                        decoration: InputDecoration(
                          labelText: context.tr('Expense Head'),
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: Text(context.tr('Select Expense Head')),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(context.tr('None')),
                          ),
                          ...expenseHeads.map((h) {
                            final head = Map<String, dynamic>.from(h as Map);
                            return DropdownMenuItem<String>(
                              value: head['id']?.toString(),
                              child: Text(head['name'] ?? ''),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedExpenseHeadId = val;
                          });
                        },
                      ),
                    ],
                  ),
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
                                expenseHeadId: selectedExpenseHeadId,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Stock item created successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      _fetchStocks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Stock Items'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchStocks,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('Search stock items...'),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
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
                    : _filteredStocks.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No stock items found'),
                              style: GoogleFonts.inter(color: Colors.grey, fontSize: 15),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredStocks.length,
                            itemBuilder: (ctx, i) {
                              final item = Map<String, dynamic>.from(_filteredStocks[i] as Map);
                              final name = item['item_name'] ?? '';
                              final unitDisplay = item['unit_display'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE0F2FE),
                                    foregroundColor: Color(0xFF0284C7),
                                    child: Icon(Icons.inventory_2_outlined),
                                  ),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${context.tr("Unit")}: $unitDisplay',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (item['expense_head_name'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${context.tr("Expense Head")}: ${item['expense_head_name']}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewStockItem,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
