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
  String? officerNotes;
  String? rejectionReason;
  String? redirectedDepartment;
  String? redirectionReason;

  AuthorityComplaint({
    required this.id,
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
    this.officerNotes,
    this.rejectionReason,
    this.redirectedDepartment,
    this.redirectionReason,
  });
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
  });
}

class AuthorityCertificate {
  final String id;
  final String title;
  final String issuedBy;
  final String issueDate;
  final String credentialUrl;
  final String grade;

  const AuthorityCertificate({
    required this.id,
    required this.title,
    required this.issuedBy,
    required this.issueDate,
    required this.credentialUrl,
    required this.grade,
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

  const AuthorityNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.isUrgent = false,
    this.relatedComplaintId,
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
  });
}

/// In-memory repository of mock authority data for Phase 1 UI.
class MockAuthorityRepository {
  static final AuthorityProfileData currentOfficer = AuthorityProfileData(
    legalName: 'Er. Rajesh Varma',
    maskedIdentityNumber: 'XXXX-XXXX-8921',
    designation: 'Assistant Executive Engineer',
    department: 'Water Supply & Public Works',
    officialEmail: 'rajesh.varma@corporation.gov.in',
    jurisdiction: 'Zone 5 - Ward 62, Greater Municipal Corp',
    phone: '+91 98401 23456',
    employeeId: 'EMP-GMC-2024-419',
    isVerified: true,
  );

