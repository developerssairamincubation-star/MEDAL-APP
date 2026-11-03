// lib/modules/authority/screens/admin/admin_authority_applications_list_screen.dart
// Admin Authority Applications List Screen
// Shows registered officer applications with Pending, Approved, and Rejected tabs.

import 'package:medal/widgets/medal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../../../widgets/medal_logo.dart';

enum ApplicationFilterTab { pending, approved, rejected }

class AdminAuthorityApplicationsListScreen extends StatefulWidget {
  const AdminAuthorityApplicationsListScreen({super.key});

  @override
  State<AdminAuthorityApplicationsListScreen> createState() =>
      _AdminAuthorityApplicationsListScreenState();
}

class _AdminAuthorityApplicationsListScreenState
    extends State<AdminAuthorityApplicationsListScreen> {
  ApplicationFilterTab _selectedTab = ApplicationFilterTab.pending;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allApplications = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Enforce role permission in UI if session exists with non-admin role
    if (ApiService().isAuthenticated && ApiService().userRole != 'admin') {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Access Denied: Only authenticated System Administrators can access this dashboard.';
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch all applications so we can compute accurate tab counts
      final list = await ApiService().getAuthorityApplications(status: 'all');
      if (!mounted) return;

      setState(() {
        _allApplications = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 403) {
          _errorMessage =
              'Access Denied: You do not have administrator permissions to view this queue.';
        } else if (e.statusCode == 401) {
          _errorMessage = 'Session expired. Please log in as Administrator.';
        } else {
          _errorMessage = e.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    final statusString = switch (_selectedTab) {
      ApplicationFilterTab.pending => 'pending',
      ApplicationFilterTab.approved => 'approved',
      ApplicationFilterTab.rejected => 'rejected',
    };
    return _allApplications.where((app) {
      final s = app['status']?.toString().toLowerCase().trim() ?? 'pending';
      return s == statusString;
    }).toList();
  }

  int _countForStatus(String status) {
    return _allApplications.where((app) {
      final s = app['status']?.toString().toLowerCase().trim() ?? 'pending';
      return s == status;
    }).length;
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text(
              'Admin Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to end your Administrator session and return to role selection?',
          style: GoogleFonts.inter(fontSize: 13.5, color: MedalTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: MedalTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Log Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.roleSelection,
        (route) => false,
      );
    }
  }

  void _openDetails(Map<String, dynamic> app) async {
    final int? appId = app['id'] is int ? app['id'] : int.tryParse(app['id']?.toString() ?? '');
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminVerification,
      arguments: {
        'id': appId,
        'application': app,
      },
    );

    if (result == true) {
      // Refresh list after review action
      _loadApplications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 550),
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                // 1. Top Brand Header
                _buildTopBrandHeader(),

                // 2. Navigation SubNavBar
                _buildSubNavBar(),

                // 3. Status Filter Tabs
                _buildFilterTabs(),

                // 4. Main Body Content (loading, error, empty, or list)
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrandHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MedalLogo(iconSize: 18),
          const SizedBox(width: 6),
          Text(
            'MEdAL',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111C2D),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(
                Icons.arrow_back,
                color: Color(0xFF111C2D),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Authority Applications',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111C2D),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ADMIN CONSOLE',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6D28D9),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            key: const Key('admin_logout_button'),
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            tooltip: 'Log Out',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final pendingCount = _countForStatus('pending');
    final approvedCount = _countForStatus('approved');
    final rejectedCount = _countForStatus('rejected');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabItem(
              tab: ApplicationFilterTab.pending,
              label: 'Pending',
              count: pendingCount,
              badgeColor: const Color(0xFF6D28D9),
              badgeBg: const Color(0xFFEDE9FE),
            ),
            _buildTabItem(
              tab: ApplicationFilterTab.approved,
              label: 'Approved',
              count: approvedCount,
              badgeColor: const Color(0xFF15803D),
              badgeBg: const Color(0xFFDCFCE7),
            ),
            _buildTabItem(
              tab: ApplicationFilterTab.rejected,
              label: 'Rejected',
              count: rejectedCount,
              badgeColor: const Color(0xFFB91C1C),
              badgeBg: const Color(0xFFFEE2E2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required ApplicationFilterTab tab,
    required String label,
    required int count,
    required Color badgeColor,
    required Color badgeBg,
  }) {
    final isSelected = _selectedTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != tab) {
            setState(() => _selectedTab = tab);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF111C2D) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? badgeBg : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? badgeColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: MedalTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading authority applications...',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: MedalTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Unable to load applications',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: MedalTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadApplications,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: MedalTheme.primary),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredApplications;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_rounded,
                  color: Color(0xFF6D28D9),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyTitle(),
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111C2D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getEmptySubtitle(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MedalTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _loadApplications,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh List'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: MedalTheme.primary,
      onRefresh: _loadApplications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final app = filtered[index];
          return _buildApplicationCard(app);
        },
      ),
    );
  }

  String _getEmptyTitle() {
    return switch (_selectedTab) {
      ApplicationFilterTab.pending => 'No Pending Applications',
      ApplicationFilterTab.approved => 'No Approved Officers',
      ApplicationFilterTab.rejected => 'No Rejected Applications',
    };
  }

  String _getEmptySubtitle() {
    return switch (_selectedTab) {
      ApplicationFilterTab.pending =>
        'There are no officer registration submissions currently awaiting administrative review.',
      ApplicationFilterTab.approved =>
        'No authority accounts have been approved in this session yet.',
      ApplicationFilterTab.rejected =>
        'No submissions have been rejected.',
    };
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    final officerName = app['full_name']?.toString() ?? 'Officer';
    final designation = app['designation']?.toString() ?? 'Municipal Officer';
    final department = app['department']?.toString() ?? 'Department';
    final email = app['official_email']?.toString() ?? '';
    final jurisdiction = app['jurisdiction']?.toString() ?? 'General Jurisdiction';
    final status = (app['status']?.toString() ?? 'pending').toLowerCase().trim();

    String formattedDate = '';
    if (app['created_at'] != null) {
      try {
        final dt = DateTime.parse(app['created_at'].toString()).toLocal();
        formattedDate = DateFormat('MMM dd, yyyy').format(dt);
      } catch (_) {
        formattedDate = app['created_at'].toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(app),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Name + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Color(0xFF64748B),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            officerName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111C2D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            designation,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(status),
                  ],
                ),

                const SizedBox(height: 12),

                // Department and Jurisdiction block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              department,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF6366F1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Jurisdiction: $jurisdiction',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Footer row: Email + Submission Date + Forward Arrow
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              email,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2563EB),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'APPROVED';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        label = 'REJECTED';
        break;
      case 'pending':
      default:
        bg = const Color(0xFFEDE9FE);
        text = const Color(0xFF6D28D9);
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
