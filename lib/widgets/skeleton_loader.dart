import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget skeleton dengan efek shimmer yang halus untuk loading state.
class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _animation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE8ECF0),
                Color(0xFFFFFFFF),
                Color(0xFFE8ECF0),
              ],
              stops: [
                (_animation.value - 0.15).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.15).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PRIMITIVE SKELETON WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Boneka skeleton persegi panjang dengan sudut membulat.
class SkeletonRect extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonRect({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
    );
  }
}

/// Boneka skeleton lingkaran.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SCREEN-SPECIFIC SKELETONS
// ═══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// 1. REGISTER SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton khusus untuk halaman registrasi — meniru layout form.
class RegisterSkeleton extends StatelessWidget {
  const RegisterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Header skeleton (icon, title, subtitle)
          Center(
            child: Column(
              children: [
                const SkeletonCircle(size: 64),
                const SizedBox(height: 16),
                const SkeletonRect(width: 200, height: 28, borderRadius: 8),
                const SizedBox(height: 10),
                const SkeletonRect(width: 240, height: 16, borderRadius: 6),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Field 1: Nama Lengkap
          const SkeletonRect(width: 100, height: 14, borderRadius: 6),
          const SizedBox(height: 10),
          const SkeletonRect(height: 56, borderRadius: 16),
          const SizedBox(height: 20),

          // Field 2: Email
          const SkeletonRect(width: 60, height: 14, borderRadius: 6),
          const SizedBox(height: 10),
          const SkeletonRect(height: 56, borderRadius: 16),
          const SizedBox(height: 20),

          // Field 3: Password
          const SkeletonRect(width: 80, height: 14, borderRadius: 6),
          const SizedBox(height: 10),
          const SkeletonRect(height: 56, borderRadius: 16),
          const SizedBox(height: 20),

          // Field 4: Konfirmasi Password
          const SkeletonRect(width: 140, height: 14, borderRadius: 6),
          const SizedBox(height: 10),
          const SkeletonRect(height: 56, borderRadius: 16),

          const SizedBox(height: 32),

          // Button skeleton
          const SkeletonRect(height: 56, borderRadius: 16),

          const SizedBox(height: 24),

          // Login link skeleton
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: const SkeletonRect(width: 180, height: 18, borderRadius: 6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. HOME SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman utama (HomeScreen).
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Gradient Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: AppColors.gradientMain,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting + notification bell
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonRect(width: 140, height: 16, borderRadius: 6),
                    const SkeletonCircle(size: 36),
                  ],
                ),
                const SizedBox(height: 8),
                // Nama guru
                const SkeletonRect(width: 180, height: 22, borderRadius: 6),
                const SizedBox(height: 16),
                // Attendance card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonRect(
                            width: 100, height: 12, borderRadius: 4,
                          ),
                          const SizedBox(height: 8),
                          const SkeletonRect(
                            width: 60, height: 28, borderRadius: 6,
                          ),
                          const SizedBox(height: 4),
                          const SkeletonRect(
                            width: 80, height: 12, borderRadius: 4,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _MiniSkeleton(label: 'H'),
                          const SizedBox(width: 8),
                          _MiniSkeleton(label: 'T'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Stat Cards ──
          Row(
            children: [
              Expanded(child: _StatSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _StatSkeleton()),
            ],
          ),

          const SizedBox(height: 24),

          // ── Akses Cepat ──
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 100, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _QuickActionSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _QuickActionSkeleton()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _QuickActionSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _QuickActionSkeleton()),
            ],
          ),

          const SizedBox(height: 24),

          // ── Daftar Hadir Hari Ini ──
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 200, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SkeletonRect(width: 100, height: 36, borderRadius: 18),
                SizedBox(width: 8),
                SkeletonRect(width: 70, height: 36, borderRadius: 18),
                SizedBox(width: 8),
                SkeletonRect(width: 80, height: 36, borderRadius: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Status summary bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: List.generate(4, (_) => const Expanded(
                child: _StatusPillSkeleton(),
              )).expand((w) => [w, const SizedBox(width: 8)]).toList()
                ..removeLast(),
            ),
          ),
          const SizedBox(height: 16),

          // Student attendance cards
          ...List.generate(4, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _AttendanceCardSkeleton(),
          )),

          const SizedBox(height: 20),

          // Riwayat button
          const SkeletonRect(height: 50, borderRadius: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. STUDENTS SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Data Siswa (StudentsScreen).
class StudentsSkeleton extends StatelessWidget {
  const StudentsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const SkeletonRect(height: 50, borderRadius: 16),
        ),
        const SizedBox(height: 12),
        // Dropdown filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const SkeletonRect(height: 50, borderRadius: 16),
        ),
        const SizedBox(height: 12),
        // Student cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _StudentCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. REPORTS SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Laporan (ReportsScreen).
