import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// Primary call to action: blue-to-cyan gradient with an outer glow.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
    this.height = 56,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;

    final Widget body = AnimatedOpacity(
      opacity: active ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.42),
                    blurRadius: 26,
                    spreadRadius: -4,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: sora(14, 700, color: Colors.white, letterSpacing: 0.8),
            ),
            if (icon != null) ...<Widget>[
              const SizedBox(width: 12),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0x33061021),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );

    return Pressable(
      onTap: active ? onPressed : null,
      child: expanded ? SizedBox(width: double.infinity, child: body) : body,
    );
  }
}

/// Secondary, quieter action - outlined glass pill.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.textSecondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
            ],
            Text(label, style: sora(13, 600, color: color)),
          ],
        ),
      ),
    );
  }
}
