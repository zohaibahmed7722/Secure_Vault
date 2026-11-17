import 'package:flutter/material.dart';

/// Reusable application icon and brand mark that automatically adapts
/// to the current theme color scheme or custom primary/secondary colors.
class VaultAppIcon extends StatelessWidget {
  final double size;
  final double? iconSize;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Key? markKey;
  final double? borderRadius;
  final bool showGlow;
  final IconData icon;

  const VaultAppIcon({
    super.key,
    this.size = 88,
    this.iconSize,
    this.primaryColor,
    this.secondaryColor,
    this.markKey,
    this.borderRadius,
    this.showGlow = true,
    this.icon = Icons.shield_moon_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = primaryColor ?? scheme.primary;
    final secondary = secondaryColor ?? scheme.secondary;
    final effectiveIconSize = iconSize ?? (size * 0.54);
    final effectiveRadius = borderRadius ?? (size * 0.31);

    return Container(
      key: markKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ),
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.32),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          size: effectiveIconSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
