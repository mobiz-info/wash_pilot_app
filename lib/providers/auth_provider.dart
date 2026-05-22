import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _token;
  String? _role;
  String? _companyName;
  String? _branchName;
  String? _displayName;
  String? _username;
  String _currencySymbol = '₹';

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get role => _role;
  String? get companyName => _companyName;
  String? get branchName => _branchName;
  String? get displayName => _displayName;
  String? get username => _username;
  bool get isBranchAdmin => _role == 'BRANCH_ADMIN';
  bool get isCompanyAdmin => _role == 'COMPANY_ADMIN';
  String get currencySymbol => _currencySymbol;

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
    _currencySymbol = prefs.getString('auth_currency_symbol') ?? '₹';
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
        _currencySymbol = data['currency_symbol'] ?? '₹';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_role', _role ?? '');
        await prefs.setString('auth_company', _companyName ?? '');
        await prefs.setString('auth_branch', _branchName ?? '');
        await prefs.setString('auth_display_name', _displayName ?? '');
        await prefs.setString('auth_username', _username ?? '');
        await prefs.setString('auth_currency_symbol', _currencySymbol);

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

  Future<void> logout() async {
    _token = null;
    _role = null;
    _companyName = null;
    _branchName = null;
    _displayName = null;
    _username = null;
    _currencySymbol = '₹';
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
