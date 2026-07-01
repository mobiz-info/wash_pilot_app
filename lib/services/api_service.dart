import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String appName = "Car Wash";
  static const String appIconPath = "assets/icons/mobiz_logo_foreground.png";
  // Use 10.0.2.2 for Android Emulator, or your local IP if on a real device
  // static const String baseUrl = "http://10.54.237.238:8000/api";
  static const String baseUrl = "http://68.183.94.11:78/api";

  static final Map<String, String> _modelToTypeMap = {};

  static Future<void> ensureModelToTypeMap(String token) async {
    if (_modelToTypeMap.isNotEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customer/form-data/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['success'] == true) {
          final models = res['vehicle_models'] as List<dynamic>;
          for (final m in models) {
            final modelName = m['name'] as String;
            final typeName = m['vehicle_type'] as String;
            _modelToTypeMap[modelName] = typeName;
          }
        }
      }
    } catch (_) {}
  }

  static Map<String, dynamic> _mapVehicleTypesInResponse(Map<String, dynamic> data) {
    if (data['customer'] != null && data['customer']['vehicles'] != null) {
      final vehicles = data['customer']['vehicles'] as List<dynamic>;
      for (final v in vehicles) {
        if (v is Map) {
          final typeVal = v['vehicle_type']?.toString() ?? '';
          if (typeVal.isEmpty) {
            final modelName = (v['type'] ?? v['vehicle_model_name'] ?? '').toString();
            if (modelName.isNotEmpty) {
              v['vehicle_type'] = _modelToTypeMap[modelName] ?? '';
            }
          }
        }
      }
    }
    if (data['vehicle'] != null) {
      final v = data['vehicle'];
      if (v is Map) {
        final typeVal = v['vehicle_type']?.toString() ?? '';
        if (typeVal.isEmpty) {
          final modelName = (v['model'] ?? '').toString();
          if (modelName.isNotEmpty) {
            v['vehicle_type'] = _modelToTypeMap[modelName] ?? '';
          }
        }
      }
    }
    return data;
  }
  // "http://10.17.6.238:8000/api";
  // 'http://68.183.94.11:78/api';
  // http://172.20.10.5:8000/api
  // Update this to 'http://10.0.2.2:8000/api' if testing on Android Emulator

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    print(response.body);
    print(response.statusCode);
    if (response.statusCode == 200 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> searchCustomer(
    String mobile,
    String token,
  ) async {
    await ensureModelToTypeMap(token);
    final response = await http.get(
      Uri.parse('$baseUrl/customer/search/?mobile=$mobile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 ||
        response.statusCode == 404 ||
        response.statusCode == 401) {
      return _mapVehicleTypesInResponse(jsonDecode(response.body));
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> searchCustomerList(
    String query,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customer/search-list/?q=$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getInvoiceServices(
    String customerId,
    String vehicleId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/invoice/services/?customer_id=$customerId&vehicle_id=$vehicleId',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> invoiceData,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoice/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(invoiceData),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getFormData(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/customer/form-data/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> addCustomer(
    Map<String, dynamic> data,
    String token,
  ) async {
    await ensureModelToTypeMap(token);
    final response = await http.post(
      Uri.parse('$baseUrl/customer/add/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 401) {
      return _mapVehicleTypesInResponse(jsonDecode(response.body));
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> listCustomers(
    String token, {
    String? search,
  }) async {
    String url = '$baseUrl/customer/list/';
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load customers.');
    }
  }

  static Future<Map<String, dynamic>> getInactiveCustomers(
    String token, {
    int days = 60,
  }) async {
    final url = '$baseUrl/customer/inactive/?days=$days';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load inactive customers.');
    }
  }

  static Future<Map<String, dynamic>> getWhatsAppTemplates(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/whatsapp/templates/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load WhatsApp templates.');
    }
  }

  static Future<Map<String, dynamic>> sendWhatsAppBroadcast(
    String token, {
    required String recipientType,
    required String message,
    String var2 = '',
    List<String> customerIds = const [],
    int inactiveDays = 60,
  }) async {
    final body = jsonEncode({
      'recipient_type': recipientType,
      'message': message,
      'var_2': var2,
      'customer_ids': customerIds,
      'inactive_days': inactiveDays,
    });
    final response = await http.post(
      Uri.parse('$baseUrl/whatsapp/broadcast/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send broadcast.');
    }
  }

  static Future<Map<String, dynamic>> searchVehicle(
    String vehicleNumber,
    String token,
  ) async {
    await ensureModelToTypeMap(token);
    final response = await http.get(
      Uri.parse('$baseUrl/vehicle/search/?vehicle_number=$vehicleNumber'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 ||
        response.statusCode == 404 ||
        response.statusCode == 401) {
      return _mapVehicleTypesInResponse(jsonDecode(response.body));
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }
  static Future<Map<String, dynamic>> searchVehicleList(
    String query,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/vehicle/search-list/?q=$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> listBookings(
    String token, {
    String? fromDate,
    String? toDate,
  }) async {
    String url = '$baseUrl/booking/list/';
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    if (params.isNotEmpty) {
      url += '?' + params.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/$bookingId/status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> sendBookingReadyAlert(
    String bookingId,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/$bookingId/ready-alert/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> sendVehicleReadyAlertGeneric({
    required String phone,
    required String vehicleNumber,
    required String customerName,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/ready-alert/generic/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'phone': phone,
        'vehicle_number': vehicleNumber,
        'customer_name': customerName,
      }),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getBranchSchemes(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/schemes/branch/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getCompanyBranches(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/company/branches/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load branches.');
    }
  }

  static Future<Map<String, dynamic>> getSchemeOptions(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/schemes/options/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load scheme options.');
    }
  }

  static Future<Map<String, dynamic>> createScheme(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/schemes/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create scheme.');
    }
  }

  static Future<Map<String, dynamic>> listInvoices(
    String token, {
    String? fromDate,
    String? toDate,
    String? paymentMode,
  }) async {
    String url = '$baseUrl/invoice/list/';
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    if (paymentMode != null && paymentMode.isNotEmpty) params['payment_mode'] = paymentMode;
    if (params.isNotEmpty) {
      url += '?' + params.entries.map((e) => '${e.key}=${e.value}').join('&');
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/stats/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to connect to the server.');
    }
  }

  static Future<Map<String, dynamic>> getAvailableSchemes(
    String customerId,
    String vehicleId,
    String serviceId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/schemes/available/').replace(
        queryParameters: {
          'customer_id': customerId,
          'vehicle_id': vehicleId,
          'service_id': serviceId,
        },
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load schemes.');
    }
  }

  /// Validate a voucher number for a scheme and return the discount amount.
  static Future<Map<String, dynamic>> validateVoucher(
    String schemeId,
    String voucherNumber,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/schemes/validate-voucher/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'scheme_id': schemeId,
        'voucher_number': voucherNumber,
      }),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to validate voucher.');
    }
  }

  /// Outstanding invoices list
  static Future<Map<String, dynamic>> getOutstandingList(
    String token, {
    String? fromDate,
    String? toDate,
    String? branchId,
  }) async {
    String url = '$baseUrl/outstanding/list/';
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load outstanding list.');
    }
  }

  static Future<Map<String, dynamic>> getReceiptList(
    String token, {
    String? fromDate,
    String? toDate,
    String? branchId,
    String? paymentMode,
  }) async {
    String url = '$baseUrl/receipt/list/';
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    if (branchId != null && branchId.isNotEmpty) params['branch_id'] = branchId;
    if (paymentMode != null && paymentMode.isNotEmpty) params['payment_mode'] = paymentMode;
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load receipts.');
    }
  }

  /// Collect payment for an invoice
  static Future<Map<String, dynamic>> collectPayment({
    required String invoiceId,
    required double amount,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/outstanding/collect/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'invoice_id': invoiceId, 'amount': amount}),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to collect payment.');
    }
  }

  /// Fetch full customer details for editing
  static Future<Map<String, dynamic>> getCustomer(
    String customerId,
    String token,
  ) async {
    await ensureModelToTypeMap(token);
    final response = await http.get(
      Uri.parse('$baseUrl/customer/get/?customer_id=$customerId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404 ||
        response.statusCode == 401) {
      return _mapVehicleTypesInResponse(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer.');
    }
  }

  /// Update customer details (name, type, whatsapp, email, address, add vehicles)
  static Future<Map<String, dynamic>> editCustomer(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/customer/edit/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404 ||
        response.statusCode == 401) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update customer.');
    }
  }

  static Future<Map<String, dynamic>> _reportGet(
    String path,
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
    String? paymentMode,
  }) async {
    final params = <String, String>{'from_date': fromDate, 'to_date': toDate};
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    if (paymentMode != null && paymentMode.isNotEmpty) {
      params['payment_mode'] = paymentMode;
    }
    final response = await http.get(
      Uri.parse('$baseUrl/$path').replace(queryParameters: params),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load report.');
  }

  static Future<Map<String, dynamic>> getJobReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) =>
      _reportGet('reports/jobs/', token, fromDate, toDate, branchId: branchId);

  static Future<Map<String, dynamic>> getSchemeBeneficiaryReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) => _reportGet(
    'reports/scheme-beneficiary/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
  );

  static Future<Map<String, dynamic>> getCollectionReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
    String? paymentMode,
  }) => _reportGet(
    'reports/collection/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
    paymentMode: paymentMode,
  );

  static Future<Map<String, dynamic>> getOutstandingReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) => _reportGet(
    'reports/outstanding/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
  );

  static Future<Map<String, dynamic>> getDaywiseConsolidatedReport(
    String token,
    String type,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final params = <String, String>{
      'type': type,
      'from_date': fromDate,
      'to_date': toDate,
    };
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final response = await http.get(
      Uri.parse('$baseUrl/reports/daywise/').replace(queryParameters: params),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 401) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load daywise report.');
  }

  static Future<Map<String, dynamic>> getBookingReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) => _reportGet(
    'reports/bookings/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
  );

  static Future<Map<String, dynamic>> getCancellationReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) => _reportGet(
    'reports/cancellations/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
  );

  static Future<Map<String, dynamic>> getServiceTypeReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) => _reportGet(
    'reports/service-type/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
  );

  static Future<Map<String, dynamic>> listComplaintTypes(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/complaint-types/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load complaint types.');
    }
  }

  static Future<Map<String, dynamic>> createComplaintType(String token, String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/complaint-types/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create complaint type.');
    }
  }

  static Future<Map<String, dynamic>> createComplaint({
    required String token,
    required String complaintTypeId,
    required String priority,
    required String complaint,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/complaints/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'complaint_type_id': complaintTypeId,
        'priority': priority,
        'complaint': complaint,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create complaint.');
    }
  }

  static Future<Map<String, dynamic>> listComplaints(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/complaints/list/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load complaints.');
    }
  }

  static Future<Map<String, dynamic>> updateComplaintStatus({
    required String token,
    required String complaintId,
    required String status,
    String? remarks,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/complaints/update-status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'complaint_id': complaintId,
        'status': status,
        if (remarks != null) 'remarks': remarks,
      }),
    );
    if (response.statusCode == 200 ||
        response.statusCode == 400 ||
        response.statusCode == 404) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update complaint status.');
    }
  }

  static Future<Map<String, dynamic>> getExpenseHeads(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/expenses/heads/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load expense heads.');
    }
  }

  static Future<Map<String, dynamic>> createExpenseEntry(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create expense.');
    }
  }

  static Future<Map<String, dynamic>> getStaffList(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/staff/list/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff list.');
    }
  }

  static Future<Map<String, dynamic>> getStaffLeaves(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/staff/leaves/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff leaves.');
    }
  }

  static Future<Map<String, dynamic>> createStaffLeave(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/staff/leaves/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to record staff leave.');
    }
  }

  static Future<Map<String, dynamic>> getStockList(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/stock/list/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stock list.');
    }
  }

  static Future<Map<String, dynamic>> getPurchaseRequests(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/purchase-requests/list/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load purchase requests.');
    }
  }

  static Future<Map<String, dynamic>> createPurchaseRequest(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/purchase-requests/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to submit purchase request.');
    }
  }

  static Future<Map<String, dynamic>> createExpenseHead(
    String token,
    String name,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/heads/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create expense head.');
    }
  }

  static Future<Map<String, dynamic>> createStock(
    String token,
    String itemName,
    String unit, {
    String? expenseHeadId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stock/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'item_name': itemName,
        'unit': unit,
        if (expenseHeadId != null) 'expense_head_id': expenseHeadId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create stock item.');
    }
  }

  static Future<Map<String, dynamic>> editExpenseHead(
    String token,
    String id,
    String name,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/heads/edit/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to edit expense head.');
    }
  }

  static Future<Map<String, dynamic>> deleteExpenseHead(
    String token,
    String id,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses/heads/delete/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete expense head.');
    }
  }

  static Future<Map<String, dynamic>> editStock(
    String token,
    String id,
    String itemName,
    String unit, {
    String? expenseHeadId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stock/edit/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'item_name': itemName,
        'unit': unit,
        'expense_head_id': expenseHeadId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to edit stock item.');
    }
  }

  static Future<Map<String, dynamic>> deleteStock(
    String token,
    String id,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stock/delete/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete stock item.');
    }
  }

  static Future<Map<String, dynamic>> getExtrasList(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/extras/list/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load extras list.');
    }
  }

  static Future<Map<String, dynamic>> createExtra(
    String token,
    String name,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/extras/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 400) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create extra item.');
    }
  }

  static Future<Map<String, dynamic>> getExpenseHeadWiseReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final params = <String, String>{'from_date': fromDate, 'to_date': toDate};
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final url = Uri.parse('$baseUrl/reports/expense-head-wise/').replace(queryParameters: params);
    print('DEBUG getExpenseHeadWiseReport URL: $url');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('DEBUG getExpenseHeadWiseReport STATUS: ${response.statusCode}');
    print('DEBUG getExpenseHeadWiseReport BODY: ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load expense head report (status: ${response.statusCode}, body: ${response.body}).');
  }

  static Future<Map<String, dynamic>> getExpenseHeadDetailReport(
    String token,
    String expenseHeadId,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final params = <String, String>{
      'expense_head_id': expenseHeadId,
      'from_date': fromDate,
      'to_date': toDate,
    };
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final url = Uri.parse('$baseUrl/reports/expense-head-wise/detail/').replace(queryParameters: params);
    print('DEBUG getExpenseHeadDetailReport URL: $url');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('DEBUG getExpenseHeadDetailReport STATUS: ${response.statusCode}');
    print('DEBUG getExpenseHeadDetailReport BODY: ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load expense head detail report (status: ${response.statusCode}, body: ${response.body}).');
  }

  static Future<Map<String, dynamic>> getLeaveReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final params = <String, String>{'from_date': fromDate, 'to_date': toDate};
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final url = Uri.parse('$baseUrl/reports/leave/').replace(queryParameters: params);
    print('DEBUG getLeaveReport URL: $url');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print('DEBUG getLeaveReport STATUS: ${response.statusCode}');
    print('DEBUG getLeaveReport BODY: ${response.body}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load leave report (status: ${response.statusCode}, body: ${response.body}).');
  }

  static Future<Map<String, dynamic>> getServiceTypeDetailReport(
    String token,
    String serviceName,
    String fromDate,
    String toDate, {
    String? branchId,
    String? vehicleTypeId,
    String? vehicleTypeModelId,
  }) async {
    final Map<String, String> params = {
      'service_name': serviceName,
      'from_date': fromDate,
      'to_date': toDate,
    };
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    if (vehicleTypeId != null && vehicleTypeId.isNotEmpty) {
      params['vehicle_type_id'] = vehicleTypeId;
    }
    if (vehicleTypeModelId != null && vehicleTypeModelId.isNotEmpty) {
      params['vehicle_type_model_id'] = vehicleTypeModelId;
    }
    final url = Uri.parse('$baseUrl/reports/service-type/detail/').replace(queryParameters: params);
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load service type detail report.');
  }

  static Future<Map<String, dynamic>> getServiceTypeVehicleBreakdownReport(
    String token,
    String serviceName,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final Map<String, String> params = {
      'service_name': serviceName,
      'from_date': fromDate,
      'to_date': toDate,
    };
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final url = Uri.parse('$baseUrl/reports/service-type/vehicle-breakdown/').replace(queryParameters: params);
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load service type vehicle breakdown report.');
  }

  static Future<Map<String, dynamic>> getProfitLossReport(
    String token,
    String fromDate,
    String toDate, {
    String? branchId,
  }) async {
    final Map<String, String> params = {
      'from_date': fromDate,
      'to_date': toDate,
    };
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
    }
    final url = Uri.parse('$baseUrl/reports/profit-loss/').replace(queryParameters: params);
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load profit/loss report.');
  }

  // --- Booking Settings APIs ---

  static Future<Map<String, dynamic>> getBookingSettings(
    String token, {
    String? branchId,
  }) async {
    String url = '$baseUrl/booking/settings/';
    if (branchId != null && branchId.isNotEmpty) {
      url += '?branch_id=$branchId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load booking settings.');
  }

  static Future<Map<String, dynamic>> updateBookingSettings(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/settings/update/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update booking settings.');
  }

  // --- Holiday Calendar APIs ---

  static Future<Map<String, dynamic>> getHolidays(
    String token, {
    String? branchId,
  }) async {
    String url = '$baseUrl/booking/holiday/list/';
    if (branchId != null && branchId.isNotEmpty) {
      url += '?branch_id=$branchId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load holidays.');
  }

  static Future<Map<String, dynamic>> createHoliday(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/holiday/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create holiday.');
  }

  static Future<Map<String, dynamic>> deleteHoliday(
    String token,
    String id,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/holiday/delete/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to delete holiday.');
  }

  // --- Weekly Off Days APIs ---

  static Future<Map<String, dynamic>> getWeeklyOffs(
    String token, {
    String? branchId,
  }) async {
    String url = '$baseUrl/booking/weekly-off/list/';
    if (branchId != null && branchId.isNotEmpty) {
      url += '?branch_id=$branchId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load weekly offs.');
  }

  static Future<Map<String, dynamic>> createWeeklyOff(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/weekly-off/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create weekly off.');
  }

  static Future<Map<String, dynamic>> deleteWeeklyOff(
    String token,
    String id,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/weekly-off/delete/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to delete weekly off.');
  }

  // --- Booking Pause APIs ---

  static Future<Map<String, dynamic>> getBookingPauses(
    String token, {
    String? branchId,
  }) async {
    String url = '$baseUrl/booking/pause/list/';
    if (branchId != null && branchId.isNotEmpty) {
      url += '?branch_id=$branchId';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load booking pauses.');
  }

  static Future<Map<String, dynamic>> createBookingPause(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/pause/create/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create booking pause.');
  }

  static Future<Map<String, dynamic>> deleteBookingPause(
    String token,
    String id,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/pause/delete/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 403) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to delete booking pause.');
  }
}

