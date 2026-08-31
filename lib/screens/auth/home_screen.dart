import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../providers/auth_provider.dart';
import '../../services/toast_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final FirestoreService? firestoreService;

  const HomeScreen({super.key, this.onNavigateToTab, this.firestoreService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FirestoreService _fs =
      widget.firestoreService ?? FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  // Helper: Ambil inisial dari nama
  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    final word = parts.isNotEmpty ? parts[0] : '';
    if (word.length <= 2) return word.toUpperCase();
    return word.substring(0, 2).toUpperCase();
  }

  Future<void> _uploadFotoProfil() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final admin = auth.admin;
    final guru = auth.guru;

    if (!isAdmin && guru == null) return;
    if (isAdmin && admin == null) return;

    final userId = isAdmin ? admin!.id : guru!.id;
    final existingFotoUrl = isAdmin ? admin?.fotoUrl : guru?.fotoUrl;

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Foto Profil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.accent),
                ),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Gunakan kamera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Ambil dari penyimpanan'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (existingFotoUrl != null && existingFotoUrl.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                  ),
                  title: const Text('Hapus Foto'),
                  subtitle: const Text('Kembali ke inisial'),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    if (source == 'delete') {
      await _hapusFotoProfil();
      return;
    }

    try {
      final imageSource =
          source == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? picked = await _picker.pickImage(
        source: imageSource,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (picked == null || !mounted) return;

      ToastService.show(context, message: 'Menyimpan foto...');

      // Simpan foto ke direktori lokal aplikasi
      final appDir = await getApplicationDocumentsDirectory();
      final profilDir = Directory('${appDir.path}/profil');
      if (!await profilDir.exists()) {
        await profilDir.create(recursive: true);
      }

      final ext = picked.path.split('.').last;
      final localPath = '${profilDir.path}/$userId.$ext';
      await File(picked.path).copy(localPath);

      if (isAdmin) {
        await _fs.updateAdmin(userId, {'fotoUrl': localPath});
      } else {
        await _fs.updateGuru(userId, {'fotoUrl': localPath});
      }

      if (!mounted) return;

      // Reload data profil
      if (isAdmin) {
        final updatedAdmin = await _fs.getAdmin(userId);
        if (updatedAdmin != null && mounted) {
          auth.updateAdmin(updatedAdmin);
        }
      } else {
        final updatedGuru = await _fs.getGuru(userId);
        if (updatedGuru != null && mounted) {
          auth.updateGuru(updatedGuru);
        }
      }

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil disimpan!');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal simpan foto: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _hapusFotoProfil() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;

    if (isAdmin) {
      final admin = auth.admin;
      if (admin == null || admin.fotoUrl == null) return;
      await _hapusFotoInternal(admin.id, admin.fotoUrl!, isAdmin: true);
    } else {
      final guru = auth.guru;
      if (guru == null || guru.fotoUrl == null) return;
      await _hapusFotoInternal(guru.id, guru.fotoUrl!, isAdmin: false);
    }
  }

  Future<void> _hapusFotoInternal(String userId, String fotoUrl,
      {required bool isAdmin}) async {
    final auth = context.read<AuthProvider>();

    try {
      // Hapus file lokal
      final localFile = File(fotoUrl);
      if (await localFile.exists()) {
        await localFile.delete();
      }

      if (isAdmin) {
        await _fs.updateAdmin(userId, {'fotoUrl': null});
      } else {
        await _fs.updateGuru(userId, {'fotoUrl': null});
      }

      if (!mounted) return;

      if (isAdmin) {
        final updatedAdmin = await _fs.getAdmin(userId);
        if (updatedAdmin != null && mounted) {
          auth.updateAdmin(updatedAdmin);
        }
      } else {
        final updatedGuru = await _fs.getGuru(userId);
        if (updatedGuru != null && mounted) {
          auth.updateGuru(updatedGuru);
        }
      }

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal hapus foto: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final fotoUrl = isAdmin ? auth.admin?.fotoUrl : auth.guru?.fotoUrl;
    final nama = isAdmin ? auth.admin?.nama : auth.guru?.nama;
    final displayNama = nama ?? (isAdmin ? 'Admin' : 'Guru');
    final sapaan = _getGreeting();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header Gradient (melayang lembut) ──
            EntranceAnimation(
              child: FloatAnimation(
                child: Container(
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
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: _uploadFotoProfil,
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            backgroundImage: fotoUrl != null &&
                                    fotoUrl.isNotEmpty
                                ? (fotoUrl.startsWith('http')
                                    ? NetworkImage(fotoUrl) as ImageProvider
                                    : (File(fotoUrl).existsSync()
                                        ? FileImage(File(fotoUrl))
                                        : null))
                                : null,
                            child: fotoUrl == null || fotoUrl.isEmpty
                                ? Text(
                                    _getInitials(displayNama),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayNama,
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
                        final hadir = absensiHariIni
                            .where((a) => a.status == 'hadir')
                            .length;
                        final persen = total > 0
                            ? ((hadir / total) * 100).toStringAsFixed(0)
                            : '0';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Kehadiran Hari Ini",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12),
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
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 11),
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
              ),
            ),

            const SizedBox(height: 24),

            // ── Statistik Ringkas ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, snapshot) {
                final semuaSiswa = snapshot.data ?? [];
                // Filter siswa berdasarkan kelas guru (admin lihat semua)
                final List<Siswa> filteredSiswa;
                if (isAdmin) {
                  filteredSiswa = semuaSiswa;
                } else {
                  final guruKelas = auth.guru?.kelasList ?? [];
                  filteredSiswa = guruKelas.isNotEmpty
                      ? semuaSiswa.where((s) => guruKelas.contains(s.kelas)).toList()
                      : semuaSiswa;
                }
                final totalSiswa = filteredSiswa.length;

                return EntranceAnimation(
                  delay: const Duration(milliseconds: 120),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_alt_rounded,
                          label: 'Total Siswa',
                          value: totalSiswa.toString(),
                          animateValue: totalSiswa,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<List<Absensi>>(
                          // Total absensi per hari: hanya catatan hari ini,
                          // otomatis kembali 0 setelah 24 jam (hari berganti).
                          stream: _fs.getAbsensiHariIni(DateTime.now()),
                          builder: (context, snap) {
                            final totalAbsensiHariIni = snap.data?.length ?? 0;
                            return _StatCard(
                              icon: Icons.checklist_rounded,
                              label: 'Absensi Hari Ini',
                              value: totalAbsensiHariIni.toString(),
                              animateValue: totalAbsensiHariIni,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Guru Piket Hari Ini ──
            EntranceAnimation(
              delay: const Duration(milliseconds: 200),
              child: _buildGuruPiketSection(),
            ),

            const SizedBox(height: 20),

            // ── Absensi Hari Ini ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, siswaSnap) {
                final semuaSiswaData = siswaSnap.data ?? [];
                // Filter siswa berdasarkan kelas guru (admin lihat semua)
                final List<Siswa> semuaSiswa;
                if (isAdmin) {
                  semuaSiswa = semuaSiswaData;
                } else {
                  final guruKelas = auth.guru?.kelasList ?? [];
                  semuaSiswa = guruKelas.isNotEmpty
                      ? semuaSiswaData.where((s) => guruKelas.contains(s.kelas)).toList()
                      : semuaSiswaData;
                }
                return StreamBuilder<List<Absensi>>(
                  stream: _fs.getAbsensiHariIni(DateTime.now()),
                  builder: (context, absenSnap) {
                    final absensiHariIni = absenSnap.data ?? [];

                    // Map siswaId -> set of statuses untuk lookup cepat.
                    // Satu siswa bisa punya banyak absensi (per mapel),
                    // kita ambil status 'terbaik': hadir > izin > sakit > alpa.
                    final statusPriority = {
                      'hadir': 0,
                      'izin': 1,
                      'sakit': 2,
                      'alpa': 3,
                    };
                    final bestStatusMap = <String, int>{}; // siswaId -> priority
                    for (final a in absensiHariIni) {
                      final priority = statusPriority[a.status] ?? 4;
                      final existing = bestStatusMap[a.siswaId];
                      if (existing == null || priority < existing) {
                        bestStatusMap[a.siswaId] = priority;
                      }
                    }

                    // Kelompokkan siswa berdasarkan status
                    final hadirList = <Siswa>[];
                    final izinList = <Siswa>[];
                    final sakitList = <Siswa>[];
                    final alpaList = <Siswa>[];
                    final belumAbsenList = <Siswa>[];

                    for (final siswa in semuaSiswa) {
                      final priority = bestStatusMap[siswa.id];
                      if (priority == null) {
                        belumAbsenList.add(siswa);
                        continue;
                      }
                      switch (priority) {
                        case 0:
                          hadirList.add(siswa);
                          break;
                        case 1:
                          izinList.add(siswa);
                          break;
                        case 2:
                          sakitList.add(siswa);
                          break;
                        case 3:
                          alpaList.add(siswa);
                          break;
                        default:
                          belumAbsenList.add(siswa);
                      }
                    }

                    return _buildAbsensiHariIni(
                      semuaSiswa: semuaSiswa,
                      hadirList: hadirList,
                      izinList: izinList,
                      sakitList: sakitList,
                      alpaList: alpaList,
                      belumAbsenList: belumAbsenList,
                      totalAbsensi: absensiHariIni.length,
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

  // ─── Load Guru Piket dengan fallback ──────────────────────────
  Future<List<GuruPiket>> _loadGuruPiket() async {
    try {
      final data = await _fs.getGuruPiket();
      if (data.isEmpty) {
        // Fallback ke default jika Firestore kosong
        return guruPiketDefault
            .map((d) => GuruPiket.fromMap(d))
            .toList();
      }
      return data;
    } catch (e) {
      // Fallback ke default jika error
      return guruPiketDefault
          .map((d) => GuruPiket.fromMap(d))
          .toList();
    }
  }

  // ─── Guru Piket Hari Ini ──────────────────────────────────────
  Widget _buildGuruPiketSection() {
    const hariMap = {
      1: 'SENIN', 2: 'SELASA', 3: 'RABU', 4: 'KAMIS', 5: 'JUMAT',
    };
    final hariIni = hariMap[DateTime.now().weekday] ?? 'SENIN';

    return FutureBuilder<List<GuruPiket>>(
      future: _loadGuruPiket(),
      builder: (context, snapshot) {
        final guruPiket = snapshot.data ?? [];
        final piketHariIni = guruPiket
            .where((p) => p.hari.toUpperCase() == hariIni)
            .toList();
        final namaPiket = piketHariIni
            .expand((p) => p.namaGuru)
            .toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded,
                        color: Color(0xFF0EA5E9), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Guru Piket Hari Ini',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          hariIni,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (namaPiket.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Tidak ada guru piket hari ini',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: namaPiket.map((nama) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded,
                              size: 16, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 6),
                          Text(
                            nama,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Absensi Hari Ini ──────────────────────────────────────────
  Widget _buildAbsensiHariIni({
    required List<Siswa> semuaSiswa,
    required List<Siswa> hadirList,
    required List<Siswa> izinList,
    required List<Siswa> sakitList,
    required List<Siswa> alpaList,
    required List<Siswa> belumAbsenList,
    required int totalAbsensi,
  }) {
    if (semuaSiswa.isEmpty) return const SizedBox.shrink();

    final totalSiswa = semuaSiswa.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Absensi Hari Ini',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.foreground,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$totalAbsensi dari $totalSiswa siswa',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Summary Cards ──
        Row(
          children: [
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.check_circle_rounded,
                label: 'Hadir',
                value: hadirList.length,
                color: AppColors.success,
                onTap: () => _showDetailAbsensi(
                  title: 'Hadir',
                  siswaList: hadirList,
                  status: 'hadir',
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.event_busy_rounded,
                label: 'Izin',
                value: izinList.length,
                color: AppColors.accent,
                onTap: () => _showDetailAbsensi(
                  title: 'Izin',
                  siswaList: izinList,
                  status: 'izin',
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.sick_rounded,
                label: 'Sakit',
                value: sakitList.length,
                color: AppColors.warning,
                onTap: () => _showDetailAbsensi(
                  title: 'Sakit',
                  siswaList: sakitList,
                  status: 'sakit',
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.cancel_rounded,
                label: 'Alpa',
                value: alpaList.length,
                color: Colors.red,
                onTap: () => _showDetailAbsensi(
                  title: 'Alpa',
                  siswaList: alpaList,
                  status: 'alpa',
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.help_outline_rounded,
                label: 'Belum Absen',
                value: belumAbsenList.length,
                color: AppColors.muted,
                onTap: () => _showDetailAbsensi(
                  title: 'Belum Absen',
                  siswaList: belumAbsenList,
                  status: 'belum',
                  color: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusSummaryCard(
                icon: Icons.people_alt_rounded,
                label: 'Total',
                value: totalSiswa,
                color: AppColors.primary,
                onTap: () => _showDetailAbsensi(
                  title: 'Semua Siswa',
                  siswaList: semuaSiswa,
                  status: 'all',
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Detail Absensi (Bottom Sheet) ────────────────────────────
  void _showDetailAbsensi({
    required String title,
    required List<Siswa> siswaList,
    required String status,
    required Color color,
  }) {
    // Ambil data absensi hari ini untuk status setiap siswa
    final absensiStream = _fs.getAbsensiHariIni(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StreamBuilder<List<Absensi>>(
        stream: absensiStream,
        builder: (context, snapshot) {
          final absensiHariIni = snapshot.data ?? [];
          final statusMap = <String, String>{};
          for (final a in absensiHariIni) {
            statusMap[a.siswaId] = a.status;
          }

          return Container(
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.school, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              '${siswaList.length} siswa',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status summary bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDetailStatusBar(siswaList, statusMap),
                ),
                const SizedBox(height: 8),
                // Daftar siswa
                Expanded(
                  child: siswaList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 48, color: color.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada siswa',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          itemCount: siswaList.length,
                          itemBuilder: (context, index) {
                            final siswa = siswaList[index];
                            final siswaStatus = statusMap[siswa.id];

                            String statusLabel;
                            Color statusColor;
                            switch (siswaStatus) {
                              case 'hadir':
                                statusLabel = 'Hadir';
                                statusColor = AppColors.success;
                                break;
                              case 'izin':
                                statusLabel = 'Izin';
                                statusColor = AppColors.accent;
                                break;
                              case 'sakit':
                                statusLabel = 'Sakit';
                                statusColor = AppColors.warning;
                                break;
                              case 'alpa':
                                statusLabel = 'Alpa';
                                statusColor = Colors.red;
                                break;
                              default:
                                statusLabel = 'Belum Absen';
                                statusColor = AppColors.muted;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        statusColor.withValues(alpha: 0.12),
                                    child: Text(
                                      siswa.nama.isNotEmpty
                                          ? siswa.nama[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          '${siswa.nis} • Kelas ${siswa.kelas}',
                                          style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          statusColor.withValues(alpha: 0.12),
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
          );
        },
      ),
    );
  }

  // ─── Detail Status Bar ──────────────────────────────────────
  Widget _buildDetailStatusBar(
    List<Siswa> siswaList,
    Map<String, String> statusMap,
  ) {
    final hadir = siswaList.where((s) => statusMap[s.id] == 'hadir').length;
    final izin = siswaList.where((s) => statusMap[s.id] == 'izin').length;
    final sakit = siswaList.where((s) => statusMap[s.id] == 'sakit').length;
    final alpa = siswaList.where((s) => statusMap[s.id] == 'alpa').length;
    final belumAbsen =
        siswaList.where((s) => !statusMap.containsKey(s.id)).length;

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
          _SheetStatusPill(
              label: '?', value: belumAbsen, color: AppColors.muted),
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
              style:
                  TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Summary Card ──────────────────────────────────────
class _StatusSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  const _StatusSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              CountUpNumber(
                value: value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
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
  final int? animateValue;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.animateValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: Container(
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
                  if (animateValue != null)
                    CountUpNumber(
                      value: animateValue!,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    )
                  else
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
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
