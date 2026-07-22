import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/country_config.dart';

class CountryScreen extends StatefulWidget {
  const CountryScreen({super.key});

  @override
  State<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<CountryScreen> {
  CountryCode _selected = CountryConfig.current.code;
  bool _isSaving = false;

  Future<void> _select(CountryCode code) async {
    setState(() {
      _selected = code;
      _isSaving = true;
    });
    await CountryConfig.setCountry(code);
    setState(() => _isSaving = false);

    if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final countries = CountryConfig.all;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Select Country',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Info banner ──────────────────────────────────────────────────
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selecting a country sets the default phone code and currency symbol across the entire app.',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
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
                  padding: const EdgeInsets.all(16),
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    final isSelected = country.code == _selected;

                    return GestureDetector(
                      onTap: _isSaving ? null : () => _select(country.code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF000080).withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF000080)
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isSelected ? 0.06 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Flag
                            Text(
                              country.flag,
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(width: 16),

                            // Country info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    country.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? const Color(0xFF000080)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // Phone code badge
                                      _badge(
                                        icon: Icons.phone_outlined,
                                        label: country.phoneDialCode,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 8),
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
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF000080),
                                size: 26,
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
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
