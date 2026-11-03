// lib/modules/authority/screens/dashboard/authority_comment_thread_screen.dart
// Dedicated individual comment thread screen matching Screenshot 3.
// Displays the selected parent comment, its attached photo, authorities assigned,
// reply composer, and exclusively its direct thread replies.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import 'authority_main_screen.dart';
import '../../../../widgets/medal_logo.dart';
import '../../widgets/authority_nav_item.dart';

class AuthorityCommentThreadScreen extends StatefulWidget {
  final int complaintId;
  final Map<String, dynamic> commentData;
  final Map<String, dynamic>? parentComplaint;

  const AuthorityCommentThreadScreen({
    super.key,
    required this.complaintId,
    required this.commentData,
    this.parentComplaint,
  });

  @override
  State<AuthorityCommentThreadScreen> createState() =>
      _AuthorityCommentThreadScreenState();
}

class _AuthorityCommentThreadScreenState
    extends State<AuthorityCommentThreadScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;
  bool _isSubmitting = false;

  // Selected comment state
  late int _upvotes;
  late int _commentsCount;
  late int _repostsCount;
  bool _isUpvoted = false;
  bool _isReposted = false;

  // Local thread replies matching Screenshot 3
  late List<Map<String, dynamic>> _replies;

  // Reply engagement states: id -> state
  final Map<int, int> _replyUpvotes = {};
  final Map<int, int> _replyDownvotes = {};
  final Map<int, int> _replyUserVote = {}; // 1, -1, 0
  final Map<int, bool> _replyLiked = {};

  @override
  void initState() {
    super.initState();
    _upvotes = widget.commentData['upvotes_count'] as int? ?? 124;
    _commentsCount = widget.commentData['replies_count'] as int? ?? 12;
    _repostsCount = widget.commentData['reposts_count'] as int? ?? 24;

    _initializeReplies();
  }

  void _initializeReplies() {
    // Populate direct replies matching Screenshot 3
    final initialList = widget.commentData['replies_list'] as List<dynamic>?;
    if (initialList != null && initialList.isNotEmpty) {
      _replies = List<Map<String, dynamic>>.from(initialList);
    } else {
      _replies = [
        {
          'id': 301,
          'author': 'Chia Sen',
          'initials': 'CS',
          'time': '2 mins ago',
          'text':
              'This issue needs immediate attention. We should take steps to resolve it before it causes more inconvenience to the people living nearby.',
          'upvotes': 11,
          'downvotes': 2,
          'replies': 0,
          'avatar_color': const Color(0xFF5EEAD4),
          'avatar_text_color': const Color(0xFF0F766E),
        },
        {
          'id': 302,
          'author': 'Steve Mark',
          'initials': 'SM',
          'time': '7 mins ago',
          'text':
              'We need a permanent solution rather than a temporary fix. Please ensure regular monitoring so that this issue does not happen again.',
          'upvotes': 11,
          'downvotes': 2,
          'replies': 1,
          'avatar_color': const Color(0xFF86EFAC),
          'avatar_text_color': const Color(0xFF15803D),
        },
        {
          'id': 303,
          'author': 'Liya Fatima',
          'initials': 'LF',
          'time': '10 mins ago',
          'text':
              'Thank you for bringing this issue to everyone\'s attention. I support this complaint and request the local authorities to take prompt action.',
          'upvotes': 11,
          'downvotes': 2,
          'replies': 0,
          'avatar_color': const Color(0xFFF87171),
          'avatar_text_color': Colors.white,
        },
      ];
    }

    for (final reply in _replies) {
      final id = reply['id'] as int? ?? 0;
      _replyUpvotes[id] = reply['upvotes'] as int? ?? 11;
      _replyDownvotes[id] = reply['downvotes'] as int? ?? 2;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not select image: $e')));
    }
  }

  void _handleMentionClick() {
    final text = _replyController.text;
    final newText = text.isEmpty || text.endsWith(' ') ? '$text@' : '$text @';
    _replyController.text = newText;
    _replyController.selection = TextSelection.fromPosition(
      TextPosition(offset: _replyController.text.length),
    );
    _replyFocusNode.requestFocus();
  }

  void _handleEmojiInsert() {
    final text = _replyController.text;
    _replyController.text = '$text👍 ';
    _replyController.selection = TextSelection.fromPosition(
      TextPosition(offset: _replyController.text.length),
    );
    _replyFocusNode.requestFocus();
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final commentId = widget.commentData['id'] as int? ?? 1002;
    final hadImage = _selectedImage != null;

    try {
      String? uploadedImageUrl;
      if (hadImage) {
        try {
          final bytes = await _selectedImage!.readAsBytes();
          uploadedImageUrl = await ApiService().uploadEvidence(
            fileBytes: bytes,
            filename: _selectedImage!.name,
            mimeType: _selectedImage!.mimeType,
          );
        } catch (_) {
          // Fallback for offline/mock development
        }
      }

      // Attempt backend API call if reachable
      try {
        await ApiService().addComment(
          widget.complaintId,
          content.isNotEmpty ? content : '[Photo]',
          parentCommentId: commentId,
          imageUrl: uploadedImageUrl,
        );
      } catch (_) {
        // Fallback for offline/mock development
      }

      // Add to local thread replies list
      final currentUser = ApiService().currentUser;
      final currentUserName = (currentUser?['full_name'] ?? 'Officer')
          .toString();
      final currentUserProfile = currentUser?['profile_image_url'] as String?;
      final newReply = {
        'id': DateTime.now().millisecondsSinceEpoch % 100000,
        'author': currentUserName,
        'initials': currentUserName.isNotEmpty
            ? currentUserName[0].toUpperCase()
            : 'O',
        'profile_image_url': currentUserProfile,
        'time': 'just now',
        'text': content.isNotEmpty ? content : '[Photo Attachment]',
        'upvotes': 0,
        'downvotes': 0,
        'replies': 0,
        'avatar_color': const Color(0xFFDBEAFE),
        'avatar_text_color': const Color(0xFF1D4ED8),
        'local_image': hadImage ? _selectedImage : null,
        'image_url': uploadedImageUrl,
        'image': uploadedImageUrl ?? (hadImage ? _selectedImage?.path : null),
      };

      setState(() {
        _replies.insert(0, newReply);
        _commentsCount++;
        _replyController.clear();
        _selectedImage = null;
        _isSubmitting = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted!'),
          backgroundColor: Color(0xFF0467B6),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post reply: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _toggleVote(int replyId, int vote) {
    setState(() {
      final currentVote = _replyUserVote[replyId] ?? 0;
      if (currentVote == vote) {
        _replyUserVote[replyId] = 0;
        if (vote == 1) {
          _replyUpvotes[replyId] = (_replyUpvotes[replyId] ?? 11) - 1;
        } else {
          _replyDownvotes[replyId] = (_replyDownvotes[replyId] ?? 2) - 1;
        }
      } else {
        if (currentVote == 1) {
          _replyUpvotes[replyId] = (_replyUpvotes[replyId] ?? 11) - 1;
        } else if (currentVote == -1) {
          _replyDownvotes[replyId] = (_replyDownvotes[replyId] ?? 2) - 1;
        }

        _replyUserVote[replyId] = vote;
        if (vote == 1) {
          _replyUpvotes[replyId] = (_replyUpvotes[replyId] ?? 11) + 1;
        } else {
          _replyDownvotes[replyId] = (_replyDownvotes[replyId] ?? 2) + 1;
        }
      }
    });
  }

  void _toggleLike(int replyId) {
    setState(() {
      _replyLiked[replyId] = !(_replyLiked[replyId] ?? false);
    });
  }

  Widget _buildRichText(String text, {double fontSize = 12.5}) {
    final words = text.split(' ');
    final List<InlineSpan> spans = [];

    for (final word in words) {
      if (word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: GoogleFonts.inter(
              color: const Color(0xFF0467B6),
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: GoogleFonts.inter(
              color: const Color(0xFF0F172A),
              fontSize: fontSize,
              height: 1.4,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final authorName =
        widget.commentData['author'] ??
        widget.commentData['user_name'] ??
        'Kevin Xanty';
    final authorInitials = widget.commentData['initials'] ?? 'KX';
    final timeAgo = widget.commentData['time'] ?? '10 mins ago';
    final commentText =
        widget.commentData['text'] ??
        widget.commentData['comment'] ??
        'Yes , i too have seen this issue and reported it a immediate action would be perfect.';
    final authorities =
        widget.commentData['authorities'] as List<String>? ??
        ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen'];
    final imageAsset =
        widget.commentData['image_url'] as String? ??
        widget.commentData['image'] as String? ??
        'assets/images/sample_trash_overflow.jpg';
    final location =
        widget.parentComplaint?['location'] ?? 'Bharathiyar street';
    final sdgAlignment = widget.parentComplaint?['sdg_alignment'] ?? 'SDG 13';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Header
            _buildTopHeader(),

            // Vertically scrollable Thread Page
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 10.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Selected Parent Comment Card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Author Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final rawUrl =
                                          widget.commentData['profile_image_url']
                                              as String?;
                                      final resolvedUrl =
                                          (rawUrl != null &&
                                              rawUrl.trim().isNotEmpty)
                                          ? ApiService().resolveImageUrl(
                                              rawUrl.trim(),
                                            )
                                          : null;
                                      Widget fallback() => CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(
                                          0xFF86EFAC,
                                        ),
                                        child: Text(
                                          authorInitials,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      );

                                      if (resolvedUrl != null &&
                                          resolvedUrl.isNotEmpty) {
                                        return ClipOval(
                                          child: Image.network(
                                            resolvedUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    fallback(),
                                          ),
                                        );
                                      }
                                      return fallback();
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authorName,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111C2D),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '$timeAgo • ',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.public,
                                            size: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Comment Text
                              Text(
                                commentText,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF1E293B),
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Authorities assigned section
                              Text(
                                'Authorities assigned:',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 3),
                              ...authorities.map(
                                (auth) => Text(
                                  auth,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0467B6),
                                    height: 1.35,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Attached Photo (Overflowing trash bins or uploaded photo)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildAttachmentWidget(
                                  imageAsset,
                                  height: 180,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Location and SDG Badge Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 15,
                                        color: Color(0xFF0467B6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        location,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0467B6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE4E6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.eco_outlined,
                                          size: 12,
                                          color: Color(0xFFBE123C),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          sdgAlignment,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFBE123C),
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

                        // Action Bar Row (Upvote | Comment | Repost)
                        _buildActionRow(),

                        // 2. Inline Reply Composer
                        _buildReplyComposer(),

                        // 3. Thread Replies Header & Items
                        ..._buildRepliesList(),

                        // "Show all comments." footer link
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text(
                            'Show all comments.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar matching Authority shell
            _buildBottomNavigationBar(),
          ],
        ),
      ),
    );
  }

  /// Top navigation header matching MEDAL shell with back support
  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MedalLogo(iconSize: 18),
              const SizedBox(width: 6),
              Text(
                'MEdAL',
                style: GoogleFonts.inter(
                  color: const Color(0xFF111C2D),
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Horizontal Action Bar: Upvote | Comment | Repost
  Widget _buildActionRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // 1. Upvote
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isUpvoted = !_isUpvoted;
                  _upvotes += _isUpvoted ? 1 : -1;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'Upvote ($_upvotes)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: _isUpvoted
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: const Color(0xFF0467B6),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Divider
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

          // 2. Comment
          Expanded(
            child: InkWell(
              onTap: () => _replyFocusNode.requestFocus(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'Comment ($_commentsCount)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5D6478),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Divider
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

          // 3. Repost
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isReposted = !_isReposted;
                  _repostsCount += _isReposted ? 1 : -1;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'Repost($_repostsCount)',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _isReposted
                          ? const Color(0xFF0467B6)
                          : const Color(0xFF5D6478),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline reply composer with avatar, mention, emoji, and image picker
  Widget _buildReplyComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User avatar with profile photo or initials
              Builder(
                builder: (context) {
                  final user = ApiService().currentUser;
                  final rawUrl = user?['profile_image_url'] as String?;
                  final resolvedUrl =
                      (rawUrl != null && rawUrl.trim().isNotEmpty)
                      ? ApiService().resolveImageUrl(rawUrl.trim())
                      : null;
                  final userName = (user?['full_name'] ?? 'Officer').toString();
                  final userInitials = userName.isNotEmpty
                      ? userName[0].toUpperCase()
                      : 'O';

                  Widget fallback() => CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Text(
                      userInitials,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0467B6),
                      ),
                    ),
                  );

                  if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                    return ClipOval(
                      child: Image.network(
                        resolvedUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            fallback(),
                      ),
                    );
                  }
                  return fallback();
                },
              ),
              const SizedBox(width: 10),

              // Input field container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          focusNode: _replyFocusNode,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a comment..',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _submitReply(),
                        ),
                      ),
                      // Mention icon
                      InkWell(
                        onTap: _handleMentionClick,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(
                            Icons.alternate_email_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      // Emoji icon
                      InkWell(
                        onTap: _handleEmojiInsert,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            size: 17,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      // Image picker icon
                      InkWell(
                        onTap: _handlePickImage,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(
                            Icons.crop_original_outlined,
                            size: 17,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      // Submit button
                      if (_isSubmitting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        InkWell(
                          onTap: _submitReply,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                              color: Color(0xFF0467B6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Selected image preview chip
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 42),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      size: 14,
                      color: Color(0xFF0467B6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Photo attached',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0467B6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _selectedImage = null),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Thread replies list (exclusively direct replies to this comment thread)
  List<Widget> _buildRepliesList() {
    final List<Widget> widgets = [];

    for (int i = 0; i < _replies.length; i++) {
      final reply = _replies[i];
      final id = reply['id'] as int? ?? i;
      final author = reply['author']?.toString() ?? 'User';
      final initials = reply['initials']?.toString() ?? 'U';
      final time = reply['time']?.toString() ?? 'just now';
      final text = reply['text']?.toString() ?? '';
      final upvotes = _replyUpvotes[id] ?? (reply['upvotes'] as int? ?? 11);
      final downvotes =
          _replyDownvotes[id] ?? (reply['downvotes'] as int? ?? 2);
      final repliesCount = reply['replies'] as int? ?? 0;
      final isLiked = _replyLiked[id] ?? false;
      final userVote = _replyUserVote[id] ?? 0;
      final avatarBg =
          reply['avatar_color'] as Color? ?? const Color(0xFFE2E8F0);
      final avatarTextColor =
          reply['avatar_text_color'] as Color? ?? const Color(0xFF1E293B);
      final localImage = reply['local_image'] as XFile?;

      widgets.add(
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      );

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply Author Header
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final rawUrl = reply['profile_image_url'] as String?;
                      final resolvedUrl =
                          (rawUrl != null && rawUrl.trim().isNotEmpty)
                          ? ApiService().resolveImageUrl(rawUrl.trim())
                          : null;
                      Widget fallback() => CircleAvatar(
                        radius: 17,
                        backgroundColor: avatarBg,
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: avatarTextColor,
                          ),
                        ),
                      );

                      if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                        return ClipOval(
                          child: Image.network(
                            resolvedUrl,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                fallback(),
                          ),
                        );
                      }
                      return fallback();
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    author,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '•  $time',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Reply Text
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: _buildRichText(text),
              ),

              // Image attachment preview if present
              if (reply['image_url'] != null ||
                  reply['image'] != null ||
                  localImage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 44, top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildAttachmentWidget(
                      (reply['image_url'] ?? reply['image'] ?? localImage?.path)
                          .toString(),
                      height: 120,
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // Engagement Row (Upvote, Downvote, Reply, Heart, Share)
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Row(
                  children: [
                    // Upvote
                    InkWell(
                      onTap: () => _toggleVote(id, 1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_drop_up_rounded,
                            size: 20,
                            color: userVote == 1
                                ? const Color(0xFF0467B6)
                                : const Color(0xFF64748B),
                          ),
                          Text(
                            '$upvotes',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: userVote == 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: userVote == 1
                                  ? const Color(0xFF0467B6)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Downvote
                    InkWell(
                      onTap: () => _toggleVote(id, -1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: userVote == -1
                                ? Colors.redAccent
                                : const Color(0xFF64748B),
                          ),
                          Text(
                            '$downvotes',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: userVote == -1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: userVote == -1
                                  ? Colors.redAccent
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Reply Icon
                    InkWell(
                      onTap: () {
                        _replyController.text =
                            '@${author.replaceAll(' ', '')} ';
                        _replyFocusNode.requestFocus();
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          if (repliesCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$repliesCount',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Heart Like
                    InkWell(
                      onTap: () => _toggleLike(id),
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 14.5,
                        color: isLiked
                            ? Colors.redAccent
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Share
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.file_upload_outlined,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  /// Bottom navigation bar matching Authority shell
  Widget _buildBottomNavigationBar() {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavItem(
              index: 0,
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 1,
              icon: Icons.article_outlined,
              label: 'My Complaint',
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 2,
              icon: Icons.groups_outlined,
              label: 'Academy',
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 3,
              icon: Icons.person_rounded,
              label: 'Profile',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isDashboard = index == 0;

    return AuthorityNavItem(
      icon: icon,
      label: label,
      isSelected: isDashboard,
      onTap: () {
        if (isDashboard) {
          // Return all the way to Dashboard
          Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => AuthorityMainScreen(initialIndex: index),
            ),
            (route) => route.isFirst,
          );
        }
      },
    );
  }

  Widget _buildAttachmentWidget(String rawPath, {double height = 140}) {
    final trimmed = rawPath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        ApiService().resolveImageUrl(trimmed),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0467B6),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: height > 40 ? height - 20 : height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    } else if (!kIsWeb && File(trimmed).existsSync()) {
      return Image.file(
        File(trimmed),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height > 40 ? height - 20 : height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    } else {
      return Image.asset(
        trimmed,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height > 40 ? height - 20 : height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      );
    }
  }
}
