import 'dart:ui';
import 'package:flutter/material.dart';

import 'home_view.dart';
import 'registro_view.dart';
import 'movimientos_view.dart';
import 'parametros_view.dart';
import '../utils/theme_switch.dart';
import '../widgets/voucher_notification_listener.dart';

class MainNavView extends StatefulWidget {
  const MainNavView({super.key});

  @override
  State<MainNavView> createState() => _MainNavViewState();
}

class _MainNavViewState extends State<MainNavView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeView(),
    RegistroView(),
    MovimientosView(),
    ParametrosView(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return VoucherNotificationListener(
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // Mantiene el estado de cada tab
            IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),

            // Switch siempre visible
            const Positioned(
              top: 24,
              right: 24,
              child: ThemeSwitch(),
            ),
          ],
        ),

        // Nav moderno flotante con blur + animación + indicador
        bottomNavigationBar: _ModernBottomNav(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          isDark: isDark,
          activeColor: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ModernBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final Color activeColor;

  const _ModernBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111318) : Colors.white.withAlpha((0.85 * 255).toInt());
    final border = isDark ? Colors.white.withAlpha((0.08 * 255).toInt()) : Colors.black.withAlpha((0.06 * 255).toInt());
    final inactive = isDark ? Colors.white.withAlpha((0.55 * 255).toInt()) : Colors.black.withAlpha((0.45 * 255).toInt());

    final items = const <_NavItemData>[
      _NavItemData(icon: Icons.home_rounded),
      _NavItemData(icon: Icons.app_registration_rounded),
      _NavItemData(icon: Icons.swap_horiz_rounded),
      _NavItemData(icon: Icons.tune_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(((isDark ? 0.35 : 0.12) * 255).toInt()),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = i == currentIndex;
                  return Expanded(
                    child: _NavButton(
                      icon: items[i].icon,
                      selected: selected,
                      activeColor: activeColor,
                      inactiveColor: inactive,
                      onTap: () => onTap(i),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: activeColor.withAlpha((0.12 * 255).toInt()),
      highlightColor: activeColor.withAlpha((0.06 * 255).toInt()),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? activeColor.withAlpha((0.14 * 255).toInt()) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: selected ? 1.10 : 1.0,
                child: Icon(
                  icon,
                  size: 28,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 6),

              // Indicador (dot) del tab activo
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: 6,
                width: selected ? 18 : 6,
                decoration: BoxDecoration(
                  color: selected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  const _NavItemData({required this.icon});
}
