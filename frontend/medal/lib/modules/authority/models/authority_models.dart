// lib/modules/authority/models/authority_models.dart
// Data models and mock datasets for the MEDAL Authority Module.
// NOTE: Mock data is utilized here until Phase 2 backend APIs are connected.

import 'package:flutter/material.dart';

enum AuthorityComplaintStatus {
  assigned('Assigned', Color(0xFF0467B6), Color(0xFFE8F4FD)),
  reviewing('Reviewing', Color(0xFFD97706), Color(0xFFFEF3C7)),
  inProgress('In Progress', Color(0xFF035293), Color(0xFFE8F4FD)),
  completed('Completed', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  rejected('Rejected', Color(0xFFDC2626), Color(0xFFFEE2E2)),
  redirected('Redirected', Color(0xFF7C3AED), Color(0xFFF3E8FF));

  final String label;
  final Color color;
  final Color backgroundColor;

  const AuthorityComplaintStatus(this.label, this.color, this.backgroundColor);
}

enum AuthorityPriority {
  critical('Critical', Color(0xFFDC2626), Color(0xFFFEE2E2)),
  high('High', Color(0xFFEA580C), Color(0xFFFFEDD5)),
  medium('Medium', Color(0xFFD97706), Color(0xFFFEF3C7)),
  low('Low', Color(0xFF16A34A), Color(0xFFDCFCE7));

  final String label;
  final Color color;
  final Color backgroundColor;

  const AuthorityPriority(this.label, this.color, this.backgroundColor);
}

class SdgInfo {
  final int number;
  final String title;
  final String description;
  final Color color;

  const SdgInfo({
    required this.number,
    required this.title,
    required this.description,
    required this.color,
  });
}

class AuthorityComplaint {
  final String id;
  final int? backendId;
  final String title;
  final String description;
  final String category;
  final String ward;
  final String address;
  final double latitude;
  final double longitude;
  AuthorityComplaintStatus status;
  final AuthorityPriority priority;
  final SdgInfo sdg;
  final List<String> evidenceImages;
  final int upvotes;
  final int commentsCount;
  final DateTime reportedAt;
  final String reportedBy;
  final String? citizenProfileImageUrl;
  String? officerNotes;
  String? rejectionReason;
  String? redirectedDepartment;
  String? redirectionReason;

  AuthorityComplaint({
    required this.id,
    this.backendId,
    required this.title,
    required this.description,
    required this.category,
    required this.ward,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.priority,
    required this.sdg,
    required this.evidenceImages,
    required this.upvotes,
    required this.commentsCount,
    required this.reportedAt,
    required this.reportedBy,
    this.citizenProfileImageUrl,
    this.officerNotes,
    this.rejectionReason,
    this.redirectedDepartment,
    this.redirectionReason,
  });

  factory AuthorityComplaint.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final int? backendId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final String complaintIdStr = 'CMP-2026-${backendId ?? (DateTime.now().millisecondsSinceEpoch % 10000)}';

    // Status mapping
    final rawStatus = (map['status'] ?? 'submitted').toString().toLowerCase().trim();
    AuthorityComplaintStatus status;
    switch (rawStatus) {
      case 'assigned':
        status = AuthorityComplaintStatus.assigned;
        break;
      case 'under_review':
      case 'reviewing':
        status = AuthorityComplaintStatus.reviewing;
        break;
      case 'in_progress':
        status = AuthorityComplaintStatus.inProgress;
        break;
      case 'resolved':
      case 'completed':
        status = AuthorityComplaintStatus.completed;
        break;
      case 'rejected':
        status = AuthorityComplaintStatus.rejected;
        break;
      case 'redirected':
        status = AuthorityComplaintStatus.redirected;
        break;
      default:
        // Default to assigned for authority viewing
        status = AuthorityComplaintStatus.assigned;
        break;
    }

    // Priority mapping from impact_level
    final rawImpact = (map['impact_level'] ?? 'Medium').toString().toLowerCase().trim();
    AuthorityPriority priority;
    if (rawImpact.contains('critical')) {
      priority = AuthorityPriority.critical;
    } else if (rawImpact.contains('high')) {
      priority = AuthorityPriority.high;
    } else if (rawImpact.contains('low')) {
      priority = AuthorityPriority.low;
    } else {
      priority = AuthorityPriority.medium;
    }

