import 'package:agrishield2/core/agri_text.dart';
import 'package:agrishield2/core/media_query.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/login_controller.dart';
import 'routes.dart';

//  MOBILE â€” Floating Bottom Nav


class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  final List<_NavItem> items;
  final int            currentIndex;
  final ValueChanged<int> onTap;
  final Widget         child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // extendBody lets content go behind the floating nav
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingBottomNav(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
      ),
    );
  }
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItem> items;
  final int            currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final blur = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      // Floating effect â€” gap from edges and bottom
      padding: EdgeInsets.fromLTRB(
        24, 0, 24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: blur,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              // fully transparent fill so backdrop shows through
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(items.length, (i) {
                final item     = items[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: _FloatingNavItem(
                    item:     item,
                    isActive: isActive,
                    onTap:    () => onTap(i),
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

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool     isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); 
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeInOut,
        padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:        isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize:     MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
                child: Icon(
                isActive ? item.activeIcon : item.icon,
                key:   ValueKey(isActive),
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                size:  22,
              ),
            ),

            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 900),
                style: TextStyle(
                fontFamily: 'Outfit',
                fontSize:   8,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w400,
                color:      isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}


//  TABLET

class _TabletScaffold extends StatelessWidget {
  const _TabletScaffold({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.child,
  });

  final List<_NavItem> items;
  final int            currentIndex;
  final ValueChanged<int> onTap;
  final Widget         child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // Permanent sidebar
          _SidebarNav(
            items:        items,
            currentIndex: currentIndex,
            onTap:        onTap,
          ),

          const VerticalDivider(width: 1, thickness: 1),
          // Main content

          Expanded(child: child),
        ],
      ),
    );
  }
}

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
    final items = const [
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

class _SidebarNav extends ConsumerStatefulWidget {
  const _SidebarNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavItem> items;
  final int            currentIndex;
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
            // Logo / brand header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Row(
                children: [
                  Container(
                    width:  36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
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


            // Nav items
            ...List.generate(widget.items.length, (i) {
              final item     = widget.items[i];
              final isActive = i == widget.currentIndex;
              return _SidebarItem(
                item:     item,
                isActive: isActive,
                onTap:    () => widget.onTap(i),
              );
            }),

            const Spacer(),

            const Divider(),

            // Settings at bottom
            _SidebarItem(
              item: const _NavItem(
                icon:       Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label:      'Settings',
                route:      Routes.settings,
              ),
              isActive: false,
              onTap: () => Navigator.pushNamed(context, Routes.settings),
            ),

            // Logout
            _SidebarItem(
              item: const _NavItem(
                icon:       Icons.logout_outlined,
                activeIcon: Icons.logout_rounded,
                label:      'Logout',
                route:      '',
              ),
              isActive:  false,
              textColor: AgriColors.danger,
              iconColor: AgriColors.danger,
              onTap: () async {
                // Sign out from Firebase via controller
                await ref.read(loginControllerProvider.notifier).signOut();
                
                // Navigate back to login
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

  final _NavItem     item;
  final bool         isActive;
  final VoidCallback onTap;
  final Color?       textColor;
  final Color?       iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:        isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense:        true,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width:  3,
                height: isActive ? 20 : 0,
                decoration: BoxDecoration(
                  color:        Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: iconColor ?? (isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
                size: 20,
              ),
            ],
          ),
          title: AgriText.bodyMedium(
            item.label,
            color: textColor ?? (isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}



//  Nav Item model
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   route;
}


