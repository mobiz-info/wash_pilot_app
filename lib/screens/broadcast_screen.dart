import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/country_config.dart';
import '../providers/auth_provider.dart';
import '../providers/broadcast_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  // ValueNotifiers for UI local states
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  final ValueNotifier<List<dynamic>> _allCustomersNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _inactiveCustomersNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _filteredCustomersNotifier = ValueNotifier([]);
  final ValueNotifier<List<dynamic>> _templatesNotifier = ValueNotifier([]);
  final ValueNotifier<dynamic> _selectedTemplateNotifier = ValueNotifier(null);

  // Inactive filter days (0 = All, 30 = 30 Days, 60 = 60 Days, 90 = 90 Days)
  final ValueNotifier<int> _inactiveFilterNotifier = ValueNotifier(0);

  // Sending state per customer ID
  final ValueNotifier<Set<String>> _sendingCustomerIdsNotifier = ValueNotifier({});

  // Reminders state
  final ValueNotifier<List<dynamic>> _reminderPlansNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingReminderPlansNotifier = ValueNotifier(false);
  final ValueNotifier<DateTime> _selectedReminderDateNotifier = ValueNotifier(DateTime.now());
  final ValueNotifier<Set<String>> _sendingSinglePlanIdsNotifier = ValueNotifier({});
  final ValueNotifier<bool> _isSendingBulkRemindersNotifier = ValueNotifier(false);

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _var2Controller = TextEditingController();
  final TextEditingController _reminderSearchController = TextEditingController();

  // Bulk sending state
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCustomersList);
    _reminderSearchController.addListener(_onReminderSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData(context);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCustomersList);
    _reminderSearchController.removeListener(_onReminderSearchChanged);
    _messageController.dispose();
    _searchController.dispose();
    _var2Controller.dispose();
    _reminderSearchController.dispose();
    super.dispose();
  }

  void _onReminderSearchChanged() {
    _reminderPlansNotifier.value = List.from(_reminderPlansNotifier.value);
  }

  Future<void> _fetchData(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isLoadingNotifier.value = true;

    final broadcastProvider = context.read<BroadcastProvider>();
    await broadcastProvider.fetchAllData(token, inactiveDays: 60);

    _allCustomersNotifier.value = broadcastProvider.allCustomers;
    _inactiveCustomersNotifier.value = broadcastProvider.inactiveCustomers;
    _templatesNotifier.value = broadcastProvider.templates;
    _reminderPlansNotifier.value = broadcastProvider.reminderPlans;

    _filterCustomersList();
    _isLoadingNotifier.value = false;
  }

  Future<void> _onInactiveDaysChanged(BuildContext context, int days) async {
    _inactiveFilterNotifier.value = days;
    if (days == 0) {
      _filterCustomersList();
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingNotifier.value = true;
    try {
      final res = await ApiService.getInactiveCustomers(token, days: days);
      if (res['success'] == true) {
        _inactiveCustomersNotifier.value = res['customers'] ?? [];
      }
    } catch (_) {} finally {
      _filterCustomersList();
      _isLoadingNotifier.value = false;
    }
  }

  void _filterCustomersList() {
    final query = _searchController.text.trim().toLowerCase();
    final filterDays = _inactiveFilterNotifier.value;
    List<dynamic> source = filterDays == 0
        ? _allCustomersNotifier.value
        : _inactiveCustomersNotifier.value;

    if (query.isNotEmpty) {
      source = source.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? c['whatsapp_number'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    _filteredCustomersNotifier.value = source;
  }

  void _applyTemplate(dynamic tpl) {
    _selectedTemplateNotifier.value = tpl;
    _messageController.text = tpl != null ? (tpl['content'] ?? '') : '';
  }

  Future<void> _sendToCustomer(BuildContext context, dynamic customer) async {
    final template = _selectedTemplateNotifier.value;
    final msgTemplate = _messageController.text.trim();
    final var2Val = _var2Controller.text.trim();

    if (msgTemplate.isEmpty) {
      _showSnack(context, context.tr('Please select a template or enter a message first.'), Colors.orange);
      return;
    }

    final custId = (customer['id'] ?? '').toString();
    final custName = (customer['name'] ?? '').toString();
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final sendingSet = Set<String>.from(_sendingCustomerIdsNotifier.value);
    sendingSet.add(custId);
    _sendingCustomerIdsNotifier.value = sendingSet;

    try {
      final templateName = template != null ? (template['wawy_template_name'] ?? '').toString() : '';

      final res = await ApiService.sendWhatsAppBroadcast(
        token,
        recipientType: 'specific_customers',
        message: msgTemplate,
        var2: var2Val,
        templateName: templateName,
        customerIds: [custId],
      );

      if (res['success'] == true && (res['sent'] ?? 0) > 0) {
        _showSnack(context, '${context.tr("Message sent to")} $custName ${context.tr("via WhatsApp API!")}', Colors.green);
      } else {
        await _launchWhatsAppDirect(context, customer, msgTemplate, var2Val);
      }
    } catch (_) {
      await _launchWhatsAppDirect(context, customer, msgTemplate, var2Val);
    } finally {
      final finalSet = Set<String>.from(_sendingCustomerIdsNotifier.value);
      finalSet.remove(custId);
      _sendingCustomerIdsNotifier.value = finalSet;
    }
  }

  Future<void> _launchWhatsAppDirect(
    BuildContext context,
    dynamic customer,
    String rawMsg,
    String var2,
  ) async {
    final custName = (customer['name'] ?? '').toString();
    final custPhone = (customer['phone'] ?? customer['whatsapp_number'] ?? '').toString();
    final branchName = context.read<AuthProvider>().branchName ?? 'our branch';

    String text = rawMsg
        .replaceAll('{{1}}', custName)
        .replaceAll('{{2}}', var2)
        .replaceAll('{{3}}', (customer['vehicle_number'] ?? customer['vehicles'] ?? '').toString())
        .replaceAll('{{4}}', custPhone)
        .replaceAll('{{5}}', branchName);

    final cleanedPhone = CountryConfig.formatPhoneForWhatsapp(custPhone);
    if (cleanedPhone.isEmpty) {
      _showSnack(context, context.tr('Invalid phone number for customer.'), Colors.red);
      return;
    }

    final whatsappUrl = Uri.parse(
      "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(text)}"
    );

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      _showSnack(context, '${context.tr("Opened WhatsApp chat for")} $custName', Colors.green);
    } catch (e) {
      _showSnack(context, '${context.tr("Could not launch WhatsApp:")} $e', Colors.red);
    }
  }

  Future<void> _sendBulkBroadcast(BuildContext context) async {
    final msg = _messageController.text.trim();
    final filteredCustomers = _filteredCustomersNotifier.value;

    if (msg.isEmpty) {
      _showSnack(context, context.tr('Please select a template or enter a message.'), Colors.orange);
      return;
    }

    if (filteredCustomers.isEmpty) {
      _showSnack(context, context.tr('No customers to send to.'), Colors.orange);
      return;
    }

    final count = filteredCustomers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send, color: Color(0xFF25D366)),
          const SizedBox(width: 10),
          Text(ctx.tr('Confirm Send'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          ctx.tr('Send WhatsApp message to $count customer(s)?'),
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(ctx.tr('Send Now'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _isSendingNotifier.value = true;
    final token = context.read<AuthProvider>().token!;
    final template = _selectedTemplateNotifier.value;
    final customerIds = filteredCustomers.map((c) => (c['id'] ?? '').toString()).toList();

    try {
      final broadcastProvider = context.read<BroadcastProvider>();
      final result = await broadcastProvider.sendBroadcast(
        token: token,
        recipientType: 'specific_customers',
        recipientPhoneNumbers: customerIds,
        templateId: template != null ? template['id']?.toString() ?? '' : '',
        var1: '',
        var2: _var2Controller.text.trim(),
        customMessage: msg,
        templateName: template != null ? (template['wawy_template_name'] ?? '').toString() : '',
      );

      _isSendingNotifier.value = false;

      if (result['success'] == true) {
        _showResultDialog(context, result);
      } else {
        _showSnack(context, result['message'] ?? context.tr('Failed to send'), Colors.red);
      }
    } catch (e) {
      _isSendingNotifier.value = false;
      _showSnack(context, e.toString(), Colors.red);
    }
  }

  Future<void> _fetchReminderPlans(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isLoadingReminderPlansNotifier.value = true;
    final broadcastProvider = context.read<BroadcastProvider>();
    broadcastProvider.setSelectedReminderDate(_selectedReminderDateNotifier.value);
    await broadcastProvider.fetchReminderPlans(token);

    _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
    _isLoadingReminderPlansNotifier.value = false;
  }

  String _buildReminderMessageText(BuildContext context, dynamic plan, String branchName) {
    final custName = (plan['customer_name'] ?? 'Customer').toString();
    final vehicleNum = (plan['vehicle_number'] ?? 'your vehicle').toString();
    final serviceName = (plan['service_name'] ?? 'service').toString();

    final nextKm = plan['next_alignment_km'] ??
        plan['next_oil_change_km'] ??
        plan['next_km'] ??
        plan['due_km'] ??
        plan['next_tyre_change_km'] ??
        (plan['service_details'] is Map ? plan['service_details']['next_alignment_km'] : null) ??
        (plan['service_details'] is Map ? plan['service_details']['next_oil_change_km'] : null) ??
        '';

    final kmStr = nextKm.toString().trim();
    final kmText = kmStr.isNotEmpty && kmStr != 'null' ? ' at $kmStr KM' : '';

    return "Dear $custName, your vehicle $vehicleNum is due for $serviceName$kmText. Visit $branchName for a smooth ride.";
  }

  Future<void> _launchDirectWhatsAppReminder(BuildContext context, dynamic plan) async {
    final custPhone = (plan['customer_phone'] ?? '').toString();
    final branchName = context.read<AuthProvider>().branchName ?? 'Mobiz Auto Care Pro';
    final text = _buildReminderMessageText(context, plan, branchName);

    final cleanedPhone = CountryConfig.formatPhoneForWhatsapp(custPhone);
    if (cleanedPhone.isEmpty) {
      _showSnack(context, context.tr('Invalid phone number for customer.'), Colors.red);
      return;
    }

    final whatsappUrl = Uri.parse("https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(text)}");

    try {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      final token = context.read<AuthProvider>().token;
      final planId = (plan['id'] ?? '').toString();
      if (token != null && planId.isNotEmpty) {
        await ApiService.sendReminders(token, [planId], action: 'mark_sent');
        _reminderPlansNotifier.value = context.read<BroadcastProvider>().reminderPlans;
      }
      if (context.mounted) {
        _showSnack(context, context.tr('Opened prefilled WhatsApp chat window.'), Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, '${context.tr("Could not launch WhatsApp:")} $e', Colors.red);
      }
    }
  }

  Future<void> _sendSingleReminder(BuildContext context, dynamic plan) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final planId = (plan['id'] ?? '').toString();
    final sendingIds = Set<String>.from(_sendingSinglePlanIdsNotifier.value);
    sendingIds.add(planId);
    _sendingSinglePlanIdsNotifier.value = sendingIds;

    final broadcastProvider = context.read<BroadcastProvider>();

    try {
      final res = await broadcastProvider.sendReminders(
        token,
        [planId],
        templateName: 'wheelalignment',
        planDetails: plan,
      );

      if (!context.mounted) return;

      if (res['success'] == true || res['status'] == 'success') {
        _showSnack(context, context.tr('Reminder sent successfully!'), Colors.green);
        _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
      } else {
        _showSnack(context, res['message'] ?? context.tr('Failed to send reminder.'), Colors.red);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, '${context.tr("Failed to send reminder:")} $e', Colors.red);
      }
    } finally {
      final finalSendingIds = Set<String>.from(_sendingSinglePlanIdsNotifier.value);
      finalSendingIds.remove(planId);
      _sendingSinglePlanIdsNotifier.value = finalSendingIds;
    }
  }

  Future<void> _sendBulkReminders(BuildContext context) async {
    final broadcastProvider = context.read<BroadcastProvider>();
    final selectedReminderIds = broadcastProvider.selectedReminderIds;

    if (selectedReminderIds.isEmpty) {
      _showSnack(context, context.tr('Please select at least one client to send reminders.'), Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send, color: Color(0xFF000080)),
          const SizedBox(width: 10),
          Text(ctx.tr('Confirm Send'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          ctx.tr('Send selected ${selectedReminderIds.length} reminder(s)?'),
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF000080),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(ctx.tr('Send'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    _isSendingBulkRemindersNotifier.value = true;

    try {
      final listToSend = selectedReminderIds.toList();
      final res = await broadcastProvider.sendReminders(token, listToSend);
      if (!context.mounted) return;

      if (res['success'] == true) {
        final sent = res['sent_count'] ?? 0;
        _showSnack(context, context.tr('Successfully sent $sent reminder(s)!'), Colors.green);
        _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
      } else {
        _showSnack(context, res['message'] ?? context.tr('Failed to send selected reminders.'), Colors.red);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, e.toString(), Colors.red);
    } finally {
      _isSendingBulkRemindersNotifier.value = false;
    }
  }

  void _showResultDialog(BuildContext context, Map<String, dynamic> result) {
    final sent = result['sent'] ?? 0;
    final failed = result['failed'] ?? 0;
    final errors = (result['errors'] as List?)?.cast<String>() ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(sent > 0 ? Icons.check_circle : Icons.error, color: sent > 0 ? Colors.green : Colors.red),
          SizedBox(width: 10),
          Text(
            sent > 0 ? ctx.tr('Messages Sent!') : ctx.tr('Send Failed'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statChip(ctx, '$sent', ctx.tr('Sent'), Colors.green),
                SizedBox(width: 12),
                if (failed > 0) _statChip(ctx, '$failed', ctx.tr('Failed'), Colors.red),
              ],
            ),
            if (errors.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(ctx.tr('Issues:'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.sp)),
              SizedBox(height: 6),
              ...errors.take(5).map((e) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.red.shade700)),
                  )),
            ]
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (sent > 0) {
                _messageController.clear();
                _var2Controller.clear();
                _selectedTemplateNotifier.value = null;
                context.read<BroadcastProvider>().clearCustomerSelections();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF000080),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(ctx.tr('Done'), style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(BuildContext context, String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 12.sp, color: color)),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(context.tr('Notifications'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Color(0xFF000080),
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.people, size: 20), text: context.tr('All')),
              Tab(icon: Icon(Icons.notifications_active, size: 20), text: context.tr('Reminders')),
            ],
          ),
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: _isLoadingNotifier,
          builder: (context, isLoading, child) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ValueListenableBuilder<String>(
              valueListenable: _errorMessageNotifier,
              builder: (context, errorMsg, child) {
                if (errorMsg.isNotEmpty) {
                  return Center(child: Text(errorMsg, style: TextStyle(color: Colors.red)));
                }

                return TabBarView(
                  children: [
                    _buildAllTab(context),
                    _buildRemindersTab(context),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── 1. ALL TAB ─────────────────────────────────────────────────────────────
  Widget _buildAllTab(BuildContext context) {
    return Column(
      children: [
        // Step 1: Select Template & Step 2: Message Autofill
        _buildTemplateAndMessageSection(context),

        // Step 3: Inactive Days Filter & Search
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.person_off_outlined, size: 16, color: Colors.orange.shade800),
                  SizedBox(width: 6),
                  Text(context.tr('Inactive for:'), style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _inactiveFilterNotifier,
                        builder: (context, activeDays, child) {
                          return Row(
                            children: [
                              _filterChip(context, 0, context.tr('All')),
                              const SizedBox(width: 6),
                              _filterChip(context, 30, '30 ${context.tr("Days")}'),
                              const SizedBox(width: 6),
                              _filterChip(context, 60, '60 ${context.tr("Days")}'),
                              const SizedBox(width: 6),
                              _filterChip(context, 90, '90 ${context.tr("Days")}'),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: context.tr('Search customer name or phone...'),
                  prefixIcon: Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filterCustomersList();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // Step 4: Customer List with Individual Send Button
        Expanded(
          child: ValueListenableBuilder<List<dynamic>>(
            valueListenable: _filteredCustomersNotifier,
            builder: (context, filteredCustomers, child) {
              if (filteredCustomers.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('No customers found.'),
                    style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: filteredCustomers.length,
                itemBuilder: (_, i) => _customerRowTile(context, filteredCustomers[i]),
              );
            },
          ),
        ),

        // Bulk Send Bar at Bottom
        _buildSendBar(context),
      ],
    );
  }

  Widget _buildTemplateAndMessageSection(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: _selectedTemplateNotifier,
      builder: (context, selectedTemplate, child) {
        final hasVar2 = _messageController.text.contains('{{2}}');

        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 1: Select Template
              ValueListenableBuilder<List<dynamic>>(
                valueListenable: _templatesNotifier,
                builder: (context, templates, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('1. Select Template'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Color(0xFF000080)),
                      ),
                      SizedBox(height: 5),
                      DropdownButtonFormField<dynamic>(
                        value: selectedTemplate,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                        ),
                        hint: Text(context.tr('-- Select a template --'), style: GoogleFonts.inter(fontSize: 13.sp)),
                        items: [
                          DropdownMenuItem(value: null, child: Text(context.tr('-- Select a template --'), style: GoogleFonts.inter(fontSize: 13.sp))),
                          ...templates.map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t['name'] ?? '', style: GoogleFonts.inter(fontSize: 13.sp)),
                              )),
                        ],
                        onChanged: (val) {
                          _applyTemplate(val);
                        },
                      ),
                    ],
                  );
                },
              ),

              // Step 2: Message Autofill (only shown when template selected)
              if (selectedTemplate != null) ...[
                SizedBox(height: 12),
                Text(
                  context.tr('2. Message Autofill'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.sp, color: Color(0xFF000080)),
                ),
                SizedBox(height: 5),
                if (hasVar2) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFF000080),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('{{2}}', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _var2Controller,
                            style: GoogleFonts.inter(fontSize: 13.sp),
                            decoration: InputDecoration(
                              hintText: context.tr('Free Service / Offer / Festival Name...'),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: context.tr('Template content...'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '{{1}}=Name  {{2}}=Offer  {{3}}=Vehicle  {{4}}=Phone  {{5}}=Branch',
                  style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.grey.shade400),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(BuildContext context, int days, String label) {
    final isSelected = _inactiveFilterNotifier.value == days;
    return GestureDetector(
      onTap: () => _onInactiveDaysChanged(context, days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000080) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF000080) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _customerRowTile(BuildContext context, dynamic customer) {
    final custId = (customer['id'] ?? '').toString();
    final name = customer['name'] ?? '';
    final phone = customer['phone'] ?? customer['whatsapp_number'] ?? '';

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _sendingCustomerIdsNotifier,
      builder: (context, sendingIds, child) {
        final isSendingThis = sendingIds.contains(custId);

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Icon(Icons.person, color: const Color(0xFF000080), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        phone,
                        style: GoogleFonts.inter(fontSize: 11.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isSendingThis ? null : () => _sendToCustomer(context, customer),
                  icon: isSendingThis
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send, size: 14, color: Colors.white),
                  label: Text(
                    context.tr('Send'),
                    style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSendingNotifier,
              builder: (context, isSending, child) {
                final count = _filteredCustomersNotifier.value.length;
                return ElevatedButton.icon(
                  onPressed: isSending ? null : () => _sendBulkBroadcast(context),
                  icon: isSending
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send, color: Colors.white),
                  label: Text("${context.tr('Send All')} ($count)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF000080),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. REMINDERS TAB ───────────────────────────────────────────────────────
  List<dynamic> _filteredReminderPlans() {
    final query = _reminderSearchController.text.trim().toLowerCase();
    final plans = _reminderPlansNotifier.value;
    if (query.isEmpty) return plans;
    return plans.where((p) {
      final name = (p['customer_name'] ?? '').toString().toLowerCase();
      final phone = (p['customer_phone'] ?? '').toString().toLowerCase();
      final vehicleNum = (p['vehicle_number'] ?? '').toString().toLowerCase();
      final serviceName = (p['service_name'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query) || vehicleNum.contains(query) || serviceName.contains(query);
    }).toList();
  }

  Widget _buildRemindersTab(BuildContext context) {
    final broadcastProvider = context.watch<BroadcastProvider>();
    final selectedReminderIds = broadcastProvider.selectedReminderIds;
    final isShowAll = broadcastProvider.showAllReminders;

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _reminderPlansNotifier,
      builder: (context, reminderPlans, child) {
        final filteredPlans = _filteredReminderPlans();
        final allSelected = filteredPlans.isNotEmpty &&
            filteredPlans.every((p) => selectedReminderIds.contains(p['id']?.toString()));

        return Column(
          children: [
            // ── 1. Date Filter Segment Controls ─────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: ValueListenableBuilder<DateTime>(
                valueListenable: _selectedReminderDateNotifier,
                builder: (context, selectedReminderDate, child) {
                  final now = DateTime.now();
                  final isTodaySelected = !isShowAll &&
                      selectedReminderDate.year == now.year &&
                      selectedReminderDate.month == now.month &&
                      selectedReminderDate.day == now.day;
                  final isCustomDateSelected = !isShowAll && !isTodaySelected;

                  final formattedCustomDate =
                      "${selectedReminderDate.day.toString().padLeft(2, '0')}/${selectedReminderDate.month.toString().padLeft(2, '0')}/${selectedReminderDate.year}";

                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Today Pill
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final today = DateTime.now();
                              _selectedReminderDateNotifier.value = today;
                              context.read<BroadcastProvider>().setSelectedReminderDate(today);
                              _fetchReminderPlans(context);
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isTodaySelected ? const Color(0xFF000080) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isTodaySelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF000080).withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.today, size: 14.r, color: isTodaySelected ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.tr('Today'),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: isTodaySelected ? FontWeight.w700 : FontWeight.w600,
                                      color: isTodaySelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Select Date Pill
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedReminderDateNotifier.value,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                _selectedReminderDateNotifier.value = picked;
                                context.read<BroadcastProvider>().setSelectedReminderDate(picked);
                                _fetchReminderPlans(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isCustomDateSelected ? const Color(0xFF000080) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isCustomDateSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF000080).withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month_outlined, size: 14.r, color: isCustomDateSelected ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      isCustomDateSelected ? formattedCustomDate : context.tr('Select Date'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        fontWeight: isCustomDateSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isCustomDateSelected ? Colors.white : const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // All Reminders Pill
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              context.read<BroadcastProvider>().setShowAllReminders(true);
                              _fetchReminderPlans(context);
                            },
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: isShowAll ? const Color(0xFF000080) : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isShowAll
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF000080).withValues(alpha: 0.2),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('All'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    fontWeight: isShowAll ? FontWeight.w700 : FontWeight.w600,
                                    color: isShowAll ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── 2. Search & Select All Bar ──────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _reminderSearchController,
                      style: GoogleFonts.inter(fontSize: 13.sp),
                      decoration: InputDecoration(
                        hintText: context.tr('Search customer, phone or vehicle...'),
                        hintStyle: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: _reminderSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _reminderSearchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredPlans.length} ${context.tr("reminders")}',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3730A3),
                              ),
                            ),
                          ),
                          if (selectedReminderIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedReminderIds.length} ${context.tr("selected")}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          if (allSelected) {
                            context.read<BroadcastProvider>().clearReminderSelections();
                          } else {
                            context.read<BroadcastProvider>().selectAllReminders(filteredPlans);
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              context.tr('Select All'),
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF000080),
                              ),
                            ),
                            Checkbox(
                              value: allSelected,
                              onChanged: (val) {
                                if (val == true) {
                                  context.read<BroadcastProvider>().selectAllReminders(filteredPlans);
                                } else {
                                  context.read<BroadcastProvider>().clearReminderSelections();
                                }
                              },
                              activeColor: const Color(0xFF000080),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── 3. Reminder List Cards ──────────────────────────────────
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingReminderPlansNotifier,
                builder: (context, isLoadingReminderPlans, child) {
                  if (isLoadingReminderPlans) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (filteredPlans.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 56.r, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('No due reminders found'),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.sp,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('Select a different date or clear search filters.'),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: filteredPlans.length,
                    itemBuilder: (context, index) {
                      final plan = filteredPlans[index];
                      return _reminderCardTile(context, plan);
                    },
                  );
                },
              ),
            ),

            // ── 4. Floating Footer Action Bar ───────────────────────────
            _buildRemindersSendBar(context),
          ],
        );
      },
    );
  }

  Widget _reminderCardTile(BuildContext context, dynamic plan) {
    final broadcastProvider = context.watch<BroadcastProvider>();
    final selectedReminderIds = broadcastProvider.selectedReminderIds;
    final planId = (plan['id'] ?? '').toString();
    final isSelected = selectedReminderIds.contains(planId);
    final isSent = plan['is_sent'] == true;
    final reminderDate = plan['formatted_date'] ?? plan['scheduled_date'] ?? 'N/A';
    final custName = plan['customer_name'] ?? 'Customer';
    final custPhone = plan['customer_phone'] ?? 'No Phone';
    final vehicleNum = plan['vehicle_number'] ?? 'N/A';
    final serviceName = plan['service_name'] ?? 'Service';
    final serviceCategory = (plan['service_category'] ?? '').toString().toLowerCase();

    // Determine category accent color & icon
    IconData categoryIcon = Icons.build_circle_outlined;
    Color categoryBg = const Color(0xFFEFF6FF);
    Color categoryText = const Color(0xFF1D4ED8);

    if (serviceCategory.contains('oil') || plan['next_oil_change_km'] != null) {
      categoryIcon = Icons.water_drop_outlined;
      categoryBg = const Color(0xFFFFFBEB);
      categoryText = const Color(0xFFB45309);
    } else if (serviceCategory.contains('wheel') || serviceCategory.contains('align')) {
      categoryIcon = Icons.tire_repair_outlined;
      categoryBg = const Color(0xFFECFDF5);
      categoryText = const Color(0xFF047857);
    } else if (serviceCategory.contains('wash') || serviceCategory.contains('detail')) {
      categoryIcon = Icons.local_car_wash_outlined;
      categoryBg = const Color(0xFFF0FDF4);
      categoryText = const Color(0xFF15803D);
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _sendingSinglePlanIdsNotifier,
      builder: (context, sendingSinglePlanIds, child) {
        final isSendingSingle = sendingSinglePlanIds.contains(planId);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF000080) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8.r,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Opacity(
            opacity: isSent ? 0.75 : 1.0,
            child: Column(
            children: [
              // Top Row: Checkbox + Customer Info + Date Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 12, 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF000080),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        context.read<BroadcastProvider>().toggleReminderSelection(planId);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            custName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.sp,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12.r, color: const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                custPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Sent Badge or Due Date Badge
                    isSent
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12.r, color: const Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('Sent'),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 12.r, color: const Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Text(
                              reminderDate,
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // Middle Row: Vehicle Chip + Service Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Vehicle Number Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car, size: 13.r, color: const Color(0xFF334155)),
                          const SizedBox(width: 4),
                          Text(
                            vehicleNum,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Service Category Badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(categoryIcon, size: 13.r, color: categoryText),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                serviceName,
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: categoryText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Optional Oil KM Badge if applicable
              if (plan['next_oil_change_km'] != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Icon(Icons.speed, size: 12.r, color: const Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        "${context.tr('Next Oil Change Due:')} ${plan['next_oil_change_km']} KM",
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

              // Bottom Row: Action Buttons (WhatsApp Chat, API Send, Mark Sent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // WhatsApp Chat Button
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchDirectWhatsAppReminder(context, plan),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 14.r, color: const Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('WhatsApp Chat'),
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send API Button
                    Expanded(
                      child: InkWell(
                        onTap: isSendingSingle ? null : () => _sendSingleReminder(context, plan),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000080),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: isSendingSingle
                                ? SizedBox(
                                    width: 14.r,
                                    height: 14.r,
                                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_outlined, size: 14.r, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.tr('Send'),
                                        style: GoogleFonts.inter(
                                          fontSize: 11.sp,
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
                    const SizedBox(width: 8),

                    // Mark Sent Action Button
                    // InkWell(
                    //   onTap: () async {
                    //     final token = context.read<AuthProvider>().token;
                    //     if (token != null) {
                    //       await broadcastProvider.sendReminders(token, [planId], action: 'mark_sent');
                    //       _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
                    //     }
                    //   },
                    //   borderRadius: BorderRadius.circular(8),
                    //   child: Container(
                    //     padding: const EdgeInsets.all(8),
                    //     decoration: BoxDecoration(
                    //       color: const Color(0xFFF1F5F9),
                    //       borderRadius: BorderRadius.circular(8),
                    //       border: Border.all(color: const Color(0xFFCBD5E1)),
                    //     ),
                    //     child: Icon(
                    //       Icons.check_circle_outline,
                    //       size: 16.r,
                    //       color: const Color(0xFF64748B),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildRemindersSendBar(BuildContext context) {
    final broadcastProvider = context.watch<BroadcastProvider>();
    final selectedReminderIds = broadcastProvider.selectedReminderIds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _isSendingBulkRemindersNotifier,
          builder: (context, isSendingBulkReminders, child) {
            final hasSelection = selectedReminderIds.isNotEmpty;

            return ElevatedButton.icon(
              onPressed: hasSelection && !isSendingBulkReminders ? () => _sendBulkReminders(context) : null,
              icon: isSendingBulkReminders
                  ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_and_archive, color: Colors.white, size: 18.r),
              label: Text(
                hasSelection
                    ? "${context.tr('Send Selected')} (${selectedReminderIds.length})"
                    : context.tr('Select Reminders to Send'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                disabledBackgroundColor: Colors.grey.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            );
          },
        ),
      ),
    );
  }
}

