import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

/// Full-screen create / edit form for a Lead.
/// Returns `true` to the caller when saved successfully.
class LeadFormScreen extends StatefulWidget {
  /// Pass an existing lead map to edit; null = create mode.
  final Map<String, dynamic>? lead;

  const LeadFormScreen({super.key, this.lead});

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  // ── Loading state ──────────────────────────────────────────────────────────
  bool _isLoadingForm = true;
  bool _isSaving = false;
  String _errorMessage = '';

  // ── Vehicle master data ────────────────────────────────────────────────────
  List<dynamic> _vehicleTypes = [];
  List<dynamic> _vehicleTypeModels = [];
  List<dynamic> _makes = [];
  List<dynamic> _brandModels = [];
  List<dynamic> _colors = [];

  // ── Selected vehicle values ────────────────────────────────────────────────
  Map<String, dynamic>? _selectedVehicleType;
  Map<String, dynamic>? _selectedVehicleTypeModel;
  Map<String, dynamic>? _selectedMake;
  Map<String, dynamic>? _selectedBrandModel;
  Map<String, dynamic>? _selectedColor;
  String _wheelType = 'normal_wheel';

  // ── Text controllers ───────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();

  // ── Phone ──────────────────────────────────────────────────────────────────
  late String _phoneCode;
  late String _phoneIso;
  late String _waCode;
  late String _waIso;
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();

  // ── Date ───────────────────────────────────────────────────────────────────
  DateTime? _renewalDate;

  bool get _isEditing => widget.lead != null;

