import 'package:medal/core/services/course_progress_store.dart';
import 'package:medal/modules/authority/models/authority_models.dart';
import 'package:medal/widgets/profile_photo_cropper.dart';
import 'package:medal/widgets/profile_ui.dart';
import 'package:medal/widgets/medal_dialog.dart';
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

  static const Color primaryIndigo = Color(0xFF0467B6);
  static const Color darkNavy = Color(0xFF111C2D);

  @override
  void initState() {
    super.initState();
    _user = ApiService().currentUser;
    CourseProgressStore.instance.ensureLoaded();
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

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => MedalAlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              "Log Out",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.roleSelection,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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

      final rawBytes = await picked.readAsBytes();
      if (!mounted) return;
      // Crop step (move / zoom, circle or square) before the photo is previewed and saved.
      final bytes = await cropProfilePhoto(context, rawBytes);
      if (bytes == null || !mounted) return;
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
        return MedalAlertDialog(
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
        filename: 'profile.png',
        mimeType: 'image/png',
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

                  // 1. Profile hero (shared layout, same as every login)
                  ProfileHeroCard(
                    roleLabel: 'Citizen',
                    name: fullName,
                    email: email,
                    phone: phone,
                    pointsText: 'You have earned 35 points!',
                    photoUrl: resolvedPhotoUrl,
                    isUploading: _isUploadingPhoto,
                    onEdit: _showPhotoOptions,
                    badgeBackground: const Color(0xFFE8F4FD),
                    badgeForeground: primaryIndigo,
                  ),

                  const SizedBox(height: 14),

                  // 2. Earned certifications (only completed courses)
                  ListenableBuilder(
                    listenable: CourseProgressStore.instance,
                    builder: (context, _) => ProfileCertificatesSection(
                      certificates: [
                        for (final c in MockAuthorityRepository.certificates)
                          ProfileCertificate(
                            title: c.title,
                            dateText: c.completionDateText,
                            number: c.certificateNo,
                          ),
                      ],
                      onUpload: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Upload certificate dialog opened"),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onDownload: (cert) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Downloading ${cert.number}..."),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Account management (shared tiles)
                  const ProfileSectionTitle('Account Management'),
                  const SizedBox(height: 10),
                  ProfileAccountTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    subtitle: 'Update your name and phone number',
                    onTap: () => _showEditProfileSheet(context, fullName, phone),
                  ),
                  const SizedBox(height: 8),
                  ProfileLogoutTile(
                    onTap: () => _showLogoutConfirmationDialog(context),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
