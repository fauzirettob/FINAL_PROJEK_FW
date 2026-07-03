import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/absensi.dart';
import '../../models/guru.dart';
import '../../models/siswa.dart';

// ─── Helper maps ───────────────────────────────────────────
const _statusColors = {
  'hadir': AppColors.success,
  'izin': AppColors.accent,
  'sakit': AppColors.warning,
  'alpa': Colors.red,
};

const _statusLabels = {
  'hadir': 'Hadir',
  'izin': 'Izin',
  'sakit': 'Sakit',
  'alpa': 'Alpa',
};

class OlahDataScreen extends StatefulWidget {
  final FirestoreService? firestoreService;

  const OlahDataScreen({super.key, this.firestoreService});

  @override
  State<OlahDataScreen> createState() => _OlahDataScreenState();
}

class _OlahDataScreenState extends State<OlahDataScreen>
    with SingleTickerProviderStateMixin {
  late final FirestoreService _fs = widget.firestoreService ?? FirestoreService();
  late final TabController _tabController;

  // Filter absensi
  String? _filterStatus;
  String _searchAbsensi = '';
  String _searchGuru = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Hapus Absensi ──────────────────────────────────────────
  Future<void> _hapusAbsensi(Absensi absensi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Absensi'),
        content: Text(
          'Yakin ingin menghapus absensi ${absensi.siswaNama} '
          '(${DateFormat('dd/MM/yyyy').format(absensi.tanggal)})?',
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
      await _fs.deleteAbsensi(absensi.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Absensi berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  // ─── Hapus Guru ─────────────────────────────────────────────
  Future<void> _hapusGuru(Guru guru) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Guru'),
        content: Text(
          'Yakin ingin menghapus akun guru ${guru.nama}?\n\n'
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guru ${guru.nama} berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  // ─── Hapus Semua Absensi per Tanggal ────────────────────────
  Future<void> _hapusAbsensiBulk(List<Absensi> list) async {
    if (list.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Massal'),
        content: Text('Yakin ingin menghapus ${list.length} data absensi sekaligus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int sukses = 0;
    int gagal = 0;
    for (final a in list) {
      try {
        await _fs.deleteAbsensi(a.id);
        sukses++;
      } catch (e) {
        gagal++;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$sukses berhasil dihapus${gagal > 0 ? ', $gagal gagal' : ''}'),
        backgroundColor: gagal == 0 ? AppColors.success : AppColors.warning,
      ),
    );
  }

  // ─── Ekspor Absensi ke CSV ──────────────────────────────
  Future<void> _exportAbsensi() async {
    await _showLoadingDialog('Menyiapkan data absensi...');
    try {
      final allData = await _fs.getAllAbsensi().first;
      if (allData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop(); // tutup loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data absensi untuk diekspor'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // Header CSV
      final rows = <List<dynamic>>[
        ['No', 'Nama Siswa', 'Kelas', 'Tanggal', 'Jam', 'Status'],
      ];

      // Data rows — urutkan dari terbaru
      final sorted = List<Absensi>.from(allData)
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

      for (int i = 0; i < sorted.length; i++) {
        final a = sorted[i];
        final statusLabel = _statusLabels[a.status] ?? a.status;
        rows.add([
          i + 1,
          a.siswaNama,
          a.kelas,
          DateFormat('dd/MM/yyyy').format(a.tanggal),
          a.jam,
          statusLabel,
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // tutup loading

      await _simpanDanShare(
        rows: rows,
        filename: 'rekap_absensi_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        title: 'Rekap Absensi',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data guru untuk diekspor'),
            backgroundColor: AppColors.warning,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data siswa untuk diekspor'),
            backgroundColor: AppColors.warning,
          ),
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
              if (value == 'export_absensi') {
                _exportAbsensi();
              } else if (value == 'export_siswa') {
                _exportSiswa();
              } else if (value == 'export_guru') {
                _exportGuru();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_absensi',
                child: ListTile(
                  leading: Icon(Icons.checklist_rounded, color: AppColors.primary),
                  title: Text('Ekspor Absensi'),
                  subtitle: Text('CSV', style: TextStyle(fontSize: 11)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(icon: Icon(Icons.checklist_rounded), text: 'Rekap Absensi'),
            Tab(icon: Icon(Icons.person), text: 'Daftar Guru'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Stats Row ──────────────────────────────────────
          _buildStatsRow(),
          const SizedBox(height: 8),
          // ─── Tab Content ─────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAbsensiTab(),
                _buildGuruTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ──────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: StreamBuilder<List<Siswa>>(
        stream: _fs.getSiswaStream(),
        builder: (context, siswaSnap) {
          final totalSiswa = siswaSnap.data?.length ?? 0;
          return StreamBuilder<List<Absensi>>(
            stream: _fs.getAllAbsensi(),
            builder: (context, absensiSnap) {
              final totalAbsensi = absensiSnap.data?.length ?? 0;
              return FutureBuilder<List<Guru>>(
                future: _fs.getAllGuru(),
                builder: (context, guruSnap) {
                  final totalGuru = guruSnap.data?.length ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.checklist_rounded,
                          label: 'Absensi',
                          value: totalAbsensi.toString(),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.people_alt_rounded,
                          label: 'Siswa',
                          value: totalSiswa.toString(),
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniStatCard(
                          icon: Icons.person,
                          label: 'Guru',
                          value: totalGuru.toString(),
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ─── Tab Absensi ────────────────────────────────────────────
  Widget _buildAbsensiTab() {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchAbsensi = v.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama siswa...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String?>(
                  value: _filterStatus,
                  hint: const Icon(Icons.filter_list, size: 20, color: AppColors.muted),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Semua', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'hadir', child: Text('Hadir', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'izin', child: Text('Izin', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'sakit', child: Text('Sakit', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'alpa', child: Text('Alpa', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: StreamBuilder<List<Absensi>>(
            stream: _fs.getAllAbsensi(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allData = snapshot.data!;

              // Apply filters
              var filtered = allData;
              if (_filterStatus != null) {
                filtered = filtered.where((a) => a.status == _filterStatus).toList();
              }
              if (_searchAbsensi.isNotEmpty) {
                filtered = filtered
                    .where((a) => a.siswaNama.toLowerCase().contains(_searchAbsensi))
                    .toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 64, color: AppColors.muted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Tidak ada data absensi', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                );
              }

              // Group by tanggal untuk section header
              final grouped = <String, List<Absensi>>{};
              for (final a in filtered) {
                final key = DateFormat('yyyy-MM-dd').format(a.tanggal);
                grouped.putIfAbsent(key, () => []);
                grouped[key]!.add(a);
              }

              final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: sortedKeys.length,
                itemBuilder: (context, sectionIndex) {
                  final key = sortedKeys[sectionIndex];
                  final items = grouped[key]!;
                  final date = DateTime.parse(key);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      Padding(
                        padding: EdgeInsets.only(top: sectionIndex > 0 ? 16 : 4, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4, height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy', 'id').format(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.foreground,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${items.length} data',
                              style: const TextStyle(color: AppColors.muted, fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            // Bulk delete button
                            if (items.length > 1)
                              GestureDetector(
                                onTap: () => _hapusAbsensiBulk(items),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_sweep, size: 14, color: Colors.red),
                                      SizedBox(width: 2),
                                      Text('Hapus', style: TextStyle(fontSize: 11, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Items
                      ...items.map((a) => _buildAbsensiCard(a)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbsensiCard(Absensi a) {
    final statusColor = _statusColors[a.status] ?? AppColors.muted;
    final statusLabel = _statusLabels[a.status] ?? a.status;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.siswaNama,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.foreground),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${a.kelas}  •  ${dateFormat.format(a.tanggal)}  •  ${a.jam}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            // Delete
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _hapusAbsensi(a),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab Guru ───────────────────────────────────────────────
  Widget _buildGuruTab() {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
        // List
        Expanded(
          child: FutureBuilder<List<Guru>>(
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
          ),
        ),
      ],
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
