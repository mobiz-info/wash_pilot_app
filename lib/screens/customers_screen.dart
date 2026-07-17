import 'package:flutter/material.dart';
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
  bool _isLoadingList = true;
  List<dynamic> _allCustomers = [];
  List<dynamic> _newCustomers = [];
  List<dynamic> _inactiveCustomers = [];

  List<dynamic> _filteredAll = [];
  List<dynamic> _filteredNew = [];
  List<dynamic> _filteredInactive = [];

  final _searchController = TextEditingController();
  String _listError = '';

  // ─── Category Selection ──────────────────────────────────────
  String? _selectedCategory; // null = grid, 'all', 'new', 'inactive'

  // ─── Edit form state ─────────────────────────────────────────
  Map<String, dynamic>? _selectedCustomer;
  bool _isLoadingEdit = false;
  bool _isSaving = false;

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
  Map<String, dynamic>? _selectedCustomerType;
  String _selectedPhoneCode = '+91';
  String _selectedWhatsappCode = '+91';
  String _phoneIso = 'IN';
  String _whatsappIso = 'IN';

  // Existing vehicles (editable)
  final List<Map<String, dynamic>> _existingVehicleRows = [];

  // New vehicles to add
  final List<Map<String, dynamic>> _newVehicleRows = [];

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
    setState(() {
      _isLoadingList = true;
      _listError = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.listCustomers(token);
      if (res['success'] == true) {
        if (!mounted) return;
        setState(() {
          _allCustomers = res['customers'] as List<dynamic>;
          _categorizeAndFilter();
          _isLoadingList = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _listError = res['message'] ?? 'Failed to load';
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e.toString();
        _isLoadingList = false;
      });
    }
  }

  void _categorizeAndFilter() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sixtyDaysAgo = now.subtract(const Duration(days: 60));

    final newCust = <dynamic>[];
    final inactiveCust = <dynamic>[];

    for (final c in _allCustomers) {
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

    _newCustomers = newCust;
    _inactiveCustomers = inactiveCust;

    // Apply Search filter
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredAll = _allCustomers;
      _filteredNew = _newCustomers;
      _filteredInactive = _inactiveCustomers;
    } else {
      _filteredAll = _allCustomers.where((c) =>
          (c['name'] as String).toLowerCase().contains(q) ||
          (c['phone'] as String).contains(q)).toList();
      _filteredNew = _newCustomers.where((c) =>
          (c['name'] as String).toLowerCase().contains(q) ||
          (c['phone'] as String).contains(q)).toList();
      _filteredInactive = _inactiveCustomers.where((c) =>
          (c['name'] as String).toLowerCase().contains(q) ||
          (c['phone'] as String).contains(q)).toList();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _categorizeAndFilter();
    });
  }

  // ─── Open edit ───────────────────────────────────────────────

  Future<void> _openEdit(Map<String, dynamic> listItem) async {
    setState(() {
      _isLoadingEdit = true;
      _selectedCustomer = null;
    });
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
        setState(() => _isLoadingEdit = false);
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

      setState(() {
        _selectedCustomer = c;
        _customerTypes = types;
        _vehicleTypes = vehicleTypes;
        _vehicleTypeModels = vehicleTypeModels;
        _makes = makes;
        _brandModels = brandModels;
        _colors = colors;
        _selectedCustomerType = selectedType as Map<String, dynamic>?;
        _selectedPhoneCode = phoneCode;
        _selectedWhatsappCode = whatsappCode;
        _phoneIso = _isoFromDialCode(phoneCode);
        _whatsappIso = _isoFromDialCode(whatsappCode);
        _isLoadingEdit = false;
      });
    } catch (e) {
      _showMsg(e.toString(), isError: true);
      setState(() => _isLoadingEdit = false);
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
    if (_selectedCustomerType == null) {
      _showMsg('Please select a customer type.', isError: true);
      return;
    }

    // Combine country code + local number
    final cleanPhoneCode = _selectedPhoneCode.replaceAll('+', '');
    if (localPhone.startsWith('+')) localPhone = localPhone.replaceFirst('+', '');
    if (localPhone.startsWith(cleanPhoneCode)) localPhone = localPhone.substring(cleanPhoneCode.length);
    final phone = cleanPhoneCode + localPhone;

    String localWhatsapp = _whatsappController.text.trim();
    String whatsappVal = '';
    if (localWhatsapp.isNotEmpty) {
      final cleanWaCode = _selectedWhatsappCode.replaceAll('+', '');
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

    setState(() => _isSaving = true);
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.editCustomer({
        'customer_id': _selectedCustomer!['id'],
        'name': name,
        'phone': phone,
        'customer_type_id': _selectedCustomerType!['id'],
        'whatsapp_number': whatsappVal,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'updated_vehicles': updatedVehicles,
        'new_vehicles': newVehicles,
      }, token);

      setState(() => _isSaving = false);

      if (res['success'] == true) {
        _showMsg('Customer updated successfully!');
        setState(() {
          _selectedCustomer = null;
          _newVehicleRows.clear();
        });
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Update failed', isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
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

    setState(() => _isSaving = true);
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.deleteCustomer(_selectedCustomer!['id'], token);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res['success'] == true) {
        _showMsg(context.tr('Customer deleted successfully!'));
        setState(() {
          _selectedCustomer = null;
          _newVehicleRows.clear();
        });
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Failed to delete customer', isError: true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
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

    setState(() => _isLoadingList = true);
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.deleteCustomer(c['id'], token);
      if (!mounted) return;
      setState(() => _isLoadingList = false);

      if (res['success'] == true) {
        _showMsg(context.tr('Customer deleted successfully!'));
        _fetchCustomers();
      } else {
        _showMsg(res['message'] ?? 'Failed to delete customer', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingList = false);
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
    String getTitle() {
      if (_selectedCustomer != null) {
        return 'Edit Customer';
      }
      switch (_selectedCategory) {
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
        leading: (_selectedCustomer != null || _selectedCategory != null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    if (_selectedCustomer != null) {
                      _selectedCustomer = null;
                      for (final r in _existingVehicleRows) {
                        (r['controller'] as TextEditingController).dispose();
                      }
                      _existingVehicleRows.clear();
                      _newVehicleRows.clear();
                    } else {
                      _selectedCategory = null;
                    }
                  });
                },
              )
            : null,
        actions: [
          if (_selectedCustomer == null)
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
      body: _isLoadingEdit
          ? const Center(child: CircularProgressIndicator())
          : _selectedCustomer != null
              ? _buildEditForm()
              : _selectedCategory == null
                  ? _buildGridDashboard()
                  : _buildCustomerListScreen(),
    );
  }

  // ─── Grid Dashboard ──────────────────────────────────────────

  Widget _buildGridDashboard() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listError.isNotEmpty && _allCustomers.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_listError, style: GoogleFonts.inter(color: Colors.red.shade600)),
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
          // 1. All Customers Card (Full width)
          _buildCategoryCard(
            title: 'All Customers',
            count: _allCustomers.length,
            subtitle: 'Total Customers',
            icon: Icons.people_outline,
            color: const Color(0xFF000080),
            isFullWidth: true,
            onTap: () => setState(() {
              _selectedCategory = 'all';
              _searchController.clear();
            }),
          ),  
          const SizedBox(height: 16),

          // 2. Row containing New and Inactive
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  title: 'New Customers',
                  count: _newCustomers.length,
                  subtitle: 'Registered last 30d',
                  icon: Icons.group_add_outlined,
                  color: const Color(0xFF10B981),
                  isFullWidth: false,
                  onTap: () => setState(() {
                    _selectedCategory = 'new';
                    _searchController.clear();
                  }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoryCard(
                  title: 'Inactive Customers',
                  count: _inactiveCustomers.length,
                  subtitle: '60+ days without jobs',
                  icon: Icons.person_off_outlined,
                  color: const Color(0xFFEF4444),
                  isFullWidth: false,
                  onTap: () => setState(() {
                    _selectedCategory = 'inactive';
                    _searchController.clear();
                  }),
                ),
              ),
            ],
          ),
        ],
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
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    count.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 32,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      Text(
                        count.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
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
    List<dynamic> list;
    if (_selectedCategory == 'new') {
      list = _filteredNew;
    } else if (_selectedCategory == 'inactive') {
      list = _filteredInactive;
    } else {
      list = _filteredAll;
    }

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
              hintText: context.tr('Search by name or phone…'),
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
                  borderSide: BorderSide.none),
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
  }

  Widget _buildEmptyState() {
    String msg = 'No customers found';
    IconData icon = Icons.person_search;
    if (_selectedCategory == 'new') {
      msg = 'No new customers (last 30 days)';
      icon = Icons.group_add_outlined;
    } else if (_selectedCategory == 'inactive') {
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

    if (_selectedCategory == 'new') {
      dateInfo = 'Registered: ${formatDate(c['date_added'])}';
      dateColor = Colors.green.shade700;
    } else if (_selectedCategory == 'inactive') {
      if (c['last_invoice_date'] != null && c['last_invoice_date'].toString().isNotEmpty) {
        dateInfo = 'Last Invoice: ${formatDate(c['last_invoice_date'])}';
      } else {
        dateInfo = 'No invoice - Registered: ${formatDate(c['date_added'])}';
      }
      dateColor = Colors.red.shade700;
    } else {
      if (c['last_invoice_date'] != null && c['last_invoice_date'].toString().isNotEmpty) {
        dateInfo = 'Last Invoice: ${formatDate(c['last_invoice_date'])}';
      } else {
        dateInfo = 'Registered: ${formatDate(c['date_added'])}';
      }
    }

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
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF000080).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (c['name'] as String).isNotEmpty
                      ? (c['name'] as String)[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF000080)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['name'],
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF1E293B))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(c['phone'],
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade600)),
                      const Spacer(),
                      // Text(
                      //   dateInfo,
                      //   style: GoogleFonts.inter(
                      //       fontSize: 11,
                      //       fontWeight: FontWeight.w600,
                      //       color: dateColor),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(c['customer_type'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB))),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(
                        context.tr('${c['vehicle_count']} vehicle${(c['vehicle_count'] as int) != 1 ? "s" : ""}'),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _callCustomer(c['phone']),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
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
                    color: Colors.red.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
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
                  (_selectedCustomer!['name'] as String)[0].toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                )),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedCustomer!['name'],
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(_selectedCustomer!['phone'],
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
              _buildPhoneField(
                controller: _phoneController,
                label: 'Phone Number *',
                countryIso: _phoneIso,
                selectedCode: _selectedPhoneCode,
                onCodeChanged: (dialCode, iso) {
                  setState(() {
                    _selectedPhoneCode = dialCode;
                    _phoneIso = iso;
                  });
                },
              ),
              const SizedBox(height: 14),
              _buildPhoneField(
                controller: _whatsappController,
                label: 'WhatsApp Number',
                countryIso: _whatsappIso,
                selectedCode: _selectedWhatsappCode,
                onCodeChanged: (dialCode, iso) {
                  setState(() {
                    _selectedWhatsappCode = dialCode;
                    _whatsappIso = iso;
                  });
                },
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
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    menuMaxHeight: 350,
                    value: _selectedCustomerType,
                    items: _customerTypes
                        .map((ct) => DropdownMenuItem<Map<String, dynamic>>(
                              value: ct as Map<String, dynamic>,
                              child: Text(ct['name'], style: GoogleFonts.inter()),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCustomerType = val),
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
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade400,
            ),
            child: _isSaving
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
              onPressed: _isSaving ? null : _confirmDeleteCustomer,
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
                      setState(() => _newVehicleRows.removeAt(index));
                    } else {
                      (_existingVehicleRows[index]['controller'] as TextEditingController).dispose();
                      setState(() => _existingVehicleRows.removeAt(index));
                    }
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
                setState(() {
                  row['vehicle_type'] = val;
                  row['vehicle_type_model'] = null;
                  row['make'] = null;
                  row['brand_model'] = null;
                });
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
                  setState(() {
                    row['vehicle_type_model'] = val;
                    row['make'] = null;
                    row['brand_model'] = null;
                  });
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
                  setState(() {
                    row['make'] = val;
                    row['brand_model'] = null;
                  });
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
                  setState(() {
                    row['brand_model'] = val;
                  });
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
                setState(() {
                  row['color'] = val;
                });
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
    setState(() {
      _newVehicleRows.add({
        'controller': TextEditingController(),
        'vehicle_type': _vehicleTypes.isNotEmpty ? _vehicleTypes.first : null,
        'vehicle_type_model': null,
        'make': null,
        'brand_model': null,
        'color': null,
      });
    });
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
