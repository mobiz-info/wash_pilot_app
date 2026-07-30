import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';
import 'add_scheme_screen.dart';

class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return CountryConfig.currencySymbol;
    }
  }

  final _loading = ValueNotifier<bool>(true);
  final _error = ValueNotifier<String>('');
  final _schemes = ValueNotifier<List<dynamic>>([]);

  @override
  void initState() {
    super.initState();
    _fetchSchemes();
  }

  @override
  void dispose() {
    _loading.dispose();
    _error.dispose();
    _schemes.dispose();
    super.dispose();
  }

  Future<void> _fetchSchemes() async {
    _loading.value = true;
    _error.value = '';

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      _error.value = 'Not authenticated';
      _loading.value = false;
      return;
    }

    try {
      final res = await ApiService.getBranchSchemes(token);
      if (!mounted) return;
      if (res['success'] == true) {
        _schemes.value = res['schemes'] ?? [];
      } else {
        _error.value = res['message'] ?? 'Failed to load schemes';
      }
      _loading.value = false;
    } catch (e) {
      if (!mounted) return;
      _error.value = 'Network error: $e';
      _loading.value = false;
    }
  }

  Widget _chip(
    IconData icon,
    String label, {
    Color color = const Color(0xFF64748B),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _schemeCard(Map<String, dynamic> scheme) {
    final name = scheme['name']?.toString() ?? '';
    final type = scheme['scheme_type']?.toString() ?? '';
    final desc = scheme['description']?.toString() ?? '';
    final vehicles = scheme['vehicle_types']?.toString() ?? '';
    final services = scheme['services']?.toString() ?? '';

    // Type specific details
    String highlightText = '';
    IconData highlightIcon = Icons.star;
    Color highlightColor = const Color(0xFF000080);

    if (type.toLowerCase().contains('quantity')) {
      final paid = scheme['paid_visits']?.toString() ?? '0';
      final free = scheme['free_visits']?.toString() ?? '0';
      highlightText = 'Buy $paid, Get $free Free';
      highlightIcon = Icons.local_car_wash;
      highlightColor = Colors.green.shade700;
    } else if (type.toLowerCase().contains('discount')) {
      final pct = scheme['discount_percentage']?.toString() ?? '0';
      highlightText = '$pct% Discount';
      highlightIcon = Icons.percent;
      highlightColor = Colors.orange.shade700;
    } else if (type.toLowerCase().contains('voucher')) {
      final amt = scheme['voucher_amount']?.toString() ?? '0';
      highlightText = '$currencySymbol$amt Voucher';
      highlightIcon = Icons.card_giftcard;
      highlightColor = Colors.purple.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: highlightColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(highlightIcon, size: 14, color: highlightColor),
                      const SizedBox(width: 4),
                      Text(
                        highlightText,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: highlightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  Icons.category_outlined,
                  type,
                  color: const Color(0xFF000080),
                ),
                _chip(Icons.directions_car_outlined, vehicles),
                _chip(Icons.build_outlined, services),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompany = context.watch<AuthProvider>().isCompanyAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        title: Text(
          isCompany ? 'Schemes' : 'Available Schemes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(onPressed: _fetchSchemes, icon: const Icon(Icons.refresh)),
          if (isCompany)
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSchemeScreen()),
                );
                if (result == true) _fetchSchemes();
              },
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _loading,
        builder: (context, loading, _) => ValueListenableBuilder<String>(
          valueListenable: _error,
          builder: (context, error, _) => ValueListenableBuilder<List<dynamic>>(
            valueListenable: _schemes,
            builder: (context, schemes, _) => _buildListBody(loading, error, schemes),
          ),
        ),
      ),
    );
  }

  Widget _buildListBody(bool loading, String error, List<dynamic> schemes) {
    return loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF000080)))
        : error.isNotEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _fetchSchemes, child: Text(context.tr('Retry'))),
              ],
            ),
          )
        : schemes.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_outlined, size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  context.tr('No schemes available'),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchSchemes,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: schemes.length,
              itemBuilder: (context, index) =>
                  _schemeCard(Map<String, dynamic>.from(schemes[index] as Map)),
            ),
          );
  }
}
