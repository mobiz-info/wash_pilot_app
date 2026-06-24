import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';
import 'add_customer_screen.dart';
import 'invoice_create_screen.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('New Job'), style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: context.tr('Enter Mobile Number'),
                      prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                      prefixText: '91 ',
                      prefixStyle: const TextStyle(color: Colors.black,fontSize: 16),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF000080)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    final token = context.read<AuthProvider>().token;
                    if (token != null) {
                      final rawMobile = _mobileController.text.trim();
                      if (rawMobile.isNotEmpty) {
                        final formattedMobile = rawMobile.startsWith('91') ? rawMobile : '91$rawMobile';
                        context.read<CustomerProvider>().searchCustomer(formattedMobile, token);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('Not authenticated. Please login again.'))),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF000080),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                )
              ],
            ),
            
            const SizedBox(height: 24),

            // Consumer to watch Provider state
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.errorMessage.isNotEmpty) {
                    final isNotFound = provider.errorMessage.toLowerCase().contains('not found');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isNotFound ? Icons.person_search : Icons.error_outline,
                            size: 72,
                            color: isNotFound ? Colors.orange.shade300 : Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isNotFound ? Colors.orange.shade700 : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isNotFound) ...
                          [
                            const SizedBox(height: 24),
                            Text(
                              context.tr('No customer found with this number.'),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                             ElevatedButton.icon(
                              onPressed: () async {
                                final rawMobile = _mobileController.text.trim();
                                final formattedMobile = rawMobile.startsWith('91') ? rawMobile : '91$rawMobile';
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddCustomerScreen(
                                      phoneNumber: formattedMobile,
                                    ),
                                  ),
                                );
                                // If customer was added, auto-search again
                                if (result != null) {
                                  final token = context.read<AuthProvider>().token;
                                  if (token != null) {
                                    context.read<CustomerProvider>().searchCustomer(
                                      formattedMobile,
                                      token,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: Text(context.tr('Add New Customer')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF000080),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  if (provider.customerData != null) {
                    final data = provider.customerData!;
                    final vehicles = data['vehicles'] as List<dynamic>;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Details Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF000080).withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Color(0xFF000080)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('Type: ${data['type']}  •  ${data['phone']}'),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('Customer Vehicles'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () => _showAddVehicleDialog(context, data),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(context.tr('Add Vehicle')),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF000080),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Vehicle List
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: vehicles.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final v = vehicles[index];
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InvoiceCreateScreen(
                                        customer: data,
                                        vehicle: v,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          v['no'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: const Color(0xFF000080).withOpacity(0.08),
                                             borderRadius: BorderRadius.circular(8),
                                           ),
                                           child: Text(
                                             (v['vehicle_type'] != null && v['vehicle_type'].toString().isNotEmpty)
                                                 ? "${v['vehicle_type']} - ${v['type']}"
                                                 : v['type'],
                                             style: const TextStyle(
                                               fontWeight: FontWeight.bold,
                                               color: Color(0xFF000080),
                                               fontSize: 12,
                                             ),
                                           ),
                                         ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12.0),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('No. of visits: ${v['visits'] ?? 0}'),
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            // if (v['scheme_name'] != null)
                                            //   Text(
                                            //     'Scheme: ${v['scheme_name']}',
                                            //     style: const TextStyle(color: Color(0xFF000080), fontSize: 13, fontWeight: FontWeight.w600),
                                            //   )
                                            // else
                                            //   Text(
                                            //     'Scheme: Not Available',
                                            //     style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                            //   ),
                                          ],
                                        ),
                                        // if (v['scheme_name'] != null && v['is_eligible'] == true)
                                        //   ElevatedButton(
                                        //     onPressed: () {},
                                        //     style: ElevatedButton.styleFrom(
                                        //       backgroundColor: Colors.green,
                                        //       foregroundColor: Colors.white,
                                        //       shape: RoundedRectangleBorder(
                                        //         borderRadius: BorderRadius.circular(8),
                                        //       ),
                                        //       elevation: 0,
                                        //     ),
                                        //     child: Text(context.tr('Eligible'), style: TextStyle(fontWeight: FontWeight.bold)),
                                        //   )
                                        // else if (v['scheme_name'] != null)
                                        //   Container(
                                        //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        //     decoration: BoxDecoration(
                                        //       color: Colors.grey.shade200,
                                        //       borderRadius: BorderRadius.circular(8),
                                        //     ),
                                        //     child: Text(
                                        //       'Not Eligible',
                                        //       style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                        //     ),
                                        //   )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                          )
                        ],
                      ),
                    );
                  }

                  // Default empty state
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Search for a customer\nto start a new job'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVehicleDialog(BuildContext context, Map<String, dynamic> customerData) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddVehicleDialog(
        customerData: customerData,
        token: token,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Vehicle added successfully!')),
          backgroundColor: Colors.green,
        ),
      );
      // Refresh the search automatically
      context.read<CustomerProvider>().searchCustomer(
        customerData['phone'],
        token,
      );
    }
  }
}

