import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/toast_service.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/guru.dart';
import '../../models/siswa.dart';

class OlahDataScreen extends StatefulWidget {
  final FirestoreService? firestoreService;

  const OlahDataScreen({super.key, this.firestoreService});

  @override
  State<OlahDataScreen> createState() => _OlahDataScreenState();
}

class _OlahDataScreenState extends State<OlahDataScreen> {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();
  String _searchGuru = '';

  // ─── Hapus Guru ─────────────────────────────────────────────
  Future<void> _hapusGuru(Guru guru) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Guru'),
        content: Text(
          'Yakin ingin menghapus akun guru ${guru.nama}?\\n\\n'
          'Data absensi yang dibuat oleh guru ini tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _fs.deleteGuru(guru.id);
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Guru ${guru.nama} berhasil dihapus',
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal menghapus: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── Ekspor Guru ke CSV ─────────────────────────────────
  Future<void> _exportGuru() async {
    await _showLoadingDialog('Menyiapkan data guru...');
    try {
      final allData = await _fs.getAllGuru();
      if (allData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ToastService.show(
          context,
          message: 'Tidak ada data guru untuk diekspor',
        );
        return;
      }

      final rows = <List<dynamic>>[
        ['No', 'Nama', 'Email', 'Role', 'Tanggal Daftar'],
      ];

      for (int i = 0; i < allData.length; i++) {
        final g = allData[i];
        rows.add([
          i + 1,
          g.nama,
          g.email,
          g.role,
          DateFormat('dd/MM/yyyy').format(g.createdAt),
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await _simpanDanShare(
        rows: rows,
        filename: 'daftar_guru_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        title: 'Daftar Guru',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    }
  }

  // ─── Ekspor Siswa ke CSV ────────────────────────────────
  Future<void> _exportSiswa() async {
    await _showLoadingDialog('Menyiapkan data siswa...');
    try {
      final allData = await _fs.getAllSiswa();
      if (allData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ToastService.show(
          context,
          message: 'Tidak ada data siswa untuk diekspor',
        );
        return;
      }

      final rows = <List<dynamic>>[
        ['No', 'Nama', 'NIS', 'Kelas', 'Nama Orang Tua', 'HP Orang Tua', 'Tanggal Daftar'],
      ];

      for (int i = 0; i < allData.length; i++) {
        final s = allData[i];
        rows.add([
          i + 1,
          s.nama,
          s.nis,
          s.kelas,
          s.namaOrtu,
          s.hpOrtu,
          DateFormat('dd/MM/yyyy').format(s.createdAt),
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      await _simpanDanShare(
        rows: rows,
        filename: 'daftar_siswa_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        title: 'Daftar Siswa',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
      );
    }
  }

  // ─── Loading Dialog ─────────────────────────────────────
  Future<void> _showLoadingDialog(String message) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  // ─── Simpan CSV & Share ─────────────────────────────────
  Future<void> _simpanDanShare({
    required List<List<dynamic>> rows,
    required String filename,
    required String title,
  }) async {
    // Encode ke CSV dengan UTF-8 BOM agar Excel bisa membaca encoding Indonesia
    final csvContent = Csv().encode(rows);
    final bom = utf8.encode('\uFEFF');
    final bytes = [...bom, ...utf8.encode(csvContent)];

    // Simpan ke temporary directory
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsBytes(bytes);

    if (!mounted) return;

    // Share file via native share sheet
    final xFile = XFile(
      file.path,
      mimeType: 'text/csv',
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Olah Data'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Ekspor Data',
            onSelected: (value) {
              if (value == 'export_siswa') {
                _exportSiswa();
              } else if (value == 'export_guru') {
                _exportGuru();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_siswa',
                child: ListTile(
                  leading: Icon(Icons.people_alt_rounded, color: AppColors.accent),
                  title: Text('Ekspor Siswa'),
                  subtitle: Text('CSV', style: TextStyle(fontSize: 11)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_guru',
                child: ListTile(
                  leading: Icon(Icons.person, color: AppColors.warning),
                  title: Text('Ekspor Guru'),
                  subtitle: Text('CSV', style: TextStyle(fontSize: 11)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Stats Row ──────────────────────────────────────
          _buildStatsRow(),
          const SizedBox(height: 12),
          // ─── Search ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchGuru = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Cari guru...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          // ─── Daftar Guru ─────────────────────────────────────
          Expanded(
            child: _buildGuruList(),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ──────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<List<Siswa>>(
              future: _fs.getAllSiswa(),
              builder: (context, siswaSnap) {
                final totalSiswa = siswaSnap.data?.length ?? 0;
                return _MiniStatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Siswa',
                  value: totalSiswa.toString(),
                  color: AppColors.accent,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FutureBuilder<List<Guru>>(
              future: _fs.getAllGuru(),
              builder: (context, guruSnap) {
                final totalGuru = guruSnap.data?.length ?? 0;
                return _MiniStatCard(
                  icon: Icons.person,
                  label: 'Guru',
                  value: totalGuru.toString(),
                  color: AppColors.warning,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Daftar Guru ────────────────────────────────────────────
  Widget _buildGuruList() {
    return FutureBuilder<List<Guru>>(
      future: _fs.getAllGuru(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        var list = snapshot.data ?? [];
        if (_searchGuru.isNotEmpty) {
          list = list
              .where((g) =>
                  g.nama.toLowerCase().contains(_searchGuru) ||
                  g.email.toLowerCase().contains(_searchGuru))
              .toList();
        }

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_rounded, size: 64, color: AppColors.muted.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('Belum ada data guru', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final guru = list[index];
            final createdAt = DateFormat('dd MMM yyyy').format(guru.createdAt);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                      child: Text(
                        guru.nama.isNotEmpty ? guru.nama[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guru.nama,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guru.email,
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          Text(
                            'Terdaftar: $createdAt',
                            style: const TextStyle(color: AppColors.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _hapusGuru(guru),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Hapus guru',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Mini Stat Card ──────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
