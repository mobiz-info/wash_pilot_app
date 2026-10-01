import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'invoice_create_screen.dart';

class InsuranceNewJobScreen extends StatefulWidget {
  const InsuranceNewJobScreen({super.key});

  @override
  State<InsuranceNewJobScreen> createState() => _InsuranceNewJobScreenState();
}

class _InsuranceNewJobScreenState extends State<InsuranceNewJobScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final ValueNotifier<String> _selectedCountryCodeNotifier =
      ValueNotifier(CountryConfig.phoneDialCode);
  final ValueNotifier<String> _selectedCountryIsoNotifier =
      ValueNotifier(CountryConfig.phoneIsoCode);

  // Suggestions (while typing)
  final ValueNotifier<List<dynamic>> _suggestionsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _isSearchingSuggestionsNotifier =
      ValueNotifier(false);

  // Found customer
  final ValueNotifier<Map<String, dynamic>?> _customerNotifier =
      ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingCustomerNotifier =
      ValueNotifier(false);
  final ValueNotifier<String> _notFoundMessageNotifier =
      ValueNotifier('');

  Timer? _debounce;
  String _lastSearchedText = '';

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_onMobileChanged);
  }

  @override
  void dispose() {
    _mobileController.removeListener(_onMobileChanged);
    _mobileController.dispose();
    _selectedCountryCodeNotifier.dispose();
    _selectedCountryIsoNotifier.dispose();
    _suggestionsNotifier.dispose();
    _isSearchingSuggestionsNotifier.dispose();
    _customerNotifier.dispose();
    _isLoadingCustomerNotifier.dispose();
    _notFoundMessageNotifier.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Text change listener ───────────────────────────────────────────────────
  void _onMobileChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();

    if (text.isEmpty) {
      _customerNotifier.value = null;
      _notFoundMessageNotifier.value = '';
      _suggestionsNotifier.value = [];
      _lastSearchedText = '';
      return;
    }

    // If 10 or more digits, automatically fetch the customer!
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      if (_lastSearchedText == text && _customerNotifier.value != null) {
        return;
      }
      _suggestionsNotifier.value = [];
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _searchCustomer(autoFetch: true);
      });
      return;
    }

    // Under 10 digits: clear customer card & show suggestions if >= 3 chars
    _customerNotifier.value = null;
    _notFoundMessageNotifier.value = '';

    if (text.length >= 3) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _fetchSuggestions(text);
      });
    } else {
      _suggestionsNotifier.value = [];
    }
  }

  // ── Fetch suggestions while typing (>= 3 chars) ───────────────────────────
  Future<void> _fetchSuggestions(String q) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isSearchingSuggestionsNotifier.value = true;
    try {
      final res = await ApiService.insuranceCustomerSearch(token, search: q);
      if (res['success'] == true) {
        _suggestionsNotifier.value =
            List<dynamic>.from(res['customers'] ?? []);
      } else {
        _suggestionsNotifier.value = [];
      }
    } catch (_) {
      _suggestionsNotifier.value = [];
    } finally {
      _isSearchingSuggestionsNotifier.value = false;
    }
  }

  // ── Search customer (auto-fetch or search button or suggestion tap) ────────
  Future<void> _searchCustomer({bool autoFetch = false}) async {
    final text = _mobileController.text.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    if (!autoFetch) {
      FocusScope.of(context).unfocus();
    }

    _lastSearchedText = text;
    _suggestionsNotifier.value = [];
    _isLoadingCustomerNotifier.value = true;
    _customerNotifier.value = null;
    _notFoundMessageNotifier.value = '';

    final formattedPhone = CountryConfig.formatPhoneWithCountryCode(
        text, _selectedCountryCodeNotifier.value);

    try {
      // 1. Try search with entered text
      var res = await ApiService.insuranceCustomerSearch(token, search: text);
      var list = (res['success'] == true)
          ? List<dynamic>.from(res['customers'] ?? [])
          : <dynamic>[];

      // 2. If not found and formattedPhone is different, retry with formattedPhone
      if (list.isEmpty && formattedPhone != text) {
        res = await ApiService.insuranceCustomerSearch(token,
            search: formattedPhone);
        list = (res['success'] == true)
            ? List<dynamic>.from(res['customers'] ?? [])
            : <dynamic>[];
      }

      // 3. If still not found and digits are >= 10, try clean 10-digit suffix
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (list.isEmpty && digits.length >= 10) {
        final last10 = digits.substring(digits.length - 10);
        if (last10 != text && last10 != formattedPhone) {
          res = await ApiService.insuranceCustomerSearch(token, search: last10);
          list = (res['success'] == true)
              ? List<dynamic>.from(res['customers'] ?? [])
              : <dynamic>[];
        }
      }

      if (list.isNotEmpty) {
        final customer = list.first as Map<String, dynamic>;
        _customerNotifier.value = customer;
        _notFoundMessageNotifier.value = '';
      } else {
        _customerNotifier.value = null;
        _notFoundMessageNotifier.value = formattedPhone;
      }
    } catch (_) {
      _customerNotifier.value = null;
      _notFoundMessageNotifier.value = formattedPhone;
    } finally {
      _isLoadingCustomerNotifier.value = false;
    }
  }

  // ── Navigate to Insurance Invoice Create Page ─────────────────────────────
  void _navigateToInsuranceInvoice(Map<String, dynamic> customer) {
    final vehicles = List<dynamic>.from(customer['vehicles'] ?? []);
    final vehicle = vehicles.isNotEmpty
        ? Map<String, dynamic>.from(vehicles.first as Map)
        : <String, dynamic>{
            'id': '',
            'no': 'Non-Motor',
            'vehicle_number': 'Non-Motor',
            'type': 'Insurance',
            'vehicle_type': 'General',
            'wheel_type': 'normal_wheel',
          };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceCreateScreen(
          customer: customer,
          vehicle: vehicle,
          isInsurance: true,
        ),
      ),
    );
  }

  // ── Select customer from suggestion dropdown → Go to invoice page ─────────
  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _suggestionsNotifier.value = [];
    FocusScope.of(context).unfocus();

    final rawPhone = suggestion['phone']?.toString() ?? '';
    String strippedPhone = rawPhone;
    final allCountries = CountryConfig.all
      ..sort((a, b) =>
          b.phoneDialCode.length.compareTo(a.phoneDialCode.length));
    for (final country in allCountries) {
      final cleanCode = country.phoneDialCode.replaceAll('+', '');
      if (rawPhone.startsWith(cleanCode) &&
          rawPhone.length > cleanCode.length) {
        _selectedCountryCodeNotifier.value = country.phoneDialCode;
        _selectedCountryIsoNotifier.value = country.phoneIsoCode;
        strippedPhone = rawPhone.substring(cleanCode.length);
        break;
      }
    }

    _lastSearchedText = strippedPhone;
    _mobileController.text = strippedPhone;
    _customerNotifier.value = suggestion;
    _notFoundMessageNotifier.value = '';

    // Directly navigate to insurance invoice creation page on selection
    _navigateToInsuranceInvoice(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Insurance — New Job',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Phone input row ────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _selectedCountryIsoNotifier,
                    builder: (ctx, iso, _) => IntlPhoneField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      initialCountryCode: iso,
                      dropdownTextStyle: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      disableLengthCheck: true,
                      onCountryChanged: (country) {
                        _selectedCountryCodeNotifier.value =
                            '+${country.dialCode}';
                        _selectedCountryIsoNotifier.value = country.code;
                      },
                      onSubmitted: (_) => _searchCustomer(),
                      decoration: InputDecoration(
                        hintText: 'Enter Mobile Number',
                        hintStyle:
                            GoogleFonts.inter(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF000080)),
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _mobileController,
                          builder: (_, val, __) {
                            if (val.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              color: Colors.grey.shade400,
                              onPressed: () {
                                _mobileController.clear();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Search button
                InkWell(
                  onTap: () => _searchCustomer(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 54.h,
                    width: 54.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(Icons.search, color: Colors.white, size: 24.r),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),

            // ── Suggestions dropdown (shown while typing) ───────────────────
            ValueListenableBuilder<bool>(
              valueListenable: _isSearchingSuggestionsNotifier,
              builder: (_, searching, __) {
                if (searching) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.w, top: 4.h),
                      child: SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child:
                            const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _suggestionsNotifier,
                  builder: (_, suggestions, __) {
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return Container(
                      constraints: BoxConstraints(maxHeight: 220.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final s =
                              suggestions[i] as Map<String, dynamic>;
                          return InkWell(
                            onTap: () => _selectSuggestion(s),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 12.h),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18.r,
                                    backgroundColor:
                                        const Color(0xFF000080)
                                            .withValues(alpha: 0.08),
                                    child: Icon(Icons.person,
                                        color: const Color(0xFF000080),
                                        size: 18.r),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s['name'] ?? '',
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.sp,
                                                color: const Color(
                                                    0xFF1E293B))),
                                        SizedBox(height: 2.h),
                                        Text(s['phone'] ?? '',
                                            style: GoogleFonts.inter(
                                                fontSize: 12.sp,
                                                color: Colors
                                                    .grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF000080)
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Select',
                                            style: GoogleFonts.inter(
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    const Color(0xFF000080))),
                                        SizedBox(width: 2.w),
                                        Icon(Icons.arrow_forward_ios,
                                            size: 10.r,
                                            color: const Color(0xFF000080)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),

            SizedBox(height: 16.h),

            // ── Main content area ──────────────────────────────────────────
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingCustomerNotifier,
                builder: (_, loading, __) {
                  if (loading) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  return ValueListenableBuilder<Map<String, dynamic>?>(
                    valueListenable: _customerNotifier,
                    builder: (_, customer, __) {
                      // ── Customer found → Show card + Proceed Button (NO vehicle listing)
                      if (customer != null) {
                        return _CustomerFoundView(
                          customer: customer,
                          onProceed: () =>
                              _navigateToInsuranceInvoice(customer),
                        );
                      }

                      // ── Not found ──────────────────────────────────────
                      return ValueListenableBuilder<String>(
                        valueListenable: _notFoundMessageNotifier,
                        builder: (_, notFoundPhone, __) {
                          if (notFoundPhone.isNotEmpty) {
                            return _NotFoundSection(
                              phone: notFoundPhone,
                              onAddCustomer: () async {
                                final rawMobile =
                                    _mobileController.text.trim();
                                final formattedMobile =
                                    CountryConfig.formatPhoneWithCountryCode(
                                        rawMobile,
                                        _selectedCountryCodeNotifier.value);
                                final created = await Navigator.push<
                                    Map<String, dynamic>?>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddCustomerScreen(
                                      phoneNumber: formattedMobile,
                                      initialCountryIso:
                                          _selectedCountryIsoNotifier.value,
                                      initialDialCode:
                                          _selectedCountryCodeNotifier.value,
                                    ),
                                  ),
                                );
                                if (created != null) {
                                  _notFoundMessageNotifier.value = '';
                                  _customerNotifier.value = created;
                                  _navigateToInsuranceInvoice(created);
                                } else {
                                  _searchCustomer();
                                }
                              },
                            );
                          }

                          // ── Empty state ────────────────────────────────
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 72.r,
                                    color: Colors.grey.shade300),
                                SizedBox(height: 16.h),
                                Text('Enter Customer Number',
                                    style: GoogleFonts.inter(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade600)),
                                SizedBox(height: 6.h),
                                Text(
                                    'Enter phone number to automatically select customer and create insurance invoice',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        color: Colors.grey.shade400)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer found view: Shows customer card + direct proceed button (NO vehicles)
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerFoundView extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onProceed;

  const _CustomerFoundView({
    required this.customer,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final category =
        (customer['customer_category'] ?? 'motor').toString().toLowerCase();
    final isNonMotor = category == 'non_motor';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Customer Card ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor:
                          const Color(0xFF000080).withValues(alpha: 0.1),
                      child: Icon(Icons.person,
                          color: const Color(0xFF000080), size: 28.r),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  customer['name'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B)),
                                ),
                              ),
                              // Category Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: isNonMotor
                                      ? Colors.purple.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: isNonMotor
                                        ? Colors.purple.shade200
                                        : Colors.blue.shade200,
                                  ),
                                ),
                                child: Text(
                                  isNonMotor ? 'Non-Motor' : 'Motor',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isNonMotor
                                        ? Colors.purple.shade800
                                        : const Color(0xFF000080),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined,
                                  size: 14.r, color: Colors.grey.shade600),
                              SizedBox(width: 4.w),
                              Text(
                                customer['phone'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          if ((customer['type'] ??
                                  customer['customer_type'] ??
                                  '')
                              .toString()
                              .isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              'Type: ${customer['type'] ?? customer['customer_type']}',
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF000080),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                          if ((customer['branch'] ??
                                  customer['branch_name'] ??
                                  '')
                              .toString()
                              .isNotEmpty) ...[
                            SizedBox(height: 3.h),
                            Text(
                              'Branch: ${customer['branch'] ?? customer['branch_name']}',
                              style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Aadhaar & DOB for Non-Motor
                if (isNonMotor) ...[
                  Divider(height: 24.h, color: Colors.grey.shade200),
                  Row(
                    children: [
                      if ((customer['aadhaar_number'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Aadhaar Number',
                                  style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade500)),
                              SizedBox(height: 2.h),
                              Text(customer['aadhaar_number'].toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      if ((customer['date_of_birth'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date of Birth',
                                  style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade500)),
                              SizedBox(height: 2.h),
                              Text(customer['date_of_birth'].toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // ── Proceed Button ───────────────────────────────────────────────
          ElevatedButton(
            onPressed: onProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 20.r),
                SizedBox(width: 8.w),
                Text(
                  'Proceed to Insurance Invoice',
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.arrow_forward, size: 18.r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not found section
// ─────────────────────────────────────────────────────────────────────────────
class _NotFoundSection extends StatelessWidget {
  final String phone;
  final VoidCallback onAddCustomer;

  const _NotFoundSection({required this.phone, required this.onAddCustomer});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_search_outlined,
            size: 72.r, color: Colors.grey.shade300),
        SizedBox(height: 16.h),
        Text('Customer Not Found',
            style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700)),
        SizedBox(height: 6.h),
        Text('No customer found for $phone',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13.sp, color: Colors.grey.shade500)),
        SizedBox(height: 24.h),
        ElevatedButton.icon(
          onPressed: onAddCustomer,
          icon: Icon(Icons.person_add_outlined, size: 18.r),
          label: Text('Add New Customer',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 14.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000080),
            foregroundColor: Colors.white,
            minimumSize: Size(220.w, 50.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r)),
          ),
        ),
      ],
    );
  }
}
