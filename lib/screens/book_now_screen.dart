import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'booking_create_screen.dart';

class BookNowScreen extends StatefulWidget {
  const BookNowScreen({super.key});

  @override
  State<BookNowScreen> createState() => _BookNowScreenState();
}

class _BookNowScreenState extends State<BookNowScreen> {
  static const _primaryColor = Color(0xFF000080);

  final _mobileController = TextEditingController();
  final _searchTypeNotifier = ValueNotifier<String>('number');
  final _selectedCountryCodeNotifier = ValueNotifier<String>(CountryConfig.phoneDialCode);
  final _customerSuggestionsNotifier = ValueNotifier<List<dynamic>>([]);
  final _isSearchingSuggestionsNotifier = ValueNotifier<bool>(false);
  final _branchesNotifier = ValueNotifier<List<dynamic>>([]);
  final _selectedBranchIdNotifier = ValueNotifier<String?>( null);
  final _isLoadingBranchesNotifier = ValueNotifier<bool>(false);

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().clearData();
      _loadBranches();
    });
    _mobileController.addListener(_onMobileChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mobileController.removeListener(_onMobileChanged);
    _mobileController.dispose();
    _searchTypeNotifier.dispose();
    _selectedCountryCodeNotifier.dispose();
    _customerSuggestionsNotifier.dispose();
    _isSearchingSuggestionsNotifier.dispose();
    _branchesNotifier.dispose();
    _selectedBranchIdNotifier.dispose();
    _isLoadingBranchesNotifier.dispose();
    super.dispose();
  }

  void _onMobileChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();
    if (text.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _fetchCustomerSuggestions(text);
      });
    } else {
      _customerSuggestionsNotifier.value = [];
      if (text.isEmpty) {
        context.read<CustomerProvider>().clearData();
      }
    }
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin) return;
    _isLoadingBranchesNotifier.value = true;
    try {
      final token = auth.token;
      if (token != null) {
        final res = await ApiService.getCompanyBranches(token);
        if (res['success'] == true) {
          final list = res['branches'] as List<dynamic>;
          _branchesNotifier.value = list;
          if (list.isNotEmpty) {
            _selectedBranchIdNotifier.value = list[0]['id']?.toString();
          }
        }
      }
    } catch (_) {} finally {
      _isLoadingBranchesNotifier.value = false;
    }
  }

  Future<void> _fetchCustomerSuggestions(String query) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isSearchingSuggestionsNotifier.value = true;
    try {
      final res = _searchTypeNotifier.value == 'vehicle'
          ? await ApiService.searchVehicleList(query, token)
          : await ApiService.searchCustomerList(query, token, branchId: _selectedBranchIdNotifier.value);
      if (res['success'] == true) {
        _customerSuggestionsNotifier.value = (_searchTypeNotifier.value == 'vehicle'
            ? res['vehicles']
            : res['customers']) as List<dynamic>;
      } else {
        _customerSuggestionsNotifier.value = [];
      }
    } catch (_) {
      _customerSuggestionsNotifier.value = [];
    } finally {
      _isSearchingSuggestionsNotifier.value = false;
    }
  }

  void _selectCustomerFromSuggestion(Map<String, dynamic> suggestion) {
    _customerSuggestionsNotifier.value = [];
    String rawPhone = suggestion['phone'] ?? '';
    String phoneCode = '+91';
    for (final code in ['971', '966', '965', '968', '974', '973', '91']) {
      if (rawPhone.startsWith(code)) {
        phoneCode = '+$code';
        rawPhone = rawPhone.substring(code.length);
        break;
      }
    }
    _selectedCountryCodeNotifier.value = phoneCode;
    _mobileController.text = rawPhone;
    _searchCustomer(unfocus: true);
  }

  void _selectCustomerFromVehicleSuggestion(Map<String, dynamic> suggestion) {
    _customerSuggestionsNotifier.value = [];
    _mobileController.text = suggestion['vehicle_number'] ?? '';
    _searchCustomer(unfocus: true);
  }

  void _searchCustomer({bool unfocus = true}) {
    if (unfocus) FocusScope.of(context).unfocus();
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final queryText = _mobileController.text.trim();
    if (queryText.isEmpty) return;

    if (_searchTypeNotifier.value == 'vehicle') {
      context.read<CustomerProvider>().searchCustomer(
            queryText, token,
            branchId: _selectedBranchIdNotifier.value,
            isVehicle: true,
          );
    } else {
      final cleanCode = _selectedCountryCodeNotifier.value.replaceAll('+', '');
      final formattedMobile = queryText.startsWith(cleanCode) ? queryText : '$cleanCode$queryText';
      context.read<CustomerProvider>().searchCustomer(
            formattedMobile, token,
            branchId: _selectedBranchIdNotifier.value,
            isVehicle: false,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Book Now'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Blue header search area ──
          Container(
            color: _primaryColor,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              children: [
                // Branch selector (company admin only)
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoadingBranchesNotifier,
                  builder: (_, loading, __) {
                    if (loading) return const SizedBox(height: 8);
                    return ValueListenableBuilder<List<dynamic>>(
                      valueListenable: _branchesNotifier,
                      builder: (_, branches, __) {
                        if (!context.read<AuthProvider>().isCompanyAdmin || branches.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ValueListenableBuilder<String?>(
                            valueListenable: _selectedBranchIdNotifier,
                            builder: (_, selectedBranchId, __) {
                              return DropdownButtonFormField<String>(
                                value: selectedBranchId,
                                dropdownColor: Colors.white,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: context.tr('Select Branch'),
                                  labelStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                style: GoogleFonts.inter(color: const Color(0xFF1e293b), fontWeight: FontWeight.w600),
                                items: branches.map((b) => DropdownMenuItem<String>(
                                  value: b['id']?.toString(),
                                  child: Text(b['name'] ?? ''),
                                )).toList(),
                                onChanged: (val) {
                                  _selectedBranchIdNotifier.value = val;
                                  _customerSuggestionsNotifier.value = [];
                                  context.read<CustomerProvider>().clearData();
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),

                // Search type radio row
                ValueListenableBuilder<String>(
                  valueListenable: _searchTypeNotifier,
                  builder: (_, searchType, __) {
                    return Row(
                      children: [
                        _radioChip('number', searchType, context.tr('Owner Number'), Icons.phone),
                        const SizedBox(width: 12),
                        _radioChip('vehicle', searchType, context.tr('Vehicle Number'), Icons.directions_car),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Search input + button
                ValueListenableBuilder<String>(
                  valueListenable: _searchTypeNotifier,
                  builder: (_, searchType, __) {
                    return Row(
                      children: [
                        Expanded(
                          child: searchType == 'vehicle'
                              ? TextField(
                                  controller: _mobileController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    hintText: context.tr('Enter Vehicle Number'),
                                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: const Icon(Icons.directions_car, color: _primaryColor),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onSubmitted: (_) => _searchCustomer(),
                                )
                              : IntlPhoneField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  initialCountryCode: CountryConfig.phoneIsoCode,
                                  dropdownTextStyle: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                                  disableLengthCheck: true,
                                  onCountryChanged: (country) {
                                    _selectedCountryCodeNotifier.value = '+${country.dialCode}';
                                  },
                                  decoration: InputDecoration(
                                    hintText: context.tr('Enter Mobile Number'),
                                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onSubmitted: (_) => _searchCustomer(),
                                ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            _debounce?.cancel();
                            _searchCustomer();
                          },
                          child: Container(
                            height: 54,
                            width: 54,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.search, color: _primaryColor, size: 26),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Content area ──
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Error / not found
                if (provider.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          provider.errorMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                // Customer found
                if (provider.customerData != null) {
                  final customer = provider.customerData!;
                  final vehicles = (customer['vehicles'] as List<dynamic>? ?? []);
                  return _buildCustomerResult(customer, vehicles);
                }

                // Suggestions
                return ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _customerSuggestionsNotifier,
                  builder: (_, suggestions, __) {
                    if (suggestions.isNotEmpty) {
                      return _buildSuggestionsList(suggestions);
                    }
                    return ValueListenableBuilder<bool>(
                      valueListenable: _isSearchingSuggestionsNotifier,
                      builder: (_, isSearching, __) {
                        if (isSearching) return const Center(child: CircularProgressIndicator());
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade200),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('Search a customer to book a slot'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 15),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioChip(String value, String current, String label, IconData icon) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () {
        _searchTypeNotifier.value = value;
        _mobileController.clear();
        _customerSuggestionsNotifier.value = [];
        context.read<CustomerProvider>().clearData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? _primaryColor : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? _primaryColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(List<dynamic> suggestions) {
    final isVehicle = _searchTypeNotifier.value == 'vehicle';
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (_, i) {
        final c = suggestions[i] as Map<String, dynamic>;
        final name = isVehicle ? (c['customer_name'] ?? '') : (c['name'] ?? '');
        final subtitle = isVehicle
            ? '${c['vehicle_number']} · ${c['vehicle_model']} · ${c['customer_phone']}'
            : '${c['phone']} · ${c['customer_type']}${(c['branch_name'] != null && c['branch_name'].toString().isNotEmpty) ? ' · ${c['branch_name']}' : ''}';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isVehicle ? Icons.directions_car : Icons.person,
                color: _primaryColor,
                size: 20,
              ),
            ),
            title: Text(name.toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(subtitle.toString(), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF000080)),
            onTap: () {
              if (isVehicle) {
                _selectCustomerFromVehicleSuggestion(Map<String, dynamic>.from(c));
              } else {
                _selectCustomerFromSuggestion(Map<String, dynamic>.from(c));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomerResult(Map<String, dynamic> customer, List<dynamic> vehicles) {
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
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: _primaryColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'],
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1e293b)),
                    ),
                    const SizedBox(height: 4),
                    Text(customer['phone'], style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                    if ((customer['type'] ?? '').toString().isNotEmpty)
                      Text(customer['type'], style: GoogleFonts.inter(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          context.tr('Select a Vehicle to Book'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),

        if (vehicles.isEmpty)
          Center(
            child: Text(
              context.tr('No vehicles found for this customer.'),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),

        ...vehicles.map((v) {
          final vehicle = Map<String, dynamic>.from(v as Map);
          final bool hasScheme = vehicle['scheme_name'] != null;
          final bool isEligible = vehicle['is_eligible'] ?? false;
          final vehicleNo = vehicle['no']?.toString() ?? '';
          final vehicleType = vehicle['vehicle_type'] != null && vehicle['vehicle_type'].toString().isNotEmpty
              ? '${vehicle['vehicle_type']} - ${vehicle['type']}'
              : (vehicle['type'] ?? '');

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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEligible ? Colors.green.shade50 : _primaryColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_car, color: isEligible ? Colors.green : _primaryColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleNo,
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1e293b), letterSpacing: 0.8),
                      ),
                      Text(vehicleType.toString(), style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
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
                                child: Text(context.tr('FREE'), style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingCreateScreen(
                          customer: Map<String, dynamic>.from(customer),
                          selectedVehicle: vehicle,
                          allVehicles: vehicles,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEligible ? Colors.green : _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(context.tr('Book Now'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
