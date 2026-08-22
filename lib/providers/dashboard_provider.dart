import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasLoaded = false;
  int _totalJobs = 0;
  String _todayRevenue = '0';
  String _todayCollected = '0';
  String _todayExpense = '0';
  String _todayNetProfit = '0';
  String _totalOutstanding = '0';
  int _outstandingCount = 0;
  int _totalCustomers = 0;
  List<Map<String, dynamic>> _recentInvoices = [];

  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  int get totalJobs => _totalJobs;
  String get todayRevenue => _todayRevenue;
  String get todayCollected => _todayCollected;
  String get todayExpense => _todayExpense;
  String get todayNetProfit => _todayNetProfit;
  String get totalOutstanding => _totalOutstanding;
  int get outstandingCount => _outstandingCount;
  int get totalCustomers => _totalCustomers;
  List<Map<String, dynamic>> get recentInvoices => _recentInvoices;

  List<Map<String, dynamic>> get branches => _branches;
  String? get selectedBranchId => _selectedBranchId;

  Future<void> fetchBranches(String token) async {
    try {
      final res = await ApiService.getCompanyBranches(token);
      if (res['success'] == true) {
        _branches = List<Map<String, dynamic>>.from(res['branches'] ?? []);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching company branches: $e');
    }
  }

  void setSelectedBranchId(String? branchId, String token) {
    _selectedBranchId = branchId;
    notifyListeners();
    loadStats(token);
  }

  Future<Map<String, dynamic>?> loadStats(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.getDashboardStats(token, branchId: _selectedBranchId);
      if (res['success'] == true) {
        _totalJobs = res['today_jobs'] ?? 0;
        _todayRevenue = res['today_revenue'] ?? '0';
        _todayCollected = res['today_collected'] ?? '0';
        _todayExpense = res['today_expense'] ?? '0';
        _todayNetProfit = res['today_net_profit'] ?? '0';
        _totalOutstanding = res['total_outstanding'] ?? '0';
        _outstandingCount = res['outstanding_count'] ?? 0;
        _totalCustomers = res['total_customers'] ?? 0;
        _recentInvoices = List<Map<String, dynamic>>.from(
          res['recent_invoices'] ?? [],
        ).take(3).toList();
        _hasLoaded = true;
        return res;
      }
    } catch (e) {
      debugPrint('DashboardProvider error: $e');
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
    return null;
  }
}
