import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

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

  Future<void> _showSupplierFormDialog({Map<String, dynamic>? supplier}) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final nameController = TextEditingController(text: supplier?['name']);
    final addressController = TextEditingController(text: supplier?['address']);
    final gstController = TextEditingController(text: supplier?['gst_no']);
    final phoneController = TextEditingController(text: supplier?['phone_no']);
    final formKey = GlobalKey<FormState>();
    final isEditing = supplier != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr(isEditing ? 'Edit Supplier' : 'Add Supplier'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: context.tr('Supplier Name *'),
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('Please enter a name');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: context.tr('Phone Number *'),
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('Please enter a phone number');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: gstController,
                        decoration: InputDecoration(
                          labelText: context.tr('GST No. (Optional)'),
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: context.tr('Address *'),
                          labelStyle: GoogleFonts.inter(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('Please enter address');
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
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
                              final payload = {
                                if (isEditing) 'id': supplier['id'],
                                'name': nameController.text.trim(),
                                'phone_no': phoneController.text.trim(),
                                'gst_no': gstController.text.trim(),
                                'address': addressController.text.trim(),
                                'is_active': supplier?['is_active'] ?? true,
                              };
                              final res = await ApiService.createSupplier(token, payload);
                              if (res['success'] == true) {
                                Navigator.pop(context, true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? context.tr('Failed to save supplier')),
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
                      : Text(context.tr('Save')),
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
          content: Text(context.tr(isEditing ? 'Supplier updated successfully!' : 'Supplier created successfully!')),
          backgroundColor: Colors.green,
        ),
      );
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
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFE0E0FF),
                                          foregroundColor: Color(0xFF000080),
                                          child: Icon(Icons.business),
                                        ),
                                        title: Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${context.tr("Phone")}: $phone', style: GoogleFonts.inter(fontSize: 13, color: Colors.black54)),
                                              if (gst.toString().isNotEmpty)
                                                Text('${context.tr("GST")}: $gst', style: GoogleFonts.inter(fontSize: 13, color: Colors.black54)),
                                              Text('${context.tr("Address")}: $address', style: GoogleFonts.inter(fontSize: 13, color: Colors.black38), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showSupplierFormDialog(supplier: supplier);
                                            } else if (value == 'delete') {
                                              _deleteSupplier(supplier);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                  const SizedBox(width: 8),
                                                  Text(context.tr('Edit'), style: GoogleFonts.inter()),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.delete, size: 18, color: Colors.red),
                                                  const SizedBox(width: 8),
                                                  Text(context.tr('Delete'), style: GoogleFonts.inter(color: Colors.red)),
                                                ],
                                              ),
                                            ),
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
        onPressed: () => _showSupplierFormDialog(),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
