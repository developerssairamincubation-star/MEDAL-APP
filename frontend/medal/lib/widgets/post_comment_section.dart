// lib/widgets/post_comment_section.dart
// Production-quality, reusable comment interaction & display widget matching the reference UI.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/services/api_service.dart';

/// Reusable comment section displayed below feed post action bar.
/// Handles:
/// - Comment input bar with circular avatar, '@' mention, emoji picker, image attachment
/// - Parent comments with voting, replies count, and reply action
/// - Nested replies indented with vertical branch line and '(-)' collapse/expand control
/// - 'Show all comments.' expansion action at bottom
class PostCommentSection extends StatefulWidget {
  final int complaintId;
  final int initialCommentCount;
  final ValueChanged<int>? onCommentCountChanged;
  final VoidCallback? onShowAllPressed;

  const PostCommentSection({
    super.key,
    required this.complaintId,
    this.initialCommentCount = 0,
    this.onCommentCountChanged,
    this.onShowAllPressed,
  });

  @override
  State<PostCommentSection> createState() => _PostCommentSectionState();
}

class _PostCommentSectionState extends State<PostCommentSection> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _comments = [];

  // Active reply target: {'id': int, 'user_name': String}
  Map<String, dynamic>? _replyingTo;

  // Selected image attachment
  XFile? _selectedImage;

  // Emoji picker strip visibility
  bool _showEmojiStrip = false;

  // Track collapsed status of parent comments: set of parent comment IDs that are collapsed
  final Set<int> _collapsedParentIds = {};

  // Track local upvotes and downvotes: commentId -> vote (1 for up, -1 for down, 0 for none)
  final Map<int, int> _userVotes = {};

  // Whether the user tapped "Show all comments." to expand the entire thread
  bool _showAll = false;

  final List<String> _quickEmojis = [
    "👍",
    "👏",
    "🙏",
    "😊",
    "❤️",
    "🔥",
    "⚠️",
    "✅",
    "🙌",
    "🤝",
  ];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService().getComments(widget.complaintId);
      if (mounted) {
        setState(() {
          _comments = data;
          _isLoading = false;
        });
        widget.onCommentCountChanged?.call(_comments.length);
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

  String _getCurrentUserInitials() {
    final user = ApiService().currentUser;
    final name = (user?['full_name'] as String?) ?? 'Mukil K';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'MK';
  }

  Map<String, Color> _getAvatarColors(String initials) {
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
    } else if (clean == "MK") {
      return {
        "bg": const Color(0xFFF3E8FF),
        "text": const Color(0xFF7C3AED),
      };
    } else if (clean == "JD") {
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

  String _formatTimestamp(dynamic dateStr) {
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

  Future<void> _handlePickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not pick image: $e")),
      );
    }
  }

  void _handleMentionClick() {
    final text = _textController.text;
    final newText = text.isEmpty || text.endsWith(" ") ? "$text@" : "$text @";
    _textController.text = newText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _focusNode.requestFocus();
  }

  void _handleEmojiInsert(String emoji) {
    final text = _textController.text;
    _textController.text = "$text$emoji ";
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  Future<void> _submitComment() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final parentId = _replyingTo != null
          ? ((_replyingTo!['parent_comment_id'] as int?) ?? (_replyingTo!['id'] as int?))
          : null;
      final added = await ApiService().addComment(
        widget.complaintId,
        content.isNotEmpty ? content : "[Image Attachment]",
        parentCommentId: parentId,
      );

      _textController.clear();
      if (mounted) {
        setState(() {
          _comments.add(added);
          _showAll = true;
          if (parentId != null) {
            _collapsedParentIds.remove(parentId);
            final targetId = _replyingTo?['id'] as int?;
            if (targetId != null) {
              _collapsedParentIds.remove(targetId);
            }
          }
          _replyingTo = null;
          _selectedImage = null;
          _showEmojiStrip = false;
          _isSubmitting = false;
        });
        widget.onCommentCountChanged?.call(_comments.length);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parentId != null ? "Reply posted!" : "Comment posted!"),
            backgroundColor: const Color(0xFF4338CA),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to post: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startReply(Map<String, dynamic> targetComment) {
    setState(() {
      _replyingTo = targetComment;
      final author = targetComment['user_name'] ?? targetComment['username'] ?? 'User';
      _textController.text = "@${author.toString().replaceAll(' ', '')} ";
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _textController.clear();
    });
  }

  bool _isCurrentUserCommentAuthor(Map<String, dynamic> comment) {
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

  Future<void> _confirmDeleteComment(Map<String, dynamic> comment) async {
    final commentId = comment['id'] as int?;
    if (commentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Comment"),
        content: const Text("Are you sure you want to delete this comment? This action cannot be undone."),
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
        final res = await ApiService().deleteComment(widget.complaintId, commentId);
        final bool hasReplies = res['has_replies'] == true;
        if (mounted) {
          setState(() {
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
          });
          widget.onCommentCountChanged?.call(
            _comments.where((c) => c['is_deleted'] != true).length,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Comment deleted."),
              backgroundColor: Color(0xFF4338CA),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete comment: $e"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build quick lookup for parent id of every comment to resolve root threads
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

    // Organize comments into parent and replies
    final parentComments = _comments.where((c) => c['parent_comment_id'] == null).toList();
    final allReplies = _comments.where((c) => c['parent_comment_id'] != null).toList();

    // Map root parent ID -> list of replies
    final Map<int, List<Map<String, dynamic>>> repliesMap = {};
    for (final reply in allReplies) {
      final rootId = getRootParentId(reply['id'] as int? ?? 0);
      repliesMap.putIfAbsent(rootId, () => []).add(reply);
    }

    // Limit initial display to 2 parent comments unless _showAll is true
    final displayedParents = _showAll ? parentComments : parentComments.take(2).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. REACTION / REPLYING BANNER
          if (_replyingTo != null) _buildReplyingBanner(),

          // 2. COMMENT INPUT CONTAINER
          _buildCommentInput(),

          // 2b. EMOJI PICKER STRIP
          if (_showEmojiStrip) _buildEmojiPickerStrip(),

          // 2c. SELECTED IMAGE PREVIEW
          if (_selectedImage != null) _buildImagePreview(),

          const SizedBox(height: 18),

          // 3. COMMENTS LIST
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    TextButton(
                      onPressed: _fetchComments,
                      child: const Text("Retry", style: TextStyle(color: Color(0xFF4338CA))),
                    ),
                  ],
                ),
              ),
            )
          else if (parentComments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  "No comments yet. Start the conversation!",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else ...[
            // Render comments hierarchy
            for (int i = 0; i < displayedParents.length; i++) ...[
              _buildParentCommentWithReplies(
                displayedParents[i],
                repliesMap[displayedParents[i]['id'] as int? ?? 0] ?? [],
              ),
              if (i < displayedParents.length - 1) const SizedBox(height: 16),
            ],

            const SizedBox(height: 14),

            // 4. "Show all comments." ACTION BUTTON
            GestureDetector(
              onTap: () {
                if (widget.onShowAllPressed != null) {
                  widget.onShowAllPressed!();
                } else {
                  setState(() {
                    _showAll = !_showAll;
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  _showAll ? "Show fewer comments." : "Show all comments.",
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Banner shown when replying to a specific comment
  Widget _buildReplyingBanner() {
    final targetName = _replyingTo?['user_name'] ?? 'User';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 14, color: Color(0xFF4338CA)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Replying to @$targetName",
              style: const TextStyle(
                color: Color(0xFF4338CA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  /// Main comment input row with user avatar and action buttons
  Widget _buildCommentInput() {
    final initials = _getCurrentUserInitials();
    final avatarColors = _getAvatarColors(initials);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left User Avatar (e.g. MK in purple circle)
        Container(
          width: 36,
          height: 36,
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
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Rounded Comment Input Field Container
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Text Input
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: const InputDecoration(
                      hintText: "Add a comment..",
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),

                // '@' Mention Action Button
                IconButton(
                  icon: const Icon(
                    Icons.alternate_email,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: "Mention",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: _handleMentionClick,
                ),

                // '😊' Emoji Action Button
                IconButton(
                  icon: Icon(
                    Icons.sentiment_satisfied_outlined,
                    size: 18,
                    color: _showEmojiStrip ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                  ),
                  tooltip: "Emoji",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: () {
                    setState(() {
                      _showEmojiStrip = !_showEmojiStrip;
                    });
                  },
                ),

                // '🖼' Image Attachment Action Button
                IconButton(
                  icon: Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: _selectedImage != null ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                  ),
                  tooltip: "Attach image",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 16,
                  onPressed: _handlePickImage,
                ),

                // Submit Send Button
                if (_isSubmitting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: Color(0xFF4338CA),
                    ),
                    tooltip: "Send",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 16,
                    onPressed: _submitComment,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quick emoji strip below input
  Widget _buildEmojiPickerStrip() {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        children: _quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () => _handleEmojiInsert(emoji),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Preview thumbnail for image attachment
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 46),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: kIsWeb
                ? Image.network(
                    _selectedImage!.path,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(_selectedImage!.path),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 8),
          const Text(
            "Photo attached",
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              setState(() {
                _selectedImage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Parent comment and its nested replies connected via tree branch
  Widget _buildParentCommentWithReplies(
    Map<String, dynamic> parent,
    List<Map<String, dynamic>> replies,
  ) {
    final parentId = parent['id'] as int? ?? 0;
    final initials = (parent['user_initials'] ?? 'LG').toString();
    final authorName = (parent['user_name'] ?? parent['username'] ?? 'Lisa Godwin').toString();
    final timestamp = _formatTimestamp(parent['created_at']);
    final commentText = (parent['comment'] ?? parent['content'] ?? '').toString();

    final isCollapsed = _collapsedParentIds.contains(parentId);
    final hasReplies = replies.isNotEmpty;
    final isDeleted = parent['is_deleted'] == true;

    // Upvote calculation
    final userVote = _userVotes[parentId] ?? 0;
    final baseVotes = (parentId == 3 || parentId == 101) ? 11 : 0;
    final votesDisplay = (baseVotes + userVote).clamp(0, 999);

    final avatarColors = _getAvatarColors(initials);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PARENT COMMENT CARD
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (e.g. LG in Lime Green)
            Container(
              width: 32,
              height: 32,
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
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Name & Timestamp
                  Row(
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Comment Body (RichText supporting @mentions, or deleted placeholder)
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
                    _buildFormattedCommentText(commentText),

                  const SizedBox(height: 6),

                  // Voting & Reply Toolbar (▲ 11 ▼  💬 1  Delete)
                  if (!isDeleted)
                    Row(
                      children: [
                        // Collapse control placeholder / icon if has replies
                        if (hasReplies)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isCollapsed) {
                                  _collapsedParentIds.remove(parentId);
                                } else {
                                  _collapsedParentIds.add(parentId);
                                }
                              });
                            },
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
                          onTap: () {
                            setState(() {
                              if (_userVotes[parentId] == 1) {
                                _userVotes[parentId] = 0;
                              } else {
                                _userVotes[parentId] = 1;
                              }
                            });
                          },
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
                          onTap: () {
                            setState(() {
                              if (_userVotes[parentId] == -1) {
                                _userVotes[parentId] = 0;
                              } else {
                                _userVotes[parentId] = -1;
                              }
                            });
                          },
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: userVote == -1 ? Colors.redAccent : const Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Reply icon & count
                        GestureDetector(
                          onTap: () => _startReply(parent),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                size: 12.5,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${replies.length}",
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

                        // Delete button for comment author
                        if (_isCurrentUserCommentAuthor(parent)) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _confirmDeleteComment(parent),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 13,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  "Delete",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600,
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
          ],
        ),

        // NESTED REPLIES WITH TREE BRANCH CONNECTOR
        if (hasReplies && !isCollapsed) ...[
          for (int j = 0; j < replies.length; j++) ...[
            _buildNestedReplyItem(replies[j], isLast: j == replies.length - 1),
          ],
        ],
      ],
    );
  }

  /// Nested reply item indented underneath parent with branch curve
  Widget _buildNestedReplyItem(Map<String, dynamic> reply, {required bool isLast}) {
    final initials = (reply['user_initials'] ?? 'RG').toString();
    final authorName = (reply['user_name'] ?? reply['username'] ?? 'Ramya Govindhan').toString();
    final timestamp = _formatTimestamp(reply['created_at']);
    final commentText = (reply['comment'] ?? reply['content'] ?? '').toString();

    final avatarColors = _getAvatarColors(initials);

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // L-shaped connector branch curve
          CustomPaint(
            size: const Size(20, 36),
            painter: _TreeBranchPainter(),
          ),
          const SizedBox(width: 4),

          // Reply Author Avatar (e.g. RG in Light Sky Blue)
          Container(
            width: 26,
            height: 26,
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
                fontSize: 10.5,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reply Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Timestamp
                Row(
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Reply text (or deleted placeholder)
                if (reply['is_deleted'] == true)
                  const Text(
                    "This comment was deleted",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  _buildFormattedCommentText(commentText),

                const SizedBox(height: 4),

                if (reply['is_deleted'] != true)
                  Row(
                    children: [
                      // Quick reply action
                      GestureDetector(
                        onTap: () => _startReply(reply),
                        child: const Text(
                          "Reply",
                          style: TextStyle(
                            color: Color(0xFF4338CA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Delete button for reply author
                      if (_isCurrentUserCommentAuthor(reply)) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _confirmDeleteComment(reply),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 12,
                                color: Color(0xFFEF4444),
                              ),
                              SizedBox(width: 2),
                              Text(
                                "Delete",
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  /// Parses text to highlight @mentions in accent blue/purple
  Widget _buildFormattedCommentText(String text) {
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
}

/// Custom painter for the L-shaped connector tree branch
class _TreeBranchPainter extends CustomPainter {
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
