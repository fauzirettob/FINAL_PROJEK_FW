import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animasi masuk elemen UI: fade-in + slide naik halus.
///
/// Bisa diberi [delay] agar beberapa elemen muncul berurutan (staggered),
/// misalnya kartu per kartu di dalam daftar.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan" (reduce motion):
/// jika [MediaQuery.disableAnimations] aktif, konten langsung tampil tanpa
/// animasi.
class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;
  final Curve curve;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
    this.slideOffset = 24,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = CurvedAnimation(
      parent: _controller,
      curve: Interval(0, 0.85, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: selesaikan animasi seketika dan batalkan timer delay
    // agar tidak ada animasi maupun timer tertunda yang tidak diperlukan.
    if (MediaQuery.disableAnimationsOf(context)) {
      _delayTimer?.cancel();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce motion: tampilkan konten langsung tanpa animasi.
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, widget.slideOffset * (1 - _slide.value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Efek tekan (press): elemen sedikit mengecil saat disentuh dan
/// kembali normal saat dilepas — umpan balik sentuhan yang halus.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": saat aktif,
/// efek skala berlangsung instan (tanpa animasi).
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final Curve curve;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.curve = Curves.easeOut,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reduce motion: tanpa durasi animasi (perubahan instan).
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.duration;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// Angka statistik yang berhitung naik (count-up) dari 0 ke [value]
/// setiap kali [value] berubah.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan": saat aktif,
/// nilai akhir langsung ditampilkan tanpa animasi.
class CountUpNumber extends StatelessWidget {
  final int value;
  final Duration duration;
  final Curve curve;
  final TextStyle? style;

  const CountUpNumber({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    // Reduce motion: tampilkan nilai akhir langsung.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(value.toString(), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, _) {
        return Text(
          animatedValue.round().toString(),
          style: style,
        );
      },
    );
  }
}

/// Animasi melayang lembut: elemen naik-turun halus (seperti melayang)
/// secara terus-menerus, dengan gerakan sinusoidal yang tenang.
///
/// Cocok untuk memberi "nyawa" pada satu elemen utama (mis. header Beranda)
/// tanpa terasa berlebihan. Menghormati pengaturan aksesibilitas
/// "kurangi gerakan" (reduce motion): konten tampil statis.
class FloatAnimation extends StatefulWidget {
  final Widget child;

  /// Amplitudo gerakan naik-turun dalam piksel (default 6).
  final double amplitude;

  /// Durasi satu siklus penuh naik-turun (default 3 detik — sangat pelan).
  final Duration duration;

  const FloatAnimation({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<FloatAnimation> createState() => _FloatAnimationState();
}

class _FloatAnimationState extends State<FloatAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce motion: tampilkan konten statis.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Gerakan sinusoidal: -amplitude → +amplitude → -amplitude.
        final dy = math.sin(_controller.value * 2 * math.pi) * widget.amplitude;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
    );
  }
}
