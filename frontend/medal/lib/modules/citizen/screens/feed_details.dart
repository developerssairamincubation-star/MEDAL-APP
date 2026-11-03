import 'package:medal/widgets/medal_dialog.dart';
import 'package:medal/widgets/post_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:medal/core/utils/location_text.dart';
import 'package:flutter/services.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/screens/common_button.dart';
import 'package:medal/widgets/comment_bottom_sheet.dart';

class FeedDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? feedData;
  final bool initialShowComments;

  const FeedDetailScreen({
    super.key,
    this.feedData,
    this.initialShowComments = false,
  });

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  late Map<String, dynamic> _data;
  int _upvotes = 0;
  int _comments = 0;
  int _reposts = 0;
  bool _hasUpvoted = false;
  bool _hasReposted = false;
  bool _isLoadingUpvote = false;
  bool _isLoadingRepost = false;

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

    _reposts = _data['reposts_count'] is int
        ? _data['reposts_count']
        : (int.tryParse(_data['reposts_count']?.toString() ?? '0') ?? 0);

    _hasUpvoted = _data['has_upvoted'] == true;
    _hasReposted = _data['has_reposted'] == true;

    _loadUpvoteStatus();
    _loadRepostStatus();

    if (widget.initialShowComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleOpenComments();
      });
    }
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

  Future<void> _loadRepostStatus() async {
    final id = _data['id'] as int?;
    if (id == null || !ApiService().isAuthenticated) return;
    try {
      final status = await ApiService().getRepostStatus(id);
      if (mounted) {
        setState(() {
          _reposts = status['total_reposts'] ?? _reposts;
          _hasReposted = status['has_reposted'] == true;
          _data['reposts_count'] = _reposts;
          _data['has_reposted'] = _hasReposted;
          if (widget.feedData != null) {
            widget.feedData!['reposts_count'] = _reposts;
            widget.feedData!['has_reposted'] = _hasReposted;
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
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleRepost() async {
    final id = _data['id'] as int?;
    if (id == null || _isLoadingRepost) return;

    setState(() => _isLoadingRepost = true);
    try {
      final res = await ApiService().repostComplaint(id);
      if (mounted) {
        final nowReposted = res['has_reposted'] == true;
        setState(() {
          _reposts = res['total_reposts'] ?? _reposts;
          _hasReposted = nowReposted;
          _isLoadingRepost = false;
          _data['reposts_count'] = _reposts;
          _data['has_reposted'] = _hasReposted;
          if (widget.feedData != null) {
            widget.feedData!['reposts_count'] = _reposts;
            widget.feedData!['has_reposted'] = _hasReposted;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nowReposted
                ? 'Reposted! This report now appears on your profile.'
                : 'Repost removed.'),
            backgroundColor: const Color(0xFF0467B6),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRepost = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
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
      builder: (ctx) => MedalAlertDialog(
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
              backgroundColor: Color(0xFF0467B6),
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
        return const Color(0xFF0467B6);
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
    final currentUserId = ApiService().currentUser?['id'];
    final isCurrentUser = (currentUserId != null && _data['citizen_id'] == currentUserId);
    String? rawProfileUrl = _data['profile_image_url'] as String?;
    if ((rawProfileUrl == null || rawProfileUrl.trim().isEmpty) && isCurrentUser) {
      rawProfileUrl = ApiService().currentUser?['profile_image_url'] as String?;
    }
    final resolvedPhotoUrl = (rawProfileUrl != null && rawProfileUrl.trim().isNotEmpty)
        ? ApiService().resolveImageUrl(rawProfileUrl.trim())
        : null;
    final time = _formatTime(_data['created_at']);
    final status = (_data['status'] ?? 'submitted').toString();
    final statusColor = _getStatusColor(status);
    final title = (_data['title'] ?? 'Civic Issue').toString();
    final description = (_data['description'] ?? 'No description provided.').toString();
    final imageUrl = _data['image_url'] as String?;
    final location = displayLocation(_data);
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
                        child: (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  resolvedPhotoUrl,
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0467B6),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0467B6),
                                  ),
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
                      Container(
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

                  // Location (own line, full text) above the SDG info
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.location_on,
                          size: 15,
                          color: Color(0xFF0467B6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          key: const Key('post_location'),
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF0467B6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (sdgText.isNotEmpty) ...[
                    const SizedBox(height: 6),
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
                          Flexible(
                            child: Text(
                              sdgText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B1C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 2. INTERACTION ROW — shared Upvote | Comment | Repost bar
            PostActionBar(
              upvotes: _upvotes,
              comments: _comments,
              reposts: _reposts,
              isUpvoted: _hasUpvoted,
              isReposted: _hasReposted,
              onUpvote: _handleToggleUpvote,
              onComment: _handleOpenComments,
              onRepost: _handleRepost,
              height: 42,
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
                        backgroundColor: Color(0xFF0467B6),
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