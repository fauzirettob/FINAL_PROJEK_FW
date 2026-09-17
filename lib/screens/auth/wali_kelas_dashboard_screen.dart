import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';
import '../../models/siswa.dart';
import '../../models/absensi.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../providers/auth_provider.dart';
import 'student_detail_screen.dart';
import 'jadwal_pelajaran_screen.dart';

class WaliKelasDashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const WaliKelasDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<WaliKelasDashboardScreen> createState() =>
      _WaliKelasDashboardScreenState();
}

class _WaliKelasDashboardScreenState extends State<WaliKelasDashboardScreen> {
  late final FirestoreService _fs = FirestoreService();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    final word = parts.isNotEmpty ? parts[0] : '';
    if (word.length <= 2) return word.toUpperCase();
    return word.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guru = auth.guru;
    final waliKelas = guru?.waliKelas ?? '';
    final namaGuru = guru?.nama ?? 'Wali Kelas';
    final sapaan = _getGreeting();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header ──
            EntranceAnimation(
              child: FloatAnimation(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                            "$sapaan ☀️",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            backgroundImage: guru?.fotoUrl != null &&
                                    guru!.fotoUrl!.isNotEmpty
                                ? (guru.fotoUrl!.startsWith('http')
                                    ? NetworkImage(guru.fotoUrl!)
                                        as ImageProvider
                                    : (!kIsWeb && File(guru.fotoUrl!).existsSync()
                                        ? FileImage(File(guru.fotoUrl!))
                                        : null))
                                : null,
                            child: (guru?.fotoUrl == null ||
                                    guru!.fotoUrl!.isEmpty)
                                ? Text(
                                    _getInitials(namaGuru),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  )
                                : null,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Wali Kelas $waliKelas',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Statistik Kelas ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, siswaSnapshot) {
                final semuaSiswa = siswaSnapshot.data ?? [];
                final siswaKelas =
                    semuaSiswa.where((s) => s.kelas == waliKelas).toList();

                return StreamBuilder<List<Absensi>>(
                  stream: _fs.getAbsensiHariIni(DateTime.now()),
                  builder: (context, absenSnapshot) {
                    final absenHariIni = absenSnapshot.data ?? [];
                    final absenKelas = absenHariIni
                        .where((a) => a.kelas == waliKelas)
                        .toList();
                    final hadir =
                        absenKelas.where((a) => a.status == 'hadir').length;
                    final total = siswaKelas.length;
                    final persen = total > 0
                        ? ((hadir / total) * 100).toStringAsFixed(0)
                        : '0';

                    // Hitung alpa dan belum absen
                    final alpa = absenKelas.where((a) => a.status == 'alpa').length;
                    // Siswa yang belum ada absensi sama sekali hari ini
                    final siswaIdsHadir = absenKelas
                        .where((a) => a.status == 'hadir' || a.status == 'izin' || a.status == 'sakit')
                        .map((a) => a.siswaId)
                        .toSet();
                    final belumAbsen = siswaKelas
                        .where((s) => !siswaIdsHadir.contains(s.id))
                        .length;

                    return Column(
                      children: [
                        EntranceAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.people_alt_rounded,
                                  label: 'Total Siswa',
                                  value: total.toString(),
                                  animateValue: total,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.check_circle_rounded,
                                  label: 'Hadir Hari Ini',
                                  value: '$hadir ($persen%)',
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        EntranceAnimation(
                          delay: const Duration(milliseconds: 150),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.cancel_rounded,
                                  label: 'Alpa Hari Ini',
                                  value: alpa.toString(),
                                  animateValue: alpa,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.help_outline_rounded,
                                  label: 'Belum Absen',
                                  value: belumAbsen.toString(),
                                  animateValue: belumAbsen,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Info Jadwal Kelas Hari Ini ──
            EntranceAnimation(
              delay: const Duration(milliseconds: 200),
              child: _buildJadwalHariIni(waliKelas),
            ),

            const SizedBox(height: 20),

            // ── Menu Cepat ──
            EntranceAnimation(
              delay: const Duration(milliseconds: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Menu Wali Kelas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminMenuCard(
                    icon: Icons.people_rounded,
                    color: AppColors.accent,
                    label: "Daftar Siswa Kelas",
                    subtitle: "Lihat semua siswa di kelas $waliKelas",
                    onTap: () => _openDaftarSiswa(waliKelas),
                  ),
                  const SizedBox(height: 8),

                  _AdminMenuCard(
                    icon: Icons.table_chart_rounded,
                    color: const Color(0xFF8B5CF6),
                    label: "Rekap Absensi",
                    subtitle: "Rekap kehadiran siswa kelas",
                    onTap: () => _openRekapAbsensi(waliKelas),
                  ),
                  const SizedBox(height: 8),

                  _AdminMenuCard(
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF0EA5E9),
                    label: "Jadwal Pelajaran",
                    subtitle: "Lihat jadwal kelas $waliKelas",
                    onTap: () => _openJadwalPelajaran(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Daftar Siswa Ringkas ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, snapshot) {
                final semuaSiswa = snapshot.data ?? [];
                final siswaKelas = semuaSiswa
                    .where((s) => s.kelas == waliKelas)
                    .toList()
                  ..sort((a, b) => a.nama.compareTo(b.nama));

                if (siswaKelas.isEmpty) return const SizedBox.shrink();

                return EntranceAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Siswa Kelas $waliKelas',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.foreground,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${siswaKelas.length} siswa',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...siswaKelas.take(10).map((siswa) {
                        return _SiswaListTile(
                          siswa: siswa,
                          onTap: () => _openDetailSiswa(siswa),
                        );
                      }),
                      if (siswaKelas.length > 10) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () => _openDaftarSiswa(waliKelas),
                            child: Text(
                              'Lihat semua ${siswaKelas.length} siswa →',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Jadwal Hari Ini Widget ──
  Widget _buildJadwalHariIni(String kelas) {
    const hariMap = {
      1: 'SENIN',
      2: 'SELASA',
      3: 'RABU',
      4: 'KAMIS',
      5: 'JUMAT',
    };
    final hariIni = hariMap[DateTime.now().weekday] ?? 'SENIN';
    final isJumat = hariIni == 'JUMAT';
    final tingkat = kelasToTingkat(kelas);

    // Ambil jadwal sesuai hari
    final rawSlots = isJumat ? jadwalDefaultJumat : jadwalDefaultSeninKamis;

    // Filter slot yang punya mapel untuk tingkat ini
    final slotsAktif = rawSlots.where((s) {
      if (isJumat) return true; // Jumat: tampilkan semua slot
      return s['mapelPerKelas'] != null &&
          Map<String, dynamic>.from(s['mapelPerKelas'] as Map)
              .containsKey(tingkat ?? '');
    }).toList();

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
                child: const Icon(Icons.schedule_rounded,
                    color: Color(0xFF0EA5E9), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jadwal Hari Ini',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      '$hariIni \u2022 Kelas $kelas',
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
          ...slotsAktif.map((slot) {
            final rawMap = slot['mapelPerKelas'];
            final typedMap = rawMap != null ? Map<String, dynamic>.from(rawMap as Map) : null;
            final mapelList = typedMap?[tingkat ?? ''];
            final namaMapel = mapelList is List
                ? mapelList.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
                : <String>[];
            final keterangan = slot['keterangan']?.toString() ?? '';
            final isNonPel = keterangan.toLowerCase().contains('istirahat') ||
                keterangan.toLowerCase().contains('ishoma') ||
                keterangan.toLowerCase().contains('apel') ||
                keterangan.toLowerCase().contains('break') ||
                keterangan.toLowerCase().contains('lunch');
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: namaMapel.isNotEmpty
                    ? const Color(0xFF0EA5E9).withValues(alpha: 0.04)
                    : isNonPel
                        ? AppColors.muted.withValues(alpha: 0.03)
                        : AppColors.muted.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: namaMapel.isNotEmpty
                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: namaMapel.isNotEmpty
                          ? const Color(0xFF0EA5E9).withValues(alpha: 0.1)
                          : AppColors.muted.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${slot['jamMulai']}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: namaMapel.isNotEmpty
                            ? const Color(0xFF0EA5E9)
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jam ke-${slot['jamKe']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (namaMapel.isNotEmpty)
                          Text(
                            namaMapel.join(' \u2022 '),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            keterangan,
                            style: TextStyle(
                              fontSize: 11,
                              color: isNonPel
                                  ? AppColors.muted.withValues(alpha: 0.6)
                                  : AppColors.muted.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openDaftarSiswa(String kelas) {
    // Navigate to students tab (index 1 in wali kelas shell)
    widget.onNavigateToTab?.call(1);
  }

  void _openRekapAbsensi(String kelas) {
    widget.onNavigateToTab?.call(2);
  }

  void _openJadwalPelajaran() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JadwalPelajaranScreen(),
      ),
    );
  }

  void _openDetailSiswa(Siswa siswa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(siswa: siswa),
      ),
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

// ── Menu Card ──
class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Siswa List Tile ──
class _SiswaListTile extends StatelessWidget {
  final Siswa siswa;
  final VoidCallback onTap;

  const _SiswaListTile({
    required this.siswa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: PressableScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                child: Text(
                  siswa.nama.isNotEmpty ? siswa.nama[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siswa.nama,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: ${siswa.nis}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
