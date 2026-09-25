import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import 'lead_form_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Leads'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
                icon: const Icon(Icons.list_alt, size: 20),
                text: context.tr('List')),
            Tab(
                icon: const Icon(Icons.notifications_active, size: 20),
                text: context.tr('Reminders')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeadsListTab(),
          _LeadsRemindersTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Leads List
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsListTab extends StatefulWidget {
  @override
  State<_LeadsListTab> createState() => _LeadsListTabState();
}

class _LeadsListTabState extends State<_LeadsListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<List<dynamic>> _leadsNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _filteredLeadsNotifier =
      ValueNotifier([]);
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterLeads);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLeads());
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterLeads);
    _searchController.dispose();
    _isLoadingNotifier.dispose();
    _leadsNotifier.dispose();
    _filteredLeadsNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isLoadingNotifier.value = true;
    try {
      final res = await ApiService.listLeads(token);
      if (res['status'] == 'success') {
        _leadsNotifier.value = List<dynamic>.from(res['leads'] ?? []);
        _filterLeads();
      }
    } catch (e) {
      _showSnack('Failed to load leads: $e', Colors.red);
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _filterLeads() {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) {
      _filteredLeadsNotifier.value = List.from(_leadsNotifier.value);
    } else {
      _filteredLeadsNotifier.value = _leadsNotifier.value.where((l) {
        final name = (l['customer_name'] ?? '').toString().toLowerCase();
        final phone = (l['phone_number'] ?? '').toString().toLowerCase();
        final vehicle = (l['vehicle_details'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || vehicle.contains(q);
      }).toList();
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _openCreateOrEditSheet({Map<String, dynamic>? lead}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(lead: lead),
      ),
    );
    if (result == true) {
      await _fetchLeads();
    }
  }

  Future<void> _deleteLead(String leadId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(context.tr('Delete Lead'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('${context.tr('Delete lead for')} $name?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('Delete'),
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.deleteLead(token, leadId);
      if (res['status'] == 'success') {
        _showSnack(context.tr('Lead deleted.'), Colors.green);
        await _fetchLeads();
      } else {
        _showSnack(res['message'] ?? 'Failed', Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: REdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: context.tr('Search name, phone, vehicle...'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              ElevatedButton.icon(
                onPressed: () => _openCreateOrEditSheet(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000080),
                  foregroundColor: Colors.white,
                  padding: REdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('Create'),
                    style:
                        GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return ValueListenableBuilder<List<dynamic>>(
                valueListenable: _filteredLeadsNotifier,
                builder: (context, leads, _) {
                  if (leads.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 60.r, color: Colors.grey.shade300),
                          SizedBox(height: 12.h),
                          Text(
                            context.tr('No leads found.'),
                            style: GoogleFonts.inter(
                                color: Colors.grey.shade500,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            context.tr('Tap Create to add your first lead.'),
                            style: GoogleFonts.inter(
                                color: Colors.grey.shade400,
                                fontSize: 12.sp),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _fetchLeads,
                    child: ListView.separated(
                      padding: REdgeInsets.all(16),
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, i) => _buildLeadCard(leads[i]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final renewalDate = lead['renewal_date'];
    final renewalDisplay = renewalDate != null
        ? _formatDate(renewalDate.toString())
        : context.tr('No date set');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8.r,
              offset: Offset(0, 2.h))
        ],
      ),
      child: ListTile(
        contentPadding: REdgeInsets.fromLTRB(16, 10, 12, 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF000080).withOpacity(0.1),
          radius: 22.r,
          child: Text(
            (lead['customer_name'] ?? '?').toString().isNotEmpty
                ? lead['customer_name'].toString()[0].toUpperCase()
                : '?',
            style: GoogleFonts.inter(
                color: const Color(0xFF000080),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          lead['customer_name'] ?? '',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
              color: const Color(0xFF1E293B)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Row(children: [
              Icon(Icons.phone, size: 13.r, color: Colors.grey.shade500),
              SizedBox(width: 4.w),
              Text(lead['phone_number'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 12.sp, color: Colors.grey.shade600)),
            ]),
            if ((lead['vehicle_details'] ?? '').toString().isNotEmpty) ...[
              SizedBox(height: 2.h),
              Row(children: [
                Icon(Icons.directions_car, size: 13.r, color: Colors.grey.shade500),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(lead['vehicle_details'].toString(),
                      style: GoogleFonts.inter(
                          fontSize: 12.sp, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            SizedBox(height: 4.h),
            Container(
              padding:
                  REdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: renewalDate != null
                    ? const Color(0xFF000080).withOpacity(0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today,
                      size: 11.r,
                      color: renewalDate != null
                          ? const Color(0xFF000080)
                          : Colors.grey.shade400),
                  SizedBox(width: 4.w),
                  Text(
                    renewalDisplay,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: renewalDate != null
                          ? const Color(0xFF000080)
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 20.r, color: const Color(0xFF000080)),
              onPressed: () => _openCreateOrEditSheet(
                  lead: Map<String, dynamic>.from(lead)),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20.r, color: Colors.red),
              onPressed: () => _deleteLead(
                  lead['id'].toString(), lead['customer_name'] ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (_) {}
    return isoDate;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Leads Reminders
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsRemindersTab extends StatefulWidget {
  @override
  State<_LeadsRemindersTab> createState() => _LeadsRemindersTabState();
}

class _LeadsRemindersTabState extends State<_LeadsRemindersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<List<dynamic>> _leadsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _showAllNotifier = ValueNotifier(false);
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<Set<String>> _sendingIdsNotifier = ValueNotifier({});

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReminders());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoadingNotifier.dispose();
    _leadsNotifier.dispose();
    _showAllNotifier.dispose();
    _sendingIdsNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchReminders() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isLoadingNotifier.value = true;
    try {
      final res = await ApiService.getLeadsReminders(
        token,
        showAll: _showAllNotifier.value,
        daysAhead: 30,
      );
      if (res['status'] == 'success') {
        _leadsNotifier.value = List<dynamic>.from(res['leads'] ?? []);
      }
    } catch (e) {
      _showSnack('Failed to load reminders: $e', Colors.red);
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  List<dynamic> get _filteredLeads {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return _leadsNotifier.value;
    return _leadsNotifier.value.where((l) {
      final name = (l['customer_name'] ?? '').toString().toLowerCase();
      final phone = (l['phone_number'] ?? '').toString().toLowerCase();
      final vehicle = (l['vehicle_details'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || vehicle.contains(q);
    }).toList();
  }

  Future<void> _launchWhatsApp(dynamic lead) async {
    final leadId = (lead['id'] ?? '').toString();
    final phone = (lead['whatsapp_number'] ?? lead['phone_number'] ?? '').toString();
    final name = (lead['customer_name'] ?? 'Customer').toString();
    final vehicle = (lead['vehicle_details'] ?? '').toString();
    final renewalDisplay = (lead['renewal_date_display'] ?? '').toString();
    final branchName =
        context.read<AuthProvider>().branchName ?? 'Mobiz Auto Care Pro';

    final vehicleInfo = vehicle.isNotEmpty ? ' vehicle ($vehicle)' : ' vehicle';
    final dateInfo = renewalDisplay.isNotEmpty ? ' on $renewalDisplay' : '';
    final msg = 'Dear $name, your$vehicleInfo service renewal is due$dateInfo. Thank you, $branchName.';

    final cleanedPhone = CountryConfig.formatPhoneForWhatsapp(phone);
    if (cleanedPhone.isEmpty) {
      _showSnack(context.tr('Invalid phone number.'), Colors.red);
      return;
    }

    final sendingSet = Set<String>.from(_sendingIdsNotifier.value);
    sendingSet.add(leadId);
    _sendingIdsNotifier.value = sendingSet;

    final url = Uri.parse(
        'https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(msg)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      _showSnack(
          '${context.tr('Opened WhatsApp chat for')} $name', Colors.green);
    } catch (e) {
      _showSnack('${context.tr('Could not launch WhatsApp:')} $e', Colors.red);
    } finally {
      final finalSet = Set<String>.from(_sendingIdsNotifier.value);
      finalSet.remove(leadId);
      _sendingIdsNotifier.value = finalSet;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Controls bar
        Container(
          color: Colors.white,
          padding: REdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list, size: 16.r, color: Colors.grey.shade600),
                  SizedBox(width: 6.w),
                  ValueListenableBuilder<bool>(
                    valueListenable: _showAllNotifier,
                    builder: (context, showAll, _) => Row(
                      children: [
                        _filterChip(context, false, showAll),
                        SizedBox(width: 8.w),
                        _filterChip(context, true, showAll),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20.r, color: const Color(0xFF000080)),
                    onPressed: _fetchReminders,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: context.tr('Search name, phone, vehicle...'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // Reminders list
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final leads = _filteredLeads;
              if (leads.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 60.r, color: Colors.grey.shade300),
                      SizedBox(height: 12.h),
                      Text(
                        context.tr('No upcoming renewals.'),
                        style: GoogleFonts.inter(
                            color: Colors.grey.shade500,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _fetchReminders,
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _sendingIdsNotifier,
                  builder: (context, sendingIds, _) {
                    return ListView.separated(
                      padding: REdgeInsets.all(16),
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, i) =>
                          _buildReminderCard(leads[i], sendingIds),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context, bool isAll, bool currentShowAll) {
    final isSelected = isAll == currentShowAll;
    return GestureDetector(
      onTap: () {
        _showAllNotifier.value = isAll;
        _fetchReminders();
      },
      child: Container(
        padding: REdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000080) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF000080)
                  : Colors.grey.shade300),
        ),
        child: Text(
          isAll ? context.tr('All') : context.tr('Next 30 Days'),
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(
      Map<String, dynamic> lead, Set<String> sendingIds) {
    final leadId = (lead['id'] ?? '').toString();
    final daysUntil = lead['days_until_renewal'] as int?;
    final isOverdue = lead['is_overdue'] == true;
    final isToday = lead['is_today'] == true;
    final isSending = sendingIds.contains(leadId);

    Color statusColor;
    String statusLabel;
    if (isOverdue) {
      statusColor = Colors.red;
      statusLabel = context.tr('Overdue');
    } else if (isToday) {
      statusColor = Colors.orange;
      statusLabel = context.tr('Today');
    } else if (daysUntil != null && daysUntil <= 7) {
      statusColor = Colors.orange.shade700;
      statusLabel = '${daysUntil}d';
    } else {
      statusColor = const Color(0xFF10B981);
      statusLabel = daysUntil != null ? '${daysUntil}d' : '';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
            color: isOverdue
                ? Colors.red.withOpacity(0.3)
                : isToday
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8.r,
              offset: Offset(0, 2.h))
        ],
      ),
      child: Padding(
        padding: REdgeInsets.all(14),
        child: Row(
          children: [
            // Status badge
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : isToday
                            ? Icons.today
                            : Icons.schedule,
                    color: statusColor,
                    size: 18.r,
                  ),
                  if (statusLabel.isNotEmpty)
                    Text(statusLabel,
                        style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                ],
              ),
            ),
            SizedBox(width: 12.w),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead['customer_name'] ?? '',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                        color: const Color(0xFF1E293B)),
                  ),
                  SizedBox(height: 3.h),
                  Row(children: [
                    Icon(Icons.phone, size: 12.r, color: Colors.grey.shade500),
                    SizedBox(width: 4.w),
                    Text(lead['phone_number'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 12.sp, color: Colors.grey.shade600)),
                  ]),
                  if ((lead['vehicle_details'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Row(children: [
                      Icon(Icons.directions_car,
                          size: 12.r, color: Colors.grey.shade500),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(lead['vehicle_details'].toString(),
                            style: GoogleFonts.inter(
                                fontSize: 12.sp, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  SizedBox(height: 4.h),
                  Row(children: [
                    Icon(Icons.calendar_today,
                        size: 12.r, color: statusColor),
                    SizedBox(width: 4.w),
                    Text(
                      lead['renewal_date_display'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                    ),
                  ]),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // WhatsApp button
            GestureDetector(
              onTap: isSending ? null : () => _launchWhatsApp(lead),
              child: Container(
                padding: REdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSending
                      ? Colors.grey.shade100
                      : const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: isSending
                          ? Colors.grey.shade300
                          : const Color(0xFF25D366).withOpacity(0.4)),
                ),
                child: isSending
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                    : Icon(Icons.chat,
                        color: const Color(0xFF25D366), size: 22.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


