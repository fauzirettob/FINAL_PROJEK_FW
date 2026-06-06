import 'package:flutter/material.dart';

class BgWidget extends StatelessWidget {
  final Widget child;

  const BgWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1A2E) : null,
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: isDark
          ? Stack(
              children: [
                // Dark overlay for dark mode
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                child,
              ],
            )
          : child,
    );
  }
}
