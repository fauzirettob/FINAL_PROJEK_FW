import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bg_widget.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _nisController = TextEditingController();
  final _kelasController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _namaOrtuController = TextEditingController();
  final _hpOrtuController = TextEditingController();
  final _pinOrtuController = TextEditingController();

  String? _searchQuery;
  String? _selectedKelas;

  bool get _isFormDirty =>
      _namaController.text.isNotEmpty ||
      _nisController.text.isNotEmpty ||
      _kelasController.text.isNotEmpty ||
      _kategoriController.text.isNotEmpty ||
      _namaOrtuController.text.isNotEmpty ||
      _hpOrtuController.text.isNotEmpty ||
      _pinOrtuController.text.isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _kelasController.dispose();
    _kategoriController.dispose();
    _namaOrtuController.dispose();
    _hpOrtuController.dispose();
    _pinOrtuController.dispose();
    super.dispose();
  }

  Future<void> _showHapusSiswaDialog(Siswa siswa) async {
    final fs = FirestoreService();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        void Function(void Function())? setDialogState;

        Future<void> onConfirm() async {
          setDialogState?.call(() => isLoading = true);
          try {
            await fs.deleteAbsensiBySiswaId(siswa.id);
            await fs.deleteSiswa(siswa.id);

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Siswa ${siswa.nama} berhasil dihapus.'),
                  backgroundColor: AppColors.success,
                ),
              );
          } catch (e) {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text('Gagal menghapus: $e')),
            );
          } finally {
            setDialogState?.call(() => isLoading = false);
          }
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                setDialogState = setStateDialog;
                return Container(
                  width: 360,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
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
                    children: [
                      // Warning icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Hapus Siswa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apakah Anda yakin ingin menghapus\n${siswa.nama} (${siswa.nis})?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data absensi siswa ini juga akan dihapus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
                              height: 46,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        setStateDialog(() => isLoading = true);
                                        await onConfirm();
                                      },
                                // Note: onConfirm also calls setDialogState for loading state
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Hapus',
                                        style: TextStyle(fontWeight: FontWeight.w600),
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
          ),
        );
      },
    );
  }

  Future<void> _showTambahSiswaDialog() async {
    final fs = FirestoreService();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        String? nisDuplicateError;
        void Function(void Function())? setDialogState;

        Future<void> onSubmit() async {
          final auth = dialogContext.read<AuthProvider>();
          final guru = auth.guru;

          if (guru == null) {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Guru belum tersedia.')),
            );
            return;
          }

          if (!(_formKey.currentState?.validate() ?? false)) return;

          // Cek duplikat NIS sebelum menyimpan
          final existing = await fs.getSiswaByNIS(_nisController.text.trim());
          if (existing != null) {
            setDialogState?.call(() {
              nisDuplicateError = 'NIS ${_nisController.text.trim()} sudah terdaftar atas nama ${existing.nama}';
            });
            return;
          }

          setDialogState?.call(() => isLoading = true);
          try {
            final now = DateTime.now();
            final siswaId = DateTime.now().millisecondsSinceEpoch.toString();

            final siswa = Siswa(
              id: siswaId,
              nama: _namaController.text.trim(),
              nis: _nisController.text.trim(),
              kelas: _kelasController.text.trim(),
              kategori: _kategoriController.text.trim(),
              namaOrtu: _namaOrtuController.text.trim(),
              hpOrtu: _hpOrtuController.text.trim(),
              pinOrtu: _pinOrtuController.text.trim(),
              createdAt: now,
            );

            await fs.addSiswa(siswa);

            final jam = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            final absensi = Absensi(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              siswaId: siswa.id,
              siswaNama: siswa.nama,
              kelas: siswa.kelas,
              kategori: siswa.kategori,
              tanggal: now,
              status: 'hadir',
              jam: jam,
              dikirim: false,
              guruId: guru.id,
            );

            await fs.addAbsensi(absensi);

            // Reset form
            _namaController.clear();
            _nisController.clear();
            _kelasController.clear();
            _kategoriController.clear();
            _namaOrtuController.clear();
            _hpOrtuController.clear();
            _pinOrtuController.clear();

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('Data berhasil disimpan.')),
            );
          } catch (e) {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(content: Text('Gagal menyimpan: $e')),
            );
          } finally {
            setDialogState?.call(() => isLoading = false);
          }
        }

        final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            );

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 420,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientMain,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_add, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Tambah Siswa', style: titleStyle),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (_isFormDirty) {
                                  final confirmed = await showDialog<bool>(
                                    context: dialogContext,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text('Konfirmasi'),
                                      content: const Text(
                                        'Form sudah terisi. Yakin ingin menutup? Data yang belum disimpan akan hilang.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Lanjutkan Isi'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Tutup'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }
                                } else {
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StatefulBuilder(
                    builder: (context, setStateDialog) {
                      setDialogState = setStateDialog;
                      return Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SingleChildScrollView(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _namaController,
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
                                    controller: _nisController,
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
                                    controller: _kelasController,
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
                                    controller: _kategoriController,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori',
                                      hintText: 'Contoh: Reguler, Ekstrakurikuler, Pramuka',
                                      prefixIcon: Icon(Icons.category),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Kategori tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _namaOrtuController,
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
                                    controller: _hpOrtuController,
                                    decoration: const InputDecoration(
                                      labelText: 'HP Orang Tua',
                                      prefixIcon: Icon(Icons.phone),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'HP orang tua tidak boleh kosong'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _pinOrtuController,
                                    decoration: const InputDecoration(
                                      labelText: 'PIN Orang Tua (4-6 digit)',
                                      hintText: 'Buat PIN untuk login orang tua',
                                      prefixIcon: Icon(Icons.lock),
                                    ),
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    maxLength: 6,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'PIN tidak boleh kosong';
                                      }
                                      if (v.trim().length < 4) {
                                        return 'PIN minimal 4 digit';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: isLoading ? null : AppColors.gradientMain,
                                  color: isLoading ? AppColors.card : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: isLoading ? AppColors.background : Colors.transparent,
                                    foregroundColor: isLoading ? AppColors.muted : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          setStateDialog(() {});
                                          await onSubmit();
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
                                      : const Icon(Icons.check_circle_rounded),
                                  label: Text(
                                    isLoading ? 'Menyimpan...' : 'Simpan ke Absensi',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
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
        );
      },
    );
  }

  /// Kirim notifikasi rekap absensi hari ini ke orang tua siswa (filter kelas)
  Future<void> _kirimNotifikasiSemua() async {
    final fs = FirestoreService();
    // Ambil data siswa
    final semuaSiswa = await fs.getAllSiswa();
    if (semuaSiswa.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada siswa terdaftar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Filter berdasarkan kelas yang dipilih (jika ada)
    final siswaFilterKelas = _selectedKelas != null
        ? semuaSiswa.where((s) => s.kelas == _selectedKelas).toList()
        : semuaSiswa;

    if (siswaFilterKelas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedKelas != null
              ? 'Tidak ada siswa di kelas $_selectedKelas.'
              : 'Belum ada siswa terdaftar.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Filter siswa yang punya nomor HP
    final siswaDenganHp = siswaFilterKelas
        .where((s) => s.hpOrtu.isNotEmpty)
        .toList();

    if (siswaDenganHp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada siswa dengan nomor HP orang tua.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Tampilkan dialog konfirmasi
    final kelasLabel = _selectedKelas != null ? 'Kelas $_selectedKelas — ' : '';
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.send_to_mobile, color: AppColors.whatsapp),
            SizedBox(width: 8),
            Text('Kirim Notifikasi'),
          ],
        ),
        content: Text(
          '${kelasLabel}Kirim rekap absensi hari ini ke ${siswaDenganHp.length} orang tua siswa via WhatsApp?\n\n'
          'Notifikasi akan dikirim ke nomor yang terdaftar di data siswa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Kirim'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Progress state
    int total = siswaDenganHp.length;
    int terkirim = 0;
    int gagal = 0;

    // Progress state
    void Function(void Function())? updateProgress;

    // Tampilkan progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            updateProgress = setStateDialog;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Mengirim notifikasi...\n$terkirim dari $total terkirim',
                      textAlign: TextAlign.center,
                    ),
                    if (gagal > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '$gagal gagal',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Ambil absensi hari ini (pakai query yang lebih efisien)
    final now = DateTime.now();
    final todayStr = DateFormat('dd/MM/yyyy').format(now);
    final absensiHariIni = await fs.getAbsensiHariIni(now).first;

    // Map siswaId -> status absensi
    final statusMap = <String, String>{};
    for (final a in absensiHariIni) {
      statusMap[a.siswaId] = a.status;
    }

    for (final siswa in siswaDenganHp) {
      final status = statusMap[siswa.id] ?? 'Belum absen';

      final berhasil = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: siswa.hpOrtu,
        namaSiswa: siswa.nama,
        status: status,
        tanggal: todayStr,
      );

      if (berhasil) {
        terkirim++;
      } else {
        gagal++;
      }

      // Update progress dialog
      updateProgress?.call(() {});
    }

    if (!mounted) return;
    // Tutup progress dialog
    Navigator.of(context).pop();

    if (!mounted) return;
    // Tampilkan hasil
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              gagal == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
              color: gagal == 0 ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(gagal == 0 ? 'Terkirim' : 'Selesai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Berhasil: $terkirim'),
            if (gagal > 0) Text('❌ Gagal: $gagal'),
            const SizedBox(height: 8),
            Text(
              'Notifikasi rekap absensi telah dikirim ke nomor WhatsApp orang tua siswa.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile, color: AppColors.whatsapp),
            tooltip: 'Kirim Notifikasi ke Semua',
            onPressed: () => _kirimNotifikasiSemua(),
          ),
        ],
      ),
      body: BgWidget(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari siswa...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Siswa>>(
              stream: fs.getSiswaStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Gagal memuat data siswa: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allData = snapshot.data!;
                final uniqueKelas = allData.map((s) => s.kelas).toSet().toList()..sort();

                if (_selectedKelas != null && !uniqueKelas.contains(_selectedKelas)) {
                  _selectedKelas = null;
                }

                final list = allData
                    .where((s) {
                      if (_selectedKelas != null && s.kelas != _selectedKelas) {
                        return false;
                      }
                      if (_searchQuery != null &&
                          !s.nama.toLowerCase().contains(_searchQuery!) &&
                          !s.nis.toLowerCase().contains(_searchQuery!) &&
                          !s.kelas.toLowerCase().contains(_searchQuery!) &&
                          !s.kategori.toLowerCase().contains(_searchQuery!)) {
                        return false;
                      }
                      return true;
                    })
                    .toList();

                return Column(
                  children: [
                    if (uniqueKelas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedKelas,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              prefixIcon: const Icon(Icons.filter_list, size: 20),
                              hintText: 'Semua Kelas',
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: const Text('Semua Kelas', style: TextStyle(color: AppColors.muted)),
                              ),
                              ...uniqueKelas.map(
                                (k) => DropdownMenuItem<String?>(
                                  value: k,
                                  child: Text(k),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _selectedKelas = v),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                _selectedKelas != null
                                    ? 'Tidak ada siswa di kelas $_selectedKelas.'
                                    : 'Belum ada data siswa.',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final s = list[index];
                                return GestureDetector(
                                  onTap: () async {
                                    final edited = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailScreen(siswa: s),
                                      ),
                                    );
                                    if (edited == true && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Data siswa berhasil diperbarui.'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.gradientMain.colors[0],
                                            child: Text(
                                              s.nama.isNotEmpty ? s.nama[0] : '?',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.nama,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${s.nis} • ${s.kelas}',
                                                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    s.kategori,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.chat_bubble, color: AppColors.whatsapp),
                                            tooltip: 'Chat WhatsApp ke ${s.namaOrtu}',
                                            onPressed: () => WhatsAppService.bukaWhatsApp(s.hpOrtu),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _showHapusSiswaDialog(s),
                                            tooltip: 'Hapus siswa',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahSiswaDialog,
        label: const Text('Tambah Siswa'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
