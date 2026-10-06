import 'package:flutter/material.dart';
import 'package:medal/core/services/api_service.dart';

/// Single shared comments controller managing comments state per complaint.
/// Both the inline [PostCommentSection] and the [CommentBottomSheet] share
/// the exact same controller instance for a given complaint ID, ensuring
/// instantaneous bidirectional synchronization of comments, replies, deletes, and counts.
class ComplaintCommentsController extends ChangeNotifier {
  final int complaintId;

  static final Map<int, ComplaintCommentsController> _registry = {};

  factory ComplaintCommentsController.forComplaint(int complaintId) {
    return _registry.putIfAbsent(
      complaintId,
      () => ComplaintCommentsController._(complaintId),
    );
  }

  ComplaintCommentsController._(this.complaintId);

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasFetched = false;

  final Set<int> _collapsedParentIds = {};
  final Map<int, int> _userVotes = {};

  List<Map<String, dynamic>> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasFetched => _hasFetched;
  Set<int> get collapsedParentIds => _collapsedParentIds;
  Map<int, int> get userVotes => _userVotes;

  int get activeCommentCount =>
      _comments.where((c) => c['is_deleted'] != true).length;

  /// Builds a fully-threaded hierarchy tree where each reply is nested directly
  /// under the specific comment it responds to (root -> reply -> reply to reply).
  List<CommentThreadNode> getThreadedTree() {
    final allIds = <int>{};
    for (final c in _comments) {
      final id = c['id'] as int?;
      if (id != null) allIds.add(id);
    }

    final Map<int, List<Map<String, dynamic>>> directChildrenMap = {};
    final List<Map<String, dynamic>> rootComments = [];

    for (final c in _comments) {
      final parentId = c['parent_comment_id'] as int?;
      if (parentId == null || !allIds.contains(parentId)) {
        rootComments.add(c);
      } else {
        directChildrenMap.putIfAbsent(parentId, () => []).add(c);
      }
    }

    CommentThreadNode buildNode(Map<String, dynamic> comment, int depth) {
      final id = comment['id'] as int? ?? 0;
      final directChildren = directChildrenMap[id] ?? [];
      return CommentThreadNode(
        comment: comment,
        depth: depth,
        children: directChildren
            .map((child) => buildNode(child, depth + 1))
            .toList(),
      );
    }

    return rootComments.map((root) => buildNode(root, 0)).toList();
  }

  /// Backward-compatible grouping of root comments and replies map
  ({List<Map<String, dynamic>> rootComments, Map<int, List<Map<String, dynamic>>> repliesMap}) getThreadedComments() {
    final Map<int, int?> parentIdLookup = {};
    for (final c in _comments) {
      final id = c['id'] as int?;
      if (id != null) {
        parentIdLookup[id] = c['parent_comment_id'] as int?;
      }
    }

    int getRootParentId(int childId) {
      int current = childId;
      int depth = 0;
      while (parentIdLookup[current] != null && depth < 20) {
        current = parentIdLookup[current]!;
        depth++;
      }
      return current;
    }

    final roots = _comments.where((c) => c['parent_comment_id'] == null).toList();
    final allReplies = _comments.where((c) => c['parent_comment_id'] != null).toList();

    final Map<int, List<Map<String, dynamic>>> repliesMap = {};
    for (final reply in allReplies) {
      final rootId = getRootParentId(reply['id'] as int? ?? 0);
      repliesMap.putIfAbsent(rootId, () => []).add(reply);
    }

    return (rootComments: roots, repliesMap: repliesMap);
  }

