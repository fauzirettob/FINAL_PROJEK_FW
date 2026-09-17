import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/jadwal_pelajaran.dart';
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

  /// mapel -> {hadir: n, izin: n, sakit: n, alpa: n}
  Map<String, Map<String, int>> _statusCountPerMapel = {};

  /// kelas -> mapel -> jumlah absen
  Map<String, Map<String, int>> _absensiCountPerKelasMapel = {};

  /// Set of overridden mapel keys (format: 'tingkat_mapel')
  final Set<String> _overriddenMapel = {};

  /// Kelas yang sedang di-expand
  final Set<String> _expandedClasses = {};

  @override
  void initState() {
    super.initState();
    _loadAbsensiCount();
  }

  Future<void> _loadAbsensiCount() async {
    final absensiList = await _fs.getAbsensiByDate(_today);
    if (!mounted) return;

    final statusMap = <String, Map<String, int>>{};
    final kelasMapelMap = <String, Map<String, int>>{};

    for (final a in absensiList) {
      if (a.mataPelajaran.isNotEmpty) {
        statusMap.putIfAbsent(a.mataPelajaran, () => {});
        statusMap[a.mataPelajaran]![a.status] =
            (statusMap[a.mataPelajaran]![a.status] ?? 0) + 1;

        if (a.kelas.isNotEmpty) {
          kelasMapelMap.putIfAbsent(a.kelas, () => {});
          kelasMapelMap[a.kelas]![a.mataPelajaran] =
              (kelasMapelMap[a.kelas]![a.mataPelajaran] ?? 0) + 1;
        }
      }
    }
    setState(() {
      _statusCountPerMapel = statusMap;
      _absensiCountPerKelasMapel = kelasMapelMap;
    });

    // Load overrides untuk semua tingkat
    await _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    final overrides = <String>{};
    // Cek override untuk semua tingkat dan semua mapel
    for (final tingkat in daftarKelasJadwal) {
      final allMapel = getMapelByTingkat(tingkat);
      for (final mapel in allMapel) {
        final isOverridden = await _fs.isAttendanceTimeOverridden(
            tingkat, mapel, _today);
        if (isOverridden) {
          overrides.add('${tingkat}_$mapel');
        }
      }
    }
    if (mounted) {
      setState(() {
        _overriddenMapel
          ..clear()
          ..addAll(overrides);
      });
    }
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

          // Ambil data guru secara aman
          List<String> guruMapelList = [];
          List<String> guruKelasList = [];
          if (auth.guru != null) {
            guruMapelList = List<String>.from(auth.guru!.mapelList);
            guruKelasList = List<String>.from(auth.guru!.kelasList);
          }

          // Admin melihat semua kelas yang ada di daftar
          final bool isAdmin = auth.isAdmin;

          // Tentukan kelas yang akan ditampilkan
          final List<String> kelasList;
          if (isAdmin) {
            // Admin: tampilkan semua tingkat kelas
            kelasList = List<String>.from(daftarKelasJadwal);
          } else if (guruKelasList.isNotEmpty) {
            // Guru: konversi kelas (10, 11, 12) ke tingkat (X, XI, XII)
            final Set<String> tingkatSet = {};
            for (final k in guruKelasList) {
              final tingkat = kelasToTingkat(k);
              if (tingkat != null) tingkatSet.add(tingkat);
            }
            kelasList = tingkatSet.toList()..sort();
          } else {
            kelasList = List<String>.from(daftarKelasJadwal);
          }

          if (kelasList.isEmpty) {
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
                    'Belum ada kelas yang ditugaskan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hubungi admin untuk mengatur\nkelas dan mata pelajaran',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAbsensiCount,
            child: SingleChildScrollView(
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
                                  '${kelasList.length} kelas • Absensi per kelas & mapel',
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

                // ── Daftar Kelas & Mapel ──
                Text(
                  'Pilih Kelas & Mata Pelajaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 87, 160, 255).withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk kelas untuk melihat mapel, lalu ketuk mapel untuk absen',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),

                // ── List Kelas dengan Mapel ──
                ...kelasList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tingkat = entry.value;

                  // Ambil mapel untuk tingkat ini dari jadwal
                  List<String> mapelForTingkat = getMapelByTingkat(tingkat);

                  // Filter berdasarkan mapel yang diajar guru
                  List<String> filteredMapel;
                  if (isAdmin) {
                    filteredMapel = mapelForTingkat;
                  } else if (guruMapelList.isNotEmpty) {
                    filteredMapel = mapelForTingkat
                        .where((m) => guruMapelList.contains(m))
                        .toList();
                  } else {
                    filteredMapel = mapelForTingkat;
                  }

                  if (filteredMapel.isEmpty) return const SizedBox.shrink();

                  final isExpanded = _expandedClasses.contains(tingkat);

                  // Hitung total absensi untuk kelas ini
                  int totalAbsenKelas = 0;
                  final kelasAbsen = _absensiCountPerKelasMapel[tingkat];
                  if (kelasAbsen != null) {
                    for (final count in kelasAbsen.values) {
                      totalAbsenKelas += count;
                    }
                  }

                  return EntranceAnimation(
                    delay: Duration(milliseconds: index * 80),
                    child: _KelasSection(
                      tingkat: tingkat,
                      mapelList: filteredMapel,
                      isExpanded: isExpanded,
                      totalAbsen: totalAbsenKelas,
                      absensiCountPerMapel: kelasAbsen,
                      statusCountPerMapel: _statusCountPerMapel,
                      overriddenMapel: _overriddenMapel,
                      isAdmin: isAdmin,
                      onToggle: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedClasses.remove(tingkat);
                          } else {
                            _expandedClasses.add(tingkat);
                          }
                        });
                      },
                      onMapelTap: (mapel) => _bukaMapel(tingkat, mapel),
                    ),
                  );
                }),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bukaMapel(String tingkat, String mataPelajaran) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbsenKelasDetailScreen(
          kelas: tingkat,
          tanggal: _today,
          mataPelajaran: mataPelajaran,
        ),
      ),
    ).then((_) => _loadAbsensiCount());
  }
}

