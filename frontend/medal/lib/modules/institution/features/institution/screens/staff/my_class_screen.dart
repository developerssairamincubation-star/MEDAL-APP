// lib/features/institution/screens/staff/my_class_screen.dart
// Place at: lib/features/institution/screens/staff/my_class_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../models/member.dart';
import '../../providers/institution_provider.dart';
import '../../widgets/async_body.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/member_progress_card.dart';

/// Students screen — the teacher's own students with their real SEEK progress.
class MyClassScreen extends ConsumerStatefulWidget {
  const MyClassScreen({super.key});

  @override
  ConsumerState<MyClassScreen> createState() => _MyClassScreenState();
}

class _MyClassScreenState extends ConsumerState<MyClassScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = _filters.first;

  List<InstitutionMember> _apply(List<InstitutionMember> all) {
    final q = _query.trim().toLowerCase();
    return all.where((m) {
      final matchesSearch = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          (m.studentId ?? '').toLowerCase().contains(q) ||
          (m.department ?? '').toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        'Not started' => m.status == MemberStatus.notStarted,
        'Completed' => m.status == MemberStatus.completed,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.staffDashboard);
        break;
      case 1:
        break; // Already here
      case 2:
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        context.go(AppRoutes.staffProfile);
        break;
    }
  }

  static const _filters = ['All Students', 'Not started', 'Completed'];

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentMembersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Students',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Top-right action: add students by e-mail or CSV (they are added under this teacher).
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: const Key('add_students_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.push(AppRoutes.staffAddStudents),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, size: 17, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Add Students',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search students, IDs, or departments...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textMuted, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Filter chips ────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final filter = _filters[i];
                final isSelected = filter == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // ── Student list ────────────────────────────────────
          Expanded(
            child: AsyncBody<List<InstitutionMember>>(
              value: students,
              onRetry: () => ref.invalidate(studentMembersProvider),
              builder: (all) {
                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No students yet',
                    message: 'Use Add Students (top right) to invite students by email or CSV. They appear here under you.',
                  );
                }
                final shown = _apply(all);
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No students match your filters',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(studentMembersProvider.future),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: shown.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => MemberProgressCard(
                      member: shown[i],
                      onTap: () => context.push('/staff/student/${shown[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        items: staffNavItems,
        currentIndex: 1,
        onTap: _onNavTap,
      ),
    );
  }
}
