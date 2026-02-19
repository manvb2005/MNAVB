import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/theme_provider.dart';

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeProvider, bool>(
      (provider) => provider.themeMode == ThemeMode.dark,
    );

    final shadowColor = Colors.black.withAlpha((0.18 * 255).round());
    final borderColor = Colors.white.withAlpha((0.30 * 255).round());
    final trackStart = const Color(0xFFFFC76A);
    final trackEnd = const Color(0xFF2A3A67);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () {
            final themeProvider = context.read<ThemeProvider>();
            HapticFeedback.lightImpact();
            themeProvider.toggleTheme();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: 60,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDark
                    ? const [Color(0xFF31406F), Color(0xFF1B264A)]
                    : const [Color(0xFFFFD580), Color(0xFFFFA94D)],
              ),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: isDark ? 0.0 : 0.95,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: isDark ? 0.95 : 0.0,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.nightlight_round,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  alignment: isDark
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.95, end: 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0xFFDEE8FF), Color(0xFF9CB0DD)]
                              : [trackStart, trackEnd],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.20 * 255).round()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Icon(
                          isDark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          key: ValueKey<bool>(isDark),
                          size: 14,
                          color: isDark
                              ? const Color(0xFF30457A)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
