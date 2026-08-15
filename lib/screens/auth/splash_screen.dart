import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../auth/main_shell.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';

/// Splash screen elegan & modern: gradient hijau yang mengalir pelan, orb
/// bercahaya melayang, logo kaca (glassmorphism) dengan glow yang berdenyut
/// lembut, dan elemen yang muncul bertahap. Semuanya 2D — tanpa efek 3D.
///
/// Menghormati pengaturan aksesibilitas "kurangi gerakan" (reduce motion):
/// semua animasi dinonaktifkan, konten tampil statis.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Menggerakkan aliran gradient & drift orb (terus-menerus, pelan).
  late final AnimationController _bgController;

  /// Denyut lembut logo (scale kecil naik-turun).
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Bolak-balik halus (reverse) agar aliran gradient tidak "melompat"
    // saat loop berulang.
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _navigateAfterDelay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: hentikan animasi, tampilkan posisi statis.
    if (MediaQuery.disableAnimationsOf(context)) {
      _bgController.stop();
      _bgController.value = 0.0;
      _pulseController.stop();
      _pulseController.value = 0.5;
    } else if (!_bgController.isAnimating) {
      _bgController.repeat(reverse: true);
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  /// Navigasi ke halaman berikutnya (MainShell jika sudah login,
  /// LoginScreen jika belum). Hanya berjalan SEKALI.
  Future<void> _navigateAfterDelay([
    Duration delay = const Duration(seconds: 2),
  ]) async {
    if (_navigated) return;
    _navigated = true;

    try {
      // Delay minimal agar splash sempat tampil
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      debugPrint('📱 SplashScreen: user=${auth.user?.uid}, role=${auth.role}');

      // Jika user sudah login, tunggu role-nya selesai dimuat (max 5 detik)
      if (auth.user != null) {
        int retries = 0;
        while (retries < 20 && auth.role == null && mounted) {
          await Future.delayed(const Duration(milliseconds: 250));
          retries++;
        }
        debugPrint(
            '📱 SplashScreen: setelah menunggu role, retries=$retries, role=${auth.role}');
      }

      if (!mounted) return;

      final tujuan = auth.isAuthenticated ? 'MainShell' : 'LoginScreen';
      debugPrint('📱 SplashScreen: navigasi ke $tujuan');

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            if (auth.isAuthenticated) {
              return const MainShell();
            } else {
              return const LoginScreen();
            }
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      debugPrint('❌ SplashScreen navigation error: $e');
      // Fallback: coba navigasi ke login langsung
      if (mounted) {
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } catch (_) {
          debugPrint('❌ SplashScreen fallback navigation juga gagal');
        }
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background: gradient hijau mengalir + orb bercahaya ──
          _buildBackground(),

          // ── Konten utama ──
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Logo kaca dengan glow berdenyut ──
                EntranceAnimation(
                  duration: const Duration(milliseconds: 650),
                  slideOffset: 26,
                  child: _buildLogo(),
                ),

                const SizedBox(height: 24),

                // ── Judul ──
                EntranceAnimation(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'Absensi Siswa',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          letterSpacing: 0.6,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tagline ──
                EntranceAnimation(
                  delay: const Duration(milliseconds: 320),
                  child: Text(
                    'Catat kehadiran dengan mudah',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Badge ──
                EntranceAnimation(
                  delay: const Duration(milliseconds: 430),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smartphone_rounded,
                            size: 16, color: Colors.white70),
                        SizedBox(width: 7),
                        Text(
                          'Absensi Digital',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Indikator loading ──
                EntranceAnimation(
                  delay: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                EntranceAnimation(
                  delay: const Duration(milliseconds: 330),
                  child: Text(
                    'Memuat...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),

          // ── Vignette lembut di tepi ──
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.3,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.16),
                  ],
                  stops: const [0.62, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient hijau yang mengalir pelan + orb bercahaya melayang (2D).
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final t = _bgController.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.lerp(
                  Alignment.topLeft, Alignment.bottomLeft, t)!,
              end: Alignment.lerp(
                  Alignment.bottomRight, Alignment.topRight, t)!,
              colors: const [
                Color(0xFF0A5C34),
                Color(0xFF149B59),
                Color(0xFF26C979),
              ],
            ),
          ),
          child: Stack(
            children: [
              _orb(
                align: const Alignment(-0.85, -0.9),
                size: 240,
                opacity: 0.16,
                phase: 0.0,
                speed: 1.0,
                t: t,
              ),
              _orb(
                align: const Alignment(0.95, -0.55),
                size: 180,
                opacity: 0.13,
                phase: 2.1,
                speed: 0.7,
                t: t,
              ),
              _orb(
                align: const Alignment(-0.7, 0.95),
                size: 210,
                opacity: 0.12,
                phase: 4.2,
                speed: 0.85,
                t: t,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Satu orb bercahaya yang melayang perlahan (gerakan sinusoidal).
  Widget _orb({
    required Alignment align,
    required double size,
    required double opacity,
    required double phase,
    required double speed,
    required double t,
  }) {
    return Align(
      alignment: align,
      child: Transform.translate(
        offset: Offset(
          math.sin(t * 2 * math.pi * speed + phase) * 26,
          math.cos(t * 2 * math.pi * speed * 0.6 + phase) * 22,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: opacity),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Logo kaca (glassmorphism) dengan glow ring & denyut lembut.
  Widget _buildLogo() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring di belakang logo
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.24),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Badge logo dengan denyut halus
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.28),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
