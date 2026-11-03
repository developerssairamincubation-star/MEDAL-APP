// lib/modules/authority/screens/admin/admin_authority_verification_screen.dart
// Admin Authority Verification and Officer Onboarding Details Screen
// Visually matches the MEDAL Admin Authority Verification design specification.

import 'package:medal/widgets/medal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../../../widgets/medal_logo.dart';

class AdminAuthorityVerificationScreen extends StatefulWidget {
  final Map<String, dynamic>? application;
  final int? initialApplicationId;

  const AdminAuthorityVerificationScreen({
    super.key,
    this.application,
    int? applicationId,
    int? initialApplicationId,
  }) : initialApplicationId = applicationId ?? initialApplicationId;

  @override
  State<AdminAuthorityVerificationScreen> createState() =>
      _AdminAuthorityVerificationScreenState();
}

class _AdminAuthorityVerificationScreenState
    extends State<AdminAuthorityVerificationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _application;
  int? _resolvedApplicationId;
  bool _hasInitialized = false;

  // Selected clearance level for approval
  String _selectedClearanceLevel = 'Level 2 (Inspection & Resolution Lead)';

  final List<String> _clearanceOptions = [
    'Level 1 (Field Officer & Site Inspector)',
    'Level 2 (Inspection & Resolution Lead)',
    'Level 3 (Department Chief & Municipal Commissioner)',
  ];

  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate from constructor if provided
    if (widget.application != null) {
      _application = Map<String, dynamic>.from(widget.application!);
      final rawId = _application!['id'];
      _resolvedApplicationId = widget.initialApplicationId ??
          (rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''));
      _syncClearanceLevel();
      _isLoading = false;
    } else if (widget.initialApplicationId != null) {
      _resolvedApplicationId = widget.initialApplicationId;
      _isLoading = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _initFromWidgetAndRoute();
    }
  }

  void _initFromWidgetAndRoute() {
    Map<String, dynamic>? appData = widget.application;
    int? appId = widget.initialApplicationId ?? _resolvedApplicationId;

    // Check for route arguments if not fully supplied via constructor
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      if (args is int) {
        appId ??= args;
      } else if (args is String) {
        appId ??= int.tryParse(args);
      } else if (args is Map) {
        final map = Map<String, dynamic>.from(args);
        if (map.containsKey('application') && map['application'] is Map) {
          appData ??= Map<String, dynamic>.from(map['application'] as Map);
        } else if (map.containsKey('full_name') || map.containsKey('official_email')) {
          appData ??= map;
        }
        if (map.containsKey('id')) {
          final rawId = map['id'];
          appId ??= rawId is int ? rawId : int.tryParse(rawId.toString());
        }
      }
    }

    if (appData != null) {
      _application = Map<String, dynamic>.from(appData);
      final rawId = _application!['id'];
      _resolvedApplicationId = appId ?? (rawId is int ? rawId : int.tryParse(rawId?.toString() ?? ''));
      _syncClearanceLevel();
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      // Refresh fresh details from backend in background to keep data strictly up to date
      if (_resolvedApplicationId != null) {
        _loadApplicationDetails(_resolvedApplicationId!, background: true);
      }
    } else if (appId != null) {
      _resolvedApplicationId = appId;
      _loadApplicationDetails(appId);
    } else {
      _loadFallbackApplications();
    }
  }

  void _syncClearanceLevel() {
    final rawClearance = _application?['clearance_level']?.toString();
    final appClearance = rawClearance?.trim();
    if (appClearance != null && appClearance.isNotEmpty) {
      if (!_clearanceOptions.contains(appClearance)) {
        _clearanceOptions.add(appClearance);
      }
      _selectedClearanceLevel = appClearance;
    }
    if (!_clearanceOptions.contains(_selectedClearanceLevel)) {
      _clearanceOptions.add(_selectedClearanceLevel);
    }
  }

  Future<void> _loadApplicationDetails(int id, {bool background = false}) async {
    if (!background) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    if (ApiService().isAuthenticated && ApiService().userRole != 'admin') {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Access Denied: Only authenticated System Administrators can access this dashboard.';
        _isLoading = false;
      });
      return;
    }

    try {
      final app = await ApiService().getAuthorityApplication(id);
      if (!mounted) return;
      setState(() {
        _application = app;
        _isLoading = false;
        _errorMessage = null;
        _syncClearanceLevel();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!background || _application == null) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (!background || _application == null) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFallbackApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (ApiService().isAuthenticated && ApiService().userRole != 'admin') {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Access Denied: Only authenticated System Administrators can access this dashboard.';
        _isLoading = false;
      });
      return;
    }

    try {
      final list = await ApiService().getAuthorityApplications(status: 'pending');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (list.isNotEmpty) {
          _application = list.first;
          final rawId = _application!['id'];
          _resolvedApplicationId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          _syncClearanceLevel();
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove() async {
    final app = _application;
    if (app == null || _isProcessingAction) return;

    final int appId = app['id'] is int ? app['id'] : int.parse(app['id'].toString());
    final String officerName = app['full_name']?.toString() ?? 'Officer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Approve Authority Application',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to approve $officerName and onboard them as a verified Authority Official with $_selectedClearanceLevel?',
          style: GoogleFonts.inter(fontSize: 13.5, color: MedalTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: MedalTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm Approval', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);

    try {
      await ApiService().approveAuthorityApplication(
        appId,
        clearanceLevel: _selectedClearanceLevel,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$officerName has been approved and onboarded as an Official.'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );

      // Return true to refresh applications list
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve application: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleReject() async {
    final app = _application;
    if (app == null || _isProcessingAction) return;

    final int appId = app['id'] is int ? app['id'] : int.parse(app['id'].toString());
    final String officerName = app['full_name']?.toString() ?? 'Officer';

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reject Submission',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide an official administrative reason for rejecting $officerName\'s registration. The applicant will see this explanation.',
              style: GoogleFonts.inter(fontSize: 13, color: MedalTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Identity document illegible or employment badge expired',
                hintStyle: GoogleFonts.inter(fontSize: 12.5, color: MedalTheme.gray),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: MedalTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason (min 3 characters).')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm Rejection', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    setState(() => _isProcessingAction = true);

    try {
      await ApiService().rejectAuthorityApplication(appId, reason: reason);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application rejected with reason: $reason'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );

      // Return true to refresh applications list
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _handleBackNavigation() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.adminApplicationsList);
    }
  }

  void _showDocumentViewerDialog({
    required String title,
    required String docUrl,
    required String badgeLabel,
  }) {
    final trimmed = docUrl.trim();
    if (trimmed.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => MedalAlertDialog(
          title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Text(
            'No document file was uploaded for this requirement.',
            style: GoogleFonts.inter(fontSize: 13, color: MedalTheme.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: MedalTheme.primary),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final resolvedUrl = ApiService().resolveImageUrl(trimmed);
    final isPdf = trimmed.toLowerCase().endsWith('.pdf');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111C2D),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: MedalTheme.slateBlue),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6D28D9),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MedalTheme.lavenderBorder),
                    ),
                    child: isPdf
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 56,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'PDF Document Stored',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: MedalTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Text(
                                  trimmed,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: MedalTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: resolvedUrl.isEmpty
                                ? const Center(child: Icon(Icons.insert_drive_file_outlined, size: 48, color: MedalTheme.slateBlue))
                                : Image.network(
                                    resolvedUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.insert_drive_file_outlined,
                                            size: 48,
                                            color: MedalTheme.slateBlue,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Certified Verification File',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: MedalTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MedalTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Close Preview',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // 1. Top Brand Header
                  _buildTopBrandHeader(),

                  // 2. Navigation SubNavBar matching Screenshot 3
                  _buildSubNavBar(),

                  // 3. Body Content
                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrandHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MedalLogo(iconSize: 18),
          const SizedBox(width: 6),
          Text(
            'MEdAL',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111C2D),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          InkWell(
            onTap: _handleBackNavigation,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(
                Icons.arrow_back,
                color: Color(0xFF111C2D),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Authority verification',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111C2D),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: MedalTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading application details...',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: MedalTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Unable to load application',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: MedalTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_resolvedApplicationId != null) {
                    _loadApplicationDetails(_resolvedApplicationId!);
                  } else {
                    _loadFallbackApplications();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: MedalTheme.primary),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _handleBackNavigation,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Return to List'),
              ),
            ],
          ),
        ),
      );
    }

    if (_application == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF6D28D9),
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Application Not Found',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111C2D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The selected Authority application details could not be found.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MedalTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _handleBackNavigation,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Return to List'),
              ),
            ],
          ),
        ),
      );
    }

    try {
      return _buildDetailsContent();
    } catch (e, stack) {
      debugPrint('[MEDAL] Authority Details render error: $e\n$stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Error Rendering Application Details',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: MedalTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_resolvedApplicationId != null) {
                    _loadApplicationDetails(_resolvedApplicationId!);
                  } else {
                    _loadFallbackApplications();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: MedalTheme.primary),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailsContent() {

    final app = _application!;
    final fullName = app['full_name']?.toString() ?? 'Officer';
    final designation = app['designation']?.toString() ?? 'Officer';
    final department = app['department']?.toString() ?? 'Municipal Department';
    final jurisdiction = app['jurisdiction']?.toString() ?? 'Assigned Catchment Sector';
    final email = app['official_email']?.toString() ?? '';
    final phone = app['official_phone']?.toString() ?? '+91 00000 00000';
    final aadhaarDoc = app['aadhaar_document_url']?.toString() ?? '';
    final gazetteDoc = app['employment_document_url']?.toString() ?? '';
    final status = (app['status']?.toString() ?? 'pending').toLowerCase().trim();

    final isPending = status == 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Applicant status badge matching screenshot
          Align(
            alignment: Alignment.centerRight,
            child: _buildApplicantStatusBadge(status),
          ),

          const SizedBox(height: 8),

          // Card 1: Officer Profile Card
          _buildOfficerProfileCard(
            fullName: fullName,
            designation: designation,
            department: department,
            jurisdiction: jurisdiction,
          ),

          const SizedBox(height: 18),

          // Card 2: Uploaded Documents Section
          _buildUploadedDocumentsSection(
            aadhaarDoc: aadhaarDoc,
            gazetteDoc: gazetteDoc,
          ),

          const SizedBox(height: 18),

          // Card 3: Information Details Card
          _buildInformationDetailsCard(
            designation: designation,
            department: department,
            email: email,
            jurisdiction: jurisdiction,
            phone: phone,
          ),

          const SizedBox(height: 18),

          // Section 4: Designated Clearance Authority Level
          _buildClearanceLevelSection(enabled: isPending),

          const SizedBox(height: 22),

          // Section 5: Action Buttons (or status info banner if not pending)
          if (isPending)
            _buildActionButtons()
          else
            _buildCompletedStatusBanner(status, app['rejection_reason']?.toString()),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildApplicantStatusBadge(String status) {
    String label = 'AWAITING APPROVAL';
    Color bg = const Color(0xFFF3E8FF);
    Color text = const Color(0xFF7E22CE);

    if (status == 'approved') {
      label = 'APPROVED & ONBOARDED';
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
    } else if (status == 'rejected') {
      label = 'REJECTED';
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Card 1: Officer Profile Card matching screenshot
  Widget _buildOfficerProfileCard({
    required String fullName,
    required String designation,
    required String department,
    required String jurisdiction,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle in top right matching screenshot 3
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F4FA),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Officer Row with Avatar, Name, Designation
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF1F5F9),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person_rounded,
                              color: Color(0xFF64748B),
                              size: 32,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.inter(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111C2D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      designation,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Department & Jurisdiction Container matching screenshot
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.apartment_rounded,
                      size: 15,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        department,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Jurisdiction: $jurisdiction',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
),
);
}

  /// Card 2: Uploaded Documents Section matching screenshot
  Widget _buildUploadedDocumentsSection({
    required String aadhaarDoc,
    required String gazetteDoc,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Uploaded Documents',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111C2D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '2 Files Ready',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Document 1: Aadhaar Card Copy
        _buildDocumentCard(
          docUrl: aadhaarDoc,
          thumbnailIcon: Icons.badge_outlined,
          title: 'Aadhaar Card Copy',
          badgeText: 'IDENTITY CONFIRMED',
          badgeColor: const Color(0xFF4F46E5),
          actionText: 'View Full',
          actionIcon: Icons.visibility_outlined,
          onAction: () => _showDocumentViewerDialog(
            title: 'Aadhaar Card Copy',
            docUrl: aadhaarDoc,
            badgeLabel: 'IDENTITY CONFIRMED',
          ),
        ),

        const SizedBox(height: 12),

        // Document 2: Gov Employment Gazette
        _buildDocumentCard(
          docUrl: gazetteDoc,
          thumbnailIcon: Icons.verified_outlined,
          title: 'Gov Employment Gazette',
          badgeText: 'STAMP CERTIFIED',
          badgeColor: const Color(0xFF475569),
          actionText: 'Inspect',
          actionIcon: Icons.search_rounded,
          onAction: () => _showDocumentViewerDialog(
            title: 'Gov Employment Gazette',
            docUrl: gazetteDoc,
            badgeLabel: 'STAMP CERTIFIED',
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentThumbnail(String? docUrl, IconData fallbackIcon) {
    final cleanUrl = docUrl?.trim() ?? '';
    final resolvedUrl = cleanUrl.isNotEmpty ? ApiService().resolveImageUrl(cleanUrl) : '';
    final isPdf = cleanUrl.toLowerCase().endsWith('.pdf');
    final isImage = cleanUrl.toLowerCase().endsWith('.jpg') ||
        cleanUrl.toLowerCase().endsWith('.jpeg') ||
        cleanUrl.toLowerCase().endsWith('.png') ||
        cleanUrl.toLowerCase().endsWith('.webp');

    return Container(
      width: 76,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isImage && resolvedUrl.isNotEmpty
          ? Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnailIcon(fallbackIcon),
            )
          : _buildFallbackThumbnailIcon(fallbackIcon, isPdf: isPdf),
    );
  }

  Widget _buildFallbackThumbnailIcon(IconData icon, {bool isPdf = false}) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          isPdf ? Icons.picture_as_pdf_rounded : icon,
          size: 26,
          color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    String? docUrl,
    required IconData thumbnailIcon,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String actionText,
    required IconData actionIcon,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail box
          _buildDocumentThumbnail(docUrl, thumbnailIcon),
          const SizedBox(width: 14),
          // Title & Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111C2D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // Action button
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              // The app theme gives ElevatedButtons an infinite minimum width, which breaks layout in a Row.
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionText,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(actionIcon, size: 14, color: const Color(0xFF4F46E5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 3: Information Details Card matching screenshot
  Widget _buildInformationDetailsCard({
    required String designation,
    required String department,
    required String email,
    required String jurisdiction,
    required String phone,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Designation & Department
          _buildInfoFieldBlock(
            label: 'DESIGNATION & DEPARTMENT',
            topTrailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_rounded, size: 10, color: Color(0xFF7E22CE)),
                  const SizedBox(width: 3),
                  Text(
                    'Gazette Verified',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7E22CE),
                    ),
                  ),
                ],
              ),
            ),
            valueWidget: Text(
              '$designation, $department',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111C2D),
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 2. Official Government Email
          _buildInfoFieldBlock(
            label: 'OFFICIAL GOVERNMENT EMAIL',
            topTrailing: const Icon(
              Icons.mail_outline_rounded,
              size: 14,
              color: Color(0xFF4F46E5),
            ),
            valueWidget: Text(
              email,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Jurisdiction Boundary
          _buildInfoFieldBlock(
            label: 'JURISDICTION BOUNDARY',
            topTrailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 11,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 2),
                Text(
                  'Zone 4 Catchment',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
            valueWidget: Text(
              jurisdiction,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 4. Secure Contact Phone
          _buildInfoFieldBlock(
            label: 'SECURE CONTACT PHONE',
            topTrailing: const Icon(
              Icons.phone_android_rounded,
              size: 13,
              color: Color(0xFF64748B),
            ),
            valueWidget: Text(
              phone,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111C2D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFieldBlock({
    required String label,
    required Widget topTrailing,
    required Widget valueWidget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              topTrailing,
            ],
          ),
          const SizedBox(height: 4),
          valueWidget,
        ],
      ),
    );
  }

  /// Section 4: Clearance Authority Level Dropdown matching screenshot
  Widget _buildClearanceLevelSection({bool enabled = true}) {
    final uniqueOptions = _clearanceOptions.toSet().toList();
    if (!uniqueOptions.contains(_selectedClearanceLevel)) {
      uniqueOptions.add(_selectedClearanceLevel);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Designated Clearance Authority Level',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111C2D),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedClearanceLevel,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              items: uniqueOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(
                    opt,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111C2D),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: enabled
                  ? (val) {
                      if (val != null) {
                        setState(() => _selectedClearanceLevel = val);
                      }
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Grants authority to sign off on environmental grievance closures.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Section 5: Action Buttons matching screenshot
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 1. Approve & Onboard Officer Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isProcessingAction ? null : _handleApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5), // Purple from screenshot
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessingAction
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Approve & Onboard Officer',
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. Reject Submission Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isProcessingAction ? null : _handleReject,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFE4E6), // Light red from screenshot
              foregroundColor: const Color(0xFF991B1B),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFF991B1B)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Reject Submission',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF991B1B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedStatusBanner(String status, String? reason) {
    final isApproved = status == 'approved';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isApproved ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isApproved ? 'Officer Account Activated' : 'Application Rejected',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isApproved ? const Color(0xFF15803D) : const Color(0xFF991B1B),
                ),
              ),
            ],
          ),
          if (!isApproved && reason != null && reason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $reason',
              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF7F1D1D)),
            ),
          ],
        ],
      ),
    );
  }
}
