import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'bookings_list_screen.dart';

class BookingCreateScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  final Map<String, dynamic> selectedVehicle;
  final List<dynamic> allVehicles;

  const BookingCreateScreen({
    super.key,
    required this.customer,
    required this.selectedVehicle,
    required this.allVehicles,
  });

  @override
  State<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends State<BookingCreateScreen> {
  static const _primaryColor = Color(0xFF000080);

  // --- State ---
  late Map<String, dynamic> _selectedVehicle;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  Map<String, dynamic>? _selectedService;
  final _notesController = TextEditingController();

  bool _isLoadingServices = false;
  List<Map<String, dynamic>> _services = [];
  bool _isSubmitting = false;
  String? _serviceError;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.selectedVehicle;
    _loadServices();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoadingServices = true;
      _serviceError = null;
    });

    try {
      final customerId = widget.customer['id']?.toString() ?? '';
      final vehicleId = _selectedVehicle['id']?.toString() ?? '';

      if (customerId.isEmpty || vehicleId.isEmpty) {
        setState(() {
          _isLoadingServices = false;
          _serviceError = 'Invalid customer or vehicle';
        });
        return;
      }

      final res = await ApiService.getInvoiceServices(customerId, vehicleId, token);
      if (res['success'] == true) {
        final svcs = (res['services'] as List<dynamic>? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        // Group by service_type to show categories
        setState(() {
          _services = svcs;
          _isLoadingServices = false;
        });
      } else {
        setState(() {
          _isLoadingServices = false;
          _serviceError = res['message'] ?? 'Could not load services';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingServices = false;
        _serviceError = e.toString();
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a service')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await ApiService.createBooking({
        'customer_id': widget.customer['id']?.toString() ?? '',
        'vehicle_id': _selectedVehicle['id']?.toString() ?? '',
        'booking_date': _formatDate(_selectedDate),
        'service_id': _selectedService!['id']?.toString() ?? '',
        'service_name': _selectedService!['name'] ?? '',
        'notes': _notesController.text.trim(),
      }, token);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Booking confirmed for ${_displayDate(_selectedDate)}!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to bookings list
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BookingsListScreen()),
          (route) => route.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${res['message'] ?? 'Booking failed'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Create Booking'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Customer header
          _buildCustomerHeader(),
          // Scrollable form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Vehicle Selector
                _buildSectionLabel(context.tr('Select Vehicle'), Icons.directions_car),
                const SizedBox(height: 10),
                _buildVehicleSelector(),
                const SizedBox(height: 24),

                // Date Picker
                _buildSectionLabel(context.tr('Select Date'), Icons.calendar_today),
                const SizedBox(height: 10),
                _buildDatePicker(),
                const SizedBox(height: 24),

                // Service Selector
                _buildSectionLabel(context.tr('Select Service'), Icons.miscellaneous_services),
                const SizedBox(height: 10),
                _buildServiceSelector(),
                const SizedBox(height: 24),

                // Notes
                _buildSectionLabel(context.tr('Notes (Optional)'), Icons.notes),
                const SizedBox(height: 10),
                _buildNotesField(),
                const SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      color: _primaryColor,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer['name'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.customer['phone'] ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _primaryColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: const Color(0xFF1e293b),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelector() {
    if (widget.allVehicles.length == 1) {
      // Only one vehicle - show as readonly card
      return _vehicleCard(_selectedVehicle, isSelected: true, onTap: null);
    }
    return Column(
      children: widget.allVehicles.map((v) {
        final vehicle = Map<String, dynamic>.from(v as Map);
        final isSelected = vehicle['id']?.toString() == _selectedVehicle['id']?.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _vehicleCard(vehicle, isSelected: isSelected, onTap: () {
            setState(() {
              _selectedVehicle = vehicle;
              _selectedService = null;
              _services = [];
            });
            _loadServices();
          }),
        );
      }).toList(),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> vehicle, {required bool isSelected, required VoidCallback? onTap}) {
    final vehicleNo = vehicle['no']?.toString() ?? vehicle['number']?.toString() ?? '';
    final vehicleType = vehicle['vehicle_type']?.toString() ?? vehicle['type']?.toString() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? _primaryColor.withOpacity(0.08) : Colors.black.withOpacity(0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car,
                color: isSelected ? _primaryColor : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleNo,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: const Color(0xFF1e293b),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (vehicleType.isNotEmpty)
                    Text(
                      vehicleType,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today, color: _primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Booking Date'),
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _displayDate(_selectedDate),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFF1e293b),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSelector() {
    if (_isLoadingServices) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_serviceError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _serviceError!,
                style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _loadServices,
              child: Text(context.tr('Retry'), style: const TextStyle(color: _primaryColor)),
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Text(
              context.tr('No services available for this vehicle'),
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Group by service_type
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final svc in _services) {
      final type = svc['service_type']?.toString() ?? 'Other';
      grouped.putIfAbsent(type, () => []).add(svc);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.key,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((svc) => _serviceCard(svc)),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _serviceCard(Map<String, dynamic> svc) {
    final isSelected = _selectedService?['id']?.toString() == svc['id']?.toString();
    final rate = svc['rate'] != null ? double.tryParse(svc['rate'].toString()) ?? 0.0 : 0.0;

    return GestureDetector(
      onTap: () => setState(() => _selectedService = svc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? _primaryColor.withOpacity(0.08) : Colors.black.withOpacity(0.02),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _serviceIcon(svc['service_type_slug']?.toString() ?? ''),
                color: isSelected ? _primaryColor : Colors.grey.shade500,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                svc['name']?.toString() ?? '',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isSelected ? _primaryColor : const Color(0xFF1e293b),
                ),
              ),
            ),
            if (rate > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${rate.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _serviceIcon(String slug) {
    switch (slug) {
      case 'oil_change': return Icons.oil_barrel_outlined;
      case 'tyre_change': return Icons.tire_repair;
      case 'wheel_alignment': return Icons.settings_outlined;
      case 'car_wash':
      case 'washing': return Icons.local_car_wash;
      case 'detailing': return Icons.auto_fix_high;
      default: return Icons.miscellaneous_services_outlined;
    }
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: context.tr('Add any special instructions...'),
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('Confirm Booking'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
