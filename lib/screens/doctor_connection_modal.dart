import 'package:flutter/material.dart';
import '../services/clinician_service.dart';

class DoctorInfo {
  final int doctorId;
  final String name;
  final String email;
  final String specialty;
  final String? clinic;
  final String? location;
  final bool isValidated;
  final int? linkId; // ADDED: Needed for cancellation
  final bool isPending; // ADDED

  DoctorInfo({
    required this.doctorId, required this.name, required this.email,
    required this.specialty, this.clinic, this.location, required this.isValidated,
    this.linkId, this.isPending = false,
  });
}

class DoctorConnectionModal extends StatefulWidget {
  final int childId;
  const DoctorConnectionModal({super.key, required this.childId});

  @override
  State<DoctorConnectionModal> createState() => _DoctorConnectionModalState();
}

class _DoctorConnectionModalState extends State<DoctorConnectionModal> {
  final _searchController = TextEditingController();
  List<DoctorInfo> _allDoctors = [];
  List<DoctorInfo> _filteredDoctors = [];
  List<DoctorInfo> _pendingRequests = [];
  // ignore: unused_field
  List<DoctorInfo> _activeConnections = [];
  String _searchQuery = '';
  // ignore: unused_field
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterDoctors);
  }

  Future<void> _loadData() async {
    try {
      final availableDocsRaw = await ClinicianService.instance.getAvailableDoctors();
      final linksRaw = await ClinicianService.instance.getChildLinks(widget.childId);

      final List<DoctorInfo> pending = [];
      final List<DoctorInfo> active = [];
      final List<int> linkedDoctorIds = [];

      for (var link in linksRaw) {
        linkedDoctorIds.add(link['doctor_id']);
        final doc = DoctorInfo(
          doctorId: link['doctor_id'],
          linkId: link['link_id'],
          name: 'Dr. ${link['first_name']} ${link['last_name']}'.trim(),
          email: link['email'] ?? '',
          specialty: link['specialty'] ?? '',
          clinic: link['clinic'],
          isValidated: true,
          isPending: link['is_active'] == 0,
        );
        if (link['is_active'] == 0) {
          pending.add(doc);
        } else {
          active.add(doc);
        }
      }

      final List<DoctorInfo> available = availableDocsRaw
          .where((d) => !linkedDoctorIds.contains(d['doctor_id']))
          .map((d) => DoctorInfo(
                doctorId: d['doctor_id'],
                name: 'Dr. ${d['first_name']} ${d['last_name']}'.trim(),
                email: d['email'] ?? '',
                specialty: d['specialty'] ?? '',
                clinic: d['clinic'], location: d['location'],
                isValidated: d['is_validated'] == 1,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _allDoctors = available;
          _filteredDoctors = available;
          _pendingRequests = pending;
          _activeConnections = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDoctors() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      _filteredDoctors = _allDoctors.where((doctor) {
        return doctor.name.toLowerCase().contains(query) || doctor.specialty.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ignore: unused_element
  Future<void> _sendConnectionRequest(DoctorInfo doctor) async {
    final success = await ClinicianService.instance.requestConnection(widget.childId, doctor.doctorId);
    if (!mounted) return;
    if (success) {
      showDialog(context: context, builder: (context) => _SuccessDialog(doctorName: doctor.name));
      _loadData(); // Refresh lists
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send request')));
    }
  }

  Future<void> _cancelPendingRequest(DoctorInfo doctor) async {
    if (doctor.linkId == null) return;
    final success = await ClinicianService.instance.cancelConnection(doctor.linkId!);
    if (success && mounted) _loadData(); // Refresh lists
  }

  void _connectDoctor(DoctorInfo doctor) {
    _showConfirmationDialog(doctor);
  }

  void _showConfirmationDialog(DoctorInfo doctor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: Text(
          'Confirm Connection',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send connection request to',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD5C2E8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        doctor.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (doctor.isValidated) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  Text(doctor.email, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  Text(doctor.specialty, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                'This will allow the doctor to monitor your child\'s eye health data. You can revoke access at any time.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendConnectionRequest(doctor); // Wires up to the new live API!
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD5C2E8),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Connect'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connect with Doctor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctors by name, specialty...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2C) : const Color(0xFFF5F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available Doctors Section
                  if (_filteredDoctors.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Doctors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredDoctors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doctor = _filteredDoctors[index];
                            return _DoctorCard(
                              isDark: isDark,
                              doctor: doctor,
                              onConnect: () => _connectDoctor(doctor),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    )
                  else if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No doctors found matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    ),

                  // Pending Requests Section
                  if (_pendingRequests.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doctor = _pendingRequests[index];
                            return _PendingRequestCard(
                              isDark: isDark,
                              doctor: doctor,
                              onCancel: () => _cancelPendingRequest(doctor),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ACC1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final bool isDark;
  final DoctorInfo doctor;
  final VoidCallback onConnect;

  const _DoctorCard({
    required this.isDark,
    required this.doctor,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD5C2E8).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD5C2E8).withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5C2E8).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFD5C2E8),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      doctor.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      doctor.specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD5C2E8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (doctor.clinic != null || doctor.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${doctor.clinic ?? 'Clinic'}, ${doctor.location ?? 'Location'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD5C2E8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Connect →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final bool isDark;
  final DoctorInfo doctor;
  final VoidCallback onCancel;

  const _PendingRequestCard({
    required this.isDark,
    required this.doctor,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  doctor.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const Text(
                  'Waiting for approval...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  final String doctorName;

  const _SuccessDialog({required this.doctorName});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFB9E3A4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Request Sent!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connection request sent to\n${widget.doctorName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
