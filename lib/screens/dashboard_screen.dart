import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'bills_screen.dart';
import 'collection_screen.dart';
import 'customers_screen.dart';
import 'expense_screen.dart';

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
          if (context.read<AuthProvider>().isCompanyAdmin) {
            context.read<DashboardProvider>().fetchBranches(token);
          }
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18.sp),
        ),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              final token = context.read<AuthProvider>().token;
              if (token != null) {
                if (context.read<AuthProvider>().isCompanyAdmin) {
                  context.read<DashboardProvider>().fetchBranches(token);
                }
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
      body: SingleChildScrollView(
        padding: REdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          children: [
            if (auth.subscriptionActive && auth.subscriptionDaysLeft <= 5)
              Container(
                margin: EdgeInsets.only(bottom: 16.h),
                padding: REdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20.r),
                    SizedBox(width: 12.w),
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
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Branch Filter for Company Admin ──────────────────────
            if (auth.isCompanyAdmin) ...[
              _buildBranchDropdown(dashProvider, auth, context),
              SizedBox(height: 16.h),
            ],

            // ── Today's Stats ───────────────────────────────────────────
            buildSectionTitle(context.tr("Today's Summary"), Icons.today_outlined),
            SizedBox(height: 10.h),
            _buildTodayStats(dashProvider, context),
            SizedBox(height: 20.h),

            // ── Totals Row ──────────────────────────────────────────────
            buildSectionTitle(context.tr('Overview'), Icons.analytics_outlined),
            SizedBox(height: 10.h),
            _buildOverviewRow(dashProvider, context),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // ─── Today Stats (3 cards) ───────────────────────────────────────────────
  Widget _buildTodayStats(DashboardProvider p, BuildContext context) {
    final loading = p.isLoading;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Revenue',
                loading ? '...' : p.todayRevenue,
                Icons.trending_up,
                const Color(0xFF3B82F6),
                Color(0xFFEFF6FF),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _statCard(
                context,
                'Collected',
                loading ? '...' : p.todayCollected,
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
                const Color(0xFFF0FDF4),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Expense',
                loading ? '...' : p.todayExpense,
                Icons.trending_down,
                const Color(0xFFEF4444),
                const Color(0xFFFFF1F2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ExpenseScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'Net Profit',
                loading ? '...' : p.todayNetProfit,
                Icons.account_balance,
                const Color(0xFF0F766E),
                Color(0xFFE6F4F1),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _statCard(
                context,
                'Jobs',
                loading ? '...' : '${p.totalJobs}',
                Icons.work_outline,
                Color(0xFF8B5CF6),
                Color(0xFFF5F3FF),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BillsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
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
            Color(0xFFEF4444),
            Color(0xFFFFF1F2),
            subtitle: loading ? '' : '${p.outstandingCount} ${context.tr('invoices')}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CollectionScreen()),
              );
            },
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _statCard(
            context,
            'Customers',
            loading ? '...' : '${p.totalCustomers}',
            Icons.people_outline,
            const Color(0xFFF59E0B),
            const Color(0xFFFFFBEB),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentInvoices(BuildContext context, List<dynamic> recentInvoices) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
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
                contentPadding: REdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.receipt_outlined,
                    color: Color(0xFF3B82F6),
                    size: 20.r,
                  ),
                ),
                title: Text(
                  inv['customer'] ?? '',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.sp,
                    color: Color(0xFF1e293b),
                  ),
                ),
                subtitle: Text(
                  context.tr('${inv['invoice_number'] ?? ''} · ${inv['vehicle'] ?? ''}'),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: Color(0xFF94A3B8),
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
                        fontSize: 13.sp,
                        color: Color(0xFF1e293b),
                      ),
                    ),
                    if (outstanding > 0)
                      Text(
                        context.tr('Due $currencySymbol${outstanding.toStringAsFixed(0)}'),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        context.tr('Paid'),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.green.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast) Divider(height: 1.h, indent: 72.w),
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: REdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: REdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: color, size: 18.r),
            ),
            SizedBox(height: 10.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1e293b),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              context.tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchDropdown(DashboardProvider p, AuthProvider auth, BuildContext context) {
    final token = auth.token;
    return Container(
      padding: REdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: p.selectedBranchId,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF000080), size: 22.r),
          hint: Row(
            children: [
              Icon(Icons.storefront_outlined, size: 18.r, color: Color(0xFF000080)),
              SizedBox(width: 10.w),
              Text(
                context.tr('All Branches'),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 18.r, color: Color(0xFF000080)),
                  SizedBox(width: 10.w),
                  Text(
                    context.tr('All Branches'),
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            ...p.branches.map((b) {
              return DropdownMenuItem<String?>(
                value: b['id']?.toString(),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18.r, color: Color(0xFF3B82F6)),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        b['name'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (val) {
            if (token != null) {
              p.setSelectedBranchId(val, token);
            }
          },
        ),
      ),
    );
  }
}

Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18.r, color: Color(0xFF000080)),
        SizedBox(width: 8.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1e293b),
          ),
        ),
      ],
    );
  }

