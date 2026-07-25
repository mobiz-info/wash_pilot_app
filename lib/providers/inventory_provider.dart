import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<dynamic> _oilProducts = [];
  List<dynamic> _tyreBrands = [];
  List<dynamic> _stockItems = [];
  List<dynamic> _extras = [];

  bool _isLoadingOil = false;
  bool _isLoadingTyres = false;
  bool _isLoadingStock = false;
  bool _isLoadingExtras = false;

  List<dynamic> get oilProducts => _oilProducts;
  List<dynamic> get tyreBrands => _tyreBrands;
  List<dynamic> get stockItems => _stockItems;
  List<dynamic> get extras => _extras;

  bool get isLoadingOil => _isLoadingOil;
  bool get isLoadingTyres => _isLoadingTyres;
  bool get isLoadingStock => _isLoadingStock;
  bool get isLoadingExtras => _isLoadingExtras;

  // ── Fetch Operations ──────────────────────────────────────────────────────
  Future<void> fetchOilProducts(String token) async {
    _isLoadingOil = true;
    notifyListeners();

    try {
      final res = await ApiService.getOilProducts(token);
      if (res['success'] == true) {
        _oilProducts = res['oil_products'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching oil products: $e');
    } finally {
      _isLoadingOil = false;
      notifyListeners();
    }
  }

  Future<void> fetchTyreBrands(String token) async {
    _isLoadingTyres = true;
    notifyListeners();

    try {
      final res = await ApiService.getTyreBrands(token);
      if (res['success'] == true) {
        _tyreBrands = res['tyre_brands'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching tyre brands: $e');
    } finally {
      _isLoadingTyres = false;
      notifyListeners();
    }
  }

  Future<void> fetchStockItems(String token) async {
    _isLoadingStock = true;
    notifyListeners();

    try {
      final res = await ApiService.getStockList(token);
      if (res['success'] == true) {
        _stockItems = res['stocks'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching stock items: $e');
    } finally {
      _isLoadingStock = false;
      notifyListeners();
    }
  }

  Future<void> fetchExtras(String token) async {
    _isLoadingExtras = true;
    notifyListeners();

    try {
      final res = await ApiService.getExtrasList(token);
      if (res['success'] == true) {
        _extras = res['extras'] ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching extras: $e');
    } finally {
      _isLoadingExtras = false;
      notifyListeners();
    }
  }
}
