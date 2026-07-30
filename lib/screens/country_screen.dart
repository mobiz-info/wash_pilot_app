import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/country_config.dart';

class CountryScreen extends StatelessWidget {
  const CountryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = ValueNotifier<CountryCode>(CountryConfig.current.code);
    final isSaving = ValueNotifier<bool>(false);

    Future<void> select(CountryCode code) async {
      selected.value = code;
      isSaving.value = true;
      await CountryConfig.setCountry(code);
      isSaving.value = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${CountryConfig.current.flag} Country set to ${CountryConfig.current.displayName}. '
              'Phone code: ${CountryConfig.current.phoneDialCode} | '
              'Currency: ${CountryConfig.current.currencySymbol}',
            ),
            backgroundColor: const Color(0xFF000080),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    final countries = CountryConfig.all;

    return ValueListenableBuilder<bool>(
      valueListenable: isSaving,
      builder: (context, saving, _) => ValueListenableBuilder<CountryCode>(
        valueListenable: selected,
        builder: (context, sel, _) => Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: Text('Select Country', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF000080),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Stack(
            children: [
              Column(
                children: [
              Container(
                width: double.infinity,
                padding: REdgeInsets.symmetric(horizontal: 18, vertical: 14),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: const Color(0xFF1D4ED8), size: 18.r),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Selecting a country sets the default phone code and currency symbol across the entire app.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5.sp,
                          color: const Color(0xFF1E40AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Country list ───────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: REdgeInsets.all(16),
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    final isSelected = country.code == sel;

                    return GestureDetector(
                      onTap: saving ? null : () => select(country.code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: REdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF000080).withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF000080)
                                : Colors.grey.shade200,
                            width: isSelected ? 2.w : 1.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Flag
                            Text(
                              country.flag,
                              style: TextStyle(fontSize: 28.sp),
                            ),
                            SizedBox(width: 16.w),

                            // Country info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    country.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFF000080)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      // Phone code badge
                                      _badge(
                                        icon: Icons.phone_outlined,
                                        label: country.phoneDialCode,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                      SizedBox(width: 8.w),
                                      // Currency badge
                                      _badge(
                                        icon: Icons.payments_outlined,
                                        label: '${country.currencySymbol} (${country.currencyCode})',
                                        color: const Color(0xFF10B981),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Check mark
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: const Color(0xFF000080),
                                size: 26.r,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Loading overlay ──────────────────────────────────────────────
              if (saving)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.r, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
