import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medal/core/models/image_analysis_result.dart';
import 'package:medal/core/services/api_service.dart';
import 'package:medal/core/services/ml_analysis_service.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/widgets/medal_app_bar.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController =
      TextEditingController(text: "2nd street, medavakkam");
  final TextEditingController imageUrlController = TextEditingController();

  String selectedCategory = "Workplace Conduct";
  String? selectedSdg;
  String selectedImpact = "Medium";
  String selectedEquity = "Standard Urban Zone";
  String selectedPostAs = "Public";
  String selectedOfficial = "@elenarodriguez";

  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  String? _errorMessage;

  // AI & Computer Vision Analysis State
  bool _isAnalyzingImage = false;
  ImageAnalysisResult? _aiAnalysisResult;
  String? _aiStatusMessage;

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
          _isAnalyzingImage = true;
          _aiAnalysisResult = null;
          _aiStatusMessage = null;
        });
        // Run AI Analysis concurrently — never blocks image preview or reporting
        _runAiAnalysis(bytes, picked.name, picked.mimeType);
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

  Future<void> _runAiAnalysis(Uint8List bytes, String filename, String? mimeType) async {
    try {
      final result = await MlAnalysisService().analyzeImage(
        imageBytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        _isAnalyzingImage = false;
        _aiAnalysisResult = result;
        if (result.success && result.sdgs.isNotEmpty && result.issue.category != 'unknown') {
          // Auto-select primary suggested SDG
          final topId = result.sdgs.first.id;
          final match = sdgList.firstWhere(
            (s) => s["number"] == topId,
            orElse: () => <String, dynamic>{},
          );
          if (match.isNotEmpty && match["fullName"] != null) {
            selectedSdg = match["fullName"] as String;
          }

          // Auto-align civic issue category
          if (result.issue.category == 'waste_dumping') {
            selectedCategory = "Garbage & Solid Waste";
          } else if (result.issue.category == 'road_damage') {
            selectedCategory = "Road & Potholes";
          } else if (result.issue.category == 'water_leakage') {
            selectedCategory = "Water Supply & Leakage";
          } else if (result.issue.category == 'streetlight_damage') {
            selectedCategory = "Streetlight & Lighting";
          } else if (result.issue.category == 'tree_damage') {
            selectedCategory = "Environment & Greenery";
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "AI detected ${result.issue.label} — Selected SDG $topId automatically!",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          _aiStatusMessage = result.message.isNotEmpty
              ? result.message
              : "The image could not be confidently classified. Please select the SDG manually.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingImage = false;
        _aiStatusMessage = "AI analysis unavailable. Please select the SDG manually.";
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _isAnalyzingImage = false;
      _aiAnalysisResult = null;
      _aiStatusMessage = null;
      selectedSdg = null;
    });
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
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4F46E5)),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF4F46E5)),
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

  void _showCancelReportingDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner with circuit gradient & circular close icon
              Container(
                width: double.infinity,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
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
                      color: Color(0xFF4F46E5),
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
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "No",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // "Yes" secondary text button
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(initialIndex: 0),
                          ),
                          (route) => false,
                        );
                      },
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

  Future<void> _handleSubmit() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final location = locationController.text.trim();
    final directUrl = imageUrlController.text.trim();

    if (title.isEmpty || description.isEmpty || location.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in the title, location, and description.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields (Subject, Description)."),
          backgroundColor: Colors.redAccent,
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

      final complaint = await ApiService().createComplaint(
        title: title,
        description: description,
        category: selectedCategory.toLowerCase().replaceAll(' ', '_'),
        location: location,
        imageUrl: finalImageUrl,
        sdgAlignment: selectedSdg,
        impactLevel: selectedImpact,
        equityClassification: selectedEquity,
        aiDetectedIssue: (_aiAnalysisResult != null && _aiAnalysisResult!.issue.category != 'unknown')
            ? _aiAnalysisResult!.issue.category
            : null,
        aiIssueConfidence: (_aiAnalysisResult != null && _aiAnalysisResult!.issue.confidence > 0)
            ? _aiAnalysisResult!.issue.confidence
            : null,
        aiSuggestedSdgs: (_aiAnalysisResult != null && _aiAnalysisResult!.sdgs.isNotEmpty)
            ? _aiAnalysisResult!.toJsonString()
            : null,
        aiAnalysisStatus: _aiAnalysisResult != null
            ? (_aiAnalysisResult!.success && _aiAnalysisResult!.issue.category != 'unknown'
                ? 'success'
                : 'unknown')
            : null,
        aiModelVersion: 'yolo26n.pt',
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
    const primaryColor = Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MedalAppBar(
        showNotification: false,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _showCancelReportingDialog,
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
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _showCancelReportingDialog();
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

            // 2. GPS STATUS / MAP CARD
            Container(
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
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map graphic container with circular radar pin
                  Container(
                    height: 130,
                    width: double.infinity,
                    color: const Color(0xFF334155),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Stylized blueprint grid
                        CustomPaint(
                          size: const Size(double.infinity, 130),
                          painter: _MapGridPainter(),
                        ),
                        // Radar ring
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(alpha: 0.25),
                          ),
                        ),
                        // Radar pin
                        const Icon(
                          Icons.location_on,
                          color: primaryColor,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  // Bottom bar with GPS STATUS and Location secured badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "GPS STATUS",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locationController.text,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Location secured",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10.5,
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

                  // Dashed Photo Upload Box + AI Analyze Button Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          width: 96,
                          height: 96,
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
                                        width: 96,
                                        height: 96,
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
                      const SizedBox(width: 14),
                      // AI Analyze action button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_imageBytes == null || _isAnalyzingImage)
                                    ? (_imageBytes == null ? _showImageSourceDialog : null)
                                    : () {
                                        if (_imageBytes != null && _selectedImage != null) {
                                          setState(() {
                                            _isAnalyzingImage = true;
                                            _aiAnalysisResult = null;
                                            _aiStatusMessage = null;
                                          });
                                          _runAiAnalysis(_imageBytes!, _selectedImage!.name, _selectedImage!.mimeType);
                                        }
                                      },
                                icon: _isAnalyzingImage
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                                label: Text(
                                  _isAnalyzingImage
                                      ? "Analyzing..."
                                      : (_imageBytes != null ? "Analyze with AI" : "Upload Evidence"),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _imageBytes != null
                                  ? "Tap to run YOLO AI & auto-select correct SDG"
                                  : "Add a photo to enable instant AI civic analysis",
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      if (_imageBytes != null)
                        InkWell(
                          onTap: _isAnalyzingImage
                              ? null
                              : () {
                                  if (_imageBytes != null && _selectedImage != null) {
                                    setState(() {
                                      _isAnalyzingImage = true;
                                      _aiAnalysisResult = null;
                                      _aiStatusMessage = null;
                                    });
                                    _runAiAnalysis(_imageBytes!, _selectedImage!.name, _selectedImage!.mimeType);
                                  }
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isAnalyzingImage) ...[
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.8, color: primaryColor),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Analyzing...",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor),
                                  ),
                                ] else ...[
                                  const Icon(Icons.refresh_rounded, size: 14, color: primaryColor),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "Re-Analyze",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryColor),
                                  ),
                                ],
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
                  const SizedBox(height: 14),

                  // ── AI State 1: Active Analysis Spinner ──
                  if (_isAnalyzingImage) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "✨ AI Analysis in Progress",
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Scanning evidence with YOLO to detect civic issues & SDGs...",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── AI State 2: Successful AI Alignment Suggestions ──
                  if (!_isAnalyzingImage &&
                      _aiAnalysisResult != null &&
                      _aiAnalysisResult!.sdgs.isNotEmpty &&
                      _aiAnalysisResult!.issue.category != 'unknown') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                "✨ AI Suggested Alignment",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Confidence: ${(_aiAnalysisResult!.issue.confidence * 100).toInt()}%",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Detected issue: ${_aiAnalysisResult!.issue.label}",
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _aiAnalysisResult!.sdgs.map((sdg) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  "SDG ${sdg.id} — ${sdg.name} (${(sdg.confidence * 100).toInt()}% relevance)",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "💡 Suggestions applied. You can freely change or tap any SDG card below.",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── AI State 3: Informational / Fallback Notice ──
                  if (!_isAnalyzingImage &&
                      _aiStatusMessage != null &&
                      (_aiAnalysisResult == null ||
                          _aiAnalysisResult!.issue.category == 'unknown' ||
                          _aiAnalysisResult!.sdgs.isEmpty)) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiStatusMessage!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

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
                        final isAiSuggested = _aiAnalysisResult != null &&
                            _aiAnalysisResult!.sdgs.any((s) => s.id == sdg["number"]);
                        final suggestedItem = isAiSuggested
                            ? _aiAnalysisResult!.sdgs.firstWhere((s) => s.id == sdg["number"])
                            : null;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedSdg = sdg["fullName"] as String;
                            });
                          },
                          child: Container(
                            width: 96,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : (isAiSuggested
                                        ? const Color(0xFF22C55E)
                                        : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2.0 : (isAiSuggested ? 1.5 : 1.0),
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isAiSuggested) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    margin: const EdgeInsets.only(bottom: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      suggestedItem != null
                                          ? "${(suggestedItem.confidence * 100).toInt()}% AI"
                                          : "AI Pick",
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                                Container(
                                  width: 42,
                                  height: 42,
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
                                      fontSize: 19,
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

/// Painter for the subtle blueprint grid in the map card
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF475569).withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}