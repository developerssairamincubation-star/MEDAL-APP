// lib/modules/authority/screens/dashboard/authority_dashboard_screen.dart
// Authority Dashboard / Feed screen showing key metrics, SLA alerts, and priority feed.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/authority_models.dart';
import '../complaints/authority_complaint_detail_screen.dart';

class AuthorityDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToComplaints;

  const AuthorityDashboardScreen({
    super.key,
    required this.onNavigateToComplaints,
  });

  @override
  State<AuthorityDashboardScreen> createState() =>
      _AuthorityDashboardScreenState();
}

class _AuthorityDashboardScreenState extends State<AuthorityDashboardScreen> {
  final officer = MockAuthorityRepository.currentOfficer;

  @override
  Widget build(BuildContext context) {
    final allComplaints = MockAuthorityRepository.complaints;
    final inProgressCount = allComplaints
        .where((c) => c.status == AuthorityComplaintStatus.inProgress)
        .length;
    final reviewingCount = allComplaints
        .where((c) => c.status == AuthorityComplaintStatus.reviewing)
        .length;
    final assignedCount = allComplaints
        .where((c) => c.status == AuthorityComplaintStatus.assigned)
        .length;
    final resolvedCount = allComplaints
        .where((c) => c.status == AuthorityComplaintStatus.completed)
        .length;

    final priorityList = allComplaints
        .where((c) =>
            c.priority == AuthorityPriority.critical ||
            c.priority == AuthorityPriority.high)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: MedalTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Officer Profile Welcome Banner
            _buildOfficerHeader(),
            const SizedBox(height: 16),

            // SLA Deadline Alert Banner
            _buildSlaAlertBanner(),
            const SizedBox(height: 18),

            // 4 Stats Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Total Assigned",
                    count: "${assignedCount + inProgressCount + reviewingCount}",
                    subtitle: "Active Ward Issues",
                    icon: Icons.assignment_outlined,
                    color: MedalTheme.primary,
                    bgColor: MedalTheme.primaryTint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: "In Progress",
                    count: "$inProgressCount",
                    subtitle: "Crew Dispatched",
                    icon: Icons.sync_rounded,
                    color: MedalTheme.primaryDark,
                    bgColor: MedalTheme.primaryTint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Under Review",
                    count: "$reviewingCount",
                    subtitle: "Pending Triage",
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: "Resolved",
                    count: "$resolvedCount",
                    subtitle: "Verified Complete",
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Priority Action Feed Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Priority Civic Feed",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MedalTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: widget.onNavigateToComplaints,
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      color: MedalTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Priority Complaints List
            if (priorityList.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "No critical priority complaints at this moment.",
                    style: TextStyle(color: MedalTheme.textSecondary),
                  ),
                ),
              )
            else
              Column(
                children: priorityList.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MedalTheme.lavenderBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.priority.backgroundColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.priority.label.toUpperCase(),
                                style: TextStyle(
                                  color: item.priority.color,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.id,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: MedalTheme.primary,
                                ),
                              ),
                            ),
                            Text(
                              item.ward,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: MedalTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: MedalTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.address,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: MedalTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: MedalTheme.slateBlue),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AuthorityComplaintDetailScreen(
                                complaint: item,
                                onStatusChanged: () => setState(() {}),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MedalTheme.lavenderBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: MedalTheme.primaryTint,
            child: Icon(Icons.person, color: MedalTheme.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      officer.legalName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MedalTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 2),
                          Text(
                            "VERIFIED",
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${officer.designation} • ${officer.department}",
                  style: const TextStyle(fontSize: 12, color: MedalTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  officer.jurisdiction,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: MedalTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlaAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alarm_on_rounded, color: Color(0xFFDC2626), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SLA Attention Notice",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "2 complaints in Ward 62 approaching 24h SLA response deadline. Review and dispatch crews promptly.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedalTheme.lavenderBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MedalTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: MedalTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
