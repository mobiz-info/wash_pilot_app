import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'add_supplier_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  final _suppliers = ValueNotifier<List<dynamic>>([]);
  final _filteredSuppliers = ValueNotifier<List<dynamic>>([]);
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _suppliers.dispose();
    _filteredSuppliers.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final res = await ApiService.getSuppliersList(token);
      if (res['success'] == true) {
        _suppliers.value = res['suppliers'] ?? [];
        _filteredSuppliers.value = List.from(_suppliers.value);
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load suppliers';
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
      _filteredSuppliers.value = List.from(_suppliers.value);
    } else {
      _filteredSuppliers.value = _suppliers.value.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone_no'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
  }

  Future<void> _openSupplierPage({Map<String, dynamic>? supplier}) async {
    final isEditing = supplier != null;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSupplierScreen(supplier: supplier),
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(isEditing ? 'Supplier updated successfully!' : 'Supplier added successfully!')),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchSuppliers();
    }
  }

  Future<void> _deleteSupplier(Map<String, dynamic> supplier) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Supplier')),
        content: Text('${context.tr('Are you sure you want to delete')} "${supplier['name']}"?'),
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
        final res = await ApiService.deleteSupplier(token, supplier['id']);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Supplier deleted successfully!')), backgroundColor: Colors.green),
          );
          _fetchSuppliers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? context.tr('Failed to delete supplier')), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: Text(
          context.tr('Suppliers'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchSuppliers,
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
                hintText: context.tr('Search suppliers...'),
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
                  valueListenable: _filteredSuppliers,
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
                                      onPressed: _fetchSuppliers,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                                      child: Text(context.tr('Retry')),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filtered.isEmpty
                              ? Center(child: Text(context.tr('No suppliers found'), style: GoogleFonts.inter(color: Colors.grey, fontSize: 15)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final supplier = Map<String, dynamic>.from(filtered[i] as Map);
                                    final name = supplier['name'] ?? '';
                                    final phone = supplier['phone_no'] ?? '';
                                    final address = supplier['address'] ?? '';
                                    final gst = supplier['gst_no'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Info row
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const CircleAvatar(
                                                  backgroundColor: Color(0xFFE0E0FF),
                                                  foregroundColor: Color(0xFF000080),
                                                  child: Icon(Icons.business),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '📞 $phone',
                                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                                                      ),
                                                      if (gst.toString().isNotEmpty) ...
                                                      [
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '🧾 ${context.tr("Tax")}: $gst',
                                                          style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                                                        ),
                                                      ],
                                                      if (address.toString().isNotEmpty) ...
                                                      [
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '📍 $address',
                                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.black38),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                      // Supplier type badge
                                                      if (supplier['supplier_type'] != null) ...
                                                      [
                                                        const SizedBox(height: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: supplier['supplier_type'] == 'credit'
                                                                ? Colors.orange.shade50
                                                                : supplier['supplier_type'] == 'bill_to_bill'
                                                                    ? Colors.purple.shade50
                                                                    : Colors.green.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: supplier['supplier_type'] == 'credit'
                                                                  ? Colors.orange.shade200
                                                                  : supplier['supplier_type'] == 'bill_to_bill'
                                                                      ? Colors.purple.shade200
                                                                      : Colors.green.shade200,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            supplier['supplier_type'] == 'credit'
                                                                ? context.tr('Credit')
                                                                : supplier['supplier_type'] == 'bill_to_bill'
                                                                    ? context.tr('Bill to Bill')
                                                                    : context.tr('Cash'),
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: supplier['supplier_type'] == 'credit'
                                                                  ? Colors.orange.shade700
                                                                  : supplier['supplier_type'] == 'bill_to_bill'
                                                                      ? Colors.purple.shade700
                                                                      : Colors.green.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                          // Action buttons row
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextButton.icon(
                                                  onPressed: () => _openSupplierPage(supplier: supplier),
                                                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF000080)),
                                                  label: Text(
                                                    context.tr('Edit'),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF000080),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(width: 1, height: 36, color: const Color(0xFFEEEEEE)),
                                              Expanded(
                                                child: TextButton.icon(
                                                  onPressed: () => _deleteSupplier(supplier),
                                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                                  label: Text(
                                                    context.tr('Delete'),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.red,
                                                    ),
                                                  ),
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
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSupplierPage(),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
