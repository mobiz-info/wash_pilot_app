import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// ─── Entry screen ──────────────────────────────────────────────────────────────
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _reports = [
    {
      'title': 'Job Report',
      'subtitle': 'All invoices & job summary',
      'icon': Icons.receipt_long_outlined,
      'color': Color(0xFF2563EB),
      'bg': Color(0xFFEFF6FF),
      'type': 'job',
    },
    {
      'title': 'Scheme Beneficiary',
      'subtitle': 'Customers who redeemed schemes',
      'icon': Icons.card_giftcard_outlined,
      'color': Color(0xFF7C3AED),
      'bg': Color(0xFFF5F3FF),
      'type': 'scheme',
    },
    {
      'title': 'Collection Report',
      'subtitle': 'All payment collections',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFF059669),
      'bg': Color(0xFFECFDF5),
      'type': 'collection',
    },
    {
      'title': 'Outstanding Report',
      'subtitle': 'Unpaid invoice balances',
      'icon': Icons.pending_actions_outlined,
      'color': Color(0xFFDC2626),
      'bg': Color(0xFFFEF2F2),
      'type': 'outstanding',
    },
    {
      'title': 'Booking Report',
      'subtitle': 'All bookings & status summary',
      'icon': Icons.calendar_month_outlined,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7),
      'type': 'booking',
    },
    {
      'title': 'Cancellation Report',
      'subtitle': 'All cancelled bookings',
      'icon': Icons.cancel_presentation_outlined,
      'color': Color(0xFF475569),
      'bg': Color(0xFFF1F5F9),
      'type': 'cancellation',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Reports',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _reports.length,
        itemBuilder: (context, i) {
          final r = _reports[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(
                  reportType: r['type'] as String,
                  title: r['title'] as String,
                ),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: r['bg'] as Color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      r['icon'] as IconData,
                      color: r['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title'] as String,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Detail screen ─────────────────────────────────────────────────────────────
class ReportDetailScreen extends StatefulWidget {
  final String reportType;
  final String title;
  const ReportDetailScreen({
    super.key,
    required this.reportType,
    required this.title,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }

  DateTime _fromDate = DateTime.now(); // Changed to today
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _data;
  String _error = '';
  List<dynamic> _branches = [];
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _load();
  }

  String get _fromStr => DateFormat('dd-MM-yyyy').format(_fromDate);
  String get _toStr => DateFormat('dd-MM-yyyy').format(_toDate);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      Map<String, dynamic> res;
      switch (widget.reportType) {
        case 'job':
          res = await ApiService.getJobReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        case 'scheme':
          res = await ApiService.getSchemeBeneficiaryReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        case 'collection':
          res = await ApiService.getCollectionReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        case 'outstanding':
          res = await ApiService.getOutstandingReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        case 'booking':
          res = await ApiService.getBookingReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        case 'cancellation':
          res = await ApiService.getCancellationReport(
            token,
            _fromStr,
            _toStr,
            branchId: _selectedBranchId,
          );
          break;
        default:
          res = {'success': false, 'message': 'Unknown report'};
      }
      if (res['success'] == true) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBranches() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isCompanyAdmin || auth.token == null) return;

    try {
      final res = await ApiService.getCompanyBranches(auth.token!);
      if (!mounted || res['success'] != true) return;
      setState(() => _branches = res['branches'] ?? []);
    } catch (_) {
      // Reports can still load company-wide if the branch list is unavailable.
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF000080)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          _fromDate = picked;
        else
          _toDate = picked;
      });
      _load();
    }
  }

  Future<void> _downloadPdf() async {
    if (_data == null ||
        _data!['rows'] == null ||
        (_data!['rows'] as List).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to generate PDF.')));
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });
    try {
      final pdf = pw.Document();
      final rows = _data!['rows'] as List<dynamic>;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPdfHeader(),
              pw.SizedBox(height: 20),
              _buildPdfSummary(),
              pw.SizedBox(height: 20),
              _buildPdfTable(rows),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            '${widget.title.replaceAll(' ', '_')}_${_fromStr}_to_${_toStr}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  pw.Widget _buildPdfHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          widget.title,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#000080'),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Date Range: ${DateFormat('dd MMM yyyy').format(_fromDate)} - ${DateFormat('dd MMM yyyy').format(_toDate)}',
          style: const pw.TextStyle(fontSize: 14),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Branch: ${_selectedBranchName}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated On: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildPdfSummary() {
    final d = _data!;
    List<pw.Widget> items = [];

    switch (widget.reportType) {
      case 'job':
        items = [
          _pdfSummaryItem('Jobs', '${d['total_jobs']}'),
          _pdfSummaryItem('Revenue', 'Rs. ${_fmt(d['total_revenue'])}'),
          _pdfSummaryItem('Collected', 'Rs. ${_fmt(d['total_collected'])}'),
          _pdfSummaryItem('Discount', 'Rs. ${_fmt(d['total_discount'])}'),
        ];
        break;
      case 'scheme':
        items = [
          _pdfSummaryItem('Redemptions', '${d['total_count']}'),
          _pdfSummaryItem('Total Discount', 'Rs. ${_fmt(d['total_discount'])}'),
        ];
        break;
      case 'collection':
        items = [
          _pdfSummaryItem(
            'Total Collected',
            'Rs. ${_fmt(d['total_collected'])}',
          ),
          _pdfSummaryItem('Count', '${d['count']}'),
        ];
        break;
      case 'outstanding':
        items = [
          _pdfSummaryItem('Invoices', '${d['count']}'),
          _pdfSummaryItem(
            'Total Outstanding',
            'Rs. ${_fmt(d['total_outstanding'])}',
          ),
        ];
        break;
      case 'booking':
        items = [
          _pdfSummaryItem('Bookings', '${d['total_bookings']}'),
          _pdfSummaryItem('Pending', '${d['total_pending']}'),
          _pdfSummaryItem('Confirmed', '${d['total_confirmed']}'),
          _pdfSummaryItem('Completed', '${d['total_completed']}'),
          _pdfSummaryItem('Cancelled', '${d['total_cancelled']}'),
        ];
        break;
      case 'cancellation':
        items = [
          _pdfSummaryItem('Cancelled', '${d['total_cancelled']}'),
        ];
        break;
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: items,
    );
  }

  pw.Widget _pdfSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTable(List<dynamic> rows) {
    List<String> headers = [];
    List<List<String>> data = [];

    switch (widget.reportType) {
      case 'job':
        headers = [
          'Date',
          'Invoice No',
          'Customer',
          'Vehicle',
          'Total',
          'Collected',
        ];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['invoice_number'] ?? '',
            '${r['customer']} (${r['phone']})',
            r['vehicle'] ?? '',
            _fmt(r['total']),
            _fmt(r['collected']),
          ]);
        }
        break;
      case 'scheme':
        headers = ['Date', 'Invoice No', 'Customer', 'Scheme', 'Discount'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['invoice_number'] ?? '',
            r['customer'] ?? '',
            '${r['scheme']} (${r['scheme_type']})',
            _fmt(r['discount']),
          ]);
        }
        break;
      case 'collection':
        headers = [
          'Date',
          'Receipt No',
          'Invoice No',
          'Customer',
          'Mode',
          'Amount',
        ];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['receipt_number'] ?? '',
            r['invoice_number'] ?? '',
            r['customer'] ?? '',
            (r['payment_mode'] ?? '').toString().toUpperCase(),
            _fmt(r['amount']),
          ]);
        }
        break;
      case 'outstanding':
        headers = [
          'Date',
          'Invoice No',
          'Customer',
          'Total',
          'Collected',
          'Balance',
        ];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['invoice_number'] ?? '',
            r['customer'] ?? '',
            _fmt(r['total']),
            _fmt(r['collected']),
            _fmt(r['balance']),
          ]);
        }
        break;
      case 'booking':
        headers = ['Date', 'Time', 'Customer', 'Vehicle', 'Status'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['time'] ?? '',
            '${r['customer']} (${r['phone']})',
            r['vehicle'] ?? '',
            (r['status'] ?? '').toString().toUpperCase(),
          ]);
        }
        break;
      case 'cancellation':
        headers = ['Date', 'Time', 'Customer', 'Vehicle', 'Status'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            r['time'] ?? '',
            '${r['customer']} (${r['phone']})',
            r['vehicle'] ?? '',
            'CANCELLED',
          ]);
        }
        break;
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
      cellHeight: 30,
      cellAlignments: {
        for (int i = 0; i < headers.length; i++)
          i: i >= headers.length - 2 &&
                  widget.reportType != 'scheme' &&
                  widget.reportType != 'booking' &&
                  widget.reportType != 'cancellation'
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_data != null && (_data!['rows'] as List).isNotEmpty)
            _isGeneratingPdf
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Download PDF',
                    onPressed: _downloadPdf,
                  ),
        ],
      ),
      body: Column(
        children: [
          // Date filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        'From',
                        _fromDate,
                        () => _pickDate(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateButton(
                        'To',
                        _toDate,
                        () => _pickDate(isFrom: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000080),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                if (context.watch<AuthProvider>().isCompanyAdmin) ...[
                  const SizedBox(height: 12),
                  _branchDropdown(),
                ],
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error,
                          style: GoogleFonts.inter(color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _data == null
                ? const SizedBox()
                : _buildSingleBody(),
          ),
        ],
      ),
    );
  }

  String get _selectedBranchName {
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      return 'All branches';
    }
    for (final branch in _branches) {
      final item = Map<String, dynamic>.from(branch as Map);
      if (item['id']?.toString() == _selectedBranchId) {
        return item['name']?.toString() ?? 'Selected branch';
      }
    }
    return 'Selected branch';
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Branch',
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFF000080).withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: const Color(0xFF000080).withOpacity(0.2),
          ),
        ),
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('All branches')),
        ..._branches.map((branch) {
          final item = Map<String, dynamic>.from(branch as Map);
          return DropdownMenuItem<String>(
            value: item['id']?.toString() ?? '',
            child: Text(item['name']?.toString() ?? ''),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value == null || value.isEmpty ? null : value;
        });
        _load();
      },
    );
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF000080).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: const Color(0xFF000080).withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yy').format(date),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Single body (Job / Scheme / Outstanding / Collection) ───

  Widget _buildSingleBody() {
    final d = _data!;
    final rows = d['rows'] as List<dynamic>;
    return Column(
      children: [
        _buildSummaryBar(),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 56,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No data for this period',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) => _buildRow(
                    rows[i],
                    isReceipt: widget.reportType == 'collection',
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Summary bar ─────────────────────────────────────────────

  Widget _buildSummaryBar() {
    final d = _data!;
    final currencySymbol = context.read<AuthProvider>().currencySymbol;
    List<Map<String, dynamic>> items = [];

    switch (widget.reportType) {
      case 'job':
        items = [
          {
            'label': 'Jobs',
            'value': '${d['total_jobs']}',
            'color': const Color(0xFF2563EB),
          },
          {
            'label': 'Revenue',
            'value': '$currencySymbol${_fmt(d['total_revenue'])}',
            'color': const Color(0xFF059669),
          },
          {
            'label': 'Collected',
            'value': '$currencySymbol${_fmt(d['total_collected'])}',
            'color': const Color(0xFF7C3AED),
          },
          {
            'label': 'Discount',
            'value': '$currencySymbol${_fmt(d['total_discount'])}',
            'color': const Color(0xFFDC2626),
          },
        ];
        break;
      case 'scheme':
        items = [
          {
            'label': 'Redemptions',
            'value': '${d['total_count']}',
            'color': const Color(0xFF7C3AED),
          },
          {
            'label': 'Total Discount',
            'value': '$currencySymbol${_fmt(d['total_discount'])}',
            'color': const Color(0xFF059669),
          },
        ];
        break;
      case 'collection':
        items = [
          {
            'label': 'Total Collected',
            'value': '$currencySymbol${_fmt(d['total_collected'])}',
            'color': const Color(0xFF059669),
          },
          {
            'label': 'Count',
            'value': '${d['count']}',
            'color': const Color(0xFF1E293B),
          },
        ];
        break;
      case 'outstanding':
        items = [
          {
            'label': 'Invoices',
            'value': '${d['count']}',
            'color': const Color(0xFFDC2626),
          },
          {
            'label': 'Total Outstanding',
            'value': '$currencySymbol${_fmt(d['total_outstanding'])}',
            'color': const Color(0xFFDC2626),
          },
        ];
        break;
      case 'booking':
        items = [
          {
            'label': 'Bookings',
            'value': '${d['total_bookings']}',
            'color': const Color(0xFF1E293B),
          },
          {
            'label': 'Pending',
            'value': '${d['total_pending']}',
            'color': const Color(0xFFD97706),
          },
          {
            'label': 'Confirmed',
            'value': '${d['total_confirmed']}',
            'color': const Color(0xFF2563EB),
          },
          {
            'label': 'Completed',
            'value': '${d['total_completed']}',
            'color': const Color(0xFF059669),
          },
          {
            'label': 'Cancelled',
            'value': '${d['total_cancelled']}',
            'color': const Color(0xFFDC2626),
          },
        ];
        break;
      case 'cancellation':
        items = [
          {
            'label': 'Cancelled',
            'value': '${d['total_cancelled']}',
            'color': const Color(0xFFDC2626),
          },
        ];
        break;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Column(
                  children: [
                    Text(
                      item['value'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: item['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ─── Row card ────────────────────────────────────────────────

  Widget _bookingStatusChip(String status) {
    final isPending = status == 'pending';
    final isConfirmed = status == 'confirmed';
    final isCancelled = status == 'cancelled';

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
            ? 'Confirmed'
            : isCancelled
                ? 'Cancelled'
                : 'Completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusLabel,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> row, {bool isReceipt = false}) {
    final isBookingOrCancel = widget.reportType == 'booking' || widget.reportType == 'cancellation';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReceipt
                    ? (row['receipt_number'] ?? '')
                    : isBookingOrCancel
                        ? 'Booking #${row['auto_id'] ?? ''}'
                        : (row['invoice_number'] ?? ''),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF000080),
                ),
              ),
              Text(
                row['date'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          if (isReceipt) ...[
            const SizedBox(height: 4),
            Text(
              'Invoice: ${row['invoice_number']}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Customer & vehicle
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${row['customer'] ?? ''} · ${row['phone'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 14,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                row['vehicle'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              if (row['branch'] != null && (row['branch'] as String).isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    row['branch'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          // Services (job report)
          if (row.containsKey('services') &&
              (row['services'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.build_outlined,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    row['services'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Notes (booking report specific)
          if (isBookingOrCancel &&
              row['notes'] != null &&
              (row['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row['notes'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Scheme
          if (row.containsKey('scheme') &&
              row['scheme'] != null &&
              row['scheme'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 14,
                  color: Colors.purple.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  '${row['scheme']}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    row['scheme_type'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.purple.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Payment mode (receipt)
          if (isReceipt && row.containsKey('payment_mode')) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.payment_outlined,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  (row['payment_mode'] as String).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 16),

          // Amount row / Status row
          Row(
            children: [
              if (isBookingOrCancel) ...[
                _bookingStatusChip(row['status'] ?? ''),
                if (row['time'] != null && (row['time'] as String).isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _chip(
                    'Time',
                    row['time'],
                    const Color(0xFFF1F5F9),
                    Colors.grey.shade800,
                  ),
                ],
              ] else ...[
                if (row.containsKey('total')) ...[
                  _chip(
                    'Total',
                    '$currencySymbol${_fmt(row['total'])}',
                    Colors.grey.shade100,
                    Colors.grey.shade800,
                  ),
                  const SizedBox(width: 8),
                ],
                if (row.containsKey('collected') && !isReceipt)
                  _chip(
                    'Collected',
                    '$currencySymbol${_fmt(row['collected'])}',
                    const Color(0xFFECFDF5),
                    const Color(0xFF059669),
                  ),
                if (row.containsKey('balance'))
                  _chip(
                    'Balance',
                    '$currencySymbol${_fmt(row['balance'])}',
                    const Color(0xFFFEF2F2),
                    const Color(0xFFDC2626),
                  ),
                if (row.containsKey('discount') &&
                    row['discount'] != '0.00' &&
                    row['discount'] != null)
                  _chip(
                    'Discount',
                    '$currencySymbol${_fmt(row['discount'])}',
                    const Color(0xFFF5F3FF),
                    const Color(0xFF7C3AED),
                  ),
                if (isReceipt && row.containsKey('amount'))
                  _chip(
                    'Amount',
                    '$currencySymbol${_fmt(row['amount'])}',
                    const Color(0xFFECFDF5),
                    const Color(0xFF059669),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: fg.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    try {
      final d = double.parse(val.toString());
      if (d == d.truncate()) return d.toInt().toString();
      return d.toStringAsFixed(2);
    } catch (_) {
      return val.toString();
    }
  }
}