/// Widget seksi per kelas (X, XI, XII)
class _KelasSection extends StatelessWidget {
  final String tingkat;
  final List<String> mapelList;
  final bool isExpanded;
  final int totalAbsen;
  final Map<String, int>? absensiCountPerMapel;
  final Map<String, Map<String, int>> statusCountPerMapel;
  final Set<String> overriddenMapel;
  final bool isAdmin;
  final VoidCallback onToggle;
  final void Function(String mapel) onMapelTap;

  const _KelasSection({
    required this.tingkat,
    required this.mapelList,
    required this.isExpanded,
    this.totalAbsen = 0,
    this.absensiCountPerMapel,
    required this.statusCountPerMapel,
    required this.overriddenMapel,
    required this.isAdmin,
    required this.onToggle,
    required this.onMapelTap,
  });

  Color get _tingkatColor {
    switch (tingkat) {
      case 'X':
        return const Color(0xFF6366F1); // Indigo
      case 'XI':
        return const Color(0xFF8B5CF6); // Violet
      case 'XII':
        return const Color(0xFFEC4899); // Pink
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tingkatColor;
    final sudahAbsen = totalAbsen > 0;

    return Tilt3D(
      maxTilt: 4,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sudahAbsen
                ? color.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.15),
            width: sudahAbsen ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // ── Header Kelas (tap untuk expand/collapse) ──
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Ikon kelas
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          tingkat,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Info kelas
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelas $tingkat',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${mapelList.length} mata pelajaran',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge jumlah mapel
                    if (sudahAbsen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalAbsen',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(width: 8),

                    // Arrow
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Daftar Mapel (expandable) ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 118,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: mapelList.length,
                  itemBuilder: (context, index) {
                    final mapel = mapelList[index];
                    final absenCount =
                        absensiCountPerMapel?[mapel] ?? 0;
                    final statusCounts = statusCountPerMapel[mapel];
                    final isOverridden =
                        overriddenMapel.contains('${tingkat}_$mapel');
                    return _MapelCard(
                      nama: mapel,
                      tingkat: tingkat,
                      color: _tingkatColor,
                      absenCount: absenCount,
                      statusCounts: statusCounts,
                      isOverridden: isOverridden,
                      isAdmin: isAdmin,
                      onTap: () => onMapelTap(mapel),
                    );
                  },
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapelCard extends StatelessWidget {
  final String nama;
  final String tingkat;
  final Color color;
  final int absenCount;
  final Map<String, int>? statusCounts;
  final bool isOverridden;
  final bool isAdmin;
  final VoidCallback onTap;

  const _MapelCard({
    required this.nama,
    required this.tingkat,
    required this.color,
    this.absenCount = 0,
    this.statusCounts,
    this.isOverridden = false,
    this.isAdmin = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sudahAbsen = absenCount > 0;
    final hadir = statusCounts?['hadir'] ?? 0;
    final izin = statusCounts?['izin'] ?? 0;
    final sakit = statusCounts?['sakit'] ?? 0;

    return PressableScale(
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sudahAbsen
                ? color.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.2),
            width: sudahAbsen ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getMapelIcon(nama),
                      color: color,
                      size: 18,
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
              const SizedBox(height: 6),
              Text(
                nama,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              // Jadwal waktu
              _JadwalTimeChip(nama: nama, tingkat: tingkat, isOverridden: isOverridden),
              const SizedBox(height: 3),
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
                    if (sakit > 0)
                      _MiniChip(label: 'S', value: sakit, color: AppColors.warning),
                  ],
                )
              else
                Text(
                  'Tap untuk absen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
            ],
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

/// Chip yang menampilkan jadwal waktu mata pelajaran
/// dan status validitas waktu absensi.
class _JadwalTimeChip extends StatelessWidget {
  final String nama;
  final String tingkat;
  final bool isOverridden;

  const _JadwalTimeChip({
    required this.nama,
    required this.tingkat,
    this.isOverridden = false,
  });

  @override
  Widget build(BuildContext context) {
    final jadwalList = getJadwalMapelByTingkat(tingkat, nama);
    if (jadwalList.isEmpty) {
      return const SizedBox.shrink();
    }

    // Cek apakah ada jadwal yang masih valid
    bool adaYangValid = false;
    JadwalMapelInfo? jadwalPertama;
    for (final j in jadwalList) {
      if (jadwalPertama == null) jadwalPertama = j;
      if (isWaktuAbsensiValid(j)) {
        adaYangValid = true;
        break;
      }
    }

    final jadwal = jadwalPertama!;
    final isExpired = !adaYangValid && !isOverridden;
    final isRefreshed = isOverridden && !adaYangValid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.08)
            : isRefreshed
                ? Colors.orange.withValues(alpha: 0.08)
                : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.2)
              : isRefreshed
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired
                ? Icons.access_time_filled_rounded
                : isRefreshed
                    ? Icons.refresh_rounded
                    : Icons.access_time_rounded,
            size: 9,
            color: isExpired
                ? Colors.red
                : isRefreshed
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(width: 2),
          Text(
            isRefreshed ? '${jadwal.rentangWaktu} ✦' : jadwal.rentangWaktu,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isExpired
                  ? Colors.red
                  : isRefreshed
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
