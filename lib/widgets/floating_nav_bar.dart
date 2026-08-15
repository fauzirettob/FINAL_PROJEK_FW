import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Satu item navigasi pada [FloatingNavBar].
class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Navigasi bawah mengambang (floating dock) dengan desain modern.
///
/// Keunggulan dibanding `BottomNavigationBar` bawaan:
/// - Berupa "dock" mengambang dengan sudut membulat & bayangan lembut.
/// - Item aktif diberi lingkaran gradien + label tebal berwarna.
/// - Efek **hover "menggelembung"**: saat kursor (desktop/web) menyentuh
///   item, ikon membesar dengan kurva elastis (`elasticOut`) dan memunculkan
///   kilau (glow) — persis seperti gelembung yang mengembang.
/// - Di layar sentuh, item tetap mengecil sesaat saat ditekan (press feedback).
/// - Item dibagi rata (`Expanded`) sehingga aman di layar sempit — tidak ada
///   overflow, label menyesuaikan otomatis.
/// - Mendukung keyboard (Tab + Enter/Spasi) & screen reader via Semantics.
/// - Menghormati pengaturan aksesibilitas "kurangi gerakan" (reduce motion).
class FloatingNavBar extends StatefulWidget {
  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor = AppColors.primary,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  /// Indeks item yang sedang di-hover (untuk efek menggelembung).
  int? _hoveredIndex;

  /// Indeks item yang sedang ditekan (press feedback di layar sentuh).
  int? _pressedIndex;

  void _setHovered(int? index) {
    if (mounted && _hoveredIndex != index) {
      setState(() => _hoveredIndex = index);
    }
  }

  void _setPressed(int? index) {
    if (mounted && _pressedIndex != index) {
      setState(() => _pressedIndex = index);
    }
  }

  /// Aktivasi via keyboard (Enter/Spasi) saat item mendapat fokus.
  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Reduce motion: animasi menjadi instan.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.foreground.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < widget.items.length; i++)
                Expanded(child: _buildItem(i, duration)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, Duration duration) {
    final item = widget.items[index];
    final isActive = index == widget.currentIndex;
    final isHovered = index == _hoveredIndex;
    final isPressed = index == _pressedIndex;
    final color = widget.activeColor;

    // Skala: menggelembung saat hover (elastis), mengecil saat ditekan.
    double scale = 1.0;
    if (isHovered) scale = 1.18;
    if (isPressed) scale = 0.92;

    return Semantics(
      button: true,
      selected: isActive,
      child: MouseRegion(
        onEnter: (_) => _setHovered(index),
        onExit: (_) => _setHovered(null),
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: item.label,
          waitDuration: const Duration(milliseconds: 600),
          child: Focus(
            canRequestFocus: true,
            onKeyEvent: (node, event) => _handleKeyEvent(index, event),
            child: GestureDetector(
              onTap: () => widget.onTap(index),
              onTapDown: (_) => _setPressed(index),
              onTapUp: (_) => _setPressed(null),
              onTapCancel: () => _setPressed(null),
              child: AnimatedScale(
                scale: scale,
                duration: duration,
                curve: isHovered ? Curves.elasticOut : Curves.easeOut,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lingkaran ikon: gradien saat aktif, kilau saat hover.
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOut,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              isActive ? AppColors.gradientMain : null,
                          color: isActive
                              ? null
                              : (isHovered
                                  ? color.withValues(alpha: 0.12)
                                  : Colors.transparent),
                          boxShadow: [
                            if (isActive)
                              BoxShadow(
                                color: color.withValues(alpha: 0.40),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              )
                            else if (isHovered)
                              BoxShadow(
                                color: color.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: isActive
                              ? Colors.white
                              : (isHovered ? color : AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // FittedBox mengecilkan label otomatis bila ruang sempit,
                      // sehingga teks tetap utuh (tanpa elipsis) di HP kecil.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? color
                                : (isHovered
                                    ? AppColors.foreground
                                    : AppColors.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
