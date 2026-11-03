// lib/widgets/post_action_bar.dart
// Shared Upvote | Comment | Repost bar used by feed cards and the single-post page.
// Default state is grey; an active upvote/repost turns blue and bold.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.upvotes,
    required this.comments,
    required this.reposts,
    required this.isUpvoted,
    required this.isReposted,
    required this.onUpvote,
    required this.onComment,
    required this.onRepost,
    this.height = 40,
  });

  final int upvotes;
  final int comments;
  final int reposts;
  final bool isUpvoted;
  final bool isReposted;
  final VoidCallback onUpvote;
  final VoidCallback onComment;
  final VoidCallback onRepost;
  final double height;

  static const Color _active = Color(0xFF0467B6);
  static const Color _inactive = Color(0xFF5D6478);
  static const Color _divider = Color(0xFFE5EDF5);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _divider, width: 1)),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            _item(
              label: 'Upvote ($upvotes)',
              icon: isUpvoted ? Icons.arrow_circle_up_rounded : Icons.arrow_upward_rounded,
              active: isUpvoted,
              onTap: onUpvote,
            ),
            Container(width: 1, height: height, color: _divider),
            _item(
              label: 'Comment ($comments)',
              icon: Icons.chat_bubble_outline_rounded,
              active: false,
              onTap: onComment,
            ),
            Container(width: 1, height: height, color: _divider),
            _item(
              label: 'Repost($reposts)',
              icon: Icons.repeat_rounded,
              active: isReposted,
              onTap: onRepost,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? _active : _inactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
