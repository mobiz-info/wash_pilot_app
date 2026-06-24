import 'dart:io';

import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _allCustomers = [];
  List<dynamic> _filteredCustomers = [];
  Set<String> _selectedCustomerIds = {};

  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  // Broadcasting State
  bool _isBroadcasting = false;
  List<dynamic> _broadcastQueue = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.listCustomers(token);
      if (res['success'] == true) {
        setState(() {
          _allCustomers = res['customers'];
          _filteredCustomers = List.from(_allCustomers);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load customers';
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

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final name = (c['name'] ?? '').toLowerCase();
        final phone = (c['phone'] ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        for (var c in _filteredCustomers) {
          _selectedCustomerIds.add(c['id']);
        }
      } else {
        for (var c in _filteredCustomers) {
          _selectedCustomerIds.remove(c['id']);
        }
      }
    });
  }

  void _startBroadcast() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter a message to send.')), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedCustomerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please select at least one customer.')), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _broadcastQueue = _allCustomers.where((c) => _selectedCustomerIds.contains(c['id'])).toList();
      _currentIndex = 0;
      _isBroadcasting = true;
    });
  }

  Future<void> _sendToCurrent() async {
    if (_currentIndex >= _broadcastQueue.length) return;

    final customer = _broadcastQueue[_currentIndex];
    String phone = customer['phone'] ?? '';
    
    // Clean phone number (remove spaces, +, etc)
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Default country code if missing (assumes India +91 for example, but adjust as needed or rely on stored format)
    // Most users store either full format or 10 digits.
    if (phone.length == 10) {
      phone = '91$phone'; // You can change this to UAE (971) or leave it as is if they store country code.
    }

    final message = Uri.encodeComponent(_messageController.text.trim());
    
    // Universal WhatsApp Link
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      // Automatically advance to the next person for when they return to the app
      setState(() {
        _currentIndex++;
      });
      if (_currentIndex >= _broadcastQueue.length) {
        // Finished
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('🎉 Sending Complete!')),
            content: Text(context.tr('You have reached the end of the notification list.')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isBroadcasting = false;
                    _selectedCustomerIds.clear();
                    _messageController.clear();
                  });
                },
                child: Text(context.tr('Done')),
              )
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Could not open WhatsApp. Is it installed?')), backgroundColor: Colors.red),
      );
    }
  }

  void _skipCurrent() {
    setState(() {
      _currentIndex++;
      if (_currentIndex >= _broadcastQueue.length) {
        _isBroadcasting = false;
        _selectedCustomerIds.clear();
      }
    });
  }

  void _stopBroadcasting() {
    setState(() {
      _isBroadcasting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isBroadcasting) {
      return _buildBroadcastingView();
    }
    return _buildSetupView();
  }

  Widget _buildSetupView() {
    final allSelected = _filteredCustomers.isNotEmpty && 
                        _filteredCustomers.every((c) => _selectedCustomerIds.contains(c['id']));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('New Notification'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Message Box
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Message Content'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: context.tr('Type something...'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Search and Filters
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.tr('Search customers...'),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    
                    // Select All Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('Select Customers (${_selectedCustomerIds.length} selected)'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          Row(
                            children: [
                              Text(context.tr('Select All'), style: GoogleFonts.inter(fontSize: 13)),
                              Checkbox(
                                value: allSelected,
                                onChanged: _toggleSelectAll,
                                activeColor: const Color(0xFF000080),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    // List of customers
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (ctx, i) {
                          final c = _filteredCustomers[i];
                          final isSelected = _selectedCustomerIds.contains(c['id']);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? const Color(0xFF000080) : Colors.grey.shade200),
                            ),
                            child: CheckboxListTile(
                              title: Text(c['name'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              subtitle: Text(c['phone'] ?? 'No phone', style: GoogleFonts.inter(fontSize: 12)),
                              value: isSelected,
                              activeColor: const Color(0xFF000080),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedCustomerIds.add(c['id']);
                                  } else {
                                    _selectedCustomerIds.remove(c['id']);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Start Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                      ),
                      child: SafeArea(
                        child: ElevatedButton(
                          onPressed: _startBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            '${context.tr('Start Sending to')} ${_selectedCustomerIds.length}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
    );
  }

  Widget _buildBroadcastingView() {
    if (_currentIndex >= _broadcastQueue.length) {
      return Scaffold(body: Center(child: Text(context.tr('Done'))));
    }
    
    final currentCustomer = _broadcastQueue[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(context.tr('Sending Notifications...'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _stopBroadcasting,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.tr('Customer ${_currentIndex + 1} of ${_broadcastQueue.length}'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _broadcastQueue.length,
              backgroundColor: Colors.grey.shade300,
              color: Colors.green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF000080).withOpacity(0.1),
                    child: const Icon(Icons.person, size: 40, color: Color(0xFF000080)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentCustomer['name'] ?? 'Unknown',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentCustomer['phone'] ?? 'No phone',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton.icon(
                    onPressed: _sendToCurrent,
                    icon: const Icon(Icons.send),
                    label: Text(context.tr('Send in WhatsApp'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: _skipCurrent,
                    child: Text(context.tr('Skip Customer'), style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16)),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            Text(
              context.tr('Tip: After pressing Send, WhatsApp will open. Hit send there, then return to this app to automatically advance to the next customer.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
            )
          ],
        ),
      ),
    );
  }
}
