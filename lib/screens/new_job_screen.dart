import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../config/country_config.dart';
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
  String _selectedCountryCode = CountryConfig.phoneDialCode;
  String _selectedCountryIso = CountryConfig.phoneIsoCode;
  String _searchType = 'number';
  Timer? _debounce;
  List<dynamic> _customerSuggestions = [];
  bool _isSearchingSuggestions = false;

  List<dynamic> _branches = [];
  String? _selectedBranchId;
  bool _isLoadingBranches = false;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_onMobileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().clearData();
      _loadBranches();
    });
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin) return;
    
    setState(() {
      _isLoadingBranches = true;
    });
    
    try {
      final token = auth.token;
      if (token != null) {
        final res = await ApiService.getCompanyBranches(token);
        if (res['success'] == true && mounted) {
          setState(() {
            _branches = res['branches'] as List<dynamic>;
            if (_branches.isNotEmpty) {
              _selectedBranchId = _branches[0]['id']?.toString();
            }
            _isLoadingBranches = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  void _onMobileChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();
    if (text.length >= 2) {
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
      final res = _searchType == 'vehicle'
          ? await ApiService.searchVehicleList(query, token)
          : await ApiService.searchCustomerList(query, token, branchId: _selectedBranchId);
      if (res['success'] == true && mounted) {
        setState(() {
          _customerSuggestions = (_searchType == 'vehicle' ? res['vehicles'] : res['customers']) as List<dynamic>;
          _isSearchingSuggestions = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _customerSuggestions = [];
            _isSearchingSuggestions = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _customerSuggestions = [];
          _isSearchingSuggestions = false;
        });
      }
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

  void _selectCustomerFromVehicleSuggestion(Map<String, dynamic> suggestion) {
    setState(() {
      _customerSuggestions = [];
      _mobileController.text = suggestion['vehicle_number'] ?? '';
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
      final queryText = _mobileController.text.trim();
      if (queryText.isNotEmpty) {
        if (_searchType == 'vehicle') {
          context.read<CustomerProvider>().searchCustomer(
            queryText,
            token,
            branchId: _selectedBranchId,
            isVehicle: true,
          );
        } else {
          final cleanCode = _selectedCountryCode.replaceAll('+', '');
          final formattedMobile = queryText.startsWith(cleanCode) ? queryText : '$cleanCode$queryText';
          context.read<CustomerProvider>().searchCustomer(
            formattedMobile,
            token,
            branchId: _selectedBranchId,
            isVehicle: false,
          );
        }
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
            if (_isLoadingBranches)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (context.read<AuthProvider>().isCompanyAdmin && _branches.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: InputDecoration(
                  labelText: context.tr('Select Branch'),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF000080)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
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
                items: _branches.map((b) {
                  return DropdownMenuItem<String>(
                    value: b['id']?.toString(),
                    child: Text(b['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBranchId = val;
                    _customerSuggestions = [];
                    context.read<CustomerProvider>().clearData();
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            // Search Type Radios
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Radio<String>(
                  value: 'number',
                  groupValue: _searchType,
                  activeColor: const Color(0xFF000080),
                  onChanged: (val) {
                    setState(() {
                      _searchType = val!;
                      _mobileController.clear();
                      _customerSuggestions = [];
                      context.read<CustomerProvider>().clearData();
                    });
                  },
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchType = 'number';
                      _mobileController.clear();
                      _customerSuggestions = [];
                      context.read<CustomerProvider>().clearData();
                    });
                  },
                  child: Text(
                    context.tr('Search by Number'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _searchType == 'number' ? const Color(0xFF000080) : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'vehicle',
                  groupValue: _searchType,
                  activeColor: const Color(0xFF000080),
                  onChanged: (val) {
                    setState(() {
                      _searchType = val!;
                      _mobileController.clear();
                      _customerSuggestions = [];
                      context.read<CustomerProvider>().clearData();
                    });
                  },
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchType = 'vehicle';
                      _mobileController.clear();
                      _customerSuggestions = [];
                      context.read<CustomerProvider>().clearData();
                    });
                  },
                  child: Text(
                    context.tr('Search by Vehicle'),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _searchType == 'vehicle' ? const Color(0xFF000080) : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search Section
            Row(
              children: [
                Expanded(
                  child: _searchType == 'vehicle'
                      ? TextField(
                          controller: _mobileController,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: context.tr('Enter Vehicle Number'),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.directions_car, color: Color(0xFF000080)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                        )
                      : IntlPhoneField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          initialCountryCode: CountryConfig.phoneIsoCode,
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
                                      branchId: _selectedBranchId,
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
                                      branchId: _selectedBranchId,
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
                                  backgroundColor: const Color(0xFF000080).withValues(alpha: 0.1),
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
                                      if (data['branch'] != null && data['branch'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${context.tr("Branch")}: ${data['branch']}',
                                          style: const TextStyle(
                                            color: Color(0xFF000080),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
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
                              ElevatedButton.icon(
                                onPressed: () => _showAddVehicleDialog(context, data),
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: Text(
                                  context.tr('Add Vehicle'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                                  foregroundColor: const Color(0xFF000080),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFF000080), width: 1.2),
                                  ),
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
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF000080).withValues(alpha: 0.15),
                                      width: 1.7,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF000080).withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
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
                                                style: GoogleFonts.inter(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF000080),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_circle_right, size: 18, color: Color(0xFF000080)),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF000080).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF000080).withValues(alpha: 0.15),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              (v['vehicle_type'] != null && v['vehicle_type'].toString().isNotEmpty)
                                                  ? "${v['vehicle_type']} - ${v['type']}"
                                                  : v['type'],
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF000080),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Text(
                                                  context.tr('No. of visits: ${v['visits'] ?? 0}'),
                                                  style: GoogleFonts.inter(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.0),
                                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
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
        final isVehicleSuggestion = _searchType == 'vehicle';
        
        final String name = isVehicleSuggestion 
            ? (c['customer_name'] ?? '') 
            : (c['name'] ?? '');
            
        final String subtitle = isVehicleSuggestion
            ? '${c['vehicle_number']} · ${c['vehicle_model']} · ${c['customer_phone']}'
            : '${c['phone']} · ${c['customer_type']}${(c['branch_name'] != null && c['branch_name'].toString().isNotEmpty) ? ' · ${c['branch_name']}' : ''}';
            
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
              if (isVehicleSuggestion) {
                _selectCustomerFromVehicleSuggestion(c);
              } else {
                _selectCustomerFromSuggestion(c);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF000080).withValues(alpha: 0.08),
                    child: Icon(
                      isVehicleSuggestion ? Icons.directions_car : Icons.person,
                      color: const Color(0xFF000080),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
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
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
        // WhatsApp API not configured → use server-provided branch-custom prefill message
        final String messageText = res['message_text']?.toString() ?? '';

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

  // 4-level hierarchy
  List<dynamic> _vehicleTypes = [];
  List<dynamic> _vehicleTypeModels = [];
  List<dynamic> _makes = [];
  List<dynamic> _brandModels = [];
  List<dynamic> _colors = [];

  Map<String, dynamic>? _selectedType;
  Map<String, dynamic>? _selectedSegment;
  Map<String, dynamic>? _selectedMake;
  Map<String, dynamic>? _selectedBrand;
  Map<String, dynamic>? _selectedColor;

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
        final vehicleTypes = formDataRes['vehicle_types'] as List<dynamic>? ?? [];
        final vehicleTypeModels = formDataRes['vehicle_type_models'] as List<dynamic>?
            ?? formDataRes['vehicle_models'] as List<dynamic>? ?? [];
        final makes = formDataRes['makes'] as List<dynamic>? ?? [];
        final brandModels = formDataRes['brand_models'] as List<dynamic>? ?? [];
        final colors = formDataRes['colors'] as List<dynamic>? ?? [];

        setState(() {
          _fullCustomerData = customerRes['customer'];
          _vehicleTypes = vehicleTypes;
          _vehicleTypeModels = vehicleTypeModels;
          _makes = makes;
          _brandModels = brandModels;
          _colors = colors;
          if (vehicleTypes.isNotEmpty) _selectedType = vehicleTypes.first;
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
    final number = _numberController.text.trim().toUpperCase();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter vehicle number'))),
      );
      return;
    }
    if (_selectedSegment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select a vehicle type and segment'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vehicleData = <String, dynamic>{
        'vehicle_number': number,
        'vehicle_model_id': _selectedSegment!['id'],
      };
      if (_selectedMake != null) vehicleData['make_id'] = _selectedMake!['id'];
      if (_selectedBrand != null) vehicleData['brand_model_id'] = _selectedBrand!['id'];
      if (_selectedColor != null) vehicleData['color_id'] = _selectedColor!['id'];

      final response = await ApiService.editCustomer({
        'customer_id': _fullCustomerData!['id'],
        'name': _fullCustomerData!['name'],
        'phone': _fullCustomerData!['phone'],
        'whatsapp_number': _fullCustomerData!['whatsapp_number'] ?? '',
        'email': _fullCustomerData!['email'] ?? '',
        'address': _fullCustomerData!['address'] ?? '',
        'customer_type_id': _fullCustomerData!['customer_type_id'],
        'new_vehicles': [vehicleData],
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

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    void Function(T?)? onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
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
              menuMaxHeight: 300,
              value: value,
              hint: Text(hint ?? 'Select...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item), style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsForType(_selectedType?['id']);
    final makes = _makesForSegment(_selectedSegment?['id']);
    final brands = _brandModelsForSegmentAndMake(_selectedSegment?['id'], _selectedMake?['id']);

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

                  // Level 1 — Vehicle Type
                  _buildDropdown<Map<String, dynamic>>(
                    label: context.tr('Vehicle Type *'),
                    value: _selectedType,
                    items: _vehicleTypes.cast<Map<String, dynamic>>(),
                    labelBuilder: (vt) => vt['name'],
                    hint: 'Select vehicle type',
                    onChanged: (val) {
                      setState(() {
                        _selectedType = val;
                        _selectedSegment = null;
                        _selectedMake = null;
                        _selectedBrand = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Level 2 — Segment
                  if (_selectedType != null) ...[
                    _buildDropdown<Map<String, dynamic>>(
                      label: context.tr('Segment *'),
                      value: _selectedSegment,
                      items: segments.cast<Map<String, dynamic>>(),
                      labelBuilder: (m) => m['name'],
                      hint: segments.isEmpty ? 'No segments available' : 'Select segment',
                      onChanged: segments.isEmpty ? null : (val) {
                        setState(() {
                          _selectedSegment = val;
                          _selectedMake = null;
                          _selectedBrand = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Level 3 — Vehicle Make (Optional)
                  if (_selectedSegment != null) ...[
                    _buildDropdown<Map<String, dynamic>>(
                      label: context.tr('Vehicle Make'),
                      value: _selectedMake,
                      items: makes.cast<Map<String, dynamic>>(),
                      labelBuilder: (b) => b['name'],
                      hint: makes.isEmpty ? 'No makes available' : 'Select make',
                      onChanged: makes.isEmpty ? null : (val) {
                        setState(() {
                          _selectedMake = val;
                          _selectedBrand = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Level 4 — Brand Model (Optional, only show after Make is selected)
                  if (_selectedSegment != null && _selectedMake != null) ...[
                    _buildDropdown<Map<String, dynamic>>(
                      label: context.tr('Brand'),
                      value: _selectedBrand,
                      items: brands.cast<Map<String, dynamic>>(),
                      labelBuilder: (b) => b['name'],
                      hint: brands.isEmpty ? 'No brands available' : 'Select brand',
                      onChanged: brands.isEmpty ? null : (val) {
                        setState(() => _selectedBrand = val);
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Color (optional)
                  if (_selectedType != null) ...[
                    _buildDropdown<Map<String, dynamic>>(
                      label: context.tr('Color (Optional)'),
                      value: _selectedColor,
                      items: [{'id': '', 'name': 'None'}, ..._colors.cast<Map<String, dynamic>>()],
                      labelBuilder: (c) => c['name'],
                      hint: 'Select color',
                      onChanged: (val) {
                        setState(() {
                          _selectedColor = (val?['id'] == '') ? null : val;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Vehicle Number
                  Text(
                    context.tr('Vehicle Number *'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _numberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: context.tr('Enter Vehicle Number'),
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


