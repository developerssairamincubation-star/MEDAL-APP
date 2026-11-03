// lib/widgets/role_card.dart
// Premium reusable role selection card with hover effects, custom animations, and responsive layout.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String description;
  final Widget icon;
  final String buttonText;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  Widget _buildIconBox(Color primaryColor, bool compact) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: _isHovered ? primaryColor.withValues(alpha: 0.1) : MedalTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: widget.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final compact = widget.compact;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        transform: _isHovered 
            ? (Matrix4.translationValues(0.0, -4.0, 0.0)..multiply(Matrix4.diagonal3Values(1.01, 1.01, 1.0)))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? primaryColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isHovered ? 16 : 8,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: primaryColor.withValues(alpha: 0.08),
              highlightColor: primaryColor.withValues(alpha: 0.04),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20.0 : 24.0,
                  vertical: compact ? 14.0 : 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Container (+ title inline on compact/mobile so two
                    // cards fit on one screen without scrolling)
                    if (compact)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIconBox(primaryColor, compact),
                          const SizedBox(width: 12),
                          Text(
                            widget.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: MedalTheme.textPrimary,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildIconBox(primaryColor, compact),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: MedalTheme.textPrimary,
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? 8 : 10),
                    // Description
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: MedalTheme.textSecondary,
                        fontSize: compact ? 13 : 14,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 24),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 40 : 48,
                      child: OutlinedButton(
                        onPressed: widget.onTap,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isHovered ? Colors.transparent : primaryColor,
                            width: 1.5,
                          ),
                          backgroundColor: _isHovered ? primaryColor : Colors.transparent,
                          foregroundColor: _isHovered ? Colors.white : primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.buttonText,
                          style: TextStyle(
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
