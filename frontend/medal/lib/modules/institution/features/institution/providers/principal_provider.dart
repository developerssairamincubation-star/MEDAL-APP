// lib/modules/institution/features/institution/providers/principal_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medal/core/services/api_service.dart';

import '../models/member.dart';
import '../services/institution_api.dart';
import 'institution_provider.dart';

// ── Add staff ────────────────────────────────────────────────────────────────

class AddStaffState {
  final bool isLoading;
  final String? error;
  final NewStaffResult? created;

  const AddStaffState({this.isLoading = false, this.error, this.created});
}

class AddStaffNotifier extends StateNotifier<AddStaffState> {
  AddStaffNotifier(this._ref) : super(const AddStaffState());

  final Ref _ref;
  static const _api = InstitutionApi();

  /// Creates the staff account. On success [AddStaffState.created] holds the
  /// one-time temporary password for the principal to hand over.
  Future<void> addStaff({
    required String name,
    required String email,
    String? department,
    String? designation,
  }) async {
    if (name.trim().isEmpty) {
      state = const AddStaffState(error: "Please enter the teacher's name.");
      return;
    }
    if (!email.contains('@') || email.trim().length < 5) {
      state = const AddStaffState(error: 'Please enter a valid email address.');
      return;
    }

    state = const AddStaffState(isLoading: true);
    try {
      final created = await _api.addStaff(
        name: name.trim(),
        email: email.trim(),
        department: department?.trim(),
        designation: designation?.trim(),
      );
      _ref.invalidate(staffMembersProvider);
      _ref.invalidate(institutionOverviewProvider);
      state = AddStaffState(created: created);
    } on ApiException catch (e) {
      state = AddStaffState(error: e.message);
    } catch (_) {
      state = const AddStaffState(error: 'Could not add staff. Check your connection.');
    }
  }

  void reset() => state = const AddStaffState();
}

final addStaffProvider =
    StateNotifierProvider.autoDispose<AddStaffNotifier, AddStaffState>(
  (ref) => AddStaffNotifier(ref),
);

// ── Add students (staff) ─────────────────────────────────────────────────────

/// CSV format the server expects; shown in the app and copyable as a template.
const studentCsvTemplate = 'name,email,department\nAsha Kumar,asha.kumar@example.com,Science\n';

class AddStudentsState {
  final bool isLoading;
  final String? error;
  final StudentInviteResult? invited;
  final BulkInviteResult? bulk;

  const AddStudentsState({this.isLoading = false, this.error, this.invited, this.bulk});
}

class AddStudentsNotifier extends StateNotifier<AddStudentsState> {
  AddStudentsNotifier(this._ref) : super(const AddStudentsState());

  final Ref _ref;
  static const _api = InstitutionApi();

  void _refresh() {
    _ref.invalidate(studentMembersProvider);
    _ref.invalidate(institutionOverviewProvider);
  }

  Future<void> inviteOne({required String name, required String email, String? department}) async {
    if (name.trim().isEmpty) {
      state = const AddStudentsState(error: "Please enter the student's name.");
      return;
    }
    if (!email.contains('@') || email.trim().length < 5) {
      state = const AddStudentsState(error: 'Please enter a valid email address.');
      return;
    }
    state = const AddStudentsState(isLoading: true);
    try {
      final result = await _api.inviteStudent(
        name: name.trim(),
        email: email.trim(),
        department: department?.trim(),
      );
      _refresh();
      state = AddStudentsState(invited: result);
    } on ApiException catch (e) {
      state = AddStudentsState(error: e.message);
    } catch (_) {
      state = const AddStudentsState(error: 'Could not add the student. Check your connection.');
    }
  }

  Future<void> inviteCsv({required List<int> bytes, required String filename}) async {
    state = const AddStudentsState(isLoading: true);
    try {
      final result = await _api.inviteStudentsCsv(bytes: bytes, filename: filename);
      _refresh();
      state = AddStudentsState(bulk: result);
    } on ApiException catch (e) {
      state = AddStudentsState(error: e.message);
    } catch (_) {
      state = const AddStudentsState(error: 'Could not upload the file. Check your connection.');
    }
  }

  void reset() => state = const AddStudentsState();
}

final addStudentsProvider =
    StateNotifierProvider.autoDispose<AddStudentsNotifier, AddStudentsState>(
  (ref) => AddStudentsNotifier(ref),
);
