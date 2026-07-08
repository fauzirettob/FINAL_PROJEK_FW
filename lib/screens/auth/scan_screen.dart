import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
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
  bool _isProcessing = false;
  String _selectedStatus = 'alpa';
  final FirestoreService _fs = FirestoreService();

  // Filter kelas
  String? _selectedKelas;
  List<String> _kelasList = [];
  List<Siswa> _allSiswa = [];

  @override
  void initState() {
    super.initState();
    _loadSiswaAndKelas();
  }

  Future<void> _loadSiswaAndKelas() async {
    try {
      final siswaList = await _fs.getAllSiswa();
      final kelasList = siswaList.map((s) => s.kelas).toSet().toList()..sort();
      if (mounted) {
        setState(() {
          _allSiswa = siswaList;
          _kelasList = kelasList;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data siswa: $e');
    }
  }

  List<Siswa> get _filteredSiswa {
    if (_selectedKelas == null) return [];
    return _allSiswa.where((s) => s.kelas == _selectedKelas).toList();
  }

  @override
  void dispose() {
    _nisController.dispose();
    super.dispose();
  }

  void _setStatus(String status) {
    setState(() => _selectedStatus = status);
  }

  Future<void> _submitAbsensi() async {
    if (_isProcessing) return;
    final nis = _nisController.text.trim();

    if (nis.isEmpty) {
      ToastService.show(context, message: 'Masukkan NIS siswa');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final siswa = await _fs.getSiswaByNIS(nis);

      if (siswa == null) {
        if (!mounted) return;
        ToastService.show(context, message: 'Siswa dengan NIS $nis tidak ditemukan');
        setState(() => _isProcessing = false);
        return;
      }

      // Ambil data user yang sedang login (guru atau admin)
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final guru = auth.guru;
      final admin = auth.admin;

      String userId;
      if (guru != null) {
        userId = guru.id;
      } else if (admin != null) {
        userId = admin.id;
      } else {
        if (!mounted) return;
        ToastService.show(context, message: 'User belum ditemukan. Silakan login ulang.');
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

      final absensi = Absensi(
        id: absensiId,
        siswaId: siswa.id,
        siswaNama: siswa.nama,
        kelas: siswa.kelas,
        tanggal: now,
        status: _selectedStatus,
        jam: DateFormat.Hm().format(now),
        guruId: userId,
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
                  _nisController.clear();
                  _selectedStatus = 'alpa';
                });
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Error: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Absensi Siswa")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.gradientMain,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Absensi Manual',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Masukkan NIS siswa dan pilih status',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Filter Kelas ──
            if (_kelasList.isNotEmpty) ...[
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
                          value: _selectedKelas,
                          hint: const Row(
                            children: [
                              Icon(Icons.class_, size: 18, color: AppColors.muted),
                              SizedBox(width: 8),
                              Text('Pilih Kelas',
                                  style: TextStyle(color: AppColors.muted)),
                            ],
                          ),
                          items: [
                            ..._kelasList.map((k) => DropdownMenuItem(
                                  value: k,
                                  child: Row(
                                    children: [
                                      Icon(Icons.class_, size: 18, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text(k),
                                    ],
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedKelas = v),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedKelas != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedKelas = null;
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

            // ── Daftar Siswa per Kelas ──
            if (_selectedKelas != null) ...[
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
                            'Siswa Kelas $_selectedKelas (${_filteredSiswa.length})',
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
                            'Tidak ada siswa di kelas ini',
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
                    label: "Alpa",
                    icon: Icons.cancel,
                    color: Colors.red,
                    isSelected: _selectedStatus == 'alpa',
                    onTap: _isProcessing ? null : () => _setStatus('alpa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "Hadir",
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    isSelected: _selectedStatus == 'hadir',
                    onTap: _isProcessing ? null : () => _setStatus('hadir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: "Izin",
                    icon: Icons.event_busy,
                    color: AppColors.accent,
                    isSelected: _selectedStatus == 'izin',
                    onTap: _isProcessing ? null : () => _setStatus('izin'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "Sakit",
                    icon: Icons.sick,
                    color: AppColors.warning,
                    isSelected: _selectedStatus == 'sakit',
                    onTap: _isProcessing ? null : () => _setStatus('sakit'),
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
