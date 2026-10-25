// lib/modules/institution/features/institution/widgets/unesco_logo.dart
// Reusable UNESCO + MGIEP logo card matching design screenshots 4, 5, 6.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UnescoLogoWidget extends StatelessWidget {
  final double width;
  final double? height;

  const UnescoLogoWidget({
    super.key,
    this.width = 96,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Temple building icon (UNESCO emblem)
              const Icon(
                Icons.account_balance,
                size: 16,
                color: Color(0xFF111827),
              ),
              const SizedBox(width: 4),
              // MGIEP emblem box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF111827), width: 0.9),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  'MGIEP',
                  style: GoogleFonts.inter(
                    fontSize: 6.5,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: const Color(0xFF111827),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            'unesco',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              height: 1.1,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
