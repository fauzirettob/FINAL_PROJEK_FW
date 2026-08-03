import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../auth/main_shell.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in utama
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Pulse untuk ikon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Navigasi setelah animasi selesai (2 detik)
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    try {
      // Minimal delay agar animasi sempat tampil (2 detik)
      await Future.delayed(const Duration(seconds: 2));

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
        debugPrint('📱 SplashScreen: setelah menunggu role, retries=$retries, role=${auth.role}');
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
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D6B3E),
              Color(0xFF1A9E5E),
              Color(0xFF28B873),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── Ikon Sekolah ──
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Judul Aplikasi ──
                Text(
                  "Absensi Siswa",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                ),

                const SizedBox(height: 12),

                // ── Subtitle ──
                Text(
                  "Catat kehadiran dengan mudah",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                      ),
                ),

                const SizedBox(height: 8),

                // ── Info kelas ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smartphone_rounded, size: 16, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        "Absensi Digital",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Loading Indicator ──
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "Memuat...",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
