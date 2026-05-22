import 'package:car_wash_mobile/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'bills_screen.dart';
import 'book_now_screen.dart';
import 'bookings_list_screen.dart';
import 'collection_screen.dart';
import 'new_job_screen.dart';
import 'receipts_screen.dart';
import 'vehicle_search_screen.dart';
import 'edit_customer_screen.dart';
import 'customers_screen.dart';
import 'schemes_screen.dart';
import 'reports_screen.dart';
import 'broadcast_screen.dart';
import 'complaints_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // --- state ---

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  // --- navigation ---
  final List<Map<String, dynamic>> _branchMenuItems = [
    {
      'title': 'New Job',
      'icon': Icons.add_circle_outline,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Book Now',
      'icon': Icons.calendar_today,
      'color': Color(0xFFF97316),
    },
    {'title': 'Bookings', 'icon': Icons.event_note, 'color': Color(0xFF8B5CF6)},
    {'title': 'Bill', 'icon': Icons.receipt_long, 'color': Color(0xFF22C55E)},
    {
      'title': 'Outstanding',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFFDC2626),
    },
    {
      'title': 'Receipt',
      'icon': Icons.receipt_outlined,
      'color': Color(0xFF0F766E),
    },
    {
      'title': 'Customers',
      'icon': Icons.people_outline,
      'color': Color(0xFFA855F7),
    },
    {
      'title': 'Schemes',
      'icon': Icons.card_giftcard,
      'color': Color(0xFFEC4899),
    },
    {'title': 'Reports', 'icon': Icons.bar_chart, 'color': Color(0xFF14B8A6)},
    {
      'title': 'Vehicle',
      'icon': Icons.directions_car,
      'color': Color(0xFF6366F1),
    },
    {'title': 'Broadcasts', 'icon': Icons.campaign, 'color': Color(0xFF00BFFF)},
    {'title': 'Language', 'icon': Icons.language, 'color': Color(0xFF92400E)},
    {
      'title': 'Complaints',
      'icon': Icons.assignment_late_outlined,
      'color': Color(0xFFF43F5E),
    },
    // {
    //   'title': 'Profile',
    //   'icon': Icons.person_outline,
    //   'color': Color(0xFF64748B),
    // },
    // {
    //   'title': 'Settings',
    //   'icon': Icons.settings_outlined,
    //   'color': Color(0xFF94A3B8),
    // },
  ];

  final List<Map<String, dynamic>> _companyMenuItems = [
    {
      'title': 'Schemes',
      'icon': Icons.card_giftcard,
      'color': Color(0xFFEC4899),
    },
    {'title': 'Reports', 'icon': Icons.bar_chart, 'color': Color(0xFF14B8A6)},
    {
      'title': 'Outstanding',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFFDC2626),
    },
    {
      'title': 'Receipt',
      'icon': Icons.receipt_outlined,
      'color': Color(0xFF0F766E),
    },
    {
      'title': 'Customers',
      'icon': Icons.people_outline,
      'color': Color(0xFFA855F7),
    },
    {
      'title': 'Complaints',
      'icon': Icons.assignment_late_outlined,
      'color': Color(0xFFF43F5E),
    },
  ];

  void _navigate(BuildContext context, String title) {
    final routes = <String, Widget>{
      'New Job': const NewJobScreen(),
      'Book Now': const BookNowScreen(),
      'Bookings': const BookingsListScreen(),
      'Bill': const BillsScreen(),
      'Outstanding': const CollectionScreen(),
      'Receipt': const ReceiptsScreen(),
      'Vehicle': const VehicleSearchScreen(),
      'Edit Customer': const EditCustomerScreen(),
      'Customers': const CustomersScreen(),
      'Reports': const ReportsScreen(),
      'Schemes': const SchemesScreen(),
      'Broadcasts': const BroadcastScreen(),
      'Complaints': const ComplaintsScreen(),
    };
    final screen = routes[title];
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  // ─── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = (auth.displayName?.isNotEmpty == true)
        ? auth.displayName!
        : (auth.companyName?.isNotEmpty == true)
        ? auth.companyName!
        : (auth.username ?? 'Admin');
    final isBranch = auth.isBranchAdmin;
    final isCompany = auth.isCompanyAdmin;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),

      // ── Drawer ──────────────────────────────────────────────────────────
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF000080), Color(0xFF0000CD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_car_wash,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isBranch ? 'Branch Admin' : 'Company Admin',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable menu items ────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _drawerItem(
                      Icons.dashboard_outlined,
                      'Dashboard',
                      () => Navigator.pop(context),
                    ),
                    if (!isCompany) ...[
                      _drawerItem(Icons.receipt_long_outlined, 'Bills', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BillsScreen()),
                        );
                      }),
                      _drawerItem(Icons.calendar_today_outlined, 'Bookings', () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookingsListScreen(),
                          ),
                        );
                      }),
                    ],
                    _drawerItem(
                      Icons.account_balance_wallet_outlined,
                      'Outstanding',
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CollectionScreen()),
                        );
                      },
                    ),
                    _drawerItem(Icons.receipt_outlined, 'Receipt', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
                      );
                    }),
                    _drawerItem(Icons.bar_chart_outlined, 'Reports', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    }),
                    _drawerItem(Icons.card_giftcard_outlined, 'Schemes', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SchemesScreen()),
                      );
                    }),
                    _drawerItem(Icons.people_outline, 'Customers', () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomersScreen()),
                      );
                    }),
                    if (!isCompany)
                      _drawerItem(
                        Icons.directions_car_outlined,
                        'Vehicle Search',
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleSearchScreen(),
                            ),
                          );
                        },
                      ),
                    _drawerItem(
                      Icons.assignment_late_outlined,
                      'Complaints',
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ComplaintsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Fixed bottom: Logout + version ───────────────────────────
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.logout,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                    fontSize: 15,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        'Logout',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
                        style: GoogleFonts.inter(color: Colors.grey.shade600),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Logout',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthProvider>().logout();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'v1.0.5',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_car_wash,
                color: Color(0xFF000080),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Car Wash',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        // actions: [
        //   IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        // ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Welcome Card ────────────────────────────────────────────
            _buildWelcomeCard(displayName, isBranch),
            const SizedBox(height: 20),

            // ── Quick Menu ──────────────────────────────────────────────
            buildSectionTitle('Quick Menu', Icons.grid_view_outlined),
            const SizedBox(height: 10),
            _buildMenuGrid(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Welcome Card ────────────────────────────────────────────────────────

  Widget _buildWelcomeCard(String name, bool isBranch) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000080), Color(0xFF0000B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000080).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back 👋',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBranch ? 'Branch Admin' : 'Company Admin',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Recent Invoices ────────────────────────────────────────────────────

  // ─── Quick Menu Grid ─────────────────────────────────────────────────────
  Widget _buildMenuGrid() {
    final auth = context.read<AuthProvider>();
    final menuItems = auth.isCompanyAdmin
        ? _companyMenuItems
        : _branchMenuItems;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final color = item['color'] as Color;
        return InkWell(
          onTap: () => _navigate(context, item['title']),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item['icon'], color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  item['title'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Section Title ────────────────────────────────────────────────────────

  // ─── Drawer Item ──────────────────────────────────────────────────────────
  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF000080), size: 22),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: const Color(0xFF1e293b),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
