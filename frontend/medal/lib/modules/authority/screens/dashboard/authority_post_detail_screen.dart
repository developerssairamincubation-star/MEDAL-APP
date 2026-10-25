// lib/modules/authority/screens/dashboard/authority_post_detail_screen.dart
// Social Post Details screen matching Screenshot 2.
// Displays the full complaint post, assigned authorities, full post image,
// location & SDG badge, social action row, inline comment composer,
// and all comments visible in the same vertically scrollable container.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../notifications/authority_notifications_screen.dart';
import 'authority_comment_thread_screen.dart';
import 'authority_main_screen.dart';

class AuthorityPostDetailScreen extends StatefulWidget {
  final int? complaintId;
  final Map<String, dynamic>? complaintData;
  final bool autoFocusComment;

  const AuthorityPostDetailScreen({
    super.key,
    this.complaintId,
    this.complaintData,
    this.autoFocusComment = false,
  });

  @override
  State<AuthorityPostDetailScreen> createState() =>
      _AuthorityPostDetailScreenState();
}

class _AuthorityPostDetailScreenState extends State<AuthorityPostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;
  bool _isSubmitting = false;

  // Post engagement counters
  late int _upvotes;
  late int _commentsCount;
  late int _repostsCount;
  bool _isUpvoted = false;
  bool _isReposted = false;

  // Root comments list
  late List<Map<String, dynamic>> _comments;

  // Engagement tracking per comment: commentId -> value
  final Map<int, int> _commentUpvotes = {};
  final Map<int, int> _commentDownvotes = {};
  final Map<int, int> _commentUserVotes = {};
  final Map<int, bool> _commentLiked = {};

  @override
  void initState() {
    super.initState();
    final data = widget.complaintData ?? {};
    _upvotes = data['upvotes_count'] as int? ?? 124;
    _commentsCount = data['comments_count'] as int? ?? 12;
    _repostsCount = data['reposts_count'] as int? ?? 24;

    _initializeComments();

    if (widget.autoFocusComment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _commentFocusNode.requestFocus();
        }
      });
    }
  }

  void _initializeComments() {
    _comments = [
      {
        'id': 1001,
        'author': 'Lisa Godwin',
        'initials': 'LG',
        'time': '24m ago',
        'text':
            'Yes, it have come to our observation that this issue has been a big concern and it is really bothering the thought of health. @RamyaGovindhan please take action.',
        'upvotes': 11,
        'downvotes': 2,
        'replies': 1,
        'avatar_color': const Color(0xFFFEF08A),
        'avatar_text_color': const Color(0xFF854D0E),
        'image': null,
        'authorities': ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen'],
        'replies_list': <Map<String, dynamic>>[],
      },
      {
        'id': 1002,
        'author': 'Kevin Xanty',
        'initials': 'KX',
        'time': '10m ago',
        'text':
            'Yes , i too have seen this issue and reported it a immediate action would be perfect.',
        'upvotes': 11,
        'downvotes': 2,
        'replies': 3,
        'avatar_color': const Color(0xFF86EFAC),
        'avatar_text_color': const Color(0xFF15803D),
        'image': 'assets/images/sample_trash_overflow.jpg',
        'authorities': ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen'],
        'replies_list': [
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
        ],
      },
      {
        'id': 1003,
        'author': 'Divya ken',
        'initials': 'DK',
        'time': '10m ago',
        'text':
            'If the issue is resolved immediately, it would be great help for the community here',
        'upvotes': 11,
        'downvotes': 2,
        'replies': 1,
        'avatar_color': const Color(0xFFF87171),
        'avatar_text_color': Colors.white,
        'image': null,
        'authorities': ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen'],
        'replies_list': <Map<String, dynamic>>[],
      },
    ];

    for (final c in _comments) {
      final id = c['id'] as int? ?? 0;
      _commentUpvotes[id] = c['upvotes'] as int? ?? 11;
      _commentDownvotes[id] = c['downvotes'] as int? ?? 2;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $e')),
      );
    }
  }

  void _handleMentionClick() {
    final text = _commentController.text;
    final newText = text.isEmpty || text.endsWith(' ') ? '$text@' : '$text @';
    _commentController.text = newText;
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _commentFocusNode.requestFocus();
  }

  void _handleEmojiInsert() {
    final text = _commentController.text;
    _commentController.text = '$text👍 ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _commentFocusNode.requestFocus();
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final complaintId = widget.complaintId ??
        widget.complaintData?['id'] as int? ??
        101;
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
          // Fallback gracefully for offline/mock development
        }
      }

      try {
        await ApiService().addComment(
          complaintId,
          content.isNotEmpty ? content : '[Photo]',
          imageUrl: uploadedImageUrl,
        );
      } catch (_) {
        // Fallback gracefully for offline/mock development
      }

      final newComment = {
        'id': DateTime.now().millisecondsSinceEpoch % 100000,
        'author': 'You',
        'initials': 'ME',
        'time': 'just now',
        'text': content.isNotEmpty ? content : '[Photo Attachment]',
        'upvotes': 0,
        'downvotes': 0,
        'replies': 0,
        'avatar_color': const Color(0xFFDBEAFE),
        'avatar_text_color': const Color(0xFF1D4ED8),
        'image': uploadedImageUrl ?? (hadImage ? _selectedImage?.path : null),
        'image_url': uploadedImageUrl,
        'authorities': ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen'],
        'replies_list': <Map<String, dynamic>>[],
      };

      setState(() {
        _comments.insert(0, newComment);
        _commentsCount++;
        _commentController.clear();
        _selectedImage = null;
        _isSubmitting = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment posted!'),
          backgroundColor: Color(0xFF0467B6),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post comment: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _navigateToThread(Map<String, dynamic> comment) {
    final complaintId = widget.complaintId ??
        widget.complaintData?['id'] as int? ??
        101;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthorityCommentThreadScreen(
          complaintId: complaintId,
          commentData: comment,
          parentComplaint: widget.complaintData,
        ),
      ),
    );
  }

  void _toggleVote(int commentId, int vote) {
    setState(() {
      final currentVote = _commentUserVotes[commentId] ?? 0;
      if (currentVote == vote) {
        _commentUserVotes[commentId] = 0;
        if (vote == 1) {
          _commentUpvotes[commentId] = (_commentUpvotes[commentId] ?? 11) - 1;
        } else {
          _commentDownvotes[commentId] =
              (_commentDownvotes[commentId] ?? 2) - 1;
        }
      } else {
        if (currentVote == 1) {
          _commentUpvotes[commentId] = (_commentUpvotes[commentId] ?? 11) - 1;
        } else if (currentVote == -1) {
          _commentDownvotes[commentId] =
              (_commentDownvotes[commentId] ?? 2) - 1;
        }

        _commentUserVotes[commentId] = vote;
        if (vote == 1) {
          _commentUpvotes[commentId] = (_commentUpvotes[commentId] ?? 11) + 1;
        } else {
          _commentDownvotes[commentId] =
              (_commentDownvotes[commentId] ?? 2) + 1;
        }
      }
    });
  }

  void _toggleLike(int commentId) {
    setState(() {
      _commentLiked[commentId] = !(_commentLiked[commentId] ?? false);
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
    final data = widget.complaintData ?? {};
    final authorName = data['citizen_name'] ?? 'James Doe';
    final authorInitials = data['citizen_initials'] ?? 'JD';
    final timeAgo = '2 hours ago';
    final description = data['description'] ??
        'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.';
    final authorities = [
      '@elenarodriguez',
      '@Jane_doe',
      '@Marcus_Chen',
    ];
    final imageAsset =
        data['image_url'] ?? 'assets/images/sample_waste_canal.jpg';
    final location = data['location'] ?? 'Bharathiyar street';
    final sdgAlignment = data['sdg_alignment'] ?? 'SDG 13';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FD),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            _buildTopHeader(),

            // Vertically scrollable post + comments container (Twitter-like)
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
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Post Header & Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Author row with status badge
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFF3E8FF),
                                    child: Text(
                                      authorInitials,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF9333EA),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
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
                                  ),
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'IN PROGRESS',
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Full complaint description
                              Text(
                                description,
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

                              // Full post image
                              if (imageAsset != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    imageAsset,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      height: 160,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 40,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
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

                        // 2. Inline Comment Composer
                        _buildCommentComposer(),

                        // 3. Comments Section (Visible in same scrollable view)
                        ..._buildCommentsList(),

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
              const Icon(
                Icons.military_tech_rounded,
                color: Color(0xFF0467B6),
                size: 26,
              ),
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
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AuthorityNotificationsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Color(0xFF475569),
                    size: 24,
                  ),
                  Positioned(
                    top: 1,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
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

  /// Action Bar (Upvote | Comment | Repost)
  Widget _buildActionRow() {
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
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
                      fontWeight:
                          _isUpvoted ? FontWeight.w700 : FontWeight.w600,
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
              onTap: () => _commentFocusNode.requestFocus(),
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

  /// Inline comment composer
  Widget _buildCommentComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Purple MK Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF3E8FF),
                child: Text(
                  'MK',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9333EA),
                  ),
                ),
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
                          controller: _commentController,
                          focusNode: _commentFocusNode,
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
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (_) => _submitComment(),
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
                          onTap: _submitComment,
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

  /// All comments visible directly below post
  List<Widget> _buildCommentsList() {
    final List<Widget> widgets = [];

    for (int i = 0; i < _comments.length; i++) {
      final comment = _comments[i];
      final id = comment['id'] as int? ?? i;
      final author = comment['author']?.toString() ?? 'User';
      final initials = comment['initials']?.toString() ?? 'U';
      final time = comment['time']?.toString() ?? 'just now';
      final text = comment['text']?.toString() ?? '';
      final upvotes =
          _commentUpvotes[id] ?? (comment['upvotes'] as int? ?? 11);
      final downvotes =
          _commentDownvotes[id] ?? (comment['downvotes'] as int? ?? 2);
      final repliesCount = comment['replies'] as int? ?? 1;
      final isLiked = _commentLiked[id] ?? false;
      final userVote = _commentUserVotes[id] ?? 0;
      final avatarBg =
          comment['avatar_color'] as Color? ?? const Color(0xFFE2E8F0);
      final avatarTextColor =
          comment['avatar_text_color'] as Color? ?? const Color(0xFF1E293B);
      final attachedImage = (comment['image_url'] ?? comment['image']) as String?;

      widgets.add(
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      );

      widgets.add(
        InkWell(
          onTap: () => _navigateToThread(comment),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment Author Header
                Row(
                  children: [
                    CircleAvatar(
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

                // Comment Text
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: _buildRichText(text),
                ),

                // Attached Photo inside comment (e.g. Kevin Xanty's comment or uploaded photo)
                if (attachedImage != null && attachedImage.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 44, top: 10, bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildCommentImage(attachedImage),
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

                      // Reply Icon (Taps into individual thread)
                      InkWell(
                        onTap: () => _navigateToThread(comment),
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
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
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

    return InkWell(
      onTap: () {
        if (isDashboard) {
          Navigator.pop(context);
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
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: isDashboard
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 21, color: const Color(0xFF0467B6)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0467B6),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 21, color: const Color(0xFF64748B)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCommentImage(String imagePath) {
    final trimmed = imagePath.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        ApiService().resolveImageUrl(trimmed),
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 140,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0467B6)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    } else if (!kIsWeb && File(trimmed).existsSync()) {
      return Image.file(
        File(trimmed),
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    } else {
      return Image.asset(
        trimmed,
        width: double.infinity,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 120,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: Icon(Icons.image_outlined, size: 32, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }
  }
}
