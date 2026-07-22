import 'package:flutter/material.dart';
import '../config/country_config.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class EditCustomerScreen extends StatefulWidget {
  const EditCustomerScreen({super.key});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  // ─── Customer list state ─────────────────────────────────────
  bool _isLoadingList = true;
  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];
  final _searchController = TextEditingController();
  String _listError = '';

  // ─── Edit form state ─────────────────────────────────────────
  Map<String, dynamic>? _selectedCustomer;
  bool _isLoadingEdit = false;
  bool _isSaving = false;

  List<dynamic> _customerTypes = [];
  List<dynamic> _vehicleTypes = [];
  List<dynamic> _vehicleTypeModels = []; // all segments
  List<dynamic> _makes = [];             // all manufacturers/makes
  List<dynamic> _brandModels = [];       // all brand models
  List<dynamic> _colors = [];

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  Map<String, dynamic>? _selectedCustomerType;
  String _selectedPhoneCode = CountryConfig.phoneDialCode;
  String _selectedWhatsappCode = CountryConfig.phoneDialCode;
  String _phoneIso = CountryConfig.phoneIsoCode;
  String _whatsappIso = CountryConfig.phoneIsoCode;

  // Existing vehicles (editable)
  final List<Map<String, dynamic>> _existingVehicleRows = [];

  // New vehicles to add
  final List<Map<String, dynamic>> _newVehicleRows = [];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_filterCustomers);
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

  // ─── List ────────────────────────────────────────────────────

  Future<void> _fetchCustomers() async {
    setState(() { _isLoadingList = true; _listError = ''; });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.listCustomers(token);
      if (res['success'] == true) {
        setState(() {
          _allCustomers = res['customers'] as List<dynamic>;
          _filteredCustomers = _allCustomers;
          _isLoadingList = false;
        });
      } else {
        setState(() { _listError = res['message'] ?? 'Failed to load'; _isLoadingList = false; });
      }
    } catch (e) {
      setState(() { _listError = e.toString(); _isLoadingList = false; });
    }
  }

  void _filterCustomers() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = q.isEmpty
          ? _allCustomers
          : _allCustomers.where((c) =>
              (c['name'] as String).toLowerCase().contains(q) ||
              (c['phone'] as String).contains(q)).toList();
    });
  }

  // ─── Open edit ───────────────────────────────────────────────

  Future<void> _openEdit(Map<String, dynamic> listItem) async {
    setState(() { _isLoadingEdit = true; _selectedCustomer = null; });
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

      _nameController.text = c['name'] ?? '';
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
    if (name.isEmpty) { _showMsg('Please enter customer name.', isError: true); return; }
    if (localPhone.isEmpty) { _showMsg('Please enter phone number.', isError: true); return; }
    if (_selectedCustomerType == null) { _showMsg('Please select a customer type.', isError: true); return; }

    final cleanPhoneCode = _selectedPhoneCode.replaceAll('+', '');
    if (localPhone.startsWith('+')) {
      localPhone = localPhone.replaceFirst('+', '');
    }
    if (localPhone.startsWith(cleanPhoneCode)) {
      localPhone = localPhone.substring(cleanPhoneCode.length);
    }
    final phone = cleanPhoneCode + localPhone;

    String localWhatsapp = _whatsappController.text.trim();
    String whatsappVal = '';
    if (localWhatsapp.isNotEmpty) {
      final cleanWhatsappCode = _selectedWhatsappCode.replaceAll('+', '');
      if (localWhatsapp.startsWith('+')) {
        localWhatsapp = localWhatsapp.replaceFirst('+', '');
      }
      if (localWhatsapp.startsWith(cleanWhatsappCode)) {
        localWhatsapp = localWhatsapp.substring(cleanWhatsappCode.length);
      }
      whatsappVal = cleanWhatsappCode + localWhatsapp;
    }

    // Collect updated existing vehicles
    final updatedVehicles = <Map<String, dynamic>>[];
    for (final row in _existingVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final segment = row['vehicle_type_model'] as Map<String, dynamic>?;
      final brandModel = row['brand_model'] as Map<String, dynamic>?;
      final make = row['make'] as Map<String, dynamic>?;
      final color = row['color'] as Map<String, dynamic>?;

      if (num.isNotEmpty && segment != null) {
        final vehicleData = <String, dynamic>{
          'id': row['id'],
          'vehicle_number': num,
          'vehicle_model_id': segment['id'],
        };
        if (brandModel != null) vehicleData['brand_model_id'] = brandModel['id'];
        if (make != null) vehicleData['make_id'] = make['id'];
        if (color != null) vehicleData['color_id'] = color['id'];
        updatedVehicles.add(vehicleData);
      }
    }

    // Collect new vehicles
    final newVehicles = <Map<String, dynamic>>[];
    for (final row in _newVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final segment = row['vehicle_type_model'] as Map<String, dynamic>?;
      final brandModel = row['brand_model'] as Map<String, dynamic>?;
      final make = row['make'] as Map<String, dynamic>?;
      final color = row['color'] as Map<String, dynamic>?;

      if (num.isNotEmpty && segment != null) {
        final vehicleData = <String, dynamic>{
          'vehicle_number': num,
          'vehicle_model_id': segment['id'],
        };
        if (brandModel != null) vehicleData['brand_model_id'] = brandModel['id'];
        if (make != null) vehicleData['make_id'] = make['id'];
        if (color != null) vehicleData['color_id'] = color['id'];
        newVehicles.add(vehicleData);
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
        setState(() { _selectedCustomer = null; _newVehicleRows.clear(); });
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          _selectedCustomer == null ? 'Select Customer to Edit' : 'Edit Customer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _selectedCustomer != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedCustomer = null;
                  for (final r in _existingVehicleRows) {
                    (r['controller'] as TextEditingController).dispose();
                  }
                  _existingVehicleRows.clear();
                  _newVehicleRows.clear();
                }),
              )
            : null,
      ),
      body: _isLoadingEdit
          ? const Center(child: CircularProgressIndicator())
          : _selectedCustomer == null
              ? _buildCustomerList()
              : _buildEditForm(),
    );
  }

  // ─── Customer List ───────────────────────────────────────────

  Widget _buildCustomerList() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF000080),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                      onPressed: () { _searchController.clear(); _filterCustomers(); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingList
              ? const Center(child: CircularProgressIndicator())
              : _listError.isNotEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(_listError, style: GoogleFonts.inter(color: Colors.red.shade600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _fetchCustomers, icon: const Icon(Icons.refresh), label: Text(context.tr('Retry'))),
                    ]))
                  : _filteredCustomers.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_search, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(context.tr('No customers found'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _fetchCustomers,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, i) => _buildCustomerTile(_filteredCustomers[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCustomerTile(Map<String, dynamic> c) {
    return GestureDetector(
      onTap: () => _openEdit(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF000080).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (c['name'] as String).isNotEmpty ? (c['name'] as String)[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF000080)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
                const SizedBox(height: 3),
                Text(c['phone'], style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                    child: Text(c['customer_type'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                  ),
                  if ((c['branch_name']?.toString() ?? c['branch']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          c['branch_name']?.toString() ?? c['branch']?.toString() ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF7C3AED))),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(context.tr('${c['vehicle_count']} vehicle${(c['vehicle_count'] as int) != 1 ? "s" : ""}'),
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ]),
            ),
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
              gradient: const LinearGradient(colors: [Color(0xFF000080), Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(
                  (_selectedCustomer!['name'] as String)[0].toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                )),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selectedCustomer!['name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(_selectedCustomer!['phone'], style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
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
                icon: Icons.phone_outlined,
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
                icon: Icons.chat_outlined,
              ),
              const SizedBox(height: 14),
              _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildTextField(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),
              const SizedBox(height: 14),
              Text(context.tr('Customer Type *'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    menuMaxHeight: 350,
                    value: _selectedCustomerType,
                    items: _customerTypes.map((ct) => DropdownMenuItem<Map<String, dynamic>>(
                      value: ct as Map<String, dynamic>,
                      child: Text(ct['name'], style: GoogleFonts.inter()),
                    )).toList(),
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
                Center(child: Text(context.tr('No vehicles registered.'), style: GoogleFonts.inter(color: Colors.grey.shade500))),

              // Existing
              ...List.generate(_existingVehicleRows.length, (i) => _buildVehicleRow(i, isNew: false)),

              // New
              ...List.generate(_newVehicleRows.length, (i) => _buildVehicleRow(i, isNew: true)),
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
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.tr('Save Changes'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
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
                labelBuilder: (b) => b['name']?.toString() ?? '',
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

            // Color (optional)
            if (selectedType != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Color (Optional)',
                value: selectedColor,
                items: [{'id': '', 'name': 'None'}, ..._colors.cast<Map<String, dynamic>>()],
                labelBuilder: (c) => c['name']?.toString() ?? '',
                hint: 'Select color',
                onChanged: (val) {
                  setState(() {
                    row['color'] = (val?['id'] == '') ? null : val;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Vehicle Number
            Text('Vehicle Number *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            TextField(
              controller: row['controller'] as TextEditingController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter Vehicle Number',
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

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF000080), size: 20),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF000080))),
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
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr(label), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        IntlPhoneField(
          key: ValueKey('${label}_$countryIso'),
          controller: controller,
          initialCountryCode: countryIso,
          onCountryChanged: (country) {
            onCodeChanged('+${country.dialCode}', country.code);
          },
          dropdownTextStyle: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          disableLengthCheck: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF000080))),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF000080))),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    ]);
  }
}
