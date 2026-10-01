import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
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

  final Set<String> _selectedReminderIds = {};
  final Set<String> _sendingSinglePlanIds = {};
  bool _isSendingBulk = false;

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
          _selectedReminderIds.clear();
        });
      } else {
        setState(() {
          _error = res['message'] ?? context.tr('Failed to load reminders');
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

  String _formatDateDisplay(String? s) {
    if (s == null || s.isEmpty) return '—';
    final parts = s.split('-');
    if (parts.length != 3) return s;
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    final monthName = (m >= 1 && m <= 12) ? months[m] : parts[1];
    return '${parts[2]} $monthName ${parts[0]}';
  }

  String _buildReminderMessageText(Map<String, dynamic> plan) {
    final custName = (plan['customer_name'] ?? 'Customer').toString().trim();
    String insService =
        (plan['service_name'] ?? 'Insurance').toString().trim();
    if (insService.isEmpty || insService.toLowerCase() == 'service') {
      insService = 'Insurance';
    }
    if (insService.toLowerCase().endsWith(' policy')) {
      insService = insService.substring(0, insService.length - 7).trim();
    }
    final expiryVal =
        plan['insurance_expiry_date'] ?? plan['expiry_date'] ?? '';
    final expiryDate = _formatDateDisplay(expiryVal.toString());

    String branchName = (plan['branch_name'] ?? '').toString().trim();
    if (branchName.isEmpty) {
      final authBranch =
          context.read<AuthProvider>().branchName?.trim() ?? '';
      final companyName =
          context.read<AuthProvider>().companyName?.trim() ?? '';
      branchName = authBranch.isNotEmpty
          ? authBranch
          : (companyName.isNotEmpty ? companyName : 'Mobiz Auto Care Pro');
    }

    final insCompany = (plan['insurance_company_name'] ?? '').toString().trim();
    final serviceLabel = insCompany.isNotEmpty ? "$insCompany $insService" : insService;
    return "Dear $custName, $serviceLabel policy expiry reminder.\n"
        "Expiry date: $expiryDate\n"
        "Kindly contact for the renewal.\n"
        "$branchName support team";
  }

  Future<void> _launchDirectWhatsApp(Map<String, dynamic> plan) async {
    final custPhone = (plan['phone'] ??
            plan['whatsapp_number'] ??
            plan['customer_phone'] ??
            '')
        .toString();
    final text = _buildReminderMessageText(plan);
    final cleanedPhone = CountryConfig.formatPhoneForWhatsapp(custPhone);

    if (cleanedPhone.isEmpty) {
      _showSnack(context.tr('Invalid phone number for customer.'), Colors.red);
      return;
    }

    final whatsappUrl = Uri.parse(
      "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(text)}",
    );

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      final token = context.read<AuthProvider>().token;
      final planId = (plan['id'] ?? '').toString();
      if (token != null && planId.isNotEmpty) {
        await ApiService.sendReminders(token, [planId], action: 'mark_sent');
      }
      if (!mounted) return;
      _showSnack(
        context.tr('Opened prefilled WhatsApp chat window.'),
        Colors.green,
      );
      _loadReminders();
    } catch (e) {
      if (!mounted) return;
      _showSnack('${context.tr("Could not launch WhatsApp:")} $e', Colors.red);
    }
  }

  Future<void> _sendSingleReminderApi(Map<String, dynamic> plan) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final planId = (plan['id'] ?? '').toString();
    if (planId.isEmpty) return;

    setState(() {
      _sendingSinglePlanIds.add(planId);
    });

    try {
      final res = await ApiService.sendReminders(
        token,
        [planId],
        templateName: 'insurancereminder',
        planDetails: plan,
      );

      if (!mounted) return;

      if (res['success'] == true || res['status'] == 'success') {
        _showSnack(
          context.tr('Reminder sent successfully!'),
          Colors.green,
        );
        _loadReminders();
      } else {
        _showSnack(
          res['message'] ?? context.tr('Failed to send reminder.'),
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('${context.tr("Failed to send reminder:")} $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingSinglePlanIds.remove(planId);
        });
      }
    }
  }

  Future<void> _sendBulkReminders() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || _selectedReminderIds.isEmpty) return;

    setState(() {
      _isSendingBulk = true;
    });

    try {
      final listToSend = _selectedReminderIds.toList();
      final res = await ApiService.sendReminders(
        token,
        listToSend,
        templateName: 'insurancereminder',
      );

      if (!mounted) return;

      if (res['success'] == true || res['status'] == 'success') {
        final sentCount = res['sent_count'] ?? listToSend.length;
        _showSnack(
          '${context.tr("Successfully sent")} $sentCount ${context.tr("reminder(s)!")}',
          Colors.green,
        );
        _loadReminders();
      } else {
        _showSnack(
          res['message'] ?? context.tr('Failed to send reminders.'),
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('${context.tr("Failed to send reminders:")} $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingBulk = false;
        });
      }
    }
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _showAll = false;
      });
      _loadReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = !_showAll &&
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Insurance Reminders'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('Refresh'),
            onPressed: _loadReminders,
          ),
        ],
      ),
      bottomNavigationBar: _selectedReminderIds.isNotEmpty
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedReminderIds.length} ${context.tr("selected")}',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            context.tr('Ready to send via WhatsApp'),
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                 
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // ── Filter Bar ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              children: [
                Row(
                  children: [
                    // Date picker pill
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: !_showAll
                              ? const Color(0xFF000080).withValues(alpha: 0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: !_showAll
                                ? const Color(0xFF000080)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 15.r,
                              color: !_showAll
                                  ? const Color(0xFF000080)
                                  : Colors.grey.shade600,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              isToday
                                  ? context.tr('Today')
                                  : _formatDateDisplay(_dateParam),
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: !_showAll
                                    ? const Color(0xFF000080)
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // All Reminders pill
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showAll = !_showAll;
                        });
                        _loadReminders();
                      },
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: _showAll
                              ? const Color(0xFF000080)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: _showAll
                                ? const Color(0xFF000080)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          context.tr('All Reminders'),
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                _showAll ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // Search field
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadReminders(),
                  style: GoogleFonts.inter(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: context
                        .tr('Search customer, vehicle, or phone...'),
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13.sp, color: Colors.grey.shade400),
                    prefixIcon:
                        Icon(Icons.search, size: 20.r, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadReminders();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                  ),
                ),
              ],
            ),
          ),

          Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h)),

          // ── Selection & Counter Row ──────────────────────────────────────
        

          // ── Results List ────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: GoogleFonts.inter(color: Colors.red),
                        ),
                      )
                    : _reminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 64.r, color: Colors.grey.shade300),
                                SizedBox(height: 16.h),
                                Text(
                                  context.tr('No due reminders found'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
                            itemCount: _reminders.length,
                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                            itemBuilder: (_, i) {
                              final item =
                                  _reminders[i] as Map<String, dynamic>;
                              final planId = (item['id'] ?? '').toString();
                              final isSelected =
                                  _selectedReminderIds.contains(planId);
                              final isSendingSingle =
                                  _sendingSinglePlanIds.contains(planId);

                              return _InsuranceReminderCard(
                                reminder: item,
                                isSelected: isSelected,
                                isSendingSingle: isSendingSingle,
                                // onToggleSelect: () {
                                //   setState(() {
                                //     if (isSelected) {
                                //       _selectedReminderIds.remove(planId);
                                //     } else {
                                //       _selectedReminderIds.add(planId);
                                //     }
                                //   });
                                // },
                                onWhatsAppChat: () =>
                                    _launchDirectWhatsApp(item),
                                onSendApi: () => _sendSingleReminderApi(item),
                                formatDate: _formatDateDisplay,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reminder Card with Checkbox & Action Buttons (WhatsApp Chat + Send API)
// ─────────────────────────────────────────────────────────────────────────────
class _InsuranceReminderCard extends StatelessWidget {
  final Map<String, dynamic> reminder;
  final bool isSelected;
  final bool isSendingSingle;
  // final VoidCallback onToggleSelect;
  final VoidCallback onWhatsAppChat;
  final VoidCallback onSendApi;
  final String Function(String?) formatDate;

  const _InsuranceReminderCard({
    required this.reminder,
    required this.isSelected,
    required this.isSendingSingle,
    // required this.onToggleSelect,
    required this.onWhatsAppChat,
    required this.onSendApi,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheduledDate = reminder['scheduled_date'] as String? ?? '';
    final expiryDate = reminder['insurance_expiry_date'] as String? ?? '';
    final isToday = scheduledDate ==
        DateTime.now().toIso8601String().substring(0, 10);
    final vehicleNo = (reminder['vehicle_number'] ?? '').toString().trim();
    final serviceName = (reminder['service_name'] ?? '').toString().trim();
    final insCompany = (reminder['insurance_company_name'] ?? '').toString().trim();
    final invoiceNo = (reminder['invoice_number'] ?? '').toString().trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: isSelected
            ? Border.all(color: const Color(0xFF000080), width: 1.8)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Checkbox + Avatar + Name + Phone + Badge
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 14.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection Checkbox
                // Checkbox(
                //   value: isSelected,
                //   activeColor: const Color(0xFF000080),
                //   shape: RoundedRectangleBorder(
                //     borderRadius: BorderRadius.circular(4.r),
                //   ),
                //   onChanged: (_) => onToggleSelect(),
                // ),

                // Shield Icon
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: const Color(0xFF7C3AED),
                    size: 20.r,
                  ),
                ),

                SizedBox(width: 10.w),

                // Name & Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder['customer_name'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        reminder['phone'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isToday)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      context.tr('Today'),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Details section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                Divider(height: 1, color: Colors.grey.shade100),
                SizedBox(height: 8.h),
                if (vehicleNo.isNotEmpty && vehicleNo != 'NON-MOTOR') ...[
                  _DetailRow(
                    icon: Icons.directions_car_outlined,
                    label: context.tr('Vehicle'),
                    value: vehicleNo,
                  ),
                  SizedBox(height: 5.h),
                ],
                _DetailRow(
                  icon: Icons.home_repair_service_outlined,
                  label: context.tr('Service'),
                  value: serviceName.isNotEmpty ? serviceName : 'Insurance',
                ),
                if (insCompany.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  _DetailRow(
                    icon: Icons.business_outlined,
                    label: context.tr('Company'),
                    value: insCompany,
                  ),
                ],
                SizedBox(height: 5.h),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: context.tr('Reminder Date'),
                  value: formatDate(scheduledDate),
                ),
                if (expiryDate.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: context.tr('Policy Expiry'),
                    value: formatDate(expiryDate),
                    valueColor: Colors.red.shade600,
                    isBold: true,
                  ),
                ],
                if (invoiceNo.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  _DetailRow(
                    icon: Icons.receipt_long_outlined,
                    label: context.tr('Invoice'),
                    value: '#$invoiceNo',
                  ),
                ],
                SizedBox(height: 8.h),
              ],
            ),
          ),

          // ── Action Buttons Row ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(14.r),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                // WhatsApp Chat Button
                Expanded(
                  child: InkWell(
                    onTap: onWhatsAppChat,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 15.r,
                            color: const Color(0xFF16A34A),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            context.tr('WhatsApp Chat'),
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10.w),

                // Send API Button
                Expanded(
                  child: InkWell(
                    onTap: isSendingSingle ? null : onSendApi,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000080),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: isSendingSingle
                            ? SizedBox(
                                width: 15.r,
                                height: 15.r,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send_outlined,
                                    size: 15.r,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    context.tr('Send'),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14.r, color: Colors.grey.shade500),
        SizedBox(width: 6.w),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