    // SDG parsing
    final rawSdg = (map['sdg_alignment'] ?? 'SDG 11').toString();
    int sdgNum = 11;
    final match = RegExp(r'\d+').firstMatch(rawSdg);
    if (match != null) {
      sdgNum = int.tryParse(match.group(0)!) ?? 11;
    }
    final sdg = SdgInfo(
      number: sdgNum,
      title: 'SDG $sdgNum',
      description: rawSdg,
      color: sdgNum == 13
          ? const Color(0xFF3F7E44)
          : (sdgNum == 11 ? const Color(0xFFFD9D24) : const Color(0xFF0467B6)),
    );

    // Evidence images
    final List<String> evidence = [];
    final imgUrl = map['image_url']?.toString();
    if (imgUrl != null && imgUrl.trim().isNotEmpty) {
      evidence.add(imgUrl.trim());
    }

    // Ward extraction from location or jurisdiction
    final loc = (map['location_address'] ?? map['location'] ?? 'Municipal Zone').toString();
    String ward = 'Ward 14';
    final wardMatch = RegExp(r'Ward\s*\d+', caseSensitive: false).firstMatch(loc);
    if (wardMatch != null) {
      ward = wardMatch.group(0)!;
    }

    DateTime reportedAt;
    try {
      reportedAt = map['created_at'] != null ? DateTime.parse(map['created_at'].toString()).toLocal() : DateTime.now();
    } catch (_) {
      reportedAt = DateTime.now();
    }

    return AuthorityComplaint(
      id: complaintIdStr,
      backendId: backendId,
      title: (map['title'] ?? 'Civic Grievance').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? 'General').toString(),
      ward: ward,
      address: loc,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 80.2435,
      status: status,
      priority: priority,
      sdg: sdg,
      evidenceImages: evidence,
      upvotes: map['upvotes_count'] is int ? map['upvotes_count'] : (int.tryParse(map['upvotes_count']?.toString() ?? '0') ?? 0),
      commentsCount: map['comments_count'] is int ? map['comments_count'] : (int.tryParse(map['comments_count']?.toString() ?? '0') ?? 0),
      reportedAt: reportedAt,
      reportedBy: (map['citizen_name'] ?? 'Citizen').toString(),
      citizenProfileImageUrl: map['profile_image_url']?.toString(),
      officerNotes: map['officer_notes']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
    );
  }

  int? get numericId {
    if (backendId != null) return backendId;
    final direct = int.tryParse(id.trim());
    if (direct != null) return direct;
    final clean = id.trim();
    if (clean.contains('-')) {
      return int.tryParse(clean.split('-').last);
    }
    return null;
  }
}

class AuthorityCourse {
  final String id;
  final String title;
  final String department;
  final int totalModules;
  final int completedModules;
  final double progress;
  final String duration;
  final String level;
  final String instructor;
  final String? badgeText;
  final double? rating;
  final String? imageAsset;
  final String? buttonActionText;
  final bool isFeatured;

  const AuthorityCourse({
    required this.id,
    required this.title,
    required this.department,
    required this.totalModules,
    required this.completedModules,
    required this.progress,
    required this.duration,
    required this.level,
    required this.instructor,
    this.badgeText,
    this.rating,
    this.imageAsset,
    this.buttonActionText,
    this.isFeatured = false,
  });
}

class AuthorityCertificate {
  final String id;
  final String title;
  final String issuedBy;
  final String issueDate;
  final String credentialUrl;
  final String grade;
  final String certificateNo;
  final String completionDateText;
  final String badgeType;

  const AuthorityCertificate({
    required this.id,
    required this.title,
    required this.issuedBy,
    required this.issueDate,
    required this.credentialUrl,
    required this.grade,
    this.certificateNo = 'MED-8929-XR4',
    this.completionDateText = 'COMPLETED MAY 2024',
    this.badgeType = 'check',
  });
}

class AuthorityNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final bool isUrgent;
  final String? relatedComplaintId;
  final String? group;
  final String? actionButtonText;
  final String? iconType;

  const AuthorityNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.isUrgent = false,
    this.relatedComplaintId,
    this.group,
    this.actionButtonText,
    this.iconType,
  });
}