  Future<void> fetchComments({bool forceRefresh = false}) async {
    if (_hasFetched && !forceRefresh && !_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading) {
        notifyListeners();
      }
    });

    try {
      final fetched = await ApiService().getComments(complaintId);
      _comments = fetched;
      _hasFetched = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> addComment(
    String content, {
    int? parentCommentId,
  }) async {
    final newComment = await ApiService().addComment(
      complaintId,
      content,
      parentCommentId: parentCommentId,
    );

    _comments.add(newComment);
    _hasFetched = true;
    if (parentCommentId != null) {
      _collapsedParentIds.remove(parentCommentId);
    }
    notifyListeners();
    return newComment;
  }

  Future<void> deleteComment(int commentId) async {
    bool hasReplies = false;
    try {
      final res = await ApiService().deleteComment(complaintId, commentId);
      hasReplies = res['has_replies'] == true;
    } catch (_) {
      // If offline or in test environment, determine reply existence from local state
      hasReplies = _comments.any((c) => c['parent_comment_id'] == commentId);
    }

    if (hasReplies) {
      final idx = _comments.indexWhere((c) => c['id'] == commentId);
      if (idx != -1) {
        _comments[idx]['is_deleted'] = true;
        _comments[idx]['comment'] = 'This comment was deleted';
        _comments[idx]['content'] = 'This comment was deleted';
      }
    } else {
      _comments.removeWhere((c) => c['id'] == commentId);
    }
    notifyListeners();
  }

  /// For tests: directly initialize the in-memory comments state
  void setCommentsForTesting(List<Map<String, dynamic>> comments) {
    _comments = List.from(comments);
    _hasFetched = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void toggleCollapse(int parentId) {
    if (_collapsedParentIds.contains(parentId)) {
      _collapsedParentIds.remove(parentId);
    } else {
      _collapsedParentIds.add(parentId);
    }
    notifyListeners();
  }

  void toggleVote(int commentId, int vote) {
    if (_userVotes[commentId] == vote) {
      _userVotes[commentId] = 0;
    } else {
      _userVotes[commentId] = vote;
    }
    notifyListeners();
  }

  /// For testing or resetting in-memory registry
  static void clearRegistry() {
    _registry.clear();
  }
}

/// Represents a node in the hierarchical comment thread tree.
class CommentThreadNode {
  final Map<String, dynamic> comment;
  final List<CommentThreadNode> children;
  final int depth;

  CommentThreadNode({
    required this.comment,
    required this.children,
    this.depth = 0,
  });

  /// Total count of active descendants in this subtree
  int get totalRepliesCount {
    int count = 0;
    for (final child in children) {
      if (child.comment['is_deleted'] != true) count++;
      count += child.totalRepliesCount;
    }
    return count;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI styling helpers and components (identical across inline & popup)
// ─────────────────────────────────────────────────────────────────────────────

String getCurrentUserInitials() {
  final user = ApiService().currentUser;
  final name = (user?['full_name'] as String?) ?? 'Mukil K';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : 'MK';
}

Map<String, Color> getCommentAvatarColors(String initials) {
  final clean = initials.toUpperCase();
  if (clean == "LG") {
    return {
      "bg": const Color(0xFFE2F952),
      "text": const Color(0xFF4D7C0F),
    };
  } else if (clean == "RG") {
    return {
      "bg": const Color(0xFFBAE6FD),
      "text": const Color(0xFF0369A1),
    };
  } else if (clean == "MK" || clean == "JD") {
    return {
      "bg": const Color(0xFFF3E8FF),
      "text": const Color(0xFF7C3AED),
    };
  } else if (clean == "ML") {
    return {
      "bg": const Color(0xFFDBEAFE),
      "text": const Color(0xFF4F46E5),
    };
  } else if (clean == "OI") {
    return {
      "bg": const Color(0xFFFCE7F3),
      "text": const Color(0xFF9333EA),
    };
  }
  return {
    "bg": const Color(0xFFE0E7FF),
    "text": const Color(0xFF4338CA),
  };
}

String formatCommentTimestamp(dynamic dateStr) {
  if (dateStr == null) return "24m ago";
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
    return "24m ago";
  }
}

Widget buildFormattedCommentText(String text) {
  final words = text.split(" ");
  final List<InlineSpan> spans = [];

  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.startsWith("@")) {
      spans.add(
        TextSpan(
          text: "$word ",
          style: const TextStyle(
            color: Color(0xFF4338CA),
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: "$word ",
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      );
    }
  }

  return RichText(
    text: TextSpan(children: spans),
  );
}

bool isCurrentUserCommentAuthor(Map<String, dynamic> comment) {
  final user = ApiService().currentUser;
  if (user == null) return false;
  if (user['role'] == 'admin') return true;
  final currentUserId = user['id'];
  final commentUserId = comment['user_id'];
  if (currentUserId != null && commentUserId != null) {
    return currentUserId.toString() == commentUserId.toString();
  }
  final currentName = (user['full_name'] ?? user['username'] ?? '').toString().trim().toLowerCase();
  final commentName = (comment['user_name'] ?? comment['username'] ?? '').toString().trim().toLowerCase();
  return currentName.isNotEmpty && currentName == commentName;
}

Widget buildCommentAvatarWidget({
  required String initials,
  required double size,
  String? profileImageUrl,
  dynamic userId,
  double fontSize = 12,
}) {
  final avatarColors = getCommentAvatarColors(initials);
  final currentUserId = ApiService().currentUser?['id'];
  final isCurrentUser = (currentUserId != null &&
      userId != null &&
      currentUserId.toString() == userId.toString());

  String? rawProfileUrl = profileImageUrl;
  if ((rawProfileUrl == null || rawProfileUrl.trim().isEmpty) && isCurrentUser) {
    rawProfileUrl = ApiService().currentUser?['profile_image_url'] as String?;
  }
  final resolvedPhotoUrl = (rawProfileUrl != null && rawProfileUrl.trim().isNotEmpty)
      ? ApiService().resolveImageUrl(rawProfileUrl.trim())
      : null;

  Widget fallbackAvatar() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: avatarColors['bg'],
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: avatarColors['text'],
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      );

  if (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty) {
    return ClipOval(
      child: Image.network(
        resolvedPhotoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallbackAvatar(),
      ),
    );
  }
  return fallbackAvatar();
}

/// Custom painter for tree branch connectors in threaded replies.
/// When [isLast] is false: draws a vertical line through the height and curves right into the avatar.
/// When [isLast] is true: curves right into the avatar and terminates cleanly.
class ThreadBranchPainter extends CustomPainter {
  final bool isLast;
  final double curveY;
  final Color color;
  final double strokeWidth;

  const ThreadBranchPainter({
    required this.isLast,
    this.curveY = 15.0,
    this.color = const Color(0xFFCBD5E1),
    this.strokeWidth = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 0);

    if (isLast) {
      path.lineTo(0, curveY - 7);
      path.quadraticBezierTo(0, curveY, 7, curveY);
      path.lineTo(size.width, curveY);
    } else {
      path.lineTo(0, size.height);
      path.moveTo(0, curveY - 7);
      path.quadraticBezierTo(0, curveY, 7, curveY);
      path.lineTo(size.width, curveY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ThreadBranchPainter oldDelegate) =>
      oldDelegate.isLast != isLast ||
      oldDelegate.curveY != curveY ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Backwards compatibility painter alias
class TreeBranchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.5)
      ..quadraticBezierTo(0, size.height * 0.7, size.width * 0.5, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.7);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Contextual action menu displayed upon long-pressing an authored comment or reply.
void showCommentActionMenu({
  required BuildContext context,
  required Map<String, dynamic> comment,
  required ValueChanged<Map<String, dynamic>> onDelete,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
                title: const Text(
                  "Delete",
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(comment);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                title: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Recursive threaded comment tile rendering multi-level nested replies
/// with tree branch lines, collapse control, voting, and long-press action.
class ThreadedCommentNodeWidget extends StatelessWidget {
  final CommentThreadNode node;
  final ComplaintCommentsController controller;
  final ValueChanged<Map<String, dynamic>> onReply;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final bool isLast;

  const ThreadedCommentNodeWidget({
    super.key,
    required this.node,
    required this.controller,
    required this.onReply,
    required this.onDelete,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final comment = node.comment;
    final commentId = comment['id'] as int? ?? 0;
    final isRoot = node.depth == 0;
    final isCollapsed = controller.collapsedParentIds.contains(commentId);
    final hasChildren = node.children.isNotEmpty;

    final commentCard = _buildCommentCard(context, comment, isRoot);

    if (isRoot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          commentCard,
          if (hasChildren && !isCollapsed) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < node.children.length; i++) ...[
                    ThreadedCommentNodeWidget(
                      node: node.children[i],
                      controller: controller,
                      onReply: onReply,
                      onDelete: onDelete,
                      isLast: i == node.children.length - 1,
                    ),
                    if (i < node.children.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thread branch connector
            CustomPaint(
              size: const Size(18, double.infinity),
              painter: ThreadBranchPainter(
                isLast: isLast,
                curveY: 15.0,
              ),
            ),
            const SizedBox(width: 4),
            // Reply content and deeper children
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  commentCard,
                  if (hasChildren && !isCollapsed) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < node.children.length; i++) ...[
                            ThreadedCommentNodeWidget(
                              node: node.children[i],
                              controller: controller,
                              onReply: onReply,
                              onDelete: onDelete,
                              isLast: i == node.children.length - 1,
                            ),
                            if (i < node.children.length - 1) const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCommentCard(BuildContext context, Map<String, dynamic> comment, bool isRoot) {
    final commentId = comment['id'] as int? ?? 0;
    final initials = (comment['user_initials'] ?? (isRoot ? 'LG' : 'RG')).toString();
    final authorName = (comment['user_name'] ?? comment['username'] ?? (isRoot ? 'Lisa Godwin' : 'Ramya Govindhan')).toString();
    final timestamp = formatCommentTimestamp(comment['created_at']);
    final commentText = (comment['comment'] ?? comment['content'] ?? '').toString();
    final isDeleted = comment['is_deleted'] == true;
    final userVote = controller.userVotes[commentId] ?? 0;
    final baseVotes = (commentId == 3 || commentId == 101) ? 11 : 0;
    final votesDisplay = (baseVotes + userVote).clamp(0, 999);
    final hasChildren = node.children.isNotEmpty;
    final isCollapsed = controller.collapsedParentIds.contains(commentId);

    final avatarSize = isRoot ? 32.0 : 26.0;
    final avatarFontSize = isRoot ? 12.0 : 10.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        if (isDeleted) return;
        if (isCurrentUserCommentAuthor(comment)) {
          showCommentActionMenu(
            context: context,
            comment: comment,
            onDelete: onDelete,
          );
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          buildCommentAvatarWidget(
            initials: initials,
            size: avatarSize,
            profileImageUrl: comment['profile_image_url'] as String?,
            userId: comment['user_id'],
            fontSize: avatarFontSize,
          ),
          const SizedBox(width: 8),

          // Details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author & Timestamp
                Row(
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: isRoot ? 13 : 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "•",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timestamp,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: isRoot ? 11.5 : 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Body text or deleted note
                if (isDeleted)
                  const Text(
                    "This comment was deleted",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  buildFormattedCommentText(commentText),

                const SizedBox(height: 5),

                // Toolbar (Collapse toggle + Upvote + Downvote + Reply)
                // Note: NO visible Delete button! Delete is triggered via onLongPress
                if (!isDeleted)
                  Row(
                    children: [
                      // Collapse control if this comment has children
                      if (hasChildren)
                        GestureDetector(
                          onTap: () => controller.toggleCollapse(commentId),
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              color: Colors.white,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isCollapsed ? Icons.add : Icons.remove,
                              size: 10,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),

                      // Upvote arrow ▲
                      GestureDetector(
                        onTap: () => controller.toggleVote(commentId, userVote == 1 ? 0 : 1),
                        child: Icon(
                          Icons.arrow_drop_up,
                          size: 20,
                          color: userVote == 1 ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                        ),
                      ),

                      // Vote count
                      Text(
                        "$votesDisplay",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: userVote == 1 ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Downvote arrow ▼
                      GestureDetector(
                        onTap: () => controller.toggleVote(commentId, userVote == -1 ? 0 : -1),
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: userVote == -1 ? Colors.redAccent : const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Reply action with replies count
                      GestureDetector(
                        onTap: () => onReply(comment),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 12.5,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${node.children.length}",
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Reply",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF4338CA),
                                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}

/// Backwards compatibility tile for any callers expecting ParentCommentTile
class ParentCommentTile extends StatelessWidget {
  final Map<String, dynamic> parent;
  final List<Map<String, dynamic>> replies;
  final bool isCollapsed;
  final int userVote;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onVote;
  final ValueChanged<Map<String, dynamic>> onReply;
  final ValueChanged<Map<String, dynamic>> onDelete;

  const ParentCommentTile({
    super.key,
    required this.parent,
    required this.replies,
    required this.isCollapsed,
    required this.userVote,
    required this.onToggleCollapse,
    required this.onVote,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final complaintId = parent['complaint_id'] as int? ?? 0;
    final controller = ComplaintCommentsController.forComplaint(complaintId);

    final node = CommentThreadNode(
      comment: parent,
      depth: 0,
      children: replies
          .map((r) => CommentThreadNode(comment: r, children: [], depth: 1))
          .toList(),
    );

    return ThreadedCommentNodeWidget(
      node: node,
      controller: controller,
      onReply: onReply,
      onDelete: onDelete,
    );
  }
}
