import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import 'history_screen.dart';


class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final FirestoreService? firestoreService;

  const HomeScreen({super.key, this.onNavigateToTab, this.firestoreService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();
  String? _selectedKelas;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guru = auth.guru;
    final namaGuru = guru?.nama ?? 'Guru';
    final sapaan = _getGreeting();

    return SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header Gradient ──
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$sapaan 👋",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: () {
                          _navigateToTab(4);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    namaGuru,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ── Card Kehadiran Hari Ini ──
                  const SizedBox(height: 16),
                  StreamBuilder<List<Absensi>>(
                    stream: _fs.getAbsensiHariIni(DateTime.now()),
                    builder: (context, snapshot) {
                      final absensiHariIni = snapshot.data ?? [];
                      final total = absensiHariIni.length;
                      final hadir = absensiHariIni.where((a) => a.status == 'hadir').length;
                      final persen = total > 0 ? ((hadir / total) * 100).toStringAsFixed(0) : '0';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Kehadiran Hari Ini",
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$persen%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "$total siswa",
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _MiniStat(
                                  label: "H",
                                  value: hadir.toString(),
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(width: 8),
                                _MiniStat(
                                  label: "T",
                                  value: (total - hadir).toString(),
                                  color: Colors.orangeAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Statistik Ringkas ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, snapshot) {
                final totalSiswa = snapshot.data?.length ?? 0;

                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_alt_rounded,
                        label: 'Total Siswa',
                        value: totalSiswa.toString(),
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<List<Absensi>>(
                        stream: _fs.getAllAbsensi(),
                        builder: (context, snap) {
                          final totalAbsensi = snap.data?.length ?? 0;
                          return _StatCard(
                            icon: Icons.checklist_rounded,
                            label: 'Total Absensi',
                            value: totalAbsensi.toString(),
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Akses Cepat ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Akses Cepat",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.foreground),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.photo_camera_rounded,
                    color: AppColors.success,
                    label: "Absensi ",
                    onTap: () => _navigateToTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.people_rounded,
                    color: AppColors.accent,
                    label: "Data Siswa",
                    onTap: () => _navigateToTab(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.warning,
                    label: "Laporan",
                    onTap: () => _navigateToTab(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.history_rounded,
                    color: Colors.deepPurple,
                    label: "Riwayat",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Daftar Hadir ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Daftar Hadir Hari Ini",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.foreground),
              ),
            ),
            const SizedBox(height: 12),
            // Gabungkan data siswa + absensi hari ini
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, siswaSnapshot) {
                if (siswaSnapshot.hasError) {
                  return _buildErrorState('Gagal memuat data siswa');
                }
                if (!siswaSnapshot.hasData) {
                  return _buildLoadingState();
                }

                final semuaSiswa = siswaSnapshot.data!;

                return StreamBuilder<List<Absensi>>(
                  stream: _fs.getAbsensiHariIni(DateTime.now()),
                  builder: (context, absensiSnapshot) {
                    final absensiHariIni = absensiSnapshot.data ?? [];

                    // Map siswaId -> Absensi untuk lookup cepat
                    final absensiMap = <String, Absensi>{};
                    for (final a in absensiHariIni) {
                      absensiMap[a.siswaId] = a;
                    }

                    if (semuaSiswa.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'Belum ada siswa terdaftar',
                        subtitle: 'Tambahkan siswa melalui menu Data Siswa',
                      );
                    }

                    // Kumpulkan daftar kelas unik
                    final daftarKelas = semuaSiswa
                        .map((s) => s.kelas)
                        .toSet()
                        .toList()
                      ..sort();

                    // Filter berdasarkan kelas yang dipilih
                    var siswaTerfilter = semuaSiswa;
                    if (_selectedKelas != null) {
                      siswaTerfilter = semuaSiswa
                          .where((s) => s.kelas == _selectedKelas)
                          .toList();
                    }

                    // Urutkan: Hadir, Izin, Sakit, Alpa, Belum Absen
                    final statusOrder = {'hadir': 0, 'izin': 1, 'sakit': 2, 'alpa': 3};
                    final sortedSiswa = List<Siswa>.from(siswaTerfilter);
                    sortedSiswa.sort((a, b) {
                      final aAbsen = absensiMap[a.id];
                      final bAbsen = absensiMap[b.id];
                      final aOrder = aAbsen != null ? (statusOrder[aAbsen.status] ?? 4) : 4;
                      final bOrder = bAbsen != null ? (statusOrder[bAbsen.status] ?? 4) : 4;
                      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
                      return a.nama.compareTo(b.nama);
                    });

                    // Hitung ulang berdasarkan data yang sudah difilter
                    final absensiTerfilter = <Absensi>[];
                    for (final siswa in siswaTerfilter) {
                      final absen = absensiMap[siswa.id];
                      if (absen != null) {
                        absensiTerfilter.add(absen);
                      }
                    }
                    final totalSiswa = siswaTerfilter.length;
                    final totalTerabsen = absensiTerfilter.length;
                    final belumAbsen = totalSiswa - totalTerabsen;

                    return Column(
                      children: [
                        // ── Filter Kelas ──
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(
                                label: 'Semua Kelas',
                                isSelected: _selectedKelas == null,
                                onTap: () => setState(() => _selectedKelas = null),
                              ),
                              const SizedBox(width: 8),
                              ...daftarKelas.map((kelas) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _FilterChip(
                                      label: kelas,
                                      isSelected: _selectedKelas == kelas,
                                      onTap: () =>
                                          setState(() => _selectedKelas = kelas),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Ringkasan Status ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _StatusPill(
                                    label: 'Hadir',
                                    value: absensiTerfilter.where((a) => a.status == 'hadir').length,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(
                                    label: 'Izin',
                                    value: absensiTerfilter.where((a) => a.status == 'izin').length,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(
                                    label: 'Sakit',
                                    value: absensiTerfilter.where((a) => a.status == 'sakit').length,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(
                                    label: 'Alpa',
                                    value: absensiTerfilter.where((a) => a.status == 'alpa').length,
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              if (belumAbsen > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline,
                                          size: 16, color: AppColors.warning),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$belumAbsen siswa belum melakukan absensi',
                                        style: const TextStyle(
                                          color: AppColors.warning,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Daftar Lengkap ──
                        if (sortedSiswa.isEmpty)
                          _buildEmptyState(
                            icon: Icons.inbox_rounded,
                            title: 'Tidak ada siswa di kelas ini',
                            subtitle: _selectedKelas != null
                                ? 'Pilih kelas lain atau reset filter'
                                : 'Tambahkan siswa untuk memulai',
                          )
                        else ...[
                          // Info jumlah ditampilkan
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  'Menampilkan ${sortedSiswa.length} siswa',
                                  style: TextStyle(
                                    color: AppColors.muted.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...sortedSiswa.map((siswa) {
                            final absen = absensiMap[siswa.id];
                            return _buildDaftarHadirCard(siswa, absen);
                          }),
                        ],

                        const SizedBox(height: 20),

                        // ── Tombol Riwayat ──
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history_rounded),
                            label: const Text("Lihat Riwayat Lengkap"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTab(int tabIndex) {
    widget.onNavigateToTab?.call(tabIndex);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.muted)),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDaftarHadirCard(Siswa siswa, Absensi? absen) {
    final bool sudahAbsen = absen != null;

    String statusLabel;
    Color statusColor;
    if (sudahAbsen) {
      final a = absen;
      final labels = {
        'hadir': 'Hadir',
        'izin': 'Izin',
        'sakit': 'Sakit',
        'alpa': 'Alpa',
      };
      final colors = {
        'hadir': AppColors.success,
        'izin': AppColors.accent,
        'sakit': AppColors.warning,
        'alpa': Colors.red,
      };
      statusLabel = labels[a.status] ?? a.status;
      statusColor = colors[a.status] ?? AppColors.muted;
    } else {
      statusLabel = 'Belum Absen';
      statusColor = AppColors.muted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sudahAbsen
              ? AppColors.border
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar lingkaran dengan inisial
          CircleAvatar(
            radius: 18,
            backgroundColor: sudahAbsen
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.border.withValues(alpha: 0.5),
            child: Text(
              siswa.nama.isNotEmpty ? siswa.nama[0].toUpperCase() : '?',
              style: TextStyle(
                color: sudahAbsen ? AppColors.primary : AppColors.muted,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Detail siswa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siswa.nama,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: sudahAbsen
                        ? AppColors.foreground
                        : AppColors.foreground.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      siswa.kelas,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),

                  ],
                ),
              ],
            ),
          ),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip (untuk filter kelas) ──
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Status Pill (ringkasan status di daftar hadir) ──
class _StatusPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini Stat (used inside header) ──
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action ──
class _QuickAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowOpacity;
  late Animation<double> _shadowBlur;
  late Animation<double> _shadowOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowOpacity = Tween<double>(begin: 0.12, end: 0.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowBlur = Tween<double>(begin: 12.0, end: 3.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowOffset = Tween<double>(begin: 4.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _shadowOpacity.value),
                blurRadius: _shadowBlur.value,
                offset: Offset(0, _shadowOffset.value),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.color, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