class AuthorityProfileData {
  String legalName;
  String maskedIdentityNumber;
  String designation;
  String department;
  String officialEmail;
  String jurisdiction;
  String phone;
  String employeeId;
  bool isVerified;
  String position;
  String secureContactPhone;
  int points;
  List<String> achievements;
  List<String> works;

  AuthorityProfileData({
    required this.legalName,
    required this.maskedIdentityNumber,
    required this.designation,
    required this.department,
    required this.officialEmail,
    required this.jurisdiction,
    required this.phone,
    required this.employeeId,
    this.isVerified = true,
    this.position = 'Citizen , certified user',
    this.secureContactPhone = '+91 98451 22301',
    this.points = 35,
    this.achievements = const [],
    this.works = const [],
  });
}

/// In-memory repository of mock authority data for Phase 1 UI.
class MockAuthorityRepository {
  static final AuthorityProfileData currentOfficer = AuthorityProfileData(
    legalName: 'Lawrence Perker',
    maskedIdentityNumber: 'XXXX-XXXX-8921',
    designation: 'Divisional Environmental Inspector',
    department: 'Public Works & Sanitation',
    officialEmail: 'lawrenceperker@medal.gov',
    jurisdiction: 'Zone 4, Pine River Catchment, Municipal Office Complex, Sector 9',
    phone: '9123456789',
    employeeId: 'EMP-GMC-2024-419',
    isVerified: true,
    position: 'Citizen , certified user',
    secureContactPhone: '+91 98451 22301',
    points: 35,
    achievements: ['Gold Medal Civic Service', 'Top SDG 13 Inspector'],
    works: ['Pine River Canal Remediation', 'Sector 9 Lighting Upgrade'],
  );

