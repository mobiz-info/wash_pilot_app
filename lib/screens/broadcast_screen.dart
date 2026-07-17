import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

enum RecipientMode { allCustomers, specificCustomers, inactiveCustomers, reminders }

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});
  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RecipientMode _mode = RecipientMode.allCustomers;

  // ── Data ───────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _allCustomers = [];
  List<dynamic> _inactiveCustomers = [];
  List<dynamic> _filteredCustomers = [];
  Set<String> _selectedCustomerIds = {};
  List<dynamic> _templates = [];
  dynamic _selectedTemplate;

  // ── Reminders state ────────────────────────────────────────────────────────
  List<dynamic> _reminderPlans = [];
  bool _isLoadingReminderPlans = false;
  DateTime _selectedReminderDate = DateTime.now();
  final Set<String> _selectedReminderIds = {};
  final Set<String> _sendingSinglePlanIds = {};
  bool _isSendingBulkReminders = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _var2Controller = TextEditingController();
  final _reminderSearchController = TextEditingController();

  // ── Sending state ──────────────────────────────────────────────────────────
  bool _isSending = false;
  int _inactiveDays = 60;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCustomerIds.clear();
          _selectedReminderIds.clear();
          switch (_tabController.index) {
            case 0:
              _mode = RecipientMode.allCustomers;
              _filteredCustomers = List.from(_allCustomers);
              break;
            case 1:
              _mode = RecipientMode.specificCustomers;
              _filteredCustomers = List.from(_allCustomers);
              break;
            case 2:
              _mode = RecipientMode.inactiveCustomers;
              _filteredCustomers = List.from(_inactiveCustomers);
              break;
            case 3:
              _mode = RecipientMode.reminders;
              break;
          }
        });
      }
    });
    _fetchData();
    _searchController.addListener(_filterCustomers);
    _reminderSearchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _var2Controller.dispose();
    _reminderSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        ApiService.listCustomers(token),
        ApiService.getInactiveCustomers(token, days: _inactiveDays),
        ApiService.getWhatsAppTemplates(token),
        ApiService.getReminderPlans(token),
      ]);
      setState(() {
        if (results[0]['success'] == true) _allCustomers = results[0]['customers'] ?? [];
        if (results[1]['success'] == true) _inactiveCustomers = results[1]['customers'] ?? [];
        if (results[2]['success'] == true) _templates = results[2]['templates'] ?? [];
        if (results[3]['success'] == true) _reminderPlans = results[3]['plans'] ?? [];
        _filteredCustomers = List.from(_allCustomers);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReminderPlans() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => _isLoadingReminderPlans = true);
    try {
      final dateStr = "${_selectedReminderDate.year}-${_selectedReminderDate.month.toString().padLeft(2, '0')}-${_selectedReminderDate.day.toString().padLeft(2, '0')}";
      final res = await ApiService.getReminderPlans(token, date: dateStr);
      setState(() {
        if (res['success'] == true) {
          _reminderPlans = res['plans'] ?? [];
        }
        _isLoadingReminderPlans = false;
      });
    } catch (_) {
      setState(() => _isLoadingReminderPlans = false);
    }
  }

  Future<void> _sendSingleReminder(dynamic plan) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    
    final planId = plan['id'] as String;
    setState(() => _sendingSinglePlanIds.add(planId));

    try {
      final res = await ApiService.sendReminders(token, [planId]);
      if (!mounted) return;

      if (res['success'] == true) {
        _showSnack(context.tr('Reminder sent successfully!'), Colors.green);
        setState(() {
          _reminderPlans.removeWhere((p) => p['id'] == planId);
          _selectedReminderIds.remove(planId);
        });
      } else if (res['use_fallback'] == true && res['whatsapp_url'] != null) {
        // Launch whatsapp
        final whatsappUrl = Uri.parse(res['whatsapp_url'] as String);
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);

        // Mark as sent in background
        await ApiService.sendReminders(token, [planId], action: 'mark_sent');

        if (mounted) {
          _showSnack(context.tr('Opened prefilled WhatsApp chat window.'), Colors.green);
          setState(() {
            _reminderPlans.removeWhere((p) => p['id'] == planId);
            _selectedReminderIds.remove(planId);
          });
        }
      } else {
        _showSnack(res['message'] ?? context.tr('Failed to send reminder.'), Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() => _sendingSinglePlanIds.remove(planId));
      }
    }
  }

  Future<void> _sendBulkReminders() async {
    if (_selectedReminderIds.isEmpty) {
      _showSnack(context.tr('Please select at least one client to send reminders.'), Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send, color: Color(0xFF000080)),
          const SizedBox(width: 10),
          Text(context.tr('Confirm Send'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          context.tr('Send selected ${_selectedReminderIds.length} reminder(s)?'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('Send'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _isSendingBulkReminders = true);

    try {
      final listToSend = _selectedReminderIds.toList();
      final res = await ApiService.sendReminders(token, listToSend);
      if (!mounted) return;

      if (res['success'] == true) {
        final sent = res['sent_count'] ?? 0;
        _showSnack(context.tr('Successfully sent $sent reminder(s)!'), Colors.green);
        setState(() {
          _reminderPlans.removeWhere((p) => listToSend.contains(p['id']));
          _selectedReminderIds.clear();
        });
      } else {
        _showSnack(res['message'] ?? context.tr('Failed to send selected reminders.'), Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSendingBulkReminders = false);
      }
    }
  }

  Future<void> _refreshInactive() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getInactiveCustomers(token, days: _inactiveDays);
      setState(() {
        if (res['success'] == true) _inactiveCustomers = res['customers'] ?? [];
        _filteredCustomers = List.from(_inactiveCustomers);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    final source = _mode == RecipientMode.inactiveCustomers ? _inactiveCustomers : _allCustomers;
    setState(() {
      _filteredCustomers = source.where((c) {
        final name = (c['name'] ?? '').toLowerCase();
        final phone = (c['phone'] ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _applyTemplate(dynamic tpl) {
    setState(() => _selectedTemplate = tpl);
    _messageController.text = tpl['content'] ?? '';
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        for (var c in _filteredCustomers) _selectedCustomerIds.add(c['id']);
      } else {
        for (var c in _filteredCustomers) _selectedCustomerIds.remove(c['id']);
      }
    });
  }

  int get _recipientCount {
    if (_mode == RecipientMode.allCustomers) return _allCustomers.length;
    if (_mode == RecipientMode.inactiveCustomers) return _inactiveCustomers.length;
    return _selectedCustomerIds.length;
  }

  String get _recipientTypeStr {
    switch (_mode) {
      case RecipientMode.allCustomers: return 'all_customers';
      case RecipientMode.specificCustomers: return 'specific_customers';
      case RecipientMode.inactiveCustomers: return 'inactive_customers';
      case RecipientMode.reminders: return 'reminders';
    }
  }

  // ── SEND via API ───────────────────────────────────────────────────────────
  Future<void> _sendBroadcast() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      _showSnack(context.tr('Please enter a message.'), Colors.orange);
      return;
    }
    if (_mode == RecipientMode.specificCustomers && _selectedCustomerIds.isEmpty) {
      _showSnack(context.tr('Please select at least one customer.'), Colors.orange);
      return;
    }
    if (_recipientCount == 0) {
      _showSnack(context.tr('No customers to send to.'), Colors.orange);
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.send, color: Color(0xFF25D366)),
          const SizedBox(width: 10),
          Text(context.tr('Confirm Send'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          context.tr('Send WhatsApp message to $_recipientCount customer(s) automatically?'),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('Send Now'),
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final token = context.read<AuthProvider>().token!;
      final result = await ApiService.sendWhatsAppBroadcast(
        token,
        recipientType: _recipientTypeStr,
        message: msg,
        var2: _var2Controller.text.trim(),
        customerIds: _selectedCustomerIds.toList(),
        inactiveDays: _inactiveDays,
      );

      setState(() => _isSending = false);

      if (result['success'] == true) {
        _showResultDialog(result);
      } else {
        _showSnack(result['message'] ?? context.tr('Failed to send'), Colors.red);
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showSnack(e.toString(), Colors.red);
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final sent = result['sent'] ?? 0;
    final failed = result['failed'] ?? 0;
    final errors = (result['errors'] as List?)?.cast<String>() ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(sent > 0 ? Icons.check_circle : Icons.error,
              color: sent > 0 ? Colors.green : Colors.red),
          const SizedBox(width: 10),
          Text(
            sent > 0 ? context.tr('Messages Sent!') : context.tr('Send Failed'),
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                _statChip('$sent', context.tr('Sent'), Colors.green),
                const SizedBox(width: 12),
                if (failed > 0) _statChip('$failed', context.tr('Failed'), Colors.red),
              ],
            ),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(context.tr('Issues:'),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              ...errors.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.red.shade700)),
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
                setState(() {
                  _selectedTemplate = null;
                  _selectedCustomerIds.clear();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(context.tr('Done'),
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Notifications'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          tabs: [
            Tab(icon: const Icon(Icons.people, size: 18), text: context.tr('All')),
            Tab(icon: const Icon(Icons.checklist, size: 18), text: context.tr('Specific')),
            Tab(icon: const Icon(Icons.person_off, size: 18), text: context.tr('Inactive')),
            Tab(icon: const Icon(Icons.notifications_active, size: 18), text: context.tr('Reminders')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    if (_mode != RecipientMode.reminders)
                      _buildMessageComposer(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAllTab(),
                          _buildSpecificTab(),
                          _buildInactiveTab(),
                          _buildRemindersTab(),
                        ],
                      ),
                    ),
                    if (_mode != RecipientMode.reminders)
                      _buildSendBar(),
                  ],
                ),
    );
  }

  // ── Message composer ───────────────────────────────────────────────────────
  Widget _buildMessageComposer() {
    final hasVar2 = _messageController.text.contains('{{2}}');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template dropdown
          if (_templates.isNotEmpty) ...[
            Text(context.tr('Template'),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 5),
            DropdownButtonFormField<dynamic>(
              value: _selectedTemplate,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              hint: Text(context.tr('-- Select a template --'),
                  style: GoogleFonts.inter(fontSize: 13)),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(context.tr('-- No template --'))),
                ..._templates.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t['name'] ?? '',
                          style: GoogleFonts.inter(fontSize: 13)),
                    )),
              ],
              onChanged: (val) {
                if (val == null) {
                  setState(() => _selectedTemplate = null);
                  _messageController.clear();
                } else {
                  _applyTemplate(val);
                }
              },
            ),
            const SizedBox(height: 10),
          ],

          // {{2}} input (only shown when template has it)
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('{{2}}',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
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
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Message body
          Text(context.tr('Message'),
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 5),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('Type message or select template...'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
  }

  // ── All customers tab ──────────────────────────────────────────────────────
  Widget _buildAllTab() {
    return Column(
      children: [
        _buildBanner(
          '${_allCustomers.length} ${context.tr('customers — all will receive this message')}',
          Colors.blue.shade700,
          Icons.people,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _allCustomers.length,
            itemBuilder: (_, i) => _customerTile(_allCustomers[i]),
          ),
        ),
      ],
    );
  }

  // ── Specific tab ───────────────────────────────────────────────────────────
  Widget _buildSpecificTab() {
    final allSelected = _filteredCustomers.isNotEmpty &&
        _filteredCustomers.every((c) => _selectedCustomerIds.contains(c['id']));
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
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_selectedCustomerIds.length} ${context.tr('selected')}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600)),
              Row(children: [
                Text(context.tr('All'), style: GoogleFonts.inter(fontSize: 12)),
                Checkbox(
                    value: allSelected,
                    onChanged: _toggleSelectAll,
                    activeColor: const Color(0xFF000080)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _filteredCustomers.length,
            itemBuilder: (_, i) {
              final c = _filteredCustomers[i];
              final isSelected = _selectedCustomerIds.contains(c['id']);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? const Color(0xFF000080)
                          : Colors.grey.shade200),
                ),
                child: CheckboxListTile(
                  dense: true,
                  title: Text(c['name'] ?? '',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(c['phone'] ?? '',
                      style: GoogleFonts.inter(fontSize: 11)),
                  value: isSelected,
                  activeColor: const Color(0xFF000080),
                  onChanged: (val) => setState(() {
                    if (val == true) {
                      _selectedCustomerIds.add(c['id']);
                    } else {
                      _selectedCustomerIds.remove(c['id']);
                    }
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Inactive tab ───────────────────────────────────────────────────────────
  Widget _buildInactiveTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(context.tr('Inactive for'),
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              ...[30, 60, 90, 180].map((d) {
                final sel = _inactiveDays == d;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _inactiveDays = d);
                      _refreshInactive();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            sel ? const Color(0xFF000080) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${d}d',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  sel ? Colors.white : Colors.grey.shade600)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        _buildBanner(
          '${_inactiveCustomers.length} ${context.tr('inactive customers ($_inactiveDays+ days)')}',
          Colors.orange.shade700,
          Icons.person_off,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _inactiveCustomers.length,
            itemBuilder: (_, i) => _inactiveTile(_inactiveCustomers[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _customerTile(dynamic c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF000080).withOpacity(0.1),
          child: Text(
            (c['name'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF000080),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        title: Text(c['name'] ?? '',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(c['phone'] ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
      ),
    );
  }

  Widget _inactiveTile(dynamic c) {
    final lastVisit = c['last_invoice_date'] ?? 'Never';
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.orange.shade50,
          child: Text(
            (c['name'] ?? 'U')[0].toUpperCase(),
            style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        title: Text(c['name'] ?? '',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(c['phone'] ?? '',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
        trailing: Text('Last: $lastVisit',
            style: GoogleFonts.inter(
                fontSize: 10, color: Colors.orange.shade700)),
      ),
    );
  }

  // ── Send bar ───────────────────────────────────────────────────────────────
  Widget _buildSendBar() {
    final count = _recipientCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: (_isSending || count == 0) ? null : _sendBroadcast,
          icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: Text(
            _isSending
                ? context.tr('Sending...')
                : context.tr('Send to $count Customer${count != 1 ? 's' : ''}'),
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  List<dynamic> get _filteredReminderPlans {
    final query = _reminderSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _reminderPlans;
    return _reminderPlans.where((p) {
      final name = (p['customer_name'] ?? '').toString().toLowerCase();
      final phone = (p['customer_phone'] ?? '').toString().toLowerCase();
      final vehicleNum = (p['vehicle_number'] ?? '').toString().toLowerCase();
      final serviceName = (p['service_name'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query) || vehicleNum.contains(query) || serviceName.contains(query);
    }).toList();
  }

  Widget _buildRemindersTab() {
    final filteredPlans = _filteredReminderPlans;
    final allSelected = filteredPlans.isNotEmpty &&
        filteredPlans.every((p) => _selectedReminderIds.contains(p['id']));

    return Column(
      children: [
        // Date Selector Header Row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF000080)),
              const SizedBox(width: 8),
              Text(
                context.tr('Select Date:'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedReminderDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedReminderDate = picked;
                      });
                      _fetchReminderPlans();
                    }
                  },
                  child: Container(
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
                          "${_selectedReminderDate.day.toString().padLeft(2, '0')}-${_selectedReminderDate.month.toString().padLeft(2, '0')}-${_selectedReminderDate.year}",
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Bulk Actions Bar (if reminder plans are available)
        if (filteredPlans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: allSelected,
                      activeColor: const Color(0xFF000080),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            for (var p in filteredPlans) {
                              _selectedReminderIds.add(p['id'] as String);
                            }
                          } else {
                            _selectedReminderIds.clear();
                          }
                        });
                      },
                    ),
                    Text(
                      context.tr('Select All'),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSendingBulkReminders ? null : _sendBulkReminders,
                  icon: _isSendingBulkReminders
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                    context.tr('Send Selected (${_selectedReminderIds.length})'),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

        // Reminder List Builder
        Expanded(
          child: _isLoadingReminderPlans
              ? const Center(child: CircularProgressIndicator())
              : filteredPlans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('No clients due for reminders'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: filteredPlans.length,
                      itemBuilder: (context, index) {
                        final plan = filteredPlans[index];
                        final planId = plan['id'] as String;
                        final isSelected = _selectedReminderIds.contains(planId);
                        final isSendingSingle = _sendingSinglePlanIds.contains(planId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF000080),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedReminderIds.add(planId);
                                      } else {
                                        _selectedReminderIds.remove(planId);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              plan['customer_name'] ?? 'Customer',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "${context.tr('Rem')} ${plan['reminder_no']}",
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${plan['vehicle_number']} · ${plan['vehicle_type']}",
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${context.tr('Due Service')}: ${plan['service_name']}",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isSendingSingle ? null : () => _sendSingleReminder(plan),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000080),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: isSendingSingle
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.send_rounded, size: 12),
                                            const SizedBox(width: 4),
                                            Text(context.tr('Send'), style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
