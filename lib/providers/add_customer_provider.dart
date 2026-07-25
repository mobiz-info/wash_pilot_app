import 'package:flutter/foundation.dart';
import '../config/country_config.dart';
import '../services/api_service.dart';

class AddCustomerProvider extends ChangeNotifier {
  bool isLoadingForm = true;
  bool isSaving = false;
  String errorMessage = '';

  List<dynamic> customerTypes = [];
  List<dynamic> vehicleTypes = [];
  List<dynamic> vehicleTypeModels = [];
  List<dynamic> makes = [];
  List<dynamic> brandModels = [];
  List<dynamic> colors = [];
  List<dynamic> branches = [];

  Map<String, dynamic>? selectedCustomerType;
  Map<String, dynamic>? selectedBranch;

  String selectedPhoneCode = CountryConfig.phoneDialCode;
  String selectedWhatsappCode = CountryConfig.phoneDialCode;
  String phoneIso = CountryConfig.phoneIsoCode;
  String whatsappIso = CountryConfig.phoneIsoCode;

  // Each entry: {controller, vehicle_type, vehicle_type_model, make, brand_model, color}
  final List<Map<String, dynamic>> vehicleRows = [];

  Future<void> fetchFormData(String token, {String? branchId}) async {
    isLoadingForm = true;
    errorMessage = '';
    notifyListeners();

    try {
      final res = await ApiService.getFormData(token);
      if (res['success'] == true) {
        customerTypes = res['customer_types'] as List<dynamic>;
        vehicleTypes = res['vehicle_types'] as List<dynamic>? ?? [];
        vehicleTypeModels =
            res['vehicle_type_models'] as List<dynamic>? ??
            res['vehicle_models'] as List<dynamic>? ??
            [];
        makes = res['makes'] as List<dynamic>? ?? [];
        brandModels = res['brand_models'] as List<dynamic>? ?? [];
        colors = res['colors'] as List<dynamic>? ?? [];
        branches = res['branches'] as List<dynamic>? ?? [];

        if (customerTypes.isNotEmpty) selectedCustomerType = customerTypes.first;
        if (branches.isNotEmpty) {
          if (branchId != null) {
            selectedBranch = branches.firstWhere(
              (b) => b['id']?.toString() == branchId,
              orElse: () => branches.first,
            );
          } else {
            selectedBranch = branches.first;
          }
        }

        // Set default vehicle_type for existing rows
        for (final row in vehicleRows) {
          if (vehicleTypes.isNotEmpty && row['vehicle_type'] == null) {
            row['vehicle_type'] = vehicleTypes.first;
          }
        }

        isLoadingForm = false;
      } else {
        errorMessage = res['message'] ?? 'Failed to load form data';
        isLoadingForm = false;
      }
    } catch (e) {
      errorMessage = e.toString();
      isLoadingForm = false;
    }
    notifyListeners();
  }

  void addVehicleRow() {
    vehicleRows.add({
      'controller': null, // TextEditingController created in widget
      'vehicle_type': vehicleTypes.isNotEmpty ? vehicleTypes.first : null,
      'vehicle_type_model': null,
      'make': null,
      'brand_model': null,
      'color': null,
    });
    notifyListeners();
  }

  void removeVehicleRow(int index) {
    if (vehicleRows.length <= 1) return;
    vehicleRows.removeAt(index);
    notifyListeners();
  }

  void updateVehicleRow(int index, String key, dynamic value) {
    vehicleRows[index][key] = value;
    notifyListeners();
  }

  void setSelectedCustomerType(Map<String, dynamic>? val) {
    selectedCustomerType = val;
    notifyListeners();
  }

  void setSelectedBranch(Map<String, dynamic>? val) {
    selectedBranch = val;
    notifyListeners();
  }

  void setPhoneCode(String dialCode, String iso) {
    selectedPhoneCode = dialCode;
    phoneIso = iso;
    notifyListeners();
  }

  void setWhatsappCode(String dialCode, String iso) {
    selectedWhatsappCode = dialCode;
    whatsappIso = iso;
    notifyListeners();
  }

  void setSaving(bool val) {
    isSaving = val;
    notifyListeners();
  }

  List<dynamic> segmentsForType(String? vehicleTypeId) {
    if (vehicleTypeId == null) return [];
    return vehicleTypeModels
        .where((m) => m['vehicle_type_id'] == vehicleTypeId)
        .toList();
  }

  List<dynamic> makesForSegment(String? segmentId) {
    if (segmentId == null) return [];
    final bmInSeg = brandModels.where(
      (b) => b['vehicle_type_model_id'] == segmentId,
    );
    final makeIds = bmInSeg
        .map((b) => b['make_id']?.toString())
        .where((id) => id != null && id!.isNotEmpty)
        .toSet();
    return makes.where((m) => makeIds.contains(m['id'].toString())).toList();
  }

  List<dynamic> brandModelsForSegmentAndMake(
    String? segmentId,
    String? makeId,
  ) {
    if (segmentId == null) return [];
    final bmInSeg = brandModels.where(
      (b) => b['vehicle_type_model_id'] == segmentId,
    );
    if (makeId != null && makeId.isNotEmpty) {
      return bmInSeg
          .where((b) => b['make_id']?.toString() == makeId)
          .toList();
    }
    return bmInSeg.toList();
  }

  void reset() {
    isLoadingForm = true;
    isSaving = false;
    errorMessage = '';
    customerTypes = [];
    vehicleTypes = [];
    vehicleTypeModels = [];
    makes = [];
    brandModels = [];
    colors = [];
    branches = [];
    selectedCustomerType = null;
    selectedBranch = null;
    selectedPhoneCode = CountryConfig.phoneDialCode;
    selectedWhatsappCode = CountryConfig.phoneDialCode;
    phoneIso = CountryConfig.phoneIsoCode;
    whatsappIso = CountryConfig.phoneIsoCode;
    vehicleRows.clear();
    notifyListeners();
  }
}
