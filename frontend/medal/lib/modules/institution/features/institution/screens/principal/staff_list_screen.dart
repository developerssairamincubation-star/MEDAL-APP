// lib/features/institution/screens/principal/staff_list_screen.dart
// Place at: lib/features/institution/screens/principal/staff_list_screen.dart

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

/// Staff List Screen — matches Principal_login_stafflist.png
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  static const _allStaff = 'All Staff';

  final _searchController = TextEditingController();
  String _query = '';
  String _department = _allStaff;

  List<InstitutionMember> _filter(List<InstitutionMember> all) {
    final q = _query.trim().toLowerCase();
    return all.where((m) {
      final matchesSearch = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q) ||
          (m.department ?? '').toLowerCase().contains(q);
      final matchesDept = _department == _allStaff || m.department == _department;
      return matchesSearch && matchesDept;
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
        context.go(AppRoutes.principalDashboard);
        break;
      case 1:
        break; // Already here
      case 2:
        context.go(AppRoutes.principalAddStaff);
        break;
      case 3:
        context.go(AppRoutes.principalProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffMembersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search teachers, emails, or departments...',
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
          // ── Department Filter chips ─────────────────────────
          Builder(builder: (context) {
            final departments = [
              _allStaff,
              ...{
                for (final m in staff.valueOrNull ?? const <InstitutionMember>[])
                  if ((m.department ?? '').isNotEmpty) m.department!,
              },
            ];
            if (departments.length < 2) return const SizedBox.shrink();
            return SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: departments.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final dep = departments[i];
                  final isSelected = dep == _department;
                  return GestureDetector(
                    onTap: () => setState(() => _department = dep),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        dep,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          // ── List header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded,
                    size: 20, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'Teachers List',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Staff cards list ────────────────────────────────
          Expanded(
            child: AsyncBody<List<InstitutionMember>>(
              value: staff,
              onRetry: () => ref.invalidate(staffMembersProvider),
              builder: (all) {
                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No staff added yet',
                    message: 'Use "Add staffs" to create the first teacher account.',
                  );
                }
                final shown = _filter(all);
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No staff match your search',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(staffMembersProvider.future),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: shown.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => MemberProgressCard(
                      member: shown[i],
                      onTap: () => context.push('/principal/member/${shown[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        items: principalNavItems,
        currentIndex: 1,
        onTap: _onNavTap,
      ),
    );
  }
}
