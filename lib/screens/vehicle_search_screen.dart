import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'invoice_create_screen.dart';
import 'vehicle_service_history_screen.dart';


class VehicleSearchScreen extends StatefulWidget {
  const VehicleSearchScreen({super.key});

  @override
  State<VehicleSearchScreen> createState() => _VehicleSearchScreenState();
}

class _VehicleSearchScreenState extends State<VehicleSearchScreen> {
  final _vehicleController = TextEditingController();
  final _isLoading = ValueNotifier<bool>(false);
  final _errorMessage = ValueNotifier<String>('');
  final _result = ValueNotifier<Map<String, dynamic>?>( null);
  Timer? _debounce;
  final _suggestions = ValueNotifier<List<dynamic>>([]);
  final _isSuggesting = ValueNotifier<bool>(false);

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
      _result.value = null;
      _suggestions.value = [];
      _errorMessage.value = '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _vehicleController.removeListener(_onSearchChanged);
    _vehicleController.dispose();
    _isLoading.dispose();
    _errorMessage.dispose();
    _result.dispose();
    _suggestions.dispose();
    _isSuggesting.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isSuggesting.value = true;

    try {
      final res = await ApiService.searchVehicleList(query, token);
      if (res['success'] == true) {
        _suggestions.value = res['vehicles'] as List<dynamic>;
        _errorMessage.value = '';
        _isSuggesting.value = false;
      } else {
        _suggestions.value = [];
        _isSuggesting.value = false;
      }
    } catch (e) {
      _suggestions.value = [];
      _isSuggesting.value = false;
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
    _isLoading.value = true;
    _errorMessage.value = '';
    _result.value = null;
    _suggestions.value = [];

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.searchVehicle(number, token);
      if (res['success'] == true) {
        _result.value = res;
        _isLoading.value = false;
      } else {
        _errorMessage.value = res['message'] ?? 'Vehicle not found';
        _isLoading.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
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

    _isLoading.value = true;

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
            SnackBar(content: Text(context.tr('✅ WhatsApp Ready Alert sent successfully!')), backgroundColor: Colors.green),
          );
        } else {
          final message = "Hello $customerName, your vehicle ($vehicleNumber) is ready for pickup! Thank you for choosing our service.";
          String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (cleanedPhone.length == 10) cleanedPhone = '91$cleanedPhone';
          if (cleanedPhone.isNotEmpty) {
            final whatsappUrl = Uri.parse("https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}");
            await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('No phone number available for this customer')), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? context.tr('Failed to send Ready Alert.')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) _isLoading.value = false;
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
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, loading, _) => ValueListenableBuilder<String>(
                valueListenable: _errorMessage,
                builder: (context, errMsg, _) => ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: _result,
                  builder: (context, result, _) => ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _suggestions,
                    builder: (context, suggestions, _) => loading
                        ? const Center(child: CircularProgressIndicator())
                        : errMsg.isNotEmpty
                            ? _buildEmptyState(errMsg)
                            : result != null
                                ? _buildResult(result)
                                : suggestions.isNotEmpty
                                    ? _buildSuggestionsList(suggestions)
                                    : _buildHint(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(List<dynamic> suggestions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
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

  Widget _buildEmptyState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_crash, size: 80, color: Colors.orange.shade200),
          const SizedBox(height: 16),
          Text(errorMessage, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.orange.shade700, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(context.tr('Check the vehicle number and try again.'), style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> resultData) {
    final vehicle = resultData['vehicle'] as Map<String, dynamic>;
    final customer = resultData['customer'] as Map<String, dynamic>;
    final visits = resultData['visits'] as Map<String, dynamic>;

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

          // Service Status Card (Badges, Odometer, Alerts)
          _buildServiceStatusCard(vehicle),
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
  Widget _buildServiceStatusCard(Map<String, dynamic> vehicle) {
    final int odo = vehicle['current_odometer_km'] ?? 0;
    final int? nextOil = vehicle['next_oil_change_km'];
    final int? nextTyre = vehicle['next_tyre_change_km'];
    final String? lastOilDate = vehicle['last_oil_change_date'];
    final String? lastTyreDate = vehicle['last_tyre_change_date'];

    bool oilAlert = nextOil != null && odo >= (nextOil - 500);
    bool tyreAlert = nextTyre != null && odo >= (nextTyre - 2000);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.engineering_outlined, size: 18, color: Color(0xFF000080)),
                  const SizedBox(width: 8),
                  Text(context.tr('Service Status'), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VehicleServiceHistoryScreen(
                        vehicleId: vehicle['id'],
                        vehicleNumber: vehicle['number'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 14, color: Color(0xFF000080)),
                label: Text(context.tr('History'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF000080))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080).withOpacity(0.08),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _serviceIndicatorRow(
            Icons.speed,
            'Current Odometer',
            odo > 0 ? '$odo km' : 'Not recorded',
            Colors.grey.shade700,
          ),
          const Divider(height: 20),
          _serviceIndicatorRow(
            Icons.oil_barrel,
            'Oil Change',
            nextOil != null ? 'Next at $nextOil km' : 'Not scheduled',
            oilAlert ? Colors.red : Colors.green,
            subtitle: lastOilDate != null ? 'Last: $lastOilDate' : null,
            badge: oilAlert ? 'DUE / OVERDUE' : null,
          ),
          const Divider(height: 20),
          _serviceIndicatorRow(
            Icons.circle_outlined,
            'Tyre Change',
            nextTyre != null ? 'Next at $nextTyre km' : 'Not scheduled',
            tyreAlert ? Colors.red : Colors.green,
            subtitle: lastTyreDate != null ? 'Last: $lastTyreDate' : null,
            badge: tyreAlert ? 'DUE / OVERDUE' : null,
          ),
        ],
      ),
    );
  }

  Widget _serviceIndicatorRow(
    IconData icon,
    String label,
    String value,
    Color statusColor, {
    String? subtitle,
    String? badge,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: statusColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(label), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(context.tr(value), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.tr(badge),
                        style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(context.tr(subtitle), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

