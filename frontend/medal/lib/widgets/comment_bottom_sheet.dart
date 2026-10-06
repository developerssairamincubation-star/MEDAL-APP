// lib/widgets/comment_bottom_sheet.dart
// Production-quality, reusable comments bottom sheet matching the inline comment UI reference.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/widgets/comments_controller.dart';

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
  final ImagePicker _imagePicker = ImagePicker();

  late ComplaintCommentsController _controller;
  bool _isSubmitting = false;

  // Active reply target comment
  Map<String, dynamic>? _replyTarget;

  // Selected image attachment
  XFile? _selectedImage;

  // Emoji picker strip visibility
  bool _showEmojiStrip = false;

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
    _commentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant CommentBottomSheet oldWidget) {
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
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    _scrollController.dispose();
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
    final text = _commentController.text;
    final newText = text.isEmpty || text.endsWith(" ") ? "$text@" : "$text @";
    _commentController.text = newText;
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _focusNode.requestFocus();
  }

  void _handleEmojiInsert(String emoji) {
    final text = _commentController.text;
    _commentController.text = "$text$emoji ";
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final parentId = _replyTarget != null ? (_replyTarget!['id'] as int?) : null;

      await _controller.addComment(
        text.isNotEmpty ? text : "[Image Attachment]",
        parentCommentId: parentId,
      );

      _commentController.clear();

      if (mounted) {
        setState(() {
          _replyTarget = null;
          _selectedImage = null;
          _showEmojiStrip = false;
          _isSubmitting = false;
        });

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
            content: Text("Failed to post: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleReplyTo(Map<String, dynamic> target) {
    setState(() {
      _replyTarget = target;
      final author = (target['user_name'] ?? target['username'] ?? 'User').toString();
      final mention = "@${author.replaceAll(' ', '')} ";
      if (!_commentController.text.contains(mention.trim())) {
        _commentController.text = "$mention${_commentController.text}".trim();
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

  void _cancelReply() {
    setState(() {
      _replyTarget = null;
      _commentController.clear();
    });
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
        await _controller.deleteComment(commentId);
        if (mounted) {
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
    final rootNodes = _controller.getThreadedTree();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle pill
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Row: Comments (N) and Close button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Comments (${_controller.activeCommentCount})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Comments List
          Expanded(
            child: _controller.isLoading && _controller.comments.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  )
                : _controller.errorMessage != null && _controller.comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _controller.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                            TextButton(
                              onPressed: () => _controller.fetchComments(forceRefresh: true),
                              child: const Text("Retry", style: TextStyle(color: Color(0xFF4338CA))),
                            ),
                          ],
                        ),
                      )
                    : rootNodes.isEmpty
                        ? const Center(
                            child: Text(
                              "No comments yet. Start the conversation!",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: rootNodes.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (ctx, index) {
                              return ThreadedCommentNodeWidget(
                                node: rootNodes[index],
                                controller: _controller,
                                onReply: _handleReplyTo,
                                onDelete: _confirmDeleteComment,
                              );
                            },
                          ),
          ),

          // Pinned Bottom Input Area with keyboard padding and SafeArea
          _buildBottomInputArea(),
        ],
      ),
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replying banner
          if (_replyTarget != null) _buildReplyingBanner(),

          // Emoji picker strip
          if (_showEmojiStrip) _buildEmojiPickerStrip(),

          // Image preview
          if (_selectedImage != null) _buildImagePreview(),

          // Input Row matching reference design
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User Avatar
              buildCommentAvatarWidget(
                initials: getCurrentUserInitials(),
                size: 36,
                profileImageUrl: ApiService().currentUser?['profile_image_url']?.toString(),
                userId: ApiService().currentUser?['id'],
                fontSize: 13,
              ),
              const SizedBox(width: 10),

              // Rounded Input container
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
                      // Text Field
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: _replyTarget != null ? "Write a reply..." : "Write a comment...",
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _handleSubmitComment(),
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

                      // Send Button with Icons.send_rounded
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
                            Icons.send_rounded,
                            size: 18,
                            color: Color(0xFF4338CA),
                          ),
                          tooltip: "Send",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          splashRadius: 16,
                          onPressed: _handleSubmitComment,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyingBanner() {
    final targetName = _replyTarget?['user_name'] ?? _replyTarget?['username'] ?? 'User';
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

  Widget _buildEmojiPickerStrip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 46),
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

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 46),
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
