import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../state/providers.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(icon: Icons.space_dashboard_rounded, label: 'Today'),
    _NavItem(icon: Icons.insights_rounded, label: 'Progress'),
    _NavItem(icon: Icons.tune_rounded, label: 'Settings'),
  ];

  void _select(WidgetRef ref, int index) {
    if (index == ref.read(shellTabProvider)) return;
    HapticFeedback.selectionClick();
    ref.read(shellTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(shellTabProvider);
    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        child: IndexedStack(
          index: index,
          children: const <Widget>[
            HomeScreen(),
            HistoryScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
          child: GlassCard(
            radius: 26,
            opaque: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(_items.length, (int i) {
                return Expanded(
                  child: _NavButton(
                    item: _items[i],
                    selected: i == index,
                    onTap: () => _select(ref, i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected ? AppColors.accentGradient : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.neonBlue.withOpacity(0.38),
                    blurRadius: 20,
                    spreadRadius: -6,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              item.icon,
              size: 19,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: sora(12, 600, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
