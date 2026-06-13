import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? phoneNumber;

  const AddCustomerScreen({super.key, this.phoneNumber});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  bool _isLoadingForm = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _customerTypes = [];
  List<dynamic> _vehicleModels = [];

  // Group vehicle models by type for picker
  Map<String, List<dynamic>> _vehicleModelsByType = {};

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  Map<String, dynamic>? _selectedCustomerType;

  // Each entry: {vehicle_number_controller, vehicle_model}
  final List<Map<String, dynamic>> _vehicleRows = [];

  @override
  void initState() {
    super.initState();
    if (widget.phoneNumber != null) {
      _phoneController.text = widget.phoneNumber!;
    }
    _fetchFormData();
    _addVehicleRow(); // Start with one empty vehicle row
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    for (final row in _vehicleRows) {
      (row['controller'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _fetchFormData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.getFormData(token);
      if (res['success'] == true) {
        final types = res['customer_types'] as List<dynamic>;
        final models = res['vehicle_models'] as List<dynamic>;

        // Group models by vehicle_type
        final Map<String, List<dynamic>> grouped = {};
        for (final m in models) {
          final type = m['vehicle_type'] as String;
          grouped.putIfAbsent(type, () => []).add(m);
        }

        setState(() {
          _customerTypes = types;
          _vehicleModels = models;
          _vehicleModelsByType = grouped;
          if (types.isNotEmpty) _selectedCustomerType = types.first;
          _isLoadingForm = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load form data';
          _isLoadingForm = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingForm = false;
      });
    }
  }

  void _addVehicleRow() {
    setState(() {
      _vehicleRows.add({
        'controller': TextEditingController(),
        'model': _vehicleModels.isNotEmpty ? _vehicleModels.first : null,
      });
    });
  }

  void _removeVehicleRow(int index) {
    if (_vehicleRows.length <= 1) return; // Must keep at least one
    ((_vehicleRows[index]['controller']) as TextEditingController).dispose();
    setState(() {
      _vehicleRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter customer name.');
      return;
    }
    if (phone.isEmpty) {
      _showError('Please enter phone number.');
      return;
    }
    if (_selectedCustomerType == null) {
      _showError('Please select a customer type.');
      return;
    }

    // Collect valid vehicles
    final vehicles = <Map<String, dynamic>>[];
    for (final row in _vehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final model = row['model'];
      if (num.isNotEmpty && model != null) {
        vehicles.add({'vehicle_number': num, 'vehicle_model_id': model['id']});
      }
    }

    if (vehicles.isEmpty) {
      _showError('Please add at least one vehicle with a number.');
      return;
    }

    setState(() => _isSaving = true);

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.addCustomer({
        'name': name,
        'phone': phone,
        'customer_type_id': _selectedCustomerType!['id'],
        'whatsapp_number': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'vehicles': vehicles,
      }, token);

      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Customer added successfully!')), backgroundColor: Colors.green),
        );
        // Return the customer data to NewJobScreen
        Navigator.pop(context, res['customer']);
      } else {
        _showError(res['message'] ?? 'Failed to add customer');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      _showError(e.toString());
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Add New Customer'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingForm
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _customerTypes.isEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection(
                        title: 'Customer Details',
                        icon: Icons.person_outline,
                        children: [
                          _buildTextField(_nameController, 'Full Name *', Icons.badge_outlined),
                          const SizedBox(height: 14),
                          // Phone (read-only if pre-filled, otherwise editable)
                          (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty)
                              ? _buildReadOnlyField('Phone Number *', widget.phoneNumber!, Icons.phone_outlined)
                              : _buildTextField(_phoneController, 'Phone Number *', Icons.phone_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _buildTextField(_whatsappController, 'WhatsApp Number', Icons.chat_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 14),
                          _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _buildTextField(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 14),
                          // Customer Type Dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('Customer Type *'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Map<String, dynamic>>(
                                    isExpanded: true,
                                    menuMaxHeight: 350,
                                    value: _selectedCustomerType,
                                    items: _customerTypes.map((ct) {
                                      return DropdownMenuItem<Map<String, dynamic>>(
                                        value: ct,
                                        child: Text(ct['name'], style: GoogleFonts.inter()),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedCustomerType = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Vehicles',
                        icon: Icons.directions_car_outlined,
                        trailing: TextButton.icon(
                          onPressed: _addVehicleRow,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.tr('Add Vehicle')),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF000080)),
                        ),
                        children: [
                          ...List.generate(_vehicleRows.length, (i) => _buildVehicleRow(i)),
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
                            : Text(context.tr('Save Customer'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF000080), size: 20),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF000080))),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Text(value, style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleRow(int index) {
    final row = _vehicleRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF000080).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car, size: 18, color: const Color(0xFF000080).withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(context.tr('Vehicle ${index + 1}'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF000080))),
                const Spacer(),
                if (_vehicleRows.length > 1)
                  GestureDetector(
                    onTap: () => _removeVehicleRow(index),
                    child: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 22),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Vehicle Model Dropdown (groups by type)
            Text(context.tr('Vehicle Model *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  isExpanded: true,
                  menuMaxHeight: 350,
                  value: row['model'],
                  hint: Text(context.tr('Select model...')),
                  items: _buildGroupedDropdownItems(),
                  onChanged: (val) => setState(() => _vehicleRows[index]['model'] = val),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Vehicle Number
            Text(context.tr('Vehicle Number *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            TextField(
              controller: row['controller'] as TextEditingController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: context.tr('e.g. KL 01 AB 1234'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF000080))),
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

  List<DropdownMenuItem<Map<String, dynamic>>> _buildGroupedDropdownItems() {
    final items = <DropdownMenuItem<Map<String, dynamic>>>[];
    _vehicleModelsByType.forEach((type, models) {
      // Header item (disabled)
      items.add(DropdownMenuItem<Map<String, dynamic>>(
        enabled: false,
        value: null,
        child: Text(type.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
      ));
      for (final m in models) {
        items.add(DropdownMenuItem<Map<String, dynamic>>(
          value: m,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(m['name'], style: GoogleFonts.inter()),
          ),
        ));
      }
    });
    return items;
  }
}
