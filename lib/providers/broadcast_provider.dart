import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

enum RecipientMode { allCustomers, specificCustomers, inactiveCustomers, reminders }

class BroadcastProvider extends ChangeNotifier {
  // ── Tab & Mode State ───────────────────────────────────────────────────────
  RecipientMode _mode = RecipientMode.allCustomers;
  RecipientMode get mode => _mode;

  void setMode(RecipientMode newMode) {
    _mode = newMode;
    notifyListeners();
  }

  // ── Data Lists ────────────────────────────────────────────────────────────
  List<dynamic> _allCustomers = [];
  List<dynamic> _inactiveCustomers = [];
  List<dynamic> _templates = [];
  List<dynamic> _reminderPlans = [];

  bool _isLoading = false;
  bool _isLoadingReminderPlans = false;
  bool _isSending = false;

  List<dynamic> get allCustomers => _allCustomers;
  List<dynamic> get inactiveCustomers => _inactiveCustomers;
  List<dynamic> get templates => _templates;
  List<dynamic> get reminderPlans => _reminderPlans;

  bool get isLoading => _isLoading;
  bool get isLoadingReminderPlans => _isLoadingReminderPlans;
  bool get isSending => _isSending;

  // ── Date and Reminders Selection State ─────────────────────────────────────
  DateTime _selectedReminderDate = DateTime.now();
  final Set<String> _selectedReminderIds = {};
  final Set<String> _selectedCustomerIds = {};

  DateTime get selectedReminderDate => _selectedReminderDate;
  Set<String> get selectedReminderIds => _selectedReminderIds;
  Set<String> get selectedCustomerIds => _selectedCustomerIds;

  void setSelectedReminderDate(DateTime date) {
    _selectedReminderDate = date;
    notifyListeners();
  }

  void toggleReminderSelection(String planId) {
    if (_selectedReminderIds.contains(planId)) {
      _selectedReminderIds.remove(planId);
    } else {
      _selectedReminderIds.add(planId);
    }
    notifyListeners();
  }

  void selectAllReminders(List<dynamic> plans) {
    for (var p in plans) {
      if (p['id'] != null) {
        _selectedReminderIds.add(p['id'].toString());
      }
    }
    notifyListeners();
  }

  void clearReminderSelections() {
    _selectedReminderIds.clear();
    notifyListeners();
  }

  void toggleCustomerSelection(String id) {
    if (_selectedCustomerIds.contains(id)) {
      _selectedCustomerIds.remove(id);
    } else {
      _selectedCustomerIds.add(id);
    }
    notifyListeners();
  }

  void selectAllCustomers(List<dynamic> customers) {
    for (var c in customers) {
      if (c['id'] != null) {
        _selectedCustomerIds.add(c['id'].toString());
      }
    }
    notifyListeners();
  }

  void clearCustomerSelections() {
    _selectedCustomerIds.clear();
    notifyListeners();
  }

  // ── Operations ────────────────────────────────────────────────────────────
  Future<void> fetchAllData(String token, {int inactiveDays = 30}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.listCustomers(token),
        ApiService.getInactiveCustomers(token, days: inactiveDays),
        ApiService.getWhatsAppTemplates(token),
        ApiService.getReminderPlans(token),
      ]);

      if (results[0]['success'] == true) _allCustomers = results[0]['customers'] ?? [];
      if (results[1]['success'] == true) _inactiveCustomers = results[1]['customers'] ?? [];
      if (results[2]['success'] == true) _templates = results[2]['templates'] ?? [];
      if (results[3]['success'] == true) _reminderPlans = results[3]['plans'] ?? [];
    } catch (e) {
      debugPrint('Error loading broadcast data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReminderPlans(String token) async {
    _isLoadingReminderPlans = true;
    notifyListeners();

    try {
      final dateStr =
          "${_selectedReminderDate.year}-${_selectedReminderDate.month.toString().padLeft(2, '0')}-${_selectedReminderDate.day.toString().padLeft(2, '0')}";
      final res = await ApiService.getReminderPlans(token, date: dateStr);
      if (res['success'] == true) {
        _reminderPlans = res['plans'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching reminder plans: $e');
    } finally {
      _isLoadingReminderPlans = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendBroadcast({
    required String token,
    required String recipientType,
    required List<String> recipientPhoneNumbers,
    required String templateId,
    required String var1,
    required String var2,
    required String customMessage,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      return await ApiService.sendWhatsAppBroadcast(
        token,
        recipientType: recipientType,
        message: customMessage,
        var2: var2,
        customerIds: recipientPhoneNumbers,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> sendReminders(
    String token,
    List<String> planIds, {
    String? action,
  }) async {
    try {
      final res = await ApiService.sendReminders(token, planIds, action: action);
      if (res['success'] == true || action == 'mark_sent') {
        _reminderPlans.removeWhere((p) => planIds.contains(p['id']));
        for (var id in planIds) {
          _selectedReminderIds.remove(id);
        }
        notifyListeners();
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
