import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import 'absen_kelas_detail_screen.dart';


class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final FirestoreService? firestoreService;

  const HomeScreen({super.key, this.onNavigateToTab, this.firestoreService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();

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

            const SizedBox(height: 20),

            // ── Rekap Per Kelas ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, siswaSnap) {
                final semuaSiswa = siswaSnap.data ?? [];
                return StreamBuilder<List<Absensi>>(
                  stream: _fs.getAbsensiHariIni(DateTime.now()),
                  builder: (context, absenSnap) {
                    final absensiHariIni = absenSnap.data ?? [];

                    // Kelompokkan siswa per kelas
                    final kelasMap = <String, List<Siswa>>{};
                    for (final s in semuaSiswa) {
                      kelasMap.putIfAbsent(s.kelas, () => []);
                      kelasMap[s.kelas]!.add(s);
                    }

                    final kelasList = kelasMap.keys.toList()..sort();
                    final totalAbsensiHariIni = absensiHariIni.length;

                    // Map siswaId -> status untuk lookup cepat
                    final statusMap = <String, String>{};
                    for (final a in absensiHariIni) {
                      statusMap[a.siswaId] = a.status;
                    }

                    return _buildRekapPerKelas(
                      kelasList: kelasList,
                      kelasMap: kelasMap,
                      statusMap: statusMap,
                      totalAbsensiHariIni: totalAbsensiHariIni,
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

  // ─── Helper: Ambil inisial dari nama kelas ────────────────────
  String _getInitials(String kelas) {
    final parts = kelas.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    // Ambil maks 2 huruf pertama jika 1 kata
    final word = parts.isNotEmpty ? parts[0] : '';
    if (word.length <= 2) return word.toUpperCase();
    return word.substring(0, 2).toUpperCase();
  }

  // ─── Helper: Warna unik per kelas ─────────────────────────────
  final List<Color> _kelasPalette = const [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
  ];

  Color _getKelasColor(String kelas) {
    final hash = kelas.hashCode.abs();
    return _kelasPalette[hash % _kelasPalette.length];
  }

  // ─── Rekap Per Kelas ──────────────────────────────────────────
  Widget _buildRekapPerKelas({
    required List<String> kelasList,
    required Map<String, List<Siswa>> kelasMap,
    required Map<String, String> statusMap,
    required int totalAbsensiHariIni,
  }) {
    if (kelasList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            const Text(
              'Rekap Per Kelas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.foreground),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalAbsensiHariIni absensi hari ini',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Info jumlah kelas
        Row(
          children: [
            Icon(Icons.class_, size: 14, color: AppColors.muted.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              '${kelasList.length} kelas',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Cards per kelas
        ...kelasList.map((kelas) {
          final siswaKelas = kelasMap[kelas] ?? [];
          final totalSiswa = siswaKelas.length;
          final hadir = siswaKelas.where((s) => statusMap[s.id] == 'hadir').length;
          final belumAbsen = siswaKelas.where((s) => !statusMap.containsKey(s.id)).length;
          final persenHadir = totalSiswa > 0 ? hadir / totalSiswa : 0.0;

          Color progressColor;
          if (persenHadir >= 0.75) {
            progressColor = AppColors.success;
          } else if (persenHadir >= 0.5) {
            progressColor = AppColors.warning;
          } else {
            progressColor = Colors.red;
          }

          return GestureDetector(
            onTap: () => _showDetailSiswaPerKelas(
              kelas: kelas,
              siswaKelas: siswaKelas,
              statusMap: statusMap,
            ),
            child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Header kelas
                Row(
                  children: [
                    // Badge kelas dengan inisial dan warna
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _getKelasColor(kelas).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(kelas),
                          style: TextStyle(
                            color: _getKelasColor(kelas),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kelas $kelas',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    // Tombol absen cepat dengan warna solid + shadow
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getKelasColor(kelas),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _getKelasColor(kelas).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AbsenKelasDetailScreen(
                                  kelas: kelas,
                                  tanggal: DateTime.now(),
                                ),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Absen',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: persenHadir,
                    backgroundColor: AppColors.border.withValues(alpha: 0.5),
                    color: progressColor,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                // Stat row
                Row(
                  children: [
                    _KelasStatItem(
                      icon: Icons.check_circle_rounded,
                      label: 'Hadir',
                      value: hadir.toString(),
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    _KelasStatItem(
                      icon: Icons.schedule_rounded,
                      label: 'Belum Absen',
                      value: belumAbsen.toString(),
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    _KelasStatItem(
                      icon: Icons.people_alt_rounded,
                      label: 'Total',
                      value: totalSiswa.toString(),
                      color: AppColors.accent,
                    ),
                  ],
                ),

              ],
            ),
          ),
          );
        }),
      ],
    );
  }

  // ─── Detail Siswa Per Kelas (Bottom Sheet) ────────────────────
  void _showDetailSiswaPerKelas({
    required String kelas,
    required List<Siswa> siswaKelas,
    required Map<String, String> statusMap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.class_, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kelas,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          '${siswaKelas.length} siswa',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.border.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            // Status summary bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildBottomSheetStatusBar(siswaKelas, statusMap),
            ),
            const SizedBox(height: 8),
            // Daftar siswa
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: siswaKelas.length,
                itemBuilder: (context, index) {
                  final siswa = siswaKelas[index];
                  final status = statusMap[siswa.id];
                  final sudahAbsen = status != null;

                  String statusLabel;
                  Color statusColor;
                  if (sudahAbsen) {
                    final labels = {'hadir': 'Hadir', 'izin': 'Izin', 'sakit': 'Sakit', 'alpa': 'Alpa'};
                    final colors = {'hadir': AppColors.success, 'izin': AppColors.accent, 'sakit': AppColors.warning, 'alpa': Colors.red};
                    statusLabel = labels[status] ?? status;
                    statusColor = colors[status] ?? AppColors.muted;
                  } else {
                    statusLabel = 'Belum Absen';
                    statusColor = AppColors.muted;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: sudahAbsen
                              ? statusColor.withValues(alpha: 0.12)
                              : AppColors.border.withValues(alpha: 0.5),
                          child: Text(
                            siswa.nama.isNotEmpty ? siswa.nama[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: sudahAbsen ? statusColor : AppColors.muted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ${siswa.nama}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.foreground,
                                ),
                              ),
                              Text(
                                siswa.nis,
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Sheet Status Bar ──────────────────────────────────
  Widget _buildBottomSheetStatusBar(
    List<Siswa> siswaKelas,
    Map<String, String> statusMap,
  ) {
    final hadir = siswaKelas.where((s) => statusMap[s.id] == 'hadir').length;
    final izin = siswaKelas.where((s) => statusMap[s.id] == 'izin').length;
    final sakit = siswaKelas.where((s) => statusMap[s.id] == 'sakit').length;
    final alpa = siswaKelas.where((s) => statusMap[s.id] == 'alpa').length;
    final belumAbsen = siswaKelas.where((s) => !statusMap.containsKey(s.id)).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _SheetStatusPill(label: 'H', value: hadir, color: AppColors.success),
          _SheetStatusPill(label: 'I', value: izin, color: AppColors.accent),
          _SheetStatusPill(label: 'S', value: sakit, color: AppColors.warning),
          _SheetStatusPill(label: 'A', value: alpa, color: Colors.red),
          _SheetStatusPill(label: '?', value: belumAbsen, color: AppColors.muted),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet Status Pill ──────────────────────────────────
class _SheetStatusPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SheetStatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kelas Stat Item ──────────────────────────────────────────
class _KelasStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KelasStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
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

