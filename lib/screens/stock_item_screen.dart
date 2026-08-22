import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

import 'stock_item_form_screen.dart';

class StockItemScreen extends StatelessWidget {
  const StockItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StockItemBodyView(showAppBar: true);
  }
}

class StockItemBodyView extends StatefulWidget {
  final bool showAppBar;
  const StockItemBodyView({super.key, this.showAppBar = false});

  @override
  State<StockItemBodyView> createState() => _StockItemBodyViewState();
}

class _StockItemBodyViewState extends State<StockItemBodyView> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  final _stocks = ValueNotifier<List<dynamic>>([]);
  final _filteredStocks = ValueNotifier<List<dynamic>>([]);
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
    _isLoading.dispose();
    _errorMessage.dispose();
    _stocks.dispose();
    _filteredStocks.dispose();
    super.dispose();
  }

  Future<void> _fetchStocks() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final res = await ApiService.getStockList(token);
      if (res['success'] == true) {
        _stocks.value = res['stocks'] ?? [];
        _filteredStocks.value = List.from(_stocks.value);
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load stock items';
        _isLoading.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  void _filter() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredStocks.value = List.from(_stocks.value);
    } else {
      _filteredStocks.value = _stocks.value.where((s) {
        final name = (s['item_name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    }
  }

  Future<void> _addNewStockItem() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const StockItemFormScreen(),
      ),
    );
    if (result == true) {
      _fetchStocks();
    }
  }

  Future<void> _editStockItem(Map<String, dynamic> item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockItemFormScreen(item: item),
      ),
    );
    if (result == true) {
      _fetchStocks();
    }
  }

  Future<void> _deleteStockItem(Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Stock Item')),
        content: Text('${context.tr('Are you sure you want to delete')} "${item['item_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _isLoading.value = true;
      try {
        final res = await ApiService.deleteStock(token, item['id']);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Stock item deleted successfully!')), backgroundColor: Colors.green),
          );
          _fetchStocks();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? context.tr('Failed to delete stock item')), backgroundColor: Colors.red),
          );
          _isLoading.value = false;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.showAppBar
          ? AppBar(
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
            )
          : null,
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
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, loading, _) => ValueListenableBuilder<String>(
                valueListenable: _errorMessage,
                builder: (context, errMsg, _) => ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _filteredStocks,
                  builder: (context, filtered, _) => loading
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
                                      onPressed: _fetchStocks,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                                      child: Text(context.tr('Retry')),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filtered.isEmpty
                              ? Center(child: Text(context.tr('No stock items found'), style: GoogleFonts.inter(color: Colors.grey, fontSize: 15)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final item = Map<String, dynamic>.from(filtered[i] as Map);
                                    final name = item['item_name'] ?? '';
                                    final unitDisplay = item['unit_display'] ?? '';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 3))],
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), foregroundColor: Color(0xFF0284C7), child: Icon(Icons.inventory_2_outlined)),
                                        title: Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${context.tr("Unit")}: $unitDisplay', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                                            if (item['expense_head_name'] != null) ...[
                                              const SizedBox(height: 2),
                                              Text('${context.tr("Expense Head")}: ${item['expense_head_name']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                                            ],
                                          ],
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (value) {
                                            if (value == 'edit') _editStockItem(item);
                                            else if (value == 'delete') _deleteStockItem(item);
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit, size: 18, color: Colors.blue), const SizedBox(width: 8), Text(context.tr('Edit'), style: GoogleFonts.inter())])),
                                            PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size: 18, color: Colors.red), const SizedBox(width: 8), Text(context.tr('Delete'), style: GoogleFonts.inter(color: Colors.red))])),
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
