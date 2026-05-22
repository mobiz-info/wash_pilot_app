import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'invoice_create_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingsListScreen extends StatefulWidget {
  const BookingsListScreen({super.key});

  @override
  State<BookingsListScreen> createState() => _BookingsListScreenState();
}

class _BookingsListScreenState extends State<BookingsListScreen> {
  bool _isLoading = false;
  List<dynamic> _bookings = [];
  String _errorMessage = '';

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _fetchBookings();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final res = await ApiService.listBookings(
        token,
        fromDate: _fromDate != null ? _formatDate(_fromDate!) : null,
        toDate: _toDate != null ? _formatDate(_toDate!) : null,
      );
      if (res['success'] == true) {
        setState(() {
          _bookings = res['bookings'] as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load bookings';
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

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080), onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate != null && _fromDate!.isAfter(picked)) _fromDate = picked;
      }
    });
    _fetchBookings();
  }

  Future<void> _updateStatus(String bookingId, String status) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final res = await ApiService.updateBookingStatus(bookingId, status, token);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'confirmed' ? '✅ Booking started!' : '❌ Booking cancelled.'),
          backgroundColor: status == 'confirmed' ? Colors.green : Colors.red,
        ),
      );
      _fetchBookings(); // Refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmAction(Map<String, dynamic> booking, String action) {
    final isStart = action == 'confirmed';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isStart ? Icons.play_circle : Icons.cancel_outlined,
                color: isStart ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(isStart ? 'Start Booking' : 'Cancel Booking',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isStart
                ? 'Mark this booking as started/confirmed?'
                : 'Are you sure you want to cancel this booking?',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            _dialogRow(Icons.directions_car, booking['vehicle']['number']),
            const SizedBox(height: 4),
            _dialogRow(Icons.person, booking['customer']['name']),
            const SizedBox(height: 4),
            _dialogRow(Icons.calendar_today, _formatDisplayDate(booking['booking_date'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(booking['id'], action);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isStart ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isStart ? 'Start' : 'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  String _formatDisplayDate(String rawDate) {
    try {
      final d = DateTime.parse(rawDate);
      return _displayDate(d);
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _sendReadyAlert(Map<String, dynamic> booking) async {
    final customer = booking['customer'];
    final vehicle = booking['vehicle'];
    final name = customer['name'] ?? 'Customer';
    final vehicleNumber = vehicle['number'] ?? 'your vehicle';
    
    String phone = customer['phone'] ?? '';
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length == 10) {
      phone = '91$phone'; // Assuming default country code +91
    }

    final message = Uri.encodeComponent('Hello $name, your vehicle ($vehicleNumber) is ready for pickup! Thank you for choosing our service.');
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Bookings', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Filter Bar
          Container(
            color: const Color(0xFF000080),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Row(
              children: [
                Expanded(child: _datePicker(label: 'From', date: _fromDate, isFrom: true)),
                const SizedBox(width: 12),
                Expanded(child: _datePicker(label: 'To', date: _toDate, isFrom: false)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _fetchBookings,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.search, color: Color(0xFF000080)),
                  ),
                ),
              ],
            ),
          ),

          // Booking count
          if (!_isLoading && _bookings.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    '${_bookings.length} booking${_bookings.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _bookings.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchBookings,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _bookings.length,
                              itemBuilder: (ctx, i) => _bookingCard(_bookings[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker({required String label, required DateTime? date, required bool isFrom}) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF000080)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  Text(
                    date != null ? _displayDate(date) : 'Select',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1e293b)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';

    final statusColor = isPending
        ? Colors.orange
        : isConfirmed
            ? Colors.blue
            : isCancelled
                ? Colors.red
                : Colors.green;

    final statusLabel = isPending
        ? '⏳ Pending'
        : isConfirmed
            ? '✅ Confirmed'
            : isCancelled
                ? '❌ Cancelled'
                : '🎉 Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Vehicle + customer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF000080).withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.directions_car, color: Color(0xFF000080), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking['vehicle']['number'],
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8, color: const Color(0xFF1e293b))),
                              Text(booking['vehicle']['model'],
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(booking['customer']['name'], style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade800)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(booking['customer']['phone'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    ],
                  ),
                ),
                // Date & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatDisplayDate(booking['booking_date']),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF000080))),
                    if (booking['booking_time'] != null)
                      Text(booking['booking_time'],
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(statusLabel,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
              ],
            ),

            // Notes
            if ((booking['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Expanded(child: Text(booking['notes'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700))),
                  ],
                ),
              ),
            ],

            // Action buttons
            if (isPending || isConfirmed || isCompleted) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isPending)
                    Expanded(
                      child: _actionBtn(
                        label: 'Start',
                        icon: Icons.play_circle_outline,
                        color: Colors.green,
                        onTap: () => _confirmAction(booking, 'confirmed'),
                      ),
                    ),
                  if (isConfirmed)
                    Expanded(
                      child: _actionBtn(
                        label: 'Create Invoice',
                        icon: Icons.receipt_long,
                        color: const Color(0xFF000080),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InvoiceCreateScreen(
                                customer: Map<String, dynamic>.from(booking['customer'] as Map),
                                vehicle: Map<String, dynamic>.from(booking['vehicle'] as Map),
                                bookingId: booking['id'] as String,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (isCompleted)
                    Expanded(
                      child: _actionButton(
                        label: 'Ready Alert',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                  // onTap: () => _showAlertDialog('ready'),
                        onTap: () => _sendReadyAlert(booking),
                      ),
                    ),
                  if (isPending || isConfirmed) const SizedBox(width: 12),
                  if (isPending || isConfirmed)
                    Expanded(
                      child: _actionBtn(
                        label: 'Cancel',
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                        onTap: () => _confirmAction(booking, 'cancelled'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

   Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            // Icon(icon, color: Colors.white, size: 23),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  

  Widget _actionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('No bookings found', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
          Text('for the selected date range.', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade200),
          const SizedBox(height: 16),
          Text(_errorMessage, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.red, fontSize: 14)),
        ],
      ),
    );
  }
}
