import 'package:flutter/material.dart';
import '../config/country_config.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? phoneNumber;
  final String? initialCountryIso; // e.g. 'IN', 'AE', 'SA' — null means use CountryConfig
  final String? branchId;

  const AddCustomerScreen({
    super.key,
    this.phoneNumber,
    this.initialCountryIso,
    this.branchId,
  });

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  bool _isLoadingForm = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _customerTypes = [];

  // 4-level vehicle hierarchy
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
  List<dynamic> _branches = [];
  Map<String, dynamic>? _selectedBranch;

  String _selectedPhoneCode = CountryConfig.phoneDialCode;
  String _selectedWhatsappCode = CountryConfig.phoneDialCode;
  String _phoneIso = CountryConfig.phoneIsoCode;
  String _whatsappIso = CountryConfig.phoneIsoCode;

  // Each entry: {controller, vehicle_type, vehicle_type_model, make, brand_model, color}
  final List<Map<String, dynamic>> _vehicleRows = [];

  @override
  void initState() {
    super.initState();
    // Resolve the effective ISO code — prefer explicit param, else use CountryConfig
    final effectiveIso = widget.initialCountryIso ?? CountryConfig.phoneIsoCode;
    if (widget.phoneNumber != null) {
      String rawPhone = widget.phoneNumber!;
      String detectedCode = CountryConfig.phoneDialCode;
      for (final code in ['971', '966', '965', '968', '974', '973', '91']) {
        if (rawPhone.startsWith(code)) {
          detectedCode = '+$code';
          rawPhone = rawPhone.substring(code.length);
          break;
        }
      }
      _phoneController.text = rawPhone;
      _whatsappController.text = rawPhone;
      _selectedPhoneCode = detectedCode;
      _selectedWhatsappCode = detectedCode;
      _phoneIso = effectiveIso;
      _whatsappIso = effectiveIso;
    } else {
      _phoneIso = effectiveIso;
      _whatsappIso = effectiveIso;
    }
    _fetchFormData();
    _addVehicleRow();
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
        final vehicleTypes = res['vehicle_types'] as List<dynamic>? ?? [];
        final vehicleTypeModels = res['vehicle_type_models'] as List<dynamic>? ?? res['vehicle_models'] as List<dynamic>? ?? [];
        final makes = res['makes'] as List<dynamic>? ?? [];
        final brandModels = res['brand_models'] as List<dynamic>? ?? [];
        final colors = res['colors'] as List<dynamic>? ?? [];
        final branches = res['branches'] as List<dynamic>? ?? [];

        setState(() {
          _customerTypes = types;
          _vehicleTypes = vehicleTypes;
          _vehicleTypeModels = vehicleTypeModels;
          _makes = makes;
          _brandModels = brandModels;
          _colors = colors;
          _branches = branches;
          if (types.isNotEmpty) _selectedCustomerType = types.first;
          if (branches.isNotEmpty) {
            if (widget.branchId != null) {
              _selectedBranch = branches.firstWhere(
                (b) => b['id']?.toString() == widget.branchId,
                orElse: () => branches.first,
              );
            } else {
              _selectedBranch = branches.first;
            }
          }

          // Set default vehicle_type for existing rows
          for (final row in _vehicleRows) {
            if (vehicleTypes.isNotEmpty && row['vehicle_type'] == null) {
              row['vehicle_type'] = vehicleTypes.first;
            }
          }

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
        'vehicle_type': _vehicleTypes.isNotEmpty ? _vehicleTypes.first : null,
        'vehicle_type_model': null,
        'make': null,
        'brand_model': null,
        'color': null,
      });
    });
  }

  void _removeVehicleRow(int index) {
    if (_vehicleRows.length <= 1) return;
    ((_vehicleRows[index]['controller']) as TextEditingController).dispose();
    setState(() {
      _vehicleRows.removeAt(index);
    });
  }

  List<dynamic> _segmentsForType(String? vehicleTypeId) {
    if (vehicleTypeId == null) return [];
    return _vehicleTypeModels.where((m) => m['vehicle_type_id'] == vehicleTypeId).toList();
  }

  List<dynamic> _makesForSegment(String? segmentId) {
    if (segmentId == null) return [];
    final brandModelsInSegment = _brandModels.where((b) => b['vehicle_type_model_id'] == segmentId);
    final makeIds = brandModelsInSegment.map((b) => b['make_id']?.toString()).where((id) => id != null && id!.isNotEmpty).toSet();
    return _makes.where((m) => makeIds.contains(m['id'].toString())).toList();
  }

  List<dynamic> _brandModelsForSegmentAndMake(String? segmentId, String? makeId) {
    if (segmentId == null) return [];
    final brandModelsInSegment = _brandModels.where((b) => b['vehicle_type_model_id'] == segmentId);
    if (makeId != null && makeId.isNotEmpty) {
      return brandModelsInSegment.where((b) => b['make_id']?.toString() == makeId).toList();
    }
    return brandModelsInSegment.toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    String localPhone = _phoneController.text.trim();

    if (name.isEmpty) { _showError('Please enter customer name.'); return; }
    if (localPhone.isEmpty) { _showError('Please enter phone number.'); return; }
    if (_selectedCustomerType == null) { _showError('Please select a customer type.'); return; }

    final cleanPhoneCode = _selectedPhoneCode.replaceAll('+', '');
    if (localPhone.startsWith('+')) localPhone = localPhone.replaceFirst('+', '');
    if (localPhone.startsWith(cleanPhoneCode)) localPhone = localPhone.substring(cleanPhoneCode.length);
    final phone = cleanPhoneCode + localPhone;

    String localWhatsapp = _whatsappController.text.trim();
    String whatsappVal = '';
    if (localWhatsapp.isNotEmpty) {
      final cleanWhatsappCode = _selectedWhatsappCode.replaceAll('+', '');
      if (localWhatsapp.startsWith('+')) localWhatsapp = localWhatsapp.replaceFirst('+', '');
      if (localWhatsapp.startsWith(cleanWhatsappCode)) localWhatsapp = localWhatsapp.substring(cleanWhatsappCode.length);
      whatsappVal = cleanWhatsappCode + localWhatsapp;
    }

    // Collect valid vehicles
    final vehicles = <Map<String, dynamic>>[];
    for (final row in _vehicleRows) {
      final num = (row['controller'] as TextEditingController).text.trim();
      final segment = row['vehicle_type_model'] as Map<String, dynamic>?;
      if (num.isEmpty || segment == null) continue;

      final vehicleData = <String, dynamic>{
        'vehicle_number': num,
        'vehicle_model_id': segment['id'],
      };
      final brandModel = row['brand_model'] as Map<String, dynamic>?;
      if (brandModel != null) vehicleData['brand_model_id'] = brandModel['id'];

      final make = row['make'] as Map<String, dynamic>?;
      if (make != null) vehicleData['make_id'] = make['id'];

      final color = row['color'] as Map<String, dynamic>?;
      if (color != null) vehicleData['color_id'] = color['id'];

      vehicles.add(vehicleData);
    }

    if (vehicles.isEmpty) {
      _showError('Please add at least one vehicle with type and segment selected.');
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
        'whatsapp_number': whatsappVal,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'vehicles': vehicles,
        if (_selectedBranch != null) 'branch_id': _selectedBranch!['id'],
      }, token);

      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Customer added successfully!')), backgroundColor: Colors.green),
        );

        if (res['whatsapp_action'] == 'manual') {
          final cust = res['customer'] ?? {};
          final custName = cust['name'] ?? name;
          final branchName = cust['branch_name'] ?? 'our branch';
          final whatsappNum = cust['whatsapp_number'] ?? phone;
          final message = "Dear $custName, Thank you for choosing $branchName.";
          String cleanedPhone = whatsappNum.toString().replaceAll(RegExp(r'\D'), '');
          if (cleanedPhone.length == 10) cleanedPhone = '91$cleanedPhone';
          if (cleanedPhone.isNotEmpty) {
            final whatsappUrl = Uri.parse("https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}");
            try { await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication); } catch (_) {}
          }
        }

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
                          _buildPhoneField(
                            controller: _phoneController,
                            label: 'Phone Number *',
                            countryIso: _phoneIso,
                            selectedCode: _selectedPhoneCode,
                            onCodeChanged: (dialCode, iso) => setState(() { _selectedPhoneCode = dialCode; _phoneIso = iso; }),
                            icon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildPhoneField(
                            controller: _whatsappController,
                            label: 'WhatsApp Number',
                            countryIso: _whatsappIso,
                            selectedCode: _selectedWhatsappCode,
                            onCodeChanged: (dialCode, iso) => setState(() { _selectedWhatsappCode = dialCode; _whatsappIso = iso; }),
                            icon: Icons.chat_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),
                          _buildTextField(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),
                          const SizedBox(height: 14),
                          _buildDropdown<Map<String, dynamic>>(
                            label: 'Customer Type *',
                            value: _selectedCustomerType,
                            items: _customerTypes.cast<Map<String, dynamic>>(),
                            labelBuilder: (ct) => ct['name'],
                            onChanged: (val) => setState(() => _selectedCustomerType = val),
                          ),
                          if (_branches.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _buildDropdown<Map<String, dynamic>>(
                              label: 'Branch *',
                              value: _selectedBranch,
                              items: _branches.cast<Map<String, dynamic>>(),
                              labelBuilder: (b) => b['name'],
                              onChanged: (val) => setState(() => _selectedBranch = val),
                            ),
                          ],
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
                      const SizedBox(height: 32),
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
          onCountryChanged: (country) => onCodeChanged('+${country.dialCode}', country.code),
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

  Widget _buildVehicleRow(int index) {
    final row = _vehicleRows[index];
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
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF000080).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(Icons.directions_car, size: 18, color: const Color(0xFF000080).withOpacity(0.7)),
                const SizedBox(width: 6),
                Text('Vehicle ${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF000080))),
                const Spacer(),
                if (_vehicleRows.length > 1)
                  GestureDetector(
                    onTap: () => _removeVehicleRow(index),
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
              labelBuilder: (vt) => vt['name'],
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
                labelBuilder: (m) => m['name'],
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
                labelBuilder: (b) => b['name'],
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
            // Level 4 — Brand Model (Optional, only show after Make is selected)
            if (selectedSegment != null && selectedMake != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Brand',
                value: selectedBrand,
                items: brands.cast<Map<String, dynamic>>(),
                labelBuilder: (b) => b['name'],
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
                labelBuilder: (c) => c['name'],
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
}
