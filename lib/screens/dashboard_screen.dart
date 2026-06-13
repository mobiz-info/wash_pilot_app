import 'package:car_wash_mobile/providers/auth_provider.dart';
import 'package:car_wash_mobile/services/api_service.dart';
import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _statsLoading = true;
  int _totalJobs = 0;
  String _todayRevenue = '0';
  String _todayCollected = '0';
  String _todayExpense = '0';
  String _todayNetProfit = '0';
  String _totalOutstanding = '0';
  int _outstandingCount = 0;
  int _totalCustomers = 0;
  List<Map<String, dynamic>> _recentInvoices = [];

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _statsLoading = true);
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.getDashboardStats(token);
      if (mounted && res['success'] == true) {
        setState(() {
          _totalJobs = res['today_jobs'] ?? 0;
          _todayRevenue = res['today_revenue'] ?? '0';
          _todayCollected = res['today_collected'] ?? '0';
          _todayExpense = res['today_expense'] ?? '0';
          _todayNetProfit = res['today_net_profit'] ?? '0';
          _totalOutstanding = res['total_outstanding'] ?? '0';
          _outstandingCount = res['outstanding_count'] ?? 0;
          _totalCustomers = res['total_customers'] ?? 0;
          _recentInvoices = List<Map<String, dynamic>>.from(
            res['recent_invoices'] ?? [],
          ).take(3).toList();
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  String _fmt(String raw) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    try {
      final v = double.parse(raw);
      if (v >= 1000000) return '$currencySymbol${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return '$currencySymbol${(v / 1000).toStringAsFixed(1)}K';
      return '$currencySymbol${v.toStringAsFixed(0)}';
    } catch (_) {
      return '$currencySymbol$raw';
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Dashboard'),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Open drawer
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 27,horizontal: 20),
        child: Column(
          children: [
            // ── Today's Stats ───────────────────────────────────────────
            buildSectionTitle(context.tr("Today's Summary"), Icons.today_outlined),
            const SizedBox(height: 10),
            _buildTodayStats(),
            const SizedBox(height: 20),
        
            // ── Totals Row ──────────────────────────────────────────────
            buildSectionTitle(context.tr('Overview'), Icons.analytics_outlined),
            const SizedBox(height: 10),
            _buildOverviewRow(),
            const SizedBox(height: 20),
        
            // ── Recent Invoices ─────────────────────────────────────────
            // if (_recentInvoices.isNotEmpty) ...[
            //   buildSectionTitle(
            //     'Today\'s Recent Jobs',
            //     Icons.receipt_long_outlined,
            //   ),
            //   const SizedBox(height: 10),
            //   _buildRecentInvoices(),
            //   const SizedBox(height: 20),
            // ],
          ],
        ),
      ),
    );
  }

  

  // ─── Today Stats (3 cards) ───────────────────────────────────────────────
  Widget _buildTodayStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Revenue',
                _statsLoading ? '...' : _todayRevenue,
                Icons.trending_up,
                const Color(0xFF3B82F6),
                const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                'Collected',
                _statsLoading ? '...' : _todayCollected,
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
                const Color(0xFFF0FDF4),
              ),
            ),
            const SizedBox(width: 8),
            
          ],
        ),
        const SizedBox(height: 10),
       
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Expense',
                _statsLoading ? '...' : _todayExpense,
                Icons.trending_down,
                const Color(0xFFEF4444),
                const Color(0xFFFFF1F2),
              ),
            ),
            const SizedBox(width: 10),
            
           
          ],
        ),
         const SizedBox(height: 10),
         Row(
          children: [
            Expanded(
              child: _statCard(
                'Net Profit',
                _statsLoading ? '...' : _todayNetProfit,
                Icons.account_balance,
                const Color(0xFF0F766E),
                const Color(0xFFE6F4F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Jobs',
                _statsLoading ? '...' : '$_totalJobs',
                Icons.work_outline,
                const Color(0xFF8B5CF6),
                const Color(0xFFF5F3FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ─── Overview Row (outstanding + customers) ──────────────────────────────
  Widget _buildOverviewRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Outstanding',
            _statsLoading ? '...' : _totalOutstanding,
            Icons.warning_amber_outlined,
            const Color(0xFFEF4444),
            const Color(0xFFFFF1F2),
            subtitle: _statsLoading ? '' : '$_outstandingCount ${context.tr('invoices')}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            'Customers',
            _statsLoading ? '...' : '$_totalCustomers',
            Icons.people_outline,
            const Color(0xFFF59E0B),
            const Color(0xFFFFFBEB),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentInvoices() {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _recentInvoices.asMap().entries.map((e) {
          final inv = e.value;
          final isLast = e.key == _recentInvoices.length - 1;
          final total = inv['total'] ?? '0';
          final collected = inv['collected'] ?? '0';
          final outstanding =
              (double.tryParse(total) ?? 0) - (double.tryParse(collected) ?? 0);

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                title: Text(
                  inv['customer'] ?? '',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1e293b),
                  ),
                ),
                subtitle: Text(
                  context.tr('${inv['invoice_number'] ?? ''} · ${inv['vehicle'] ?? ''}'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('$currencySymbol$total'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: const Color(0xFF1e293b),
                      ),
                    ),
                    if (outstanding > 0)
                      Text(
                        context.tr('Due $currencySymbol${outstanding.toStringAsFixed(0)}'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        context.tr('Paid'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.green.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 72),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1e293b),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(label),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF000080)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1e293b),
          ),
        ),
      ],
    );
  }
