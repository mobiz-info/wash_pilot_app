import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class ExtrasScreen extends StatefulWidget {
  const ExtrasScreen({super.key});

  @override
  State<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends State<ExtrasScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');
  final _extras = ValueNotifier<List<dynamic>>([]);
  final _filteredExtras = ValueNotifier<List<dynamic>>([]);
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExtras();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _extras.dispose();
    _filteredExtras.dispose();
    super.dispose();
  }

  Future<void> _fetchExtras() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final res = await ApiService.getExtrasList(token);
      if (res['success'] == true) {
        _extras.value = res['extras'] ?? [];
        _filteredExtras.value = List.from(_extras.value);
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load extras';
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
      _filteredExtras.value = List.from(_extras.value);
    } else {
      _filteredExtras.value = _extras.value.where((e) {
        final name = (e['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    }
  }

  Future<void> _deleteExtraItem(Map<String, dynamic> item) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('Delete Extra Item'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          '${context.tr('Are you sure you want to delete')} "${item['name']}"?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final res = await ApiService.deleteExtra(token, item['id'].toString());
        if (res['success'] == true) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? context.tr('Extra item deleted successfully')),
              backgroundColor: Colors.green,
            ),
          );
          _fetchExtras();
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? context.tr('Failed to delete extra item')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addNewExtraItem() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedCategoryId;
    List<dynamic> categories = [];
    bool isLoadingCategories = true;

    try {
      final catRes = await ApiService.getServiceCategories(token);
      if (catRes['success'] == true) {
        categories = catRes['categories'] ?? [];
      }
    } catch (_) {}
    isLoadingCategories = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Add Extra Item'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Select Service Category'),
                        labelStyle: GoogleFonts.inter(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(context.tr('None / General'), style: GoogleFonts.inter(color: Colors.grey)),
                        ),
                        ...categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text(c['name'].toString(), style: GoogleFonts.inter()),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCategoryId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Extra Name *'),
                        labelStyle: GoogleFonts.inter(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('Please enter extra name');
                        }
                        return null;
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
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);
                            final defaultErrorMsg = context.tr('Failed to create extra item');
                            try {
                              final res = await ApiService.createExtra(
                                token,
                                nameController.text.trim(),
                                serviceTypeId: selectedCategoryId,
                              );
                              if (res['success'] == true && res['extra'] != null) {
                                nav.pop(Map<String, dynamic>.from(res['extra']));
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? defaultErrorMsg),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                setDialogState(() => isCreating = false);
                              }
                            } catch (e) {
                              messenger.showSnackBar(
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Extra item created successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      _fetchExtras();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Extras'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchExtras,
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
                hintText: context.tr('Search extras...'),
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
                  valueListenable: _filteredExtras,
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
                                      onPressed: _fetchExtras,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                                      child: Text(context.tr('Retry')),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filtered.isEmpty
                              ? Center(child: Text(context.tr('No extras found'), style: GoogleFonts.inter(color: Colors.grey, fontSize: 15)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final item = Map<String, dynamic>.from(filtered[i] as Map);
                                    final name = item['name'] ?? '';
                                    final categoryName = item['service_type_name'] ?? '';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 3))],
                                      ),
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Color(0xFFFCE7F3),
                                          foregroundColor: Color(0xFFEC4899),
                                          child: Icon(Icons.more_horiz_outlined),
                                        ),
                                        title: Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                                        subtitle: categoryName.isNotEmpty
                                            ? Text(categoryName, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600))
                                            : null,
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _deleteExtraItem(item),
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
        onPressed: _addNewExtraItem,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

