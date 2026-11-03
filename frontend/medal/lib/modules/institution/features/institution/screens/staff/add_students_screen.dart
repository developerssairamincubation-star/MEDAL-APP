// lib/modules/institution/features/institution/screens/staff/add_students_screen.dart
// Staff adds students under themselves: one at a time by e-mail, or many from a CSV file.
// Either way the server e-mails each student an invite (see backend /institution/students/*).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medal/widgets/medal_dialog.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../models/member.dart';
import '../../providers/principal_provider.dart';
import '../../widgets/custom_action_button.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/medal_app_bar.dart';

/// A CSV the teacher picked on their device.
class PickedCsv {
  const PickedCsv(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}

typedef CsvPicker = Future<PickedCsv?> Function();

Future<PickedCsv?> pickCsvFromDevice() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    withData: true,
  );
  final file = result?.files.single;
  if (file == null || file.bytes == null) return null;
  return PickedCsv(file.name, file.bytes!);
}

class AddStudentsScreen extends ConsumerStatefulWidget {
  const AddStudentsScreen({super.key, this.csvPicker = pickCsvFromDevice});

  /// Injectable for tests.
  final CsvPicker csvPicker;

  @override
  ConsumerState<AddStudentsScreen> createState() => _AddStudentsScreenState();
}