class _AddVehicleDialog extends StatefulWidget {
  final Map<String, dynamic> customerData;
  final String token;

  const _AddVehicleDialog({
    required this.customerData,
    required this.token,
  });

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  
  Map<String, dynamic>? _fullCustomerData;
  List<dynamic> _vehicleModels = [];
  Map<String, List<dynamic>> _vehicleModelsByType = {};
  Map<String, dynamic>? _selectedModel;
  final _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getCustomer(widget.customerData['id'], widget.token),
        ApiService.getFormData(widget.token),
      ]);

      final customerRes = results[0];
      final formDataRes = results[1];

      if (customerRes['success'] == true && formDataRes['success'] == true) {
        final models = formDataRes['vehicle_models'] as List<dynamic>;
        final Map<String, List<dynamic>> grouped = {};
        for (final m in models) {
          final type = m['vehicle_type'] as String;
          grouped.putIfAbsent(type, () => []).add(m);
        }

        setState(() {
          _fullCustomerData = customerRes['customer'];
          _vehicleModels = models;
          _vehicleModelsByType = grouped;
          if (models.isNotEmpty) {
            _selectedModel = models.first;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load details or options';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final number = _numberController.text.trim().toUpperCase();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter vehicle number'))),
      );
      return;
    }
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select a vehicle model'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await ApiService.editCustomer({
        'customer_id': _fullCustomerData!['id'],
        'name': _fullCustomerData!['name'],
        'phone': _fullCustomerData!['phone'],
        'whatsapp_number': _fullCustomerData!['whatsapp_number'] ?? '',
        'email': _fullCustomerData!['email'] ?? '',
        'address': _fullCustomerData!['address'] ?? '',
        'customer_type_id': _fullCustomerData!['customer_type_id'],
        'new_vehicles': [
          {
            'vehicle_number': number,
            'vehicle_model_id': _selectedModel!['id'],
          }
        ],
      }, widget.token);

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to add vehicle';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSaving = false;
      });
    }
  }

  List<DropdownMenuItem<Map<String, dynamic>>> _buildGroupedDropdownItems() {
    final items = <DropdownMenuItem<Map<String, dynamic>>>[];
    _vehicleModelsByType.forEach((type, models) {
      items.add(DropdownMenuItem<Map<String, dynamic>>(
        enabled: false,
        value: null,
        child: Text(
          type.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ));
      for (final m in models) {
        items.add(DropdownMenuItem<Map<String, dynamic>>(
          value: m,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(m['name']),
          ),
        ));
      }
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.tr('Add Vehicle'),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF000080)),
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage.isNotEmpty) ...[
                    Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.tr('Vehicle Model'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        menuMaxHeight: 350,
                        value: _selectedModel,
                        hint: Text(context.tr('Select model...')),
                        items: _buildGroupedDropdownItems(),
                        onChanged: (val) => setState(() => _selectedModel = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Vehicle Number'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _numberController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: context.tr('e.g. KL 01 AB 1234'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF000080)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.tr('Cancel'), style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000080),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(context.tr('Save')),
        ),
      ],
    );
  }
}
