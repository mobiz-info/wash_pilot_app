import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final _isLoading = ValueNotifier<bool>(true);
  final _errorMessage = ValueNotifier<String>('');

  final _branches = ValueNotifier<List<dynamic>>([]);
  final _selectedBranchId = ValueNotifier<String?>(null);

  // General Settings State
  final _isBookingEnabled = ValueNotifier<bool>(true);
  final _maxBookingController = TextEditingController();
  final _welcomeMessageController = TextEditingController();
  final _closingTime = ValueNotifier<TimeOfDay?>(null);

  // Weekly Off State
  final List<String> _allDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final _weeklyOffs = ValueNotifier<List<dynamic>>([]); // list of {id, day}

  // Holidays State
  final _holidays = ValueNotifier<List<dynamic>>([]); // list of {id, holiday_date, repeat_yearly}

  // Pauses State
  final _pauses = ValueNotifier<List<dynamic>>([]); // list of {id, from_date, to_date, reason}

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
    _isLoading.dispose();
    _errorMessage.dispose();
    _branches.dispose();
    _selectedBranchId.dispose();
    _isBookingEnabled.dispose();
    _closingTime.dispose();
    _weeklyOffs.dispose();
    _holidays.dispose();
    _pauses.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialBranches() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      final res = await ApiService.getCompanyBranches(token);
      if (res['success'] == true) {
        final branchesList = res['branches'] ?? [];
        _branches.value = List<dynamic>.from(branchesList);
        if (branchesList.isNotEmpty) {
          _selectedBranchId.value = branchesList.first['id']?.toString();
        }
        await _fetchAllData();
      } else {
        throw Exception(res['message'] ?? 'Failed to load branches');
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  Future<void> _fetchAllData() async {
    if (_selectedBranchId.value == null) {
      _isLoading.value = false;
      return;
    }
    _isLoading.value = true;
    _errorMessage.value = '';
    try {
      await Future.wait([
        _fetchGeneralSettings(),
        _fetchWeeklyOffData(),
        _fetchHolidayData(),
        _fetchPauseData(),
      ]);
      _isLoading.value = false;
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  Future<void> _fetchTabData() async {
    if (_selectedBranchId.value == null) return;
    _isLoading.value = true;
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
      _isLoading.value = false;
    } catch (e) {
      _errorMessage.value = e.toString();
      _isLoading.value = false;
    }
  }

  Future<void> _fetchGeneralSettings() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getBookingSettings(auth.token!, branchId: _selectedBranchId.value);
    if (res['success'] == true) {
      final bs = res['booking_settings'] ?? {};
      _isBookingEnabled.value = bs['is_booking_enabled'] ?? true;
      _maxBookingController.text = (bs['max_booking_per_day'] ?? 50).toString();
      _welcomeMessageController.text = bs['whatsapp_welcome_message']?.toString() ?? '';
      final closingTimeStr = bs['booking_closing_time']?.toString() ?? '';
      if (closingTimeStr.isNotEmpty) {
        final parts = closingTimeStr.split(':');
        if (parts.length >= 2) {
          _closingTime.value = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      } else {
        _closingTime.value = null;
      }
    }
  }

  Future<void> _fetchWeeklyOffData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getWeeklyOffs(auth.token!, branchId: _selectedBranchId.value);
    if (res['success'] == true) {
      _weeklyOffs.value = List<dynamic>.from(res['weekly_offs'] ?? []);
    }
  }

  Future<void> _fetchHolidayData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getHolidays(auth.token!, branchId: _selectedBranchId.value);
    if (res['success'] == true) {
      _holidays.value = List<dynamic>.from(res['holidays'] ?? []);
    }
  }

  Future<void> _fetchPauseData() async {
    final auth = context.read<AuthProvider>();
    final res = await ApiService.getBookingPauses(auth.token!, branchId: _selectedBranchId.value);
    if (res['success'] == true) {
      _pauses.value = List<dynamic>.from(res['pauses'] ?? []);
    }
  }

  // --- SAVE GENERAL SETTINGS ---
  Future<void> _saveGeneralSettings() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId.value == null) return;

    final maxVal = int.tryParse(_maxBookingController.text.trim());
    if (maxVal == null || maxVal < 0) {
      _showSnackBar(context.tr('Please enter a valid maximum bookings count'), Colors.orange);
      return;
    }

    String? closingTimeStr;
    if (_closingTime.value != null) {
      final hh = _closingTime.value!.hour.toString().padLeft(2, '0');
      final mm = _closingTime.value!.minute.toString().padLeft(2, '0');
      closingTimeStr = '$hh:$mm:00';
    }

    _isLoading.value = true;
    try {
      final res = await ApiService.updateBookingSettings(token, {
        'branch_id': _selectedBranchId.value,
        'is_booking_enabled': _isBookingEnabled.value,
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
      _isLoading.value = false;
    }
  }

  // --- TOGGLE WEEKLY OFF ---
  Future<void> _toggleWeeklyOff(String day, bool enableOff) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId.value == null) return;

    _isLoading.value = true;
    try {
      if (enableOff) {
        final res = await ApiService.createWeeklyOff(token, {
          'branch_id': _selectedBranchId.value,
          'day': day,
        });
        if (res['success'] == true) {
          _showSnackBar(context.tr('Weekly Off day added'), Colors.green);
        } else {
          throw Exception(res['message'] ?? 'Failed to add Weekly Off');
        }
      } else {
        final match = _weeklyOffs.value.firstWhere((w) => w['day'] == day, orElse: () => null);
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
      _isLoading.value = false;
    }
  }

  // --- ADD HOLIDAY ---
  Future<void> _addHoliday() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId.value == null) return;

    final selectedDateNotifier = ValueNotifier<DateTime?>(DateTime.now());
    final repeatYearlyNotifier = ValueNotifier<bool>(false);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
              ValueListenableBuilder<DateTime?>(
                valueListenable: selectedDateNotifier,
                builder: (context, selectedDate, _) {
                  return ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        selectedDateNotifier.value = picked;
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      selectedDate != null
                          ? DateFormat('dd-MM-yyyy').format(selectedDate)
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
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: repeatYearlyNotifier,
                builder: (context, repeatYearly, _) {
                  return CheckboxListTile(
                    title: Text(
                      context.tr('Repeat Yearly'),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    value: repeatYearly,
                    onChanged: (val) {
                      repeatYearlyNotifier.value = val ?? false;
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ValueListenableBuilder<DateTime?>(
              valueListenable: selectedDateNotifier,
              builder: (context, selectedDate, _) {
                return ElevatedButton(
                  onPressed: selectedDate == null ? null : () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(context.tr('Add')),
                );
              },
            ),
          ],
        );
      },
    );

    final selectedDate = selectedDateNotifier.value;
    final repeatYearly = repeatYearlyNotifier.value;
    selectedDateNotifier.dispose();
    repeatYearlyNotifier.dispose();

    if (result == true && selectedDate != null) {
      _isLoading.value = true;
      try {
        final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        final res = await ApiService.createHoliday(token, {
          'branch_id': _selectedBranchId.value,
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
        _isLoading.value = false;
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
      _isLoading.value = true;
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
        _isLoading.value = false;
      }
    }
  }

  // --- ADD PAUSE ---
  Future<void> _addPausePeriod() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || _selectedBranchId.value == null) return;

    final fromDateNotifier = ValueNotifier<DateTime?>(DateTime.now());
    final toDateNotifier = ValueNotifier<DateTime?>(DateTime.now());
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
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
                ValueListenableBuilder<DateTime?>(
                  valueListenable: fromDateNotifier,
                  builder: (context, fromDate, _) {
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          fromDateNotifier.value = picked;
                          if (toDateNotifier.value != null && toDateNotifier.value!.isBefore(picked)) {
                            toDateNotifier.value = picked;
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        fromDate != null
                            ? DateFormat('dd-MM-yyyy').format(fromDate)
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
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(context.tr('To Date *'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: toDateNotifier,
                  builder: (context, toDate, _) {
                    return ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: toDate ?? (fromDateNotifier.value ?? DateTime.now()),
                          firstDate: fromDateNotifier.value ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) {
                          toDateNotifier.value = picked;
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        toDate != null
                            ? DateFormat('dd-MM-yyyy').format(toDate)
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
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(context.tr('Reason (Optional)'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    hintText: context.tr('e.g. Maintenance, Renovation'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            ValueListenableBuilder<DateTime?>(
              valueListenable: fromDateNotifier,
              builder: (context, fromDate, _) => ValueListenableBuilder<DateTime?>(
                valueListenable: toDateNotifier,
                builder: (context, toDate, _) {
                  return ElevatedButton(
                    onPressed: (fromDate == null || toDate == null)
                        ? null
                        : () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000080),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(context.tr('Add Pause')),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    final fromDate = fromDateNotifier.value;
    final toDate = toDateNotifier.value;
    fromDateNotifier.dispose();
    toDateNotifier.dispose();

    if (result == true && fromDate != null && toDate != null) {
      _isLoading.value = true;
      try {
        final formattedFrom = DateFormat('yyyy-MM-dd').format(fromDate!);
        final formattedTo = DateFormat('yyyy-MM-dd').format(toDate!);
        final res = await ApiService.createBookingPause(token, {
          'branch_id': _selectedBranchId.value,
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
        _isLoading.value = false;
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
      _isLoading.value = true;
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
        _isLoading.value = false;
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
          if (isCompanyAdmin)
            ValueListenableBuilder<List<dynamic>>(
              valueListenable: _branches,
              builder: (context, branchList, _) {
                if (branchList.isEmpty) return const SizedBox.shrink();
                return _buildBranchDropdown(branchList);
              },
            ),

          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, loading, _) => ValueListenableBuilder<String>(
                valueListenable: _errorMessage,
                builder: (context, err, _) {
                  if (loading) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF000080)));
                  }
                  if (err.isNotEmpty) {
                    return _buildErrorWidget(err);
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGeneralTab(),
                      _buildWeeklyOffsTab(),
                      _buildHolidaysTab(),
                      _buildPausesTab(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown(List<dynamic> branchList) {
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
              child: ValueListenableBuilder<String?>(
                valueListenable: _selectedBranchId,
                builder: (context, selectedId, _) => DropdownButton<String>(
                  isExpanded: true,
                  value: selectedId,
                  items: branchList.map((b) {
                    return DropdownMenuItem<String>(
                      value: b['id']?.toString(),
                      child: Text(b['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    _selectedBranchId.value = val;
                    _fetchAllData();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(err, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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
            ValueListenableBuilder<bool>(
              valueListenable: _isBookingEnabled,
              builder: (context, enabled, _) => SwitchListTile(
                title: Text(
                  context.tr('Enable Booking Service'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  context.tr(''),
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
                value: enabled,
                onChanged: (val) => _isBookingEnabled.value = val,
                activeColor: const Color(0xFF000080),
                contentPadding: EdgeInsets.zero,
              ),
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
            ValueListenableBuilder<TimeOfDay?>(
              valueListenable: _closingTime,
              builder: (context, closingT, _) => GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: closingT ?? const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (picked != null) {
                    _closingTime.value = picked;
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
                        closingT != null
                            ? closingT.format(context)
                            : context.tr('No Closing Time (No Limit)'),
                        style: GoogleFonts.inter(fontSize: 15, color: closingT != null ? Colors.black87 : Colors.grey),
                      ),
                      const Spacer(),
                      if (closingT != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                          onPressed: () => _closingTime.value = null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
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
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: _weeklyOffs,
      builder: (context, offs, _) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allDays.length,
        itemBuilder: (context, index) {
          final day = _allDays[index];
          final isOff = offs.any((w) => w['day'] == day);
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
      ),
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
          child: ValueListenableBuilder<List<dynamic>>(
            valueListenable: _holidays,
            builder: (context, holidayList, _) {
              if (holidayList.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('No custom holidays added yet.'),
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: holidayList.length,
                itemBuilder: (context, index) {
                  final h = holidayList[index];
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
            onPressed: _addPausePeriod,
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
          child: ValueListenableBuilder<List<dynamic>>(
            valueListenable: _pauses,
            builder: (context, pauseList, _) {
              if (pauseList.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('No booking pauses scheduled yet.'),
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: pauseList.length,
                itemBuilder: (context, index) {
                  final p = pauseList[index];
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
              );
            },
          ),
        ),
      ],
    );
  }
}
