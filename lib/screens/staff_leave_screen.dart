import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class StaffLeaveScreen extends StatefulWidget {
  const StaffLeaveScreen({super.key});

  @override
  State<StaffLeaveScreen> createState() => _StaffLeaveScreenState();
}

class _StaffLeaveScreenState extends State<StaffLeaveScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _leaves = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaves();
  }

  Future<void> _fetchLeaves() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.getStaffLeaves(token);
      if (res['success'] == true) {
        setState(() {
          _leaves = res['leaves'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load leaves';
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

  void _navigateToAddLeave() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddLeaveScreen()),
    );
    if (result == true) {
      _fetchLeaves();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Staff Leaves'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchLeaves,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchLeaves,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000080),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(context.tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : _leaves.isEmpty
                  ? Center(
                      child: Text(
                        context.tr('No staff leaves recorded'),
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchLeaves,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _leaves.length,
                        itemBuilder: (ctx, i) {
                          final leave = Map<String, dynamic>.from(_leaves[i] as Map);
                          final staffName = leave['staff_name'] ?? '';
                          final empId = leave['employee_id'] ?? '';
                          final branchName = leave['branch_name'] ?? '';
                          final reason = leave['reason'] ?? '';
                          final remarks = leave['remarks'] ?? '';
                          final status = leave['status'] ?? 'APPROVED';

                          // Format Dates
                          String dateRange = '';
                          try {
                            final startDt = DateTime.parse(leave['start_date']);
                            final endDt = DateTime.parse(leave['end_date']);
                            final startFmt = DateFormat('dd MMM yyyy').format(startDt);
                            final endFmt = DateFormat('dd MMM yyyy').format(endDt);
                            if (startFmt == endFmt) {
                              dateRange = startFmt;
                            } else {
                              dateRange = '$startFmt - $endFmt';
                            }
                          } catch (_) {
                            dateRange = '${leave['start_date']} - ${leave['end_date']}';
                          }

                          // Status Styling
                          Color statusColor = Colors.green;
                          Color statusBg = const Color(0xFFE8F5E9);
                          if (status == 'PENDING') {
                            statusColor = Colors.orange;
                            statusBg = const Color(0xFFFFF3E0);
                          } else if (status == 'REJECTED') {
                            statusColor = Colors.red;
                            statusBg = const Color(0xFFFFEBEE);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              staffName,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$empId • $branchName',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          context.tr(status),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dateRange,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (reason.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            reason,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (remarks.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.notes, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            remarks,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddLeave,
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddLeaveScreen extends StatefulWidget {
  const AddLeaveScreen({super.key});

  @override
  State<AddLeaveScreen> createState() => _AddLeaveScreenState();
}

class _AddLeaveScreenState extends State<AddLeaveScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  List<dynamic> _staffs = [];

  // Form fields
  Map<String, dynamic>? _selectedStaff;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _status = 'APPROVED';

  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStaffs();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _fetchStaffs() async {
    final auth = context.read<AuthProvider>();
    final isStaff = auth.role != 'COMPANY_ADMIN' && auth.role != 'BRANCH_ADMIN';
    if (isStaff) {
      setState(() {
        _status = 'PENDING';
        _isLoading = false;
      });
      return;
    }

    final token = auth.token;
    if (token == null) return;

    try {
      final res = await ApiService.getStaffList(token);
      if (res['success'] == true) {
        setState(() {
          _staffs = res['staffs'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load staff list';
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

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF000080),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showStaffSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _StaffSelectorBottomSheet(
          staffs: _staffs,
          onSelected: (staff) {
            setState(() {
              _selectedStaff = staff;
            });
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final isStaff = auth.role != 'COMPANY_ADMIN' && auth.role != 'BRANCH_ADMIN';
    final token = auth.token;
    if (token == null) return;

    if (!isStaff && _selectedStaff == null) {
      _showSnackBar(context.tr('Please select a staff member'), Colors.orange);
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      _showSnackBar(context.tr('End date cannot be before start date'), Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        if (!isStaff) 'staff_id': _selectedStaff!['id'],
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'reason': _reasonController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'status': _status,
      };

      final res = await ApiService.createStaffLeave(token, payload);
      if (res['success'] == true) {
        if (mounted) {
          _showSnackBar(context.tr('Leave recorded successfully!'), Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showSnackBar(res['message'] ?? context.tr('Failed to record leave'), Colors.red);
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), Colors.red);
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isStaff = auth.role != 'COMPANY_ADMIN' && auth.role != 'BRANCH_ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Record Leave'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchStaffs,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
                          child: Text(context.tr('Retry')),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, color: Color(0xFF000080), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('Leave Details'),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: const Color(0xFF000080),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Staff selector
                            if (!isStaff) ...[
                              _buildLabel(context.tr('Staff Member *')),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _showStaffSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, size: 20, color: Colors.grey.shade500),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _selectedStaff != null
                                              ? '${_selectedStaff!['name']} (${_selectedStaff!['employee_id']})'
                                              : context.tr('Select Staff Member'),
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            color: _selectedStaff != null
                                                ? Colors.black87
                                                : Colors.grey.shade500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Start Date
                            _buildLabel(context.tr('Start Date *')),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _pickDate(isStart: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade500),
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat('dd-MM-yyyy').format(_startDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // End Date
                            _buildLabel(context.tr('End Date *')),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _pickDate(isStart: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade500),
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat('dd-MM-yyyy').format(_endDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Reason
                            _buildTextField(
                              _reasonController,
                              context.tr('Reason'),
                              Icons.edit_note,
                            ),
                            const SizedBox(height: 14),

                            // Remarks
                            _buildTextField(
                              _remarksController,
                              context.tr('Remarks'),
                              Icons.comment_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),

                            // Status Dropdown
                            if (!isStaff) ...[
                              _buildLabel(context.tr('Status *')),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _status,
                                    items: [
                                      DropdownMenuItem(
                                        value: 'APPROVED',
                                        child: Text(context.tr('Approved')),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PENDING',
                                        child: Text(context.tr('Pending')),
                                      ),
                                      DropdownMenuItem(
                                        value: 'REJECTED',
                                        child: Text(context.tr('Rejected')),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _status = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                context.tr('Record Leave'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade500),
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
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _StaffSelectorBottomSheet extends StatefulWidget {
  final List<dynamic> staffs;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _StaffSelectorBottomSheet({
    required this.staffs,
    required this.onSelected,
  });

  @override
  State<_StaffSelectorBottomSheet> createState() => _StaffSelectorBottomSheetState();
}

class _StaffSelectorBottomSheetState extends State<_StaffSelectorBottomSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _filteredStaffs = [];

  @override
  void initState() {
    super.initState();
    _filteredStaffs = List.from(widget.staffs);
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStaffs = List.from(widget.staffs);
      } else {
        _filteredStaffs = widget.staffs.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final empId = (s['employee_id'] ?? '').toString().toLowerCase();
          return name.contains(query) || empId.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Select Staff Member'),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF000080),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              )
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search staff members...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredStaffs.isEmpty
                ? Center(
                    child: Text(
                      context.tr('No staff members found'),
                      style: GoogleFonts.inter(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStaffs.length,
                    itemBuilder: (context, index) {
                      final staff = Map<String, dynamic>.from(_filteredStaffs[index] as Map);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF000080).withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: Color(0xFF000080)),
                        ),
                        title: Text(
                          staff['name'] ?? '',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${staff['employee_id'] ?? ''} • ${staff['branch_name'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          widget.onSelected(staff);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
