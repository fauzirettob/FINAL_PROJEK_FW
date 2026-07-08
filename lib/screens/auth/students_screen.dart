import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/app_theme.dart';

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
  final _namaOrtuController = TextEditingController();
  final _hpOrtuController = TextEditingController();

  bool get _isFormDirty =>
      _namaController.text.isNotEmpty ||
      _nisController.text.isNotEmpty ||
      _kelasController.text.isNotEmpty ||
      _namaOrtuController.text.isNotEmpty ||
      _hpOrtuController.text.isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _kelasController.dispose();
    _namaOrtuController.dispose();
    _hpOrtuController.dispose();
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
            child: Container(
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
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  setDialogState = setStateDialog;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Hapus Siswa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apakah Anda yakin ingin menghapus\n${siswa.nama} (${siswa.nis})?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data absensi siswa ini juga akan dihapus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.muted,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : onConfirm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: isLoading
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditSiswaDialog(Siswa siswa) async {
    final fs = FirestoreService();

    // Gunakan controller lokal agar tidak mengganggu form tambah
    final namaCtrl = TextEditingController(text: siswa.nama);
    final nisCtrl = TextEditingController(text: siswa.nis);
    final kelasCtrl = TextEditingController(text: siswa.kelas);
    final namaOrtuCtrl = TextEditingController(text: siswa.namaOrtu);
    final hpOrtuCtrl = TextEditingController(text: siswa.hpOrtu);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        String? nisDuplicateError;
        void Function(void Function())? setDialogState;

        Future<void> onSubmit() async {
          if (!(_formKey.currentState?.validate() ?? false)) return;

          // Cek duplikat NIS jika NIS berubah
          final nisBaru = nisCtrl.text.trim();
          if (nisBaru != siswa.nis) {
            final existing = await fs.getSiswaByNIS(nisBaru);
            if (existing != null) {
              setDialogState?.call(() {
                nisDuplicateError = 'NIS $nisBaru sudah terdaftar atas nama ${existing.nama}';
              });
              return;
            }
          }

          setDialogState?.call(() => isLoading = true);
          try {
            await fs.updateSiswa(siswa.id, {
              'nama': namaCtrl.text.trim(),
              'nis': nisBaru,
              'kelas': kelasCtrl.text.trim(),
              'namaOrtu': namaOrtuCtrl.text.trim(),
              'hpOrtu': hpOrtuCtrl.text.trim(),
            });

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(
                content: Text('Data siswa berhasil diperbarui.'),
                backgroundColor: AppColors.success,
              ),
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
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.edit_rounded, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Edit Siswa', style: titleStyle),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
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
                                    controller: namaCtrl,
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
                                    controller: nisCtrl,
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
                                    controller: kelasCtrl,
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
                                    controller: namaOrtuCtrl,
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
                                    controller: hpOrtuCtrl,
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
                                  onPressed: isLoading ? null : () async {
                                    setStateDialog(() {});
                                    await onSubmit();
                                  },
                                  icon: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.save_rounded),
                                  label: Text(
                                    isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
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
          final admin = auth.admin;

          // Dapatkan ID user yang bertindak (guru atau admin)
          String userId;
          if (guru != null) {
            userId = guru.id;
          } else if (admin != null) {
            userId = admin.id;
          } else {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('User belum tersedia.')),
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
              namaOrtu: _namaOrtuController.text.trim(),
              hpOrtu: _hpOrtuController.text.trim(),
              createdAt: now,
            );

            await fs.addSiswa(siswa);

            final jam = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            final absensi = Absensi(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              siswaId: siswa.id,
              siswaNama: siswa.nama,
              kelas: siswa.kelas,
              tanggal: now,
              status: 'hadir',
              jam: jam,
              dikirim: false,
              guruId: userId,
            );

            await fs.addAbsensi(absensi);

            // Reset form
            _namaController.clear();
            _nisController.clear();
            _kelasController.clear();
            _namaOrtuController.clear();
            _hpOrtuController.clear();

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

  /// Kirim notifikasi rekap absensi hari ini ke orang tua siswa
  Future<void> _kirimNotifikasiSemua() async {
    final fs = FirestoreService();
    // Ambil data siswa
    final semuaSiswa = await fs.getAllSiswa();
    if (semuaSiswa.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada siswa terdaftar.'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    // Filter siswa yang punya nomor HP (trim spasi)
    final siswaDenganHp = semuaSiswa
        .where((s) => s.hpOrtu.trim().isNotEmpty)
        .toList();

    if (siswaDenganHp.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada siswa dengan nomor HP orang tua.'),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    // Tampilkan dialog konfirmasi
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
          'Kirim rekap absensi hari ini ke ${siswaDenganHp.length} orang tua siswa via WhatsApp?\n\n'
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
      body: _buildKelasView(fs),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahSiswaDialog,
        label: const Text('Tambah Siswa'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ─── Tampilan Per Kelas (kartu kelas + tabel siswa) ───────────
  Widget _buildKelasView(FirestoreService fs) {
    return StreamBuilder<List<Siswa>>(
      stream: fs.getSiswaStream(),
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

        final kelasList = kelasMap.keys.toList()..sort();

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
                  child: const Icon(Icons.school_outlined, size: 40, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum ada kelas terdaftar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tambahkan siswa terlebih dahulu',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Kelas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ketuk kelas untuk lihat data orang tua',
                style: TextStyle(fontSize: 13, color: AppColors.muted.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: kelasList.length,
                itemBuilder: (context, index) {
                  final kelas = kelasList[index];
                  final siswaCount = kelasMap[kelas]!.length;
                  return _buildKelasCard(kelas, siswaCount);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKelasCard(String kelas, int siswaCount) {
    return GestureDetector(
      onTap: () => _showSiswaPerKelas(kelas),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                kelas,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground),
              ),
              const SizedBox(height: 2),
              Text(
                '$siswaCount siswa',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Sheet: Daftar Siswa per Kelas ────────────────────
  void _showSiswaPerKelas(String kelas) {
    final fs = FirestoreService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: StreamBuilder<List<Siswa>>(
          stream: fs.getSiswaStream(),
          builder: (context, snapshot) {
            final siswaList = (snapshot.data ?? [])
                .where((s) => s.kelas == kelas)
                .toList();

            return Column(
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.class_, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelas $kelas',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              '${siswaList.length} siswa',
                              style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
                          child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 32, child: Text('No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary))),
                      const Expanded(
                        child: Text('NIS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text('Nama Siswa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                      ),
                      const Expanded(
                        child: Text('Nama Ortu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text('Aksi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Student list
                Expanded(
                  child: siswaList.isEmpty
                      ? const Center(
                          child: Text('Tidak ada siswa di kelas ini', style: TextStyle(color: AppColors.muted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: siswaList.length,
                          itemBuilder: (context, index) {
                            final s = siswaList[index];
                            final isGenap = index % 2 == 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isGenap ? AppColors.card : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${index + 1}.',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      s.nis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.foreground),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      s.nama,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.foreground),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      s.namaOrtu,
                                      style: const TextStyle(fontSize: 13, color: AppColors.foreground),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showEditSiswaDialog(s),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.accent),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => _showHapusSiswaDialog(s),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }
}
