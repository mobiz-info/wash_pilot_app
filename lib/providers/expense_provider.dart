import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<dynamic> _expenseHeads = [];
  List<dynamic> _suppliers = [];

  bool _isLoadingHeads = false;
  bool _isLoadingSuppliers = false;

  List<dynamic> get expenseHeads => _expenseHeads;
  List<dynamic> get suppliers => _suppliers;

  bool get isLoadingHeads => _isLoadingHeads;
  bool get isLoadingSuppliers => _isLoadingSuppliers;

  Future<void> fetchExpenseHeads(String token) async {
    _isLoadingHeads = true;
    notifyListeners();

    try {
      final res = await ApiService.getExpenseHeads(token);
      if (res['success'] == true) {
        _expenseHeads = res['expense_heads'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching expense heads: $e');
    } finally {
      _isLoadingHeads = false;
      notifyListeners();
    }
  }

  Future<void> fetchSuppliers(String token) async {
    _isLoadingSuppliers = true;
    notifyListeners();

    try {
      final res = await ApiService.getSuppliersList(token);
      if (res['success'] == true) {
        _suppliers = res['suppliers'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    } finally {
      _isLoadingSuppliers = false;
      notifyListeners();
    }
  }
}
