import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
  final _stockGroups = ValueNotifier<List<dynamic>>([]);
  final _generalStocks = ValueNotifier<List<dynamic>>([]);

  // Selections
  String? _selectedBranchId;
  String _selectedCategory = 'ALL'; // ALL or group_id
  final TextEditingController _searchController = TextEditingController();
  final _searchQuery = ValueNotifier<String>('');

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
    _stockGroups.dispose();
    _generalStocks.dispose();
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

    // 2. Fetch Stock Groups
    try {
      final grpRes = await ApiService.getStockGroups(token);
      if (grpRes['success'] == true) {
        _stockGroups.value = grpRes['groups'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching stock groups: $e');
    }

    // 3. Fetch Stock List
    try {
      final genRes = await ApiService.getStockList(token);
      if (genRes['success'] == true) {
        _generalStocks.value = genRes['stocks'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching stock list: $e');
    }

    _isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Stock Management'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: Color(0xFF000080),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: context.tr('Refresh'),
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
              valueListenable: _stockGroups,
              builder: (context, stockGroups, _) => ValueListenableBuilder<List<dynamic>>(
                valueListenable: _generalStocks,
                builder: (context, generalStocks, _) => ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (context, query, _) {
                    if (loading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF000080)),
                      );
                    }
                    if (errMsg.isNotEmpty) {
                      return Center(
                        child: Text(errMsg, style: TextStyle(color: Colors.red)),
                      );
                    }

                    // Filter items based on selected Stock Group & search query
                    final q = query.trim().toLowerCase();
                    final List<Map<String, dynamic>> filteredItems = [];

                    for (var g in generalStocks) {
                      final item = Map<String, dynamic>.from(g as Map);
                      final name = (item['item_name'] ?? '').toString();
                      final groupName = (item['group_name'] ?? '').toString();
                      final groupId = (item['group_id'] ?? '').toString();
                      final unit = (item['main_unit'] ?? item['unit_display'] ?? item['unit'] ?? '').toString();
                      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                      final isLow = item['is_low_stock'] ?? (qty <= 2);

                      // Category (Group) filter check
                      bool matchCategory = true;
                      if (_selectedCategory != 'ALL') {
                        matchCategory = (groupId == _selectedCategory) || (groupName == _selectedCategory);
                      }

                      final brand = (item['brand'] ?? '').toString();
                      final subtitleParts = <String>[];
                      if (brand.isNotEmpty) subtitleParts.add('Brand: $brand');
                      if (groupName.isNotEmpty) subtitleParts.add('Group: $groupName');
                      subtitleParts.add('Unit: $unit');
                      final subtitleText = subtitleParts.join(' · ');

                      // Search query check
                      bool matchSearch = q.isEmpty ||
                          name.toLowerCase().contains(q) ||
                          brand.toLowerCase().contains(q) ||
                          groupName.toLowerCase().contains(q);

                      if (matchCategory && matchSearch) {
                        filteredItems.add({
                          'id': item['id'],
                          'title': name,
                          'group_name': groupName,
                          'subtitle': subtitleText,
                          'qty_text': '${qty.toStringAsFixed(0)} $unit',
                          'is_low': isLow,
                        });
                      }
                    }

                    return Column(
                      children: [
                        // ── Top Header Controls: Branch Selector & Stock Group Category Filter Dropdown ──
                        Container(
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                                            value: _selectedBranchId,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF000080)),
                                            items: branches.map<DropdownMenuItem<String>>((b) {
                                              return DropdownMenuItem<String>(
                                                value: b['id']?.toString(),
                                                child: Text(
                                                  b['name']?.toString() ?? '',
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _selectedBranchId = val);
                                                _loadAllData();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],

                                  // Stock Group Category Filter Dropdown
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: _selectedCategory,
                                          icon: const Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF1D4ED8)),
                                          items: [
                                            DropdownMenuItem<String>(
                                              value: 'ALL',
                                              child: Text(
                                                context.tr('All Stock Groups'),
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.sp,
                                                  color: Color(0xFF1D4ED8),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            ...stockGroups.map<DropdownMenuItem<String>>((grp) {
                                              final grpMap = Map<String, dynamic>.from(grp as Map);
                                              final grpId = grpMap['id']?.toString() ?? '';
                                              final grpName = grpMap['name']?.toString() ?? '';
                                              return DropdownMenuItem<String>(
                                                value: grpId,
                                                child: Text(
                                                  grpName,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.sp,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }),
                                          ],
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
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
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
                            color: const Color(0xFF000080),
                            child: filteredItems.isEmpty
                                ? Center(
                                    child: Text(
                                      context.tr('No inventory items found'),
                                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 14.sp),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: filteredItems.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      final title = item['title'] as String;
                                      final subtitle = item['subtitle'] as String;
                                      final qtyText = item['qty_text'] as String;
                                      final bool isLow = item['is_low'] as bool;

                                      return Card(
                                        color: Colors.white,
                                        elevation: 0,
                                        margin: EdgeInsets.only(bottom: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isLow ? Colors.red.shade300 : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          leading: CircleAvatar(
                                            backgroundColor: isLow ? Colors.red.shade50 : Color(0xFFE0F2FE),
                                            child: Icon(
                                              Icons.inventory_2_outlined,
                                              color: isLow ? Colors.red : Color(0xFF0284C7),
                                              size: 22,
                                            ),
                                          ),
                                          title: Text(
                                            title,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
                                              ),
                                              if (isLow) ...[
                                                SizedBox(height: 4),
                                                Text(
                                                  'LOW STOCK ALERT',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10.sp,
                                                    color: Colors.red.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: Text(
                                            qtyText,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w900,
                                              color: isLow ? Colors.red.shade700 : Color(0xFF000080),
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
    );
  }
}
