import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/awesome_dialogs.dart';
import '../../widgets/tilt3d.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _nisController = TextEditingController();
  String? _selectedKelas;
  final _namaOrtuController = TextEditingController();
  final _hpOrtuController = TextEditingController();

  /// Widget untuk menampilkan preview mata pelajaran berdasarkan kelas
  Widget _buildMapelPreview(String kelas) {
    final mapelList = getMapelByKelas(kelas);
    if (mapelList.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Mata Pelajaran untuk $kelas:',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: mapelList.map((m) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                m,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  bool get _isFormDirty =>
      _namaController.text.isNotEmpty ||
      _nisController.text.isNotEmpty ||
      _selectedKelas != null ||
      _namaOrtuController.text.isNotEmpty ||
      _hpOrtuController.text.isNotEmpty;

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
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
            ToastService.show(
              context,
              message: 'Siswa ${siswa.nama} berhasil dihapus.',
            );
          } catch (e) {
            if (!dialogContext.mounted) return;
            ToastService.show(
              dialogContext,
              message: 'Gagal menghapus: $e',
              backgroundColor: Colors.red.shade600,
              icon: Icons.error_outline,
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
    String? kelasValue = siswa.kelas;
    final namaOrtuCtrl = TextEditingController(text: siswa.namaOrtu);
    final hpOrtuCtrl = TextEditingController(text: siswa.hpOrtu);

    // Sertakan kelas lama (mungkin di luar daftar) agar tetap bisa dipilih.
    final kategoriOptions = <String>[
      ...kategoriKelas,
      if (siswa.kelas.isNotEmpty && !kategoriKelas.contains(siswa.kelas))
        siswa.kelas,
    ];

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
              'kelas': kelasValue ?? '',
              'namaOrtu': namaOrtuCtrl.text.trim(),
              'hpOrtu': hpOrtuCtrl.text.trim(),
            });

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            ToastService.show(
              dialogContext,
              message: 'Data siswa berhasil diperbarui.',
            );
          } catch (e) {
            if (!dialogContext.mounted) return;
            ToastService.show(
              dialogContext,
              message: 'Gagal menyimpan: $e',
              backgroundColor: Colors.red.shade600,
              icon: Icons.error_outline,
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
                                  DropdownButtonFormField<String>(
                                    initialValue: kategoriOptions
                                            .contains(kelasValue)
                                        ? kelasValue
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori',
                                      prefixIcon: Icon(Icons.class_),
                                    ),
                                    items: kategoriOptions
                                        .map((k) => DropdownMenuItem(
                                              value: k,
                                              child: Text(k),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setDialogState?.call(() => kelasValue = v),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Kategori harus dipilih'
                                        : null,
                                  ),
                                  // Tampilkan mata pelajaran untuk kelas yang dipilih
                                  if (kelasValue != null) ...[
                                    const SizedBox(height: 8),
                                    _buildMapelPreview(kelasValue!),
                                  ],
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

    final createdSiswa = await showDialog<Siswa>(
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
              kelas: _selectedKelas ?? '',
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
            _selectedKelas = null;
            _namaOrtuController.clear();
            _hpOrtuController.clear();

            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop(siswa);
          } catch (e) {
            if (!dialogContext.mounted) return;
            ToastService.show(
              dialogContext,
              message: 'Gagal menyimpan: $e',
              backgroundColor: Colors.red.shade600,
              icon: Icons.error_outline,
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
                                    builder: (ctx) => AwesomeConfirmDialog(
                                      title: 'Tutup Form?',
                                      message: 'Form sudah terisi. Yakin ingin '
                                          'menutup? Data yang belum disimpan '
                                          'akan hilang.',
                                      icon: Icons.close_rounded,
                                      color: Colors.red,
                                      cancelText: 'Lanjutkan Isi',
                                      confirmText: 'Tutup',
                                      confirmIcon: Icons.close_rounded,
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
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedKelas,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategori Kelas',
                                      prefixIcon: Icon(Icons.class_),
                                    ),
                                    items: kategoriKelas
                                        .map((k) => DropdownMenuItem(
                                              value: k,
                                              child: Text(k),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setDialogState?.call(() => _selectedKelas = v),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Kategori harus dipilih'
                                        : null,
                                  ),
                                  // Tampilkan mata pelajaran untuk kelas yang dipilih
                                  if (_selectedKelas != null) ...[
                                    const SizedBox(height: 8),
                                    _buildMapelPreview(_selectedKelas!),
                                  ],
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

    if (!mounted || createdSiswa == null) return;

    // Popup sukses bergaya popup notifikasi WA setelah data siswa tersimpan.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AwesomeSuccessDialog(
        title: 'Siswa Berhasil Ditambahkan',
        subtitle: '${createdSiswa.nama} (${createdSiswa.nis}) berhasil '
            'ditambahkan ke kelas ${createdSiswa.kelas}.',
        confirmText: 'Selesai',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa'),
        actions: [],
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
                // mainAxisExtent: tinggi sel tetap sehingga konten kartu
                // (ikon + teks) selalu muat — mencegah RenderFlex overflow
                // pada layar kecil (childAspectRatio bergantung lebar layar
                // dan membuat sel terlalu pendek di HP sempit).
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 118,
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
    return Tilt3D(
      child: GestureDetector(
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                kelas,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.foreground),
              ),
              const SizedBox(height: 2),
              Text(
                '$siswaCount siswa',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
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
