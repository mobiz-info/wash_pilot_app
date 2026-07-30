import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  // ─── Customer list state ─────────────────────────────────────
  final _isLoadingList = ValueNotifier<bool>(true);
  final _allCustomers = ValueNotifier<List<dynamic>>([]);
  final _newCustomers = ValueNotifier<List<dynamic>>([]);
  final _inactiveCustomers = ValueNotifier<List<dynamic>>([]);

  final _filteredAll = ValueNotifier<List<dynamic>>([]);
  final _filteredNew = ValueNotifier<List<dynamic>>([]);
  final _filteredInactive = ValueNotifier<List<dynamic>>([]);

  final _searchController = TextEditingController();
  final _listError = ValueNotifier<String>('');

  // ─── Category Selection ──────────────────────────────────────
  final _selectedCategory = ValueNotifier<String?>(null); // null = grid, 'all', 'new', 'inactive'

  // ─── Edit form state ─────────────────────────────────────────
  final _selectedCustomer = ValueNotifier<Map<String, dynamic>?>(null);
  final _isLoadingEdit = ValueNotifier<bool>(false);
  final _isSaving = ValueNotifier<bool>(false);

  List<dynamic> _customerTypes = [];
  List<dynamic> _vehicleTypes = [];
  List<dynamic> _vehicleTypeModels = [];
  List<dynamic> _makes = [];
  List<dynamic> _brandModels = [];
  List<dynamic> _colors = [];

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _selectedCustomerType = ValueNotifier<Map<String, dynamic>?>(null);
  final _selectedPhoneCode = ValueNotifier<String>('+91');
  final _selectedWhatsappCode = ValueNotifier<String>('+91');
  final _phoneIso = ValueNotifier<String>('IN');
  final _whatsappIso = ValueNotifier<String>('IN');

  // Existing vehicles (editable)
  final List<Map<String, dynamic>> _existingVehicleRows = [];

  // New vehicles to add
  final List<Map<String, dynamic>> _newVehicleRows = [];
  final _vehicleRowsNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    for (final row in _existingVehicleRows) {
      (row['controller'] as TextEditingController).dispose();
    }
    for (final row in _newVehicleRows) {
      (row['controller'] as TextEditingController).dispose();
    }
    _isLoadingList.dispose();
    _allCustomers.dispose();
    _newCustomers.dispose();
    _inactiveCustomers.dispose();
    _filteredAll.dispose();
    _filteredNew.dispose();
    _filteredInactive.dispose();
    _listError.dispose();
    _selectedCategory.dispose();
    _selectedCustomer.dispose();
    _isLoadingEdit.dispose();
    _isSaving.dispose();
    _selectedCustomerType.dispose();
    _selectedPhoneCode.dispose();
    _selectedWhatsappCode.dispose();
    _phoneIso.dispose();
    _whatsappIso.dispose();
    _vehicleRowsNotifier.dispose();
    super.dispose();
  }

  // ─── List & Filtering ────────────────────────────────────────

  Future<void> _callCustomer(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final url = Uri.parse('tel:$phone');
      try {
        final success = await launchUrl(url);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Could not launch phone dialer.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Could not launch phone dialer.')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    _isLoadingList.value = true;
    _listError.value = '';
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.listCustomers(token);
      if (res['success'] == true) {
        if (!mounted) return;
        final rawList = List<dynamic>.from(res['customers'] as List);
        
        // Order by created date / ID descending (newest customer first)
        rawList.sort((a, b) {
          DateTime? da, db;
          if (a['date_added'] != null && a['date_added'].toString().isNotEmpty) {
            da = DateTime.tryParse(a['date_added'].toString());
          } else if (a['created_at'] != null && a['created_at'].toString().isNotEmpty) {
            da = DateTime.tryParse(a['created_at'].toString());
          }
          if (b['date_added'] != null && b['date_added'].toString().isNotEmpty) {
            db = DateTime.tryParse(b['date_added'].toString());
          } else if (b['created_at'] != null && b['created_at'].toString().isNotEmpty) {
            db = DateTime.tryParse(b['created_at'].toString());
          }

          if (da != null && db != null) {
            return db.compareTo(da);
          } else if (da != null) {
            return -1;
          } else if (db != null) {
            return 1;
          }

          final idA = int.tryParse(a['id']?.toString() ?? '') ?? 0;
          final idB = int.tryParse(b['id']?.toString() ?? '') ?? 0;
          return idB.compareTo(idA);
        });

        _allCustomers.value = rawList;
        _categorizeAndFilter();
        _isLoadingList.value = false;
      } else {
        if (!mounted) return;
        _listError.value = res['message'] ?? 'Failed to load';
        _isLoadingList.value = false;
      }
    } catch (e) {
      if (!mounted) return;
      _listError.value = e.toString();
      _isLoadingList.value = false;
    }
  }

  void _categorizeAndFilter() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sixtyDaysAgo = now.subtract(const Duration(days: 60));

    final newCust = <dynamic>[];
    final inactiveCust = <dynamic>[];

    for (final c in _allCustomers.value) {
      // 1. Check if New (registered in last 30 days)
      bool isNew = false;
      if (c['date_added'] != null && c['date_added'].toString().isNotEmpty) {
        try {
          final dateAdded = DateTime.parse(c['date_added'].toString());
          isNew = dateAdded.isAfter(thirtyDaysAgo);
        } catch (_) {}
      }
      if (isNew) {
        newCust.add(c);
      }

      // 2. Check if Inactive (no invoice in last 60 days)
      bool isInactive = false;
      if (c['last_invoice_date'] != null && c['last_invoice_date'].toString().isNotEmpty) {
        try {
          final lastInvoice = DateTime.parse(c['last_invoice_date'].toString());
          isInactive = lastInvoice.isBefore(sixtyDaysAgo);
        } catch (_) {}
      } else {
        // No invoice. Check if date_added is older than 60 days
        if (c['date_added'] != null && c['date_added'].toString().isNotEmpty) {
          try {
            final dateAdded = DateTime.parse(c['date_added'].toString());
            isInactive = dateAdded.isBefore(sixtyDaysAgo);
          } catch (_) {}
        }
      }
      if (isInactive) {
        inactiveCust.add(c);
      }
    }

    _newCustomers.value = newCust;
    _inactiveCustomers.value = inactiveCust;

    // Apply Search filter safely
    final q = _searchController.text.trim().toLowerCase();
    bool matchesQuery(dynamic c) {
      if (q.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final whatsapp = (c['whatsapp_number'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();

      if (name.contains(q) || phone.contains(q) || whatsapp.contains(q) || email.contains(q)) {
        return true;
      }

      final vehicles = c['vehicles'] as List<dynamic>? ?? [];
      for (final v in vehicles) {
        final plate = (v['vehicle_number'] ?? '').toString().toLowerCase();
        if (plate.contains(q)) return true;
      }
      return false;
    }

    _filteredAll.value = _allCustomers.value.where(matchesQuery).toList();
    _filteredNew.value = _newCustomers.value.where(matchesQuery).toList();
    _filteredInactive.value = _inactiveCustomers.value.where(matchesQuery).toList();
  }

  void _onSearchChanged() {
    _categorizeAndFilter();
  }

  // ─── Open edit ───────────────────────────────────────────────

  Future<void> _openEdit(Map<String, dynamic> listItem) async {
    _isLoadingEdit.value = true;
    _selectedCustomer.value = null;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final results = await Future.wait([
        ApiService.getCustomer(listItem['id'] as String, token),
        ApiService.getFormData(token),
      ]);

      final customerRes = results[0];
      final formRes = results[1];

      if (customerRes['success'] != true) {
        _showMsg(customerRes['message'] ?? 'Failed to load customer', isError: true);
        _isLoadingEdit.value = false;
        return;
      }

      final types = formRes['customer_types'] as List<dynamic>? ?? [];
      final vehicleTypes = formRes['vehicle_types'] as List<dynamic>? ?? [];
      final vehicleTypeModels = formRes['vehicle_type_models'] as List<dynamic>? ?? formRes['vehicle_models'] as List<dynamic>? ?? [];
      final makes = formRes['makes'] as List<dynamic>? ?? [];
      final brandModels = formRes['brand_models'] as List<dynamic>? ?? [];
      final colors = formRes['colors'] as List<dynamic>? ?? [];

      final c = customerRes['customer'] as Map<String, dynamic>;
      final typeId = c['customer_type_id'] as String?;
      final selectedType = typeId != null
          ? types.firstWhere((t) => t['id'].toString() == typeId,
              orElse: () => types.isNotEmpty ? types.first : null)
          : (types.isNotEmpty ? types.first : null);

      _nameController.text = c['name'] ?? '';

      // Detect & strip country code from phone
      String rawPhone = c['phone'] ?? '';
      String phoneCode = '+91';
      for (final code in ['971', '966', '965', '968', '974', '973', '91']) {
        if (rawPhone.startsWith(code)) {
          phoneCode = '+$code';
          rawPhone = rawPhone.substring(code.length);
          break;
        }
      }
      String rawWhatsapp = c['whatsapp_number'] ?? '';
      String whatsappCode = '+91';
      for (final code in ['971', '966', '965', '968', '974', '973', '91']) {
        if (rawWhatsapp.startsWith(code)) {
          whatsappCode = '+$code';
          rawWhatsapp = rawWhatsapp.substring(code.length);
          break;
        }
      }
      _phoneController.text = rawPhone;
      _whatsappController.text = rawWhatsapp;
      _emailController.text = c['email'] ?? '';
      _addressController.text = c['address'] ?? '';

      // Build existing vehicle rows with controllers
      for (final row in _existingVehicleRows) {
        (row['controller'] as TextEditingController).dispose();
      }
      _existingVehicleRows.clear();
      _newVehicleRows.clear();

      for (final v in c['vehicles'] as List<dynamic>) {
        final segmentId = v['vehicle_model_id']?.toString();
        final brandId = v['brand_model_id']?.toString();
        final makeId = v['make_id']?.toString();
        final colorId = v['color_id']?.toString();

        final matchedSegment = segmentId != null
            ? vehicleTypeModels.firstWhere((m) => m['id'].toString() == segmentId, orElse: () => null)
            : null;

        final matchedType = (matchedSegment != null && matchedSegment['vehicle_type_id'] != null)
            ? vehicleTypes.firstWhere((t) => t['id'].toString() == matchedSegment['vehicle_type_id'].toString(), orElse: () => null)
            : (vehicleTypes.isNotEmpty ? vehicleTypes.first : null);

        final matchedMake = makeId != null
            ? makes.firstWhere((m) => m['id'].toString() == makeId, orElse: () => null)
            : null;

        final matchedBrand = brandId != null
            ? brandModels.firstWhere((b) => b['id'].toString() == brandId, orElse: () => null)
            : null;

        final matchedColor = colorId != null
            ? colors.firstWhere((col) => col['id'].toString() == colorId, orElse: () => null)
            : null;

        _existingVehicleRows.add({
          'id': v['id'],
          'controller': TextEditingController(text: v['vehicle_number'] ?? ''),
          'vehicle_type': matchedType,
          'vehicle_type_model': matchedSegment,
          'make': matchedMake,
          'brand_model': matchedBrand,
          'color': matchedColor,
        });
      }

      _customerTypes = types;
      _vehicleTypes = vehicleTypes;
      _vehicleTypeModels = vehicleTypeModels;
      _makes = makes;
      _brandModels = brandModels;
      _colors = colors;
      _selectedCustomerType.value = selectedType as Map<String, dynamic>?;
      _selectedPhoneCode.value = phoneCode;
      _selectedWhatsappCode.value = whatsappCode;
      _phoneIso.value = _isoFromDialCode(phoneCode);
      _whatsappIso.value = _isoFromDialCode(whatsappCode);
      _selectedCustomer.value = c;
      _isLoadingEdit.value = false;
      _vehicleRowsNotifier.value++;
    } catch (e) {
      _showMsg(e.toString(), isError: true);
      _isLoadingEdit.value = false;
    }
  }

  // ─── Save ────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    String localPhone = _phoneController.text.trim();
    if (name.isEmpty) {
      _showMsg('Please enter customer name.', isError: true);
      return;
    }
    if (localPhone.isEmpty) {
      _showMsg('Please enter phone number.', isError: true);
      return;
    }
    if (_selectedCustomerType.value == null) {
      _showMsg('Please select a customer type.', isError: true);
      return;
    }

    // Combine country code + local number
    final cleanPhoneCode = _selectedPhoneCode.value.replaceAll('+', '');
    if (localPhone.startsWith('+')) localPhone = localPhone.replaceFirst('+', '');
    if (localPhone.startsWith(cleanPhoneCode)) localPhone = localPhone.substring(cleanPhoneCode.length);
    final phone = cleanPhoneCode + localPhone;

    String localWhatsapp = _whatsappController.text.trim();
    String whatsappVal = '';
    if (localWhatsapp.isNotEmpty) {
      final cleanWaCode = _selectedWhatsappCode.value.replaceAll('+', '');
      if (localWhatsapp.startsWith('+')) localWhatsapp = localWhatsapp.replaceFirst('+', '');
      if (localWhatsapp.startsWith(cleanWaCode)) localWhatsapp = localWhatsapp.substring(cleanWaCode.length);
      whatsappVal = cleanWaCode + localWhatsapp;
    }

    // Collect updated existing vehicles
    final updatedVehicles = <Map<String, dynamic>>[];
    for (final row in _existingVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final model = row['vehicle_type_model'];
      final brand = row['brand_model'];
      final make = row['make'];
      final color = row['color'];
      if (num.isNotEmpty) {
        updatedVehicles.add({
          'id': row['id'],
          'vehicle_number': num,
          'vehicle_model_id': model != null ? model['id'] : null,
          'brand_model_id': brand != null ? brand['id'] : null,
          'make_id': make != null ? make['id'] : null,
          'color_id': color != null ? color['id'] : null,
        });
      }
    }

    // Collect new vehicles
    final newVehicles = <Map<String, dynamic>>[];
    for (final row in _newVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final model = row['vehicle_type_model'];
      final brand = row['brand_model'];
      final make = row['make'];
      final color = row['color'];
      if (num.isNotEmpty && model != null) {
        newVehicles.add({
          'vehicle_number': num,
          'vehicle_model_id': model['id'],
          'brand_model_id': brand != null ? brand['id'] : null,
          'make_id': make != null ? make['id'] : null,
          'color_id': color != null ? color['id'] : null,
        });
      }
    }

    _isSaving.value = true;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.editCustomer({
        'customer_id': _selectedCustomer.value!['id'],
        'name': name,
        'phone': phone,
        'customer_type_id': _selectedCustomerType.value!['id'],
        'whatsapp_number': whatsappVal,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'updated_vehicles': updatedVehicles,
        'new_vehicles': newVehicles,
      }, token);

      _isSaving.value = false;

      if (res['success'] == true) {
        _showMsg('Customer updated successfully!');
        _selectedCustomer.value = null;
        _newVehicleRows.clear();
        _vehicleRowsNotifier.value++;
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Update failed', isError: true);
      }
    } catch (e) {
      _isSaving.value = false;
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _confirmDeleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Customer')),
        content: Text(context.tr('Are you sure you want to delete this customer? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete'), style: GoogleFonts.inter(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    _isSaving.value = true;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.deleteCustomer(_selectedCustomer.value!['id'], token);
      if (!mounted) return;
      _isSaving.value = false;

      if (res['success'] == true) {
        _showMsg(context.tr('Customer deleted successfully!'));
        _selectedCustomer.value = null;
        _newVehicleRows.clear();
        _vehicleRowsNotifier.value++;
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Failed to delete customer', isError: true);
      }
    } catch (e) {
      _isSaving.value = false;
      _showMsg(e.toString(), isError: true);
    }
  }

  Future<void> _confirmDeleteCustomerFromList(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Customer')),
        content: Text(context.tr('Are you sure you want to delete ${c['name']}? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete'), style: GoogleFonts.inter(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    _isLoadingList.value = true;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.deleteCustomer(c['id'], token);
      if (!mounted) return;
      _isLoadingList.value = false;

      if (res['success'] == true) {
        _showMsg(context.tr('Customer deleted successfully!'));
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Failed to delete customer', isError: true);
      }
    } catch (e) {
      if (mounted) _isLoadingList.value = false;
      _showMsg(e.toString(), isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _selectedCustomer,
      builder: (context, selectedCust, _) => ValueListenableBuilder<String?>(
        valueListenable: _selectedCategory,
        builder: (context, categoryVal, _) => ValueListenableBuilder<bool>(
          valueListenable: _isLoadingEdit,
          builder: (context, loadingEdit, _) {
            String getTitle() {
              if (selectedCust != null) {
                return 'Edit Customer';
              }
              switch (categoryVal) {
                case 'all':
                  return 'All Customers';
                case 'new':
                  return 'New Customers';
                case 'inactive':
                  return 'Inactive Customers';
                default:
                  return 'Customers';
              }
            }

            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                title: Text(
                  getTitle(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                elevation: 0,
                leading: (selectedCust != null || categoryVal != null)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (selectedCust != null) {
                            _selectedCustomer.value = null;
                            for (final r in _existingVehicleRows) {
                              (r['controller'] as TextEditingController).dispose();
                            }
                            _existingVehicleRows.clear();
                            _newVehicleRows.clear();
                            _vehicleRowsNotifier.value++;
                          } else {
                            _selectedCategory.value = null;
                          }
                        },
                      )
                    : null,
                actions: [
                  if (selectedCust == null)
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1),
                      tooltip: context.tr('Add Customer'),
                      onPressed: () async {
                        final added = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
                        );
                        if (added != null) {
                          _fetchCustomers();
                        }
                      },
                    ),
                ],
              ),
              body: loadingEdit
                  ? const Center(child: CircularProgressIndicator())
                  : selectedCust != null
                      ? _buildEditForm()
                      : categoryVal == null
                          ? _buildGridDashboard()
                          : _buildCustomerListScreen(),
            );
          },
        ),
      ),
    );
  }

  // ─── Grid Dashboard ──────────────────────────────────────────

  Widget _buildGridDashboard() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingList,
      builder: (context, loadingList, _) => ValueListenableBuilder<String>(
        valueListenable: _listError,
        builder: (context, listErr, _) => ValueListenableBuilder<List<dynamic>>(
          valueListenable: _allCustomers,
          builder: (context, allCusts, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _newCustomers,
            builder: (context, newCusts, _) => ValueListenableBuilder<List<dynamic>>(
              valueListenable: _inactiveCustomers,
              builder: (context, inactiveCusts, _) {
                if (loadingList) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (listErr.isNotEmpty && allCusts.isEmpty) {
                  return Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(listErr, style: GoogleFonts.inter(color: Colors.red.shade600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                          onPressed: _fetchCustomers,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr('Retry'))),
                    ],
                  ));
                }

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCategoryCard(
                        title: 'All Customers',
                        count: allCusts.length,
                        subtitle: 'Total Customers',
                        icon: Icons.people_outline,
                        color: const Color(0xFF000080),
                        isFullWidth: true,
                        onTap: () {
                          _selectedCategory.value = 'all';
                          _searchController.clear();
                        },
                      ),  
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCategoryCard(
                              title: 'New Customers',
                              count: newCusts.length,
                              subtitle: 'Registered last 30d',
                              icon: Icons.group_add_outlined,
                              color: const Color(0xFF10B981),
                              isFullWidth: false,
                              onTap: () {
                                _selectedCategory.value = 'new';
                                _searchController.clear();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCategoryCard(
                              title: 'Inactive Customers',
                              count: inactiveCusts.length,
                              subtitle: '60+ days without jobs',
                              icon: Icons.person_off_outlined,
                              color: const Color(0xFFEF4444),
                              isFullWidth: false,
                              onTap: () {
                                _selectedCategory.value = 'inactive';
                                _searchController.clear();
                              },
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
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isFullWidth,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: isFullWidth
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28.r),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: REdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 22.r),
                      ),
                      Text(
                        count.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Customer List Screen ───────────────────────────────────

  Widget _buildCustomerListScreen() {
    return ValueListenableBuilder<String?>(
      valueListenable: _selectedCategory,
      builder: (context, catVal, _) {
        return ValueListenableBuilder<List<dynamic>>(
          valueListenable: catVal == 'new'
              ? _filteredNew
              : catVal == 'inactive'
                  ? _filteredInactive
                  : _filteredAll,
          builder: (context, list, _) {
            return Column(
              children: [
                // Search bar
                Container(
                  color: const Color(0xFF000080),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.tr('Search by name, phone, vehicle...'),
                      hintStyle: GoogleFonts.inter(color: Colors.white60),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchCustomers,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _buildCustomerTile(list[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String msg = 'No customers found';
    IconData icon = Icons.person_search;
    if (_selectedCategory.value == 'new') {
      msg = 'No new customers (last 30 days)';
      icon = Icons.group_add_outlined;
    } else if (_selectedCategory.value == 'inactive') {
      msg = 'No inactive customers (60+ days)';
      icon = Icons.notifications_paused_outlined;
    }
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(msg, style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 14)),
      ],
    ));
  }

  Widget _buildCustomerTile(Map<String, dynamic> c) {
    String dateInfo = '';
    Color dateColor = Colors.grey.shade600;

    // Formatting date helper
    String formatDate(String? isoStr) {
      if (isoStr == null || isoStr.isEmpty) return '-';
      try {
        final dt = DateTime.parse(isoStr);
        return DateFormat('dd-MM-yyyy').format(dt);
      } catch (_) {
        return isoStr;
      }
    }

    if (_selectedCategory.value == 'new') {
      dateInfo = 'Reg: ${formatDate(c['date_added'])}';
      dateColor = Colors.green.shade700;
    } else if (_selectedCategory.value == 'inactive') {
      if (c['last_invoice_date'] != null && c['last_invoice_date'].toString().isNotEmpty) {
        dateInfo = 'Last Inv: ${formatDate(c['last_invoice_date'])}';
      } else {
        dateInfo = 'Reg: ${formatDate(c['date_added'])}';
      }
      dateColor = Colors.red.shade700;
    } else {
      if (c['last_invoice_date'] != null && c['last_invoice_date'].toString().isNotEmpty) {
        dateInfo = 'Last Inv: ${formatDate(c['last_invoice_date'])}';
      } else {
        dateInfo = 'Reg: ${formatDate(c['date_added'])}';
      }
    }

    final nameStr = (c['name'] ?? '').toString();
    final phoneStr = (c['phone'] ?? '').toString();
    final vehicleCount = c['vehicle_count'] as int? ?? (c['vehicles'] as List<dynamic>? ?? []).length;
    final branchName = (c['branch_name']?.toString() ?? c['branch']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _openEdit(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF000080).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  nameStr.isNotEmpty ? nameStr[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF000080),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameStr,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        phoneStr,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                     
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if ((c['customer_type'] ?? '').toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (c['customer_type'] ?? '').toString(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        context.tr('$vehicleCount vehicle${vehicleCount != 1 ? "s" : ""}'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                     
                    ],
                  ),
                  const SizedBox(height: 5),
                 Row(
                  
                  
                  children: [
                     if (branchName.isNotEmpty) ...[
                       
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Branch: $branchName",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                      
                  ],
                 ),
                 const SizedBox(height: 5),
                 if (dateInfo.isNotEmpty)
                        Text(
                          dateInfo,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dateColor,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _callCustomer(c['phone']),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
                ),
                child: const Icon(Icons.phone, size: 18, color: Colors.green),
              ),
            ),
            if (context.read<AuthProvider>().isCompanyAdmin) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDeleteCustomerFromList(c),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ─── Edit Form ───────────────────────────────────────────────

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF000080), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(
                  (_selectedCustomer.value!['name'] as String)[0].toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                )),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedCustomer.value!['name'],
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(_selectedCustomer.value!['phone'],
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Customer Details ──
          _buildCard(
            title: 'Customer Details',
            icon: Icons.person_outline,
            children: [
              _buildTextField(_nameController, 'Full Name *', Icons.badge_outlined),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: _phoneIso,
                builder: (context, phoneIsoVal, _) => ValueListenableBuilder<String>(
                  valueListenable: _selectedPhoneCode,
                  builder: (context, phoneCodeVal, _) => _buildPhoneField(
                    controller: _phoneController,
                    label: 'Phone Number *',
                    countryIso: phoneIsoVal,
                    selectedCode: phoneCodeVal,
                    onCodeChanged: (dialCode, iso) {
                      _selectedPhoneCode.value = dialCode;
                      _phoneIso.value = iso;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: _whatsappIso,
                builder: (context, whatsappIsoVal, _) => ValueListenableBuilder<String>(
                  valueListenable: _selectedWhatsappCode,
                  builder: (context, whatsappCodeVal, _) => _buildPhoneField(
                    controller: _whatsappController,
                    label: 'WhatsApp Number',
                    countryIso: whatsappIsoVal,
                    selectedCode: whatsappCodeVal,
                    onCodeChanged: (dialCode, iso) {
                      _selectedWhatsappCode.value = dialCode;
                      _whatsappIso.value = iso;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildTextField(_emailController, 'Email', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildTextField(_addressController, 'Address', Icons.location_on_outlined,
                  maxLines: 2),
              const SizedBox(height: 14),
              Text(context.tr('Customer Type *'),
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: _selectedCustomerType,
                    builder: (context, custTypeVal, _) => DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      menuMaxHeight: 350,
                      value: custTypeVal,
                      items: _customerTypes
                          .map((ct) => DropdownMenuItem<Map<String, dynamic>>(
                                value: ct as Map<String, dynamic>,
                                child: Text(ct['name'], style: GoogleFonts.inter()),
                              ))
                          .toList(),
                      onChanged: (val) => _selectedCustomerType.value = val,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Existing Vehicles (editable) ──
          _buildCard(
            title: 'Vehicles',
            icon: Icons.directions_car_outlined,
            trailing: TextButton.icon(
              onPressed: _addNewVehicleRow,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('Add New')),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF000080)),
            ),
            children: [
              if (_existingVehicleRows.isEmpty && _newVehicleRows.isEmpty)
                Center(
                    child: Text(context.tr('No vehicles registered.'),
                        style: GoogleFonts.inter(color: Colors.grey.shade500))),

              // Existing
              ...List.generate(
                  _existingVehicleRows.length, (i) => _buildVehicleRow(i, isNew: false)),

              // New
              ...List.generate(
                  _newVehicleRows.length, (i) => _buildVehicleRow(i, isNew: true)),
            ],
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isSaving.value ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade400,
            ),
            child: _isSaving.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.tr('Save Changes'),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (context.read<AuthProvider>().isCompanyAdmin) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSaving.value ? null : _confirmDeleteCustomer,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                context.tr('Delete Customer'),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Vehicle Row (shared for existing & new) ─────────────────

  Widget _buildVehicleRow(int index, {required bool isNew}) {
    final rows = isNew ? _newVehicleRows : _existingVehicleRows;
    final row = rows[index];
    final label = isNew ? 'New Vehicle ${index + 1}' : 'Vehicle ${index + 1}';

    final selectedType = row['vehicle_type'] as Map<String, dynamic>?;
    final selectedSegment = row['vehicle_type_model'] as Map<String, dynamic>?;
    final selectedMake = row['make'] as Map<String, dynamic>?;
    final selectedBrand = row['brand_model'] as Map<String, dynamic>?;
    final selectedColor = row['color'] as Map<String, dynamic>?;

    final segments = _segmentsForType(selectedType?['id']);
    final makes = _makesForSegment(selectedSegment?['id']);
    final brands = _brandModelsForSegmentAndMake(selectedSegment?['id'], selectedMake?['id']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isNew ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNew
                ? Colors.green.shade200
                : const Color(0xFF000080).withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.directions_car, size: 18,
                    color: isNew ? Colors.green.shade700 : const Color(0xFF000080).withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isNew ? Colors.green.shade700 : const Color(0xFF000080))),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    if (isNew) {
                      (_newVehicleRows[index]['controller'] as TextEditingController).dispose();
                      _newVehicleRows.removeAt(index);
                    } else {
                      (_existingVehicleRows[index]['controller'] as TextEditingController).dispose();
                      _existingVehicleRows.removeAt(index);
                    }
                    _vehicleRowsNotifier.value++;
                  },
                  child: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Level 1 — Vehicle Type
            _buildDropdown<Map<String, dynamic>>(
              label: 'Vehicle Type *',
              value: selectedType,
              items: _vehicleTypes.cast<Map<String, dynamic>>(),
              labelBuilder: (vt) => vt['name']?.toString() ?? '',
              hint: 'Select vehicle type',
              onChanged: (val) {
                row['vehicle_type'] = val;
                row['vehicle_type_model'] = null;
                row['make'] = null;
                row['brand_model'] = null;
                _vehicleRowsNotifier.value++;
              },
            ),
            const SizedBox(height: 12),

            // Level 2 — Segment
            if (selectedType != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Segment *',
                value: selectedSegment,
                items: segments.cast<Map<String, dynamic>>(),
                labelBuilder: (m) => m['name']?.toString() ?? '',
                hint: segments.isEmpty ? 'No segments available' : 'Select segment',
                onChanged: segments.isEmpty ? null : (val) {
                  row['vehicle_type_model'] = val;
                  row['make'] = null;
                  row['brand_model'] = null;
                  _vehicleRowsNotifier.value++;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Level 3 — Make (Optional)
            if (selectedSegment != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Vehicle Make',
                value: selectedMake,
                items: makes.cast<Map<String, dynamic>>(),
                labelBuilder: (m) => m['name']?.toString() ?? '',
                hint: makes.isEmpty ? 'No makes available' : 'Select make',
                onChanged: makes.isEmpty ? null : (val) {
                  row['make'] = val;
                  row['brand_model'] = null;
                  _vehicleRowsNotifier.value++;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Level 4 — Brand Model (Optional)
            if (selectedSegment != null && selectedMake != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Brand',
                value: selectedBrand,
                items: brands.cast<Map<String, dynamic>>(),
                labelBuilder: (b) => b['name']?.toString() ?? '',
                hint: brands.isEmpty ? 'No brands available' : 'Select brand',
                onChanged: brands.isEmpty ? null : (val) {
                  row['brand_model'] = val;
                  _vehicleRowsNotifier.value++;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Optional Color
            _buildDropdown<Map<String, dynamic>>(
              label: 'Color',
              value: selectedColor,
              items: _colors.cast<Map<String, dynamic>>(),
              labelBuilder: (c) => c['name']?.toString() ?? '',
              hint: 'Select color',
              onChanged: (val) {
                row['color'] = val;
                _vehicleRowsNotifier.value++;
              },
            ),
            const SizedBox(height: 12),

            // Vehicle Number Input
            Text(context.tr('Vehicle Number *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            TextField(
              controller: row['controller'] as TextEditingController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: context.tr('e.g. KL 01 AB 1234'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFF000080))),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  List<dynamic> _segmentsForType(String? vehicleTypeId) {
    if (vehicleTypeId == null) return [];
    return _vehicleTypeModels.where((m) => m['vehicle_type_id']?.toString() == vehicleTypeId.toString()).toList();
  }

  List<dynamic> _makesForSegment(String? segmentId) {
    if (segmentId == null) return [];
    final brandModelsInSegment = _brandModels.where((b) => b['vehicle_type_model_id']?.toString() == segmentId.toString());
    final makeIds = brandModelsInSegment.map((b) => b['make_id']?.toString()).toSet();
    return _makes.where((m) => makeIds.contains(m['id']?.toString())).toList();
  }

  List<dynamic> _brandModelsForSegmentAndMake(String? segmentId, String? makeId) {
    if (segmentId == null || makeId == null) return [];
    return _brandModels
        .where((b) => b['vehicle_type_model_id']?.toString() == segmentId.toString() && b['make_id']?.toString() == makeId.toString())
        .toList();
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?)? onChanged,
    bool required = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              menuMaxHeight: 350,
              value: value,
              hint: Text(hint ?? 'Select...', style: GoogleFonts.inter(color: Colors.grey.shade500)),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item), style: GoogleFonts.inter()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _addNewVehicleRow() {
    _newVehicleRows.add({
      'controller': TextEditingController(),
      'vehicle_type': _vehicleTypes.isNotEmpty ? _vehicleTypes.first : null,
      'vehicle_type_model': null,
      'make': null,
      'brand_model': null,
      'color': null,
    });
    _vehicleRowsNotifier.value++;
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required List<Widget> children,
      Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF000080), size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF000080))),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
        const Divider(height: 24),
        ...children,
      ]),
    );
  }

  String _isoFromDialCode(String dialCode) {
    switch (dialCode) {
      case '+971': return 'AE';
      case '+966': return 'SA';
      case '+965': return 'KW';
      case '+968': return 'OM';
      case '+974': return 'QA';
      case '+973': return 'BH';
      case '+91':  return 'IN';
      default:     return 'IN';
    }
  }

  Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required String countryIso,
    required String selectedCode,
    required void Function(String dialCode, String iso) onCodeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr(label),
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        IntlPhoneField(
          key: ValueKey('${label}_$countryIso'),
          controller: controller,
          initialCountryCode: countryIso,
          onCountryChanged: (country) {
            onCodeChanged('+${country.dialCode}', country.code);
          },
          dropdownTextStyle:
              GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          disableLengthCheck: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF000080))),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF000080))),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    ]);
  }
}
