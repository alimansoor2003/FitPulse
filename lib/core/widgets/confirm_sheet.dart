import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass_card.dart';
import 'neon_button.dart';

/// Dark glass confirmation sheet - replaces the default Material dialog so
/// destructive and branching choices stay on-theme.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050A14),
    isScrollControlled: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GlassCard(
            radius: 28,
            opaque: true,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            highlighted: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (destructive ? AppColors.danger : AppColors.neonCyan)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          (destructive ? AppColors.danger : AppColors.neonCyan)
                              .withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: destructive ? AppColors.danger : AppColors.neonCyan,
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: AppText.title),
                const SizedBox(height: 8),
                Text(message, style: AppText.body),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GhostButton(
                        label: cancelLabel,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeonButton(
                        label: confirmLabel.toUpperCase(),
                        height: 44,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
