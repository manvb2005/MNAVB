import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/theme_provider.dart';

class ThemeSwitch extends StatelessWidget {
  const ThemeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    return GestureDetector(
      onTap: () => themeProvider.toggleTheme(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: child),
        child: isDark
            ? const Icon(Icons.nightlight_round, key: ValueKey('moon'), color: Colors.yellow)
            : const Icon(Icons.wb_sunny, key: ValueKey('sun'), color: Colors.orange),
      ),
    );
  }
}