  @override
  void initState() {
    super.initState();
    _phoneCode = CountryConfig.phoneDialCode;
    _phoneIso = CountryConfig.phoneIsoCode;
    _waCode = CountryConfig.phoneDialCode;
    _waIso = CountryConfig.phoneIsoCode;

    _fetchFormData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _fetchFormData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.getFormData(token);
      if (res['success'] == true) {
        final vTypes = List<dynamic>.from(res['vehicle_types'] ?? []);
        final vTypeModels = List<dynamic>.from(
            res['vehicle_type_models'] ?? res['vehicle_models'] ?? []);
        final makes = List<dynamic>.from(res['makes'] ?? []);
        final brandModels = List<dynamic>.from(res['brand_models'] ?? []);
        final colors = List<dynamic>.from(res['colors'] ?? []);

        final validVtIds = vTypeModels
            .map((m) => m['vehicle_type_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .toSet();
        final filteredTypes = vTypes
            .where((vt) => validVtIds.contains(vt['id']?.toString()))
            .toList();

        setState(() {
          _vehicleTypes =
              filteredTypes.isNotEmpty ? filteredTypes : vTypes;
          _vehicleTypeModels = vTypeModels;
          _makes = makes;
          _brandModels = brandModels;
          _colors = colors;
          _isLoadingForm = false;
        });

        // Populate existing values when editing
        if (_isEditing) {
          _populateFromLead(widget.lead!);
        } else if (_vehicleTypes.isNotEmpty) {
          setState(() => _selectedVehicleType = _vehicleTypes.first as Map<String, dynamic>);
        }
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

  void _populateFromLead(Map<String, dynamic> lead) {
    _nameCtrl.text = lead['customer_name'] ?? '';
    _phoneCtrl.text = lead['phone_number'] ?? '';
    _waCtrl.text = lead['whatsapp_number'] ?? '';
    _vehicleNumberCtrl.text = lead['vehicle_number'] ?? '';
    _wheelType = lead['wheel_type'] ?? 'normal_wheel';

    final rd = lead['renewal_date'];
    if (rd != null && rd.toString().isNotEmpty) {
      try {
        _renewalDate = DateTime.parse(rd.toString());
      } catch (_) {}
    }

    // Match FKs against loaded master data
    final vtId = lead['vehicle_type_id']?.toString() ?? '';
    final vtmId = lead['vehicle_type_model_id']?.toString() ?? '';
    final makeId = lead['vehicle_make_id']?.toString() ?? '';
    final bmId = lead['vehicle_brand_model_id']?.toString() ?? '';
    final colorId = lead['vehicle_color_id']?.toString() ?? '';

    _selectedVehicleType = _vehicleTypes.cast<Map<String, dynamic>>()
        .where((t) => t['id']?.toString() == vtId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    _selectedVehicleTypeModel = _vehicleTypeModels.cast<Map<String, dynamic>>()
        .where((t) => t['id']?.toString() == vtmId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    _selectedMake = _makes.cast<Map<String, dynamic>>()
        .where((t) => t['id']?.toString() == makeId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    _selectedBrandModel = _brandModels.cast<Map<String, dynamic>>()
        .where((t) => t['id']?.toString() == bmId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;
    _selectedColor = _colors.cast<Map<String, dynamic>>()
        .where((t) => t['id']?.toString() == colorId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;

    if (_selectedVehicleType == null && _vehicleTypes.isNotEmpty) {
      _selectedVehicleType = _vehicleTypes.first as Map<String, dynamic>;
    }
  }

  // ── Vehicle filter helpers ─────────────────────────────────────────────────

  List<Map<String, dynamic>> _segmentsForType(String? vtId) {
    if (vtId == null || vtId.isEmpty) return _vehicleTypeModels.cast();
    return _vehicleTypeModels
        .where((m) => m['vehicle_type_id']?.toString() == vtId)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> _makesFor(String? vtId, String? segId) {
    Iterable<dynamic> list = _brandModels;
    if (segId != null && segId.isNotEmpty) {
      list = list.where((b) => b['vehicle_type_model_id']?.toString() == segId);
    } else if (vtId != null && vtId.isNotEmpty) {
      final segIds = _vehicleTypeModels
          .where((s) => s['vehicle_type_id']?.toString() == vtId)
          .map((s) => s['id']?.toString())
          .toSet();
      list = list.where((b) => segIds.contains(b['vehicle_type_model_id']?.toString()));
    } else {
      return _makes.cast();
    }
    final makeIds = list
        .map((b) => b['make_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet();
    return _makes.where((m) => makeIds.contains(m['id']?.toString())).cast<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _brandModelsFor(String? segId, String? makeId) {
    Iterable<dynamic> list = _brandModels;
    if (segId != null && segId.isNotEmpty) {
      list = list.where((b) => b['vehicle_type_model_id']?.toString() == segId);
    }
    if (makeId != null && makeId.isNotEmpty) {
      list = list.where((b) => b['make_id']?.toString() == makeId);
    }
    return list.cast<Map<String, dynamic>>().toList();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final localPhone = _phoneCtrl.text.trim();
    if (name.isEmpty) { _showSnack('Please enter customer name.'); return; }
    if (localPhone.isEmpty) { _showSnack('Please enter phone number.'); return; }

    final phone = CountryConfig.formatPhoneWithCountryCode(localPhone, _phoneCode);
    final localWa = _waCtrl.text.trim();
    final wa = localWa.isNotEmpty
        ? CountryConfig.formatPhoneWithCountryCode(localWa, _waCode)
        : '';

    setState(() => _isSaving = true);
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final data = <String, dynamic>{
        'customer_name': name,
        'phone_number': phone,
        'whatsapp_number': wa,
        'vehicle_number': _vehicleNumberCtrl.text.trim(),
        'vehicle_type_id': _selectedVehicleType?['id']?.toString() ?? '',
        'vehicle_type_model_id': _selectedVehicleTypeModel?['id']?.toString() ?? '',
        'vehicle_make_id': _selectedMake?['id']?.toString() ?? '',
        'vehicle_brand_model_id': _selectedBrandModel?['id']?.toString() ?? '',
        'vehicle_color_id': _selectedColor?['id']?.toString() ?? '',
        'wheel_type': _wheelType,
        'renewal_date': _renewalDate != null
            ? _renewalDate!.toIso8601String().split('T')[0]
            : '',
      };

      Map<String, dynamic> res;
      if (_isEditing) {
        res = await ApiService.editLead(token, widget.lead!['id'].toString(), data);
      } else {
        res = await ApiService.createLead(token, data);
      }

      if (!mounted) return;
      if (res['status'] == 'success') {
        Navigator.pop(context, true);
      } else {
        _showSnack(res['message'] ?? 'Failed to save lead.');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      _showSnack('Error: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewalDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _renewalDate = picked);
  }

  // ── Searchable modal ───────────────────────────────────────────────────────

  void _showSearchModal<T>(
    String title,
    List<T> items,
    String Function(T) labelOf,
    void Function(T?) onSelected,
  ) {
    final searchNotifier = ValueNotifier<String>('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select $title',
                      style: GoogleFonts.inter(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF000080))),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search $title...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => searchNotifier.value = v.toLowerCase().trim(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: searchNotifier,
                  builder: (_, query, __) {
                    final filtered = items
                        .where((item) =>
                            labelOf(item).toLowerCase().contains(query))
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(
                          child: Text('No results found',
                              style: GoogleFonts.inter(color: Colors.grey)));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(labelOf(item),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          _isEditing ? context.tr('Edit Lead') : context.tr('Create Lead'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingForm
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final segments = _segmentsForType(_selectedVehicleType?['id']?.toString());
    final makes = _makesFor(
        _selectedVehicleType?['id']?.toString(),
        _selectedVehicleTypeModel?['id']?.toString());
    final brands = _brandModelsFor(
        _selectedVehicleTypeModel?['id']?.toString(),
        _selectedMake?['id']?.toString());

    final renewalLabel = _renewalDate != null
        ? '${_renewalDate!.day.toString().padLeft(2, '0')}-'
            '${_renewalDate!.month.toString().padLeft(2, '0')}-'
            '${_renewalDate!.year}'
        : context.tr('Select Renewal Date');

    return SingleChildScrollView(
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Customer Info Card ──────────────────────────────────────────
          _card(
            title: context.tr('Customer Info'),
            icon: Icons.person,
            children: [
              _textField(_nameCtrl, context.tr('Customer Name *'),
                  Icons.person_outline),
              SizedBox(height: 14.h),
              _phoneField(
                ctrl: _phoneCtrl,
                label: context.tr('Phone Number *'),
                iso: _phoneIso,
                onCountryChanged: (d, iso) =>
                    setState(() { _phoneCode = d; _phoneIso = iso; }),
              ),
              SizedBox(height: 14.h),
              _phoneField(
                ctrl: _waCtrl,
                label: context.tr('WhatsApp Number (Optional)'),
                iso: _waIso,
                onCountryChanged: (d, iso) =>
                    setState(() { _waCode = d; _waIso = iso; }),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // ── Vehicle Card ────────────────────────────────────────────────
          _card(
            title: context.tr('Vehicle Details'),
            icon: Icons.directions_car,
            children: [
              // 1. Vehicle Type
              _dropdown<Map<String, dynamic>>(
                label: context.tr('Vehicle Type'),
                value: _selectedVehicleType,
                items: _vehicleTypes.cast(),
                labelOf: (t) => t['name']?.toString() ?? '',
                hint: context.tr('Select vehicle type'),
                onChanged: (val) => setState(() {
                  _selectedVehicleType = val;
                  _selectedVehicleTypeModel = null;
                  _selectedMake = null;
                  _selectedBrandModel = null;
                }),
              ),
              SizedBox(height: 12.h),

              // 2. Make (searchable)
              _searchableField<Map<String, dynamic>>(
                label: context.tr('Vehicle Make'),
                title: 'Make',
                value: _selectedMake,
                items: makes,
                labelOf: (m) => m['name']?.toString() ?? '',
                hint: makes.isEmpty
                    ? context.tr('No makes available')
                    : context.tr('Select Make (e.g. Maruti, Hyundai)...'),
                onChanged: makes.isEmpty
                    ? null
                    : (val) => setState(() {
                          _selectedMake = val;
                          _selectedBrandModel = null;
                        }),
              ),
              SizedBox(height: 12.h),

              // 3. Brand / Model (searchable)
              _searchableField<Map<String, dynamic>>(
                label: context.tr('Brand / Model'),
                title: 'Brand Model',
                value: _selectedBrandModel,
                items: brands,
                labelOf: (b) => b['name']?.toString() ?? '',
                hint: brands.isEmpty
                    ? context.tr('No models available')
                    : context.tr('Select Model (e.g. Swift, Creta)...'),
                onChanged: brands.isEmpty
                    ? null
                    : (val) => setState(() {
                          _selectedBrandModel = val;
                          if (val != null) {
                            // Auto-fill Make
                            final makeId = val['make_id']?.toString();
                            if (makeId != null && makeId.isNotEmpty) {
                              _selectedMake = _makes
                                  .cast<Map<String, dynamic>>()
                                  .where((m) => m['id']?.toString() == makeId)
                                  .cast<Map<String, dynamic>?>()
                                  .firstOrNull;
                            }
                            // Auto-fill Segment
                            final vtmId =
                                val['vehicle_type_model_id']?.toString();
                            if (vtmId != null && vtmId.isNotEmpty) {
                              final seg = _vehicleTypeModels
                                  .cast<Map<String, dynamic>>()
                                  .where((s) => s['id']?.toString() == vtmId)
                                  .cast<Map<String, dynamic>?>()
                                  .firstOrNull;
                              if (seg != null) {
                                _selectedVehicleTypeModel = seg;
                                final vtId =
                                    seg['vehicle_type_id']?.toString();
                                if (vtId != null && vtId.isNotEmpty) {
                                  _selectedVehicleType = _vehicleTypes
                                      .cast<Map<String, dynamic>>()
                                      .where((vt) =>
                                          vt['id']?.toString() == vtId)
                                      .cast<Map<String, dynamic>?>()
                                      .firstOrNull;
                                }
                              }
                            }
                          }
                        }),
              ),
              SizedBox(height: 12.h),

              // 4. Segment
              if (segments.isNotEmpty) ...[
                _dropdown<Map<String, dynamic>>(
                  label: context.tr('Segment'),
                  value: _selectedVehicleTypeModel,
                  items: segments,
                  labelOf: (m) => m['name']?.toString() ?? '',
                  hint: context.tr('Select segment'),
                  onChanged: (val) =>
                      setState(() => _selectedVehicleTypeModel = val),
                ),
                SizedBox(height: 12.h),
              ],

              // 5. Color
              if (_colors.isNotEmpty) ...[
                _dropdown<Map<String, dynamic>>(
                  label: context.tr('Color (Optional)'),
                  value: _selectedColor,
                  items: [
                    {'id': '', 'name': 'None'},
                    ..._colors.cast<Map<String, dynamic>>(),
                  ],
                  labelOf: (c) => c['name']?.toString() ?? '',
                  hint: context.tr('Select color'),
                  onChanged: (val) => setState(() =>
                      _selectedColor = (val?['id'] == '') ? null : val),
                ),
                SizedBox(height: 12.h),
              ],

              // 6. Vehicle Number
              _textField(
                _vehicleNumberCtrl,
                context.tr('Vehicle Number'),
                Icons.pin,
                textCapitalization: TextCapitalization.characters,
              ),
              SizedBox(height: 12.h),

              // 7. Wheel Type
              Text(context.tr('Wheel Type'),
                  style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(context.tr('Normal Wheel'),
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, fontWeight: FontWeight.w500)),
                      value: 'normal_wheel',
                      groupValue: _wheelType,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: const Color(0xFF000080),
                      onChanged: (v) =>
                          setState(() => _wheelType = v ?? 'normal_wheel'),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(context.tr('Alloy Wheel'),
                          style: GoogleFonts.inter(
                              fontSize: 12.sp, fontWeight: FontWeight.w500)),
                      value: 'alloy_wheel',
                      groupValue: _wheelType,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: const Color(0xFF000080),
                      onChanged: (v) =>
                          setState(() => _wheelType = v ?? 'normal_wheel'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // ── Renewal Date Card ───────────────────────────────────────────
          _card(
            title: context.tr('Renewal Date'),
            icon: Icons.calendar_today,
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: REdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10.r),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, size: 20.r, color: const Color(0xFF000080)),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          renewalLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: _renewalDate != null
                                ? const Color(0xFF1E293B)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      if (_renewalDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _renewalDate = null),
                          child: Icon(Icons.clear,
                              size: 18.r, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),

          // ── Save Button ─────────────────────────────────────────────────
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      _isEditing
                          ? context.tr('Update Lead')
                          : context.tr('Save Lead'),
                      style: GoogleFonts.inter(
                          fontSize: 15.sp, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // ── Reusable UI helpers ────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: REdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8.r,
              offset: Offset(0, 2.h))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF000080), size: 20.r),
            SizedBox(width: 8.w),
            Text(title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                    color: const Color(0xFF000080))),
          ]),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        SizedBox(height: 6.h),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14.sp),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, size: 20.r, color: Colors.grey.shade500),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide:
                    const BorderSide(color: Color(0xFF000080))),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _phoneField({
    required TextEditingController ctrl,
    required String label,
    required String iso,
    required void Function(String dialCode, String iso) onCountryChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        SizedBox(height: 6.h),
        IntlPhoneField(
          key: ValueKey('${label}_$iso'),
          controller: ctrl,
          initialCountryCode: iso,
          onCountryChanged: (country) =>
              onCountryChanged('+${country.dialCode}', country.code),
          dropdownTextStyle: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
    String? hint,
  }) {
    T? matched;
    if (value != null) {
      for (final item in items) {
        if (item is Map && value is Map && item['id']?.toString() == (value as Map)['id']?.toString()) {
          matched = item;
          break;
        } else if (item == value) {
          matched = item;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        SizedBox(height: 6.h),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              menuMaxHeight: 350,
              value: matched,
              hint: Text(hint ?? 'Select...',
                  style: GoogleFonts.inter(color: Colors.grey.shade500)),
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(labelOf(item),
                            style: GoogleFonts.inter()),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchableField<T>({
    required String label,
    required String title,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?)? onChanged,
    String? hint,
  }) {
    String displayLabel = hint ?? 'Select $title...';
    bool hasValue = false;

    if (value != null && items.isNotEmpty) {
      for (final item in items) {
        bool match = (item is Map && value is Map &&
                item['id']?.toString() == (value as Map)['id']?.toString()) ||
            item == value;
        if (match) {
          displayLabel = labelOf(item);
          hasValue = true;
          break;
        }
      }
    } else if (value != null) {
      displayLabel = labelOf(value);
      hasValue = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        SizedBox(height: 6.h),
        InkWell(
          onTap: (items.isEmpty || onChanged == null)
              ? null
              : () => _showSearchModal<T>(title, items, labelOf, onChanged),
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayLabel,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: hasValue ? Colors.black87 : Colors.grey.shade500,
                      fontWeight:
                          hasValue ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.search, size: 18.r, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
