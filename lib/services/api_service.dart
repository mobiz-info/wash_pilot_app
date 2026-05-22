import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android Emulator, or your local IP if on a real device
  static const String baseUrl = "http://172.20.10.5:8000/api";
  // "http://10.17.6.238:8000/api";
  // 'http://68.183.94.11:78/api';
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
      return jsonDecode(response.body);
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

  static Future<Map<String, dynamic>> searchVehicle(
    String vehicleNumber,
    String token,
  ) async {
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
  }) async {
    String url = '$baseUrl/invoice/list/';
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

  /// Receipts created from outstanding collections
  static Future<Map<String, dynamic>> getReceiptList(
    String token, {
    String? fromDate,
    String? toDate,
    String? branchId,
  }) async {
    String url = '$baseUrl/receipt/list/';
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
      return jsonDecode(response.body);
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
  }) async {
    final params = <String, String>{'from_date': fromDate, 'to_date': toDate};
    if (branchId != null && branchId.isNotEmpty) {
      params['branch_id'] = branchId;
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
  }) => _reportGet(
    'reports/collection/',
    token,
    fromDate,
    toDate,
    branchId: branchId,
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
}
