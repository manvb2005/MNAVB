import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color c(double o) {
      // Gris oscuro en modo claro para mejor contraste
      final base = isDark ? const Color(0xFF888888) : const Color(0xFFB0B0B0);
      return base.withAlpha((255 * o).round());
    }
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -120,
          child: _circle(280, c(0.18)),
        ),
        Positioned(
          top: 120,
          right: -140,
          child: _circle(320, c(0.12)),
        ),
        Positioned(
          bottom: -160,
          left: -140,
          child: _circle(340, c(0.24)),
        ),
        SafeArea(child: child),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
