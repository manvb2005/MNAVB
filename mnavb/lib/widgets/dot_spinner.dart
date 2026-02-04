import 'package:flutter/material.dart';
import 'dart:math' as math;

class DotSpinner extends StatefulWidget {
  final double size;
  final Color color;
  const DotSpinner({super.key, this.size = 48, this.color = Colors.white});

  @override
  State<DotSpinner> createState() => _DotSpinnerState();
}

class _DotSpinnerState extends State<DotSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotCount = 8;
    final dots = List.generate(dotCount, (i) {
      final angle = (2 * math.pi / dotCount) * i;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final delay = -0.125 * i;
          final t = (_controller.value + delay) % 1.0;
          final scale = t < 0.5 ? t * 2 : (1 - t) * 2;
          final opacity = 0.5 + 0.5 * scale;
          return Transform(
            transform: Matrix4.identity()
              ..translate(
                (widget.size / 2 - widget.size * 0.15) * math.cos(angle),
                (widget.size / 2 - widget.size * 0.15) * math.sin(angle),
                0.0,
              ),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: widget.size * 0.18,
                height: widget.size * 0.18,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withAlpha((0.3 * 255).toInt()),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: dots,
      ),
    );
  }
}
