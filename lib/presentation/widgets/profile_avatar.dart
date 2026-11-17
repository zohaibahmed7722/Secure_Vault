import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A stable, flicker-free avatar widget that avoids the visual reload animation
/// and jerking associated with standard implicit animation containers.
///
/// Uses [Image.memory] with [gaplessPlayback] and static circular clipping so
/// avatar transitions and parent rebuilds remain completely smooth without
/// blank frames or reload flicker.
///
/// Enhanced with optional border, gradient styling, and subtle ambient glow
/// to match the Secure Vault visual theme.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.image,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.placeholderIcon = Icons.person_outline,
    this.iconSize,
    this.borderColor,
    this.borderWidth = 0,
    this.boxShadow,
  });

  /// The raw image bytes of the profile picture, or null if unset.
  final Uint8List? image;

  /// The radius of the avatar circle.
  final double radius;

  /// The background fill color of the avatar.
  final Color? backgroundColor;

  /// The icon color when no profile image is available.
  final Color? foregroundColor;

  /// The icon to display when no profile image is set or if loading fails.
  final IconData placeholderIcon;

  /// The size of the placeholder icon. Defaults to 1.15 * [radius].
  final double? iconSize;

  /// Optional border color for an enclosing ring.
  final Color? borderColor;

  /// Border width. Defaults to 0.
  final double borderWidth;

  /// Optional box shadows for ambient glow.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = foregroundColor ?? theme.colorScheme.primary;
    final diameter = radius * 2;
    final effectiveIconSize = iconSize ?? (radius * 1.15);

    final hasValidImage = image != null && image!.isNotEmpty;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? theme.colorScheme.outlineVariant,
                width: borderWidth,
              )
            : null,
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasValidImage
          ? Image.memory(
              image!,
              key: ValueKey<Object>(image!),
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  placeholderIcon,
                  size: effectiveIconSize,
                  color: fg,
                );
              },
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bg,
                    bg.withValues(alpha: 0.8),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  placeholderIcon,
                  size: effectiveIconSize,
                  color: fg,
                ),
              ),
            ),
    );
  }
}

