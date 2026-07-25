import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Sending state
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier(false);
  final ValueNotifier<int> _inactiveDaysNotifier = ValueNotifier(60);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _reminderSearchController.addListener(_onReminderSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData(context);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _reminderSearchController.removeListener(_onReminderSearchChanged);
    _messageController.dispose();
    _searchController.dispose();
    _var2Controller.dispose();
    _reminderSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final mode = context.read<BroadcastProvider>().mode;
    _filterCustomers(mode);
  }

  void _onReminderSearchChanged() {
    _reminderPlansNotifier.value = List.from(_reminderPlansNotifier.value);
  }

  Future<void> _fetchData(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isLoadingNotifier.value = true;

    final broadcastProvider = context.read<BroadcastProvider>();
    await broadcastProvider.fetchAllData(token, inactiveDays: _inactiveDaysNotifier.value);

    _allCustomersNotifier.value = broadcastProvider.allCustomers;
    _inactiveCustomersNotifier.value = broadcastProvider.inactiveCustomers;
    _templatesNotifier.value = broadcastProvider.templates;
    _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
    
    final mode = broadcastProvider.mode;
    if (mode == RecipientMode.inactiveCustomers) {
      _filteredCustomersNotifier.value = List.from(broadcastProvider.inactiveCustomers);
    } else {
      _filteredCustomersNotifier.value = List.from(broadcastProvider.allCustomers);
    }

    _isLoadingNotifier.value = false;
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

  Future<void> _sendSingleReminder(BuildContext context, dynamic plan) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    
    final planId = plan['id'] as String;
    final sendingIds = Set<String>.from(_sendingSinglePlanIdsNotifier.value);
    sendingIds.add(planId);
    _sendingSinglePlanIdsNotifier.value = sendingIds;

    final broadcastProvider = context.read<BroadcastProvider>();

    try {
      final res = await broadcastProvider.sendReminders(token, [planId]);
      if (!context.mounted) return;

      if (res['success'] == true) {
        _showSnack(context, context.tr('Reminder sent successfully!'), Colors.green);
        _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
      } else if (res['use_fallback'] == true && res['whatsapp_url'] != null) {
        final whatsappUrl = Uri.parse(res['whatsapp_url'] as String);
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        await ApiService.sendReminders(token, [planId], action: 'mark_sent');

        if (context.mounted) {
          _showSnack(context, context.tr('Opened prefilled WhatsApp chat window.'), Colors.green);
          _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
        }
      } else {
        _showSnack(context, res['message'] ?? context.tr('Failed to send reminder.'), Colors.red);
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, e.toString(), Colors.red);
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
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
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

  Future<void> _refreshInactive(BuildContext context) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    _isLoadingNotifier.value = true;

    try {
      final res = await ApiService.getInactiveCustomers(token, days: _inactiveDaysNotifier.value);
      if (res['success'] == true) {
        final list = res['customers'] ?? [];
        _inactiveCustomersNotifier.value = list;
        _filteredCustomersNotifier.value = List.from(list);
      }
    } catch (_) {} finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _filterCustomers(RecipientMode mode) {
    final query = _searchController.text.toLowerCase();
    final source = mode == RecipientMode.inactiveCustomers ? _inactiveCustomersNotifier.value : _allCustomersNotifier.value;
    _filteredCustomersNotifier.value = source.where((c) {
      final name = (c['name'] ?? '').toLowerCase();
      final phone = (c['phone'] ?? '').toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  void _applyTemplate(dynamic tpl) {
    _selectedTemplateNotifier.value = tpl;
    _messageController.text = tpl['content'] ?? '';
  }

  void _toggleSelectAll(BuildContext context, bool? value) {
    final broadcastProvider = context.read<BroadcastProvider>();
    if (value == true) {
      broadcastProvider.selectAllCustomers(_filteredCustomersNotifier.value);
    } else {
      broadcastProvider.clearCustomerSelections();
    }
  }

  int _recipientCount(BuildContext context) {
    final broadcastProvider = context.read<BroadcastProvider>();
    final mode = broadcastProvider.mode;
    if (mode == RecipientMode.allCustomers) return _allCustomersNotifier.value.length;
    if (mode == RecipientMode.inactiveCustomers) return _inactiveCustomersNotifier.value.length;
    return broadcastProvider.selectedCustomerIds.length;
  }

  String _recipientTypeStr(RecipientMode mode) {
    switch (mode) {
      case RecipientMode.allCustomers: return 'all_customers';
      case RecipientMode.specificCustomers: return 'specific_customers';
      case RecipientMode.inactiveCustomers: return 'inactive_customers';
      case RecipientMode.reminders: return 'reminders';
    }
  }

  Future<void> _sendBroadcast(BuildContext context) async {
    final msg = _messageController.text.trim();
    final broadcastProvider = context.read<BroadcastProvider>();
    final mode = broadcastProvider.mode;
    final selectedCustomerIds = broadcastProvider.selectedCustomerIds;

    if (msg.isEmpty) {
      _showSnack(context, context.tr('Please enter a message.'), Colors.orange);
      return;
    }
    if (mode == RecipientMode.specificCustomers && selectedCustomerIds.isEmpty) {
      _showSnack(context, context.tr('Please select at least one customer.'), Colors.orange);
      return;
    }
    
    final count = _recipientCount(context);
    if (count == 0) {
      _showSnack(context, context.tr('No customers to send to.'), Colors.orange);
      return;
    }

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
          ctx.tr('Send WhatsApp message to $count customer(s) automatically?'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(ctx.tr('Send Now'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _isSendingNotifier.value = true;

    try {
      final token = context.read<AuthProvider>().token!;
      final result = await broadcastProvider.sendBroadcast(
        token: token,
        recipientType: _recipientTypeStr(mode),
        recipientPhoneNumbers: selectedCustomerIds.toList(),
        templateId: _selectedTemplateNotifier.value != null ? _selectedTemplateNotifier.value['id']?.toString() ?? '' : '',
        var1: '',
        var2: _var2Controller.text.trim(),
        customMessage: msg,
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
          const SizedBox(width: 10),
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
                const SizedBox(width: 12),
                if (failed > 0) _statChip(ctx, '$failed', ctx.tr('Failed'), Colors.red),
              ],
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(ctx.tr('Issues:'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              ...errors.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e', style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700)),
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
              backgroundColor: const Color(0xFF000080),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: color)),
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
    final broadcastProvider = context.watch<BroadcastProvider>();
    final mode = broadcastProvider.mode;

    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          tabController.addListener(() {
            if (!tabController.indexIsChanging) {
              context.read<BroadcastProvider>().clearCustomerSelections();
              context.read<BroadcastProvider>().clearReminderSelections();
              switch (tabController.index) {
                case 0:
                  context.read<BroadcastProvider>().setMode(RecipientMode.allCustomers);
                  _filteredCustomersNotifier.value = List.from(_allCustomersNotifier.value);
                  break;
                case 1:
                  context.read<BroadcastProvider>().setMode(RecipientMode.specificCustomers);
                  _filteredCustomersNotifier.value = List.from(_allCustomersNotifier.value);
                  break;
                case 2:
                  context.read<BroadcastProvider>().setMode(RecipientMode.inactiveCustomers);
                  _filteredCustomersNotifier.value = List.from(_inactiveCustomersNotifier.value);
                  break;
                case 3:
                  context.read<BroadcastProvider>().setMode(RecipientMode.reminders);
                  break;
              }
            }
          });

          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            appBar: AppBar(
              title: Text(context.tr('Notifications'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              bottom: TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(icon: const Icon(Icons.people, size: 18), text: context.tr('All')),
                  Tab(icon: const Icon(Icons.checklist, size: 18), text: context.tr('Specific')),
                  Tab(icon: const Icon(Icons.person_off, size: 18), text: context.tr('Inactive')),
                  Tab(icon: const Icon(Icons.notifications_active, size: 18), text: context.tr('Reminders')),
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
                      return Center(child: Text(errorMsg, style: const TextStyle(color: Colors.red)));
                    }

                    return Column(
                      children: [
                        if (mode != RecipientMode.reminders) _buildMessageComposer(context),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildAllTab(context),
                              _buildSpecificTab(context),
                              _buildInactiveTab(context),
                              _buildRemindersTab(context),
                            ],
                          ),
                        ),
                        if (mode != RecipientMode.reminders) _buildSendBar(context),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageComposer(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: _selectedTemplateNotifier,
      builder: (context, selectedTemplate, child) {
        final hasVar2 = _messageController.text.contains('{{2}}');

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<List<dynamic>>(
                valueListenable: _templatesNotifier,
                builder: (context, templates, child) {
                  if (templates.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('Template'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<dynamic>(
                          value: selectedTemplate,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          hint: Text(context.tr('-- Select a template --'), style: GoogleFonts.inter(fontSize: 13)),
                          items: [
                            DropdownMenuItem(value: null, child: Text(context.tr('-- No template --'))),
                            ...templates.map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t['name'] ?? '', style: GoogleFonts.inter(fontSize: 13)),
                                )),
                          ],
                          onChanged: (val) {
                            if (val == null) {
                              _selectedTemplateNotifier.value = null;
                              _messageController.clear();
                            } else {
                              _applyTemplate(val);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              if (hasVar2) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          color: const Color(0xFF000080),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('{{2}}', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _var2Controller,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: context.tr('Service / offer name...'),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Text(context.tr('Message'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 5),
              TextField(
                controller: _messageController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: context.tr('Type message or select template...'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '{{1}}=Name  {{2}}=Service  {{3}}=Vehicle  {{4}}=WA No  {{5}}=Branch',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllTab(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _allCustomersNotifier,
      builder: (context, allCustomers, child) {
        return Column(
          children: [
            _buildBanner(
              context,
              '${allCustomers.length} ${context.tr('customers — all will receive this message')}',
              Colors.blue.shade700,
              Icons.people,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: allCustomers.length,
                itemBuilder: (_, i) => _customerTile(context, allCustomers[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpecificTab(BuildContext context) {
    final broadcastProvider = context.watch<BroadcastProvider>();
    final selectedCustomerIds = broadcastProvider.selectedCustomerIds;

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _filteredCustomersNotifier,
      builder: (context, filteredCustomers, child) {
        final allSelected = filteredCustomers.isNotEmpty &&
            filteredCustomers.every((c) => selectedCustomerIds.contains(c['id']?.toString()));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: context.tr('Search customers...'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${selectedCustomerIds.length} ${context.tr('selected')}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  Row(children: [
                    Text(context.tr('All'), style: GoogleFonts.inter(fontSize: 12)),
                    Checkbox(
                        value: allSelected,
                        onChanged: (val) => _toggleSelectAll(context, val),
                        activeColor: const Color(0xFF000080)),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: filteredCustomers.length,
                itemBuilder: (_, i) {
                  final c = filteredCustomers[i];
                  final isSelected = selectedCustomerIds.contains(c['id']?.toString());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      title: Text(c['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(c['phone'] ?? '', style: GoogleFonts.inter(fontSize: 11)),
                      value: isSelected,
                      activeColor: const Color(0xFF000080),
                      onChanged: (val) {
                        context.read<BroadcastProvider>().toggleCustomerSelection(c['id']?.toString() ?? '');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInactiveTab(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(context.tr('Inactive for'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              ...[30, 60, 90, 180].map((d) {
                return ValueListenableBuilder<int>(
                  valueListenable: _inactiveDaysNotifier,
                  builder: (context, inactiveDays, child) {
                    final sel = inactiveDays == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          _inactiveDaysNotifier.value = d;
                          _refreshInactive(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF000080) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$d ${context.tr('Days')}',
                              style: GoogleFonts.inter(fontSize: 11, color: sel ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
        ValueListenableBuilder<List<dynamic>>(
          valueListenable: _inactiveCustomersNotifier,
          builder: (context, inactiveCustomers, child) {
            return Column(
              children: [
                _buildBanner(
                  context,
                  '${inactiveCustomers.length} ${context.tr('customers inactive — all will receive message')}',
                  Colors.orange.shade700,
                  Icons.person_off,
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: inactiveCustomers.length,
                    itemBuilder: (_, i) => _customerTile(context, inactiveCustomers[i]),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

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

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _reminderPlansNotifier,
      builder: (context, reminderPlans, child) {
        final filteredPlans = _filteredReminderPlans();
        final allSelected = filteredPlans.isNotEmpty &&
            filteredPlans.every((p) => selectedReminderIds.contains(p['id']?.toString()));

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Color(0xFF000080)),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('Select Date:'),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                  const SizedBox(width: 10),
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
                          _fetchReminderPlans(context);
                        }
                      },
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: _selectedReminderDateNotifier,
                        builder: (context, selectedReminderDate, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${selectedReminderDate.day.toString().padLeft(2, '0')}-${selectedReminderDate.month.toString().padLeft(2, '0')}-${selectedReminderDate.year}",
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const Icon(Icons.arrow_drop_down, size: 20),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: _reminderSearchController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: context.tr('Search customer or vehicle...'),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
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
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${selectedReminderIds.length} ${context.tr('selected')}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  Row(children: [
                    Text(context.tr('All'), style: GoogleFonts.inter(fontSize: 12)),
                    Checkbox(
                        value: allSelected,
                        onChanged: (val) {
                          if (val == true) {
                            context.read<BroadcastProvider>().selectAllReminders(filteredPlans);
                          } else {
                            context.read<BroadcastProvider>().clearReminderSelections();
                          }
                        },
                        activeColor: const Color(0xFF000080)),
                  ]),
                ],
              ),
            ),

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
                          Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(context.tr('No reminders found for this date.'), style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredPlans.length,
                    itemBuilder: (context, index) {
                      final plan = filteredPlans[index];
                      final planId = plan['id']?.toString() ?? '';
                      final isSelected = selectedReminderIds.contains(planId);

                      return ValueListenableBuilder<Set<String>>(
                        valueListenable: _sendingSinglePlanIdsNotifier,
                        builder: (context, sendingSinglePlanIds, child) {
                          final isSendingSingle = sendingSinglePlanIds.contains(planId);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF000080),
                                    onChanged: (val) {
                                      context.read<BroadcastProvider>().toggleReminderSelection(planId);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(plan['customer_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B))),
                                        const SizedBox(height: 2),
                                        Text(plan['customer_phone'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
                                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                                        Row(
                                          children: [
                                            const Icon(Icons.directions_car, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Text(plan['vehicle_number'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                                            const SizedBox(width: 14),
                                            const Icon(Icons.build, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Text(plan['service_name'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569))),
                                          ],
                                        ),
                                        if (plan['service_category'] == 'oil_change' || plan['next_oil_change_km'] != null) ...[
                                           const SizedBox(height: 6),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                             decoration: BoxDecoration(
                                               color: const Color(0xFFFFFBEB),
                                               borderRadius: BorderRadius.circular(6),
                                               border: Border.all(color: const Color(0xFFFCD34D)),
                                             ),
                                             child: Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 const Icon(Icons.opacity, size: 14, color: Color(0xFFD97706)),
                                                 const SizedBox(width: 6),
                                                 Text(
                                                   "${context.tr('Oil Reminder')} • ${context.tr('Next KM:')} ${plan['next_oil_change_km'] ?? 'N/A'}",
                                                   style: GoogleFonts.inter(
                                                     fontSize: 11,
                                                     color: const Color(0xFFB45309),
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                         ] else if (plan['next_run_km'] != null) ...[
                                           const SizedBox(height: 6),
                                           Row(
                                             children: [
                                               const Icon(Icons.speed, size: 14, color: Color(0xFF64748B)),
                                               const SizedBox(width: 6),
                                               Text("${context.tr('Next Service:')} ${plan['next_run_km']} KM", style: GoogleFonts.inter(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
                                             ],
                                           ),
                                         ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      IconButton(
                                        onPressed: isSendingSingle ? null : () => _sendSingleReminder(context, plan),
                                        icon: isSendingSingle
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF000080)))
                                            : const Icon(Icons.send, color: Color(0xFF25D366)),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final token = context.read<AuthProvider>().token;
                                          if (token != null) {
                                            await broadcastProvider.sendReminders(token, [planId], action: 'mark_sent');
                                            _reminderPlansNotifier.value = broadcastProvider.reminderPlans;
                                          }
                                        },
                                        icon: const Icon(Icons.check_circle_outline, color: Colors.grey),
                                        tooltip: context.tr('Mark as sent'),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _buildRemindersSendBar(context),
          ],
        );
      },
    );
  }

  Widget _buildRemindersSendBar(BuildContext context) {
    final broadcastProvider = context.watch<BroadcastProvider>();
    final selectedReminderIds = broadcastProvider.selectedReminderIds;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSendingBulkRemindersNotifier,
              builder: (context, isSendingBulkReminders, child) {
                return ElevatedButton.icon(
                  onPressed: selectedReminderIds.isEmpty || isSendingBulkReminders ? null : () => _sendBulkReminders(context),
                  icon: isSendingBulkReminders
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_and_archive, color: Colors.white),
                  label: Text("${context.tr('Send Selected')} (${selectedReminderIds.length})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildSendBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSendingNotifier,
              builder: (context, isSending, child) {
                return ElevatedButton.icon(
                  onPressed: isSending ? null : () => _sendBroadcast(context),
                  icon: isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text("${context.tr('Send Notifications')} (${_recipientCount(context)})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildBanner(BuildContext context, String text, Color color, IconData icon) {
    return Container(
      color: color.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          )
        ],
      ),
    );
  }

  Widget _customerTile(BuildContext context, dynamic c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade100)),
      child: ListTile(
        dense: true,
        title: Text(c['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(c['phone'] ?? '', style: GoogleFonts.inter(fontSize: 11)),
      ),
    );
  }
}
