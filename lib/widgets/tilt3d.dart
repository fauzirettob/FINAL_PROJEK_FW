import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Efek kartu 3D: elemen miring mengikuti posisi kursor (hover) dengan
/// perspektif nyata, seolah kartu "menghadap" ke arah mouse.
///
/// - **Tilt mengikuti kursor**: saat mouse bergerak di atas elemen, kartu
///   berputar 3D (rotateX/rotateY) mengikuti posisi kursor. Saat kursor
///   keluar, kartu kembali mulus ke posisi datar.
/// - **Hanya saat di-hover**: tidak ada gerakan terus-menerus — elemen tetap
///   diam bila tidak disentuh kursor (ramah baterai & tidak berlebihan).
/// - **Warna tetap**: hanya memengaruhi transformasi geometri, tidak
///   mengubah skema warna aplikasi.
/// - Menghormati pengaturan aksesibilitas "kurangi gerakan" (reduce motion):
///   semua animasi & transformasi dinonaktifkan, konten tampil datar.
class Tilt3D extends StatefulWidget {
  final Widget child;

  /// Kemiringan maksimum dalam derajat (default 10°).
  final double maxTilt;

  /// Nilai perspektif kamera pada matriks transformasi (default 0.0012).
  final double perspective;

  /// Durasi animasi respons hover (kembali datar saat kursor keluar).
  final Duration responseDuration;

  /// Aktifkan tilt mengikuti kursor (untuk desktop/web dengan mouse).
  final bool enableHover;

  final MouseCursor cursor;

  const Tilt3D({
    super.key,
    required this.child,
    this.maxTilt = 10,
    this.perspective = 0.0012,
    this.responseDuration = const Duration(milliseconds: 220),
    this.enableHover = true,
    this.cursor = MouseCursor.defer,
  });

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  /// Target kemiringan saat hover, ternormalisasi -0.5..0.5 per sumbu.
  Offset _target = Offset.zero;

  void _handleHover(PointerHoverEvent event) {
    if (!widget.enableHover) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;

    final dx = (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5);
    final dy = (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5);
    // rotateX bergantung posisi vertikal, rotateY pada posisi horizontal.
    final next = Offset(dy, -dx);
    if (next != _target) setState(() => _target = next);
  }

  void _handleExit(PointerExitEvent event) {
    if (_target != Offset.zero) setState(() => _target = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    // Reduce motion: tampilkan konten datar tanpa animasi 3D.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return MouseRegion(
      onHover: _handleHover,
      onExit: _handleExit,
      cursor: widget.cursor,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: _target),
        duration: widget.responseDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
        builder: (context, tilt, child) {
          final rx = tilt.dx * widget.maxTilt * math.pi / 180;
          final ry = tilt.dy * widget.maxTilt * math.pi / 180;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, widget.perspective)
              ..rotateX(rx)
              ..rotateY(ry),
            child: child,
          );
        },
      ),
    );
  }
}
