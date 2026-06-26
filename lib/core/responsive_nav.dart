import 'package:agrishield2/core/agri_text.dart';
import 'package:agrishield2/core/media_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/login_controller.dart';
import 'routes.dart';

//MOBILE 
class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOpen = ValueNotifier<bool>(false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: isOpen,
        builder: (context, open, _) {
          return SpeedDial(
            // Position
            buttonSize: const Size(58, 58),
            childrenButtonSize: const Size(52, 52),

            // Open/close notifier
            openCloseDial: isOpen,

            // Closed state icon — shows current screen icon
            icon: items[currentIndex].icon,
            activeIcon: Icons.close_rounded,

            // Styling
            backgroundColor: cs.primary,
            foregroundColor: Colors.black,
            activeBackgroundColor: cs.surface,
            activeForegroundColor: cs.onSurface,
            elevation: 6,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),

            // Overlay behind the dial when open
            overlayColor: Colors.black,
            overlayOpacity: 0.35,

            // Direction — upward stack
            direction: SpeedDialDirection.up,
            spacing: 8,
            spaceBetweenChildren: 4,

            // Haptic on open
            onOpen: () => HapticFeedback.lightImpact(),

            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;

              return SpeedDialChild(
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 20,
                  color: isActive ? Colors.black : cs.onSurface,
                ),
                backgroundColor:
                    isActive ? cs.primary : cs.surface,
                foregroundColor:
                    isActive ? Colors.black : cs.onSurface,
                elevation: 4,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                label: item.label,
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isActive ? cs.primary : cs.onSurface,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                labelBackgroundColor: cs.surface,
                labelShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
              );
            }),
          );
        },
      ),
    );
  }
}

//TABLET
class _TabletScaffold extends StatelessWidget {
  const _TabletScaffold({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          _SidebarNav(
            items: items,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// NavBar 
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Home',
        route: Routes.dashboard,
      ),
      _NavItem(
        icon: Icons.warning_outlined,
        activeIcon: Icons.warning_rounded,
        label: 'Alerts',
        route: Routes.alerts,
      ),
      _NavItem(
        icon: Icons.dns_outlined,
        activeIcon: Icons.dns_rounded,
        label: 'Nodes',
        route: Routes.nodeStatus,
      ),
      _NavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history_rounded,
        label: 'History',
        route: Routes.history,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
        route: Routes.settings,
      ),
    ];

    if (Responsive.isMobile(context)) {
      return _MobileScaffold(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
        child: child,
      );
    }

    return _TabletScaffold(
      items: items,
      currentIndex: currentIndex,
      onTap: onTap,
      child: child,
    );
  }
}

//Sidebar

class _SidebarNav extends ConsumerStatefulWidget {
  const _SidebarNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  ConsumerState<_SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends ConsumerState<_SidebarNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AgriShield',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            ...List.generate(widget.items.length, (i) {
              final item = widget.items[i];
              final isActive = i == widget.currentIndex;
              return _SidebarItem(
                item: item,
                isActive: isActive,
                onTap: () => widget.onTap(i),
              );
            }),
            const Spacer(),
            const Divider(),
            _SidebarItem(
              item: const _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
                route: Routes.settings,
              ),
              isActive: false,
              onTap: () => Navigator.pushNamed(context, Routes.settings),
            ),
            _SidebarItem(
              item: const _NavItem(
                icon: Icons.logout_outlined,
                activeIcon: Icons.logout_rounded,
                label: 'Logout',
                route: '',
              ),
              isActive: false,
              textColor: AgriColors.danger,
              iconColor: AgriColors.danger,
              onTap: () async {
                await ref.read(loginControllerProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed(Routes.login);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: isActive ? 20 : 0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: iconColor ??
                    (isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65)),
                size: 20,
              ),
            ],
          ),
          title: AgriText.bodyMedium(
            item.label,
            color: textColor ??
                (isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

//  Nav item model 

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}