class _AddStudentsScreenState extends ConsumerState<AddStudentsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _csvMode = false;
  PickedCsv? _csv;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.staffDashboard);
        break;
      case 1:
        context.go(AppRoutes.staffMyClass);
        break;
      case 2:
        context.go(AppRoutes.studentAcademy);
        break;
      case 3:
        context.go(AppRoutes.staffProfile);
        break;
    }
  }

  Future<void> _sendInvite() async {
    FocusScope.of(context).unfocus();
    await ref.read(addStudentsProvider.notifier).inviteOne(
          name: _nameController.text,
          email: _emailController.text,
          department: _departmentController.text,
        );
  }

  Future<void> _chooseCsv() async {
    final picked = await widget.csvPicker();
    if (picked != null && mounted) {
      setState(() => _csv = picked);
      ref.read(addStudentsProvider.notifier).reset();
    }
  }

  Future<void> _uploadCsv() async {
    final csv = _csv;
    if (csv == null) return;
    await ref.read(addStudentsProvider.notifier).inviteCsv(bytes: csv.bytes, filename: csv.name);
  }

  Future<void> _showInviteResult(StudentInviteResult result) async {
    final password = result.temporaryPassword;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MedalAlertDialog(
        icon: result.emailSent ? Icons.mark_email_read_outlined : Icons.vpn_key_outlined,
        title: Text(result.emailSent ? 'Invite sent' : 'Student added'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.emailSent
                  ? 'We e-mailed ${result.student.name} (${result.student.email}) their sign-in details. '
                      'They now appear under your students.'
                  : '${result.student.name} was added, but the invite e-mail could not be sent. '
                      'Share these sign-in details with them. The password is shown only once.',
            ),
            if (password != null) ...[
              const SizedBox(height: 12),
              SelectableText(result.student.email, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SelectableText(
                password,
                key: const Key('student_temporary_password'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ],
        ),
        actions: [
          if (password != null)
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(
                text: 'Email: ${result.student.email}\nPassword: $password',
              )),
              child: const Text('Copy'),
            ),
          ElevatedButton(
            key: const Key('invite_result_done'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8FF),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
        ),
      );

  Widget _modePill(String label, IconData icon, bool selected, Key key, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.primary : Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      );

  Widget _infoBox(IconData icon, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF0F0FA), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      );

  Widget _emailCard(AddStudentsState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Student's Name"),
          TextField(
            key: const Key('student_name_field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Full name', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 12),
          _label("Student's Email ID"),
          TextField(
            key: const Key('student_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _decoration('name@example.com', Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          _label('Department (optional)'),
          TextField(
            key: const Key('student_department_field'),
            controller: _departmentController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendInvite(),
            decoration: _decoration('e.g. Science', Icons.apartment_rounded),
          ),
          const SizedBox(height: 16),
          _infoBox(
            Icons.mark_email_unread_outlined,
            'We e-mail the student an invite with their sign-in details, and they are added under you.',
          ),
          const SizedBox(height: 20),
          CustomActionButton(
            key: const Key('send_invite_button'),
            label: 'Send Invite',
            isLoading: state.isLoading,
            trailingIcon: Icons.send_rounded,
            onPressed: state.isLoading ? null : _sendInvite,
          ),
        ],
      ),
    );
  }

  Widget _csvCard(AddStudentsState state) {
    final bulk = state.bulk;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Upload a CSV file'),
          _infoBox(
            Icons.description_outlined,
            'One student per row with the columns name, email and (optional) department. '
            'Up to 200 students per file. Each student is e-mailed an invite and added under you.',
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              studentCsvTemplate.trim(),
              key: const Key('csv_template_text'),
              style: GoogleFonts.robotoMono(fontSize: 11.5, color: AppTheme.textPrimary, height: 1.5),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('copy_template_button'),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: studentCsvTemplate));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template copied. Paste it into a spreadsheet and save as CSV.')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy template'),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            key: const Key('choose_csv_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: state.isLoading ? null : _chooseCsv,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                color: const Color(0xFFF8F8FF),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _csv == null
                          ? 'Choose CSV file'
                          : '${_csv!.name}  (${(_csv!.bytes.length / 1024).toStringAsFixed(1)} KB)',
                      key: const Key('csv_file_label'),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CustomActionButton(
            key: const Key('upload_csv_button'),
            label: 'Upload & Send Invites',
            isLoading: state.isLoading,
            trailingIcon: Icons.send_rounded,
            onPressed: (_csv == null || state.isLoading) ? null : _uploadCsv,
          ),
          if (bulk != null) ...[
            const SizedBox(height: 16),
            _bulkResult(bulk),
          ],
        ],
      ),
    );
  }

  Widget _bulkResult(BulkInviteResult bulk) {
    final ok = bulk.created > 0;
    return Container(
      key: const Key('csv_result'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Added ${bulk.created} of ${bulk.totalRows} students',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          if (bulk.invitesQueued > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Invites are being e-mailed to ${bulk.invitesQueued} student${bulk.invitesQueued == 1 ? '' : 's'}.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
          if (bulk.credentials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'E-mail is not set up on the server, so no invites were sent. Share these sign-in details:',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            for (final c in bulk.credentials)
              SelectableText('${c['email']}   ${c['temporary_password']}',
                  style: GoogleFonts.robotoMono(fontSize: 11.5)),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(
                text: bulk.credentials.map((c) => '${c['email']},${c['temporary_password']}').join('\n'),
              )),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy all'),
            ),
          ],
          if (bulk.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${bulk.failed} row${bulk.failed == 1 ? '' : 's'} could not be added:',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B)),
            ),
            const SizedBox(height: 4),
            for (final e in bulk.errors.take(50))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'Row ${e.row}${e.email.isEmpty ? '' : ' (${e.email})'}: ${e.error}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            if (bulk.errors.length > 50)
              Text('…and ${bulk.errors.length - 50} more.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addStudentsProvider);

    ref.listen<AddStudentsState>(addStudentsProvider, (prev, next) {
      final invited = next.invited;
      if (invited != null && prev?.invited == null) {
        _nameController.clear();
        _emailController.clear();
        _departmentController.clear();
        _showInviteResult(invited).then((_) {
          if (mounted) ref.read(addStudentsProvider.notifier).reset();
        });
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.statusInactive,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const MedalAppBar(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Students',
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Students you add are listed under you.',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _modePill('By email', Icons.alternate_email_rounded, !_csvMode, const Key('mode_email'), () {
                  setState(() => _csvMode = false);
                }),
                const SizedBox(width: 10),
                _modePill('Upload CSV', Icons.upload_file_rounded, _csvMode, const Key('mode_csv'), () {
                  setState(() => _csvMode = true);
                }),
              ],
            ),
            const SizedBox(height: 14),
            _csvMode ? _csvCard(state) : _emailCard(state),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        items: staffNavItems,
        currentIndex: 1,
        onTap: _onNavTap,
      ),
    );
  }
}
