import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bg_widget.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/whatsapp_service.dart';
import '../../models/absensi.dart';
import '../../models/siswa.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _nisController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isProcessing = false;
  String _selectedStatus = 'hadir';
  final FirestoreService _fs = FirestoreService();

  // Filter kategori
  String? _selectedKategori;
  List<String> _kategoriList = [];
  List<Siswa> _allSiswa = [];

  @override
  void initState() {
    super.initState();
    _loadSiswaAndKategori();
  }

  Future<void> _loadSiswaAndKategori() async {
    try {
      final siswaList = await _fs.getAllSiswa();
      final kategoris = siswaList.map((s) => s.kategori).toSet().toList()..sort();
      if (mounted) {
        setState(() {
          _allSiswa = siswaList;
          _kategoriList = kategoris;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data siswa: $e');
    }
  }

  List<Siswa> get _filteredSiswa {
    if (_selectedKategori == null) return [];
    return _allSiswa.where((s) => s.kategori == _selectedKategori).toList();
  }

  @override
  void dispose() {
    _nisController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  void _setStatus(String status) {
    setState(() => _selectedStatus = status);
  }

  Future<void> _submitAbsensi() async {
    if (_isProcessing) return;
    final nis = _nisController.text.trim();

    if (nis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan NIS siswa')),
      );
      return;
    }

    if (_capturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambil foto siswa terlebih dahulu')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final siswa = await _fs.getSiswaByNIS(nis);

      if (siswa == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Siswa dengan NIS $nis tidak ditemukan')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      // Ambil data guru yang sedang login
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final guru = auth.guru;

      if (guru == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guru belum ditemukan. Silakan login ulang.')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      final now = DateTime.now();
      final statusLabels = {
        'hadir': 'Hadir',
        'izin': 'Izin',
        'sakit': 'Sakit',
        'alpa': 'Alpa',
      };

      final absensiId = 'abs_${now.millisecondsSinceEpoch}';

      // Upload foto ke Firebase Storage (fallback jika gagal)
      String? fotoUrl;
      bool fotoGagal = false;
      try {
        final storage = StorageService();
        fotoUrl = await storage.uploadFoto(
          file: _capturedImage!,
          absensiId: absensiId,
        );
      } catch (e) {
        fotoGagal = true;
        debugPrint('Gagal upload foto absensi: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Foto gagal diupload, absensi tetap tersimpan'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      final absensi = Absensi(
        id: absensiId,
        siswaId: siswa.id,
        siswaNama: siswa.nama,
        kelas: siswa.kelas,
        kategori: siswa.kategori,
        tanggal: now,
        status: _selectedStatus,
        jam: DateFormat.Hm().format(now),
        guruId: guru.id,
        fotoUrl: fotoUrl,
      );

      await _fs.addAbsensi(absensi);

      // Kirim WA (hanya jika nomor HP orang tua tersedia)
      bool waBerhasil = false;
      bool waSkipped = false;
      if (siswa.hpOrtu.trim().isEmpty) {
        waSkipped = true;
        debugPrint('WA tidak dikirim: hpOrtu siswa ${siswa.nama} kosong');
      } else {
        try {
          waBerhasil = await WhatsAppService.kirimNotifikasi(
            hpOrtu: siswa.hpOrtu,
            namaSiswa: siswa.nama,
            status: statusLabels[_selectedStatus] ?? 'Hadir',
            tanggal: DateFormat('dd/MM/yyyy').format(now),
            jam: absensi.jam,
          );
        } catch (e) {
          debugPrint('Gagal kirim WA: $e');
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                waBerhasil ? Icons.check_circle : Icons.warning_amber_rounded,
                color: waBerhasil ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(waBerhasil ? "Berhasil" : "Absen Tersimpan"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Absensi ${siswa.nama} tercatat."),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabels[_selectedStatus] ?? 'Hadir',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (fotoGagal) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Foto bukti tidak tersimpan. Aktifkan Firebase Storage agar foto tersimpan.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    waBerhasil
                        ? Icons.check_circle
                        : waSkipped
                            ? Icons.info_outline
                            : Icons.error_outline,
                    size: 16,
                    color: waBerhasil
                        ? AppColors.success
                        : waSkipped
                            ? AppColors.muted
                            : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      waBerhasil
                          ? "Notifikasi WA terkirim ke ${siswa.namaOrtu}."
                          : waSkipped
                              ? "Nomor HP orang tua ${siswa.namaOrtu} belum diisi. Isi di menu Data Siswa."
                              : "Notifikasi WA gagal dikirim. Cek token Fonnte di whatsapp_service.dart.",
                      style: TextStyle(
                        fontSize: 13,
                        color: waBerhasil
                            ? AppColors.success
                            : waSkipped
                                ? AppColors.muted
                                : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _capturedImage = null;
                  _nisController.clear();
                  _selectedStatus = 'hadir';
                });
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Absensi Foto")),
      body: BgWidget(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Camera / Photo Section
            GestureDetector(
              onTap: _isProcessing ? null : _takePhoto,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: _capturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _capturedImage!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _isProcessing ? null : _takePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ambil Foto Siswa',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ketuk untuk membuka kamera',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Filter Kategori ──
            if (_kategoriList.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _selectedKategori,
                          hint: const Row(
                            children: [
                              Icon(Icons.category, size: 18, color: AppColors.muted),
                              SizedBox(width: 8),
                              Text('Pilih Kategori',
                                  style: TextStyle(color: AppColors.muted)),
                            ],
                          ),
                          items: [
                            ..._kategoriList.map((k) => DropdownMenuItem(
                                  value: k,
                                  child: Row(
                                    children: [
                                      Icon(Icons.category, size: 18, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text(k),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedKategori = v),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedKategori != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedKategori = null;
                      }),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.close, color: Colors.red, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Daftar Siswa per Kategori ──
            if (_selectedKategori != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.people, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Siswa $_selectedKategori (${_filteredSiswa.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_filteredSiswa.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Tidak ada siswa di kategori ini',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(4),
                          itemCount: _filteredSiswa.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 12, endIndent: 12),
                          itemBuilder: (context, index) {
                            final s = _filteredSiswa[index];
                            final isSelected = _nisController.text.trim() == s.nis;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isProcessing
                                  ? null
                                  : () {
                                      _nisController.text = s.nis;
                                      setState(() {});
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isSelected
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        s.nama.isNotEmpty ? s.nama[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.nama,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.foreground,
                                            ),
                                          ),
                                          Text(
                                            '${s.nis}  •  ${s.kelas}',
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle,
                                          size: 18, color: AppColors.success),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // NIS Input
            TextField(
              controller: _nisController,
              enabled: !_isProcessing,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'NIS Siswa',
                hintText: 'Masukkan NIS',
                prefixIcon: const Icon(Icons.confirmation_number),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Status Buttons
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: "Hadir",
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    isSelected: _selectedStatus == 'hadir',
                    onTap: _isProcessing ? null : () => _setStatus('hadir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "Izin",
                    icon: Icons.event_busy,
                    color: AppColors.accent,
                    isSelected: _selectedStatus == 'izin',
                    onTap: _isProcessing ? null : () => _setStatus('izin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: "Sakit",
                    icon: Icons.sick,
                    color: AppColors.warning,
                    isSelected: _selectedStatus == 'sakit',
                    onTap: _isProcessing ? null : () => _setStatus('sakit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "Alpa",
                    icon: Icons.cancel,
                    color: Colors.red,
                    isSelected: _selectedStatus == 'alpa',
                    onTap: _isProcessing ? null : () => _setStatus('alpa'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _isProcessing ? null : AppColors.gradientMain,
                  color: _isProcessing ? AppColors.card : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _isProcessing ? AppColors.background : Colors.transparent,
                    foregroundColor: _isProcessing ? AppColors.muted : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _submitAbsensi,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isProcessing ? 'Memproses...' : 'Simpan Absensi',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.muted, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.foreground,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
