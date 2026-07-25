import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class StockManagementScreen extends StatefulWidget {
  final String? initialCategory;
  const StockManagementScreen({super.key, this.initialCategory});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  
  // Data lists
  final _branches = ValueNotifier<List<dynamic>>([]);
  final _oilStocks = ValueNotifier<List<dynamic>>([]);
  final _generalStocks = ValueNotifier<List<dynamic>>([]);
  final _oilFilters = ValueNotifier<List<dynamic>>([]);
  final _oilProducts = ValueNotifier<List<dynamic>>([]);
  
  // Selections
  String? _selectedBranchId;
  String _selectedCategory = 'ALL'; // ALL, OIL, FILTER, GENERAL
  final TextEditingController _searchController = TextEditingController();
  final _searchQuery = ValueNotifier<String>('');

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'label': 'All Categories', 'icon': 'apps'},
    {'key': 'OIL', 'label': 'Oils & Lubricants', 'icon': 'oil'},
    {'key': 'FILTER', 'label': 'Oil & Air Filters', 'icon': 'filter'},
    {'key': 'GENERAL', 'label': 'General Consumables', 'icon': 'inventory'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _branches.dispose();
    _oilStocks.dispose();
    _generalStocks.dispose();
    _oilFilters.dispose();
    _oilProducts.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    // 1. Fetch Company Branches if empty
    try {
      if (_branches.value.isEmpty) {
        final bRes = await ApiService.getCompanyBranches(token);
        if (bRes['success'] == true) {
          final bList = bRes['branches'] as List<dynamic>? ?? [];
          _branches.value = bList;
          if (bList.isNotEmpty && _selectedBranchId == null) {
            _selectedBranchId = bList[0]['id']?.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching branches: $e');
    }

    // 2. Fetch Oil Stocks for selected branch
    try {
      final oilRes = await ApiService.getOilStock(token, branchId: _selectedBranchId);
      if (oilRes['success'] == true) {
        _oilStocks.value = oilRes['oil_stock'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching oil stock: $e');
    }

    // 3. Fetch General Stock Items
    try {
      final genRes = await ApiService.getStockList(token);
      if (genRes['success'] == true) {
        _generalStocks.value = genRes['stocks'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching general stock: $e');
    }

    // 4. Fetch Oil Filters
    try {
      final filterRes = await ApiService.getOilFilters(token);
      if (filterRes['success'] == true) {
        _oilFilters.value = filterRes['oil_filters'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching oil filters: $e');
    }

    // 5. Fetch Oil Products
    try {
      final prodRes = await ApiService.getOilProducts(token);
      if (prodRes['success'] == true) {
        _oilProducts.value = prodRes['oil_products'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching oil products: $e');
    }

    _isLoading.value = false;
  }

  // ── Unified Stock-In Modal ───────────────────────────────────────────────
  Future<void> _openStockInModal() async {
    String stockCategory = _selectedCategory == 'ALL' ? 'OIL' : _selectedCategory;
    final token = context.read<AuthProvider>().token!;
    
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    
    String? selectedOilProductId = _oilProducts.value.isNotEmpty ? _oilProducts.value[0]['id'] : null;
    String? selectedFilterId = _oilFilters.value.isNotEmpty ? _oilFilters.value[0]['id'] : null;
    String? selectedGeneralStockId = _generalStocks.value.isNotEmpty ? _generalStocks.value[0]['id'] : null;
    
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
                        context.tr('Add Inventory (Stock-In)'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF000080)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  
                  // Category Dropdown inside Modal
                  DropdownButtonFormField<String>(
                    value: stockCategory,
                    decoration: InputDecoration(
                      labelText: context.tr('Select Category'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'OIL', child: Text('🛢️ Oils & Lubricants')),
                      DropdownMenuItem(value: 'FILTER', child: Text('⚙️ Oil & Air Filters')),
                      DropdownMenuItem(value: 'GENERAL', child: Text('📦 General Consumables')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => stockCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Product Selector depending on Category
                  if (stockCategory == 'OIL') ...[
                    DropdownButtonFormField<String>(
                      value: selectedOilProductId,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Oil Product *'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: _oilProducts.value.map<DropdownMenuItem<String>>((p) {
                        final name = p['display_name'] ?? '';
                        final vol = p['recommended_qty_litres'] ?? 1.0;
                        return DropdownMenuItem<String>(
                          value: p['id'] as String,
                          child: Text('$name (${vol}L)', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedOilProductId = val),
                    ),
                  ] else if (stockCategory == 'FILTER') ...[
                    DropdownButtonFormField<String>(
                      value: selectedFilterId,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Oil Filter *'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: _oilFilters.value.map<DropdownMenuItem<String>>((f) {
                        final b = f['brand_name'] ?? '';
                        final n = f['name'] ?? '';
                        final p = f['price'] ?? 0;
                        return DropdownMenuItem<String>(
                          value: f['id'] as String,
                          child: Text('$b - $n (${CountryConfig.currencySymbol}$p)', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedFilterId = val),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: selectedGeneralStockId,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Stock Item *'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: _generalStocks.value.map<DropdownMenuItem<String>>((s) {
                        final name = s['item_name'] ?? '';
                        final unit = s['unit_display'] ?? '';
                        return DropdownMenuItem<String>(
                          value: s['id'] as String,
                          child: Text('$name ($unit)', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedGeneralStockId = val),
                    ),
                  ],

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: stockCategory == 'OIL' ? context.tr('Quantity (Bottles / Units) *') : context.tr('Quantity *'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: context.tr('Notes / Supplier / Invoice No.'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

                            try {
                              if (stockCategory == 'OIL' && selectedOilProductId != null) {
                                final res = await ApiService.addOilStock(
                                  selectedOilProductId!,
                                  qty,
                                  notesController.text.trim(),
                                  token,
                                  branchId: _selectedBranchId,
                                );
                                if (res['success'] == true) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res['message'] ?? context.tr('Oil stock updated!')), backgroundColor: Colors.green),
                                  );
                                  _loadAllData();
                                  return;
                                }
                              } else if (stockCategory == 'FILTER' && selectedFilterId != null) {
                                final res = await ApiService.addOilFilterStock(
                                  selectedFilterId!,
                                  qty.toInt(),
                                  token,
                                );
                                if (res['success'] == true) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res['message'] ?? context.tr('Filter stock updated!')), backgroundColor: Colors.green),
                                  );
                                  _loadAllData();
                                  return;
                                }
                              } else {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.tr('Stock recorded successfully!')), backgroundColor: Colors.green),
                                );
                                _loadAllData();
                                return;
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
        title: Text(context.tr('Stock Management'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, loading, _) => ValueListenableBuilder<String>(
          valueListenable: _errorMessage,
          builder: (context, errMsg, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _branches,
            builder: (context, branches, _) => ValueListenableBuilder<List<dynamic>>(
              valueListenable: _oilStocks,
              builder: (context, oilStocks, _) => ValueListenableBuilder<List<dynamic>>(
                valueListenable: _generalStocks,
                builder: (context, generalStocks, _) => ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _oilFilters,
                  builder: (context, oilFilters, _) => ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) {
                      if (loading) return const Center(child: CircularProgressIndicator());
                      if (errMsg.isNotEmpty) return Center(child: Text(errMsg, style: const TextStyle(color: Colors.red)));

                      // Filter items based on selected category & search query
                      final q = query.trim().toLowerCase();
                      final List<Map<String, dynamic>> combinedDisplayItems = [];

                      // 1. Add Oils if category is ALL or OIL
                      if (_selectedCategory == 'ALL' || _selectedCategory == 'OIL') {
                        for (var s in oilStocks) {
                          final product = (s['oil_product'] ?? '').toString();
                          final brand = (s['brand'] ?? '').toString();
                          final grade = (s['grade'] ?? '').toString();
                          final double qty = (s['quantity_litres'] as num?)?.toDouble() ?? 0.0;
                          final double vol = (s['volume_litres'] as num?)?.toDouble() ?? 1.0;
                          final bool isLow = s['is_low'] ?? false;

                          if (q.isEmpty || product.toLowerCase().contains(q) || brand.toLowerCase().contains(q) || grade.toLowerCase().contains(q)) {
                            combinedDisplayItems.add({
                              'type': 'OIL',
                              'title': product,
                              'subtitle': '$brand · Grade: $grade · Vol: ${vol}L',
                              'qty_text': '${qty.toInt()} units',
                              'is_low': isLow,
                              'icon': Icons.oil_barrel,
                              'color': Colors.amber.shade900,
                              'bg_color': Colors.amber.shade50,
                            });
                          }
                        }
                      }

                      // 2. Add Filters if category is ALL or FILTER
                      if (_selectedCategory == 'ALL' || _selectedCategory == 'FILTER') {
                        for (var f in oilFilters) {
                          final brand = (f['brand_name'] ?? '').toString();
                          final name = (f['name'] ?? '').toString();
                          final price = (f['price'] as num?)?.toDouble() ?? 0.0;
                          final km = f['running_km'] ?? 5000;
                          final stockQty = (f['stock_qty'] as num?)?.toInt() ?? 0;

                          if (q.isEmpty || brand.toLowerCase().contains(q) || name.toLowerCase().contains(q)) {
                            combinedDisplayItems.add({
                              'type': 'FILTER',
                              'title': '$brand - $name',
                              'subtitle': 'Price: ${CountryConfig.currencySymbol}${price.toStringAsFixed(2)} · Lifespan: $km KM',
                              'qty_text': '$stockQty units',
                              'is_low': stockQty <= 2,
                              'icon': Icons.filter_alt,
                              'color': Colors.blue.shade900,
                              'bg_color': Colors.blue.shade50,
                            });
                          }
                        }
                      }

                      // 3. Add General Items if category is ALL or GENERAL
                      if (_selectedCategory == 'ALL' || _selectedCategory == 'GENERAL') {
                        for (var g in generalStocks) {
                          final name = (g['item_name'] ?? '').toString();
                          final unit = (g['unit_display'] ?? '').toString();
                          final head = (g['expense_head_name'] ?? '').toString();
                          final qty = (g['quantity'] as num?)?.toDouble() ?? 0.0;

                          if (q.isEmpty || name.toLowerCase().contains(q) || head.toLowerCase().contains(q)) {
                            combinedDisplayItems.add({
                              'type': 'GENERAL',
                              'title': name,
                              'subtitle': head.isNotEmpty ? 'Unit: $unit · Head: $head' : 'Unit: $unit',
                              'qty_text': '${qty.toStringAsFixed(0)} $unit',
                              'is_low': qty <= 2,
                              'icon': Icons.inventory_2,
                              'color': const Color(0xFF0284C7),
                              'bg_color': const Color(0xFFE0F2FE),
                            });
                          }
                        }
                      }

                      return Column(
                        children: [
                          // ── Top Header Controls: Branch Selector & Category Filter Dropdown ──
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Branch Selector (if branches exist)
                                    if (branches.isNotEmpty) ...[
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: _selectedBranchId,
                                              icon: const Icon(Icons.store, size: 18, color: Color(0xFF000080)),
                                              items: branches.map<DropdownMenuItem<String>>((b) {
                                                final bName = b['name'] as String? ?? 'Branch';
                                                final bId = b['id']?.toString() ?? '';
                                                return DropdownMenuItem<String>(
                                                  value: bId,
                                                  child: Text(
                                                    bName,
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF000080)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (newBranchId) {
                                                if (newBranchId != null && newBranchId != _selectedBranchId) {
                                                  setState(() {
                                                    _selectedBranchId = newBranchId;
                                                  });
                                                  _loadAllData();
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],

                                    // Category Filter Dropdown
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: _selectedCategory,
                                            icon: Icon(Icons.category, size: 18, color: Colors.amber.shade900),
                                            items: _categories.map<DropdownMenuItem<String>>((c) {
                                              return DropdownMenuItem<String>(
                                                value: c['key']!,
                                                child: Text(
                                                  c['label']!,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (newCat) {
                                              if (newCat != null) {
                                                setState(() {
                                                  _selectedCategory = newCat;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Search Input Bar
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) => _searchQuery.value = value,
                                  decoration: InputDecoration(
                                    hintText: context.tr('Search product, brand or part no...'),
                                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF000080)),
                                    suffixIcon: query.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchQuery.value = '';
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // ── Inventory Item List ──────────────────────────
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _loadAllData,
                              child: combinedDisplayItems.isEmpty
                                  ? Center(
                                      child: Text(
                                        context.tr('No inventory items found'),
                                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: combinedDisplayItems.length,
                                      itemBuilder: (context, index) {
                                        final item = combinedDisplayItems[index];
                                        final title = item['title'] as String;
                                        final subtitle = item['subtitle'] as String;
                                        final qtyText = item['qty_text'] as String;
                                        final bool isLow = item['is_low'] as bool;
                                        final IconData icon = item['icon'] as IconData;
                                        final Color iconColor = item['color'] as Color;
                                        final Color bgColor = item['bg_color'] as Color;

                                        return Card(
                                          color: Colors.white,
                                          elevation: 0,
                                          margin: const EdgeInsets.only(bottom: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: isLow ? Colors.red.shade300 : Colors.grey.shade200),
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            leading: CircleAvatar(
                                              backgroundColor: isLow ? Colors.red.shade50 : bgColor,
                                              child: Icon(icon, color: isLow ? Colors.red : iconColor, size: 22),
                                            ),
                                            title: Text(
                                              title,
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 2),
                                                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                                                if (isLow) ...[
                                                  const SizedBox(height: 4),
                                                  Text('LOW STOCK ALERT', style: GoogleFonts.inter(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                                ],
                                              ],
                                            ),
                                            trailing: Text(
                                              qtyText,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: isLow ? Colors.red.shade700 : const Color(0xFF000080),
                                              ),
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openStockInModal,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: Text(context.tr('Stock-In'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
