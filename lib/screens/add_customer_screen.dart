import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final _isLoadingForm = ValueNotifier<bool>(true);
  final _isSaving = ValueNotifier<bool>(false);
  final _errorMessage = ValueNotifier<String>('');

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

  final _selectedCustomerType = ValueNotifier<Map<String, dynamic>?>(null);
  List<dynamic> _branches = [];
  final _selectedBranch = ValueNotifier<Map<String, dynamic>?>(null);

  late final ValueNotifier<String> _selectedPhoneCode;
  late final ValueNotifier<String> _selectedWhatsappCode;
  late final ValueNotifier<String> _phoneIso;
  late final ValueNotifier<String> _whatsappIso;

  // Each entry: {controller, vehicle_type, vehicle_type_model, make, brand_model, color}
  final List<Map<String, dynamic>> _vehicleRows = [];
  final _vehicleRowsNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    final effectiveIso = widget.initialCountryIso ?? CountryConfig.phoneIsoCode;
    String initialPhoneCode = CountryConfig.phoneDialCode;
    String initialWhatsappCode = CountryConfig.phoneDialCode;

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
      initialPhoneCode = detectedCode;
      initialWhatsappCode = detectedCode;
    }

    _selectedPhoneCode = ValueNotifier<String>(initialPhoneCode);
    _selectedWhatsappCode = ValueNotifier<String>(initialWhatsappCode);
    _phoneIso = ValueNotifier<String>(effectiveIso);
    _whatsappIso = ValueNotifier<String>(effectiveIso);

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
    _isLoadingForm.dispose();
    _isSaving.dispose();
    _errorMessage.dispose();
    _selectedCustomerType.dispose();
    _selectedBranch.dispose();
    _selectedPhoneCode.dispose();
    _selectedWhatsappCode.dispose();
    _phoneIso.dispose();
    _whatsappIso.dispose();
    _vehicleRowsNotifier.dispose();
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

        _customerTypes = types;
        _vehicleTypes = vehicleTypes;
        _vehicleTypeModels = vehicleTypeModels;
        _makes = makes;
        _brandModels = brandModels;
        _colors = colors;
        _branches = branches;
        if (types.isNotEmpty) _selectedCustomerType.value = types.first;
        if (branches.isNotEmpty) {
          if (widget.branchId != null) {
            _selectedBranch.value = branches.firstWhere(
              (b) => b['id']?.toString() == widget.branchId,
              orElse: () => branches.first,
            );
          } else {
            _selectedBranch.value = branches.first;
          }
        }

        // Set default vehicle_type for existing rows
        for (final row in _vehicleRows) {
          if (vehicleTypes.isNotEmpty && row['vehicle_type'] == null) {
            row['vehicle_type'] = vehicleTypes.first;
          }
        }

        _isLoadingForm.value = false;
        _vehicleRowsNotifier.value++;
      } else {
        _errorMessage.value = res['message'] ?? 'Failed to load form data';
        _isLoadingForm.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoadingForm.value = false;
    }
  }

  void _addVehicleRow() {
    _vehicleRows.add({
      'controller': TextEditingController(),
      'vehicle_type': _vehicleTypes.isNotEmpty ? _vehicleTypes.first : null,
      'vehicle_type_model': null,
      'make': null,
      'brand_model': null,
      'color': null,
    });
    _vehicleRowsNotifier.value++;
  }

  void _removeVehicleRow(int index) {
    if (_vehicleRows.length <= 1) return;
    ((_vehicleRows[index]['controller']) as TextEditingController).dispose();
    _vehicleRows.removeAt(index);
    _vehicleRowsNotifier.value++;
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    String localPhone = _phoneController.text.trim();
    if (name.isEmpty) { _showError('Please enter customer name.'); return; }
    if (localPhone.isEmpty) { _showError('Please enter phone number.'); return; }
    if (_selectedCustomerType.value == null) { _showError('Please select a customer type.'); return; }

    final phone = CountryConfig.formatPhoneWithCountryCode(localPhone, _selectedPhoneCode.value);

    String localWhatsapp = _whatsappController.text.trim();
    String whatsappVal = '';
    if (localWhatsapp.isNotEmpty) {
      whatsappVal = CountryConfig.formatPhoneWithCountryCode(localWhatsapp, _selectedWhatsappCode.value);
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

    _isSaving.value = true;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.addCustomer({
        'name': name,
        'phone': phone,
        if (whatsappVal.isNotEmpty) 'whatsapp_number': whatsappVal,
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'customer_type_id': _selectedCustomerType.value!['id'],
        if (_selectedBranch.value != null) 'branch_id': _selectedBranch.value!['id'],
        'vehicles': vehicles,
      }, token);

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Customer added successfully!')),
            backgroundColor: Colors.green,
          ),
        );
        final createdCustomer = res['customer'] as Map<String, dynamic>?;
        Navigator.pop(context, createdCustomer ?? true);
      } else {
        _showError(res['message'] ?? 'Failed to add customer');
        _isSaving.value = false;
      }
    } catch (e) {
      _showError(e.toString());
      _isSaving.value = false;
    }
  }  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingForm,
      builder: (context, loadingForm, _) => ValueListenableBuilder<String>(
        valueListenable: _errorMessage,
        builder: (context, errorMsg, _) => ValueListenableBuilder<bool>(
          valueListenable: _isSaving,
          builder: (context, saving, _) {
            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: AppBar(
                title: Text(context.tr('Add New Customer'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: loadingForm
                  ? const Center(child: CircularProgressIndicator())
                  : errorMsg.isNotEmpty
                      ? Center(child: Text(errorMsg, style: const TextStyle(color: Colors.red)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCard(
                                title: 'Customer Info',
                                icon: Icons.person,
                                children: [
                                  _buildTextField(_nameController, 'Customer Name *', Icons.person_outline),
                                  const SizedBox(height: 14),
                                  ValueListenableBuilder<String>(
                                    valueListenable: _phoneIso,
                                    builder: (context, phoneIsoVal, _) => _buildPhoneField(
                                      controller: _phoneController,
                                      label: 'Phone Number *',
                                      countryIso: phoneIsoVal,
                                      selectedCode: _selectedPhoneCode.value,
                                      onCodeChanged: (dialCode, iso) {
                                        _selectedPhoneCode.value = dialCode;
                                        _phoneIso.value = iso;
                                      },
                                      icon: Icons.phone,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ValueListenableBuilder<String>(
                                    valueListenable: _whatsappIso,
                                    builder: (context, whatsappIsoVal, _) => _buildPhoneField(
                                      controller: _whatsappController,
                                      label: 'WhatsApp Number (Optional)',
                                      countryIso: whatsappIsoVal,
                                      selectedCode: _selectedWhatsappCode.value,
                                      onCodeChanged: (dialCode, iso) {
                                        _selectedWhatsappCode.value = dialCode;
                                        _whatsappIso.value = iso;
                                      },
                                      icon: Icons.chat,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ValueListenableBuilder<Map<String, dynamic>?>(
                                    valueListenable: _selectedCustomerType,
                                    builder: (context, selectedCustType, _) => _buildDropdown<Map<String, dynamic>>(
                                      label: 'Customer Type *',
                                      value: selectedCustType,
                                      items: _customerTypes.cast<Map<String, dynamic>>(),
                                      labelBuilder: (t) => t['name'],
                                      hint: 'Select customer type',
                                      onChanged: (val) => _selectedCustomerType.value = val,
                                    ),
                                  ),
                                  if (context.watch<AuthProvider>().isCompanyAdmin && _branches.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    ValueListenableBuilder<Map<String, dynamic>?>(
                                      valueListenable: _selectedBranch,
                                      builder: (context, selectedBranchVal, _) => _buildDropdown<Map<String, dynamic>>(
                                        label: 'Branch *',
                                        value: selectedBranchVal,
                                        items: _branches.cast<Map<String, dynamic>>(),
                                        labelBuilder: (b) => b['name'],
                                        hint: 'Select branch',
                                        onChanged: (val) => _selectedBranch.value = val,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _buildTextField(_emailController, 'Email (Optional)', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                                  const SizedBox(height: 14),
                                  _buildTextField(_addressController, 'Address (Optional)', Icons.home_outlined, maxLines: 2),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildCard(
                                title: 'Vehicles',
                                icon: Icons.directions_car,
                                children: [
                                  ValueListenableBuilder<int>(
                                    valueListenable: _vehicleRowsNotifier,
                                    builder: (context, _, __) => Column(
                                      children: [
                                        for (int i = 0; i < _vehicleRows.length; i++)
                                          _buildVehicleRowWidget(i),
                                        OutlinedButton.icon(
                                          onPressed: _addVehicleRow,
                                          icon: const Icon(Icons.add, color: Color(0xFF000080)),
                                          label: Text('Add Another Vehicle', style: GoogleFonts.inter(color: const Color(0xFF000080), fontWeight: FontWeight.w600)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF000080)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000080),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: saving
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('Save Customer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({
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

  Widget _buildVehicleRowWidget(int index) {
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
                labelBuilder: (m) => m['name'],
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
                labelBuilder: (b) => b['name'],
                hint: makes.isEmpty ? 'No makes available' : 'Select make',
                onChanged: makes.isEmpty ? null : (val) {
                  row['make'] = val;
                  row['brand_model'] = null;
                  _vehicleRowsNotifier.value++;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Level 4 — Brand Model (Optional, only show after Make is selected)
            if (selectedSegment != null && selectedMake != null) ...[
              _buildDropdown<Map<String, dynamic>>(
                label: 'Brand',
                value: selectedBrand,
                items: brands.cast<Map<String, dynamic>>(),
                labelBuilder: (b) => b['name'],
                hint: brands.isEmpty ? 'No brands available' : 'Select brand',
                onChanged: brands.isEmpty ? null : (val) {
                  row['brand_model'] = val;
                  _vehicleRowsNotifier.value++;
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
                  row['color'] = (val?['id'] == '') ? null : val;
                  _vehicleRowsNotifier.value++;
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
