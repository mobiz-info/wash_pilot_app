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

  // Found customer (after selecting or exact match)
  final ValueNotifier<Map<String, dynamic>?> _customerNotifier =
      ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingCustomerNotifier =
      ValueNotifier(false);
  final ValueNotifier<String> _notFoundMessageNotifier =
      ValueNotifier('');

  Timer? _debounce;

  @override
  void dispose() {
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

  // ── Auto-suggest as user types ──────────────────────────────────────────
  void _onMobileChanged(BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final text = _mobileController.text.trim();

    // Clear customer whenever input changes
    _customerNotifier.value = null;
    _notFoundMessageNotifier.value = '';

    if (text.length >= 3) {
      _debounce = Timer(const Duration(milliseconds: 350), () {
        _fetchSuggestions(context, text);
      });
    } else {
      _suggestionsNotifier.value = [];
    }
  }

  Future<void> _fetchSuggestions(BuildContext context, String q) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isSearchingSuggestionsNotifier.value = true;
    try {
      // Use the insurance-specific search endpoint
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

  // ── Select from suggestion → load full customer ─────────────────────────
  void _selectSuggestion(
      BuildContext context, Map<String, dynamic> suggestion) {
    _suggestionsNotifier.value = [];
    FocusScope.of(context).unfocus();

    // Fill the phone field
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
    _mobileController.text = strippedPhone;

    // Show the customer card directly (we already have the data)
    _customerNotifier.value = suggestion;
    _notFoundMessageNotifier.value = '';
  }

  // ── Search button pressed ────────────────────────────────────────────────
  void _searchCustomer(BuildContext context) {
    FocusScope.of(context).unfocus();
    _suggestionsNotifier.value = [];
    final text = _mobileController.text.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingCustomerNotifier.value = true;
    _customerNotifier.value = null;
    _notFoundMessageNotifier.value = '';

    final formattedPhone = CountryConfig.formatPhoneWithCountryCode(
        text, _selectedCountryCodeNotifier.value);

    ApiService.insuranceCustomerSearch(token, search: text).then((res) {
      _isLoadingCustomerNotifier.value = false;
      if (res['success'] == true) {
        final list = List<dynamic>.from(res['customers'] ?? []);
        if (list.isNotEmpty) {
          _customerNotifier.value = list.first as Map<String, dynamic>;
        } else {
          _notFoundMessageNotifier.value = formattedPhone;
        }
      } else {
        _notFoundMessageNotifier.value = formattedPhone;
      }
    }).catchError((_) {
      _isLoadingCustomerNotifier.value = false;
      _notFoundMessageNotifier.value = formattedPhone;
    });
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
            ValueListenableBuilder<String>(
              valueListenable: _selectedCountryIsoNotifier,
              builder: (ctx, iso, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: IntlPhoneField(
                      key: ValueKey('ins_phone_$iso'),
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
                      onChanged: (_) => _onMobileChanged(context),
                      onSubmitted: (_) => _searchCustomer(context),
                      decoration: InputDecoration(
                        hintText: 'Enter Mobile Number',
                        hintStyle: GoogleFonts.inter(
                            color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
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
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Search button
                  InkWell(
                    onTap: () => _searchCustomer(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000080),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.search,
                          color: Colors.white, size: 24.r),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // ── Suggestions dropdown ───────────────────────────────────────
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final s =
                              suggestions[i] as Map<String, dynamic>;
                          return InkWell(
                            onTap: () => _selectSuggestion(context, s),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 12.h),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18.r,
                                    backgroundColor: const Color(0xFF000080)
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
                                  Icon(Icons.chevron_right,
                                      color: Colors.grey.shade400),
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
                      // ── Customer found ─────────────────────────────────
                      if (customer != null) {
                        return _CustomerFoundSection(
                          customer: customer,
                          onAddCustomer: () async {
                            final phone =
                                _mobileController.text.trim();
                            final created =
                                await Navigator.push<Map<String, dynamic>?>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddCustomerScreen(
                                    phoneNumber: phone),
                              ),
                            );
                            if (created != null) {
                              _customerNotifier.value = created;
                            }
                          },
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
                                final created = await Navigator.push<
                                    Map<String, dynamic>?>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddCustomerScreen(
                                        phoneNumber: _mobileController
                                            .text
                                            .trim()),
                                  ),
                                );
                                if (created != null) {
                                  _notFoundMessageNotifier.value = '';
                                  _customerNotifier.value = created;
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
                                    color: Colors.grey.shade200),
                                SizedBox(height: 16.h),
                                Text('Search for a customer',
                                    style: GoogleFonts.inter(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade500)),
                                SizedBox(height: 6.h),
                                Text(
                                    'Enter mobile number to start an\ninsurance job',
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
// Customer found section
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerFoundSection extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onAddCustomer;

  const _CustomerFoundSection({
    required this.customer,
    required this.onAddCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final vehicles = List<dynamic>.from(customer['vehicles'] ?? []);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Customer card ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor:
                      const Color(0xFF000080).withValues(alpha: 0.1),
                  child: Icon(Icons.person,
                      color: const Color(0xFF000080), size: 24.r),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer['name'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        customer['phone'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: Colors.grey.shade600),
                      ),
                      if ((customer['customer_type'] ?? '').isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Text(
                          'Type: ${customer['customer_type']}',
                          style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF000080),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ── Vehicles ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vehicles',
                  style: GoogleFonts.inter(
                      fontSize: 16.sp, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12.h),

          if (vehicles.isEmpty)
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text('No vehicles found for this customer',
                    style: GoogleFonts.inter(
                        color: Colors.grey.shade500, fontSize: 13.sp)),
              ),
            )
          else
            ...vehicles.asMap().entries.map((entry) {
              final v = entry.value as Map<String, dynamic>;
              final vehicleNo =
                  v['vehicle_number']?.toString() ?? v['no']?.toString() ?? '';
              final model = v['vehicle_model']?.toString() ??
                  v['model']?.toString() ?? '';
              final type = v['vehicle_type']?.toString() ?? '';

              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceCreateScreen(
                          customer: customer,
                          vehicle: v,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFF000080).withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF000080).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.directions_car,
                              color: const Color(0xFF000080), size: 22.r),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleNo,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16.sp,
                                    color: const Color(0xFF1E293B)),
                              ),
                              if (model.isNotEmpty || type.isNotEmpty) ...[
                                SizedBox(height: 3.h),
                                Text(
                                  [type, model]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text('New Job',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.sp)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          // ── No vehicle → still allow new job without vehicle ─────────────
          if (vehicles.isEmpty) ...[
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceCreateScreen(
                      customer: customer,
                      vehicle: const {},
                    ),
                  ),
                );
              },
              icon: Icon(Icons.shield_outlined, size: 18.r),
              label: Text('Start Insurance Job',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
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
        Text('No customer found for\n$phone',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13.sp, color: Colors.grey.shade500)),
        SizedBox(height: 24.h),
        ElevatedButton.icon(
          onPressed: onAddCustomer,
          icon: Icon(Icons.person_add_outlined, size: 18.r),
          label: Text('Add New Customer',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.sp)),
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
