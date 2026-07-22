import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class OilStockScreen extends StatefulWidget {
  const OilStockScreen({super.key});

  @override
  State<OilStockScreen> createState() => _OilStockScreenState();
}

class _OilStockScreenState extends State<OilStockScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _stocks = [];
  List<dynamic> _products = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final stockRes = await ApiService.getOilStock(token);
      final prodRes = await ApiService.getOilProducts(token);

      if (stockRes['success'] == true) {
        setState(() {
          _stocks = stockRes['oil_stock'] ?? [];
          _products = prodRes['success'] == true ? prodRes['oil_products'] ?? [] : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = stockRes['message'] ?? 'Failed to load stock levels';
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

  Future<void> _openStockInModal() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('No active oil products in master database.')), backgroundColor: Colors.orange),
      );
      return;
    }

    String? selectedProductId = _products[0]['id'];
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_business_outlined, color: Color(0xFF000080)),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Add Oil Stock (Stock-In)'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF000080)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: InputDecoration(
                      labelText: context.tr('Select Oil Product'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _products.map<DropdownMenuItem<String>>((p) {
                      final name = p['display_name'] ?? '';
                      final vol = p['recommended_qty_litres'] ?? 1.0;
                      return DropdownMenuItem<String>(
                        value: p['id'] as String,
                        child: Text('$name (${vol}L)', style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedProductId = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.tr('Quantity (Units/Bottles) *'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: context.tr('Notes / Supplier / Bill No.'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final qty = double.tryParse(quantityController.text) ?? 0.0;
                            if (qty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('Please enter a valid quantity.')), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            final token = context.read<AuthProvider>().token!;
                            try {
                              final res = await ApiService.addOilStock(selectedProductId!, qty, notesController.text.trim(), token);
                              if (res['success'] == true) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? context.tr('Stock updated successfully!')), backgroundColor: Colors.green),
                                );
                                _loadData();
                              } else {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? context.tr('Failed to update stock.')), backgroundColor: Colors.red),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000080),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(context.tr('Record Stock-In'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Oil Stock Management'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: context.tr('Search by name, brand, or grade...'),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF000080)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF000080), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: Builder(
                          builder: (context) {
                            final query = _searchQuery.trim().toLowerCase();
                            final filteredStocks = _stocks.where((s) {
                              final product = (s['oil_product'] ?? '').toString().toLowerCase();
                              final brand = (s['brand'] ?? '').toString().toLowerCase();
                              final grade = (s['grade'] ?? '').toString().toLowerCase();
                              return product.contains(query) ||
                                  brand.contains(query) ||
                                  grade.contains(query);
                            }).toList();

                            if (filteredStocks.isEmpty) {
                              return Center(
                                child: Text(
                                  context.tr('No matching stock items found.'),
                                  style: GoogleFonts.inter(color: Colors.grey),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredStocks.length,
                              itemBuilder: (context, index) {
                                final s = filteredStocks[index] as Map<String, dynamic>;
                                final product = s['oil_product'] ?? '';
                                final brand = s['brand'] ?? '';
                                final grade = s['grade'] ?? '';
                                final double qty = s['quantity_litres'] ?? 0.0;
                                final double vol = (s['volume_litres'] as num?)?.toDouble() ?? 1.0;
                                final bool isLow = s['is_low'] ?? false;

                                return Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: isLow ? Colors.red.shade200 : Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: (isLow ? Colors.red : const Color(0xFF000080)).withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.oil_barrel,
                                            color: isLow ? Colors.red : const Color(0xFF000080),
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product,
                                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$brand · Grade: $grade · Volume: ${vol}L',
                                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                                              ),
                                              if (isLow) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                                  child: Text(
                                                    context.tr('LOW STOCK ALERT'),
                                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${qty.toInt()} units',
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isLow ? Colors.red.shade700 : const Color(0xFF000080),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openStockInModal,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(context.tr('Stock-In'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
