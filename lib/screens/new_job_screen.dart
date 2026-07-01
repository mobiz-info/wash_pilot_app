import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'invoice_create_screen.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _mobileController = TextEditingController();
  String _selectedCountryCode = '+91';
  String _selectedCountryIso = 'IN';
  Timer? _debounce;
  List<dynamic> _customerSuggestions = [];
  bool _isSearchingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_onMobileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().clearData();
    });
  }

  void _onMobileChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();
    if (text.length >= 3) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _fetchCustomerSuggestions(text);
      });
    } else {
      setState(() {
        _customerSuggestions = [];
      });
      if (text.isEmpty) {
        context.read<CustomerProvider>().clearData();
      }
    }
  }

  Future<void> _fetchCustomerSuggestions(String query) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isSearchingSuggestions = true;
    });

    try {
      final res = await ApiService.searchCustomerList(query, token);
      if (res['success'] == true) {
        setState(() {
          _customerSuggestions = res['customers'] as List<dynamic>;
          _isSearchingSuggestions = false;
        });
      } else {
        setState(() {
          _customerSuggestions = [];
          _isSearchingSuggestions = false;
        });
      }
    } catch (e) {
      setState(() {
        _customerSuggestions = [];
        _isSearchingSuggestions = false;
      });
    }
  }

  void _selectCustomerFromSuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      _customerSuggestions = [];
    });
    String rawPhone = suggestion['phone'] ?? '';
    String phoneCode = '+91';
    String countryIso = 'IN';
    for (final code in ['971', '966', '965', '968', '974', '973', '91']) {
      if (rawPhone.startsWith(code)) {
        phoneCode = '+$code';
        rawPhone = rawPhone.substring(code.length);
        countryIso = _isoFromDialCode(phoneCode);
        break;
      }
    }
    setState(() {
      _selectedCountryCode = phoneCode;
      _selectedCountryIso = countryIso;
      _mobileController.text = rawPhone;
    });

    _searchCustomer(unfocus: true);
  }

  String _isoFromDialCode(String dialCode) {
    switch (dialCode) {
      case '+971': return 'AE';
      case '+966': return 'SA';
      case '+965': return 'KW';
      case '+968': return 'OM';
      case '+974': return 'QA';
      case '+973': return 'BH';
      case '+91':  return 'IN';
      default:     return 'IN';
    }
  }

  void _searchCustomer({bool unfocus = true}) {
    if (unfocus) {
      FocusScope.of(context).unfocus();
    }
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      final rawMobile = _mobileController.text.trim();
      if (rawMobile.isNotEmpty) {
        final cleanCode = _selectedCountryCode.replaceAll('+', '');
        final formattedMobile = rawMobile.startsWith(cleanCode) ? rawMobile : '$cleanCode$rawMobile';
        context.read<CustomerProvider>().searchCustomer(formattedMobile, token);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mobileController.removeListener(_onMobileChanged);
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('New Job'), style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Section
            Row(
              children: [
                Expanded(
                  child: IntlPhoneField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    initialCountryCode: 'IN',
                    dropdownTextStyle: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    disableLengthCheck: true,
                    onCountryChanged: (country) {
                      setState(() {
                        _selectedCountryCode = '+' + country.dialCode;
                        _selectedCountryIso = country.code;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: context.tr('Enter Mobile Number'),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF000080)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _searchCustomer(unfocus: true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                )
              ],
            ),
            
            const SizedBox(height: 24),

            // Consumer to watch Provider state
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.errorMessage.isNotEmpty) {
                    final isNotFound = provider.errorMessage.toLowerCase().contains('not found');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isNotFound ? Icons.person_search : Icons.error_outline,
                            size: 72,
                            color: isNotFound ? Colors.orange.shade300 : Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isNotFound ? Colors.orange.shade700 : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isNotFound) ...
                          [
                            const SizedBox(height: 24),
                            Text(
                              context.tr('No customer found with this number.'),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                             ElevatedButton.icon(
                              onPressed: () async {
                                final rawMobile = _mobileController.text.trim();
                                final cleanCode = _selectedCountryCode.replaceAll('+', '');
                                final formattedMobile = rawMobile.startsWith(cleanCode) ? rawMobile : '$cleanCode$rawMobile';
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddCustomerScreen(
                                      phoneNumber: formattedMobile,
                                      initialCountryIso: _selectedCountryIso,
                                    ),
                                  ),
                                );
                                // If customer was added, auto-search again
                                if (result != null) {
                                  final token = context.read<AuthProvider>().token;
                                  if (token != null) {
                                    context.read<CustomerProvider>().searchCustomer(
                                      formattedMobile,
                                      token,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: Text(context.tr('Add New Customer')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000080),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  if (provider.customerData != null) {
                    final data = provider.customerData!;
                    final vehicles = data['vehicles'] as List<dynamic>;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Details Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF000080).withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Color(0xFF000080)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('Type: ${data['type']}  •  ${data['phone']}'),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Customer Vehicles'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () => _showAddVehicleDialog(context, data),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(context.tr('Add Vehicle')),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF000080),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Vehicle List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vehicles.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final v = vehicles[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InvoiceCreateScreen(
                                        customer: data,
                                        vehicle: v,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                v['no'],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_circle_right_outlined, size: 18, color: Color(0xFF000080)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF000080).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              (v['vehicle_type'] != null && v['vehicle_type'].toString().isNotEmpty)
                                                  ? "${v['vehicle_type']} - ${v['type']}"
                                                  : v['type'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF000080),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Divider(height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            context.tr('No. of visits: ${v['visits'] ?? 0}'),
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                          ),
                                          Text(
                                            context.tr('Tap to select'),
                                            style: const TextStyle(
                                              color: Color(0xFF000080),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Divider(height: 1),
                                      ),
                                      Row(
                                        children: [
                                          _msgButton(
                                            label: context.tr('Welcome'),
                                            icon: Icons.chat_bubble_outline,
                                            color: Colors.blue.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              type: 'welcome',
                                              customer: data,
                                              vehicle: v,
                                            ),
                                          ),
                                          _msgButton(
                                            label: context.tr('Ready Alert'),
                                            icon: Icons.notifications_none,
                                            color: Colors.orange.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              type: 'ready',
                                              customer: data,
                                              vehicle: v,
                                            ),
                                          ),
                                          _msgButton(
                                            label: context.tr('Thank You'),
                                            icon: Icons.favorite_border,
                                            color: Colors.green.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              type: 'thanks',
                                              customer: data,
                                              vehicle: v,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                          },
                          )
                        ],
                      ),
                    );
                  }

                  // Default empty state or suggestions list
                  if (_customerSuggestions.isNotEmpty) {
                    return _buildCustomerSuggestionsList();
                  }

                  if (_isSearchingSuggestions) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Search for a customer\nto start a new job'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSuggestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _customerSuggestions.length,
      itemBuilder: (context, index) {
        final c = _customerSuggestions[index];
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
            onTap: () => _selectCustomerFromSuggestion(c),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF000080).withOpacity(0.08),
                    child: const Icon(Icons.person, color: Color(0xFF000080), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c['phone']} · ${c['customer_type']}',
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


  void _showAddVehicleDialog(BuildContext context, Map<String, dynamic> customerData) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddVehicleDialog(
        customerData: customerData,
        token: token,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Vehicle added successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh the search automatically
      context.read<CustomerProvider>().searchCustomer(
        customerData['phone'],
        token,
      );
    }
  }

  Widget _msgButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 12, color: color),
          label: Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.08),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: color.withOpacity(0.2), width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendGenericMessage({
    required String type,
    required Map<String, dynamic> customer,
    required Map<String, dynamic> vehicle,
  }) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final phone = customer['phone']?.toString() ?? '';
    final customerName = customer['name']?.toString() ?? 'Customer';
    final vehicleNumber = vehicle['no']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Map<String, dynamic> res;
      if (type == 'welcome') {
        res = await ApiService.sendVehicleWelcomeMessageGeneric(
          phone: phone,
          vehicleNumber: vehicleNumber,
          customerName: customerName,
          token: token,
        );
      } else if (type == 'ready') {
        res = await ApiService.sendVehicleReadyAlertGeneric(
          phone: phone,
          vehicleNumber: vehicleNumber,
          customerName: customerName,
          token: token,
        );
      } else {
        res = await ApiService.sendVehicleThanksMessageGeneric(
          phone: phone,
          vehicleNumber: vehicleNumber,
          customerName: customerName,
          token: token,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      final isAuto = res['action'] == 'auto';
      if (isAuto && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(res['message'] ?? 'Message sent successfully!')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // WhatsApp API not configured -> manual fallback via WhatsApp chat with pre-filled message
        String messageText = '';
        if (type == 'welcome') {
          messageText = "Hello $customerName, welcome to our service! We are delighted to have you and your vehicle ($vehicleNumber) with us.";
        } else if (type == 'ready') {
          messageText = "Hello $customerName, your vehicle ($vehicleNumber) is ready for pickup! Thank you for choosing our service.";
        } else {
          messageText = "Hello $customerName, thank you for choosing our service! We look forward to serving you again. Have a great day!";
        }

        String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
        if (cleanedPhone.length == 10) {
          cleanedPhone = '91$cleanedPhone';
        }

        final whatsappUrl = Uri.parse(
          "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(messageText)}"
        );

        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Error sending message')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _AddVehicleDialog extends StatefulWidget {
  final Map<String, dynamic> customerData;
  final String token;

  const _AddVehicleDialog({
    required this.customerData,
    required this.token,
  });

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  
  Map<String, dynamic>? _fullCustomerData;
  List<dynamic> _vehicleModels = [];
  Map<String, List<dynamic>> _vehicleModelsByType = {};
  Map<String, dynamic>? _selectedModel;
  final _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getCustomer(widget.customerData['id'], widget.token),
        ApiService.getFormData(widget.token),
      ]);

      final customerRes = results[0];
      final formDataRes = results[1];

      if (customerRes['success'] == true && formDataRes['success'] == true) {
        final models = formDataRes['vehicle_models'] as List<dynamic>;
        final Map<String, List<dynamic>> grouped = {};
        for (final m in models) {
          final type = m['vehicle_type'] as String;
          grouped.putIfAbsent(type, () => []).add(m);
        }

        setState(() {
          _fullCustomerData = customerRes['customer'];
          _vehicleModels = models;
          _vehicleModelsByType = grouped;
          if (models.isNotEmpty) {
            _selectedModel = models.first;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load details or options';
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

  Future<void> _save() async {
    final number = _numberController.text.trim().toUpperCase();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter vehicle number'))),
      );
      return;
    }
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select a vehicle model'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await ApiService.editCustomer({
        'customer_id': _fullCustomerData!['id'],
        'name': _fullCustomerData!['name'],
        'phone': _fullCustomerData!['phone'],
        'whatsapp_number': _fullCustomerData!['whatsapp_number'] ?? '',
        'email': _fullCustomerData!['email'] ?? '',
        'address': _fullCustomerData!['address'] ?? '',
        'customer_type_id': _fullCustomerData!['customer_type_id'],
        'new_vehicles': [
          {
            'vehicle_number': number,
            'vehicle_model_id': _selectedModel!['id'],
          }
        ],
      }, widget.token);

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to add vehicle';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
    }
  }

  List<DropdownMenuItem<Map<String, dynamic>>> _buildGroupedDropdownItems() {
    final items = <DropdownMenuItem<Map<String, dynamic>>>[];
    final keys = _vehicleModelsByType.keys.toList();
    keys.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      if (aLower == 'bike/scooter') return -1;
      if (bLower == 'bike/scooter') return 1;
      if (aLower == 'car/jeep') return -1;
      if (bLower == 'car/jeep') return 1;
      return aLower.compareTo(bLower);
    });

    for (final type in keys) {
      final models = _vehicleModelsByType[type]!;
      items.add(DropdownMenuItem<Map<String, dynamic>>(
        enabled: false,
        value: null,
        child: Text(
          type.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ));
      for (final m in models) {
        items.add(DropdownMenuItem<Map<String, dynamic>>(
          value: m,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(m['name']),
          ),
        ));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.tr('Add Vehicle'),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080)),
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage.isNotEmpty) ...[
                    Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.tr('Vehicle Model'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        menuMaxHeight: 350,
                        value: _selectedModel,
                        hint: Text(context.tr('Select model...')),
                        items: _buildGroupedDropdownItems(),
                        onChanged: (val) => setState(() => _selectedModel = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Vehicle Number'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _numberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: context.tr('e.g. KL 01 AB 1234'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF000080)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000080),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(context.tr('Save')),
        ),
      ],
    );
  }
}
