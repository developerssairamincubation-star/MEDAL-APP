// lib/widgets/mention_text_field.dart
// Multiline text field with "@" autocomplete for officials. Typing "@" opens a
// list that filters as the user types; picking one (tap, or arrow keys + Enter)
// inserts "@Name " and records the official so the post can store the tag.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/api_service.dart';

class MentionedOfficial {
  const MentionedOfficial({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is MentionedOfficial && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

typedef OfficialsFetcher = Future<List<Map<String, dynamic>>> Function(
  String query,
);

class MentionTextField extends StatefulWidget {
  const MentionTextField({
    super.key,
    required this.controller,
    required this.onMentionsChanged,
    this.decoration,
    this.style,
    this.maxLines = 4,
    this.fetchOfficials,
  });

  final TextEditingController controller;
  final ValueChanged<List<MentionedOfficial>> onMentionsChanged;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int maxLines;

  /// Defaults to the officials directory API; injectable for tests.
  final OfficialsFetcher? fetchOfficials;

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  static final RegExp _token = RegExp(r'(?:^|\s)@([^@\n]{0,40})$');

  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  List<MentionedOfficial> _mentions = [];
  String? _query; // text typed after "@", or null when not mentioning
  int _atIndex = -1;
  int _highlight = 0;
  bool _loading = false;
  int _requestId = 0;

  OfficialsFetcher get _fetch =>
      widget.fetchOfficials ??
      (q) => ApiService().searchOfficials(q);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text;

    // Drop tags whose "@Name" was edited or deleted.
    final kept = _mentions.where((m) => text.contains('@${m.name}')).toList();
    if (kept.length != _mentions.length) {
      _mentions = kept;
      widget.onMentionsChanged(List.unmodifiable(_mentions));
    }

    final sel = widget.controller.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    if (cursor < 0 || cursor > text.length) return _closePanel();
    final before = text.substring(0, cursor);
    final m = _token.firstMatch(before);
    if (m == null) return _closePanel();

    final query = m.group(1)!;
    // Right after picking a name the field still reads "@Name "; don't reopen.
    if (_mentions.any((x) => x.name == query.trimRight())) {
      return _closePanel();
    }
    _atIndex = before.lastIndexOf('@');
    if (query == _query) return;
    setState(() {
      _query = query;
      _highlight = 0;
      _loading = true;
    });
    _debounce?.cancel();
    final id = ++_requestId;
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      List<Map<String, dynamic>> res;
      try {
        res = await _fetch(query.trim());
      } catch (_) {
        res = [];
      }
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = res;
        _loading = false;
        _highlight = 0;
      });
    });
  }

  void _closePanel() {
    if (_query == null && _results.isEmpty && !_loading) return;
    _debounce?.cancel();
    _requestId++;
    setState(() {
      _query = null;
      _results = [];
      _loading = false;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_query == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closePanel();
      return KeyEventResult.handled;
    }
    if (_results.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1) % _results.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlight = (_highlight - 1 + _results.length) % _results.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _select(_results[_highlight]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _select(Map<String, dynamic> official) {
    final name = (official['full_name'] ?? '').toString();
    final id = official['id'];
    if (name.isEmpty || id is! int) return;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset.clamp(0, text.length);
    final start = _atIndex.clamp(0, cursor);
    final insert = '@$name ';
    final newText = text.replaceRange(start, cursor, insert);
    final mention = MentionedOfficial(id: id, name: name);
    if (!_mentions.contains(mention)) _mentions = [..._mentions, mention];
    widget.onMentionsChanged(List.unmodifiable(_mentions));
    _closePanel();
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          maxLines: widget.maxLines,
          style: widget.style,
          decoration: widget.decoration,
        ),
        if (_query != null) _buildPanel(),
      ],
    );
  }

  Widget _buildPanel() {
    final q = _query!;
    // A longer phrase with no match is ordinary prose, not a tag attempt.
    if (!_loading && _results.isEmpty && q.contains(' ')) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('mention_panel'),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: _loading && _results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _results.isEmpty
              ? Padding(
                  key: const Key('mention_no_match'),
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    q.isEmpty
                        ? 'No officials available to tag yet.'
                        : 'No officials match "$q".',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final o = _results[i];
                    final name = (o['full_name'] ?? '').toString();
                    final role = [
                      o['designation'],
                      o['department'],
                    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' · ');
                    return InkWell(
                      key: Key('mention_option_$i'),
                      onTap: () => _select(o),
                      child: Container(
                        color: i == _highlight
                            ? const Color(0xFFE8F4FD)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFE8F4FD),
                              child: Icon(
                                Icons.account_balance_rounded,
                                size: 15,
                                color: Color(0xFF0467B6),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111C2D),
                                    ),
                                  ),
                                  if (role.isNotEmpty)
                                    Text(
                                      role,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
