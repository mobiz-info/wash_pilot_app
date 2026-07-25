import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final dashProvider = context.watch<DashboardProvider>();
    final auth = context.watch<AuthProvider>();

    // Load stats on first build if not yet loaded
    if (!dashProvider.isLoading && !dashProvider.hasLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final token = context.read<AuthProvider>().token;
        if (token != null) {
          context.read<DashboardProvider>().loadStats(token).then((res) {
            if (res != null && context.mounted) {
              context.read<AuthProvider>().updateSubscriptionStatus(
                active: res['subscription_active'] ?? true,
                daysLeft: res['subscription_days_left'] ?? 999,
                endDate: res['subscription_end_date'],
              );
            }
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Dashboard'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final token = context.read<AuthProvider>().token;
              if (token != null) {
                context.read<DashboardProvider>().loadStats(token).then((res) {
                  if (res != null && context.mounted) {
                    context.read<AuthProvider>().updateSubscriptionStatus(
                      active: res['subscription_active'] ?? true,
                      daysLeft: res['subscription_days_left'] ?? 999,
                      endDate: res['subscription_end_date'],
                    );
                  }
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 20),
        child: Column(
          children: [
            if (auth.subscriptionActive && auth.subscriptionDaysLeft <= 5)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        auth.subscriptionDaysLeft == 0
                            ? context.tr('Subscription ends today. Please renew to avoid service disruption.')
                            : auth.subscriptionDaysLeft == 1
                                ? context.tr('Subscription ends tomorrow. Please renew to avoid service disruption.')
                                : context.tr('Subscription ending in ${auth.subscriptionDaysLeft} days. Please renew to avoid service disruption.'),
                        style: GoogleFonts.inter(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Today's Stats ───────────────────────────────────────────
            // ── Today's Stats ───────────────────────────────────────────
            buildSectionTitle(context.tr("Today's Summary"), Icons.today_outlined),
            const SizedBox(height: 10),
            _buildTodayStats(dashProvider, auth, context),
            const SizedBox(height: 20),

            // ── Totals Row ──────────────────────────────────────────────
            buildSectionTitle(context.tr('Overview'), Icons.analytics_outlined),
            const SizedBox(height: 10),
            _buildOverviewRow(dashProvider, context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Today Stats (3 cards) ───────────────────────────────────────────────
  Widget _buildTodayStats(DashboardProvider p, AuthProvider auth, BuildContext context) {
    final loading = p.isLoading;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Revenue',
                loading ? '...' : _fmt(p.todayRevenue, auth),
                Icons.trending_up,
                const Color(0xFF3B82F6),
                const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                context,
                'Collected',
                loading ? '...' : _fmt(p.todayCollected, auth),
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
                const Color(0xFFF0FDF4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Expense',
                loading ? '...' : _fmt(p.todayExpense, auth),
                Icons.trending_down,
                const Color(0xFFEF4444),
                const Color(0xFFFFF1F2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Net Profit',
                loading ? '...' : _fmt(p.todayNetProfit, auth),
                Icons.account_balance,
                const Color(0xFF0F766E),
                const Color(0xFFE6F4F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                context,
                'Jobs',
                loading ? '...' : '${p.totalJobs}',
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
  Widget _buildOverviewRow(DashboardProvider p, BuildContext context) {
    final loading = p.isLoading;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            'Outstanding',
            loading ? '...' : p.totalOutstanding,
            Icons.warning_amber_outlined,
            const Color(0xFFEF4444),
            const Color(0xFFFFF1F2),
            subtitle: loading ? '' : '${p.outstandingCount} ${context.tr('invoices')}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            context,
            'Customers',
            loading ? '...' : '${p.totalCustomers}',
            Icons.people_outline,
            const Color(0xFFF59E0B),
            const Color(0xFFFFFBEB),
          ),
        ),
      ],
    );
  }

  String _fmt(String raw, AuthProvider auth) {
    final currencySymbol = auth.currencySymbol;
    try {
      final v = double.parse(raw);
      if (v >= 1000000) return '$currencySymbol${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return '$currencySymbol${(v / 1000).toStringAsFixed(1)}K';
      return '$currencySymbol${v.toStringAsFixed(0)}';
    } catch (_) {
      return '$currencySymbol$raw';
    }
  }

  Widget _buildRecentInvoices(BuildContext context, List<dynamic> recentInvoices) {
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
        children: recentInvoices.asMap().entries.map((e) {
          final inv = e.value;
          final isLast = e.key == recentInvoices.length - 1;
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
    BuildContext context,
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
