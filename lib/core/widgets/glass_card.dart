import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-look translucent panel: the core surface of the whole app.
///
/// This deliberately does NOT use [BackdropFilter]. A live gaussian blur
/// has to be re-rasterized every frame the content behind it changes -
/// which, for a card inside a scrolling list, is every single frame it
/// moves. With dozens of these on screen across Home/History/Workout that
/// was costing 5-10ms+ of extra raster-thread time per frame while
/// scrolling (measured with the performance overlay), enough to blow the
/// frame budget and show up as visible scroll jank. The background here is
/// a few soft static gradients, not fine detail, so a translucent gradient
/// fill plus a border reads as "glass" without paying for a live blur.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.onTap,
    this.highlighted = false,
    this.border,
    this.margin,
    this.opaque = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final bool highlighted;
  final Color? border;

  /// Set for panels that sit *above* scrolling content (bottom nav, rest
  /// timer bar, modal sheets). Uses a solid fill so list content scrolling
  /// underneath cannot be read through the panel.
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final BorderRadius shape = BorderRadius.circular(radius);

    Widget content = RepaintBoundary(
      child: ClipRRect(
        borderRadius: shape,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            color: opaque
                ? (highlighted
                    ? AppColors.surfaceOpaqueRaised
                    : AppColors.surfaceOpaque)
                : null,
            gradient: opaque ? null : AppColors.glassGradient,
            border: Border.all(
              color: border ??
                  (highlighted ? AppColors.glassBorderBright : AppColors.glassBorder),
              width: 1,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap != null) {
      content = Stack(
        children: <Widget>[
          content,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: shape,
                splashColor: AppColors.neonCyan.withOpacity(0.06),
                highlightColor: AppColors.neonBlue.withOpacity(0.05),
                onTap: onTap,
              ),
            ),
          ),
        ],
      );
    }

    if (highlighted) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.neonBlue.withOpacity(0.22),
              blurRadius: 34,
              spreadRadius: -6,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: content,
      );
    }

    return margin == null ? content : Padding(padding: margin!, child: content);
  }
}

/// Small circular glass button used for the top-bar icons.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = SizedBox(
      width: size,
      height: size,
      child: GlassCard(
        radius: size / 2,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Center(
          child: Icon(icon, size: size * 0.44, color: AppColors.textPrimary),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
