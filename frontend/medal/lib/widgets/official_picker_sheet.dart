// lib/widgets/official_picker_sheet.dart
// Bottom sheet for tagging officials on a report. The list comes from the officials
// directory API (approved authorities only); nothing here is hard-coded.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/api_service.dart';
import 'mention_text_field.dart';

/// Opens the picker and returns the new selection, or null if it was dismissed.
Future<List<MentionedOfficial>?> showOfficialPicker(
  BuildContext context, {
  required List<MentionedOfficial> selected,
  OfficialsFetcher? fetchOfficials,
}) {
  return showModalBottomSheet<List<MentionedOfficial>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => OfficialPickerSheet(
      initial: selected,
      fetchOfficials: fetchOfficials,
    ),
  );
}

class OfficialPickerSheet extends StatefulWidget {
  const OfficialPickerSheet({
    super.key,
    required this.initial,
    this.fetchOfficials,
  });

  final List<MentionedOfficial> initial;

  /// Defaults to the officials directory API; injectable for tests.
  final OfficialsFetcher? fetchOfficials;

  @override
  State<OfficialPickerSheet> createState() => _OfficialPickerSheetState();
}

class _OfficialPickerSheetState extends State<OfficialPickerSheet> {
  static const Color _primary = Color(0xFF0467B6);

  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  late final Map<int, MentionedOfficial> _selected = {
    for (final o in widget.initial) o.id: o,
  };
  List<Map<String, dynamic>> _results = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetch = widget.fetchOfficials ?? (q) => ApiService().searchOfficials(q, limit: 25);
      final results = await fetch(query.trim());
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = 'Could not load officials. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(value));
  }

  void _toggle(Map<String, dynamic> official) {
    final id = official['id'] as int;
    final name = (official['full_name'] ?? '').toString();
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else if (_selected.length < 10) {
        _selected[id] = MentionedOfficial(id: id, name: name);
      }
    });
  }

  String _subtitle(Map<String, dynamic> official) {
    final parts = [
      official['designation'],
      official['department'],
    ].where((p) => p != null && p.toString().trim().isNotEmpty).map((p) => p.toString());
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tag officials',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111C2D)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Only approved authorities are listed. Tagged officials are notified about this report (max 10).',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('official_search_field'),
                  controller: _search,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name, designation or department',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(child: _buildList()),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('official_picker_done'),
                    onPressed: () => Navigator.pop(context, _selected.values.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    child: Text(_selected.isEmpty ? 'Done' : 'Done (${_selected.length} selected)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5)),
        ),
      );
    }
    if (_results.isEmpty) {
      final searching = _search.text.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            searching ? 'No officials match "${_search.text.trim()}".' : 'No approved officials are available to tag yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, i) {
        final o = _results[i];
        final id = o['id'] as int;
        final subtitle = _subtitle(o);
        return CheckboxListTile(
          key: Key('official_option_$id'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: _primary,
          value: _selected.containsKey(id),
          onChanged: (_) => _toggle(o),
          title: Text((o['full_name'] ?? '').toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 11.5)),
        );
      },
    );
  }
}
