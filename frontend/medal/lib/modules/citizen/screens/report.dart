import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/models/selected_location.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/widgets/location_picker.dart';
import 'package:medal/widgets/medal_app_bar.dart';


/// Displays the "Cancel Reporting" confirmation modal dialog.
/// Returns true if the user confirmed "Yes" (exit), false if "No" (stay).
Future<bool?> showCancelReportingDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Banner with plain gradient & circular close icon
            Container(
              width: double.infinity,
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0467B6), Color(0xFF111C2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFF0467B6),
                    size: 26,
                  ),
                ),
              ),
            ),

            // Body content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                children: [
                  const Text(
                    "Cancel Reporting",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Are you sure to exit the reporting page? The changes you have made will not be saved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // "No" primary action button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0467B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        "No",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // "Yes" secondary text button
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      "Yes",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ReportScreen extends StatefulWidget {
  final VoidCallback? onCancelReporting;
  const ReportScreen({super.key, this.onCancelReporting});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController =
      TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  SelectedLocation? _confirmedLocation;
  bool _hasConfirmedLocation = false;

  String selectedCategory = "Workplace Conduct";
  String selectedSdg = "SDG 8: Decent Work and Economic Growth";
  String selectedImpact = "Medium";
  String selectedEquity = "Standard Urban Zone";
  String selectedPostAs = "Public";
  String selectedOfficial = "@elenarodriguez";

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  bool _isAnalyzingSdg = false;
  Map<String, dynamic>? _aiSdgResult;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  final List<String> categories = const [
    "Workplace Conduct",
    "Road & Potholes",
    "Garbage & Solid Waste",
    "Water Supply & Leakage",
    "Streetlight & Lighting",
    "Drainage & Sewage",
    "Health & Sanitation",
    "Educational Infrastructure",
    "Environment & Greenery",
    "Other Civic Concern",
  ];

  final List<Map<String, dynamic>> sdgList = const [
    {
      "number": 1,
      "title": "No\nPoverty",
      "fullName": "SDG 1: No Poverty",
      "color": Color(0xFFE5243B),
    },
    {
      "number": 2,
      "title": "Zero\nHunger",
      "fullName": "SDG 2: Zero Hunger",
      "color": Color(0xFFDDA63A),
    },
    {
      "number": 3,
      "title": "Good\nHealth",
      "fullName": "SDG 3: Good Health and Well-being",
      "color": Color(0xFF4C9F38),
    },
    {
      "number": 4,
      "title": "Quality\nEducation",
      "fullName": "SDG 4: Quality Education",
      "color": Color(0xFFC5192D),
    },
    {
      "number": 5,
      "title": "Gender\nEquality",
      "fullName": "SDG 5: Gender Equality",
      "color": Color(0xFFEF4444),
    },
    {
      "number": 6,
      "title": "Clean\nWater",
      "fullName": "SDG 6: Clean Water and Sanitation",
      "color": Color(0xFF26BDE2),
    },
    {
      "number": 7,
      "title": "Affordable\nEnergy",
      "fullName": "SDG 7: Affordable and Clean Energy",
      "color": Color(0xFFFCC30B),
    },
    {
      "number": 8,
      "title": "Decent\nWork",
      "fullName": "SDG 8: Decent Work and Economic Growth",
      "color": Color(0xFFA21942),
    },
    {
      "number": 9,
      "title": "Industry &\nInnovation",
      "fullName": "SDG 9: Industry, Innovation and Infrastructure",
      "color": Color(0xFFFD6925),
    },
    {
      "number": 10,
      "title": "Reduced\nInequity",
      "fullName": "SDG 10: Reduced Inequalities",
      "color": Color(0xFFDD1367),
    },
    {
      "number": 11,
      "title": "Sustainable\nCities",
      "fullName": "SDG 11: Sustainable Cities and Communities",
      "color": Color(0xFFFD9D24),
    },
    {
      "number": 12,
      "title": "Responsible\nConsumption",
      "fullName": "SDG 12: Responsible Consumption and Production",
      "color": Color(0xFFBF8B2E),
    },
    {
      "number": 13,
      "title": "Climate\nAction",
      "fullName": "SDG 13: Climate Action",
      "color": Color(0xFF3F7E44),
    },
    {
      "number": 14,
      "title": "Life Below\nWater",
      "fullName": "SDG 14: Life Below Water",
      "color": Color(0xFF0A97D9),
    },
    {
      "number": 15,
      "title": "Life on\nLand",
      "fullName": "SDG 15: Life on Land",
      "color": Color(0xFF56C02B),
    },
    {
      "number": 16,
      "title": "Peace &\nJustice",
      "fullName": "SDG 16: Peace, Justice and Strong Institutions",
      "color": Color(0xFF00689D),
    },
    {
      "number": 17,
      "title": "Partnership\nfor Goals",
      "fullName": "SDG 17: Partnerships for the Goals",
      "color": Color(0xFF19486A),
    },
  ];

  final List<String> officialsList = const [
    "@elenarodriguez",
    "@Jane_doe",
    "@Marcus_Chen",
    "@Ward_Supervisor",
    "@Health_Inspector",
  ];

  final List<String> postAsOptions = const [
    "Public",
    "Anonymous",
    "Restricted to Ward",
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = picked;
          _imageBytes = bytes;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not pick image: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
    });
  }

  Future<void> _handleAnalyzeSdg() async {
    final subject = titleController.text.trim();
    final category = selectedCategory;
    final description = descriptionController.text.trim();

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a detailed description before analyzing with AI."),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isAnalyzingSdg) return;

    setState(() {
      _isAnalyzingSdg = true;
    });

    try {
      final result = await ApiService().analyzeSdg(
        subject: subject,
        category: category,
        description: description,
        evidenceBytes: _imageBytes,
        evidenceFilename: _selectedImage?.name,
        evidenceMimeType: _selectedImage?.mimeType,
        imageUrl: imageUrlController.text.trim().isNotEmpty
            ? imageUrlController.text.trim()
            : null,
      );

      if (!mounted) return;

      setState(() {
        _aiSdgResult = result;
        final primaryId = result['primary_sdg'];
        if (primaryId != null) {
          final matched = sdgList.firstWhere(
            (item) => item['number'] == primaryId,
            orElse: () => {},
          );
          if (matched.isNotEmpty && matched['fullName'] != null) {
            selectedSdg = matched['fullName'] as String;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "AI suggested: ${result['primary_sdg_name'] ?? 'SDG ${result['primary_sdg']}'}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("AI analysis is currently unavailable. You can select the SDG manually."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingSdg = false;
        });
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0467B6)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0467B6)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCancelReporting() async {
    final shouldExit = await showCancelReportingDialog(context);
    if (!mounted) return;
    if (shouldExit == true) {
      if (widget.onCancelReporting != null) {
        widget.onCancelReporting!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScreen(initialIndex: 0),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final location = locationController.text.trim();
    final directUrl = imageUrlController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in all required fields (Subject, Description).";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields (Subject, Description)."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_hasConfirmedLocation || _confirmedLocation == null) {
      setState(() {
        _errorMessage = "Please select and confirm the incident location.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select and confirm the incident location."),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String? finalImageUrl = directUrl.isNotEmpty ? directUrl : null;

      if (_selectedImage != null && _imageBytes != null) {
        try {
          final uploadedPath = await ApiService().uploadEvidence(
            fileBytes: _imageBytes!,
            filename: _selectedImage!.name,
            mimeType: _selectedImage!.mimeType,
          );
          finalImageUrl = uploadedPath;
        } catch (_) {}
      }

      final resolvedLocation = _confirmedLocation!.address.isNotEmpty
          ? _confirmedLocation!.address
          : (location.isNotEmpty ? location : '${_confirmedLocation!.latitude}, ${_confirmedLocation!.longitude}');

      final complaint = await ApiService().createComplaint(
        title: title,
        description: description,
        category: selectedCategory.toLowerCase().replaceAll(' ', '_'),
        location: resolvedLocation,
        latitude: _confirmedLocation!.latitude,
        longitude: _confirmedLocation!.longitude,
        locationAddress: _confirmedLocation!.address,
        imageUrl: finalImageUrl,
        sdgAlignment: selectedSdg,
        impactLevel: selectedImpact,
        equityClassification: selectedEquity,
      );

      if (!mounted) return;

      final complaintId = complaint['id'] ?? 'New';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text("Report #$complaintId submitted successfully!"),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainScreen(initialIndex: 1),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0467B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MedalAppBar(
        showNotification: false,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _handleCancelReporting,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                child: Icon(Icons.arrow_back, color: Color(0xFF1E293B), size: 24),
              ),
            ),
            const Icon(
              Icons.military_tech_rounded,
              color: primaryColor,
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
      body: PopScope(
        canPop: widget.onCancelReporting != null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && widget.onCancelReporting == null) {
            _handleCancelReporting();
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Page Headline matching reference
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Report Grievance",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(
                    width: 0,
                    height: 0,
                    child: Text(
                      "Citizen Civic Report",
                      style: TextStyle(fontSize: 0.001, color: Colors.transparent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

            // 1. SUBJECT & CATEGORY CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SUBJECT",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Brief descriptive title",
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "CATEGORY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCategory = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. REAL-TIME LOCATION PICKER
            LocationPickerWidget(
              initialLocation: _confirmedLocation,
              onLocationConfirmed: (loc) {
                if (loc != null) {
                  setState(() {
                    _confirmedLocation = loc;
                    _hasConfirmedLocation = true;
                    locationController.text = loc.address;
                    _errorMessage = null;
                  });
                }
              },
              onLocationChanged: (loc) {
                if (loc != null) {
                  setState(() {
                    _confirmedLocation = loc;
                    locationController.text = loc.address;
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // 3. EVIDENCE CAPTURE & DETAILED DESCRIPTION CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Evidence Capture",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        "Required",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dashed Photo Upload Box
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      child: _imageBytes != null
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _imageBytes!,
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: _removeImage,
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Color(0xFFEF4444),
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B), size: 26),
                                SizedBox(height: 4),
                                Text(
                                  "Add Photo",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "DETAILED DESCRIPTION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Textarea with bottom right tool icons
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            hintText: "Describe the incident in detail...",
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Icon(Icons.alternate_email, size: 17, color: Color(0xFF94A3B8)),
                              SizedBox(width: 10),
                              Icon(Icons.sentiment_satisfied_alt, size: 17, color: Color(0xFF94A3B8)),
                              SizedBox(width: 10),
                              Icon(Icons.send_rounded, size: 17, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sensitive Material Warning Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Text(
                      "Posting sensitive material—including explicit nudity, graphic violence, or hate speech—is strictly prohibited. Any content violating these guidelines will be immediately reported and permanently removed from the platform.",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFDC2626),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "TAG OFFICIALS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOfficial,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                    items: officialsList.map((off) {
                      return DropdownMenuItem<String>(
                        value: off,
                        child: Text(off),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedOfficial = val);
                    },
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE0E7FF)),
                    ),
                    child: const Text(
                      "Above mentioned officials will be notified regarding the reported grievance.",
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. POST IT AS CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "POST IT AS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPostAs,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                    items: postAsOptions.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedPostAs = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. SDG ALIGNMENT CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.auto_awesome, color: primaryColor, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "SDG Alignment",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      if (_isAnalyzingSdg)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Analyzing grievance...",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: _handleAnalyzeSdg,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A82D2), Color(0xFF0467B6)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0467B6).withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 13),
                                SizedBox(width: 5),
                                Text(
                                  "Analyze with AI",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select the Sustainable Development Goals impacted by this grievance.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  if (_aiSdgResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Color(0xFF16A34A), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "✨ AI Suggested: ${_aiSdgResult!['primary_sdg_name'] ?? 'SDG ${_aiSdgResult!['primary_sdg']}'}",
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              if (_aiSdgResult!['confidence'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${((_aiSdgResult!['confidence'] as num) * 100).toInt()}% match",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_aiSdgResult!['reason'] != null &&
                              (_aiSdgResult!['reason'] as String).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _aiSdgResult!['reason'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (_aiSdgResult!['secondary_sdgs'] != null &&
                              (_aiSdgResult!['secondary_sdgs'] as List).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  "Related:",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                ...(_aiSdgResult!['secondary_sdgs'] as List).map((secId) {
                                  final secNum = secId as int;
                                  final secMatch = sdgList.firstWhere(
                                    (s) => s['number'] == secNum,
                                    orElse: () => {'title': 'SDG $secNum'},
                                  );
                                  final cleanTitle =
                                      (secMatch['title'] as String).replaceAll('\n', ' ');
                                  return InkWell(
                                    onTap: () {
                                      final match = sdgList.firstWhere(
                                        (s) => s['number'] == secNum,
                                        orElse: () => {},
                                      );
                                      if (match.isNotEmpty && match['fullName'] != null) {
                                        setState(() {
                                          selectedSdg = match['fullName'] as String;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: Text(
                                        "SDG $secNum: $cleanTitle",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Horizontal SDG Cards
                  SizedBox(
                    height: 136,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sdgList.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final sdg = sdgList[index];
                        final isSelected = selectedSdg == sdg["fullName"];
                        final isAiPrimary = _aiSdgResult != null &&
                            _aiSdgResult!['primary_sdg'] == sdg['number'];
                        final isAiSecondary = _aiSdgResult != null &&
                            _aiSdgResult!['secondary_sdgs'] is List &&
                            (_aiSdgResult!['secondary_sdgs'] as List).contains(sdg['number']);

                        Color borderColor = const Color(0xFFE2E8F0);
                        double borderWidth = 1.0;
                        if (isSelected) {
                          borderColor = primaryColor;
                          borderWidth = 2.0;
                        } else if (isAiPrimary) {
                          borderColor = const Color(0xFF16A34A);
                          borderWidth = 2.0;
                        } else if (isAiSecondary) {
                          borderColor = const Color(0xFF86EFAC);
                          borderWidth = 1.5;
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedSdg = sdg["fullName"] as String;
                            });
                          },
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: borderColor,
                                width: borderWidth,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                else if (isAiPrimary)
                                  BoxShadow(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isAiPrimary) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "✨ AI Pick",
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ] else if (isAiSecondary) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "Related",
                                      style: TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: sdg["color"] as Color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${sdg["number"]}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  sdg["title"] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? primaryColor : const Color(0xFF334155),
                                    height: 1.1,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. PRIMARY SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Submitting Report...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "Submit Formal Report",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
}