// lib/features/institution/screens/principal/add_staff_screen.dart
// Place at: lib/features/institution/screens/principal/add_staff_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import 'package:medal/widgets/medal_dialog.dart';
import '../../models/member.dart';
import '../../providers/principal_provider.dart';
import '../../widgets/medal_app_bar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/custom_action_button.dart';

/// Add Staff Screen — creates a real Staff account. The Principal is shown the
/// temporary password once, to hand to the teacher.
class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.principalDashboard);
        break;
      case 1:
        context.go(AppRoutes.principalStaffList);
        break;
      case 2:
        break; // Already here
      case 3:
        context.go(AppRoutes.principalProfile);
        break;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref.read(addStaffProvider.notifier).addStaff(
          name: _nameController.text,
          email: _emailController.text,
          department: _departmentController.text,
          designation: _designationController.text,
        );
  }

  Future<void> _showCredentials(NewStaffResult created) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MedalAlertDialog(
        icon: Icons.vpn_key_outlined,
        title: const Text('Staff account created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share these sign-in details with ${created.staff.name}. '
                'The password is shown only once.'),
            const SizedBox(height: 12),
            SelectableText(created.staff.email,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(
              created.temporaryPassword,
              key: const Key('staff_temporary_password'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(
              text: 'Email: ${created.staff.email}\nPassword: ${created.temporaryPassword}',
            )),
            child: const Text('Copy'),
          ),
          ElevatedButton(
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
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addStaffProvider);

    ref.listen<AddStaffState>(addStaffProvider, (prev, next) {
      final created = next.created;
      if (created != null && prev?.created == null) {
        _nameController.clear();
        _emailController.clear();
        _departmentController.clear();
        _designationController.clear();
        _showCredentials(created).then((_) {
          if (mounted) ref.read(addStaffProvider.notifier).reset();
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
      appBar: const MedalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label("Teacher's Name"),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _decoration('Full name', Icons.person_outline_rounded),
              ),
              const SizedBox(height: 12),
              _label("Teacher's Email ID"),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _decoration('name@school.edu', Icons.email_outlined),
              ),
              const SizedBox(height: 12),
              _label('Department (optional)'),
              TextField(
                controller: _departmentController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _decoration('e.g. Science', Icons.apartment_rounded),
              ),
              const SizedBox(height: 12),
              _label('Designation (optional)'),
              TextField(
                controller: _designationController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: _decoration('e.g. Senior Teacher', Icons.badge_outlined),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.vpn_key_outlined, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A temporary password is generated for this account and shown '
                        'once after you add it. Share it with the teacher securely.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomActionButton(
                label: 'Add Staff',
                isLoading: state.isLoading,
                trailingIcon: Icons.person_add_alt_1_rounded,
                onPressed: state.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        items: principalNavItems,
        currentIndex: 2,
        onTap: _onNavTap,
      ),
    );
  }
}
