import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool _isLoading = false;
  List<dynamic> _complaints = [];
  List<dynamic> _complaintTypes = [];
  String? _selectedBranch = 'All';
  List<String> _branches = ['All'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token ?? '';

      // Load Complaints
      final compRes = await ApiService.listComplaints(token);
      if (compRes['success'] == true) {
        _complaints = compRes['complaints'] ?? [];
      }

      // Load Complaint Types
      final typeRes = await ApiService.listComplaintTypes(token);
      if (typeRes['success'] == true) {
        _complaintTypes = typeRes['complaint_types'] ?? [];
      }

      // Populate branches list if Company Admin
      if (auth.isCompanyAdmin) {
        final branchesSet = _complaints.map((c) => c['branch'] as String).toSet();
        _branches = ['All', ...branchesSet];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading complaints: $e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _promptResolveRemarks(String complaintId) {
    final remarksController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                context.tr('Resolve Complaint'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Enter resolution remarks/notes:'),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: context.tr('e.g. Pump repaired and tested. Working fine now.'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final remarks = remarksController.text.trim();
                          if (remarks.isEmpty) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text(context.tr('Please enter resolution remarks'))),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final token = auth.token ?? '';
                            final res = await ApiService.updateComplaintStatus(
                              token: token,
                              complaintId: complaintId,
                              status: 'resolved',
                              remarks: remarks,
                            );
                            if (res['success'] == true) {
                              Navigator.pop(dialogCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.tr('Complaint marked as resolved'))),
                                );
                              }
                              _loadData();
                            } else {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text(res['message'] ?? 'Failed to update status')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text(context.tr('Error: $e'))),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(context.tr('Resolve'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateComplaintDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token ?? '';
    String? localSelectedTypeId;
    String localSelectedPriority = 'low';
    final descController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Create Complaint'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF000080),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Complaint Type
                  Text(
                    context.tr('Complaint Type'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              menuMaxHeight: 350,
                              hint: Text(context.tr('Select Complaint Type')),
                              value: localSelectedTypeId,
                              items: _complaintTypes.map<DropdownMenuItem<String>>((t) {
                                return DropdownMenuItem<String>(
                                  value: t['id'],
                                  child: Text(t['name']),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() => localSelectedTypeId = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add new Type inline
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF000080), size: 32),
                        onPressed: () async {
                          final newType = await _showCreateComplaintTypeDialog(context);
                          if (newType != null) {
                            await _loadData();
                            setModalState(() {
                              localSelectedTypeId = newType['id'];
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority Segment control
                  Text(
                    context.tr('Priority Level'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['low', 'medium', 'high'].map((prio) {
                      final isSelected = localSelectedPriority == prio;
                      final color = prio == 'low'
                          ? Colors.green
                          : prio == 'medium'
                              ? Colors.orange
                              : Colors.red;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setModalState(() => localSelectedPriority = prio);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.12) : Colors.white,
                                border: Border.all(
                                  color: isSelected ? color : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                prio.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? color : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Complaint Description
                  Text(
                    context.tr('Complaint Details'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: context.tr('Describe the issue or complaint in detail...'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (localSelectedTypeId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('Please select complaint type'))),
                              );
                              return;
                            }
                            if (descController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('Please enter complaint description'))),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);
                            try {
                              final res = await ApiService.createComplaint(
                                token: token,
                                complaintTypeId: localSelectedTypeId!,
                                priority: localSelectedPriority,
                                complaint: descController.text.trim(),
                              );
                              if (res['success'] == true) {
                                Navigator.pop(context);
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.tr('Complaint created successfully'))),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? 'Failed to create complaint')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('Error: $e'))),
                              );
                            } finally {
                              setModalState(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000080),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            context.tr('Submit Complaint'),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showCreateComplaintTypeDialog(BuildContext parentCtx) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.token ?? '';
    final typeNameController = TextEditingController();
    bool isSaving = false;

    return showDialog<Map<String, dynamic>>(
      context: parentCtx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                context.tr('Add Complaint Type'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('Complaint Type Name'),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: typeNameController,
                    decoration: InputDecoration(
                      hintText: context.tr('e.g. Water Supply Issue'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: Text(context.tr('Cancel'), style: GoogleFonts.inter(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = typeNameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text(context.tr('Please enter a type name'))),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final res = await ApiService.createComplaintType(token, name);
                            if (res['success'] == true) {
                              Navigator.pop(dialogCtx, res['complaint_type']);
                            } else {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text(res['message'] ?? 'Failed to create complaint type')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text(context.tr('Error: $e'))),
                            );
                          } finally {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000080),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(context.tr('Add'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isOwner = auth.isCompanyAdmin;

    final isHigh = c['priority'] == 'high';
    final isMedium = c['priority'] == 'medium';
    final priorityColor = isHigh
        ? Colors.red
        : isMedium
            ? Colors.orange
            : Colors.green;

    final status = c['status'] ?? 'new';
    final statusColor = status == 'new'
        ? Colors.blue.shade700
        : status == 'pending'
            ? Colors.orange.shade700
            : Colors.green.shade700;

    final statusBgColor = status == 'new'
        ? Colors.blue.shade50
        : status == 'pending'
            ? Colors.orange.shade50
            : Colors.green.shade50;

    final remarks = c['resolve_remarks']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: priorityColor.withOpacity(0.2)),
                ),
                child: Text(
                  c['priority'].toString().toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
              Text(
                c['date_added'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            c['complaint_type'] ?? 'Complaint',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Icon(Icons.storefront, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                c['branch'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            c['complaint'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),

          if (remarks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_bank_outlined, size: 14, color: Colors.blueGrey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey.shade800),
                        children: [
                          TextSpan(
                            text: 'Resolution Remarks: ',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: remarks),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (isOwner && status != 'resolved') ...[
                ElevatedButton(
                  onPressed: () => _promptResolveRemarks(c['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    context.tr('Resolve'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isBranch = auth.isBranchAdmin;

    final filteredComplaints = _complaints.where((c) {
      return _selectedBranch == 'All' || c['branch'] == _selectedBranch;
    }).toList();

    // Sort: unresolved first (new / pending), then resolved
    final activeComplaints = filteredComplaints.where((c) => c['status'] != 'resolved').toList();
    final resolvedComplaints = filteredComplaints.where((c) => c['status'] == 'resolved').toList();
    final sortedComplaints = [...activeComplaints, ...resolvedComplaints];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          context.tr('Complaints'),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (auth.isCompanyAdmin && _branches.length > 1) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    context.tr('Filter by Branch: '),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedBranch,
                          isExpanded: true,
                          menuMaxHeight: 350,
                          items: _branches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b,
                              child: Text(b, style: GoogleFonts.inter(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedBranch = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading && sortedComplaints.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF000080),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF000080),
                    child: sortedComplaints.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.assignment_turned_in_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.tr('No Complaints found'),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr('Swipe down to check for updates.'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: sortedComplaints.length,
                            itemBuilder: (context, index) {
                              return _buildComplaintCard(sortedComplaints[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isBranch
          ? FloatingActionButton.extended(
              onPressed: _showCreateComplaintDialog,
              backgroundColor: const Color(0xFF000080),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                context.tr('Add Complaint'),
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            )
          : null,
    );
  }
}
