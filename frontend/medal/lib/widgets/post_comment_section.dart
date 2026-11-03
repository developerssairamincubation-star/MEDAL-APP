// lib/widgets/post_comment_section.dart
// Production-quality, reusable comment interaction & display widget matching the reference UI.

import 'package:medal/widgets/medal_dialog.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/widgets/comments_controller.dart';

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

  late ComplaintCommentsController _controller;
  bool _isSubmitting = false;

  // Active reply target: {'id': int, 'user_name': String}
  Map<String, dynamic>? _replyingTo;

  // Selected image attachment
  XFile? _selectedImage;

  // Emoji picker strip visibility
  bool _showEmojiStrip = false;

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
    _controller = ComplaintCommentsController.forComplaint(widget.complaintId);
    _controller.addListener(_handleControllerUpdate);
    _controller.fetchComments();
  }

  @override
  void didUpdateWidget(covariant PostCommentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.complaintId != widget.complaintId) {
      _controller.removeListener(_handleControllerUpdate);
      _controller = ComplaintCommentsController.forComplaint(widget.complaintId);
      _controller.addListener(_handleControllerUpdate);
      _controller.fetchComments();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (mounted) {
      setState(() {});
      if (_controller.hasFetched) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onCommentCountChanged?.call(_controller.activeCommentCount);
          }
        });
      }
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
      String? imageUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageUrl = await ApiService().uploadEvidence(
          fileBytes: bytes,
          filename: _selectedImage!.name,
          mimeType: _selectedImage!.mimeType,
        );
      }

      final parentId = _replyingTo != null ? (_replyingTo!['id'] as int?) : null;
      await _controller.addComment(
        content.isNotEmpty ? content : "[Photo]",
        parentCommentId: parentId,
        imageUrl: imageUrl,
      );

      _textController.clear();
      if (mounted) {
        setState(() {
          _showAll = true;
          _replyingTo = null;
          _selectedImage = null;
          _showEmojiStrip = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parentId != null ? "Reply posted!" : "Comment posted!"),
            backgroundColor: const Color(0xFF0467B6),
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

  Future<void> _confirmDeleteComment(Map<String, dynamic> comment) async {
    final commentId = comment['id'] as int?;
    if (commentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MedalAlertDialog(
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
        await _controller.deleteComment(commentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Comment deleted."),
              backgroundColor: Color(0xFF0467B6),
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
    final rootNodes = _controller.getThreadedTree();

    // Limit initial display to 2 parent comments unless _showAll is true
    final displayedNodes = _showAll ? rootNodes : rootNodes.take(2).toList();

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
          if (_controller.isLoading && _controller.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0467B6),
                  ),
                ),
              ),
            )
          else if (_controller.errorMessage != null && _controller.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      _controller.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () => _controller.fetchComments(forceRefresh: true),
                      child: const Text("Retry", style: TextStyle(color: Color(0xFF0467B6))),
                    ),
                  ],
                ),
              ),
            )
          else if (rootNodes.isEmpty)
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
            // Render comments hierarchy with ThreadedCommentNodeWidget
            for (int i = 0; i < displayedNodes.length; i++) ...[
              ThreadedCommentNodeWidget(
                node: displayedNodes[i],
                controller: _controller,
                onReply: _startReply,
                onDelete: _confirmDeleteComment,
              ),
              if (i < displayedNodes.length - 1) const SizedBox(height: 16),
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
    final targetName = _replyingTo?['user_name'] ?? _replyingTo?['username'] ?? 'User';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 14, color: Color(0xFF0467B6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Replying to @$targetName",
              style: const TextStyle(
                color: Color(0xFF0467B6),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left User Avatar (profile photo or initials fallback)
        buildCommentAvatarWidget(
          initials: getCurrentUserInitials(),
          size: 36,
          profileImageUrl: ApiService().currentUser?['profile_image_url']?.toString(),
          userId: ApiService().currentUser?['id'],
          fontSize: 13,
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
                    color: _showEmojiStrip ? const Color(0xFF0467B6) : const Color(0xFF94A3B8),
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
                    color: _selectedImage != null ? const Color(0xFF0467B6) : const Color(0xFF94A3B8),
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
                        color: Color(0xFF0467B6),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: Color(0xFF0467B6),
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
}
