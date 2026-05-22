import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  List<dynamic> _vehicleModels = [];
  Map<String, List<dynamic>> _vehicleModelsByType = {};

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  Map<String, dynamic>? _selectedCustomerType;

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
      final models = formRes['vehicle_models'] as List<dynamic>? ?? [];
      final Map<String, List<dynamic>> grouped = {};
      for (final m in models) {
        grouped.putIfAbsent(m['vehicle_type'] as String, () => []).add(m);
      }

      final c = customerRes['customer'] as Map<String, dynamic>;
      final typeId = c['customer_type_id'] as String?;
      final selectedType = typeId != null
          ? types.firstWhere((t) => t['id'].toString() == typeId,
              orElse: () => types.isNotEmpty ? types.first : null)
          : (types.isNotEmpty ? types.first : null);

      _nameController.text = c['name'] ?? '';
      _phoneController.text = c['phone'] ?? '';
      _whatsappController.text = c['whatsapp_number'] ?? '';
      _emailController.text = c['email'] ?? '';
      _addressController.text = c['address'] ?? '';

      // Build existing vehicle rows with controllers
      for (final row in _existingVehicleRows) {
        (row['controller'] as TextEditingController).dispose();
      }
      _existingVehicleRows.clear();
      _newVehicleRows.clear();

      for (final v in c['vehicles'] as List<dynamic>) {
        final modelId = v['vehicle_model_id']?.toString();
        final matchedModel = modelId != null
            ? models.firstWhere((m) => m['id'].toString() == modelId, orElse: () => models.isNotEmpty ? models.first : null)
            : (models.isNotEmpty ? models.first : null);

        _existingVehicleRows.add({
          'id': v['id'],
          'controller': TextEditingController(text: v['vehicle_number'] ?? ''),
          'model': matchedModel,
        });
      }

      setState(() {
        _selectedCustomer = c;
        _customerTypes = types;
        _vehicleModels = models;
        _vehicleModelsByType = grouped;
        _selectedCustomerType = selectedType as Map<String, dynamic>?;
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
    final phone = _phoneController.text.trim();
    if (name.isEmpty) { _showMsg('Please enter customer name.', isError: true); return; }
    if (phone.isEmpty) { _showMsg('Please enter phone number.', isError: true); return; }
    if (_selectedCustomerType == null) { _showMsg('Please select a customer type.', isError: true); return; }

    // Collect updated existing vehicles
    final updatedVehicles = <Map<String, dynamic>>[];
    for (final row in _existingVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final model = row['model'];
      if (num.isNotEmpty) {
        updatedVehicles.add({
          'id': row['id'],
          'vehicle_number': num,
          'vehicle_model_id': model != null ? model['id'] : null,
        });
      }
    }

    // Collect new vehicles
    final newVehicles = <Map<String, dynamic>>[];
    for (final row in _newVehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final model = row['model'];
      if (num.isNotEmpty && model != null) {
        newVehicles.add({'vehicle_number': num, 'vehicle_model_id': model['id']});
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
        'whatsapp_number': _whatsappController.text.trim(),
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
              hintText: 'Search by name or phone…',
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
                      ElevatedButton.icon(onPressed: _fetchCustomers, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    ]))
                  : _filteredCustomers.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_search, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No customers found', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15)),
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
                  const SizedBox(width: 8),
                  Icon(Icons.directions_car, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('${c['vehicle_count']} vehicle${(c['vehicle_count'] as int) != 1 ? "s" : ""}',
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
              _buildTextField(_phoneController, 'Phone Number *', Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _buildTextField(_whatsappController, 'WhatsApp Number', Icons.chat_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _buildTextField(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),
              const SizedBox(height: 14),
              Text('Customer Type *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
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
              label: const Text('Add New'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF000080)),
            ),
            children: [
              if (_existingVehicleRows.isEmpty && _newVehicleRows.isEmpty)
                Center(child: Text('No vehicles registered.', style: GoogleFonts.inter(color: Colors.grey.shade500))),

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
                : Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNew ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNew
                ? Colors.green.shade200
                : const Color(0xFF000080).withOpacity(0.15),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
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
          ]),
          const SizedBox(height: 12),
          Text('Vehicle Model', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                isExpanded: true,
                value: row['model'],
                hint: const Text('Select model...'),
                items: _buildGroupedDropdownItems(),
                onChanged: (val) => setState(() => rows[index]['model'] = val),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Vehicle Number', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          TextField(
            controller: row['controller'] as TextEditingController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. KL 01 AB 1234',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: Color(0xFF000080))),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────

  void _addNewVehicleRow() {
    setState(() {
      _newVehicleRows.add({
        'controller': TextEditingController(),
        'model': _vehicleModels.isNotEmpty ? _vehicleModels.first : null,
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

  List<DropdownMenuItem<Map<String, dynamic>>> _buildGroupedDropdownItems() {
    final items = <DropdownMenuItem<Map<String, dynamic>>>[];
    _vehicleModelsByType.forEach((type, models) {
      items.add(DropdownMenuItem<Map<String, dynamic>>(
        enabled: false,
        value: null,
        child: Text(type.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
      ));
      for (final m in models) {
        items.add(DropdownMenuItem<Map<String, dynamic>>(
          value: m as Map<String, dynamic>,
          child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(m['name'], style: GoogleFonts.inter())),
        ));
      }
    });
    return items;
  }
}
