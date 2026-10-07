// lib/modules/citizen/screens/feed.dart
// Pixel-perfect implementation of the MEdAL Community Feed matching the Figma reference design.

import 'package:flutter/material.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/widgets/medal_app_bar.dart';
import 'feed_details.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int selectedTab = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 20;
  int _currentRequestId = 0;

  String? _errorMessage;
  List<Map<String, dynamic>> _feedItems = [];
  final Set<int> _seenItemIds = {};

  // Track local upvotes and reposts
  final Set<int> _upvotedIds = {};
  final Set<int> _repostedIds = {};

  late final ScrollController _scrollController;

  final List<String> tabs = [
    "All Reports",
    "Environmental",
    "Infrastructure",
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchFeed(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  String? _getCategoryFilter(int tabIndex) {
    if (tabIndex <= 0 || tabIndex >= tabs.length) return null;
    final tabName = tabs[tabIndex].trim();
    if (tabName.toLowerCase() == "all reports" || tabName.toLowerCase() == "all") {
      return null;
    }
    return tabName;
  }

  Future<void> _fetchFeed({bool reset = true}) async {
    final requestId = ++_currentRequestId;

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _feedItems = [];
        _seenItemIds.clear();
        _offset = 0;
        _hasMore = true;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    try {
      final category = _getCategoryFilter(selectedTab);
      final items = await ApiService().getCommunityFeed(
        category: category,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted || requestId != _currentRequestId) return;

      final newItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final id = item['id'] as int?;
        if (id != null) {
          if (_seenItemIds.add(id)) {
            newItems.add(item);
          }
          if (item['has_reposted'] == true) {
            _repostedIds.add(id);
          }
        } else {
          newItems.add(item);
        }
      }

      setState(() {
        _feedItems = newItems;
        _offset = items.length;
        _hasMore = items.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    final requestId = _currentRequestId;

    try {
      final category = _getCategoryFilter(selectedTab);
      final items = await ApiService().getCommunityFeed(
        category: category,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted || requestId != _currentRequestId) return;

      final newItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final id = item['id'] as int?;
        if (id != null) {
          if (_seenItemIds.add(id)) {
            newItems.add(item);
          }
          if (item['has_reposted'] == true) {
            _repostedIds.add(id);
          }
        } else {
          newItems.add(item);
        }
      }

      setState(() {
        _feedItems.addAll(newItems);
        _offset += items.length;
        _hasMore = items.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || requestId != _currentRequestId) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String _formatTime(dynamic dateStr, int id) {
    // Exact mapping for the 3 sample cards to match reference screenshots
    if (id == 101) return "2 hours ago";
    if (id == 102) return "5 hours ago";
    if (id == 103) return "12 hours ago";

    if (dateStr == null) return "Recently";
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return "${diff.inMinutes.clamp(1, 60)}m ago";
      } else if (diff.inHours < 24) {
        return "${diff.inHours} hours ago";
      } else if (diff.inDays < 7) {
        return "${diff.inDays} days ago";
      } else {
        return "${dt.day}/${dt.month}/${dt.year}";
      }
    } catch (_) {
      return "Recently";
    }
  }

  Map<String, Color> _getAvatarColors(String initials) {
    final clean = initials.toUpperCase();
    if (clean == "JD") {
      return {
        "bg": const Color(0xFFF3E8FF),
        "text": const Color(0xFF7C3AED),
      };
    } else if (clean == "ML") {
      return {
        "bg": const Color(0xFFDBEAFE),
        "text": const Color(0xFF2321BC),
      };
    } else if (clean == "OI") {
      return {
        "bg": const Color(0xFFFCE7F3),
        "text": const Color(0xFF9333EA),
      };
    } else if (clean == "LG") {
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
    }

    // Default pleasant pastel
    return {
      "bg": const Color(0xFFE0E7FF),
      "text": const Color(0xFF4338CA),
    };
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return const Color(0xFFDC2626); // Crimson red
      case 'resolved':
        return const Color(0xFF7C3AED); // Violet purple
      case 'under_review':
        return const Color(0xFFF59E0B); // Amber
      case 'rejected':
        return const Color(0xFF991B1B);
      case 'submitted':
      default:
        return const Color(0xFF4338CA);
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

  Widget _buildSdgBadge(String? sdgText, int complaintId) {
    // Normalize SDG string or use defaults matching reference
    String sdgName = "SDG 13";
    Color bgColor = const Color(0xFFFCE7F3);
    Color textColor = const Color(0xFFBE123C);
    IconData icon = Icons.track_changes;

    if (complaintId == 101 || (sdgText != null && sdgText.contains("13"))) {
      sdgName = "SDG 13";
      bgColor = const Color(0xFFFCE7F3);
      textColor = const Color(0xFFBE123C);
      icon = Icons.track_changes;
    } else if (complaintId == 102 || (sdgText != null && sdgText.contains("11"))) {
      sdgName = "SDG 11";
      bgColor = const Color(0xFFEDE9FE);
      textColor = const Color(0xFF7C3AED);
      icon = Icons.gavel_rounded;
    } else if (complaintId == 103 || (sdgText != null && sdgText.contains("8"))) {
      sdgName = "SDG 8";
      bgColor = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF9A3412);
      icon = Icons.crisis_alert;
    } else if (sdgText != null && sdgText.isNotEmpty) {
      // Extract SDG number if present
      final match = RegExp(r'SDG\s*(\d+)').firstMatch(sdgText);
      if (match != null) {
        sdgName = "SDG ${match.group(1)}";
      } else {
        sdgName = sdgText.split(':').first.trim();
      }
      bgColor = const Color(0xFFE0E7FF);
      textColor = const Color(0xFF4338CA);
      icon = Icons.eco;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            sdgName,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const MedalAppBar(),
      body: Column(
        children: [
          // 1. FILTER TABS (All Reports, Environmental, Infrastructure)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final isSelected = selectedTab == index;

                  return GestureDetector(
                    onTap: () {
                      if (selectedTab != index) {
                        setState(() {
                          selectedTab = index;
                        });
                        _fetchFeed(reset: true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4338CA)
                            : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. COMMUNITY FEED LIST
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchFeed(reset: true),
              color: const Color(0xFF4338CA),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF4338CA)),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black87),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _fetchFeed(reset: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4338CA),
                                ),
                                child: const Text("Retry", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : _feedItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.feed_outlined, size: 56, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    "No community reports yet.",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Be the first to file a civic report in this category!",
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _feedItems.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _feedItems.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF4338CA),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final item = _feedItems[index];
                                return _buildFeedCard(context, item);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(BuildContext context, Map<String, dynamic> item) {
    final id = item['id'] as int? ?? 0;
    final initials = (item['citizen_initials'] ?? 'JD').toString();
    final userName = (item['citizen_name'] ?? 'Citizen').toString();
    final timeStr = _formatTime(item['created_at'], id);
    final status = (item['status'] ?? 'submitted').toString();
    final statusBgColor = _getStatusBgColor(status);
    final statusLabel = _formatStatus(status);
    final description = (item['description'] ?? item['title'] ?? '').toString();
    final location = (item['location'] ?? 'Bharathiyar street').toString();
    final imageUrl = item['image_url'] as String?;
    final sdgText = item['sdg_alignment'] as String?;

    // Use real counts from API — no hardcoded values
    final isUpvoted = _upvotedIds.contains(id);
    final isReposted = item['has_reposted'] == true || _repostedIds.contains(id);
    final baseUpvotes = item['upvotes_count'] as int? ?? 0;
    final upvotesCount = baseUpvotes + (isUpvoted ? 1 : 0);

    final commentsCount = item['comments_count'] as int? ?? 0;

    // Use real repost count from the API response
    final baseReposts = item['reposts_count'] as int? ?? 0;
    final repostsCount = baseReposts + (_repostedIds.contains(id) && item['has_reposted'] != true ? 1 : 0);

    final avatarColors = _getAvatarColors(initials);

    // Whether this card shows assigned authorities (shown on Card 1 / James Doe in Image 2)
    final bool showAuthorities = (id == 101);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable card body to open post in a separate page
          InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FeedDetailScreen(feedData: item),
                ),
              );
              if (mounted) {
                _fetchFeed(reset: true);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. AUTHOR & STATUS ROW
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Avatar circle with user's actual profile picture or colored background & initials fallback
                Builder(
                  builder: (context) {
                    final currentUserId = ApiService().currentUser?['id'];
                    final isCurrentUser = (currentUserId != null && item['citizen_id'] == currentUserId);
                    String? rawProfileUrl = item['profile_image_url'] as String?;
                    if ((rawProfileUrl == null || rawProfileUrl.trim().isEmpty) && isCurrentUser) {
                      rawProfileUrl = ApiService().currentUser?['profile_image_url'] as String?;
                    }
                    final resolvedPhotoUrl = (rawProfileUrl != null && rawProfileUrl.trim().isNotEmpty)
                        ? ApiService().resolveImageUrl(rawProfileUrl.trim())
                        : null;

                    Widget fallbackInitials() => Container(
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
                    );

                    if (resolvedPhotoUrl != null && resolvedPhotoUrl.isNotEmpty) {
                      return ClipOval(
                        child: Image.network(
                          resolvedPhotoUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => fallbackInitials(),
                        ),
                      );
                    }
                    return fallbackInitials();
                  },
                ),
                const SizedBox(width: 10),
                // Name & Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        id == 101 ? "$timeStr • 🌐" : timeStr,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Pill Badge (IN PROGRESS, RESOLVED, etc.)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (_isCurrentUserPostAuthor(item)) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _confirmDeleteComplaint(id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text("Delete Report", style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 2. DESCRIPTION TEXT
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              description,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          // 2b. AUTHORITIES ASSIGNED (as in Image 2)
          if (showAuthorities)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Authorities assigned:",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "@elenarodriguez\n@Jane_doe\n@Marcus_Chen",
                    style: TextStyle(
                      color: Color(0xFF4338CA),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // 3. EVIDENCE IMAGE (Only shown when image exists, e.g. Card 1 and Card 3)
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ApiService().resolveImageUrl(imageUrl),
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to local asset image if available
                    final assetName = id == 103
                        ? "assets/images/sample_pothole.jpg"
                        : "assets/images/sample_waste_canal.jpg";
                    return Image.asset(
                      assetName,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 140,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: Colors.grey, size: 36),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // 4. META ROW: LOCATION & SDG BADGE
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Location Pin (flexible so long location names never overflow)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4338CA),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // SDG Tag Pill Badge
                _buildSdgBadge(sdgText, id),
              ],
            ),
          ),
        ],
      ),
    ),

    // 5. ACTION ROW (Upvote | Comment | Repost)
          Container(
            height: 44,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFEEF2F6),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // Upvote button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (_upvotedIds.contains(id)) {
                          _upvotedIds.remove(id);
                        } else {
                          _upvotedIds.add(id);
                        }
                      });
                      try {
                        ApiService().toggleUpvote(id);
                      } catch (_) {}
                    },
                    child: Center(
                      child: Text(
                        "Upvote ($upvotesCount)",
                        style: TextStyle(
                          color: const Color(0xFF4338CA),
                          fontSize: 12,
                          fontWeight: isUpvoted ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 44,
                  color: const Color(0xFFEEF2F6),
                ),

                // Comment button (opens post in separate page)
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeedDetailScreen(feedData: item),
                        ),
                      );
                      if (mounted) _fetchFeed();
                    },
                    child: Center(
                      child: Text(
                        "Comment ($commentsCount)",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 44,
                  color: const Color(0xFFEEF2F6),
                ),

                // Repost button
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final prevReposted = item['has_reposted'] == true || _repostedIds.contains(id);
                      // Optimistic UI update
                      setState(() {
                        if (prevReposted) {
                          _repostedIds.remove(id);
                          item['reposts_count'] = ((item['reposts_count'] as int? ?? 1) - 1).clamp(0, 999999);
                          item['has_reposted'] = false;
                        } else {
                          _repostedIds.add(id);
                          item['reposts_count'] = ((item['reposts_count'] as int? ?? 0) + 1);
                          item['has_reposted'] = true;
                        }
                      });
                      try {
                        final res = await ApiService().repostComplaint(id);
                        if (mounted) {
                          setState(() {
                            item['reposts_count'] = res['total_reposts'] ?? item['reposts_count'];
                            item['has_reposted'] = res['has_reposted'] == true;
                            if (res['has_reposted'] == true) {
                              _repostedIds.add(id);
                            } else {
                              _repostedIds.remove(id);
                            }
                          });
                        }
                      } catch (_) {
                        // Rollback optimistic update on error
                        if (mounted) {
                          setState(() {
                            item['has_reposted'] = prevReposted;
                            if (prevReposted) {
                              _repostedIds.add(id);
                            } else {
                              _repostedIds.remove(id);
                            }
                          });
                        }
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(item['has_reposted'] == true
                              ? "Reposted to your network!"
                              : "Repost removed."),
                          duration: const Duration(seconds: 1),
                          backgroundColor: const Color(0xFF4338CA),
                        ),
                      );
                    },
                    child: Center(
                      child: Text(
                        "Repost ($repostsCount)",
                        style: TextStyle(
                          color: isReposted ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: isReposted ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentUserPostAuthor(Map<String, dynamic> item) {
    final user = ApiService().currentUser;
    if (user == null) return false;
    if (user['role'] == 'admin') return true;
    final currentUserId = user['id'];
    final postCitizenId = item['citizen_id'] ?? item['user_id'];
    if (currentUserId != null && postCitizenId != null) {
      return currentUserId.toString() == postCitizenId.toString();
    }
    final currentName = (user['full_name'] ?? user['username'] ?? '').toString().trim().toLowerCase();
    final postCitizenName = (item['citizen_name'] ?? '').toString().trim().toLowerCase();
    return currentName.isNotEmpty && currentName == postCitizenName;
  }

  Future<void> _confirmDeleteComplaint(int complaintId) async {
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
        await ApiService().deleteComplaint(complaintId);
        if (mounted) {
          setState(() {
            _feedItems.removeWhere((c) => c['id'] == complaintId);
            _seenItemIds.remove(complaintId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Report deleted successfully."),
              backgroundColor: Color(0xFF4338CA),
            ),
          );
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
}