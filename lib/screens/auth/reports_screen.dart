import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/toast_service.dart';
import '../../models/absensi.dart';
import 'history_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _fs = FirestoreService();
  final StorageService _storage = StorageService();
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
    setState(() {
      _kelasList = kelasList;
    });
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

  List<Absensi> _applyFilters(List<Absensi> all) {
    var result = all;

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      result = result.where((a) =>
          !a.tanggal.isBefore(startOfDay) && !a.tanggal.isAfter(endOfDay)).toList();
    }

    // Filter by kelas
    if (_selectedKelas != null && _selectedKelas!.isNotEmpty) {
      result = result.where((a) => a.kelas == _selectedKelas).toList();
    }

    return result;
  }

  String get _dateRangeLabel {
    if (_startDate == null || _endDate == null) return '';
    if (_startDate == _endDate) {
      return DateFormat('dd/MM/yyyy').format(_startDate!);
    }
    return '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
  }

  /// Build daily attendance chart data from a list of absensi.
  List<BarChartGroupData> _buildChartData(List<Absensi> list) {
    // Map day-of-week index (Monday=1 .. Sunday=7) to count
    final dayCount = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final a in list) {
      final dow = a.tanggal.weekday; // 1=Monday .. 7=Sunday
      dayCount[dow] = (dayCount[dow] ?? 0) + 1;
    }

    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.primary,
      AppColors.accent,
      AppColors.warning,
    ];

    return dayCount.entries.map((e) {
      // Only show Monday-Saturday (1-6) in chart, skip Sunday
      final idx = e.key;
      final val = e.value.toDouble();
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: val > 0 ? val : 0.1, // small minimum for visual
            color: colors[(idx - 1) % colors.length],
            width: 18,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).where((g) => g.x >= 1 && g.x <= 6).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laporan")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Filter Kelas ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter Kelas',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedKelas,
                  hint: const Text('Semua Kelas',
                      style: TextStyle(color: AppColors.muted)),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Semua Kelas',
                          style: TextStyle(color: AppColors.foreground)),
                    ),
                    ..._kelasList.map((k) => DropdownMenuItem(
                          value: k,
                          child: Row(
                            children: [
                              const Icon(Icons.class_, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(k),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedKelas = v),
                ),
              ),
            ),

                        const SizedBox(height: 16),

            // --- Filter Tanggal ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipWidget(
                    icon: Icons.date_range,
                    label: _dateRangeLabel.isNotEmpty ? _dateRangeLabel : 'Pilih Tanggal',
                    isActive: _startDate != null && _endDate != null && _startDate != _endDate,
                    onTap: _pickDateRange,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- Realtime Data ---
            StreamBuilder<List<Absensi>>(
              stream: _fs.getAllAbsensi(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Gagal memuat data: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final allAbsensi = snapshot.data!;
                final filtered = _applyFilters(allAbsensi);
                final total = filtered.length;

                // Count by status
                final hadir = filtered.where((a) => a.status == 'hadir').length;
                final izin = filtered.where((a) => a.status == 'izin').length;
                final sakit = filtered.where((a) => a.status == 'sakit').length;
                final alpa = filtered.where((a) => a.status == 'alpa').length;

                final persenHadir = total > 0
                    ? ((hadir / total) * 100).toStringAsFixed(1)
                    : '0.0';

                return Column(
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientMain,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _startDate != null && _endDate != null && _startDate != _endDate
                                ? 'Periode ${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                                : 'Kehadiran Hari Ini',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$persenHadir%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedKelas != null)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedKelas!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            "$total siswa tercatat",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if (_endDate != _startDate && _endDate != null && _startDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${((_endDate!.difference(_startDate!).inDays + 1) ~/ 7) + 1} hari aktif',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chart
                    if (total > 0)
                      Container(
                        height: 220,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: BarChart(
                          BarChartData(
                            barGroups: _buildChartData(filtered),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  getTitlesWidget: (val, _) {
                                    const days = [
                                      '', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', ''
                                    ];
                                    final idx = val.toInt();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        idx >= 0 && idx < days.length ? days[idx] : '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(
                              show: true,
                              horizontalInterval: 1,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: AppColors.border.withValues(alpha: 0.5),
                                strokeWidth: 1,
                              ),
                            ),
                            maxY: total > 10
                                ? (total * 0.6).ceilToDouble()
                                : (total > 0 ? total.toDouble() : 5),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: "Hadir",
                            value: hadir.toString(),
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: "Izin",
                            value: izin.toString(),
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: "Sakit",
                            value: sakit.toString(),
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: "Alpa",
                            value: alpa.toString(),
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Detail Absensi dengan Foto ---
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Detail Absensi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Belum ada data absensi',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((a) => _buildAbsensiCard(a)),

                    const SizedBox(height: 20),

                    // Riwayat Button
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
                        icon: const Icon(Icons.history),
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

                    const SizedBox(height: 12),

                    // Download Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _printPdf(filtered, persenHadir),
                        icon: const Icon(Icons.download),
                        label: const Text("Unduh Laporan PDF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsensiCard(Absensi a) {
    final statusColors = {
      'hadir': AppColors.success,
      'izin': AppColors.accent,
      'sakit': AppColors.warning,
      'alpa': Colors.red,
    };
    final statusLabels = {
      'hadir': 'Hadir',
      'izin': 'Izin',
      'sakit': 'Sakit',
      'alpa': 'Alpa',
    };
    final color = statusColors[a.status] ?? AppColors.muted;
    final label = statusLabels[a.status] ?? a.status;

    final cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Photo
          GestureDetector(
            onTap: a.fotoUrl != null
                ? () => _showPhotoDialog(a.fotoUrl!, a.siswaNama)
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.background,
              ),
              child: a.fotoUrl != null && a.fotoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        a.fotoUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image,
                              color: AppColors.muted, size: 28);
                        },
                      ),
                    )
                  : const Icon(Icons.camera_alt, color: AppColors.muted, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.siswaNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.kelas}  •  ${a.jam}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),

              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(a.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _confirmDelete(a);
        },
        onDismissed: (direction) {
          _deleteAbsensi(a);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Hapus',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        child: cardContent,
      ),
    );
  }

  Future<bool> _confirmDelete(Absensi a) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Absensi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apakah Anda yakin ingin menghapus data absensi ini?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.red[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${a.siswaNama}\n${a.status} • ${a.jam}',
                      style: TextStyle(fontSize: 13, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteAbsensi(Absensi a) async {
    try {
      // Hapus foto dari Storage jika ada
      if (a.fotoUrl != null && a.fotoUrl!.isNotEmpty) {
        await _storage.hapusFoto(a.fotoUrl!);
      }
      // Hapus dokumen dari Firestore
      await _fs.deleteAbsensi(a.id);
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          message: 'Gagal menghapus: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _showPhotoDialog(String fotoUrl, String namaSiswa) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
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
            // Photo
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
                          Text(
                            'Gagal memuat foto',
                            style: TextStyle(color: Colors.white54),
                          ),
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

  Future<void> _printPdf(List<Absensi> data, String persenHadir) async {
    final doc = pw.Document();
    final labelStatus = {
      'hadir': 'Hadir',
      'izin': 'Izin',
      'sakit': 'Sakit',
      'alpa': 'Alpa',
    };
    final dateFormat = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Laporan Absensi",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              if (_startDate != null && _endDate != null) ...[
                pw.Text(
                  "Periode: ${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}",
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 4),
              ],
              if (_selectedKelas != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  "Kelas: $_selectedKelas",
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                "Tingkat Kehadiran: $persenHadir%",
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),
              if (data.isEmpty)
                pw.Text("Tidak ada data absensi.")
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Nama',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Kelas',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Status',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Jam',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...data.map((a) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(a.siswaNama),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(a.kelas),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(labelStatus[a.status] ?? a.status),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(a.jam),
                            ),
                          ],
                        )),
                  ],
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterChipWidget({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.primary : AppColors.foreground,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({
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
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
