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

class RekapAbsensiScreen extends StatefulWidget {
  const RekapAbsensiScreen({super.key});

  @override
  State<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends State<RekapAbsensiScreen> {
  final FirestoreService _fs = FirestoreService();
  String? _selectedKelas;
  List<String> _kelasList = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadKelas();
    // Default to today
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
  }

  Future<void> _loadKelas() async {
    final snapshot = await _fs.getAllSiswa();
    if (!mounted) return;
    final kelasList = snapshot.map((s) => s.kelas).toSet().toList()..sort();
    setState(() => _kelasList = kelasList);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  String get _dateRangeLabel {
    if (_startDate == null || _endDate == null) return '';
    if (_startDate == _endDate) {
      return DateFormat('dd/MM/yyyy').format(_startDate!);
    }
    return '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
  }

  /// Filter absensi by kelas (if selected) and date range
  List<Absensi> _applyFilters(List<Absensi> all) {
    var result = all;

    // Filter by kelas
    if (_selectedKelas != null) {
      result = result.where((a) => a.kelas == _selectedKelas).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      result = result.where((a) =>
          !a.tanggal.isBefore(startOfDay) && !a.tanggal.isAfter(endOfDay)).toList();
    }

    return result;
  }

  int get _hariAktif {
    if (_startDate == null || _endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  /// Cek apakah range saat ini adalah hari ini
  bool get _isRangeHariIni {
    if (_startDate == null || _endDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _startDate == today && _endDate == today;
  }

  /// Cek apakah range saat ini adalah minggu ini (Senin-Minggu)
  bool get _isRangeMingguIni {
    if (_startDate == null || _endDate == null) return false;
    final now = DateTime.now();
    final expectedStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(expectedStart.year, expectedStart.month, expectedStart.day);
    final endOfWeek = DateTime(now.year, now.month, now.day);
    return _startDate == startOfWeek && _endDate == endOfWeek;
  }

  /// Cek apakah range saat ini adalah bulan ini
  bool get _isRangeBulanIni {
    if (_startDate == null || _endDate == null) return false;
    final now = DateTime.now();
    final expectedStart = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month, now.day);
    return _startDate == expectedStart && _endDate == endOfMonth;
  }

  /// Cek apakah range saat ini adalah minggu lalu
  bool get _isRangeMingguLalu {
    if (_startDate == null || _endDate == null) return false;
    final now = DateTime.now();
    final endOfLastWeek = now.subtract(Duration(days: now.weekday));
    final startOfLastWeek = endOfLastWeek.subtract(const Duration(days: 6));
    final expectedStart = DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day);
    final expectedEnd = DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day);
    return _startDate == expectedStart && _endDate == expectedEnd;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Ekspor CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Bar ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                const Text(
                  'Filter Rekap',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // ── Filter Kelas ──
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedKelas,
                            hint: Row(
                              children: [
                                Icon(Icons.class_, size: 16, color: AppColors.muted.withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                const Text('Pilih Kelas', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Semua Kelas', style: TextStyle(fontSize: 13, color: AppColors.foreground)),
                              ),
                              ..._kelasList.map((k) => DropdownMenuItem(
                                    value: k,
                                    child: Text(k, style: const TextStyle(fontSize: 13)),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedKelas = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Tombol Range Tanggal ──
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _dateRangeLabel.isNotEmpty ? _dateRangeLabel : 'Pilih Tanggal',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Quick range chips
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickRangeChip(
                        label: 'Hari Ini',
                        isActive: _isRangeHariIni,
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, now.day);
                            _endDate = _startDate;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _QuickRangeChip(
                        label: 'Minggu Ini',
                        isActive: _isRangeMingguIni,
                        onTap: () {
                          final now = DateTime.now();
                          final start = now.subtract(Duration(days: now.weekday - 1));
                          setState(() {
                            _startDate = DateTime(start.year, start.month, start.day);
                            _endDate = DateTime(now.year, now.month, now.day);
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _QuickRangeChip(
                        label: 'Bulan Ini',
                        isActive: _isRangeBulanIni,
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _startDate = DateTime(now.year, now.month, 1);
                            _endDate = DateTime(now.year, now.month, now.day);
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _QuickRangeChip(
                        label: 'Minggu Lalu',
                        isActive: _isRangeMingguLalu,
                        onTap: () {
                          final now = DateTime.now();
                          final endOfLastWeek = now.subtract(Duration(days: now.weekday));
                          final startOfLastWeek = endOfLastWeek.subtract(const Duration(days: 6));
                          setState(() {
                            _startDate = DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day);
                            _endDate = DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_startDate == null || _endDate == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_rounded, size: 72, color: AppColors.muted.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            const Text(
              'Pilih tanggal untuk melihat rekap',
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Gunakan filter di atas untuk memilih kelas dan range tanggal',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<Absensi>>(
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
        final filtered = _applyFilters(allData);

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return CustomScrollView(
          slivers: [
            // ── Sliver: Ringkasan ──
            SliverToBoxAdapter(
              child: _buildSummary(filtered),
            ),

            // ── Sliver: Tabel ──
            SliverToBoxAdapter(
              child: _buildTable(filtered),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummary(List<Absensi> data) {
    final hadir = data.where((a) => a.status == 'hadir').length;
    final izin = data.where((a) => a.status == 'izin').length;
    final sakit = data.where((a) => a.status == 'sakit').length;
    final alpa = data.where((a) => a.status == 'alpa').length;
    final total = data.length;

    final persenHadir = total > 0 ? ((hadir / total) * 100).toStringAsFixed(1) : '0.0';

    final labelKelas = _selectedKelas ?? 'Semua Kelas';
    final isRange = _startDate != _endDate && _endDate != null && _startDate != null;

    String periodeText;
    if (isRange) {
      periodeText =
          '${DateFormat('dd MMM yyyy', 'id').format(_startDate!)} — ${DateFormat('dd MMM yyyy', 'id').format(_endDate!)}';
    } else if (_startDate != null) {
      periodeText = DateFormat('EEEE, dd MMMM yyyy', 'id').format(_startDate!);
    } else {
      periodeText = '';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradientMain,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelKelas,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          periodeText,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (isRange) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$_hariAktif hari aktif',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '$persenHadir%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Kehadiran',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryBadge(label: 'Hadir', value: hadir, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    _SummaryBadge(label: 'Izin', value: izin, color: AppColors.accent),
                    const SizedBox(width: 8),
                    _SummaryBadge(label: 'Sakit', value: sakit, color: AppColors.warning),
                    const SizedBox(width: 8),
                    _SummaryBadge(label: 'Alpa', value: alpa, color: Colors.red[300]!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Label tabel
          Row(
            children: [
              Text(
                'Daftar Absensi',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.foreground,
                ),
              ),
              const Spacer(),
              Text(
                '$total catatan',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTable(List<Absensi> data) {
    // Sort by tanggal descending, then jam ascending
    final sorted = List<Absensi>.from(data)
      ..sort((a, b) {
        final dateCmp = b.tanggal.compareTo(a.tanggal);
        if (dateCmp != 0) return dateCmp;
        return a.jam.compareTo(b.jam);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.foreground,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.foreground,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('No'), numeric: true),
                DataColumn(label: Text('Nama Siswa')),
                DataColumn(label: Text('Kelas')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Jam')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Foto')),
              ],
              rows: List.generate(sorted.length, (index) {
                final a = sorted[index];
                final statusColor = _statusColors[a.status] ?? AppColors.muted;
                final statusLabel = _statusLabels[a.status] ?? a.status;

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (states) => index.isEven ? null : AppColors.background.withValues(alpha: 0.5),
                  ),
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(a.siswaNama, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(Text(a.kelas)),
                    DataCell(Text(DateFormat('dd/MM').format(a.tanggal))),
                    DataCell(Text(a.jam)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
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
                    ),
                    DataCell(
                      a.fotoUrl != null && a.fotoUrl!.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _showFoto(a.fotoUrl!, a.siswaNama),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.background,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    a.fotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      size: 16,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const Icon(Icons.person_rounded, size: 18, color: AppColors.muted),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final labelKelas = _selectedKelas ?? 'Semua Kelas';
    final isRange = _startDate != _endDate && _endDate != null && _startDate != null;

    String periodeText;
    if (isRange) {
      periodeText =
          '${DateFormat('dd/MM/yyyy').format(_startDate!)} — ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
    } else if (_startDate != null) {
      periodeText = DateFormat('dd/MM/yyyy').format(_startDate!);
    } else {
      periodeText = '';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: AppColors.muted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada data absensi',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada absensi untuk $labelKelas\nperiode $periodeText',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showFoto(String fotoUrl, String namaSiswa) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                fotoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Gagal memuat foto', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              namaSiswa,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Ekspor CSV ──────────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal terlebih dahulu'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final allData = await _fs.getAllAbsensi().first;
      final filtered = _applyFilters(allData);

      if (filtered.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data untuk diekspor'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final rows = <List<dynamic>>[
        ['No', 'Nama Siswa', 'Kelas', 'Tanggal', 'Jam', 'Status'],
      ];

      final sorted = List<Absensi>.from(filtered)
        ..sort((a, b) {
          final dateCmp = b.tanggal.compareTo(a.tanggal);
          if (dateCmp != 0) return dateCmp;
          return a.jam.compareTo(b.jam);
        });

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

      // Encode to CSV with UTF-8 BOM
      final csvContent = Csv().encode(rows);
      final bom = utf8.encode('\uFEFF');
      final bytes = [...bom, ...utf8.encode(csvContent)];

      final dir = await getTemporaryDirectory();
      final labelKelas = _selectedKelas ?? 'SemuaKelas';
      final filename =
          'rekap_${labelKelas}_${DateFormat('yyyyMMdd').format(_startDate!)}-${DateFormat('yyyyMMdd').format(_endDate!)}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      final dateLabel = _startDate == _endDate
          ? DateFormat('dd/MM/yyyy').format(_startDate!)
          : '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          text: 'Rekap Absensi $labelKelas - $dateLabel',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─── Quick Range Chip ──────────────────────────────────────────
class _QuickRangeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickRangeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

// ─── Summary Badge ────────────────────────────────────────────
class _SummaryBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryBadge({
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
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
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
                color: Colors.white.withValues(alpha: 0.8),
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
