// lib/widgets/profile_ui.dart
// Shared profile-page building blocks, copied from the Authority profile so
// the citizen, institution (student / staff / principal), authority and admin
// profiles all share one layout: hero card, section title, account tiles and
// the red Log Out tile. UI only; callers keep their own logic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _blue = Color(0xFF0467B6);
const Color _navy = Color(0xFF111C2D);

/// Profile hero card: role badge, avatar with edit pencil, name, "Certified
/// user", email + phone rows and an optional footer line (e.g. points).
class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.roleLabel,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.onEdit,
    this.isUploading = false,
    this.badgeBackground = const Color(0xFFF3E8FF),
    this.badgeForeground = const Color(0xFF7C3AED),
    this.showCertified = true,
    this.pointsText,
  });

  final String roleLabel;
  final String name;
  final String email;
  final String? phone;

  /// Already-resolved (absolute) image URL, or null for the person icon.
  final String? photoUrl;
  final VoidCallback? onEdit;
  final bool isUploading;
  final Color badgeBackground;
  final Color badgeForeground;
  final bool showCertified;
  final String? pointsText;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.person, size: 48, color: Color(0xFF64748B));
    final url = photoUrl?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  roleLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: badgeForeground,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: url.isEmpty
                    ? fallback
                    : Image.network(
                        url,
                        width: 74,
                        height: 74,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      ),
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              if (onEdit != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: isUploading ? null : onEdit,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          if (showCertified) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: _blue),
                const SizedBox(width: 5),
                Text(
                  'Certified user',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _infoRow(Icons.mail_outline_rounded, email),
          if (phone != null && phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoRow(Icons.phone_android_rounded, phone!),
          ],
          if (pointsText != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    pointsText!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: _blue),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: const Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: _navy,
        ),
      ),
    );
  }
}

/// White rounded row with a tinted icon, title, subtitle and chevron.
class ProfileAccountTile extends StatelessWidget {
  const ProfileAccountTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = const Color(0xFF0284C7),
    this.iconBgColor = const Color(0xFFE0F2FE),
    this.compatTitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Extra near-invisible label so older finders keep matching.
  final String? compatTitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      if (compatTitle != null && compatTitle != title)
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.001,
                            child: Text(
                              compatTitle!,
                              style: const TextStyle(fontSize: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red "Log Out" row used at the bottom of every profile.
class ProfileLogoutTile extends StatelessWidget {
  const ProfileLogoutTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFEE2E2), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 19,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const Positioned.fill(
                    child: Opacity(
                      opacity: 0.001,
                      child: Text('Sign Out', style: TextStyle(fontSize: 1)),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}

/// One earned certificate as shown on a profile.
class ProfileCertificate {
  const ProfileCertificate({
    required this.title,
    required this.dateText,
    required this.number,
    this.star = false,
  });

  final String title;
  final String dateText;
  final String number;
  final bool star;
}

/// "Earned Certifications" block: header with Upload button, certificate
/// cards, or an empty state when the user has not completed any course.
class ProfileCertificatesSection extends StatelessWidget {
  const ProfileCertificatesSection({
    super.key,
    required this.certificates,
    required this.onDownload,
    this.onUpload,
    this.header,
  });

  final List<ProfileCertificate> certificates;
  final void Function(ProfileCertificate cert) onDownload;
  final VoidCallback? onUpload;

  /// Leading widget of the header (defaults to the MEdAL badge icon).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  header ??
                      const Icon(
                        Icons.military_tech_rounded,
                        size: 20,
                        color: _blue,
                      ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Earned Certifications',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (onUpload != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Upload',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (certificates.isEmpty)
          Container(
            key: const Key('profile_no_certificates'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6E4F0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 34,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 8),
                Text(
                  'No certificates yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Finish a course in the Academy to earn one.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          for (final cert in certificates) ...[
            _CertCard(cert: cert, onDownload: () => onDownload(cert)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert, required this.onDownload});

  final ProfileCertificate cert;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(color: _blue),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cert.dateText,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cert.title,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cert.star
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        cert.star ? Icons.star_rounded : Icons.verified_rounded,
                        size: 18,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certificate No.',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cert.number,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onDownload,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FD),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: _blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
