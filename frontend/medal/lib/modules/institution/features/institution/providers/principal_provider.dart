// lib/features/institution/providers/principal_provider.dart
// Place at: lib/features/institution/providers/principal_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/principal.dart';
import '../models/staff.dart';
import '../services/mock_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class PrincipalDashboardState {
  final int totalStaff;
  final int totalStudents;
  final int certificationReady;
  final int activeStudents;
  final int inactiveStudents;
  final int enrollmentPending;
  final List<Map<String, dynamic>> recentActivity;

  const PrincipalDashboardState({
    required this.totalStaff,
    required this.totalStudents,
    required this.certificationReady,
    required this.activeStudents,
    required this.inactiveStudents,
    required this.enrollmentPending,
    required this.recentActivity,
  });
}

class StaffListState {
  final List<Staff> allStaff;
  final List<Staff> filteredStaff;
  final String searchQuery;
  final String selectedDepartment;
  final List<String> departments;

  const StaffListState({
    required this.allStaff,
    required this.filteredStaff,
    this.searchQuery = '',
    this.selectedDepartment = 'All Staff',
    required this.departments,
  });

  StaffListState copyWith({
    List<Staff>? allStaff,
    List<Staff>? filteredStaff,
    String? searchQuery,
    String? selectedDepartment,
    List<String>? departments,
  }) =>
      StaffListState(
        allStaff: allStaff ?? this.allStaff,
        filteredStaff: filteredStaff ?? this.filteredStaff,
        searchQuery: searchQuery ?? this.searchQuery,
        selectedDepartment: selectedDepartment ?? this.selectedDepartment,
        departments: departments ?? this.departments,
      );
}

class AddStaffState {
  final bool isLoading;
  final bool success;
  final String? error;
  final List<Map<String, dynamic>> pendingInvites;

  const AddStaffState({
    this.isLoading = false,
    this.success = false,
    this.error,
    this.pendingInvites = const [],
  });

  AddStaffState copyWith({
    bool? isLoading,
    bool? success,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? pendingInvites,
  }) =>
      AddStaffState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        error: clearError ? null : (error ?? this.error),
        pendingInvites: pendingInvites ?? this.pendingInvites,
      );
}

// ── Notifiers ─────────────────────────────────────────────────────────────────

class StaffListNotifier extends StateNotifier<StaffListState> {
  StaffListNotifier()
      : super(StaffListState(
          allStaff: MockRepository.staffList,
          filteredStaff: MockRepository.staffList,
          departments: _extractDepartments(MockRepository.staffList),
        ));

  static List<String> _extractDepartments(List<Staff> staff) {
    final deps = staff.map((s) => s.department).toSet().toList();
    return ['All Staff', ...deps];
  }

  void search(String query) {
    final filtered = _applyFilters(
      query: query,
      department: state.selectedDepartment,
    );
    state = state.copyWith(searchQuery: query, filteredStaff: filtered);
  }

  void filterByDepartment(String department) {
    final filtered = _applyFilters(
      query: state.searchQuery,
      department: department,
    );
    state = state.copyWith(
      selectedDepartment: department,
      filteredStaff: filtered,
    );
  }

  List<Staff> _applyFilters({
    required String query,
    required String department,
  }) {
    return state.allStaff.where((s) {
      final matchesSearch = query.isEmpty ||
          s.name.toLowerCase().contains(query.toLowerCase()) ||
          s.department.toLowerCase().contains(query.toLowerCase());
      final matchesDept =
          department == 'All Staff' || s.department == department;
      return matchesSearch && matchesDept;
    }).toList();
  }
}

class AddStaffNotifier extends StateNotifier<AddStaffState> {
  AddStaffNotifier() : super(const AddStaffState());

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

  void resetSuccess() {
    state = state.copyWith(success: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final principalDataProvider = Provider<Principal>(
  (ref) => MockRepository.principal,
);

final principalDashboardProvider = Provider<PrincipalDashboardState>(
  (ref) => PrincipalDashboardState(
    totalStaff: MockRepository.principalStats['totalStaff'] as int,
    totalStudents: MockRepository.principalStats['totalStudents'] as int,
    certificationReady:
        MockRepository.principalStats['certificationReady'] as int,
    activeStudents: MockRepository.principalStats['activeStudents'] as int,
    inactiveStudents: MockRepository.principalStats['inactiveStudents'] as int,
    enrollmentPending:
        MockRepository.principalStats['enrollmentPending'] as int,
    recentActivity: MockRepository.recentActivity,
  ),
);

final staffListProvider =
    StateNotifierProvider<StaffListNotifier, StaffListState>(
  (ref) => StaffListNotifier(),
);

final addStaffProvider =
    StateNotifierProvider<AddStaffNotifier, AddStaffState>(
  (ref) => AddStaffNotifier(),
);
