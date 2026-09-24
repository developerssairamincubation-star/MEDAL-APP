import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/screens/common_button.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';
import 'package:medal/widgets/post_comment_section.dart';

class FeedDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? feedData;

  const FeedDetailScreen({super.key, this.feedData});

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  late Map<String, dynamic> _data;
  int _upvotes = 0;
  int _comments = 0;
  int _reports = 0;
  bool _hasUpvoted = false;
  bool _isLoadingUpvote = false;

  @override
  void initState() {
    super.initState();
    _data = widget.feedData != null ? Map<String, dynamic>.from(widget.feedData!) : {};

    _upvotes = _data['upvotes_count'] is int
        ? _data['upvotes_count']
        : (int.tryParse(_data['upvotes_count']?.toString() ?? '0') ?? 0);

    _comments = _data['comments_count'] is int
        ? _data['comments_count']
        : (int.tryParse(_data['comments_count']?.toString() ?? '0') ?? 0);

    _reports = _data['reports_count'] is int
        ? _data['reports_count']
        : (int.tryParse(_data['reports_count']?.toString() ?? _data['report_count']?.toString() ?? '0') ?? 0);

    _hasUpvoted = _data['has_upvoted'] == true;

    _loadUpvoteStatus();
  }

  Future<void> _loadUpvoteStatus() async {
    final id = _data['id'] as int?;
    if (id == null) return;

    try {
      final status = await ApiService().getUpvoteStatus(id);
      if (mounted) {
        setState(() {
          _upvotes = status['total_upvotes'] ?? _upvotes;
          _hasUpvoted = status['has_upvoted'] == true;
          _data['upvotes_count'] = _upvotes;
          _data['has_upvoted'] = _hasUpvoted;
          if (widget.feedData != null) {
            widget.feedData!['upvotes_count'] = _upvotes;
            widget.feedData!['has_upvoted'] = _hasUpvoted;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _handleToggleUpvote() async {
    final id = _data['id'] as int?;
    if (id == null || _isLoadingUpvote) return;

    setState(() => _isLoadingUpvote = true);
    try {
      final res = await ApiService().toggleUpvote(id);
      if (mounted) {
        setState(() {
          _upvotes = res['total_upvotes'] ?? _upvotes;
          _hasUpvoted = res['has_upvoted'] == true;
          _isLoadingUpvote = false;
          _data['upvotes_count'] = _upvotes;
          _data['has_upvoted'] = _hasUpvoted;
          if (widget.feedData != null) {
            widget.feedData!['upvotes_count'] = _upvotes;
            widget.feedData!['has_upvoted'] = _hasUpvoted;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUpvote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isCurrentUserPostAuthor() {
    final user = ApiService().currentUser;
    if (user == null) return false;
    if (user['role'] == 'admin') return true;
    final currentUserId = user['id'];
    final postCitizenId = _data['citizen_id'] ?? _data['user_id'];
    if (currentUserId != null && postCitizenId != null) {
      return currentUserId.toString() == postCitizenId.toString();
    }
    final currentName = (user['full_name'] ?? user['username'] ?? '').toString().trim().toLowerCase();
    final postCitizenName = (_data['citizen_name'] ?? '').toString().trim().toLowerCase();
    return currentName.isNotEmpty && currentName == postCitizenName;
  }

  Future<void> _handleDeletePost() async {
    final id = _data['id'] as int?;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Report"),
        content: const Text("Are you sure you want to delete this civic report? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService().deleteComplaint(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Report deleted successfully."),
              backgroundColor: Color(0xFF4338CA),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete report: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return "Recently";
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes.clamp(1, 60)}m ago";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h ago";
      } else if (diff.inDays < 7) {
        return "${diff.inDays}d ago";
      } else {
        return "${dt.day}/${dt.month}/${dt.year}";
      }
    } catch (_) {
      return "Recently";
    }
  }

  void _handleOpenComments() {
    final id = _data['id'] as int?;
    if (id == null) return;

    CommentBottomSheet.show(
      context,
      complaintId: id,
      initialCount: _comments,
      onCommentCountChanged: (newCount) {
        setState(() {
          _comments = newCount;
          _data['comments_count'] = newCount;
          if (widget.feedData != null) {
            widget.feedData!['comments_count'] = newCount;
          }
        });
      },
    );
  }

  void _showStatusUpdateDialog() {
    final id = _data['id'] as int?;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner with circuit gradient & circular sync icon (Image 2)
              Container(
                width: double.infinity,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Body content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  children: [
                    const Text(
                      "Status update",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Verify the current status of reported grievance and then update the status.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // "Mark as Resolved" primary button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (id != null) {
                            try {
                              final updated = await ApiService().updateComplaintStatus(id, 'resolved');
                              if (mounted) {
                                setState(() {
                                  _data = updated;
                                  if (widget.feedData != null) {
                                    widget.feedData!['status'] = 'resolved';
                                  }
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() {
                                  _data['status'] = 'resolved';
                                  if (widget.feedData != null) {
                                    widget.feedData!['status'] = 'resolved';
                                  }
                                });
                              }
                            }
                          } else {
                            setState(() {
                              _data['status'] = 'resolved';
                              if (widget.feedData != null) {
                                widget.feedData!['status'] = 'resolved';
                              }
                            });
                          }
                          _showGrievanceResolvedDialog();
                        },
                        child: const Text(
                          "Mark as Resolved",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // "Cancel" button
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGrievanceResolvedDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner with checkmark (Image 3)
              Container(
                width: double.infinity,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF4F46E5),
                      size: 26,
                    ),
                  ),
                ),
              ),

              // Body content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    const Text(
                      "Grievance Resolved",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "🏆",
                      style: TextStyle(fontSize: 34),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "25 points added!",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF7E3AF2);
      case 'in_progress':
        return const Color(0xFFE02424);
      case 'under_review':
        return const Color(0xFFD97706);
      case 'rejected':
        return Colors.grey.shade600;
      case 'submitted':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'under_review':
        return 'UNDER REVIEW';
      case 'resolved':
        return 'RESOLVED';
      case 'rejected':
        return 'REJECTED';
      case 'submitted':
      default:
        return 'SUBMITTED';
    }
  }

  String _getSdgText() {
    final sdg = _data['sdg_alignment'] ?? _data['sdg'] ?? _data['sdg_goal'];
    if (sdg == null) return '';
    final s = sdg.toString().trim();
    if (s.isEmpty) return '';
    if (s.toUpperCase().startsWith('SDG')) return s.toUpperCase();
    if (int.tryParse(s) != null) return 'SDG $s';
    return s;
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool showLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, size: 17, color: iconColor),
            if (showLine)
              Container(
                width: 2,
                height: 18,
                color: isDone ? iconColor.withValues(alpha: 0.4) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isDone ? FontWeight.w600 : FontWeight.w500,
                    color: isDone ? const Color(0xFF111827) : const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final initials = (_data['citizen_initials'] ?? 'AC').toString();
    final userName = (_data['citizen_name'] ?? 'Anonymous Citizen').toString();
    final time = _formatTime(_data['created_at']);
    final status = (_data['status'] ?? 'submitted').toString();
    final statusColor = _getStatusColor(status);
    final title = (_data['title'] ?? 'Civic Issue').toString();
    final description = (_data['description'] ?? 'No description provided.').toString();
    final imageUrl = _data['image_url'] as String?;
    final location = (_data['location'] ?? 'Location not specified').toString();
    final sdgText = _getSdgText();
    final authorityName = (_data['assigned_authority'] ?? _data['assigned_officer'] ?? 'Ward Municipal Officer').toString();
    final departmentName = (_data['department'] ?? 'Civic Works Department').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: const Text(
          "Complaint Details",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isCurrentUserPostAuthor())
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              tooltip: "Delete Report",
              onPressed: _handleDeletePost,
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: Color(0xFFF3F4F6),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 1. COMPACT COMPLAINT CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x0A000000),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Avatar, Username, Relative Time, Status Badge
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFFEBF4FA),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "•",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.public,
                                  size: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showStatusUpdateDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _formatStatus(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Compact Title
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),

                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Evidence Image
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        ApiService().resolveImageUrl(imageUrl),
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 120,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Location and SDG Row
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 15,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (sdgText.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE8E8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.track_changes, size: 11, color: Color(0xFF9B1C1C)),
                              const SizedBox(width: 3),
                              Text(
                                sdgText,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9B1C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 2. INTERACTION ROW (UPVOTE, COMMENTS, REPORT with vertical dividers)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x08000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Upvote Button
                    Expanded(
                      child: InkWell(
                        onTap: _handleToggleUpvote,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasUpvoted ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                color: _hasUpvoted ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                                size: 19,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Upvote",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _hasUpvoted ? FontWeight.bold : FontWeight.w500,
                                  color: _hasUpvoted ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                "$_upvotes",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _hasUpvoted ? const Color(0xFF4F46E5) : const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Vertical Divider
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                      indent: 6,
                      endIndent: 6,
                    ),

                    // Comments Button
                    Expanded(
                      child: InkWell(
                        onTap: _handleOpenComments,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                color: Color(0xFF6B7280),
                                size: 19,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Comments",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                "$_comments",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Vertical Divider
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                      indent: 6,
                      endIndent: 6,
                    ),

                    // Report Button
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _reports += 1;
                            _data['reports_count'] = _reports;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Report flagged for civic moderation review."),
                              backgroundColor: Color(0xFF4F46E5),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.flag_outlined,
                                color: Color(0xFF6B7280),
                                size: 19,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                "Report",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                "$_reports",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
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

            const SizedBox(height: 10),

            /// 3. COMMENTS & DISCUSSION SECTION
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: PostCommentSection(
                complaintId: _data['id'] as int? ?? 0,
                initialCommentCount: _comments,
                onCommentCountChanged: (newCount) {
                  setState(() {
                    _comments = newCount;
                    _data['comments_count'] = newCount;
                    if (widget.feedData != null) {
                      widget.feedData!['comments_count'] = newCount;
                    }
                  });
                },
              ),
            ),

            const SizedBox(height: 10),

            /// 4. ASSIGNED AUTHORITY SECTION
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x08000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Assigned Authority",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0xFF4F46E5),
                        child: Icon(Icons.person, color: Colors.white, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              authorityName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              departmentName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 5. PROGRESS TIMELINE SECTION
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x08000000),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Progress Timeline",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTimelineStep(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    title: "Complaint Submitted",
                    subtitle: "Recorded in MEdAL",
                    isDone: true,
                    showLine: true,
                  ),
                  _buildTimelineStep(
                    icon: Icons.assignment,
                    iconColor: status != 'submitted' ? const Color(0xFFD97706) : Colors.grey.shade400,
                    title: "Assigned To Officer",
                    subtitle: status != 'submitted' ? "Active Review" : "Pending",
                    isDone: status != 'submitted',
                    showLine: true,
                  ),
                  _buildTimelineStep(
                    icon: Icons.build,
                    iconColor: (status == 'in_progress' || status == 'resolved') ? const Color(0xFF2563EB) : Colors.grey.shade400,
                    title: "Work In Progress",
                    subtitle: status == 'resolved' ? "Completed" : (status == 'in_progress' ? "On-going" : "Pending"),
                    isDone: status == 'in_progress' || status == 'resolved',
                    showLine: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
      bottomNavigationBar: commonBottomNav(context, 0),
    );
  }
}