  static final List<AuthorityComplaint> complaints = [
    AuthorityComplaint(
      id: 'CMP-2026-4401',
      backendId: 4401,
      title: 'Critical waste management failure',
      description:
          'Critical waste management failure observed at the canal junction. Local community impact rising due to blockage.',
      category: 'Waste management',
      ward: 'Ward 62',
      address: 'Bharathiyar street',
      latitude: 13.0827,
      longitude: 80.2707,
      status: AuthorityComplaintStatus.inProgress,
      priority: AuthorityPriority.critical,
      sdg: const SdgInfo(
        number: 13,
        title: 'Climate Action',
        description: 'Take urgent action to combat climate change and its impacts.',
        color: Color(0xFFBE123C),
      ),
      evidenceImages: [
        'assets/images/sample_waste_canal.jpg',
      ],
      upvotes: 124,
      commentsCount: 12,
      reportedAt: DateTime.parse('2026-10-06 10:30:00'),
      reportedBy: 'James Doe',
      officerNotes: 'Emergency field crew dispatched under Supervisor Mohan.',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4395',
      backendId: 4395,
      title: 'Critical Road Management',
      description:
          'Critical road management failure observed at the Naidu street junction. Local community impact rising due to lack of observation and poor quality.',
      category: 'Road Safety',
      ward: 'Ward 62',
      address: 'Bharathiyar Street',
      latitude: 13.0841,
      longitude: 80.2719,
      status: AuthorityComplaintStatus.assigned,
      priority: AuthorityPriority.high,
      sdg: const SdgInfo(
        number: 9,
        title: 'Industry, Innovation & Infrastructure',
        description: 'Make cities and human settlements inclusive, safe, resilient, and sustainable.',
        color: Color(0xFFFD9D24),
      ),
      evidenceImages: [
        'assets/images/sample_pothole.jpg',
      ],
      upvotes: 35,
      commentsCount: 9,
      reportedAt: DateTime.now().subtract(const Duration(hours: 12)),
      reportedBy: 'Deepa Narayanan',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4380',
      backendId: 4380,
      title: 'Damaged Street Light',
      description:
          'A vital street light pillar at this intersection has suffered severe physical damage, resulting in physical danger.',
      category: 'Road Safety',
      ward: 'Ward 62',
      address: 'Bharathiyar Street',
      latitude: 13.0872,
      longitude: 80.2654,
      status: AuthorityComplaintStatus.reviewing,
      priority: AuthorityPriority.high,
      sdg: const SdgInfo(
        number: 11,
        title: 'Sustainable Cities & Communities',
        description: 'Safe and well-lit urban environments for citizen safety.',
        color: Color(0xFFFD9D24),
      ),
      evidenceImages: [
        'assets/images/sample_streetlight.jpg',
      ],
      upvotes: 52,
      commentsCount: 21,
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
      reportedBy: 'Suresh Kumar',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4322',
      backendId: 4322,
      title: 'High-mast street light cluster non-functional for 2 weeks',
      description:
          'Five consecutive pole lights along the main canal bank road remain blacked out after dark. Significant security concern for pedestrians and commuters heading to the transit hub.',
      category: 'Electrical & Lighting',
      ward: 'Ward 62',
      address: 'Canal Bank Link Road, Sector 3, Ward 62',
      latitude: 13.0799,
      longitude: 80.2731,
      status: AuthorityComplaintStatus.assigned,
      priority: AuthorityPriority.medium,
      sdg: const SdgInfo(
        number: 11,
        title: 'Sustainable Cities & Communities',
        description: 'Safe and well-lit urban environments for citizen safety.',
        color: Color(0xFFFD9D24),
      ),
      evidenceImages: [
        'assets/images/dark_street.jpg',
      ],
      upvotes: 19,
      commentsCount: 4,
      reportedAt: DateTime.now().subtract(const Duration(days: 1)),
      reportedBy: 'Arun Mozhi',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4290',
      backendId: 4290,
      title: 'Stormwater drain blockage and foul water backflow',
      description:
          'Plastic debris and silt buildup choking 100m section of open stormwater canal. Water overflowing onto footpath during morning rains.',
      category: 'Drainage & Stormwater',
      ward: 'Ward 62',
      address: 'Periyar Salai service lane, Ward 62',
      latitude: 13.0811,
      longitude: 80.2688,
      status: AuthorityComplaintStatus.inProgress,
      priority: AuthorityPriority.medium,
      sdg: const SdgInfo(
        number: 6,
        title: 'Clean Water & Sanitation',
        description: 'Ensuring safe urban drainage systems.',
        color: Color(0xFF00AED9),
      ),
      evidenceImages: [
        'assets/images/drain_block.jpg',
      ],
      upvotes: 27,
      commentsCount: 6,
      reportedAt: DateTime.now().subtract(const Duration(days: 2)),
      reportedBy: 'M. Anand',
      officerNotes: 'De-silting machinery scheduled for 10:00 AM shift.',
    ),
  ];

  static const AuthorityCourse featuredCourse = AuthorityCourse(
    id: 'CRS-SEEK-01',
    title: 'Social Emotional Education:\nKnowledge to Practice (SEEK)',
    department: 'Education & Ethics',
    totalModules: 10,
    completedModules: 7,
    progress: 0.68,
    duration: '6.0 Hours',
    level: 'Intermediate',
    instructor: 'UNESCO MGIEP & MEdAL Academy',
    badgeText: 'IN PROGRESS',
    buttonActionText: 'Continue Learning',
    isFeatured: true,
  );

  static final List<AuthorityCourse> courses = [
    const AuthorityCourse(
      id: 'CRS-AUTH-101',
      title: 'Lorem ipsum dolor',
      department: 'Environmental Management',
      totalModules: 8,
      completedModules: 3,
      progress: 0.4,
      duration: '4h',
      level: 'All Levels',
      instructor: 'MEdAL Academy',
      rating: 4.9,
      badgeText: 'SDG 15',
      imageAsset: 'assets/images/sample_mountain.jpg',
      buttonActionText: 'Start Course',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-102',
      title: 'Lorem ipsum dolor',
      department: 'Empathy & Civic Communication',
      totalModules: 6,
      completedModules: 0,
      progress: 0.0,
      duration: '6h',
      level: 'Advanced',
      instructor: 'National Institute of Urban Affairs',
      rating: 4.7,
      badgeText: 'EMPATHY',
      imageAsset: 'assets/images/sample_chart.jpg',
      buttonActionText: 'Enroll',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-103',
      title: 'Lorem ipsum dolor',
      department: 'Municipal Leadership',
      totalModules: 5,
      completedModules: 0,
      progress: 0.0,
      duration: '3h',
      level: 'Leadership',
      instructor: 'Central Governance Board',
      rating: 4.8,
      badgeText: 'LEADERSHIP',
      imageAsset: 'assets/images/sample_team.jpg',
      buttonActionText: 'Enroll',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-104',
      title: 'Lorem ipsum dolor',
      department: 'Mindfulness & Focus',
      totalModules: 8,
      completedModules: 0,
      progress: 0.0,
      duration: '5h',
      level: 'Intermediate',
      instructor: 'MEdAL Academy',
      rating: 4.6,
      badgeText: 'MINDFULNESS',
      imageAsset: 'assets/images/sample_building.jpg',
      buttonActionText: 'Start Course',
    ),
  ];