  static final List<AuthorityComplaint> complaints = [
    AuthorityComplaint(
      id: 'CMP-2026-4401',
      title: 'Major underground pipeline breach causing roadway flooding',
      description:
          'Continuous drinking water pipeline rupture on 4th Main Road outside Block B apartments. High pressure leakage is causing road depression and flooding ground floor properties. Immediate valve isolation and repair crew required.',
      category: 'Water Supply',
      ward: 'Ward 62',
      address: '4th Main Road, Near Gandhi Park Junction, Ward 62',
      latitude: 13.0827,
      longitude: 80.2707,
      status: AuthorityComplaintStatus.inProgress,
      priority: AuthorityPriority.critical,
      sdg: const SdgInfo(
        number: 6,
        title: 'Clean Water & Sanitation',
        description: 'Ensure availability and sustainable management of water and sanitation for all.',
        color: Color(0xFF00AED9),
      ),
      evidenceImages: [
        'assets/images/water_leak_1.jpg',
        'assets/images/water_leak_2.jpg',
      ],
      upvotes: 48,
      commentsCount: 14,
      reportedAt: DateTime.now().subtract(const Duration(hours: 3)),
      reportedBy: 'Karthik S. (Resident)',
      officerNotes: 'Emergency field crew dispatched under Supervisor Mohan.',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4395',
      title: 'Unattended municipal solid waste heap near primary school gate',
      description:
          'Sanitation bins overflowing for the past 4 days. Waste spilled across pedestrian walkway adjacent to Government Primary School. Stray animals gathering and foul odor spreading across residential street.',
      category: 'Sanitation & Waste',
      ward: 'Ward 62',
      address: '12th Cross Street, Bharathi Nagar, Ward 62',
      latitude: 13.0841,
      longitude: 80.2719,
      status: AuthorityComplaintStatus.assigned,
      priority: AuthorityPriority.high,
      sdg: const SdgInfo(
        number: 11,
        title: 'Sustainable Cities & Communities',
        description: 'Make cities and human settlements inclusive, safe, resilient, and sustainable.',
        color: Color(0xFFFD9D24),
      ),
      evidenceImages: [
        'assets/images/waste_heap.jpg',
      ],
      upvotes: 35,
      commentsCount: 9,
      reportedAt: DateTime.now().subtract(const Duration(hours: 7)),
      reportedBy: 'Deepa Narayanan',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4380',
      title: 'Deep crater pothole dangerous for two-wheelers during night',
      description:
          'Deep asphalt damage approximately 2.5ft wide and 8 inches deep following heavy rainfall. Two accidents reported last evening. Barricading and cold-mix patch work required urgently.',
      category: 'Roads & Infrastructure',
      ward: 'Ward 62',
      address: 'Radial Road underpass flyover ramp, Ward 62',
      latitude: 13.0872,
      longitude: 80.2654,
      status: AuthorityComplaintStatus.reviewing,
      priority: AuthorityPriority.high,
      sdg: const SdgInfo(
        number: 9,
        title: 'Industry, Innovation & Infrastructure',
        description: 'Build resilient infrastructure and foster sustainable civic development.',
        color: Color(0xFFF36E25),
      ),
      evidenceImages: [
        'assets/images/pothole_crater.jpg',
      ],
      upvotes: 52,
      commentsCount: 21,
      reportedAt: DateTime.now().subtract(const Duration(hours: 14)),
      reportedBy: 'Suresh Kumar',
    ),
    AuthorityComplaint(
      id: 'CMP-2026-4322',
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

  static final List<AuthorityCourse> courses = [
    const AuthorityCourse(
      id: 'CRS-AUTH-101',
      title: 'Urban Water Distribution & High-Pressure Leakage Protocols',
      department: 'Water Supply & Sewerage',
      totalModules: 8,
      completedModules: 6,
      progress: 0.75,
      duration: '4.5 Hours',
      level: 'Intermediate',
      instructor: 'Ministry of Jal Shakti & MEdAL Academy',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-102',
      title: 'Civic SLA Management & Escalation Framework',
      department: 'Public Governance',
      totalModules: 5,
      completedModules: 5,
      progress: 1.0,
      duration: '3.0 Hours',
      level: 'Advanced',
      instructor: 'National Institute of Urban Affairs',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-103',
      title: 'Hazardous Waste Isolation & Rapid Municipal Remediation',
      department: 'Sanitation & Health',
      totalModules: 6,
      completedModules: 2,
      progress: 0.33,
      duration: '5.0 Hours',
      level: 'Specialist',
      instructor: 'Central Pollution Control Board',
    ),
    const AuthorityCourse(
      id: 'CRS-AUTH-104',
      title: 'GIS-Based Spatial Civic Inspection & Road Asset Auditing',
      department: 'Roads & Infrastructure',
      totalModules: 10,
      completedModules: 0,
      progress: 0.0,
      duration: '6.5 Hours',
      level: 'All Levels',
      instructor: 'MEdAL Geospatial Civic Cell',
    ),
  ];

  static final List<AuthorityCertificate> certificates = [
    const AuthorityCertificate(
      id: 'CERT-AUTH-2025-081',
      title: 'Civic SLA Management & Escalation Framework',
      issuedBy: 'National Institute of Urban Affairs (NIUA) & MEdAL',
      issueDate: '15 Nov 2025',
      credentialUrl: 'https://medal.gov.in/verify/CERT-AUTH-2025-081',
      grade: 'Distinction (94%)',
    ),
    const AuthorityCertificate(
      id: 'CERT-AUTH-2025-042',
      title: 'Municipal Digital Grievance Redressal Certification',
      issuedBy: 'State E-Governance Mission & MEdAL Cell',
      issueDate: '28 Aug 2025',
      credentialUrl: 'https://medal.gov.in/verify/CERT-AUTH-2025-042',
      grade: 'Executive Honors',
    ),
    const AuthorityCertificate(
      id: 'CERT-AUTH-2024-911',
      title: 'Public Works Environmental Quality & SDG Standards',
      issuedBy: 'Ministry of Housing and Urban Affairs (MoHUA)',
      issueDate: '10 Dec 2024',
      credentialUrl: 'https://medal.gov.in/verify/CERT-AUTH-2024-911',
      grade: 'Certified Auditor',
    ),
  ];

  static final List<AuthorityNotificationItem> notifications = [
    AuthorityNotificationItem(
      id: 'NOTIF-1',
      title: 'Critical Issue Assigned: Water Main Breach',
      body: 'Complaint #CMP-2026-4401 in Ward 62 has been escalated and assigned to your department. SLA: 24h response required.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      isRead: false,
      isUrgent: true,
      relatedComplaintId: 'CMP-2026-4401',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-2',
      title: 'Community Escalation Threshold Crossed',
      body: 'Complaint #CMP-2026-4380 (Pothole crater) has reached 50+ citizen upvotes in Ward 62.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      isUrgent: true,
      relatedComplaintId: 'CMP-2026-4380',
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-3',
      title: 'Admin Verification Notice',
      body: 'Your municipal authority credentials and department jurisdiction were validated successfully by the Nodal Admin.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      isUrgent: false,
    ),
    AuthorityNotificationItem(
      id: 'NOTIF-4',
      title: 'Monthly Ward Performance Report Ready',
      body: 'Ward 62 closed 48 civic reports with a 91% resolution compliance rate for the previous cycle.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
      isUrgent: false,
    ),
  ];
}
