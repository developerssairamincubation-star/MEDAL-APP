// lib/modules/authority/screens/complaints/authority_complaint_detail_screen.dart
// Complaint Detail Screen for Authority Officers with full evidence, SDG alignment,
// and status action dialogs (In Progress, Completed, Rejected, Redirected).

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/authority_models.dart';

class AuthorityComplaintDetailScreen extends StatefulWidget {
  final AuthorityComplaint complaint;
  final VoidCallback? onStatusChanged;

  const AuthorityComplaintDetailScreen({
    super.key,
    required this.complaint,
    this.onStatusChanged,
  });

  @override
  State<AuthorityComplaintDetailScreen> createState() =>
      _AuthorityComplaintDetailScreenState();
}

class _AuthorityComplaintDetailScreenState
    extends State<AuthorityComplaintDetailScreen> {
  late AuthorityComplaint _complaint;

  final List<String> _departmentOptions = [
    'Solid Waste Management',
    'Water Supply & Sewerage',
    'Roads & Highways Department (PWD)',
    'Electricity & Street Lighting (TANGEDCO)',
    'Public Health & Sanitation',
    'Traffic Police & Road Safety',
    'Town Planning & Revenue',
    'Stormwater Drainage Department',
  ];

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
  }

  void _showImagePreviewDialog(String imageAsset) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text("Evidence Attachment", style: TextStyle(fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Container(
              height: 280,
              width: double.infinity,
              color: MedalTheme.darkNavy,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_outlined, size: 56, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(
                    imageAsset,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "(Evidence attachment uploaded by citizen)",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMarkInProgress() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.play_circle_outline, color: MedalTheme.primary),
            SizedBox(width: 8),
            Text("Mark as In Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Assigning this complaint will notify the citizen and track the resolution SLA.",
              style: TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: "Add officer notes (optional, e.g. Crew assigned)",
                hintStyle: const TextStyle(fontSize: 13, color: MedalTheme.gray),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _complaint.status = AuthorityComplaintStatus.inProgress;
                if (notesController.text.trim().isNotEmpty) {
                  _complaint.officerNotes = notesController.text.trim();
                }
              });
              widget.onStatusChanged?.call();
              Navigator.pop(ctx);
              _showToast("Complaint marked as In Progress");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MedalTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _handleMarkCompleted() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text("Complete Complaint", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please provide a resolution summary for citizen confirmation and audit record.",
              style: TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: "Resolution notes (e.g. Pipeline patched and tested)",
                hintStyle: const TextStyle(fontSize: 13, color: MedalTheme.gray),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _complaint.status = AuthorityComplaintStatus.completed;
                _complaint.officerNotes = notesController.text.trim().isNotEmpty
                    ? notesController.text.trim()
                    : 'Work executed and verified by assigned officer.';
              });
              widget.onStatusChanged?.call();
              Navigator.pop(ctx);
              _showToast("Complaint marked as Completed");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Resolve"),
          ),
        ],
      ),
    );
  }

  void _handleRejectComplaint() {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text("Reject Complaint", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "A detailed reason is mandatory when rejecting a citizen grievance.",
                style: TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: "Enter mandatory rejection reason...",
                  hintStyle: const TextStyle(fontSize: 13, color: MedalTheme.gray),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                  ),
                ),
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Reason is required for rejection";
                  }
                  if (val.trim().length < 8) {
                    return "Please provide at least 8 characters explanation";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _complaint.status = AuthorityComplaintStatus.rejected;
                  _complaint.rejectionReason = reasonController.text.trim();
                });
                widget.onStatusChanged?.call();
                Navigator.pop(ctx);
                _showToast("Complaint rejected with recorded reason");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  void _handleRedirectComplaint() {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    String selectedDept = _departmentOptions.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.alt_route_rounded, color: MedalTheme.primaryDark),
              SizedBox(width: 8),
              Text("Redirect Complaint",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select the appropriate department and provide a redirection rationale.",
                    style: TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Target Authority / Department",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                    ),
                    items: _departmentOptions
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedDept = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Redirection Reason (Mandatory)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: "Explain why this belongs to target department...",
                      hintStyle: const TextStyle(fontSize: 13, color: MedalTheme.gray),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                      ),
                    ),
                    maxLines: 3,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Redirection reason is required";
                      }
                      if (val.trim().length < 8) {
                        return "Please provide at least 8 characters explanation";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _complaint.status = AuthorityComplaintStatus.redirected;
                    _complaint.redirectedDepartment = selectedDept;
                    _complaint.redirectionReason = reasonController.text.trim();
                  });
                  widget.onStatusChanged?.call();
                  Navigator.pop(ctx);
                  _showToast("Complaint redirected to $selectedDept");
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MedalTheme.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Redirect"),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: MedalTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedalTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: MedalTheme.darkNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _complaint.id,
          style: const TextStyle(
            color: MedalTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _complaint.status.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _complaint.status.label.toUpperCase(),
              style: TextStyle(
                color: _complaint.status.color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),
        ),
      ),
      bottomNavigationBar: _buildBottomActionsBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority & Category Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _complaint.priority.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 14, color: _complaint.priority.color),
                      const SizedBox(width: 4),
                      Text(
                        "${_complaint.priority.label} Priority",
                        style: TextStyle(
                          color: _complaint.priority.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _complaint.category,
                    style: const TextStyle(
                      color: MedalTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              _complaint.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: MedalTheme.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Reported By & Date
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: MedalTheme.slateBlue),
                const SizedBox(width: 4),
                Text(
                  "Reported by ${_complaint.reportedBy}",
                  style: const TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 16, color: MedalTheme.slateBlue),
                const SizedBox(width: 4),
                Text(
                  _complaint.ward,
                  style: const TextStyle(fontSize: 13, color: MedalTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 1: Detailed Description
            _buildSectionCard(
              title: "Citizen Grievance Description",
              icon: Icons.notes_rounded,
              child: Text(
                _complaint.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: MedalTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Location & Coordinates
            _buildSectionCard(
              title: "Geographical Location & Jurisdiction",
              icon: Icons.location_on_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place, color: MedalTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _complaint.address,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "GPS Coordinates: ${_complaint.latitude}, ${_complaint.longitude} (${_complaint.ward})",
                    style: const TextStyle(fontSize: 12, color: MedalTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  // Mock Map View Card
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MedalTheme.lavenderBorder),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.map_outlined, size: 48, color: Color(0xFF94A3B8)),
                        Positioned(
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.navigation, size: 14, color: MedalTheme.primary),
                                SizedBox(width: 4),
                                Text(
                                  "Precise GPS Pin Confirmed",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: MedalTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Evidence & Attachments
            _buildSectionCard(
              title: "Citizen Evidence & Attachments (${_complaint.evidenceImages.length})",
              icon: Icons.camera_alt_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: _complaint.evidenceImages.map((img) {
                      return GestureDetector(
                        onTap: () => _showImagePreviewDialog(img),
                        child: Container(
                          width: 100,
                          height: 90,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MedalTheme.lavenderBorder),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, color: MedalTheme.primary, size: 30),
                              SizedBox(height: 4),
                              Text("View Photo",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: SDG Alignment Card
            _buildSectionCard(
              title: "United Nations SDG Alignment",
              icon: Icons.eco_outlined,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _complaint.sdg.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _complaint.sdg.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _complaint.sdg.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "SDG\n${_complaint.sdg.number}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _complaint.sdg.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _complaint.sdg.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _complaint.sdg.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MedalTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Reactions & Community Engagement
            _buildSectionCard(
              title: "Community Reactions & Engagement",
              icon: Icons.thumb_up_alt_outlined,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: MedalTheme.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MedalTheme.lavenderBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 18, color: MedalTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          "${_complaint.upvotes} Citizen Upvotes",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MedalTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16, color: MedalTheme.slateBlue),
                        const SizedBox(width: 6),
                        Text(
                          "${_complaint.commentsCount} Comments",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section 6: Officer Notes / Action Audit History
            if (_complaint.officerNotes != null ||
                _complaint.rejectionReason != null ||
                _complaint.redirectionReason != null) ...[
              const SizedBox(height: 16),
              _buildSectionCard(
                title: "Official Audit Log",
                icon: Icons.history_edu_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_complaint.officerNotes != null) ...[
                      const Text("Officer Notes:",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(_complaint.officerNotes!,
                          style: const TextStyle(fontSize: 13, color: MedalTheme.textSecondary)),
                      const SizedBox(height: 8),
                    ],
                    if (_complaint.rejectionReason != null) ...[
                      const Text("Rejection Reason:",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red)),
                      Text(_complaint.rejectionReason!,
                          style: const TextStyle(fontSize: 13, color: MedalTheme.textSecondary)),
                      const SizedBox(height: 8),
                    ],
                    if (_complaint.redirectionReason != null) ...[
                      Text("Redirected to: ${_complaint.redirectedDepartment}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13, color: Colors.purple)),
                      Text("Reason: ${_complaint.redirectionReason}",
                          style: const TextStyle(fontSize: 13, color: MedalTheme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedalTheme.lavenderBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MedalTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MedalTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: MedalTheme.lavenderBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Officer Actions",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MedalTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 1. In Progress
                Expanded(
                  child: ElevatedButton(
                    onPressed: _complaint.status == AuthorityComplaintStatus.inProgress
                        ? null
                        : _handleMarkInProgress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MedalTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("In Progress",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Completed
                Expanded(
                  child: ElevatedButton(
                    onPressed: _complaint.status == AuthorityComplaintStatus.completed
                        ? null
                        : _handleMarkCompleted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Completed",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Rejected (Must request reason)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _complaint.status == AuthorityComplaintStatus.rejected
                        ? null
                        : _handleRejectComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Reject",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Redirected (Must request reason & department)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _complaint.status == AuthorityComplaintStatus.redirected
                        ? null
                        : _handleRedirectComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MedalTheme.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Redirect",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
