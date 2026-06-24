import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';

class BookingSettingsScreen extends StatefulWidget {
  const BookingSettingsScreen({super.key});

  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _branches = [];
  String? _selectedBranchId;

  // General Settings State
  bool _isBookingEnabled = true;
  final _maxBookingController = TextEditingController();
  final _welcomeMessageController = TextEditingController();
  TimeOfDay? _closingTime;

  // Weekly Off State
  final List<String> _allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  List<dynamic> _weeklyOffs = []; // list of {id, day}

  // Holidays State
  List<dynamic> _holidays = []; // list of {id, holiday_date, repeat_yearly}

  // Pauses State
  List<dynamic> _pauses = []; // list of {id, from_date, to_date, reason}

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchTabData();
      }
    });
    _fetchInitialBranches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _maxBookingController.dispose();
    _welcomeMessageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialBranches() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.getCompanyBranches(token);
      if (res['success'] == true) {
        final branches = res['branches'] ?? [];
        setState(() {
          _branches = branches;
          if (branches.isNotEmpty) {
            _selectedBranchId = branches.first['id']?.toString();
          }
        });
        await _fetchAllData();
      } else {
        throw Exception(res['message'] ?? 'Failed to load branches');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllData() async {
    if (_selectedBranchId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await Future.wait([
        _fetchGeneralSettings(),
        _fetchWeeklyOffData(),
        _fetchHolidayData(),
        _fetchPauseData(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTabData() async {
    if (_selectedBranchId == null) return;
    setState(() => _isLoading = true);
    try {
      switch (_tabController.index) {
        case 0:
          await _fetchGeneralSettings();
          break;
        case 1:
          await _fetchWeeklyOffData();
          break;
        case 2:
          await _fetchHolidayData();
          break;
        case 3:
          await _fetchPauseData();
          break;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGeneralSettings() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getBookingSettings(auth.token!, branchId: _selectedBranchId);
    if (res['success'] == true) {
      final bs = res['booking_settings'] ?? {};
      _isBookingEnabled = bs['is_booking_enabled'] ?? true;
      _maxBookingController.text = (bs['max_booking_per_day'] ?? 50).toString();
      _welcomeMessageController.text = bs['whatsapp_welcome_message']?.toString() ?? '';
      final closingTimeStr = bs['booking_closing_time']?.toString() ?? '';
      if (closingTimeStr.isNotEmpty) {
        final parts = closingTimeStr.split(':');
        if (parts.length >= 2) {
          _closingTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      } else {
        _closingTime = null;
      }
    }
  }

  Future<void> _fetchWeeklyOffData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getWeeklyOffs(auth.token!, branchId: _selectedBranchId);
    if (res['success'] == true) {
      _weeklyOffs = res['weekly_offs'] ?? [];
    }
  }

  Future<void> _fetchHolidayData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getHolidays(auth.token!, branchId: _selectedBranchId);
    if (res['success'] == true) {
      _holidays = res['holidays'] ?? [];
    }
  }

  Future<void> _fetchPauseData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getBookingPauses(auth.token!, branchId: _selectedBranchId);
    if (res['success'] == true) {
      _pauses = res['pauses'] ?? [];
    }
  }

  // --- SAVE GENERAL SETTINGS ---
  Future<void> _saveGeneralSettings() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId == null) return;

    final maxVal = int.tryParse(_maxBookingController.text.trim());
    if (maxVal == null || maxVal < 0) {
      _showSnackBar(context.tr('Please enter a valid maximum bookings count'), Colors.orange);
      return;
    }

    String? closingTimeStr;
    if (_closingTime != null) {
      final hh = _closingTime!.hour.toString().padLeft(2, '0');
      final mm = _closingTime!.minute.toString().padLeft(2, '0');
      closingTimeStr = '$hh:$mm:00';
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.updateBookingSettings(token, {
        'branch_id': _selectedBranchId,
        'is_booking_enabled': _isBookingEnabled,
        'max_booking_per_day': maxVal,
        'booking_closing_time': closingTimeStr,
        'whatsapp_welcome_message': _welcomeMessageController.text.trim(),
      });
      if (res['success'] == true) {
        _showSnackBar(context.tr('Settings updated successfully'), Colors.green);
        await _fetchGeneralSettings();
      } else {
        throw Exception(res['message'] ?? 'Failed to save settings');
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- TOGGLE WEEKLY OFF ---
  Future<void> _toggleWeeklyOff(String day, bool enableOff) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId == null) return;

    setState(() => _isLoading = true);
    try {
      if (enableOff) {
        final res = await ApiService.createWeeklyOff(token, {
          'branch_id': _selectedBranchId,
          'day': day,
        });
        if (res['success'] == true) {
          _showSnackBar(context.tr('Weekly Off day added'), Colors.green);
        } else {
          throw Exception(res['message'] ?? 'Failed to add Weekly Off');
        }
      } else {
        final match = _weeklyOffs.firstWhere((w) => w['day'] == day, orElse: () => null);
        if (match != null) {
          final res = await ApiService.deleteWeeklyOff(token, match['id'].toString());
          if (res['success'] == true) {
            _showSnackBar(context.tr('Weekly Off day removed'), Colors.green);
          } else {
            throw Exception(res['message'] ?? 'Failed to remove Weekly Off');
          }
        }
      }
      await _fetchWeeklyOffData();
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ADD HOLIDAY ---
  Future<void> _addHoliday() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId == null) return;

    DateTime? selectedDate = DateTime.now();
    bool repeatYearly = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Add Holiday'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      selectedDate != null
                          ? DateFormat('dd-MM-yyyy').format(selectedDate!)
                          : context.tr('Select Date'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: Text(
                      context.tr('Repeat Yearly'),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    value: repeatYearly,
                    onChanged: (val) {
                      setStateDialog(() => repeatYearly = val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: selectedDate == null ? null : () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(context.tr('Add'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && selectedDate != null) {
      setState(() => _isLoading = true);
      try {
        final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
        final res = await ApiService.createHoliday(token, {
          'branch_id': _selectedBranchId,
          'holiday_date': formattedDate,
          'repeat_yearly': repeatYearly,
        });
        if (res['success'] == true) {
          _showSnackBar(context.tr('Holiday added successfully'), Colors.green);
          await _fetchHolidayData();
        } else {
          throw Exception(res['message'] ?? 'Failed to add holiday');
        }
      } catch (e) {
        _showSnackBar(e.toString(), Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- DELETE HOLIDAY ---
  Future<void> _deleteHoliday(String id) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Holiday'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(context.tr('Are you sure you want to delete this holiday?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(context.tr('Delete'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final res = await ApiService.deleteHoliday(token, id);
        if (res['success'] == true) {
          _showSnackBar(context.tr('Holiday deleted successfully'), Colors.green);
          await _fetchHolidayData();
        } else {
          throw Exception(res['message'] ?? 'Failed to delete holiday');
        }
      } catch (e) {
        _showSnackBar(e.toString(), Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- ADD PAUSE ---
  Future<void> _addBookingPause() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId == null) return;

    DateTime? fromDate = DateTime.now();
    DateTime? toDate = DateTime.now();
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('Pause Bookings'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF000080)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.tr('From Date *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            fromDate = picked;
                            if (toDate != null && toDate!.isBefore(fromDate!)) {
                              toDate = fromDate;
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        fromDate != null
                            ? DateFormat('dd-MM-yyyy').format(fromDate!)
                            : context.tr('Select Start Date'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(context.tr('To Date *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: toDate ?? (fromDate ?? DateTime.now()),
                          firstDate: fromDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          setStateDialog(() => toDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        toDate != null
                            ? DateFormat('dd-MM-yyyy').format(toDate!)
                            : context.tr('Select End Date'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(context.tr('Reason'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: context.tr('Reason for pause'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: fromDate == null || toDate == null ? null : () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(context.tr('Pause'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && fromDate != null && toDate != null) {
      setState(() => _isLoading = true);
      try {
        final formattedFrom = DateFormat('yyyy-MM-dd').format(fromDate!);
        final formattedTo = DateFormat('yyyy-MM-dd').format(toDate!);
        final res = await ApiService.createBookingPause(token, {
          'branch_id': _selectedBranchId,
          'from_date': formattedFrom,
          'to_date': formattedTo,
          'reason': reasonCtrl.text.trim(),
        });
        if (res['success'] == true) {
          _showSnackBar(context.tr('Booking pause scheduled successfully'), Colors.green);
          await _fetchPauseData();
        } else {
          throw Exception(res['message'] ?? 'Failed to create booking pause');
        }
      } catch (e) {
        _showSnackBar(e.toString(), Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- DELETE PAUSE ---
  Future<void> _deleteBookingPause(String id) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete Booking Pause'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(context.tr('Are you sure you want to delete this pause?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(context.tr('Delete'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final res = await ApiService.deleteBookingPause(token, id);
        if (res['success'] == true) {
          _showSnackBar(context.tr('Booking pause deleted successfully'), Colors.green);
          await _fetchPauseData();
        } else {
          throw Exception(res['message'] ?? 'Failed to delete booking pause');
        }
      } catch (e) {
        _showSnackBar(e.toString(), Colors.red);
      } finally {
        setState(() => _isLoading = false);
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
    final isCompanyAdmin = auth.isCompanyAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Booking Settings'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF000080),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: context.tr('General')),
            Tab(text: context.tr('Off Days')),
            Tab(text: context.tr('Holidays')),
            Tab(text: context.tr('Pause')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Branch selector for Company Admin
          if (isCompanyAdmin && _branches.isNotEmpty) _buildBranchDropdown(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF000080)))
                : _errorMessage.isNotEmpty
                    ? _buildErrorWidget()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGeneralTab(),
                          _buildWeeklyOffsTab(),
                          _buildHolidaysTab(),
                          _buildPausesTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Select Branch to Manage Settings'),
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBranchId,
                items: _branches.map((b) {
                  return DropdownMenuItem<String>(
                    value: b['id']?.toString(),
                    child: Text(b['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBranchId = val;
                  });
                  _fetchAllData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAllData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000080), foregroundColor: Colors.white),
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. GENERAL SETTINGS TAB ---
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(
                context.tr('Enable Booking Service'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                context.tr(''),
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
              value: _isBookingEnabled,
              onChanged: (val) => setState(() => _isBookingEnabled = val),
              activeColor: const Color(0xFF000080),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),
            Text(
              context.tr('Max Bookings Per Day'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _maxBookingController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.numbers, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Booking Closing Time'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _closingTime ?? const TimeOfDay(hour: 18, minute: 0),
                );
                if (picked != null) {
                  setState(() => _closingTime = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _closingTime != null
                          ? _closingTime!.format(context)
                          : context.tr('No Closing Time (No Limit)'),
                      style: GoogleFonts.inter(fontSize: 15, color: _closingTime != null ? Colors.black87 : Colors.grey),
                    ),
                    const Spacer(),
                    if (_closingTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                        onPressed: () => setState(() => _closingTime = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('WhatsApp Welcome Message'),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _welcomeMessageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.tr('Enter welcome message template...'),
                helperText: context.tr('Placeholders: {customer_name}, {branch_name}, {company_name}'),
                helperMaxLines: 2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveGeneralSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000080),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                context.tr('Save Settings'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. WEEKLY OFF TAB ---
  Widget _buildWeeklyOffsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allDays.length,
      itemBuilder: (context, index) {
        final day = _allDays[index];
        final isOff = _weeklyOffs.any((w) => w['day'] == day);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 10),
          child: CheckboxListTile(
            title: Text(
              context.tr(day[0].toUpperCase() + day.substring(1)),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            value: isOff,
            activeColor: const Color(0xFF000080),
            onChanged: (val) {
              _toggleWeeklyOff(day, val ?? false);
            },
          ),
        );
      },
    );
  }

  // --- 3. HOLIDAYS TAB ---
  Widget _buildHolidaysTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addHoliday,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Add Custom Holiday')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: _holidays.isEmpty
              ? Center(
                  child: Text(
                    context.tr('No custom holidays added yet.'),
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _holidays.length,
                  itemBuilder: (context, index) {
                    final h = _holidays[index];
                    final dateStr = h['holiday_date']?.toString() ?? '';
                    final repeat = h['repeat_yearly'] == true;
                    DateTime? parsedDate;
                    if (dateStr.isNotEmpty) {
                      parsedDate = DateTime.tryParse(dateStr);
                    }
                    final displayDate = parsedDate != null ? DateFormat('dd-MM-yyyy').format(parsedDate) : dateStr;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0E0FF),
                          child: Icon(Icons.beach_access, color: Color(0xFF000080), size: 20),
                        ),
                        title: Text(displayDate, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        subtitle: Text(repeat ? context.tr('Repeats Yearly') : context.tr('One-time Holiday')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteHoliday(h['id'].toString()),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- 4. PAUSES TAB ---
  Widget _buildPausesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addBookingPause,
            icon: const Icon(Icons.add),
            label: Text(context.tr('Pause Booking Schedule')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000080),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: _pauses.isEmpty
              ? Center(
                  child: Text(
                    context.tr('No booking pauses scheduled yet.'),
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pauses.length,
                  itemBuilder: (context, index) {
                    final p = _pauses[index];
                    final fromStr = p['from_date']?.toString() ?? '';
                    final toStr = p['to_date']?.toString() ?? '';
                    final reason = p['reason']?.toString() ?? '';

                    DateTime? fromD = fromStr.isNotEmpty ? DateTime.tryParse(fromStr) : null;
                    DateTime? toD = toStr.isNotEmpty ? DateTime.tryParse(toStr) : null;

                    final displayFrom = fromD != null ? DateFormat('dd-MM-yyyy').format(fromD) : fromStr;
                    final displayTo = toD != null ? DateFormat('dd-MM-yyyy').format(toD) : toStr;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEBEE),
                          child: Icon(Icons.pause_circle_outline, color: Colors.red, size: 20),
                        ),
                        title: Text('$displayFrom ${context.tr('to')} $displayTo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          reason.isNotEmpty ? reason : context.tr('No reason provided'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteBookingPause(p['id'].toString()),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
