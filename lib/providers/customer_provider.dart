import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomerProvider with ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _customerData;
  String _errorMessage = '';

  Map<String, String> _modelToTypeMap = {};

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get customerData => _customerData;
  String get errorMessage => _errorMessage;

  Future<void> _ensureModelToTypeMap(String token) async {
    if (_modelToTypeMap.isNotEmpty) return;
    try {
      final res = await ApiService.getFormData(token);
      if (res['success'] == true) {
        final models = res['vehicle_models'] as List<dynamic>;
        for (final m in models) {
          final modelName = m['name'] as String;
          final typeName = m['vehicle_type'] as String;
          _modelToTypeMap[modelName] = typeName;
        }
      }
    } catch (e) {
      debugPrint('Failed to load form data in CustomerProvider: $e');
    }
  }

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
      // Ensure we have loaded the model to type mapping
      await _ensureModelToTypeMap(token);

      final data = await ApiService.searchCustomer(mobile, token);
      
      if (data['success'] == true) {
        final customer = Map<String, dynamic>.from(data['customer']);
        final List<dynamic> vehicles = List<dynamic>.from(customer['vehicles'] ?? []);
        
        // Dynamically add vehicle_type if missing or empty using local map fallback
        final List<Map<String, dynamic>> updatedVehicles = [];
        for (final v in vehicles) {
          final vMap = Map<String, dynamic>.from(v);
          final typeVal = vMap['vehicle_type']?.toString() ?? '';
          if (typeVal.isEmpty) {
            final modelName = vMap['type']?.toString() ?? '';
            vMap['vehicle_type'] = _modelToTypeMap[modelName] ?? '';
          }
          updatedVehicles.add(vMap);
        }
        
        customer['vehicles'] = updatedVehicles;
        _customerData = customer;
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