  static final List<AuthorityCertificate> certificates = [
    const AuthorityCertificate(
      id: 'CERT-AUTH-2024-084',
      title: 'Advanced Grievance Resolution',
      issuedBy: 'National Institute of Urban Affairs & MEdAL',
      issueDate: '15 May 2024',
      credentialUrl: 'https://medal.gov.in/verify/MED-8929-XR4',
      grade: 'Distinction (96%)',
      certificateNo: 'MED-8929-XR4',
      completionDateText: 'COMPLETED MAY 2024',
      badgeType: 'check',
    ),
    const AuthorityCertificate(
      id: 'CERT-AUTH-2024-012',
      title: 'SDG Alignment & Institutional Ethics',
      issuedBy: 'Ministry of Housing and Urban Affairs & MEdAL Cell',
      issueDate: '20 Feb 2024',
      credentialUrl: 'https://medal.gov.in/verify/MED-1102-G12',
      grade: 'Certified Officer',
      certificateNo: 'MED-1102-G12',
      completionDateText: 'COMPLETED FEB 2024',
      badgeType: 'star',
    ),
    const AuthorityCertificate(
      id: 'CERT-AUTH-2025-081',
      title: 'Civic SLA Management & Escalation Framework',
      issuedBy: 'National Institute of Urban Affairs (NIUA) & MEdAL',
      issueDate: '15 Nov 2025',
      credentialUrl: 'https://medal.gov.in/verify/CERT-AUTH-2025-081',
      grade: 'Distinction (94%)',
      certificateNo: 'MED-5501-A90',
      completionDateText: 'COMPLETED NOV 2023',
      badgeType: 'check',
    ),
  ];

  static final List<AuthorityNotificationItem> notifications = [
    AuthorityNotificationItem(
      id: 'NOTIF-TOP',
      title: 'People tagged you',
      body: 'John Doe, Red Swan and others tagged you',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      isRead: false,
      isUrgent: false,
      iconType: 'check',
      group: 'Header',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-1',
      title: 'Course 20% pending , we would love to see your progress',
      body: 'Course 20% pending , we would love to see your progress',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: false,
      isUrgent: true,
      iconType: 'academy',
      group: 'Last 7 days',
      actionButtonText: 'View',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-2',
      title: 'Redirected update',
      body: 'View the redirected update on the complaint.',
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      isRead: true,
      isUrgent: false,
      iconType: 'redirect',
      group: 'Last 7 days',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-3',
      title: 'Course 1 successfully completed , view the certificate',
      body: 'Course 1 successfully completed , view the certificate',
      timestamp: DateTime.now().subtract(const Duration(days: 12)),
      isRead: true,
      isUrgent: false,
      iconType: 'academy',
      group: 'Last 30 days',
      actionButtonText: 'View',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-4',
      title: 'Tagged you',
      body: 'John Doe has tagged you',
      timestamp: DateTime.now().subtract(const Duration(days: 18)),
      isRead: true,
      isUrgent: false,
      iconType: 'tag',
      group: 'Last 30 days',
      actionButtonText: 'View',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-5',
      title: 'Communities update',
      body: '30+ posts on the community',
      timestamp: DateTime.now().subtract(const Duration(days: 25)),
      isRead: true,
      isUrgent: false,
      iconType: 'community',
      group: 'Last 30 days',
    ),
  ];
}
