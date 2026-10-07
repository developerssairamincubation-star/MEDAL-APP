import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medal/core/services/api_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? complaintData;
  final int? complaintId;

  const ComplaintDetailScreen({
    super.key,
    this.complaintData,
    this.complaintId,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.complaintData != null) {
      _data = Map<String, dynamic>.from(widget.complaintData!);
    } else if (widget.complaintId != null) {
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    final id = widget.complaintId ?? _data?['id'];
    if (id == null) return;

    setState(() => _isLoading = true);
    try {
      final details = await ApiService().getComplaintDetails(id);
      if (mounted) {
        setState(() {
          _data = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final id = _data?['id'];
    if (id == null) return;

    try {
      final updated = await ApiService().updateComplaintStatus(id, newStatus);
      if (mounted) {
        setState(() {
          _data = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status updated to ${_formatStatus(newStatus)}"),
            backgroundColor: const Color(0xFF2321BC),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.purple;
      case 'under_review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'submitted':
      default:
        return const Color(0xFF2321BC);
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'under_review':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      case 'submitted':
      default:
        return 'Submitted';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5FA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2321BC))),
      );
    }

    if (_errorMessage != null || _data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF111827)),
          title: const Text("Complaint Details", style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1.0, thickness: 1.0, color: Color(0xFFF3F4F6)),
          ),
        ),
        body: Center(
          child: Text(_errorMessage ?? "Complaint not found"),
        ),
      );
    }

    final id = _data!['id'];
    final title = _data!['title'] ?? 'Untitled';
    final description = _data!['description'] ?? 'No description provided.';
    final category = (_data!['category'] ?? 'General').toString().toUpperCase();
    final location = _data!['location'] ?? 'No location';
    final status = (_data!['status'] ?? 'submitted').toString();
    final createdAt = _data!['created_at'] != null
        ? DateTime.tryParse(_data!['created_at'])?.toLocal().toString().split('.')[0] ?? _data!['created_at']
        : 'N/A';
    final statusColor = _getStatusColor(status);
    final userRole = ApiService().userRole;
    final isOfficialOrAdmin = userRole == 'official' || userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: Text(
          "Complaint #$id",
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, thickness: 1.0, color: Color(0xFFF3F4F6)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Card 1: Header + Basic Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2321BC).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Color(0xFF2321BC),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Color(0xFF2321BC)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Reported on: $createdAt",
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /// Card: Alignment & Classifications (SDG, Impact, Equity)
            if (_data?['sdg_alignment'] != null || _data?['impact_level'] != null || _data?['equity_classification'] != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "IMPACT & SDG CLASSIFICATION",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2321BC),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_data?['sdg_alignment'] != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.public, color: Color(0xFF059669), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("SDG Alignment", style: TextStyle(fontSize: 11, color: Colors.black54)),
                                Text(
                                  _data!['sdg_alignment'].toString(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_data?['equity_classification'] != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: Color(0xFF2321BC), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Equity Zone", style: TextStyle(fontSize: 11, color: Colors.black54)),
                                Text(
                                  _data!['equity_classification'].toString(),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_data?['impact_level'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 18),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Impact Level", style: TextStyle(fontSize: 11, color: Colors.black54)),
                              Text(
                                _data!['impact_level'].toString(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// Card: Photo Evidence
            if (_data?['image_url'] != null && _data!['image_url'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_library_outlined, color: Color(0xFF2321BC), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "PHOTO EVIDENCE",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2321BC),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ApiService().resolveImageUrl(_data!['image_url'].toString()),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 100,
                          color: Colors.grey.shade100,
                          child: const Center(child: Text("Evidence attachment preview not accessible")),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// Card 2: Full Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DESCRIPTION",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2321BC),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /// Official/Admin Status Management Actions
            if (isOfficialOrAdmin) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "OFFICIAL ACTIONS",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2321BC),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Update Complaint Status:",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusActionButton("submitted", "Submitted", const Color(0xFF2321BC)),
                        _statusActionButton("under_review", "Under Review", Colors.orange),
                        _statusActionButton("in_progress", "In Progress", Colors.purple),
                        _statusActionButton("resolved", "Resolved", Colors.green),
                        _statusActionButton("rejected", "Rejected", Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            /// Card 3: Status Progression
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "STATUS TIMELINE",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2321BC),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _timelineStep(
                    title: "1. Complaint Submitted",
                    subtitle: "Issue recorded in MEDAL database.",
                    isCompleted: true,
                  ),
                  _timelineStep(
                    title: "2. Under Review",
                    subtitle: "Assigned to the relevant municipal department.",
                    isCompleted: status == 'under_review' || status == 'in_progress' || status == 'resolved',
                  ),
                  _timelineStep(
                    title: "3. In Progress",
                    subtitle: "Field team is actively addressing the issue.",
                    isCompleted: status == 'in_progress' || status == 'resolved',
                  ),
                  _timelineStep(
                    title: "4. Resolved",
                    subtitle: "Issue has been resolved and verified.",
                    isCompleted: status == 'resolved',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusActionButton(String value, String label, Color color) {
    final isCurrent = (_data?['status'] ?? '').toString().toLowerCase() == value;
    return ElevatedButton(
      onPressed: isCurrent ? null : () => _updateStatus(value),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _timelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF2321BC) : Colors.grey.shade300,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? const Color(0xFF2321BC) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCompleted ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted ? Colors.black54 : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}