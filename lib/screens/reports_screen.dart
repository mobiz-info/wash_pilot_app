import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
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
      'title': 'Income Report',
      'subtitle': 'Revenue grouped by service',
      'icon': Icons.monetization_on_outlined,
      'color': Color(0xFF059669),
      'bg': Color(0xFFECFDF5),
      'type': 'income',
    },
     {
      'title': 'Expense Report',
      'subtitle': 'Expenses grouped by head',
      'icon': Icons.pie_chart_outline,
      'color': Color(0xFFE11D48),
      'bg': Color(0xFFFFF1F2),
      'type': 'expense_head',
    },
    {
      'title': 'Profit Report',
      'subtitle': 'Income vs Expense summary',
      'icon': Icons.analytics_outlined,
      'color': Color(0xFF0F766E),
      'bg': Color(0xFFF0FDF4),
      'type': 'profit',
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
   
    {
      'title': 'Leave Report',
      'subtitle': 'Staff leaves and statuses',
      'icon': Icons.work_off_outlined,
      'color': Color(0xFFD97706),
      'bg': Color(0xFFFEF3C7),
      'type': 'leave',
    },
    
  ];

  static const _daywiseReports = [
    {
      'title': 'Daywise Income Report',
      'subtitle': 'Day-by-day revenue summary',
      'icon': Icons.monetization_on_outlined,
      'color': Color(0xFF059669),
      'bg': Color(0xFFECFDF5),
      'type': 'daywise_income',
    },
    {
      'title': 'Daywise Profit Report',
      'subtitle': 'Day-by-day income vs expense',
      'icon': Icons.analytics_outlined,
      'color': Color(0xFF0F766E),
      'bg': Color(0xFFF0FDF4),
      'type': 'daywise_profit',
    },
    {
      'title': 'Daywise Collection Report',
      'subtitle': 'Day-by-day payment collections',
      'icon': Icons.account_balance_wallet_outlined,
      'color': Color(0xFF2563EB),
      'bg': Color(0xFFEFF6FF),
      'type': 'daywise_collection',
    },
    {
      'title': 'Daywise Outstanding Report',
      'subtitle': 'Day-by-day outstanding balances',
      'icon': Icons.pending_actions_outlined,
      'color': Color(0xFFDC2626),
      'bg': Color(0xFFFEF2F2),
      'type': 'daywise_outstanding',
    },
  ];

  Widget _buildReportTile(BuildContext context, Map<String, dynamic> r) {
    return GestureDetector(
      onTap: () {
        if (r['type'] == 'profit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProfitReportScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(
                reportType: r['type'] as String,
                title: r['title'] as String,
              ),
            ),
          );
        }
      },
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final reports = _reports.where((r) {
      if (r['type'] == 'expense_head') {
        return auth.isCompanyAdmin;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Reports'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.tr('General Reports'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF000080),
              ),
            ),
          ),
          ...reports.map((r) => _buildReportTile(context, r)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.tr('Daywise Consolidated Reports'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF000080),
              ),
            ),
          ),
          ..._daywiseReports.map((r) => _buildReportTile(context, r)),
        ],
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
      if (widget.reportType.startsWith('daywise_')) {
        final subType = widget.reportType.substring(8); // 'income', 'profit', 'collection', 'outstanding'
        res = await ApiService.getDaywiseConsolidatedReport(
          token,
          subType,
          _fromStr,
          _toStr,
          branchId: _selectedBranchId,
        );
      } else {
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
          case 'expense_head':
            res = await ApiService.getExpenseHeadWiseReport(
              token,
              _fromStr,
              _toStr,
              branchId: _selectedBranchId,
            );
            break;
          case 'leave':
            res = await ApiService.getLeaveReport(
              token,
              _fromStr,
              _toStr,
              branchId: _selectedBranchId,
            );
            break;
          case 'income':
            res = await ApiService.getServiceTypeReport(
              token,
              _fromStr,
              _toStr,
              branchId: _selectedBranchId,
            );
            break;
          default:
            res = {'success': false, 'message': 'Unknown report'};
        }
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
      ).showSnackBar(SnackBar(content: Text(context.tr('No data to generate PDF.'))));
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
      ).showSnackBar(SnackBar(content: Text(context.tr('Failed to generate PDF: $e'))));
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
      case 'expense_head':
        items = [
          _pdfSummaryItem('Total Expense', 'Rs. ${_fmt(d['total_expense'])}'),
        ];
        break;
      case 'leave':
        items = [
          _pdfSummaryItem('Total Leaves', '${d['total_leaves']}'),
          _pdfSummaryItem('Approved', '${d['approved_leaves']}'),
          _pdfSummaryItem('Pending', '${d['pending_leaves']}'),
        ];
        break;
      case 'income':
        items = [
          _pdfSummaryItem('Total Quantity', '${d['total_count']}'),
          _pdfSummaryItem('Total Income', 'Rs. ${_fmt(d['total_revenue'])}'),
        ];
        break;
      case 'daywise_income':
        items = [
          _pdfSummaryItem('Jobs', '${d['total_jobs']}'),
          _pdfSummaryItem('Revenue', 'Rs. ${_fmt(d['total_income'])}'),
          _pdfSummaryItem('Collected', 'Rs. ${_fmt(d['total_collected'])}'),
        ];
        break;
      case 'daywise_profit':
        items = [
          _pdfSummaryItem('Income', 'Rs. ${_fmt(d['total_income'])}'),
          _pdfSummaryItem('Expense', 'Rs. ${_fmt(d['total_expense'])}'),
          _pdfSummaryItem('Net Profit', 'Rs. ${_fmt(d['total_profit'])}'),
        ];
        break;
      case 'daywise_collection':
        items = [
          _pdfSummaryItem('Cash', 'Rs. ${_fmt(d['total_cash'])}'),
          _pdfSummaryItem('Cheque', 'Rs. ${_fmt(d['total_cheque'])}'),
          _pdfSummaryItem('Online', 'Rs. ${_fmt(d['total_online'])}'),
          _pdfSummaryItem('Total Collected', 'Rs. ${_fmt(d['total_collected'])}'),
        ];
        break;
      case 'daywise_outstanding':
        items = [
          _pdfSummaryItem('Invoices', '${d['total_invoices']}'),
          _pdfSummaryItem('Total Outstanding', 'Rs. ${_fmt(d['total_outstanding'])}'),
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
      case 'expense_head':
        headers = ['Sl No', 'Expense Head', 'Total Amount'];
        for (int idx = 0; idx < rows.length; idx++) {
          final r = rows[idx];
          data.add([
            '${idx + 1}',
            r['expense_head_name'] ?? '',
            _fmt(r['total_amount']),
          ]);
        }
        break;
      case 'leave':
        headers = ['SL', 'Staff Name', 'Branch', 'From', 'To', 'Status', 'Reason'];
        for (int idx = 0; idx < rows.length; idx++) {
          final r = rows[idx];
          String start = r['start_date'] ?? '';
          String end = r['end_date'] ?? '';
          try {
            if (start.isNotEmpty) start = DateFormat('dd-MM-yyyy').format(DateTime.parse(start));
            if (end.isNotEmpty) end = DateFormat('dd-MM-yyyy').format(DateTime.parse(end));
          } catch (_) {}
          data.add([
            '${idx + 1}',
            r['staff_name'] ?? '',
            r['branch_name'] ?? '',
            start,
            end,
            r['status'] ?? '',
            r['reason'] ?? '',
          ]);
        }
        break;
      case 'income':
        headers = ['Sl No', 'Service', 'Amount'];
        for (int idx = 0; idx < rows.length; idx++) {
          final r = rows[idx];
          data.add([
            '${idx + 1}',
            r['service_name'] ?? '',
            _fmt(r['revenue']),
          ]);
        }
        break;
      case 'daywise_income':
        headers = ['Date', 'Job Count', 'Revenue', 'Collected'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            (r['count'] ?? 0).toString(),
            _fmt(r['income']),
            _fmt(r['collected']),
          ]);
        }
        break;
      case 'daywise_profit':
        headers = ['Date', 'Income', 'Expense', 'Net Profit'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            _fmt(r['income']),
            _fmt(r['expense']),
            _fmt(r['profit']),
          ]);
        }
        break;
      case 'daywise_collection':
        headers = ['Date', 'Cash', 'Cheque', 'Online', 'Total'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            _fmt(r['cash']),
            _fmt(r['cheque']),
            _fmt(r['online']),
            _fmt(r['total']),
          ]);
        }
        break;
      case 'daywise_outstanding':
        headers = ['Date', 'Unpaid Invoices', 'Outstanding Balance'];
        for (var r in rows) {
          data.add([
            r['date'] ?? '',
            (r['count'] ?? 0).toString(),
            _fmt(r['outstanding']),
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
          i: (widget.reportType == 'expense_head' && i == 2) ||
                  (widget.reportType == 'income' && i == 2) ||
                  (widget.reportType.startsWith('daywise_') && i >= 1) ||
                  (widget.reportType != 'expense_head' &&
                      widget.reportType != 'income' &&
                      !widget.reportType.startsWith('daywise_') &&
                      widget.reportType != 'leave' &&
                      i >= headers.length - 2 &&
                      widget.reportType != 'scheme' &&
                      widget.reportType != 'booking' &&
                      widget.reportType != 'cancellation')
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
                    tooltip: context.tr('Download PDF'),
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
                          child: Text(context.tr('Retry')),
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
      menuMaxHeight: 350,
      decoration: InputDecoration(
        labelText: context.tr('Branch'),
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
        DropdownMenuItem<String>(value: '', child: Text(context.tr('All branches'))),
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
                        context.tr('No data for this period'),
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
                  itemBuilder: (ctx, i) {
                    final row = rows[i];
                    if (widget.reportType.startsWith('daywise_')) {
                      return _buildDaywiseRow(row);
                    }
                    if (widget.reportType == 'expense_head') {
                      return _buildExpenseHeadRow(row);
                    }
                    if (widget.reportType == 'leave') {
                      return _buildLeaveRow(row);
                    }
                    if (widget.reportType == 'income') {
                      return _buildIncomeRow(row, i);
                    }
                    return _buildRow(
                      row,
                      isReceipt: widget.reportType == 'collection',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDaywiseRow(Map<String, dynamic> row) {
    final currencySymbol = context.read<AuthProvider>().currencySymbol;

    if (widget.reportType == 'daywise_income') {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row['date'] ?? '',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Jobs: ${row['count'] ?? 0}'),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip('Revenue', '$currencySymbol${_fmt(row['income'])}', Colors.grey.shade100, Colors.grey.shade800),
                _chip('Collected', '$currencySymbol${_fmt(row['collected'])}', const Color(0xFFECFDF5), const Color(0xFF059669)),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.reportType == 'daywise_profit') {
      final profitVal = double.tryParse(row['profit']?.toString() ?? '0') ?? 0;
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
            Text(
              row['date'] ?? '',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080)),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip('Income', '$currencySymbol${_fmt(row['income'])}', const Color(0xFFECFDF5), const Color(0xFF059669)),
                _chip('Expense', '$currencySymbol${_fmt(row['expense'])}', const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
                _chip(
                  'Profit',
                  '$currencySymbol${_fmt(row['profit'])}',
                  profitVal >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
                  profitVal >= 0 ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.reportType == 'daywise_collection') {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row['date'] ?? '',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080)),
                ),
                Text(
                  '$currencySymbol${_fmt(row['total'])}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF059669)),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chip('Cash', '$currencySymbol${_fmt(row['cash'])}', Colors.grey.shade100, Colors.grey.shade800),
                _chip('Cheque', '$currencySymbol${_fmt(row['cheque'])}', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                _chip('Online', '$currencySymbol${_fmt(row['online'])}', const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.reportType == 'daywise_outstanding') {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row['date'] ?? '',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF000080)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr('Unpaid Invoices: ${row['count'] ?? 0}'),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _chip('Outstanding Balance', '$currencySymbol${_fmt(row['outstanding'])}', const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox();
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
      case 'expense_head':
        items = [
          {
            'label': context.tr('Total Expense'),
            'value': '$currencySymbol${_fmt(d['total_expense'])}',
            'color': const Color(0xFFDC2626),
          },
          {
            'label': context.tr('Active Heads'),
            'value': '${d['rows'] != null ? (d['rows'] as List).length : 0}',
            'color': const Color(0xFF1E293B),
          },
        ];
        break;
      case 'leave':
        items = [
          {
            'label': context.tr('Total Leaves'),
            'value': '${d['total_leaves']}',
            'color': const Color(0xFF1E293B),
          },
          {
            'label': context.tr('Approved'),
            'value': '${d['approved_leaves']}',
            'color': const Color(0xFF059669),
          },
          {
            'label': context.tr('Pending'),
            'value': '${d['pending_leaves']}',
            'color': const Color(0xFFD97706),
          },
        ];
        break;
      case 'income':
        items = [
          {
            'label': context.tr('Total Quantity'),
            'value': '${d['total_count']}',
            'color': const Color(0xFF1E293B),
          },
          {
            'label': context.tr('Total Income'),
            'value': '$currencySymbol${_fmt(d['total_revenue'])}',
            'color': const Color(0xFF059669),
          },
        ];
        break;
      case 'daywise_income':
        items = [
          {
            'label': 'Jobs',
            'value': '${d['total_jobs']}',
            'color': const Color(0xFF2563EB),
          },
          {
            'label': 'Revenue',
            'value': '$currencySymbol${_fmt(d['total_income'])}',
            'color': const Color(0xFF059669),
          },
          {
            'label': 'Collected',
            'value': '$currencySymbol${_fmt(d['total_collected'])}',
            'color': const Color(0xFF7C3AED),
          },
        ];
        break;
      case 'daywise_profit':
        final profitVal = double.tryParse(d['total_profit']?.toString() ?? '0') ?? 0;
        items = [
          {
            'label': 'Income',
            'value': '$currencySymbol${_fmt(d['total_income'])}',
            'color': const Color(0xFF059669),
          },
          {
            'label': 'Expense',
            'value': '$currencySymbol${_fmt(d['total_expense'])}',
            'color': const Color(0xFFDC2626),
          },
          {
            'label': 'Net Profit',
            'value': '$currencySymbol${_fmt(d['total_profit'])}',
            'color': profitVal >= 0 ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
          },
        ];
        break;
      case 'daywise_collection':
        items = [
          {
            'label': 'Cash',
            'value': '$currencySymbol${_fmt(d['total_cash'])}',
            'color': const Color(0xFF1E293B),
          },
          {
            'label': 'Cheque',
            'value': '$currencySymbol${_fmt(d['total_cheque'])}',
            'color': const Color(0xFFD97706),
          },
          {
            'label': 'Online',
            'value': '$currencySymbol${_fmt(d['total_online'])}',
            'color': const Color(0xFF2563EB),
          },
          {
            'label': 'Total',
            'value': '$currencySymbol${_fmt(d['total_collected'])}',
            'color': const Color(0xFF059669),
          },
        ];
        break;
      case 'daywise_outstanding':
        items = [
          {
            'label': 'Invoices',
            'value': '${d['total_invoices']}',
            'color': const Color(0xFFDC2626),
          },
          {
            'label': 'Total Outstanding',
            'value': '$currencySymbol${_fmt(d['total_outstanding'])}',
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
              context.tr('Invoice: ${row['invoice_number']}'),
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
                  context.tr('${row['customer'] ?? ''} · ${row['phone'] ?? ''}'),
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
                  context.tr('${row['scheme']}'),
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

  Widget _buildExpenseHeadRow(Map<String, dynamic> row) {
    final name = row['expense_head_name'] ?? '';
    final amount = row['total_amount'] ?? '0.00';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.pie_chart_outline,
            color: Color(0xFFE11D48),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: const Color(0xFF1E293B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currencySymbol${_fmt(amount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: const Color(0xFFE11D48),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseHeadDetailScreen(
                expenseHeadId: row['expense_head_id'] as String,
                expenseHeadName: name,
                fromDate: _fromDate,
                toDate: _toDate,
                branchId: _selectedBranchId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncomeRow(Map<String, dynamic> row, int index) {
    final name = row['service_name'] ?? '';
    final amount = row['revenue'] ?? '0.00';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF059669),
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: const Color(0xFF1E293B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currencySymbol${_fmt(amount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncomeVehicleBreakdownScreen(
                serviceName: name,
                fromDate: _fromDate,
                toDate: _toDate,
                branchId: _selectedBranchId,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeaveRow(Map<String, dynamic> row) {
    final name = row['staff_name'] ?? '';
    final empId = row['employee_id'] ?? '';
    final branch = row['branch_name'] ?? '';
    final start = row['start_date'] ?? '';
    final end = row['end_date'] ?? '';
    final reason = row['reason'] ?? '';
    final remarks = row['remarks'] ?? '';
    final status = row['status'] ?? 'APPROVED';

    final statusColor = status == 'PENDING'
        ? Colors.orange
        : status == 'APPROVED'
            ? Colors.green
            : Colors.red;

    String formattedStart = '';
    String formattedEnd = '';
    try {
      if (start.isNotEmpty) formattedStart = DateFormat('dd-MM-yyyy').format(DateTime.parse(start));
      if (end.isNotEmpty) formattedEnd = DateFormat('dd-MM-yyyy').format(DateTime.parse(end));
    } catch (_) {
      formattedStart = start;
      formattedEnd = end;
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (branch.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    branch,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (empId.isNotEmpty)
                Text(
                  'ID: $empId',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                '$formattedStart to $formattedEnd',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${context.tr('Reason')}: $reason',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${context.tr('Remarks')}: $remarks',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Expense Head Detail Screen ────────────────────────────────────────────────
class ExpenseHeadDetailScreen extends StatefulWidget {
  final String expenseHeadId;
  final String expenseHeadName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? branchId;

  const ExpenseHeadDetailScreen({
    super.key,
    required this.expenseHeadId,
    required this.expenseHeadName,
    required this.fromDate,
    required this.toDate,
    this.branchId,
  });

  @override
  State<ExpenseHeadDetailScreen> createState() => _ExpenseHeadDetailScreenState();
}

class _ExpenseHeadDetailScreenState extends State<ExpenseHeadDetailScreen> {
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }

  String get _fromStr => DateFormat('dd-MM-yyyy').format(widget.fromDate);
  String get _toStr => DateFormat('dd-MM-yyyy').format(widget.toDate);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.getExpenseHeadDetailReport(
        token,
        widget.expenseHeadId,
        _fromStr,
        _toStr,
        branchId: widget.branchId,
      );
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

  Future<void> _downloadPdf() async {
    if (_data == null ||
        _data!['details'] == null ||
        (_data!['details'] as List).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('No data to generate PDF.'))));
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });
    try {
      final pdf = pw.Document();
      final details = _data!['details'] as List<dynamic>;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${widget.expenseHeadName} Details',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#000080'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Date Range: ${DateFormat('dd MMM yyyy').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 2),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['SL', 'Expense Name', 'Date', 'Remarks', 'Amount'],
                data: details.map((r) {
                  String rawDate = (r['date'] ?? '').toString();
                  String formattedDate = '';
                  if (rawDate.isNotEmpty) {
                    try {
                      final parsed = DateTime.parse(rawDate);
                      formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
                    } catch (_) {
                      formattedDate = rawDate;
                    }
                  }
                  return [
                    (r['sl_no'] ?? '').toString(),
                    (r['expense_name'] ?? '').toString(),
                    formattedDate,
                    (r['remarks'] ?? '').toString(),
                    _fmt(r['amount']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${widget.expenseHeadName.replaceAll(' ', '_')}_Detail_${_fromStr}_to_$_toStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Failed to generate PDF: $e'))));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final details = _data != null && _data!['details'] != null
        ? _data!['details'] as List<dynamic>
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.expenseHeadName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (details.isNotEmpty)
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
                    tooltip: context.tr('Download PDF'),
                    onPressed: _downloadPdf,
                  ),
        ],
      ),
      body: _isLoading
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
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                )
              : details.isEmpty
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
                            context.tr('No details for this head'),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.grey.shade200,
                            ),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(const Color(0xFF000080)),
                              headingTextStyle: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              dataTextStyle: GoogleFonts.inter(
                                color: const Color(0xFF1E293B),
                                fontSize: 12,
                              ),
                              columns: [
                                DataColumn(label: Text(context.tr('SL'))),
                                DataColumn(label: Text(context.tr('Expense Name'))),
                                DataColumn(label: Text(context.tr('Amount'))),
                                DataColumn(label: Text(context.tr('Date'))),
                                DataColumn(label: Text(context.tr('Remarks'))),
                              ],
                              rows: List<DataRow>.generate(details.length, (i) {
                                final row = details[i];
                                final slNo = row['sl_no'] ?? (i + 1);
                                final name = row['expense_name'] ?? '';
                                final amount = row['amount'] ?? '0.00';
                                final dateStr = row['date'] ?? '';
                                final remarks = row['remarks'] ?? '';

                                String formattedDate = '';
                                if (dateStr.isNotEmpty) {
                                  try {
                                    final parsed = DateTime.parse(dateStr);
                                    formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
                                  } catch (_) {
                                    formattedDate = dateStr;
                                  }
                                }

                                return DataRow(
                                  color: MaterialStateProperty.resolveWith<Color?>((states) {
                                    if (i.isEven) return Colors.grey.shade50;
                                    return Colors.white;
                                  }),
                                  cells: [
                                    DataCell(Text('#$slNo', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(name)),
                                    DataCell(Text(
                                      '$currencySymbol${_fmt(amount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626),
                                      ),
                                    )),
                                    DataCell(Text(formattedDate)),
                                    DataCell(Text(remarks.toString().isNotEmpty ? remarks.toString() : '-')),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class IncomeDetailScreen extends StatefulWidget {
  final String serviceName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? branchId;
  final String? vehicleTypeId;
  final String? vehicleTypeModelId;

  const IncomeDetailScreen({
    super.key,
    required this.serviceName,
    required this.fromDate,
    required this.toDate,
    this.branchId,
    this.vehicleTypeId,
    this.vehicleTypeModelId,
  });

  @override
  State<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends State<IncomeDetailScreen> {
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }

  String get _fromStr => DateFormat('dd-MM-yyyy').format(widget.fromDate);
  String get _toStr => DateFormat('dd-MM-yyyy').format(widget.toDate);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.getServiceTypeDetailReport(
        token,
        widget.serviceName,
        _fromStr,
        _toStr,
        branchId: widget.branchId,
        vehicleTypeId: widget.vehicleTypeId,
        vehicleTypeModelId: widget.vehicleTypeModelId,
      );
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

  Future<void> _downloadPdf() async {
    if (_data == null ||
        _data!['details'] == null ||
        (_data!['details'] as List).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('No data to generate PDF.'))));
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });
    try {
      final pdf = pw.Document();
      final details = _data!['details'] as List<dynamic>;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${widget.serviceName} Details',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#000080'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Date Range: ${DateFormat('dd MMM yyyy').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 2),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['SL', 'Date', 'Invoice No', 'Customer', 'Vehicle Type', 'Vehicle No', 'Amount'],
                data: details.map((r) {
                  String rawDate = (r['date'] ?? '').toString();
                  String formattedDate = '';
                  if (rawDate.isNotEmpty) {
                    try {
                      final parsed = DateTime.parse(rawDate);
                      formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
                    } catch (_) {
                      formattedDate = rawDate;
                    }
                  }
                  return [
                    (r['sl_no'] ?? '').toString(),
                    formattedDate,
                    (r['invoice_number'] ?? '').toString(),
                    '${r['customer_name'] ?? ''} (${r['customer_phone'] ?? ''})',
                    (r['vehicle_type'] ?? '').toString(),
                    (r['vehicle_number'] ?? '').toString(),
                    _fmt(r['amount']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerLeft,
                  6: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${widget.serviceName.replaceAll(' ', '_')}_Detail_${_fromStr}_to_$_toStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Failed to generate PDF: $e'))));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final details = _data != null && _data!['details'] != null
        ? _data!['details'] as List<dynamic>
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.serviceName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (details.isNotEmpty)
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
                    tooltip: context.tr('Download PDF'),
                    onPressed: _downloadPdf,
                  ),
        ],
      ),
      body: _isLoading
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
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                )
              : details.isEmpty
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
                            context.tr('No details for this service'),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: double.infinity,
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
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.grey.shade200,
                            ),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(const Color(0xFF000080)),
                              headingTextStyle: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              dataTextStyle: GoogleFonts.inter(
                                color: const Color(0xFF1E293B),
                                fontSize: 12,
                              ),
                              columns: [
                                DataColumn(label: Text(context.tr('SL'))),
                                DataColumn(label: Text(context.tr('Date'))),
                                DataColumn(label: Text(context.tr('Invoice No'))),
                                DataColumn(label: Text(context.tr('Customer'))),
                                DataColumn(label: Text(context.tr('Vehicle Type'))),
                                DataColumn(label: Text(context.tr('Vehicle No'))),
                                DataColumn(label: Text(context.tr('Amount'))),
                              ],
                              rows: List<DataRow>.generate(details.length, (i) {
                                final row = details[i];
                                final slNo = row['sl_no'] ?? (i + 1);
                                final amount = row['amount'] ?? '0.00';
                                final dateStr = row['date'] ?? '';
                                final invoiceNo = row['invoice_number'] ?? '';
                                final customerName = row['customer_name'] ?? '';
                                final customerPhone = row['customer_phone'] ?? '';
                                final vehicleType = row['vehicle_type'] ?? '';
                                final vehicleNo = row['vehicle_number'] ?? '';

                                String formattedDate = '';
                                if (dateStr.isNotEmpty) {
                                  try {
                                    final parsed = DateTime.parse(dateStr);
                                    formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
                                  } catch (_) {
                                    formattedDate = dateStr;
                                  }
                                }

                                return DataRow(
                                  color: MaterialStateProperty.resolveWith<Color?>((states) {
                                    if (i.isEven) return Colors.grey.shade50;
                                    return Colors.white;
                                  }),
                                  cells: [
                                    DataCell(Text('#$slNo', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(formattedDate)),
                                    DataCell(Text(invoiceNo)),
                                    DataCell(Text('$customerName ($customerPhone)')),
                                    DataCell(Text(vehicleType.toString().isNotEmpty ? vehicleType.toString() : '-')),
                                    DataCell(Text(vehicleNo.toString().isNotEmpty ? vehicleNo.toString() : '-')),
                                    DataCell(Text(
                                      '$currencySymbol${_fmt(amount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    )),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}


class IncomeVehicleBreakdownScreen extends StatefulWidget {
  final String serviceName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? branchId;

  const IncomeVehicleBreakdownScreen({
    super.key,
    required this.serviceName,
    required this.fromDate,
    required this.toDate,
    this.branchId,
  });

  @override
  State<IncomeVehicleBreakdownScreen> createState() => _IncomeVehicleBreakdownScreenState();
}

class _IncomeVehicleBreakdownScreenState extends State<IncomeVehicleBreakdownScreen> {
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
  }

  String get _fromStr => DateFormat('dd-MM-yyyy').format(widget.fromDate);
  String get _toStr => DateFormat('dd-MM-yyyy').format(widget.toDate);

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final res = await ApiService.getServiceTypeVehicleBreakdownReport(
        token,
        widget.serviceName,
        _fromStr,
        _toStr,
        branchId: widget.branchId,
      );
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

  Future<void> _downloadPdf() async {
    if (_data == null ||
        _data!['rows'] == null ||
        (_data!['rows'] as List).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('No data to generate PDF.'))));
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
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${widget.serviceName} - Vehicle Breakdown',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#000080'),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Date Range: ${DateFormat('dd MMM yyyy').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 2),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['SL', 'Vehicle Type / Model', 'Count', 'Amount'],
                data: rows.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    idx.toString(),
                    (r['display_name'] ?? '').toString(),
                    (r['count'] ?? '').toString(),
                    _fmt(r['revenue']),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${widget.serviceName.replaceAll(' ', '_')}_Breakdown_${_fromStr}_to_$_toStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Failed to generate PDF: $e'))));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final rows = _data != null && _data!['rows'] != null
        ? _data!['rows'] as List<dynamic>
        : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.serviceName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (rows.isNotEmpty)
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
                    tooltip: context.tr('Download PDF'),
                    onPressed: _downloadPdf,
                  ),
        ],
      ),
      body: _isLoading
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
                        child: Text(context.tr('Retry')),
                      ),
                    ],
                  ),
                )
              : rows.isEmpty
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
                            context.tr('No data for this service'),
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Summary bar
                          Container(
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        '${_data?['total_count'] ?? 0}',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        context.tr('Total Quantity'),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey.shade200),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        '$currencySymbol${_fmt(_data?['total_revenue'])}',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        context.tr('Total Income'),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table
                          Container(
                            width: double.infinity,
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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.grey.shade200,
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: MaterialStateProperty.all(const Color(0xFF000080)),
                                  headingTextStyle: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  dataTextStyle: GoogleFonts.inter(
                                    color: const Color(0xFF1E293B),
                                    fontSize: 12,
                                  ),
                                  columns: [
                                    DataColumn(label: Text(context.tr('SL'))),
                                    DataColumn(label: Text(context.tr('Vehicle Type / Model'))),
                                    DataColumn(label: Text(context.tr('Count'))),
                                    DataColumn(label: Text(context.tr('Amount'))),
                                  ],
                                  rows: List<DataRow>.generate(rows.length, (i) {
                                    final row = rows[i];
                                    final displayName = row['display_name'] ?? 'Other';
                                    final count = row['count'] ?? 0;
                                    final revenue = row['revenue'] ?? '0.00';

                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                                        if (i.isEven) return Colors.grey.shade50;
                                        return Colors.white;
                                      }),
                                      onSelectChanged: (_) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => IncomeDetailScreen(
                                              serviceName: widget.serviceName,
                                              fromDate: widget.fromDate,
                                              toDate: widget.toDate,
                                              branchId: widget.branchId,
                                              vehicleTypeId: row['vehicle_type_id'] != 'null' ? row['vehicle_type_id'] : 'null',
                                              vehicleTypeModelId: row['vehicle_type_model_id'] != 'null' ? row['vehicle_type_model_id'] : 'null',
                                            ),
                                          ),
                                        );
                                      },
                                      cells: [
                                        DataCell(Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(displayName.toString())),
                                        DataCell(Text(count.toString())),
                                        DataCell(Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$currencySymbol${_fmt(revenue)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 10,
                                              color: Colors.grey.shade400,
                                            ),
                                          ],
                                        )),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}


class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  DateTime _fromDate = DateTime.now();
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

  String get currencySymbol {
    try {
      return context.read<AuthProvider>().currencySymbol;
    } catch (_) {
      return '₹';
    }
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
      final res = await ApiService.getProfitLossReport(
        token,
        _fromStr,
        _toStr,
        branchId: _selectedBranchId,
      );
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
    } catch (_) {}
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
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _load();
    }
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

  Future<void> _downloadPdf() async {
    if (_data == null) return;
    setState(() {
      _isGeneratingPdf = true;
    });
    try {
      final pdf = pw.Document();
      final incomeRows = _data!['income_rows'] as List<dynamic>? ?? [];
      final expenseRows = _data!['expense_rows'] as List<dynamic>? ?? [];
      final double totalIncome = double.tryParse(_data!['total_income']?.toString() ?? '0') ?? 0;
      final double totalExpense = double.tryParse(_data!['total_expense']?.toString() ?? '0') ?? 0;
      final double netProfit = double.tryParse(_data!['net_profit']?.toString() ?? '0') ?? 0;
      final bool isProfit = netProfit >= 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Profit & Loss Report',
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
                    'Branch: $_selectedBranchName',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Income Table
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Income', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          headers: ['SL', 'Service', 'Amount'],
                          data: incomeRows.asMap().entries.map((entry) {
                            return [
                              (entry.key + 1).toString(),
                              entry.value['service_name'] ?? '',
                              _fmt(entry.value['amount']),
                            ];
                          }).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
                          cellHeight: 25,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  // Expense Table
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Expense', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.TableHelper.fromTextArray(
                          headers: ['SL', 'Expense Head', 'Amount'],
                          data: expenseRows.asMap().entries.map((entry) {
                            return [
                              (entry.key + 1).toString(),
                              entry.value['expense_head_name'] ?? '',
                              _fmt(entry.value['amount']),
                            ];
                          }).toList(),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#000080')),
                          cellHeight: 25,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Income: Rs. ${_fmt(totalIncome)}', style: const pw.TextStyle(fontSize: 13)),
                      pw.SizedBox(height: 4),
                      pw.Text('Total Expense: Rs. ${_fmt(totalExpense)}', style: const pw.TextStyle(fontSize: 13)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: isProfit ? PdfColor.fromHex('#ECFDF5') : PdfColor.fromHex('#FEF2F2'),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      '${isProfit ? "Profit" : "Loss"}: Rs. ${_fmt(netProfit.abs())}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: isProfit ? PdfColor.fromHex('#047857') : PdfColor.fromHex('#B91C1C'),
                      ),
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Profit_Report_${_fromStr}_to_$_toStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Failed to generate PDF: $e'))));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final incomeRows = _data != null && _data!['income_rows'] != null
        ? _data!['income_rows'] as List<dynamic>
        : [];
    final expenseRows = _data != null && _data!['expense_rows'] != null
        ? _data!['expense_rows'] as List<dynamic>
        : [];

    final double totalIncome = double.tryParse(_data?['total_income']?.toString() ?? '0') ?? 0;
    final double totalExpense = double.tryParse(_data?['total_expense']?.toString() ?? '0') ?? 0;
    final double netProfit = double.tryParse(_data?['net_profit']?.toString() ?? '0') ?? 0;
    final bool isProfit = netProfit >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Profit Report'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_data != null)
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
                    tooltip: context.tr('Download PDF'),
                    onPressed: _downloadPdf,
                  ),
        ],
      ),
      body: Column(
        children: [
          // Filter section (Date & branch selection)
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
                if (auth.isCompanyAdmin) ...[
                  const SizedBox(height: 12),
                  _branchDropdown(),
                ],
              ],
            ),
          ),

          // P&L Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 12),
                            Text(_error, style: GoogleFonts.inter(color: Colors.red.shade600)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: Text(context.tr('Retry'))),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side: Income
                                  Expanded(
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                context.tr('Income'),
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF000080)),
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Theme(
                                                data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                                                child: DataTable(
                                                  columnSpacing: 10,
                                                  horizontalMargin: 8,
                                                  showCheckboxColumn: false,
                                                  headingRowColor: MaterialStateProperty.all(const Color(0xFF000080)),
                                                  headingTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                  dataTextStyle: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 10),
                                                  columns: [
                                                    DataColumn(label: Text(context.tr('SL'))),
                                                    DataColumn(label: Text(context.tr('Service'))),
                                                    DataColumn(label: Text(context.tr('Amount'))),
                                                  ],
                                                  rows: List<DataRow>.generate(incomeRows.length, (i) {
                                                    final r = incomeRows[i];
                                                    return DataRow(
                                                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                                                        if (i.isEven) return Colors.grey.shade50;
                                                        return Colors.white;
                                                      }),
                                                      cells: [
                                                        DataCell(Text('${i + 1}')),
                                                        DataCell(Text(r['service_name'] ?? '')),
                                                        DataCell(Text('$currencySymbol${_fmt(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right side: Expense
                                  Expanded(
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                context.tr('Expense'),
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFDC2626)),
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Theme(
                                                data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                                                child: DataTable(
                                                  columnSpacing: 10,
                                                  horizontalMargin: 8,
                                                  showCheckboxColumn: false,
                                                  headingRowColor: MaterialStateProperty.all(const Color(0xFFDC2626)),
                                                  headingTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                  dataTextStyle: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 10),
                                                  columns: [
                                                    DataColumn(label: Text(context.tr('SL'))),
                                                    DataColumn(label: Text(context.tr('Expense'))),
                                                    DataColumn(label: Text(context.tr('Amount'))),
                                                  ],
                                                  rows: List<DataRow>.generate(expenseRows.length, (i) {
                                                    final r = expenseRows[i];
                                                    return DataRow(
                                                      color: MaterialStateProperty.resolveWith<Color?>((states) {
                                                        if (i.isEven) return Colors.grey.shade50;
                                                        return Colors.white;
                                                      }),
                                                      cells: [
                                                        DataCell(Text('${i + 1}')),
                                                        DataCell(Text(r['expense_head_name'] ?? '')),
                                                        DataCell(Text('$currencySymbol${_fmt(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)))),
                                                      ],
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Profit / Loss card
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: SafeArea(
                              top: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: isProfit ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isProfit ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(context.tr('Total Income'), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                                        Text('$currencySymbol${_fmt(totalIncome)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(context.tr('Total Expense'), style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                                        Text('$currencySymbol${_fmt(totalExpense)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isProfit ? context.tr('Net Profit') : context.tr('Net Loss'),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isProfit ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                          ),
                                        ),
                                        Text(
                                          '$currencySymbol${_fmt(netProfit.abs())}',
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isProfit ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      isExpanded: true,
      menuMaxHeight: 350,
      decoration: InputDecoration(
        labelText: context.tr('Branch'),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF000080).withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF000080).withOpacity(0.2)),
        ),
      ),
      items: [
        DropdownMenuItem<String>(value: '', child: Text(context.tr('All branches'))),
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
            Icon(Icons.calendar_today_outlined, size: 15, color: const Color(0xFF000080).withOpacity(0.7)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                Text(
                  DateFormat('dd MMM yy').format(date),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


