// lib/modules/authority/screens/complaints/authority_complaints_screen.dart
// My Complaints screen with All, Assigned, Reviewing, and In Progress filters.

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/authority_models.dart';
import 'authority_complaint_detail_screen.dart';

class AuthorityComplaintsScreen extends StatefulWidget {
  const AuthorityComplaintsScreen({super.key});

  @override
  State<AuthorityComplaintsScreen> createState() =>
      _AuthorityComplaintsScreenState();
}

class _AuthorityComplaintsScreenState extends State<AuthorityComplaintsScreen> {
  // Filters requested: All, Assigned, Reviewing, In Progress
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusFilters = [
    'All',
    'Assigned',
    'Reviewing',
    'In Progress',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AuthorityComplaint> get _filteredComplaints {
    return MockAuthorityRepository.complaints.where((complaint) {
      // 1. Status Filter
      if (_selectedStatusFilter == 'Assigned' &&
          complaint.status != AuthorityComplaintStatus.assigned) {
        return false;
      }
      if (_selectedStatusFilter == 'Reviewing' &&
          complaint.status != AuthorityComplaintStatus.reviewing) {
        return false;
      }
      if (_selectedStatusFilter == 'In Progress' &&
          complaint.status != AuthorityComplaintStatus.inProgress) {
        return false;
      }

      // 2. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesId = complaint.id.toLowerCase().contains(query);
        final matchesTitle = complaint.title.toLowerCase().contains(query);
        final matchesDesc = complaint.description.toLowerCase().contains(query);
        final matchesCategory = complaint.category.toLowerCase().contains(query);
        final matchesWard = complaint.ward.toLowerCase().contains(query);
        return matchesId || matchesTitle || matchesDesc || matchesCategory || matchesWard;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredComplaints;

    return Scaffold(
      backgroundColor: MedalTheme.background,
      body: Column(
        children: [
          // Top Search & Title Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Complaints",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MedalTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: "Search complaints by ID, title, or ward...",
                    hintStyle: const TextStyle(fontSize: 13, color: MedalTheme.gray),
                    prefixIcon: const Icon(Icons.search, size: 20, color: MedalTheme.slateBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MedalTheme.lavenderBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MedalTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Required Status Filters: All, Assigned, Reviewing, In Progress
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _statusFilters.map((filter) {
                final isSelected = _selectedStatusFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedStatusFilter = filter);
                    },
                    selectedColor: MedalTheme.primary,
                    backgroundColor: MedalTheme.primaryTint,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : MedalTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? MedalTheme.primary : MedalTheme.lavenderBorder,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: MedalTheme.lavenderBorder),

          // Complaints List
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined,
                            size: 50, color: MedalTheme.lavenderBorder),
                        const SizedBox(height: 12),
                        Text(
                          "No complaints found for '$_selectedStatusFilter'",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return _buildComplaintCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(AuthorityComplaint item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MedalTheme.lavenderBorder),
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: ID, Priority, Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.id,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MedalTheme.primary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.priority.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.priority.label.toUpperCase(),
                            style: TextStyle(
                              color: item.priority.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.status.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.status.label.toUpperCase(),
                            style: TextStyle(
                              color: item.status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MedalTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Description preview
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: MedalTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom row: Ward / Address & Reactions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: MedalTheme.slateBlue),
                        const SizedBox(width: 4),
                        Text(
                          item.ward,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MedalTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "•  ${item.category}",
                          style: const TextStyle(fontSize: 12, color: MedalTheme.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, size: 14, color: MedalTheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          "${item.upvotes}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MedalTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.chat_bubble_outline,
                            size: 13, color: MedalTheme.slateBlue),
                        const SizedBox(width: 2),
                        Text(
                          "${item.commentsCount}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: MedalTheme.textSecondary,
                          ),
                        ),
                      ],
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
}
