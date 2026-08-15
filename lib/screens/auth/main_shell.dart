import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/floating_nav_bar.dart';
import 'home_screen.dart';
import 'absen_kelas_screen.dart';
import 'students_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'tambah_guru_screen.dart';
import 'olah_data_screen.dart';
import 'login_screen.dart';
import 'rekap_absensi_screen.dart';

class MainShell extends StatefulWidget {
  final FirestoreService? firestoreService;

  const MainShell({super.key, this.firestoreService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Timer? _roleTimeout;
  bool _isRedirecting = false;
  bool _counterSynced = false;

  @override
  void dispose() {
    _roleTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Jika user terautentikasi tetapi role masih null,
    // tampilkan loading spinner sementara.
    // Biasanya ini karena _onAuthStateChanged masih memuat data dari Firestore.
    if (auth.isAuthenticated && auth.role == null) {
      _startRoleTimeout();
      return _buildLoadingScreen(auth);
    }

    // Batalkan timer jika role sudah terisi
    _roleTimeout?.cancel();
    _roleTimeout = null;

    // Jika tidak terautentikasi, redirect ke login
    if (!auth.isAuthenticated) {
      return _buildRedirectToLogin();
    }

    final isAdmin = auth.isAdmin;

    if (isAdmin) {
      // Sinkronkan counter admin sekali saat admin pertama kali login
      if (!_counterSynced) {
        _counterSynced = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FirestoreService().syncAdminCounter().catchError((e) {
            debugPrint('MainShell: Gagal sync admin counter: $e');
          });
        });
      }
      return _buildAdminShell();
    } else {
      return _buildGuruShell();
    }
  }

  void _startRoleTimeout() {
    // Hanya mulai timer jika belum ada
    if (_roleTimeout != null && _roleTimeout!.isActive) return;

    _roleTimeout = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();

      // Jika role masih null setelah 3 detik, redirect ke login
      if (auth.isAuthenticated && auth.role == null) {
        _buildRedirectToLogin(
          message: 'Sesi tidak lengkap. Silakan login ulang.',
        );
      }
    });
  }

  Widget _buildLoadingScreen(AuthProvider auth) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              Color(0xFF1A7A4E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Memuat data...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu sebentar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedirectToLogin({String? message}) {
    if (!_isRedirecting) {
      _isRedirecting = true;
      _roleTimeout?.cancel();

      // Tampilkan snackbar SEBELUM navigasi (context masih valid)
      if (message != null) {
        ToastService.show(
          context,
          message: message,
        );
      }

      // Navigasi setelah frame selesai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }

    // Placeholder selama navigasi
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildGuruShell() {
    final screens = <Widget>[
      HomeScreen(
          onNavigateToTab: switchToTab,
          firestoreService: widget.firestoreService),
      const AbsenKelasScreen(),
      const RekapAbsensiScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: _buildAnimatedTabBody(screens),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          FloatingNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: "Beranda",
          ),
          FloatingNavItem(
            icon: Icons.edit_note_outlined,
            activeIcon: Icons.edit_note,
            label: "Absen Kelas",
          ),
          FloatingNavItem(
            icon: Icons.table_chart_outlined,
            activeIcon: Icons.table_chart,
            label: "Rekap",
          ),
          FloatingNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: "Profil",
          ),
        ],
      ),
    );
  }

  Widget _buildAdminShell() {
    final screens = <Widget>[
      AdminDashboardScreen(onNavigateToTab: switchToTab),
      TambahGuruScreen(onNavigateToTab: switchToTab),
      const StudentsScreen(),
      const OlahDataScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: _buildAnimatedTabBody(screens),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          FloatingNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: "Beranda",
          ),
          FloatingNavItem(
            icon: Icons.person_add_alt_1_outlined,
            activeIcon: Icons.person_add_alt_1,
            label: "Tambah Guru",
          ),
          FloatingNavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: "Data Siswa",
          ),
          FloatingNavItem(
            icon: Icons.manage_search_outlined,
            activeIcon: Icons.manage_search,
            label: "Olah Data",
          ),
          FloatingNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: "Profil",
          ),
        ],
      ),
    );
  }

  void switchToTab(int index) {
    final auth = context.read<AuthProvider>();
    final maxIndex = auth.isAdmin ? 4 : 3;
    if (index >= 0 && index <= maxIndex) {
      setState(() => _currentIndex = index);
    }
  }

  /// Isi tab dengan transisi halus (fade + geser tipis) saat pindah tab.
  /// Menghormati pengaturan aksesibilitas "kurangi gerakan" (reduce motion).
  Widget _buildAnimatedTabBody(List<Widget> screens) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: screens[_currentIndex],
      ),
    );
  }
}
