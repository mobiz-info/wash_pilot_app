import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class InsuranceRemindersScreen extends StatefulWidget {
  const InsuranceRemindersScreen({super.key});

  @override
  State<InsuranceRemindersScreen> createState() =>
      _InsuranceRemindersScreenState();
}

class _InsuranceRemindersScreenState extends State<InsuranceRemindersScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _reminders = [];
  bool _isLoading = true;
  String _error = '';
  bool _showAll = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _dateParam =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-'
      '${_selectedDate.month.toString().padLeft(2, '0')}-'
      '${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> _loadReminders() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final res = await ApiService.insuranceReminders(
        token,
        date: _showAll ? null : _dateParam,
        showAll: _showAll,
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
      );
      if (res['success'] == true) {
        setState(() {
          _reminders = List<dynamic>.from(res['reminders'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load reminders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _showAll = false;
      });
      _loadReminders();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} ${months[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Insurance Reminders',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
          Container(
            color: const Color(0xFF000080),
            padding: REdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              children: [
                // Date picker row
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showAll ? null : _pickDate,
                        child: Container(
                          padding: REdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16.r, color: Colors.white70),
                              SizedBox(width: 8.w),
                              Text(
                                _showAll ? 'All dates' : _formatDate(_dateParam),
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showAll = !_showAll);
                        _loadReminders();
                      },
                      child: Container(
                        padding: REdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _showAll
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          'Show All',
                          style: GoogleFonts.inter(
                            color: _showAll ? const Color(0xFF000080) : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Search
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: Colors.white),
                  onSubmitted: (_) => _loadReminders(),
                  decoration: InputDecoration(
                    hintText: 'Search by customer, phone, vehicle…',
                    hintStyle: GoogleFonts.inter(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white60),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white60),
                            onPressed: () {
                              _searchController.clear();
                              _loadReminders();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: REdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // ── Results ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Text(_error,
                            style: GoogleFonts.inter(color: Colors.red)))
                    : _reminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 64.r, color: Colors.grey.shade300),
                                SizedBox(height: 16.h),
                                Text('No reminders found',
                                    style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: REdgeInsets.all(16),
                            itemCount: _reminders.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10.h),
                            itemBuilder: (_, i) =>
                                _ReminderCard(reminder: _reminders[i] as Map<String, dynamic>),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;

  const _ReminderCard({required this.reminder});

  String _fmt(String? s) {
    if (s == null || s.isEmpty) return '—';
    final parts = s.split('-');
    if (parts.length != 3) return s;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} ${months[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDate = reminder['scheduled_date'] as String? ?? '';
    final expiryDate = reminder['insurance_expiry_date'] as String? ?? '';
    final isToday = scheduledDate == DateTime.now().toIso8601String().substring(0, 10);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: isToday
            ? Border.all(color: const Color(0xFF7C3AED), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8.r,
              offset: Offset(0, 2.h)),
        ],
      ),
      child: Padding(
        padding: REdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: REdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_outlined, color: const Color(0xFF7C3AED), size: 22.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder['customer_name'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        reminder['phone'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 13.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Container(
                    padding: REdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text('Today',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if ((reminder['vehicle_number'] as String? ?? '').isNotEmpty) ...[
              SizedBox(height: 10.h),
              _InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle',
                  value: reminder['vehicle_number'] ?? ''),
            ],
            SizedBox(height: 6.h),
            _InfoRow(icon: Icons.home_repair_service_outlined, label: 'Service',
                value: reminder['service_name'] ?? ''),
            SizedBox(height: 6.h),
            _InfoRow(icon: Icons.calendar_today_outlined, label: 'Reminder Date',
                value: _fmt(scheduledDate)),
            if (expiryDate.isNotEmpty) ...[
              SizedBox(height: 6.h),
              _InfoRow(icon: Icons.event_busy_outlined, label: 'Policy Expiry',
                  value: _fmt(expiryDate),
                  valueColor: Colors.red.shade600),
            ],
            if ((reminder['invoice_number'] as String? ?? '').isNotEmpty) ...[
              SizedBox(height: 6.h),
              _InfoRow(icon: Icons.receipt_long_outlined, label: 'Invoice',
                  value: '#${reminder['invoice_number']}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14.r, color: Colors.grey.shade500),
        SizedBox(width: 6.w),
        Text('$label: ',
            style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0F172A))),
        ),
      ],
    );
  }
}
