import 'package:flutter/material.dart';
import 'dot_spinner.dart';

class LoaderOverlay extends StatelessWidget {
  final bool show;
  final Widget? child;
  const LoaderOverlay({super.key, required this.show, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child case final currentChild?) currentChild,
        if (show)
          Positioned.fill(
            child: Container(
              color: const Color.fromRGBO(0, 0, 0, 0.35),
              child: const Center(
                child: DotSpinner(size: 64, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
