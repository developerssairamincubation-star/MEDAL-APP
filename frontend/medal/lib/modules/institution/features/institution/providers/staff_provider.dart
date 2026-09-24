// lib/features/institution/providers/staff_provider.dart
// Place at: lib/features/institution/providers/staff_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff.dart';
import '../models/student.dart';
import '../services/mock_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class StaffDashboardState {
  final int totalStudents;
  final int myClassroom;
  final int certificationReady;
  final int activeStudents;
  final int inactiveStudents;
  final int enrollmentPending;
  final List<Map<String, dynamic>> recentActivity;

  const StaffDashboardState({
    required this.totalStudents,
    required this.myClassroom,
    required this.certificationReady,
    required this.activeStudents,
    required this.inactiveStudents,
    required this.enrollmentPending,
    required this.recentActivity,
  });
}

class MyClassState {
  final List<Student> allStudents;
  final List<Student> filteredStudents;
  final String searchQuery;
  final String selectedFilter;

  const MyClassState({
    required this.allStudents,
    required this.filteredStudents,
    this.searchQuery = '',
    this.selectedFilter = 'All Students',
  });

  MyClassState copyWith({
    List<Student>? allStudents,
    List<Student>? filteredStudents,
    String? searchQuery,
    String? selectedFilter,
  }) =>
      MyClassState(
        allStudents: allStudents ?? this.allStudents,
        filteredStudents: filteredStudents ?? this.filteredStudents,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedFilter: selectedFilter ?? this.selectedFilter,
      );
}

class InviteStudentsState {
  final bool isLoading;
  final bool success;
  final String? error;
  final List<Map<String, dynamic>> pendingInvites;

  const InviteStudentsState({
    this.isLoading = false,
    this.success = false,
    this.error,
    this.pendingInvites = const [
      {'email': 'k.thompson@edu.com', 'sentAt': 'Sent 2 hours ago'},
    ],
  });

  InviteStudentsState copyWith({
    bool? isLoading,
    bool? success,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? pendingInvites,
  }) =>
      InviteStudentsState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        error: clearError ? null : (error ?? this.error),
        pendingInvites: pendingInvites ?? this.pendingInvites,
      );
}

// ── Notifiers ─────────────────────────────────────────────────────────────────

class MyClassNotifier extends StateNotifier<MyClassState> {
  MyClassNotifier()
      : super(MyClassState(
          allStudents: MockRepository.students,
          filteredStudents: MockRepository.students,
        ));

  void search(String query) {
    final filtered = _applyFilters(query: query, filter: state.selectedFilter);
    state = state.copyWith(searchQuery: query, filteredStudents: filtered);
  }

  void filterStudents(String filter) {
    final filtered = _applyFilters(query: state.searchQuery, filter: filter);
    state = state.copyWith(selectedFilter: filter, filteredStudents: filtered);
  }

  List<Student> _applyFilters({
    required String query,
    required String filter,
  }) {
    return state.allStudents.where((s) {
      final matchesSearch = query.isEmpty ||
          s.name.toLowerCase().contains(query.toLowerCase()) ||
          s.subject.toLowerCase().contains(query.toLowerCase());
      final matchesFilter = switch (filter) {
        'At Risk' => s.status == StudentStatus.needsSupport ||
            s.status == StudentStatus.inactive,
        'Top Achievers' => s.completionPct >= 0.70,
        _ => true, // All Students
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }
}

class InviteStudentsNotifier extends StateNotifier<InviteStudentsState> {
  InviteStudentsNotifier() : super(const InviteStudentsState());

  Future<void> sendInvite(String email) async {
    if (email.trim().isEmpty) {
      state = state.copyWith(error: 'Please enter an email address.');
      return;
    }
    if (!email.contains('@')) {
      state = state.copyWith(error: 'Please enter a valid email address.');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    await Future.delayed(const Duration(milliseconds: 1000));

    final updatedInvites = [
      ...state.pendingInvites,
      {
        'email': email.trim(),
        'sentAt': 'Just now',
      }
    ];

    state = state.copyWith(
      isLoading: false,
      success: true,
      pendingInvites: updatedInvites,
    );
  }

  void revokeInvite(String email) {
    final updated =
        state.pendingInvites.where((i) => i['email'] != email).toList();
    state = state.copyWith(pendingInvites: updated);
  }

  void resetSuccess() {
    state = state.copyWith(success: false);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final currentStaffProvider = Provider<Staff>(
  (ref) => MockRepository.currentStaff,
);

final staffDashboardProvider = Provider<StaffDashboardState>(
  (ref) => StaffDashboardState(
    totalStudents: MockRepository.staffStats['totalStudents'] as int,
    myClassroom: MockRepository.staffStats['myClassroom'] as int,
    certificationReady: MockRepository.staffStats['certificationReady'] as int,
    activeStudents: MockRepository.staffStats['activeStudents'] as int,
    inactiveStudents: MockRepository.staffStats['inactiveStudents'] as int,
    enrollmentPending: MockRepository.staffStats['enrollmentPending'] as int,
    recentActivity: MockRepository.recentActivity,
  ),
);

final myClassProvider = StateNotifierProvider<MyClassNotifier, MyClassState>(
  (ref) => MyClassNotifier(),
);

final inviteStudentsProvider =
    StateNotifierProvider<InviteStudentsNotifier, InviteStudentsState>(
  (ref) => InviteStudentsNotifier(),
);

/// Provides a single student by ID for the class detail screen
final selectedStudentProvider = Provider.family<Student?, String>(
  (ref, studentId) {
    return MockRepository.students
        .where((s) => s.id == studentId)
        .firstOrNull;
  },
);
