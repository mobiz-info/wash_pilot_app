import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import 'vehicle_service_history_screen.dart';

class NewJobScreen extends StatelessWidget {
  NewJobScreen({super.key});

  final TextEditingController _mobileController = TextEditingController();
  final ValueNotifier<String> _selectedCountryCodeNotifier = ValueNotifier(CountryConfig.phoneDialCode);
  final ValueNotifier<String> _selectedCountryIsoNotifier = ValueNotifier(CountryConfig.phoneIsoCode);
  final ValueNotifier<String> _searchTypeNotifier = ValueNotifier('number');
  final ValueNotifier<List<dynamic>> _customerSuggestionsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isSearchingSuggestionsNotifier = ValueNotifier(false);

  final ValueNotifier<List<dynamic>> _branchesNotifier = ValueNotifier([]);
  final ValueNotifier<String?> _selectedBranchIdNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingBranchesNotifier = ValueNotifier(false);

  Timer? _debounce;

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
    } catch (e) {
      _customerSuggestionsNotifier.value = [];
    } finally {
      _isSearchingSuggestionsNotifier.value = false;
    }
  }

  void _selectCustomerFromSuggestion(BuildContext context, Map<String, dynamic> suggestion) {
    _customerSuggestionsNotifier.value = [];
    final rawPhone = suggestion['phone']?.toString() ?? '';
    if (rawPhone.isEmpty) return;

    // Try to match any known dial code from CountryConfig
    String strippedPhone = rawPhone;
    String phoneCode = _selectedCountryCodeNotifier.value; // keep current if no match
    String countryIso = _selectedCountryIsoNotifier.value;

    // Sort all country settings by dial-code length descending (match longest prefix first)
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
        title: Text(context.tr('New Job'), style: TextStyle(fontWeight: FontWeight.w600)),
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

            // Search Section
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
                          // Customer Details Card
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
                                      if (data['branch'] != null && data['branch'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${context.tr("Branch")}: ${data['branch']}',
                                          style: TextStyle(
                                            color: Color(0xFF000080),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Customer Vehicles'),
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showAddVehicleDialog(context, data),
                                icon: Icon(Icons.add_circle_outline, size: 16),
                                label: Text(
                                  context.tr('Add Vehicle'),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF000080).withValues(alpha: 0.08),
                                  foregroundColor: Color(0xFF000080),
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                  padding: EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Color(0xFF000080).withValues(alpha: 0.15),
                                      width: 1.7,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF000080).withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: Offset(0, 4),
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
                                                  fontSize: 19.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF000080),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_circle_right, size: 18, color: Color(0xFF000080)),
                                            ],
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Color(0xFF000080).withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Color(0xFF000080).withValues(alpha: 0.15),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              (v['vehicle_type'] != null && v['vehicle_type'].toString().isNotEmpty)
                                                  ? "${v['vehicle_type']} - ${v['type']}"
                                                  : v['type'],
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF000080),
                                                fontSize: 11.sp,
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
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () => _navigateToVehicleHistory(context, v),
                                            icon: Icon(Icons.history, size: 14),
                                            label: Text(
                                              context.tr('History'),
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF000080).withValues(alpha: 0.08),
                                              foregroundColor: Color(0xFF000080),
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: const BorderSide(color: Color(0xFF000080), width: 1),
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
                                        children: [
                                          _msgButton(
                                            context,
                                            label: context.tr('Welcome'),
                                            icon: Icons.chat_bubble_outline,
                                            color: Colors.blue.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              context,
                                              type: 'welcome',
                                              customer: data,
                                              vehicle: v,
                                            ),
                                          ),
                                          _msgButton(
                                            context,
                                            label: context.tr('Ready Alert'),
                                            icon: Icons.notifications_none,
                                            color: Colors.orange.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              context,
                                              type: 'ready',
                                              customer: data,
                                              vehicle: v,
                                            ),
                                          ),
                                          _msgButton(
                                            context,
                                            label: context.tr('Thank You'),
                                            icon: Icons.favorite_border,
                                            color: Colors.green.shade700,
                                            onPressed: () => _sendGenericMessage(
                                              context,
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

                  return ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _customerSuggestionsNotifier,
                    builder: (context, customerSuggestions, child) {
                      if (customerSuggestions.isNotEmpty) {
                        return _buildCustomerSuggestionsList(context, customerSuggestions);
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: _isSearchingSuggestionsNotifier,
                        builder: (context, isSearchingSuggestions, child) {
                          if (isSearchingSuggestions) {
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
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16.sp),
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
      ),
    );
  }

  Widget _buildCustomerSuggestionsList(BuildContext context, List<dynamic> customerSuggestions) {
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
            : '${c['phone']} · ${c['customer_type']}${(c['branch_name'] != null && c['branch_name'].toString().isNotEmpty) ? ' · ${c['branch_name']}' : ''}';

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              if (isVehicleSuggestion) {
                _selectCustomerFromVehicleSuggestion(context, c);
              } else {
                _selectCustomerFromSuggestion(context, c);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFF000080).withValues(alpha: 0.1),
                    child: Icon(
                      isVehicleSuggestion ? Icons.directions_car : Icons.person,
                      color: Color(0xFF000080),
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
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
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

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Vehicle added successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      context.read<CustomerProvider>().searchCustomer(
        customerData['phone'],
        token,
      );
    }
  }

  void _navigateToVehicleHistory(BuildContext context, Map<String, dynamic> vehicle) {
    final vehicleId = vehicle['id']?.toString() ?? '';
    final vehicleNo = vehicle['no']?.toString() ?? vehicle['number']?.toString() ?? '';

    if (vehicleId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleServiceHistoryScreen(
          vehicleId: vehicleId,
          vehicleNumber: vehicleNo,
        ),
      ),
    );
  }

  Widget _msgButton(
    BuildContext context, {
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
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                      fontSize: 10.sp,
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

  Future<void> _sendGenericMessage(
    BuildContext context, {
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

      if (!context.mounted) return;
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
        final String branchName = context.read<AuthProvider>().branchName ?? '';
        final String effectiveBranch = (branchName.isNotEmpty && branchName != 'Our') ? branchName : 'our branch';

        String messageText = (res['message_text'] != null && res['message_text'].toString().isNotEmpty)
            ? res['message_text'].toString()
            : '';

        if (messageText.isEmpty) {
          if (type == 'welcome') {
            messageText = "Hi $customerName Welcome to Our $effectiveBranch.Your vehicle $vehicleNumber has arrived safely and is in expert hands.We will keep you posted!";
          } else if (type == 'ready') {
            messageText = "Hi $customerName Great news! Your vehicle $vehicleNumber is ready for pickup. Please collect at your earliest convenience.\n$effectiveBranch Support team.";
          } else {
            messageText = "Dear $customerName 🙏 Thank you for trusting us with your vehicle $vehicleNumber. We hope you had a great experience. Looking forward to seeing you again!\n$effectiveBranch support team.";
          }
        }

        final String cleanedPhone = CountryConfig.formatPhoneForWhatsapp(phone);

        final whatsappUrl = Uri.parse(
          "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(messageText)}"
        );

        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Error sending message')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _AddVehicleDialog extends StatelessWidget {
  final Map<String, dynamic> customerData;
  final String token;

  _AddVehicleDialog({
    required this.customerData,
    required this.token,
  });

  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isSavingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  final ValueNotifier<Map<String, dynamic>?> _fullCustomerDataNotifier = ValueNotifier(null);

  final ValueNotifier<List<dynamic>> _vehicleTypesNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _vehicleTypeModelsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _makesNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _brandModelsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _colorsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _emissionStandardsNotifier = ValueNotifier([]);

  final ValueNotifier<Map<String, dynamic>?> _selectedTypeNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _selectedSegmentNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _selectedMakeNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _selectedBrandNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _selectedColorNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> _selectedEmissionNotifier = ValueNotifier(null);
  final ValueNotifier<String> _selectedWheelTypeNotifier = ValueNotifier('normal_wheel');

  final TextEditingController _numberController = TextEditingController();

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getCustomer(customerData['id'], token),
        ApiService.getFormData(token),
      ]);

      final customerRes = results[0];
      final formDataRes = results[1];

      if (customerRes['success'] == true && formDataRes['success'] == true) {
        final vehicleTypes = formDataRes['vehicle_types'] as List<dynamic>? ?? [];
        _vehicleTypesNotifier.value = vehicleTypes;
        _vehicleTypeModelsNotifier.value = formDataRes['vehicle_type_models'] as List<dynamic>?
            ?? formDataRes['vehicle_models'] as List<dynamic>? ?? [];
        _makesNotifier.value = formDataRes['makes'] as List<dynamic>? ?? [];
        _brandModelsNotifier.value = formDataRes['brand_models'] as List<dynamic>? ?? [];
        _colorsNotifier.value = formDataRes['colors'] as List<dynamic>? ?? [];
        _emissionStandardsNotifier.value = formDataRes['emission_standards'] as List<dynamic>? ?? [];

        _fullCustomerDataNotifier.value = customerRes['customer'];
        if (vehicleTypes.isNotEmpty) {
          _selectedTypeNotifier.value = vehicleTypes.first;
        }
        _isLoadingNotifier.value = false;
      } else {
        _errorMessageNotifier.value = 'Failed to load details or options';
        _isLoadingNotifier.value = false;
      }
    } catch (e) {
      _errorMessageNotifier.value = e.toString();
      _isLoadingNotifier.value = false;
    }
  }

  List<dynamic> _segmentsForType(String? vehicleTypeId) {
    if (vehicleTypeId == null) return [];
    return _vehicleTypeModelsNotifier.value.where((m) => m['vehicle_type_id'] == vehicleTypeId).toList();
  }

  List<dynamic> _makesForTypeAndSegment(String? vehicleTypeId, String? segmentId) {
    Iterable<dynamic> list = _brandModelsNotifier.value;
    if (segmentId != null && segmentId.isNotEmpty) {
      list = list.where((b) => b['vehicle_type_model_id']?.toString() == segmentId.toString());
    } else if (vehicleTypeId != null && vehicleTypeId.isNotEmpty) {
      final validSegmentIds = _vehicleTypeModelsNotifier.value
          .where((s) => s['vehicle_type_id']?.toString() == vehicleTypeId.toString())
          .map((s) => s['id']?.toString())
          .toSet();
      list = list.where((b) => validSegmentIds.contains(b['vehicle_type_model_id']?.toString()));
    } else {
      return _makesNotifier.value;
    }
    final makeIds = list
        .map((b) => b['make_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet();
    return _makesNotifier.value.where((m) => makeIds.contains(m['id']?.toString())).toList();
  }

  List<dynamic> _brandModelsForSegmentAndMake(String? segmentId, String? makeId) {
    Iterable<dynamic> list = _brandModelsNotifier.value;
    if (segmentId != null && segmentId.isNotEmpty) {
      list = list.where((b) => b['vehicle_type_model_id']?.toString() == segmentId);
    }
    if (makeId != null && makeId.isNotEmpty) {
      list = list.where((b) => b['make_id']?.toString() == makeId);
    }
    return list.toList();
  }

  Future<void> _save(BuildContext context) async {
    final number = _numberController.text.trim().toUpperCase();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter vehicle number'))),
      );
      return;
    }
    if (_selectedSegmentNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select a vehicle type and segment'))),
      );
      return;
    }

    _isSavingNotifier.value = true;

    try {
      final vehicleData = <String, dynamic>{
        'vehicle_number': number,
        'vehicle_model_id': _selectedSegmentNotifier.value!['id'],
        'wheel_type': _selectedWheelTypeNotifier.value,
      };
      if (_selectedMakeNotifier.value != null) vehicleData['make_id'] = _selectedMakeNotifier.value!['id'];
      if (_selectedBrandNotifier.value != null) vehicleData['brand_model_id'] = _selectedBrandNotifier.value!['id'];
      if (_selectedColorNotifier.value != null) vehicleData['color_id'] = _selectedColorNotifier.value!['id'];
      if (_selectedEmissionNotifier.value != null) vehicleData['emission_standard_id'] = _selectedEmissionNotifier.value!['id'];

      final response = await ApiService.editCustomer({
        'customer_id': _fullCustomerDataNotifier.value!['id'],
        'name': _fullCustomerDataNotifier.value!['name'],
        'phone': _fullCustomerDataNotifier.value!['phone'],
        'whatsapp_number': _fullCustomerDataNotifier.value!['whatsapp_number'] ?? '',
        'email': _fullCustomerDataNotifier.value!['email'] ?? '',
        'address': _fullCustomerDataNotifier.value!['address'] ?? '',
        'customer_type_id': _fullCustomerDataNotifier.value!['customer_type_id'],
        'new_vehicles': [vehicleData],
      }, token);

      if (response['success'] == true) {
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _errorMessageNotifier.value = response['message'] ?? 'Failed to add vehicle';
        _isSavingNotifier.value = false;
      }
    } catch (e) {
      _errorMessageNotifier.value = e.toString();
      _isSavingNotifier.value = false;
    }
  }

  Widget _buildSearchableDropdown<T>(
    BuildContext context, {
    required String label,
    required String title,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?)? onChanged,
    String? hint,
  }) {
    String displayLabel = hint ?? context.tr('Select $title...');
    bool hasValue = false;
    if (value != null && items.isNotEmpty) {
      if (value is Map && value.containsKey('id')) {
        final valId = value['id']?.toString();
        for (final item in items) {
          if (item is Map && item['id']?.toString() == valId) {
            displayLabel = labelBuilder(item);
            hasValue = true;
            break;
          }
        }
      } else {
        displayLabel = labelBuilder(value);
        hasValue = true;
      }
    } else if (value != null) {
      displayLabel = labelBuilder(value);
      hasValue = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        InkWell(
          onTap: (items.isEmpty || onChanged == null)
              ? null
              : () => _showSearchableModal<T>(context, title, items, labelBuilder, onChanged),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: hasValue ? Colors.black87 : Colors.grey.shade500,
                      fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchableModal<T>(
    BuildContext context,
    String title,
    List<T> items,
    String Function(T) labelBuilder,
    void Function(T?) onChanged,
  ) {
    final searchNotifier = ValueNotifier<String>('');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        padding: EdgeInsets.only(
          top: 20, left: 20, right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('Select $title'), style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: const Color(0xFF000080))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('Search $title...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => searchNotifier.value = v.toLowerCase().trim(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: searchNotifier,
                builder: (_, query, __) {
                  final filtered = items.where((item) => labelBuilder(item).toLowerCase().contains(query)).toList();
                  if (filtered.isEmpty) {
                    return Center(child: Text(context.tr('No results found'), style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return ListTile(
                        title: Text(labelBuilder(item), style: TextStyle(fontWeight: FontWeight.w500)),
                        onTap: () {
                          onChanged(item);
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
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    void Function(T?)? onChanged,
    String? hint,
  }) {
    T? matchedValue;
    if (value != null && items.isNotEmpty) {
      if (value is Map && value.containsKey('id')) {
        final valId = value['id']?.toString();
        for (final item in items) {
          if (item is Map && item['id']?.toString() == valId) {
            matchedValue = item;
            break;
          }
        }
      } else {
        for (final item in items) {
          if (item == value) {
            matchedValue = item;
            break;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              menuMaxHeight: 300,
              value: matchedValue,
              hint: Text(hint ?? 'Select...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp)),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(labelBuilder(item), style: TextStyle(fontSize: 14.sp)),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.tr('Add Vehicle'),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080)),
      ),
      content: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingNotifier,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _errorMessageNotifier,
                  builder: (context, errorMsg, child) {
                    if (errorMsg.isNotEmpty) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          errorMsg,
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Vehicle Number
                Text(context.tr('Vehicle Number *'), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                SizedBox(height: 6),
                TextField(
                  controller: _numberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: context.tr('e.g. KA01AA1111'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Vehicle Type
                ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _vehicleTypesNotifier,
                  builder: (context, vehicleTypes, child) {
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedTypeNotifier,
                      builder: (context, selectedType, child) {
                        return _buildDropdown<dynamic>(
                          label: context.tr('Vehicle Type *'),
                          value: selectedType,
                          items: vehicleTypes,
                          labelBuilder: (item) => context.tr(item['name'] ?? ''),
                          onChanged: (val) {
                            _selectedTypeNotifier.value = val;
                            final validMakes = _makesForTypeAndSegment(val?['id']?.toString(), _selectedSegmentNotifier.value?['id']?.toString());
                            if (_selectedMakeNotifier.value != null && !validMakes.any((m) => m['id']?.toString() == _selectedMakeNotifier.value?['id']?.toString())) {
                              _selectedMakeNotifier.value = null;
                              _selectedBrandNotifier.value = null;
                            }
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 2. Make (Searchable Dropdown)
                ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: _selectedTypeNotifier,
                  builder: (context, selectedType, child) {
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedSegmentNotifier,
                      builder: (context, selectedSegment, child) {
                        final makes = _makesForTypeAndSegment(
                          selectedType?['id']?.toString(),
                          selectedSegment?['id']?.toString(),
                        );
                        return ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: _selectedMakeNotifier,
                          builder: (context, selectedMake, child) {
                            return _buildSearchableDropdown<dynamic>(
                              context,
                              label: context.tr('Vehicle Make'),
                              title: context.tr('Make'),
                              value: selectedMake,
                              items: makes,
                              labelBuilder: (item) => item['name'] ?? '',
                              hint: makes.isEmpty ? context.tr('No makes available') : context.tr('Select Make (e.g. Maruti, Hyundai)...'),
                              onChanged: makes.isEmpty ? null : (val) {
                                _selectedMakeNotifier.value = val;
                                _selectedBrandNotifier.value = null;
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 3. Brand / Model (Searchable Dropdown)
                ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: _selectedSegmentNotifier,
                  builder: (context, selectedSegment, child) {
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedMakeNotifier,
                      builder: (context, selectedMake, child) {
                        final brands = _brandModelsForSegmentAndMake(
                          selectedSegment?['id']?.toString(),
                          selectedMake?['id']?.toString(),
                        );
                        return ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: _selectedBrandNotifier,
                          builder: (context, selectedBrand, child) {
                            return _buildSearchableDropdown<dynamic>(
                              context,
                              label: context.tr('Brand / Model'),
                              title: context.tr('Brand Model'),
                              value: selectedBrand,
                              items: brands,
                              labelBuilder: (item) => item['name'] ?? '',
                              hint: brands.isEmpty ? context.tr('No models available') : context.tr('Select Model (e.g. Swift, Creta)...'),
                              onChanged: brands.isEmpty ? null : (val) {
                                _selectedBrandNotifier.value = val;
                                if (val != null) {
                                  final makeId = val['make_id']?.toString();
                                  if (makeId != null && makeId.isNotEmpty) {
                                    final matchedMake = _makesNotifier.value.firstWhere(
                                      (mk) => mk['id']?.toString() == makeId,
                                      orElse: () => null,
                                    );
                                    if (matchedMake != null) _selectedMakeNotifier.value = matchedMake;
                                  }

                                  final vtmId = val['vehicle_type_model_id']?.toString();
                                  if (vtmId != null && vtmId.isNotEmpty) {
                                    final matchedSegment = _vehicleTypeModelsNotifier.value.firstWhere(
                                      (vm) => vm['id']?.toString() == vtmId,
                                      orElse: () => null,
                                    );
                                    if (matchedSegment != null) {
                                      _selectedSegmentNotifier.value = matchedSegment;
                                      final vtId = matchedSegment['vehicle_type_id']?.toString();
                                      if (vtId != null && vtId.isNotEmpty) {
                                        final matchedVt = _vehicleTypesNotifier.value.firstWhere(
                                          (vt) => vt['id']?.toString() == vtId,
                                          orElse: () => null,
                                        );
                                        if (matchedVt != null) _selectedTypeNotifier.value = matchedVt;
                                      }
                                    }
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 4. Segment (Auto-populated or manually selected)
                ValueListenableBuilder<Map<String, dynamic>?>(
                  valueListenable: _selectedTypeNotifier,
                  builder: (context, selectedType, child) {
                    final segments = _segmentsForType(selectedType?['id']?.toString());
                    if (segments.isEmpty) return const SizedBox.shrink();
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedSegmentNotifier,
                      builder: (context, selectedSegment, child) {
                        return _buildDropdown<dynamic>(
                          label: context.tr('Vehicle Model (Segment) *'),
                          value: selectedSegment,
                          items: segments,
                          labelBuilder: (item) => item['name'] ?? '',
                          onChanged: (val) {
                            _selectedSegmentNotifier.value = val;
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Color selection
                ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _colorsNotifier,
                  builder: (context, colors, child) {
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedColorNotifier,
                      builder: (context, selectedColor, child) {
                        return _buildDropdown<dynamic>(
                          label: context.tr('Color'),
                          value: selectedColor,
                          items: colors,
                          labelBuilder: (item) => context.tr(item['name'] ?? ''),
                          hint: context.tr('Select Color...'),
                          onChanged: (val) {
                            _selectedColorNotifier.value = val;
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Emission Standard selection
                ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _emissionStandardsNotifier,
                  builder: (context, emissions, child) {
                    if (emissions.isEmpty) return const SizedBox.shrink();
                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: _selectedEmissionNotifier,
                      builder: (context, selectedEmission, child) {
                        return _buildDropdown<dynamic>(
                          label: context.tr('Emission Standard'),
                          value: selectedEmission,
                          items: emissions,
                          labelBuilder: (item) => item['name'] ?? '',
                          hint: context.tr('Select Emission...'),
                          onChanged: (val) {
                            _selectedEmissionNotifier.value = val;
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Wheel Type selection
                Text(
                  context.tr('Wheel Type *'),
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                SizedBox(height: 6),
                ValueListenableBuilder<String>(
                  valueListenable: _selectedWheelTypeNotifier,
                  builder: (context, selectedWheelType, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(
                              context.tr('Alloy Wheel'),
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                            ),
                            value: 'alloy_wheel',
                            groupValue: selectedWheelType,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: const Color(0xFF000080),
                            onChanged: (val) {
                              if (val != null) _selectedWheelTypeNotifier.value = val;
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text(
                              context.tr('Normal Wheel'),
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                            ),
                            value: 'normal_wheel',
                            groupValue: selectedWheelType,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: const Color(0xFF000080),
                            onChanged: (val) {
                              if (val != null) _selectedWheelTypeNotifier.value = val;
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _isLoadingNotifier,
          builder: (context, isLoading, child) {
            if (isLoading) return const SizedBox.shrink();

            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: _isSavingNotifier,
                  builder: (context, isSaving, child) {
                    return ElevatedButton(
                      onPressed: isSaving ? null : () => _save(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF000080),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving
                          ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.tr('Add')),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
