import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/routes/app_routes.dart';
import 'package:medal/widgets/medal_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _user;
  bool _isUploadingPhoto = false;

  static const Color primaryIndigo = Color(0xFF2321BC);
  static const Color darkNavy = Color(0xFF111C2D);
  static const Color slateBlue = Color(0xFF5D6478);
  static const Color lavenderBorder = Color(0xFFC6C5D7);
  static const Color accentPurple = Color(0xFF9333EA);

  @override
  void initState() {
    super.initState();
    _user = ApiService().currentUser;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = await ApiService().getMe();
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = ApiService().currentUser;
        });
      }
    }
  }

  void _showEditProfileSheet(BuildContext context, String currentName, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone == 'Not provided' ? '' : currentPhone);
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text("Full Name", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Enter your full name",
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "e.g. +91 93870 98213",
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryIndigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              final newPhone = phoneController.text.trim();

                              if (newName.length < 2) {
                                setSheetState(() {
                                  errorText = "Full name must be at least 2 characters.";
                                });
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                                errorText = null;
                              });

                              try {
                                final updated = await ApiService().updateProfile(
                                  fullName: newName,
                                  phone: newPhone.isNotEmpty ? newPhone : null,
                                );
                                if (mounted) {
                                  setState(() {
                                    _user = updated;
                                  });
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Profile updated successfully!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isSaving = false;
                                  errorText = e.toString().replaceAll("Exception: ", "");
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Profile Photo",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkNavy,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryIndigo.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: primaryIndigo),
                  ),
                  title: const Text("Take Photo", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Use your camera to snap a new photo"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndPreviewPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryIndigo.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: primaryIndigo),
                  ),
                  title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Select an existing image from your library"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndPreviewPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndPreviewPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      _showPhotoPreviewDialog(picked, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not select image: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPhotoPreviewDialog(XFile picked, Uint8List bytes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Update Profile Photo",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Preview your new profile photo:",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryIndigo, width: 3),
                ),
                child: ClipOval(
                  child: Image.memory(
                    bytes,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _uploadProfilePhoto(picked, bytes);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryIndigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Save Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadProfilePhoto(XFile picked, Uint8List bytes) async {
    setState(() => _isUploadingPhoto = true);
    try {
      await ApiService().updateProfilePhoto(
        fileBytes: bytes,
        filename: picked.name,
        mimeType: picked.mimeType,
      );

      if (!mounted) return;

      setState(() {
        _user = ApiService().currentUser;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Profile photo updated successfully!"),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);

      String errorMsg = e.toString().replaceAll("Exception: ", "");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update profile photo: $errorMsg"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? ApiService().currentUser;
    // Display Anitha Rajshekar if default citizen user, or actual custom user name
    final rawName = user?['full_name']?.toString() ?? '';
    final fullName = (rawName.isEmpty || rawName == 'Citizen User') ? 'Anitha Rajshekar' : rawName;
    final rawEmail = user?['email']?.toString() ?? '';
    final email = (rawEmail.isEmpty || rawEmail == 'citizen@medal.com') ? 'anitharakshekar@medal.gov' : rawEmail;
    final rawPhone = user?['phone']?.toString() ?? '';
    final phone = (rawPhone.isEmpty || rawPhone == 'Not provided') ? '+91 93870 98213' : rawPhone;
    final profileImageUrl = user?['profile_image_url']?.toString();
    final resolvedPhotoUrl = (profileImageUrl != null && profileImageUrl.trim().isNotEmpty)
        ? ApiService().resolveImageUrl(profileImageUrl.trim())
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MedalAppBar(
        showNotification: false,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainScreen(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                child: Icon(Icons.arrow_back, color: Color(0xFF1E293B), size: 24),
              ),
            ),
            const Icon(
              Icons.military_tech_rounded,
              color: primaryIndigo,
              size: 26,
            ),
            const SizedBox(width: 8),
            const Text(
              "MEdAL",
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14, top: 2),
                    child: Text(
                      "My Profile",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: darkNavy,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // 1. Profile Hero Card matching Reference Image 3
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        // CITIZEN Pill Badge in top right
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF0FD),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: lavenderBorder.withValues(alpha: 0.6)),
                            ),
                            child: const Text(
                              "CITIZEN",
                              style: TextStyle(
                                color: primaryIndigo,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),

                        // Avatar with Edit Pencil Icon
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: const Color(0xFFEEF2FF),
                                  child: ClipOval(
                                    child: Image.network(
                                      resolvedPhotoUrl ??
                                          "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=300",
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.bold,
                                              color: primaryIndigo,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              if (_isUploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Pencil Edit Button
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Material(
                                  color: primaryIndigo,
                                  shape: const CircleBorder(
                                    side: BorderSide(color: Colors.white, width: 2),
                                  ),
                                  elevation: 2,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                                    child: const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // User Name
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: darkNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Certified User Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.verified,
                              color: primaryIndigo,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Certified user",
                              style: TextStyle(
                                color: slateBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Email Row
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.mail_outline_rounded,
                              color: primaryIndigo,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: slateBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Phone Row
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.phone_android_rounded,
                              color: primaryIndigo,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: slateBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Points Banner
                        Row(
                          children: const [
                            SizedBox(width: 8),
                            Text("🏆", style: TextStyle(fontSize: 18)),
                            SizedBox(width: 10),
                            Text(
                              "You have earned 35 points!",
                              style: TextStyle(
                                color: darkNavy,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Section Header: Earned Certifications & Upload Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.military_tech_outlined,
                            color: primaryIndigo,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Earned Certifications",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: darkNavy,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Upload certificate dialog opened"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryIndigo,
                          elevation: 0,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Upload",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Certificate Card 1 (Indigo Bar)
                  _buildCertificateCard(
                    stripeColor: primaryIndigo,
                    completedDate: "COMPLETED MAY 2024",
                    title: "Advanced Grievance\nResolution",
                    certificateNo: "MED-8829-XR4",
                    badgeColor: const Color(0xFFEEF2FF),
                    badgeIcon: Icons.verified,
                    iconColor: primaryIndigo,
                  ),

                  const SizedBox(height: 14),

                  // Certificate Card 2 (Purple Bar)
                  _buildCertificateCard(
                    stripeColor: accentPurple,
                    completedDate: "COMPLETED FEB 2024",
                    title: "SDG Alignment & Institutional\nEthics",
                    certificateNo: "MED-1102-G12",
                    badgeColor: const Color(0xFFFAF5FF),
                    badgeIcon: Icons.stars_rounded,
                    iconColor: accentPurple,
                  ),

                  const SizedBox(height: 16),

                  // Centered View All
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "View All",
                        style: TextStyle(
                          color: primaryIndigo,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick profile edit / logout helper buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditProfileSheet(context, fullName, phone),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                        label: const Text(
                          "Edit Profile",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () async {
                          await ApiService().logout();
                          if (!context.mounted) return;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.roleSelection,
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                        label: const Text(
                          "Log Out",
                          style: TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCertificateCard({
    required Color stripeColor,
    required String completedDate,
    required String title,
    required String certificateNo,
    required Color badgeColor,
    required IconData badgeIcon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: stripeColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 16, top: 14, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Completed date and badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                completedDate,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  badgeIcon,
                  color: iconColor,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: darkNavy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          // Bottom Row: Certificate No. and Download Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Certificate No.",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    certificateNo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: darkNavy,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Downloading $certificateNo..."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
],
),
),
);
}
}