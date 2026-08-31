import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/absensi.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';
import 'absen_kelas_detail_screen.dart';

class AbsenKelasScreen extends StatefulWidget {
  const AbsenKelasScreen({super.key});

  @override
  State<AbsenKelasScreen> createState() => _AbsenKelasScreenState();
}

class _AbsenKelasScreenState extends State<AbsenKelasScreen> {
  final _today = DateTime.now();
  final FirestoreService _fs = FirestoreService();
  Map<String, int> _absensiCountPerMapel = {}; // mapel -> jumlah siswa yang sudah diabsen
  Map<String, Map<String, int>> _statusCountPerMapel = {}; // mapel -> {hadir: n, izin: n, sakit: n, alpa: n}

  @override
  void initState() {
    super.initState();
    _loadAbsensiCount();
  }

  Future<void> _loadAbsensiCount() async {
    final absensiList = await _fs.getAbsensiByDate(_today);
    if (!mounted) return;

    final countMap = <String, int>{};
    final statusMap = <String, Map<String, int>>{};
    for (final a in absensiList) {
      if (a.mataPelajaran.isNotEmpty) {
        countMap[a.mataPelajaran] = (countMap[a.mataPelajaran] ?? 0) + 1;
        statusMap.putIfAbsent(a.mataPelajaran, () => {});
        statusMap[a.mataPelajaran]![a.status] =
            (statusMap[a.mataPelajaran]![a.status] ?? 0) + 1;
      }
    }
    setState(() {
      _absensiCountPerMapel = countMap;
      _statusCountPerMapel = statusMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absen Mata Pelajaran'),
      ),
      body: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();

          // Ambil daftar mapel guru secara aman
          List<String> guruMapelList = [];
          if (auth.guru != null) {
            guruMapelList = List<String>.from(auth.guru!.mapelList);
          }

          // Admin melihat semua, guru hanya melihat mapel yang diajar
          final List<String> filteredMapel;
          if (auth.isAdmin) {
            filteredMapel = List<String>.from(daftarMataPelajaran);
          } else if (guruMapelList.isNotEmpty) {
            filteredMapel = daftarMataPelajaran
                .where((m) => guruMapelList.contains(m))
                .toList();
          } else {
            filteredMapel = List<String>.from(daftarMataPelajaran);
          }

          if (filteredMapel.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      size: 40,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada mata pelajaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hubungi admin untuk mengatur\nmata pelajaran yang ditugaskan',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Tanggal ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientMain,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(_today),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${filteredMapel.length} mata pelajaran',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Daftar Mata Pelajaran ──
                Text(
                  'Pilih Mata Pelajaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk untuk langsung mulai absensi',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Grid Mata Pelajaran ──
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 118,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredMapel.length,
                  itemBuilder: (context, index) {
                    final mapel = filteredMapel[index];
                    final color = _getMapelColor(index);
                    final absenCount = _absensiCountPerMapel[mapel] ?? 0;
                    final statusCounts = _statusCountPerMapel[mapel];
                    return EntranceAnimation(
                      delay: Duration(milliseconds: index * 70),
                      child: _MapelCard(
                        nama: mapel,
                        color: color,
                        absenCount: absenCount,
                        statusCounts: statusCounts,
                        onTap: () => _bukaMapel(mapel),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _bukaMapel(String mataPelajaran) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbsenKelasDetailScreen(
          kelas: '', // Kosong = semua kelas guru
          tanggal: _today,
          mataPelajaran: mataPelajaran,
        ),
      ),
    ).then((_) => _loadAbsensiCount());
  }

  Color _getMapelColor(int index) {
    const palette = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEC4899), // Pink
      Color(0xFFF43F5E), // Rose
      Color(0xFFF97316), // Orange
      Color(0xFF14B8A6), // Teal
      Color(0xFF06B6D4), // Cyan
      Color(0xFF3B82F6), // Blue
      Color(0xFF22C55E), // Green
      Color(0xFFEAB308), // Yellow
    ];
    return palette[index % palette.length];
  }
}

class _MapelCard extends StatelessWidget {
  final String nama;
  final Color color;
  final int absenCount;
  final Map<String, int>? statusCounts;
  final VoidCallback onTap;

  const _MapelCard({
    required this.nama,
    required this.color,
    this.absenCount = 0,
    this.statusCounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sudahAbsen = absenCount > 0;
    final hadir = statusCounts?['hadir'] ?? 0;
    final izin = statusCounts?['izin'] ?? 0;
    final sakit = statusCounts?['sakit'] ?? 0;

    return Tilt3D(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: sudahAbsen ? 0.15 : 0.1),
                color.withValues(alpha: sudahAbsen ? 0.08 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sudahAbsen
                  ? color.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.2),
              width: sudahAbsen ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getMapelIcon(nama),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    if (sudahAbsen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 10,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$absenCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                if (sudahAbsen)
                  Row(
                    children: [
                      if (hadir > 0) ...[
                        _MiniChip(label: 'H', value: hadir, color: AppColors.success),
                        const SizedBox(width: 3),
                      ],
                      if (izin > 0) ...[
                        _MiniChip(label: 'I', value: izin, color: AppColors.accent),
                        const SizedBox(width: 3),
                      ],
                      if (sakit > 0) ...[
                        _MiniChip(label: 'S', value: sakit, color: AppColors.warning),
                      ],
                    ],
                  )
                else
                  Text(
                    'Tap untuk absen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getMapelIcon(String nama) {
    final lower = nama.toLowerCase();
    if (lower.contains('qur') || lower.contains('hadits')) {
      return Icons.auto_stories_rounded;
    }
    if (lower.contains('fiqih') || lower.contains('aqidah')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('arab')) {
      return Icons.translate_rounded;
    }
    if (lower.contains('sejarah') || lower.contains('sosiologi')) {
      return Icons.history_edu_rounded;
    }
    if (lower.contains('matematika')) {
      return Icons.calculate_rounded;
    }
    if (lower.contains('bahasa indonesia')) {
      return Icons.article_rounded;
    }
    if (lower.contains('inggris')) {
      return Icons.language_rounded;
    }
    if (lower.contains('fisika')) {
      return Icons.science_rounded;
    }
    if (lower.contains('biologi')) {
      return Icons.eco_rounded;
    }
    if (lower.contains('kimia')) {
      return Icons.science_outlined;
    }
    if (lower.contains('ekonomi')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('geografi')) {
      return Icons.public_rounded;
    }
    if (lower.contains('ppkn') || lower.contains('pancasila')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('pjok') || lower.contains('olahraga')) {
      return Icons.sports_soccer_rounded;
    }
    if (lower.contains('seni') || lower.contains('budaya')) {
      return Icons.palette_rounded;
    }
    if (lower.contains('prakarya')) {
      return Icons.handyman_rounded;
    }
    if (lower.contains('informatika') || lower.contains('komputer')) {
      return Icons.computer_rounded;
    }
    return Icons.book_rounded;
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
