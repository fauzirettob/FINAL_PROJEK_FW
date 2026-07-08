import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/toast_service.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/siswa.dart';
import '../../models/absensi.dart';
import 'photo_gallery_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final Siswa siswa;
  const StudentDetailScreen({super.key, required this.siswa});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final FirestoreService _fs = FirestoreService();
  List<Absensi>? _absensiData;

  Siswa get _siswa => widget.siswa;

  Future<void> _showEditSiswaDialog() async {
    final fs = FirestoreService();
    final originalNis = _siswa.nis;

    // Pre-filled controllers
    final namaController = TextEditingController(text: _siswa.nama);
    final nisController = TextEditingController(text: _siswa.nis);
    final kelasController = TextEditingController(text: _siswa.kelas);
    final namaOrtuController = TextEditingController(text: _siswa.namaOrtu);
    final hpOrtuController = TextEditingController(text: _siswa.hpOrtu);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        String? nisDuplicateError;
        void Function(void Function())? setDialogState;

        Future<void> onSave() async {
          if (!(formKey.currentState?.validate() ?? false)) return;

          final nis = nisController.text.trim();

          // Cek duplikat NIS hanya jika NIS berubah
          if (nis != originalNis) {
            final existing = await fs.getSiswaByNIS(nis);
            if (existing != null) {
              setDialogState?.call(() {
                nisDuplicateError = 'NIS $nis sudah terdaftar atas nama ${existing.nama}';
              });
              return;
            }
          }

          setDialogState?.call(() => isLoading = true);
          bool saved = false;
          try {
            await fs.updateSiswa(_siswa.id, {
              'nama': namaController.text.trim(),
              'nis': nis,
              'kelas': kelasController.text.trim(),
              'namaOrtu': namaOrtuController.text.trim(),
              'hpOrtu': hpOrtuController.text.trim(),
            });
            saved = true;

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();

            if (!mounted) return;
            Navigator.of(context).pop(true); // Kembali ke daftar siswa dengan result
          } catch (e) {
            if (!dialogContext.mounted) return;
            ToastService.show(
              dialogContext,
              message: 'Gagal menyimpan: $e',
              backgroundColor: Colors.red.shade600,
              icon: Icons.error_outline,
            );
          } finally {
            // Hanya reset loading jika gagal — jika berhasil, dialog sudah di-pop
            // dan memanggil setState pada StatefulBuilder yang deaktivasi
            // akan memicu '_dependents.isEmpty' assertion.
            if (!saved && dialogContext.mounted) {
              setDialogState?.call(() => isLoading = false);
            }
          }
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientMain,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Siswa',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    StatefulBuilder(
                      builder: (context, setStateDialog) {
                        setDialogState = setStateDialog;
                        return Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Form fields (tanpa SingleChildScrollView — sudah di-wrapper di luar)
                              Column(
                                children: [
                                  TextFormField(
                                    controller: namaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama',
                                      prefixIcon: Icon(Icons.badge),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Nama tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: nisController,
                                    decoration: InputDecoration(
                                      labelText: 'NIS',
                                      prefixIcon: const Icon(Icons.confirmation_number),
                                      errorText: nisDuplicateError,
                                      errorMaxLines: 2,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) {
                                      if (nisDuplicateError != null) {
                                        setDialogState?.call(() => nisDuplicateError = null);
                                      }
                                    },
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'NIS tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: kelasController,
                                    decoration: const InputDecoration(
                                      labelText: 'Kelas',
                                      prefixIcon: Icon(Icons.class_),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Kelas tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: namaOrtuController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama Orang Tua',
                                      prefixIcon: Icon(Icons.family_restroom),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Nama orang tua tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: hpOrtuController,
                                    decoration: const InputDecoration(
                                      labelText: 'HP Orang Tua',
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'HP orang tua tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                              // Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: OutlinedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => Navigator.of(dialogContext).pop(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.muted,
                                          side: const BorderSide(color: AppColors.border),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: const Text(
                                          'Batal',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientMain,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          onPressed: isLoading
                                              ? null
                                              : () async {
                                                  await onSave();
                                                },
                                          icon: isLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.save_rounded),
                                          label: Text(
                                            isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                    ),
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
        );
      },
    );

    namaController.dispose();
    nisController.dispose();
    kelasController.dispose();

    namaOrtuController.dispose();
    hpOrtuController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_siswa.nama),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditSiswaDialog,
            tooltip: 'Edit data siswa',
          ),
          if (_absensiData != null && _absensiData!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              onPressed: _openGallery,
              tooltip: 'Galeri Foto',
            ),
        ],
      ),
      body: StreamBuilder<List<Absensi>>(
          stream: _fs.getAbsensiBySiswaId(_siswa.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      Text('Gagal memuat data', style: TextStyle(color: Colors.red[300])),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            _absensiData = snapshot.data!;
            final absensiList = snapshot.data!;

            if (absensiList.isEmpty) {
              return _buildEmptyState();
            }

            return _buildContent(absensiList);
          },
        ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.muted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada riwayat absensi',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _siswa.nama,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Absensi> data) {
    // Stats
    final total = data.length;
    final hadir = data.where((a) => a.status == 'hadir').length;
    final izin = data.where((a) => a.status == 'izin').length;
    final sakit = data.where((a) => a.status == 'sakit').length;
    final alpa = data.where((a) => a.status == 'alpa').length;
    final persenHadir = total > 0 ? ((hadir / total) * 100).toStringAsFixed(1) : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // --- Student Info Header ---
          _buildStudentHeader(),

          const SizedBox(height: 20),

          // --- Stats Summary ---
          _buildStatsSummary(persenHadir, total, hadir, izin, sakit, alpa),

          const SizedBox(height: 20),

          // --- Mini Chart ---
          if (total > 1) _buildMiniChart(data),

          const SizedBox(height: 20),

          // --- Attendance History ---
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Riwayat Absensi (${data.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          ...data.map((a) => _buildAbsensiCard(a)),
        ],
      ),
    );
  }

  void _openGallery() {
    if (_absensiData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoGalleryScreen(
          absensiList: _absensiData!,
          siswaNama: _siswa.nama,
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientMain,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Avatar with initial
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              _siswa.nama.isNotEmpty ? _siswa.nama[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _siswa.nama,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_siswa.kelas}  •  ${_siswa.nis}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, size: 14, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                '${_siswa.namaOrtu}  •  ${_siswa.hpOrtu}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(
    String persenHadir,
    int total,
    int hadir,
    int izin,
    int sakit,
    int alpa,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Main percentage
          Text(
            '$persenHadir%',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Text(
            'Tingkat Kehadiran',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$total hari tercatat',
            style: TextStyle(color: AppColors.muted.withValues(alpha: 0.7), fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _MiniStat(label: 'Hadir', value: hadir.toString(), color: AppColors.success),
              const SizedBox(width: 8),
              _MiniStat(label: 'Izin', value: izin.toString(), color: AppColors.accent),
              const SizedBox(width: 8),
              _MiniStat(label: 'Sakit', value: sakit.toString(), color: AppColors.warning),
              const SizedBox(width: 8),
              _MiniStat(label: 'Alpa', value: alpa.toString(), color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(List<Absensi> data) {
    // Group by month
    final monthCount = <String, int>{};
    for (final a in data) {
      final key = DateFormat('MMM yy').format(a.tanggal);
      monthCount[key] = (monthCount[key] ?? 0) + 1;
    }

    final entries = monthCount.entries.toList();
    final maxVal = entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    final chartMax = maxVal > 0 ? maxVal.toDouble() : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aktivitas per Bulan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax * 1.3,
                barTouchData: BarTouchData(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= entries.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            entries[idx].key,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxVal > 5 ? (maxVal / 3).ceilToDouble() : 1,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: entries.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: AppColors.primary,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              GestureDetector(
                onTap: a.fotoUrl != null && a.fotoUrl!.isNotEmpty
                    ? () => _showPhotoDialog(a.fotoUrl!, a.siswaNama, a.jam, a.tanggal)
                    : null,
                child: Container(
                  width: 60,
                  height: 60,
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
                                  width: 18,
                                  height: 18,
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
                                  color: AppColors.muted, size: 24);
                            },
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: AppColors.muted, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(a.tanggal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.jam,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(String fotoUrl, String namaSiswa, String jam, DateTime tanggal) {
    final dateFormat = DateFormat('dd/MM/yyyy');
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
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(tanggal)}  •  $jam',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
