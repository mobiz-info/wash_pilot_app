import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';

class BookNowScreen extends StatefulWidget {
  const BookNowScreen({super.key});

  @override
  State<BookNowScreen> createState() => _BookNowScreenState();
}

class _BookNowScreenState extends State<BookNowScreen> {
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  void _search() {
    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) return;
    FocusScope.of(context).unfocus();
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    context.read<CustomerProvider>().searchCustomer(mobile, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Book Now', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number...',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.phone, color: Color(0xFF000080)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.search, color: Color(0xFF000080), size: 26),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(provider.errorMessage, style: GoogleFonts.inter(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                if (provider.customerData == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Search a customer to book a slot', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15)),
                      ],
                    ),
                  );
                }

                final customer = provider.customerData!;
                final vehicles = (customer['vehicles'] as List<dynamic>? ?? []);

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Customer Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF000080).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF000080), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer['name'], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1e293b))),
                                const SizedBox(height: 4),
                                Text(customer['phone'], style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                                Text(customer['type'] ?? '', style: GoogleFonts.inter(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Select a Vehicle to Book',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),

                    // Vehicle Cards
                    ...vehicles.map((v) => _VehicleBookingCard(
                          vehicle: v,
                          customerId: customer['id'],
                        )),

                    if (vehicles.isEmpty)
                      Center(
                        child: Text('No vehicles found for this customer.', style: GoogleFonts.inter(color: Colors.grey)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vehicle Booking Card ───────────────────────────────────────────────────

class _VehicleBookingCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final String customerId;

  const _VehicleBookingCard({required this.vehicle, required this.customerId});

  void _pickDateAndBook(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Select Booking Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF000080),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !context.mounted) return;

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Booking', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow(Icons.directions_car, 'Vehicle', vehicle['no']),
            const SizedBox(height: 8),
            _confirmRow(Icons.calendar_today, 'Date', '${picked.day}/${picked.month}/${picked.year}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Book'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final res = await ApiService.createBooking({
      'customer_id': customerId,
      'vehicle_id': vehicle['id'],
      'booking_date': dateStr,
    }, token);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['success'] == true ? '✅ Booking confirmed for $dateStr!' : '❌ ${res['message']}'),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasScheme = vehicle['scheme_name'] != null;
    final bool isEligible = vehicle['is_eligible'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isEligible ? Colors.green.shade200 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEligible ? Colors.green.shade50 : const Color(0xFF000080).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_car, color: isEligible ? Colors.green : const Color(0xFF000080), size: 26),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle['no'], style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1e293b), letterSpacing: 0.8)),
                Text(vehicle['type'] ?? '', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
                if (hasScheme) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.local_offer_outlined, size: 12, color: Colors.indigo.shade400),
                      const SizedBox(width: 4),
                      Flexible(child: Text(vehicle['scheme_name'], style: GoogleFonts.inter(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w600))),
                      if (isEligible) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text('FREE', style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Book Button
          ElevatedButton(
            onPressed: () => _pickDateAndBook(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEligible ? Colors.green : const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Book Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
