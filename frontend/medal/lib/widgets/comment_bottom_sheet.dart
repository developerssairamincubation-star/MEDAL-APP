import 'package:flutter/material.dart';
import 'package:medal/core/services/api_service.dart';

class CommentBottomSheet extends StatefulWidget {
  final int complaintId;
  final int initialCount;
  final ValueChanged<int>? onCommentCountChanged;

  const CommentBottomSheet({
    super.key,
    required this.complaintId,
    this.initialCount = 0,
    this.onCommentCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required int complaintId,
    int initialCount = 0,
    ValueChanged<int>? onCommentCountChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentBottomSheet(
        complaintId: complaintId,
        initialCount: initialCount,
        onCommentCountChanged: onCommentCountChanged,
      ),
    );
  }

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];

  // Active reply target comment
  Map<String, dynamic>? _replyTarget;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    _commentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _activeCommentCount =>
      _comments.where((c) => c['is_deleted'] != true).length;

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final comments = await ApiService().getComments(widget.complaintId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
        widget.onCommentCountChanged?.call(_activeCommentCount);
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

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final parentId = _replyTarget != null ? (_replyTarget!['id'] as int?) : null;
      final newComment = await ApiService().addComment(
        widget.complaintId,
        text,
        parentCommentId: parentId,
      );

      _commentController.clear();

      if (mounted) {
        setState(() {
          _comments.add(newComment);
          _replyTarget = null;
          _isSubmitting = false;
        });

        widget.onCommentCountChanged?.call(_activeCommentCount);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleReplyTo(Map<String, dynamic> comm) {
    if (comm['is_deleted'] == true) return;
    final author = (comm['user_name'] ?? comm['username'] ?? 'Citizen').toString();
    setState(() {
      _replyTarget = comm;
      if (!_commentController.text.contains('@$author')) {
        _commentController.text = '@$author ${_commentController.text}'.trim();
        if (!_commentController.text.endsWith(' ')) {
          _commentController.text = '${_commentController.text} ';
        }
        _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentController.text.length),
        );
      }
    });
    _focusNode.requestFocus();
  }

  void _handleCommentLongPress(Map<String, dynamic> comm) {
    if (comm['is_deleted'] == true) return;

    final currentUserId = ApiService().currentUserId;
    final commentUserId = comm['user_id'];

    final isOwner = currentUserId != null &&
        commentUserId != null &&
        (currentUserId.toString() == commentUserId.toString());

    if (!isOwner) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  "Delete comment",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteComment(comm);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteComment(Map<String, dynamic> comm) async {
    final commentId = comm['id'] as int?;
    if (commentId == null) return;

    try {
      final res = await ApiService().deleteComment(widget.complaintId, commentId);

      if (mounted) {
        setState(() {
          final hasRepliesInList =
              _comments.any((c) => c['parent_comment_id'] == commentId);
          final serverHasReplies = res['has_replies'] == true;

          if (hasRepliesInList || serverHasReplies) {
            comm['is_deleted'] = true;
            comm['comment'] = "This comment was deleted";
            comm['content'] = "This comment was deleted";
            comm['user_name'] = "[deleted]";
            comm['username'] = "[deleted]";
          } else {
            _comments.removeWhere((c) => c['id'] == commentId);
          }
        });

        widget.onCommentCountChanged?.call(_activeCommentCount);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Comment deleted"),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF4F46E5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<String> _getMentionSuggestions() {
    final text = _commentController.text;
    final lastAt = text.lastIndexOf('@');
    if (lastAt < 0 || lastAt + 1 > text.length) return [];
    final query = text.substring(lastAt + 1).toLowerCase();
    if (query.contains(' ')) return [];

    final names = <String>{};
    for (final c in _comments) {
      if (c['is_deleted'] == true) continue;
      final name = (c['user_name'] ?? c['username'] ?? '').toString().trim();
      if (name.isNotEmpty && name.toLowerCase().contains(query)) {
        names.add(name);
      }
    }
    return names.take(4).toList();
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return "Just now";
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        return "Just now";
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m ago";
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

  List<Map<String, dynamic>> _getRootComments() {
    return _comments.where((c) => c['parent_comment_id'] == null).toList();
  }

  List<Map<String, dynamic>> _getRepliesFor(dynamic parentId) {
    if (parentId == null) return [];
    return _comments.where((c) => c['parent_comment_id'] == parentId).toList();
  }

  Widget _buildAvatar(Map<String, dynamic> comm, double radius) {
    final isDeleted = comm['is_deleted'] == true;
    if (isDeleted) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: Icon(Icons.person_off_outlined, size: radius, color: Colors.grey.shade500),
      );
    }

    final profileUrl = comm['profile_image_url'] as String?;
    final initials = (comm['user_initials'] ?? 'C').toString();

    if (profileUrl != null && profileUrl.trim().isNotEmpty) {
      final resolved = ApiService().resolveImageUrl(profileUrl);
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFEBF4FA),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: radius * 0.75,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEBF4FA),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildCommentContent(String text, bool isDeleted) {
    if (isDeleted) {
      return const Text(
        "This comment was deleted",
        style: TextStyle(
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: Color(0xFF9CA3AF),
          height: 1.35,
        ),
      );
    }

    final words = text.split(' ');
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final hasSpace = i < words.length - 1;
      if (word.startsWith('@') && word.length > 1) {
        spans.add(
          TextSpan(
            text: word + (hasSpace ? ' ' : ''),
            style: const TextStyle(
              color: Color(0xFF4F46E5),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: word + (hasSpace ? ' ' : ''),
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildCommentCard(Map<String, dynamic> comm, {int depth = 0}) {
    final isDeleted = comm['is_deleted'] == true;
    final userName = (comm['user_name'] ?? comm['username'] ?? 'Citizen').toString();
    final commentText = (comm['content'] ?? comm['comment'] ?? '').toString();
    final timeAgo = _formatTime(comm['created_at']);
    final isReply = depth > 0;
    final avatarRadius = isReply ? 13.0 : 15.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onLongPress: isDeleted ? null : () => _handleCommentLongPress(comm),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: isReply ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: isDeleted
                ? const Color(0xFFF9FAFB)
                : (isReply ? const Color(0xFFF9FAFC) : const Color(0xFFF8F8FD)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isReply ? const Color(0xFFE5E7EB) : const Color(0xFFE2E4F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(comm, avatarRadius),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Name & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: isDeleted ? FontWeight.normal : FontWeight.bold,
                            fontSize: isReply ? 12 : 13,
                            color: isDeleted ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                          ),
                        ),
                        if (!isDeleted)
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Content
                    _buildCommentContent(commentText, isDeleted),

                    if (!isDeleted) ...[
                      const SizedBox(height: 4),

                      // Action Bar: Reply Button
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _handleReplyTo(comm),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.reply_rounded,
                                    size: 13,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    "Reply",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBranch(Map<String, dynamic> reply, {int depth = 1}) {
    final nestedReplies = _getRepliesFor(reply['id']);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentCard(reply, depth: depth),
          if (nestedReplies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 14, top: 4),
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: nestedReplies
                    .map((nr) => _buildReplyBranch(nr, depth: depth + 1))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThreadRoot(Map<String, dynamic> rootComment) {
    final replies = _getRepliesFor(rootComment['id']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentCard(rootComment, depth: 0),
          if (replies.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 16, top: 4),
              padding: const EdgeInsets.only(left: 10),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Color(0xFFE5E7EB),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies
                    .map((reply) => _buildReplyBranch(reply, depth: 1))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafety = MediaQuery.of(context).padding.bottom;
    final totalCount = _activeCommentCount;
    final rootComments = _getRootComments();
    final mentionSuggestions = _getMentionSuggestions();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isLoading ? "Comments" : "Comments ($totalCount)",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Close",
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Comments Thread List / Empty State / Loader
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _fetchComments,
                              child: const Text(
                                "Retry",
                                style: TextStyle(color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5F5FA),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  "No comments yet.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Be the first to start the discussion.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            itemCount: rootComments.length,
                            itemBuilder: (context, index) {
                              return _buildThreadRoot(rootComments[index]);
                            },
                          ),
          ),

          // Bottom Input Bar with Reply Banner & Mention Suggestions
          Container(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 8,
              bottom: keyboardPadding > 0 ? keyboardPadding + 8 : bottomSafety + 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A000000),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Replying To Banner
                if (_replyTarget != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF4FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB9DCF5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          size: 15,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Replying to @${_replyTarget!['user_name'] ?? _replyTarget!['username'] ?? 'Citizen'}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _replyTarget = null;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Mention Suggestions
                if (mentionSuggestions.isNotEmpty)
                  Container(
                    height: 30,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mentionSuggestions.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final name = mentionSuggestions[index];
                        return ActionChip(
                          label: Text(
                            "@$name",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          backgroundColor: const Color(0xFFEBF4FA),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final text = _commentController.text;
                            final lastAt = text.lastIndexOf('@');
                            if (lastAt >= 0) {
                              final prefix = text.substring(0, lastAt);
                              _commentController.text = '$prefix@$name ';
                              _commentController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _commentController.text.length),
                              );
                            }
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),

                // Input Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _replyTarget != null
                                ? "Write a reply..."
                                : "Write a comment...",
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                          onSubmitted: (_) => _handleSubmitComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFF4F46E5),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSubmitting ? null : _handleSubmitComment,
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                        ),
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
