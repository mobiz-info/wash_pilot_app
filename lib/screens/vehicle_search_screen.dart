import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'invoice_create_screen.dart';

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
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _vehicleController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _vehicleController.text.trim();
    if (text.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _fetchSuggestions(text);
      });
    } else if (text.isEmpty) {
      setState(() {
        _result = null;
        _suggestions = [];
        _errorMessage = '';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vehicleController.removeListener(_onSearchChanged);
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isSuggesting = true;
    });

    try {
      final res = await ApiService.searchVehicleList(query, token);
      if (res['success'] == true) {
        setState(() {
          _suggestions = res['vehicles'] as List<dynamic>;
          _errorMessage = '';
          _isSuggesting = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _isSuggesting = false;
        });
      }
    } catch (e) {
      setState(() {
        _suggestions = [];
        _isSuggesting = false;
      });
    }
  }

  /// Called when user taps the search button or submits from keyboard.
  void _searchManual() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    FocusScope.of(context).unfocus();
    final text = _vehicleController.text.trim();
    if (text.isNotEmpty) {
      _search(text);
    }
  }

  Future<void> _search(String vehicleNumber) async {
    final number = vehicleNumber.replaceAll(' ', '');
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _result = null;
      _suggestions = [];
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


  Future<void> _makeCall(String phone) async {
    if (phone.isNotEmpty) {
      final url = Uri.parse('tel:$phone');
      try {
        final success = await launchUrl(url);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Could not launch phone dialer.')), backgroundColor: Colors.red),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Could not launch phone dialer.')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _sendReadyAlert(Map<String, dynamic> customer, Map<String, dynamic> vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: Colors.green),
            const SizedBox(width: 8),
            Text(context.tr('Send Ready Alert'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          context.tr('Send the automated WhatsApp ready alert notification to this customer?'),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(context.tr('Send'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final phone = customer['phone'] ?? '';
      final vehicleNumber = vehicle['number'] ?? '';
      final customerName = customer['name'] ?? 'Customer';

      final res = await ApiService.sendVehicleReadyAlertGeneric(
        phone: phone,
        vehicleNumber: vehicleNumber,
        customerName: customerName,
        token: token,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        if (res['action'] == 'auto') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('✅ WhatsApp Ready Alert sent successfully!')),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Manual WhatsApp chat opening fallback
          final message = "Hello $customerName, your vehicle ($vehicleNumber) is ready for pickup! Thank you for choosing our service.";
          
          String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (cleanedPhone.length == 10) {
            cleanedPhone = '91$cleanedPhone';
          }
          
          if (cleanedPhone.isNotEmpty) {
            final whatsappUrl = Uri.parse(
              "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}"
            );
            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('No phone number available for this customer')),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? context.tr('Failed to send Ready Alert.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Vehicle Search'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                      hintText: context.tr('Enter Vehicle Number (e.g. KL01AB1234)'),
                      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF000080)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _searchManual(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _searchManual,
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
                    : _result != null
                        ? _buildResult()
                        : _suggestions.isNotEmpty
                            ? _buildSuggestionsList()
                            : _buildHint(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _vehicleController.text = suggestion['vehicle_number'] ?? '';
              _searchManual();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Color(0xFF000080),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion['vehicle_number'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF000080),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${suggestion['vehicle_model']} · ${suggestion['customer_name']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            context.tr('Search by vehicle number\nto view owner & visit details'),
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
          Text(context.tr('Check the vehicle number and try again.'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
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
                      Text(context.tr('${vehicle['vehicle_type']} · ${vehicle['model']}'), style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
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
                //   Text(context.tr('Scheme: $schemeName'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.indigo.shade700, fontSize: 14)),
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
                //       Text(context.tr('$totalVisits / $paidVisits visits'), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                //       if (isEligible)
                //         Container(
                //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                //           decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade300)),
                //           child: Row(
                //             children: [
                //               const Icon(Icons.check_circle, color: Colors.green, size: 14),
                //               const SizedBox(width: 4),
                //               Text(context.tr('ELIGIBLE'), style: GoogleFonts.inter(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                //             ],
                //           ),
                //         )
                //       else
                //         Text(context.tr('${paidVisits - totalVisits} more to go'), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                //     ],
                //   ),
                // ],
                // if (schemeName == null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 8.0),
                //     child: Text(context.tr('No active scheme for this vehicle.'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                //   ),
              ],
            ),
          ),
          // New Job primary action button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceCreateScreen(
                    customer: customer,
                    vehicle: {
                      'id': vehicle['id'],
                      'no': vehicle['number'],
                      'type': vehicle['model'],
                      'vehicle_type': vehicle['vehicle_type'],
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
            label: Text(
              context.tr('New Job'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'Ready Alert',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  onTap: () => _sendReadyAlert(customer, vehicle),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  color: Colors.blue,
                  onTap: () => _makeCall(customer['phone'] ?? ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
