import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:async';
import '../config/country_config.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'quotation_create_screen.dart';

class QuotationSearchScreen extends StatelessWidget {
  const QuotationSearchScreen({super.key});

  static final TextEditingController _mobileController = TextEditingController();
  static final ValueNotifier<String> _selectedCountryCodeNotifier = ValueNotifier(CountryConfig.phoneDialCode);
  static final ValueNotifier<String> _selectedCountryIsoNotifier = ValueNotifier(CountryConfig.phoneIsoCode);
  static final ValueNotifier<String> _searchTypeNotifier = ValueNotifier('number');
  static final ValueNotifier<List<dynamic>> _customerSuggestionsNotifier = ValueNotifier([]);
  static final ValueNotifier<bool> _isSearchingSuggestionsNotifier = ValueNotifier(false);

  static final ValueNotifier<List<dynamic>> _branchesNotifier = ValueNotifier([]);
  static final ValueNotifier<String?> _selectedBranchIdNotifier = ValueNotifier(null);
  static final ValueNotifier<bool> _isLoadingBranchesNotifier = ValueNotifier(false);

  static Timer? _debounce;

  void _onMobileChanged(BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();
    if (text.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _fetchCustomerSuggestions(context, text);
      });
    } else {
      _customerSuggestionsNotifier.value = [];
      if (text.isEmpty) {
        context.read<CustomerProvider>().clearData();
      }
    }
  }

  Future<void> _loadBranches(BuildContext context) async {
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

  Future<void> _fetchCustomerSuggestions(BuildContext context, String query) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isSearchingSuggestionsNotifier.value = true;

    try {
      final res = _searchTypeNotifier.value == 'vehicle'
          ? await ApiService.searchVehicleList(query, token)
          : await ApiService.searchCustomerList(query, token, branchId: _selectedBranchIdNotifier.value);
      if (res['success'] == true) {
        _customerSuggestionsNotifier.value = (_searchTypeNotifier.value == 'vehicle' ? res['vehicles'] : res['customers']) as List<dynamic>;
      } else {
        _customerSuggestionsNotifier.value = [];
      }
    } catch (_) {
      _customerSuggestionsNotifier.value = [];
    } finally {
      _isSearchingSuggestionsNotifier.value = false;
    }
  }

  void _selectCustomerFromSuggestion(BuildContext context, Map<String, dynamic> suggestion) {
    _customerSuggestionsNotifier.value = [];
    final rawPhone = suggestion['phone']?.toString() ?? '';
    if (rawPhone.isEmpty) return;

    String strippedPhone = rawPhone;
    String phoneCode = _selectedCountryCodeNotifier.value;
    String countryIso = _selectedCountryIsoNotifier.value;

    // Match any known dial code — longest first to avoid prefix collisions
    final allCountries = CountryConfig.all
      ..sort((a, b) => b.phoneDialCode.length.compareTo(a.phoneDialCode.length));
    for (final country in allCountries) {
      final cleanCode = country.phoneDialCode.replaceAll('+', '');
      if (rawPhone.startsWith(cleanCode) && rawPhone.length > cleanCode.length) {
        phoneCode = country.phoneDialCode;
        countryIso = country.phoneIsoCode;
        strippedPhone = rawPhone.substring(cleanCode.length);
        break;
      }
    }

    _selectedCountryCodeNotifier.value = phoneCode;
    _selectedCountryIsoNotifier.value = countryIso;
    _mobileController.text = strippedPhone;

    _searchCustomer(context, unfocus: true);
  }

  void _selectCustomerFromVehicleSuggestion(BuildContext context, Map<String, dynamic> suggestion) {
    _customerSuggestionsNotifier.value = [];
    _mobileController.text = suggestion['vehicle_number'] ?? '';
    _searchCustomer(context, unfocus: true);
  }

  void _searchCustomer(BuildContext context, {bool unfocus = true}) {
    if (unfocus) {
      FocusScope.of(context).unfocus();
    }
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      final queryText = _mobileController.text.trim();
      if (queryText.isNotEmpty) {
        if (_searchTypeNotifier.value == 'vehicle') {
          context.read<CustomerProvider>().searchCustomer(
            queryText,
            token,
            branchId: _selectedBranchIdNotifier.value,
            isVehicle: true,
          );
        } else {
          final formattedMobile = CountryConfig.formatPhoneWithCountryCode(queryText, _selectedCountryCodeNotifier.value);
          context.read<CustomerProvider>().searchCustomer(
            formattedMobile,
            token,
            branchId: _selectedBranchIdNotifier.value,
            isVehicle: false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().clearData();
      _loadBranches(context);
    });

    _mobileController.addListener(() => _onMobileChanged(context));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Quotation'), style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Color(0xFF000080),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isLoadingBranchesNotifier,
              builder: (context, isLoadingBranches, child) {
                if (isLoadingBranches) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _branchesNotifier,
                  builder: (context, branches, child) {
                    if (context.read<AuthProvider>().isCompanyAdmin && branches.isNotEmpty) {
                      return ValueListenableBuilder<String?>(
                        valueListenable: _selectedBranchIdNotifier,
                        builder: (context, selectedBranchId, child) {
                          return DropdownButtonFormField<String>(
                            value: selectedBranchId,
                            decoration: InputDecoration(
                              labelText: context.tr('Select Branch'),
                              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Color(0xFF000080)),
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
                            items: branches.map((b) {
                              return DropdownMenuItem<String>(
                                value: b['id']?.toString(),
                                child: Text(b['name'] ?? ''),
                              );
                            }).toList(),
                            onChanged: (val) {
                              _selectedBranchIdNotifier.value = val;
                              _customerSuggestionsNotifier.value = [];
                              context.read<CustomerProvider>().clearData();
                            },
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Search Type Radios
            ValueListenableBuilder<String>(
              valueListenable: _searchTypeNotifier,
              builder: (context, searchType, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: 'number',
                      groupValue: searchType,
                      activeColor: const Color(0xFF000080),
                      onChanged: (val) {
                        if (val != null) {
                          _searchTypeNotifier.value = val;
                          _mobileController.clear();
                          _customerSuggestionsNotifier.value = [];
                          context.read<CustomerProvider>().clearData();
                        }
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        _searchTypeNotifier.value = 'number';
                        _mobileController.clear();
                        _customerSuggestionsNotifier.value = [];
                        context.read<CustomerProvider>().clearData();
                      },
                      child: Text(
                        context.tr('Owner Number'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: searchType == 'number' ? Color(0xFF000080) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Radio<String>(
                      value: 'vehicle',
                      groupValue: searchType,
                      activeColor: const Color(0xFF000080),
                      onChanged: (val) {
                        if (val != null) {
                          _searchTypeNotifier.value = val;
                          _mobileController.clear();
                          _customerSuggestionsNotifier.value = [];
                          context.read<CustomerProvider>().clearData();
                        }
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        _searchTypeNotifier.value = 'vehicle';
                        _mobileController.clear();
                        _customerSuggestionsNotifier.value = [];
                        context.read<CustomerProvider>().clearData();
                      },
                      child: Text(
                        context.tr('Vehicle Number'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: searchType == 'vehicle' ? Color(0xFF000080) : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Search Input Row
            ValueListenableBuilder<String>(
              valueListenable: _searchTypeNotifier,
              builder: (context, searchType, child) {
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
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.directions_car, color: Color(0xFF000080)),
                                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                              dropdownTextStyle: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14.sp),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                              disableLengthCheck: true,
                              onCountryChanged: (country) {
                                _selectedCountryCodeNotifier.value = '+' + country.dialCode;
                                _selectedCountryIsoNotifier.value = country.code;
                              },
                              decoration: InputDecoration(
                                hintText: context.tr('Enter Mobile Number'),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(vertical: 16),
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
                        _searchCustomer(context, unfocus: true);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: Color(0xFF000080),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.search, color: Colors.white),
                      ),
                    )
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Results Area
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
                          SizedBox(height: 16),
                          Text(
                            provider.errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isNotFound ? Colors.orange.shade700 : Colors.red,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isNotFound) ...[
                            SizedBox(height: 24),
                            Text(
                              context.tr('No customer found with this number.'),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14.sp),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final rawMobile = _mobileController.text.trim();
                                final formattedMobile = CountryConfig.formatPhoneWithCountryCode(rawMobile, _selectedCountryCodeNotifier.value);

                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddCustomerScreen(
                                      phoneNumber: formattedMobile,
                                      initialCountryIso: _selectedCountryIsoNotifier.value,
                                      initialDialCode: _selectedCountryCodeNotifier.value,
                                      branchId: _selectedBranchIdNotifier.value,
                                    ),
                                  ),
                                );
                                if (result != null) {
                                  final token = context.read<AuthProvider>().token;
                                  if (token != null) {
                                    context.read<CustomerProvider>().searchCustomer(
                                      formattedMobile,
                                      token,
                                      branchId: _selectedBranchIdNotifier.value,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: Text(context.tr('Add New Customer')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF000080),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                          // Customer Card
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Color(0xFF000080).withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: Color(0xFF000080)),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'],
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('Type: ${data['type']}  •  ${data['phone']}'),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 24),
                          Text(
                            context.tr('Select Vehicle for Quotation'),
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),

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
                                      builder: (context) => QuotationCreateScreen(
                                        customer: data,
                                        vehicle: v,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Color(0xFF000080).withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            v['no'],
                                            style: GoogleFonts.inter(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF000080),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (v['vehicle_type'] != null && v['vehicle_type'].toString().isNotEmpty)
                                                ? "${v['vehicle_type']} - ${v['type']}"
                                                : v['type'],
                                            style: GoogleFonts.inter(
                                              color: Colors.grey.shade600,
                                              fontSize: 13.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            context.tr('Create Quotation'),
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF000080),
                                              fontSize: 13.sp,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF000080)),
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

                  return ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _customerSuggestionsNotifier,
                    builder: (context, customerSuggestions, child) {
                      if (customerSuggestions.isNotEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: customerSuggestions.length,
                          itemBuilder: (context, index) {
                            final c = customerSuggestions[index];
                            final isVehicleSuggestion = _searchTypeNotifier.value == 'vehicle';

                            final String name = isVehicleSuggestion 
                                ? (c['customer_name'] ?? '') 
                                : (c['name'] ?? '');

                            final String subtitle = isVehicleSuggestion
                                ? '${c['vehicle_number']} · ${c['vehicle_model']} · ${c['customer_phone']}'
                                : '${c['phone']} · ${c['customer_type']}';

                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFF000080).withValues(alpha: 0.1),
                                  child: Icon(
                                    isVehicleSuggestion ? Icons.directions_car : Icons.person,
                                    color: Color(0xFF000080),
                                  ),
                                ),
                                title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12.sp)),
                                onTap: () {
                                  if (isVehicleSuggestion) {
                                    _selectCustomerFromVehicleSuggestion(context, c);
                                  } else {
                                    _selectCustomerFromSuggestion(context, c);
                                  }
                                },
                              ),
                            );
                          },
                        );
                      }

                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 80, color: Colors.grey.shade300),
                            SizedBox(height: 16),
                            Text(
                              context.tr('Search customer or vehicle\nto create a quotation'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 16.sp),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
