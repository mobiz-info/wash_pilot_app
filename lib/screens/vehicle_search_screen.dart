import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final _vehicleController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final number = _vehicleController.text.trim().toUpperCase();
    if (number.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _result = null;
    });

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.searchVehicle(number, token);
      if (res['success'] == true) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Vehicle not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAlertDialog(String type) {
    final isReady = type == 'ready';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isReady ? Icons.check_circle : Icons.star, color: isReady ? Colors.green : Colors.orange),
            const SizedBox(width: 10),
            Text(isReady ? 'Ready Alert' : 'Special Alert', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          isReady
              ? 'Mark this vehicle as "Ready"?\nThis will notify the customer that their vehicle is ready for pickup.'
              : 'Send a "Special Alert" for this vehicle?\nThis will flag the vehicle for special attention.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isReady ? '✅ Ready alert sent!' : '⭐ Special alert sent!'),
                  backgroundColor: isReady ? Colors.green : Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirm', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Vehicle Search', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                    controller: _vehicleController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      hintText: 'Enter Vehicle Number (e.g. KL01AB1234)',
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF000080)),
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.search, color: Color(0xFF000080), size: 26),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildEmptyState()
                    : _result == null
                        ? _buildHint()
                        : _buildResult(),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Search by vehicle number\nto view owner & visit details',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_crash, size: 80, color: Colors.orange.shade200),
          const SizedBox(height: 16),
          Text(_errorMessage, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.orange.shade700, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Check the vehicle number and try again.', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final vehicle = _result!['vehicle'] as Map<String, dynamic>;
    final customer = _result!['customer'] as Map<String, dynamic>;
    final visits = _result!['visits'] as Map<String, dynamic>;

    final int totalVisits = visits['total_visits'] ?? 0;
    final int paidVisits = visits['paid_visits'] ?? 0;
    final int freeVisits = visits['free_visits'] ?? 0;
    final bool isEligible = visits['is_eligible'] ?? false;
    final String? schemeName = visits['scheme_name'];

    // Progress for scheme
    double schemeProgress = 0;
    if (paidVisits > 0) {
      schemeProgress = (totalVisits / paidVisits).clamp(0.0, 1.0);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vehicle Card
          _buildCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000080).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.directions_car, color: Color(0xFF000080), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle['number'], style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: const Color(0xFF000080))),
                      const SizedBox(height: 4),
                      Text('${vehicle['vehicle_type']} · ${vehicle['model']}', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Owner Details Card
          _buildCard(
            label: 'Owner Details',
            icon: Icons.person_outline,
            child: Column(
              children: [
                _infoRow(Icons.badge_outlined, 'Name', customer['name']),
                const Divider(height: 20),
                _infoRow(Icons.phone_outlined, 'Phone', customer['phone']),
                if ((customer['whatsapp'] as String).isNotEmpty) ...[
                  const Divider(height: 20),
                  _infoRow(Icons.chat_outlined, 'WhatsApp', customer['whatsapp']),
                ],
                const Divider(height: 20),
                _infoRow(Icons.category_outlined, 'Customer Type', customer['type']),
                const Divider(height: 20),
                _infoRow(Icons.store_outlined, 'Branch', customer['branch']),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Visit Details Card
          _buildCard(
            label: 'Visit Details',
            icon: Icons.history,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBox('Total Visits', '$totalVisits', Colors.blue),
                    if (paidVisits > 0) _statBox('Paid Visits\n(Scheme)', '$paidVisits', Colors.indigo),
                    if (freeVisits > 0) _statBox('Free Visits\n(Reward)', '$freeVisits', Colors.green),
                  ],
                ),
                // if (schemeName != null) ...[
                //   const SizedBox(height: 20),
                //   Text('Scheme: $schemeName', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.indigo.shade700, fontSize: 14)),
                //   const SizedBox(height: 10),
                //   // Progress Bar
                //   ClipRRect(
                //     borderRadius: BorderRadius.circular(8),
                //     child: LinearProgressIndicator(
                //       value: schemeProgress,
                //       minHeight: 10,
                //       backgroundColor: Colors.grey.shade200,
                //       valueColor: AlwaysStoppedAnimation<Color>(isEligible ? Colors.green : const Color(0xFF000080)),
                //     ),
                //   ),
                //   const SizedBox(height: 8),
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text('$totalVisits / $paidVisits visits', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                //       if (isEligible)
                //         Container(
                //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                //           decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade300)),
                //           child: Row(
                //             children: [
                //               const Icon(Icons.check_circle, color: Colors.green, size: 14),
                //               const SizedBox(width: 4),
                //               Text('ELIGIBLE', style: GoogleFonts.inter(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                //             ],
                //           ),
                //         )
                //       else
                //         Text('${paidVisits - totalVisits} more to go', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                //     ],
                //   ),
                // ],
                // if (schemeName == null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 8.0),
                //     child: Text('No active scheme for this vehicle.', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                //   ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'Ready Alert',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  onTap: () => _showAlertDialog('ready'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  label: 'Special Alert',
                  icon: Icons.star_outline,
                  color: Colors.orange,
                  onTap: () => _showAlertDialog('special'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({Widget? child, String? label, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null && icon != null) ...[
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF000080)),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080))),
              ],
            ),
            const Divider(height: 20),
          ],
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
