import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';
import 'absen_kelas_detail_screen.dart';

class AbsenKelasMapelScreen extends StatefulWidget {
  final String mataPelajaran;
  final DateTime tanggal;

  const AbsenKelasMapelScreen({
    super.key,
    required this.mataPelajaran,
    required this.tanggal,
  });

  @override
  State<AbsenKelasMapelScreen> createState() => _AbsenKelasMapelScreenState();
}

class _AbsenKelasMapelScreenState extends State<AbsenKelasMapelScreen> {
  late final FirestoreService _fs = FirestoreService();
  Map<String, int> _absensiCountPerKelas = {};

  @override
  void initState() {
    super.initState();
    _loadAbsensiCount();
  }

  Future<void> _loadAbsensiCount() async {
    final absensiList = await _fs.getAbsensiByDate(widget.tanggal);
    if (!mounted) return;

    final countMap = <String, int>{};
    for (final a in absensiList) {
      if (a.mataPelajaran == widget.mataPelajaran && a.kelas.isNotEmpty) {
        countMap[a.kelas] = (countMap[a.kelas] ?? 0) + 1;
      }
    }
    setState(() => _absensiCountPerKelas = countMap);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mataPelajaran,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              dateFormat.format(widget.tanggal),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Siswa>>(
        stream: _fs.getSiswaStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Gagal memuat data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final semuaSiswa = snapshot.data!;
          final kelasMap = <String, List<Siswa>>{};

          for (final s in semuaSiswa) {
            kelasMap.putIfAbsent(s.kelas, () => []);
            kelasMap[s.kelas]!.add(s);
          }

          // Filter kelas berdasarkan data guru
          final auth = context.watch<AuthProvider>();
          List<String> kelasList;
          if (auth.isGuru && auth.guru != null) {
            final guruKelas = auth.guru!.kelasList;
            if (guruKelas.isNotEmpty) {
              kelasList = kelasMap.keys
                  .where((k) => guruKelas.contains(k))
                  .toList()
                ..sort();
            } else {
              kelasList = kelasMap.keys.toList()..sort();
            }
          } else {
            kelasList = kelasMap.keys.toList()..sort();
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
                      Icons.school_outlined,
                      size: 40,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada kelas terdaftar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan siswa terlebih dahulu\ndi menu Data Siswa',
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
                // ── Header Info ──
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
                              Icons.menu_book_rounded,
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
                                  widget.mataPelajaran,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pilih kelas untuk mulai absensi',
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

                // ── Daftar Kelas ──
                Text(
                  'Kelas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk kelas untuk melihat dan mengisi absensi',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),

                // ── List Kelas dengan Daftar Siswa ──
                ...kelasList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final kelas = entry.value;
                  final siswaList = kelasMap[kelas] ?? [];
                  final absenCount = _absensiCountPerKelas[kelas] ?? 0;
                  final sudahAbsen = absenCount > 0;

                  return EntranceAnimation(
                    delay: Duration(milliseconds: index * 60),
                    child: _KelasCard(
                      kelas: kelas,
                      siswaList: siswaList,
                      absenCount: absenCount,
                      sudahAbsen: sudahAbsen,
                      onTap: () => _bukaKelas(kelas),
                    ),
                  );
                }),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _bukaKelas(String kelas) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbsenKelasDetailScreen(
          kelas: kelas,
          tanggal: widget.tanggal,
          mataPelajaran: widget.mataPelajaran,
        ),
      ),
    ).then((_) => _loadAbsensiCount());
  }
}

class _KelasCard extends StatelessWidget {
  final String kelas;
  final List<Siswa> siswaList;
  final int absenCount;
  final bool sudahAbsen;
  final VoidCallback onTap;

  const _KelasCard({
    required this.kelas,
    required this.siswaList,
    required this.absenCount,
    required this.sudahAbsen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    final namaList = siswaList.map((s) => s.nama).toList();
    final maxTampil = 4; // Jumlah nama yang ditampilkan
    final namaPreview = namaList.take(maxTampil).join(', ');
    final sisaCount = namaList.length - maxTampil;

    return Tilt3D(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: Nama Kelas + Status ──
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.class_rounded,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kelas $kelas',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            '${siswaList.length} siswa',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                              '$absenCount diabsen',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Daftar Nama Siswa ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: color.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Siswa:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...namaList.take(maxTampil).map((nama) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  nama,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.foreground.withValues(alpha: 0.8),
                                  ),
                                ),
                              )),
                          if (sisaCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.muted.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+$sisaCount lainnya',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tombol Absen ──
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: Icon(
                      sudahAbsen ? Icons.edit_note_rounded : Icons.how_to_reg_rounded,
                      size: 16,
                    ),
                    label: Text(
                      sudahAbsen ? 'Edit Absensi' : 'Mulai Absen',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
