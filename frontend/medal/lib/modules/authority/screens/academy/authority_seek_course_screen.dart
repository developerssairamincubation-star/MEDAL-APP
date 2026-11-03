// lib/modules/authority/screens/academy/authority_seek_course_screen.dart
// Course content for the SEEK course opened from "Continue Learning".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/course_progress_store.dart';
import '../../models/authority_models.dart';

class AuthoritySeekCourseScreen extends StatefulWidget {
  const AuthoritySeekCourseScreen({super.key});

  @override
  State<AuthoritySeekCourseScreen> createState() =>
      _AuthoritySeekCourseScreenState();
}

class _AuthoritySeekCourseScreenState extends State<AuthoritySeekCourseScreen> {
  @override
  void initState() {
    super.initState();
    CourseProgressStore.instance.ensureLoaded();
  }

  Future<void> _toggleLesson(SeekLesson lesson) {
    return CourseProgressStore.instance.setLessonDone(
      lesson.key,
      !lesson.completed,
      courseId: SeekCourseContent.courseId,
      allLessonKeys: SeekCourseContent.allLessonKeys,
    );
  }

  static const Color _blue = Color(0xFF0467B6);
  static const Color _navy = Color(0xFF111C2D);

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.parse(SeekCourseContent.sourceUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) {
      await Clipboard.setData(
        const ClipboardData(text: SeekCourseContent.sourceUrl),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the browser. Link copied to clipboard.',
          ),
        ),
      );
    }
  }

  IconData _lessonIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'practice':
        return Icons.science_outlined;
      case 'case_study':
        return Icons.work_outline_rounded;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CourseProgressStore.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final progress = SeekCourseContent.progress;
    final finished = SeekCourseContent.completedLessons ==
        SeekCourseContent.totalLessons;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('seek_course_back_button'),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _navy,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'SEEK Course',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(
              SeekCourseContent.title.replaceAll('\n', ' '),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _navy,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              SeekCourseContent.provider,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2EDF8),
                valueColor: const AlwaysStoppedAnimation<Color>(_blue),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${SeekCourseContent.completedLessons} of ${SeekCourseContent.totalLessons} lessons completed '
              '(${(progress * 100).round()}%)',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF475569),
              ),
            ),
            if (finished) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Course completed. Your certificate is now in My Certificates.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _section('About this course'),
            Text(
              SeekCourseContent.description,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 16),
            _section('What you will learn'),
            ...SeekCourseContent.outcomes.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        o,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.4,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _section('Modules (${SeekCourseContent.modules.length})'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Open a module and tap the circle next to a lesson when you finish it. '
                'Your certificate is issued once every lesson is done.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.35,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ...SeekCourseContent.modules.map(_moduleTile),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('seek_source_link'),
              onPressed: () => _openSource(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                'View the official SEEK course (UNESCO MGIEP)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Source: ${SeekCourseContent.sourceUrl}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: _navy,
      ),
    ),
  );

  Widget _moduleTile(SeekModule m) {
    final status = m.isCompleted
        ? 'Completed'
        : (m.completedLessons > 0 ? 'In progress' : 'Upcoming');
    final statusColor = m.isCompleted
        ? const Color(0xFF16A34A)
        : (m.completedLessons > 0 ? _blue : const Color(0xFF64748B));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD6E4F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: !m.isCompleted && m.completedLessons > 0,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            title: Text(
              'Module ${m.number}: ${m.title}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${m.duration} • ${m.lessons.length} lessons • $status',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  m.summary,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ),
              ...m.lessons.map(
                (l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(_lessonIcon(l.type), size: 18, color: _blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.title,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.duration,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        key: Key('lesson_toggle_${l.number}'),
                        customBorder: const CircleBorder(),
                        onTap: () => _toggleLesson(l),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            l.completed
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: l.completed
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
