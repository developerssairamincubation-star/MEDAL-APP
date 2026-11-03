// lib/modules/institution/features/institution/screens/shared/member_detail_screen.dart
// A staff member's or student's chapter-by-chapter SEEK progress, read live from the database.
// Used by the Principal (staff and students) and by Staff (students).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../models/member.dart';
import '../../providers/institution_provider.dart';
import '../../widgets/async_body.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/member_progress_card.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final int memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(memberProgressProvider(memberId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(showBackButton: true),
      body: AsyncBody<MemberProgress>(
        value: progress,
        onRetry: () => ref.invalidate(memberProgressProvider(memberId)),
        builder: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MemberProgressCard(member: data.member),
            const SizedBox(height: 20),
            Text(
              'Chapters',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (data.modules.isEmpty)
              const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No chapters available',
              )
            else
              for (final module in data.modules) _ModuleCard(module: module),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final Map<String, dynamic> module;

  @override
  Widget build(BuildContext context) {
    final chapters = List<Map<String, dynamic>>.from(module['chapters'] as List);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Module ${module['number']}: ${module['title']}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final c in chapters)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    c['completed'] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: c['completed'] == true
                        ? AppTheme.statusActive
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['title']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _caption(c),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _caption(Map<String, dynamic> c) {
    final type = '${c['type'] ?? ''}'.replaceAll('_', ' ');
    final when = c['completed_at'] == null ? null : DateTime.tryParse('${c['completed_at']}')?.toLocal();
    final done = when == null
        ? ''
        : ' • Completed ${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
    return '$type${c['duration'] == null || '${c['duration']}'.isEmpty ? '' : ' • ${c['duration']}'}$done';
  }
}
