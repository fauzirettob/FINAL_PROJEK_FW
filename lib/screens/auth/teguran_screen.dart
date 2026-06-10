import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/siswa.dart';
import '../../models/teguran.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

class TeguranScreen extends StatefulWidget {
  const TeguranScreen({super.key});

  @override
  State<TeguranScreen> createState() => _TeguranScreenState();
}

class _TeguranScreenState extends State<TeguranScreen> {
  final _fs = FirestoreService();
  String? _selectedKelas;
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _showBuatTeguranDialog() async {
    final auth = context.read<AuthProvider>();
    final guru = auth.guru;
    if (guru == null) return;

    Siswa? selectedSiswa;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                width: 420,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Form(
                  key: formKey,
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
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Buat Teguran',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Pilih Siswa
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih Siswa',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Siswa>>(
                        stream: _fs.getSiswaStream(),
                        builder: (context, snapshot) {
                          final semuaSiswa = snapshot.data ?? [];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Siswa>(
                                value: selectedSiswa,
                                isExpanded: true,
                                hint: const Text(
                                  '-- Pilih siswa --',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                items: semuaSiswa
                                    .map((s) => DropdownMenuItem<Siswa>(
                                          value: s,
                                          child: Text(
                                            '${s.nama} (${s.kelas})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => selectedSiswa = v),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Judul
                      TextFormField(
                        controller: _judulController,
                        decoration: const InputDecoration(
                          labelText: 'Judul Teguran',
                          hintText: 'Cth: Terlambat, Tidak Mengerjakan Tugas',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Judul tidak boleh kosong'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Deskripsi
                      TextFormField(
                        controller: _deskripsiController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                          hintText: 'Jelaskan alasan teguran secara detail...',
                          prefixIcon: Icon(Icons.description_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Deskripsi tidak boleh kosong'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Tombol Kirim + Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading || selectedSiswa == null
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setDialogState(() => isLoading = true);

                                  final now = DateTime.now();
                                  final teguranId = now
                                      .millisecondsSinceEpoch
                                      .toString();
                                  final tglStr =
                                      DateFormat('dd/MM/yyyy').format(now);

                                  final siswa = selectedSiswa!;
                                  final teguran = Teguran(
                                    id: teguranId,
                                    siswaId: siswa.id,
                                    siswaNama: siswa.nama,
                                    kelas: siswa.kelas,
                                    guruId: guru.id,
                                    guruNama: guru.nama,
                                    judul: _judulController.text.trim(),
                                    deskripsi:
                                        _deskripsiController.text.trim(),
                                    tanggal: now,
                                  );

                                  try {
                                    // Kirim via WhatsApp
                                    bool waTerkirim = false;
                                    if (siswa.hpOrtu.isNotEmpty) {
                                      waTerkirim = await WhatsAppService
                                          .kirimNotifikasiTeguran(
                                        hpOrtu: siswa.hpOrtu,
                                        namaSiswa: siswa.nama,
                                        judul: teguran.judul,
                                        deskripsi: teguran.deskripsi,
                                        tanggal: tglStr,
                                      );
                                    }

                                    // Simpan teguran dengan status WA
                                    await _fs.addTeguran(Teguran(
                                      id: teguran.id,
                                      siswaId: teguran.siswaId,
                                      siswaNama: teguran.siswaNama,
                                      kelas: teguran.kelas,
                                      guruId: teguran.guruId,
                                      guruNama: teguran.guruNama,
                                      judul: teguran.judul,
                                      deskripsi: teguran.deskripsi,
                                      tanggal: teguran.tanggal,
                                      dikirimWa: waTerkirim,
                                    ));

                                    _judulController.clear();
                                    _deskripsiController.clear();

                                    if (!dialogContext.mounted) return;
                                    Navigator.pop(dialogContext);
                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(waTerkirim
                                            ? 'Teguran berhasil dikirim via WA ke ${siswa.namaOrtu}'
                                            : 'Teguran tersimpan (WA gagal dikirim)'),
                                        backgroundColor: waTerkirim
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!dialogContext.mounted) return;
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text('Gagal: $e')),
                                    );
                                  } finally {
                                    setDialogState(() => isLoading = false);
                                  }
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
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            isLoading
                                ? 'Mengirim...'
                                : 'Kirim Teguran via WhatsApp',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showHapusTeguranDialog(Teguran teguran) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Teguran'),
        content: Text(
            'Yakin ingin menghapus teguran "${teguran.judul}" untuk ${teguran.siswaNama}?'),
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

    if (confirmed == true) {
      await _fs.deleteTeguran(teguran.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teguran berhasil dihapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guru = auth.guru;
    final guruId = guru?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teguran Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.warning),
            tooltip: 'Buat Teguran Baru',
            onPressed: _showBuatTeguranDialog,
          ),
        ],
      ),
      body: guruId == null
          ? const Center(child: Text('Silakan login terlebih dahulu'))
          : StreamBuilder<List<Teguran>>(
              stream: _fs.getTeguranByGuruId(guruId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data!;

                // Filter kelas
                var filtered = list;
                if (_selectedKelas != null) {
                  filtered =
                      list.where((t) => t.kelas == _selectedKelas).toList();
                }

                // Kumpulkan kelas unik
                final kelasList =
                    list.map((t) => t.kelas).toSet().toList()..sort();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 64,
                            color: AppColors.muted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('Belum ada teguran',
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(
                          'Tekan + untuk membuat teguran baru',
                          style: TextStyle(
                              color: AppColors.muted.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Filter kelas
                    if (kelasList.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChipTeguran(
                                label: 'Semua',
                                isSelected: _selectedKelas == null,
                                onTap: () =>
                                    setState(() => _selectedKelas = null),
                              ),
                              const SizedBox(width: 8),
                              ...kelasList.map((k) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _FilterChipTeguran(
                                      label: k,
                                      isSelected: _selectedKelas == k,
                                      onTap: () => setState(
                                          () => _selectedKelas = k),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),

                    // Statistik ringkas
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _TeguranStatCard(
                            label: 'Total',
                            value: filtered.length.toString(),
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          _TeguranStatCard(
                            label: 'Terkirim WA',
                            value: filtered
                                .where((t) => t.dikirimWa)
                                .length
                                .toString(),
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          _TeguranStatCard(
                            label: 'Gagal WA',
                            value: filtered
                                .where((t) => !t.dikirimWa)
                                .length
                                .toString(),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Daftar teguran
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                          return _buildTeguranCard(t);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBuatTeguranDialog,
        label: const Text('Buat Teguran'),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTeguranCard(Teguran t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.dikirimWa
              ? AppColors.border
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Row(
            children: [
              // Icon status
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.judul,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.siswaNama,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Status WA
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.dikirimWa
                      ? AppColors.success.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t.dikirimWa
                        ? AppColors.success.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.dikirimWa ? Icons.check_circle : Icons.error_outline,
                      size: 12,
                      color:
                          t.dikirimWa ? AppColors.success : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.dikirimWa ? 'WA' : 'Gagal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: t.dikirimWa
                            ? AppColors.success
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kelas & Tanggal
          Row(
            children: [
              Icon(Icons.class_, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(t.kelas,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM/yyyy').format(t.tanggal),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Deskripsi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              t.deskripsi,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.foreground,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Footer: Guru & Tombol hapus
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                t.guruNama,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: () => _showHapusTeguranDialog(t),
                tooltip: 'Hapus teguran',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipTeguran extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipTeguran({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.warning : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.warning : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TeguranStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TeguranStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
