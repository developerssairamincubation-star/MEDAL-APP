// lib/modules/institution/features/institution/providers/institution_provider.dart
// Live data for the Principal and Staff screens. Every provider re-queries on
// each visit (autoDispose), so the screens always show the current database.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medal/core/services/api_service.dart';

import '../models/member.dart';
import '../services/institution_api.dart';

const _api = InstitutionApi();

final institutionOverviewProvider =
    FutureProvider.autoDispose<InstitutionOverview>((ref) => _api.overview());

final staffMembersProvider =
    FutureProvider.autoDispose<List<InstitutionMember>>((ref) => _api.staff());

final studentMembersProvider =
    FutureProvider.autoDispose<List<InstitutionMember>>((ref) => _api.students());

final ownProgressProvider =
    FutureProvider.autoDispose<OwnProgress>((ref) => _api.ownProgress());

final memberProgressProvider =
    FutureProvider.autoDispose.family<MemberProgress, int>(
  (ref, id) => _api.memberProgress(id),
);

/// Human-readable message for a failed request.
String describeError(Object error) =>
    error is ApiException ? error.message : 'Could not load data. Check your connection.';