class ReportsSkeleton extends StatelessWidget {
  const ReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Kategori filter
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 100, height: 14, borderRadius: 6),
          ),
          const SizedBox(height: 8),
          const SkeletonRect(height: 50, borderRadius: 16),
          const SizedBox(height: 16),

          // Date filter chip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                SkeletonRect(width: 160, height: 36, borderRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.gradientMain,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                SkeletonRect(width: 140, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonRect(width: 80, height: 36, borderRadius: 8),
                SizedBox(height: 12),
                SkeletonRect(width: 120, height: 14, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chart
          Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                SkeletonRect(height: 160, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stat cards row 1
          Row(
            children: [
              Expanded(child: _ReportStatSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _ReportStatSkeleton()),
            ],
          ),
          const SizedBox(height: 8),

          // Stat cards row 2
          Row(
            children: [
              Expanded(child: _ReportStatSkeleton()),
              const SizedBox(width: 12),
              Expanded(child: _ReportStatSkeleton()),
            ],
          ),
          const SizedBox(height: 24),

          // Detail title
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 120, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),

          // Detail cards
          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _ReportDetailCardSkeleton(),
          )),

          const SizedBox(height: 12),

          // Buttons
          const SkeletonRect(height: 50, borderRadius: 16),
          const SizedBox(height: 12),
          const SkeletonRect(height: 50, borderRadius: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PROFILE SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Profil (ProfileScreen).
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Gradient Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.gradientMain,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Column(
              children: [
                SkeletonCircle(size: 80),
                SizedBox(height: 16),
                SkeletonRect(width: 160, height: 22, borderRadius: 6),
                SizedBox(height: 4),
                SkeletonRect(width: 200, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonRect(width: 140, height: 12, borderRadius: 6),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info Akun
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 80, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),

          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _InfoCardSkeleton(),
          )),

          const SizedBox(height: 24),

          // Pengaturan
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 90, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),

          // Settings container
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                _SettingsTileSkeleton(),
                Divider(height: 1, color: AppColors.border),
                _SettingsTileSkeleton(),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout button
          const SkeletonRect(height: 52, borderRadius: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. HISTORY SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Riwayat Absensi (HistoryScreen).
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              // Search
              const SkeletonRect(height: 44, borderRadius: 12),
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    SkeletonRect(width: 150, height: 36, borderRadius: 20),
                    SizedBox(width: 8),
                    SkeletonRect(width: 100, height: 36, borderRadius: 20),
                    SizedBox(width: 8),
                    SkeletonRect(width: 110, height: 36, borderRadius: 20),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _HistoryCardSkeleton(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. STUDENT DETAIL SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Detail Siswa (StudentDetailScreen).
class StudentDetailSkeleton extends StatelessWidget {
  const StudentDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Student header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradientMain,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                SkeletonCircle(size: 72),
                SizedBox(height: 12),
                SkeletonRect(width: 180, height: 20, borderRadius: 6),
                SizedBox(height: 6),
                SkeletonRect(width: 140, height: 16, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonRect(width: 120, height: 12, borderRadius: 6),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Stats summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const SkeletonRect(width: 100, height: 40, borderRadius: 8),
                const SizedBox(height: 6),
                const SkeletonRect(width: 120, height: 14, borderRadius: 6),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(4, (_) => const Expanded(
                    child: _MiniStatSkeleton(),
                  )).expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Mini chart
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonRect(width: 140, height: 16, borderRadius: 6),
                const SizedBox(height: 16),
                const SkeletonRect(height: 150, borderRadius: 12),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // History title
          const Align(
            alignment: Alignment.centerLeft,
            child: SkeletonRect(width: 160, height: 18, borderRadius: 6),
          ),
          const SizedBox(height: 12),

          // History cards
          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _HistoryCardSkeleton(),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. SCAN SKELETON
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton untuk halaman Absensi Foto (ScanScreen).
class ScanSkeleton extends StatelessWidget {
  const ScanSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Camera placeholder
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonCircle(size: 80),
                  SizedBox(height: 16),
                  SkeletonRect(width: 160, height: 18, borderRadius: 6),
                  SizedBox(height: 6),
                  SkeletonRect(width: 140, height: 14, borderRadius: 6),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // NIS input
          const SkeletonRect(height: 56, borderRadius: 16),

          const SizedBox(height: 20),

          // Status buttons (2x2)
          Row(
            children: [
              Expanded(child: _StatusButtonSkeleton()),
              const SizedBox(width: 8),
              Expanded(child: _StatusButtonSkeleton()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatusButtonSkeleton()),
              const SizedBox(width: 8),
              Expanded(child: _StatusButtonSkeleton()),
            ],
          ),

          const SizedBox(height: 24),

          // Submit button
          const SkeletonRect(height: 54, borderRadius: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PRIVATE HELPER SKELETON WIDGETS (shared across screen skeletons)
// ═══════════════════════════════════════════════════════════════════════════════

/// Mini stat digunakan di dalam header HomeScreen.
class _MiniSkeleton extends StatelessWidget {
  final String label;
  const _MiniSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SkeletonRect(width: 32, height: 20, borderRadius: 4),
        const SizedBox(height: 4),
        SkeletonRect(width: 12, height: 10, borderRadius: 3),
      ],
    );
  }
}

/// Stat card skeleton (icon + value + label).
class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonRect(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 40, height: 20, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 60, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action card skeleton (icon + label).
class _QuickActionSkeleton extends StatelessWidget {
  const _QuickActionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          SkeletonCircle(size: 28),
          SizedBox(height: 8),
          SkeletonRect(width: 60, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Status pill skeleton for the summary bar.
class _StatusPillSkeleton extends StatelessWidget {
  const _StatusPillSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          SkeletonRect(width: 24, height: 18, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonRect(width: 30, height: 10, borderRadius: 3),
        ],
      ),
    );
  }
}

/// Attendance card skeleton (used in HomeScreen daftar hadir).
class _AttendanceCardSkeleton extends StatelessWidget {
  const _AttendanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 160, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SkeletonRect(width: 80, height: 28, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Student card skeleton (used in StudentsScreen).
class _StudentCardSkeleton extends StatelessWidget {
  const _StudentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonRect(width: 120, height: 15, borderRadius: 4),
                const SizedBox(height: 4),
                const SkeletonRect(width: 140, height: 13, borderRadius: 4),
                const SizedBox(height: 4),
                const SkeletonRect(width: 60, height: 20, borderRadius: 8),
              ],
            ),
          ),
          Row(
            children: const [
              SkeletonCircle(size: 36),
              SizedBox(width: 4),
              SkeletonCircle(size: 36),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat skeleton used in ReportsScreen.
class _ReportStatSkeleton extends StatelessWidget {
  const _ReportStatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          SkeletonRect(width: 40, height: 22, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonRect(width: 40, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Report detail card skeleton (used in ReportsScreen).
class _ReportDetailCardSkeleton extends StatelessWidget {
  const _ReportDetailCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonRect(width: 64, height: 64, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 100, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 80, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonRect(width: 60, height: 26, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Info card skeleton (used in ProfileScreen).
class _InfoCardSkeleton extends StatelessWidget {
  const _InfoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonRect(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 80, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 140, height: 15, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings tile skeleton (used in ProfileScreen).
class _SettingsTileSkeleton extends StatelessWidget {
  const _SettingsTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SkeletonRect(width: 24, height: 24, borderRadius: 6),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 80, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 120, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonCircle(size: 20),
        ],
      ),
    );
  }
}

/// History card skeleton (used in HistoryScreen & StudentDetailScreen).
class _HistoryCardSkeleton extends StatelessWidget {
  const _HistoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonRect(width: 64, height: 64, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonRect(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 160, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonRect(width: 80, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonRect(width: 60, height: 26, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Mini stat skeleton (used in StudentDetailScreen).
class _MiniStatSkeleton extends StatelessWidget {
  const _MiniStatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          SkeletonRect(width: 28, height: 18, borderRadius: 4),
          SizedBox(height: 4),
          SkeletonRect(width: 30, height: 11, borderRadius: 3),
        ],
      ),
    );
  }
}

/// Status button skeleton (used in ScanScreen).
class _StatusButtonSkeleton extends StatelessWidget {
  const _StatusButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          SkeletonCircle(size: 24),
          SizedBox(height: 6),
          SkeletonRect(width: 40, height: 13, borderRadius: 4),
        ],
      ),
    );
  }
}
