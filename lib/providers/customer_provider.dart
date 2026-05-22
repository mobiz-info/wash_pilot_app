import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomerProvider with ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _customerData;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get customerData => _customerData;
  String get errorMessage => _errorMessage;

  Future<void> searchCustomer(String mobile, String token) async {
    if (mobile.isEmpty) {
      _errorMessage = 'Please enter a mobile number';
      _customerData = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    _customerData = null;
    notifyListeners();

    try {
      final data = await ApiService.searchCustomer(mobile, token);
      
      if (data['success'] == true) {
        _customerData = data['customer'];
      } else {
        _errorMessage = data['message'] ?? 'Customer not found';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _customerData = null;
    _errorMessage = '';
    notifyListeners();
  }
}
