import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart';
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
        title: const Text('New Job', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      hintText: 'Enter Mobile Number',
                      prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
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
                      context.read<CustomerProvider>().searchCustomer(_mobileController.text.trim(), token);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Not authenticated. Please login again.')),
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
                              'No customer found with this number.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddCustomerScreen(
                                      phoneNumber: _mobileController.text.trim(),
                                    ),
                                  ),
                                );
                                // If customer was added, auto-search again
                                if (result != null) {
                                  final token = context.read<AuthProvider>().token;
                                  if (token != null) {
                                    context.read<CustomerProvider>().searchCustomer(
                                      _mobileController.text.trim(),
                                      token,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add New Customer'),
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
                                        'Type: ${data['type']}  •  ${data['phone']}',
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
                          const Text(
                            'Customer Vehicles',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            v['type'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
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
                                              'No. of visits: ${v['visits'] ?? 0}',
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
                                        //     child: const Text('Eligible', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          'Search for a customer\nto start a new job',
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
}
