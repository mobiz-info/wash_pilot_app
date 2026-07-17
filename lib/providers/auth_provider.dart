import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _token;
  String? _role;
  String? _companyName;
  String? _branchName;
  String? _displayName;
  String? _username;
  String? _companyLogo;
  // Currency is always driven by CountryConfig (set via dart tools/setup_country.dart)
  // Do NOT store/restore from SharedPreferences — that would override the build-time setting.
  bool _subscriptionActive = true;
  int _subscriptionDaysLeft = 999;
  String? _subscriptionEndDate;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get companyName => _companyName;
  String? get branchName => _branchName;
  String? get displayName => _displayName;
  String? get username => _username;
  String? get companyLogo => _companyLogo;
  bool get isBranchAdmin =>
      _role == 'BRANCH_ADMIN' ||
      _role == 'BRANCH_MANAGER' ||
      _role == 'MARKETING' ||
      _role == 'CLERICAL' ||
      _role == 'SERVICE';
  bool get isCompanyAdmin => _role == 'COMPANY_ADMIN';
  bool get canBroadcast =>
      _role == 'COMPANY_ADMIN' ||
      _role == 'BRANCH_ADMIN' ||
      _role == 'BRANCH_MANAGER';
  /// Always returns the symbol for the country selected via setup_country.dart
  /// A trailing space is included so currency amounts are formatted as "₹ 100" / "AED 50".
  String get currencySymbol => '${CountryConfig.currencySymbol} ';
  bool get subscriptionActive => _subscriptionActive;
  int get subscriptionDaysLeft => _subscriptionDaysLeft;
  String? get subscriptionEndDate => _subscriptionEndDate;

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // Migration guard: if old session lacks the new display_name key, clear it
    // so the user is prompted to log in again and get fresh data.
    final hasDisplayName = prefs.containsKey('auth_display_name');
    final token = prefs.getString('auth_token');
    if (token != null && !hasDisplayName) {
      await prefs.clear();
      notifyListeners();
      return;
    }

    _token = prefs.getString('auth_token');
    _role = prefs.getString('auth_role');
    _companyName = prefs.getString('auth_company');
    _branchName = prefs.getString('auth_branch');
    _displayName = prefs.getString('auth_display_name');
    _username = prefs.getString('auth_username');
    _companyLogo = prefs.getString('auth_company_logo');
    // Currency symbol is NOT read from prefs — always use CountryConfig
    _subscriptionActive = prefs.getBool('subscription_active') ?? true;
    _subscriptionDaysLeft = prefs.getInt('subscription_days_left') ?? 999;
    _subscriptionEndDate = prefs.getString('subscription_end_date');
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.login(username, password);

      if (data['success'] == true) {
        _token = data['token'];
        _role = data['role'];
        _companyName = data['company_name'];
        _branchName = data['branch_name'] ?? '';
        _displayName = data['display_name'] ?? data['company_name'];
        _username = data['username'];
        _companyLogo = data['company_logo'] ?? '';
        _subscriptionActive = data['subscription_active'] ?? true;
        _subscriptionDaysLeft = data['subscription_days_left'] ?? 999;
        _subscriptionEndDate = data['subscription_end_date'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_role', _role ?? '');
        await prefs.setString('auth_company', _companyName ?? '');
        await prefs.setString('auth_branch', _branchName ?? '');
        await prefs.setString('auth_display_name', _displayName ?? '');
        await prefs.setString('auth_username', _username ?? '');
        await prefs.setString('auth_company_logo', _companyLogo ?? '');
        // Currency symbol is NOT saved to prefs — driven by CountryConfig at build time
        await prefs.setBool('subscription_active', _subscriptionActive);
        await prefs.setInt('subscription_days_left', _subscriptionDaysLeft);
        if (_subscriptionEndDate != null) {
          await prefs.setString('subscription_end_date', _subscriptionEndDate!);
        } else {
          await prefs.remove('subscription_end_date');
        }

        _isLoading = false;
        notifyListeners();
        return null;
      } else {
        _isLoading = false;
        notifyListeners();
        return data['message'] ?? 'Login failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> updateSubscriptionStatus({
    required bool active,
    required int daysLeft,
    required String? endDate,
  }) async {
    _subscriptionActive = active;
    _subscriptionDaysLeft = daysLeft;
    _subscriptionEndDate = endDate;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('subscription_active', active);
    await prefs.setInt('subscription_days_left', daysLeft);
    if (endDate != null) {
      await prefs.setString('subscription_end_date', endDate);
    } else {
      await prefs.remove('subscription_end_date');
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _companyName = null;
    _branchName = null;
    _displayName = null;
    _username = null;
    _companyLogo = null;
    _subscriptionActive = true;
    _subscriptionDaysLeft = 999;
    _subscriptionEndDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
