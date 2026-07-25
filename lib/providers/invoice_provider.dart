import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class InvoiceProvider extends ChangeNotifier {
  // ── Invoices List State ──────────────────────────────────────────────────
  List<dynamic> _invoices = [];
  bool _isLoadingList = false;
  String? _listErrorMessage;
  String _searchQuery = '';
  String? _selectedBranchId;
  String? _selectedDate;

  List<dynamic> get invoices => _invoices;
  bool get isLoadingList => _isLoadingList;
  String? get listErrorMessage => _listErrorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedBranchId => _selectedBranchId;
  String? get selectedDate => _selectedDate;

  // ── Invoice Creation Form State ─────────────────────────────────────────
  bool _isCreatingInvoice = false;
  String? _createErrorMessage;
  bool _applyGst = false;
  String _paymentMode = 'cash';
  double _amountCollected = 0.0;
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedVehicle;

  bool get isCreatingInvoice => _isCreatingInvoice;
  String? get createErrorMessage => _createErrorMessage;
  bool get applyGst => _applyGst;
  String get paymentMode => _paymentMode;
  double get amountCollected => _amountCollected;
  Map<String, dynamic>? get selectedCustomer => _selectedCustomer;
  Map<String, dynamic>? get selectedVehicle => _selectedVehicle;

  void setApplyGst(bool val) {
    _applyGst = val;
    notifyListeners();
  }

  void setPaymentMode(String mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setAmountCollected(double amount) {
    _amountCollected = amount;
    notifyListeners();
  }

  void setSelectedCustomer(Map<String, dynamic>? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setSelectedVehicle(Map<String, dynamic>? vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  void resetForm() {
    _applyGst = false;
    _paymentMode = 'cash';
    _amountCollected = 0.0;
    _selectedCustomer = null;
    _selectedVehicle = null;
    _createErrorMessage = null;
    notifyListeners();
  }

  // ── Invoices List Operations ──────────────────────────────────────────────
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterBranch(String? branchId) {
    _selectedBranchId = branchId;
    notifyListeners();
  }

  void setFilterDate(String? dateStr) {
    _selectedDate = dateStr;
    notifyListeners();
  }

  Future<void> fetchInvoices(
    String token, {
    String? branchId,
    String? search,
    String? date,
    String? fromDate,
    String? toDate,
    String? paymentMode,
    String? customerType,
  }) async {
    _isLoadingList = true;
    _listErrorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.listInvoices(
        token,
        fromDate: fromDate,
        toDate: toDate,
        paymentMode: paymentMode,
      );

      if (res['success'] == true) {
        _invoices = res['invoices'] ?? [];
      } else {
        _listErrorMessage = res['message'] ?? 'Failed to load invoices';
        _invoices = [];
      }
    } catch (e) {
      _listErrorMessage = e.toString();
      _invoices = [];
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  // ── Create Invoice Action ────────────────────────────────────────────────
  Future<Map<String, dynamic>> createInvoice({
    required String token,
    required Map<String, dynamic> invoiceData,
  }) async {
    _isCreatingInvoice = true;
    _createErrorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.createInvoice(invoiceData, token);
      if (result['success'] != true) {
        _createErrorMessage = result['message'] ?? 'Failed to create invoice';
      }
      return result;
    } catch (e) {
      _createErrorMessage = e.toString();
      return {'success': false, 'message': e.toString()};
    } finally {
      _isCreatingInvoice = false;
      notifyListeners();
    }
  }

  // ── Send WhatsApp Invoice Action ─────────────────────────────────────────
  Future<Map<String, dynamic>> sendWhatsAppInvoice({
    required String token,
    required String invoiceId,
  }) async {
    try {
      return await ApiService.sendInvoiceWhatsApp(invoiceId, token);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Payment Collection Action ─────────────────────────────────────────────
  Future<Map<String, dynamic>> collectPayment({
    required String token,
    required String invoiceId,
    required double amount,
    String paymentMode = 'cash',
  }) async {
    try {
      final res = await ApiService.collectPayment(
        token: token,
        invoiceId: invoiceId,
        amount: amount,
      );
      if (res['success'] == true) {
        // Automatically refresh invoice list if available
        fetchInvoices(token);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
