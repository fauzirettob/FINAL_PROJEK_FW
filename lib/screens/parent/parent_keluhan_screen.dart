import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/keluhan.dart';
import '../../models/siswa.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'parent_login_screen.dart';

class ParentKeluhanScreen extends StatefulWidget {
  final String hpOrtu;
  final String namaOrtu;
  final List<Siswa> siswaList;

  const ParentKeluhanScreen({
    super.key,
    required this.hpOrtu,
    required this.namaOrtu,
    required this.siswaList,
  });

  @override
  State<ParentKeluhanScreen> createState() => _ParentKeluhanScreenState();
}

class _ParentKeluhanScreenState extends State<ParentKeluhanScreen> {
  final _fs = FirestoreService();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  Siswa? _selectedSiswa;

  @override
  void initState() {
    super.initState();
    if (widget.siswaList.length == 1) {
      _selectedSiswa = widget.siswaList.first;
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _kirimKeluhan() async {
    final judul = _judulController.text.trim();
    final deskripsi = _deskripsiController.text.trim();

    if (judul.isEmpty || deskripsi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan deskripsi harus diisi')),
      );
      return;
    }

    final now = DateTime.now();
    final keluhan = Keluhan(
      id: now.millisecondsSinceEpoch.toString(),
      siswaId: _selectedSiswa?.id,
      siswaNama: _selectedSiswa?.nama,
      kelas: _selectedSiswa?.kelas,
      namaOrtu: widget.namaOrtu,
      hpOrtu: widget.hpOrtu,
      judul: judul,
      deskripsi: deskripsi,
      tanggal: now,
    );

    try {
      await _fs.addKeluhan(keluhan);
      _judulController.clear();
      _deskripsiController.clear();
      setState(() => _selectedSiswa = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keluhan berhasil dikirim'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Keluhan Orang Tua'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ParentLoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header profile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.gradientMain,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      widget.namaOrtu.isNotEmpty
                          ? widget.namaOrtu[0].toUpperCase()
                          : 'O',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.namaOrtu,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.hpOrtu,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.siswaList.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Anak: ${widget.siswaList.map((s) => s.nama).join(", ")}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form keluhan
            const Text(
              'Kirim Keluhan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sampaikan keluhan atau masukan untuk putra/i Anda',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Pilih siswa (jika lebih dari 1)
            if (widget.siswaList.length > 1) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Siswa>(
                    value: _selectedSiswa,
                    isExpanded: true,
                    hint: const Text(
                      '-- Pilih anak (opsional) --',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    items: widget.siswaList
                        .map((s) => DropdownMenuItem<Siswa>(
                              value: s,
                              child: Text(
                                '${s.nama} (${s.kelas})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSiswa = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _judulController,
              decoration: const InputDecoration(
                labelText: 'Judul Keluhan',
                hintText: 'Cth: Sakit, Izin, Masalah Belajar',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deskripsiController,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Jelaskan keluhan secara detail...',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Tombol kirim
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _kirimKeluhan,
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'Kirim Keluhan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Riwayat keluhan
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: AppColors.muted),
                SizedBox(width: 6),
                Text(
                  'Riwayat Keluhan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<Keluhan>>(
              stream: _fs.getKeluhanByHpOrtu(widget.hpOrtu),
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

                if (list.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 40,
                            color: AppColors.muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text('Belum ada keluhan',
                            style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final k = list[index];
                    return _buildRiwayatCard(k);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(Keluhan k) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (k.status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusLabel = 'Pending';
        statusIcon = Icons.schedule;
        break;
      case 'dibaca':
        statusColor = AppColors.accent;
        statusLabel = 'Dibaca';
        statusIcon = Icons.visibility;
        break;
      case 'selesai':
        statusColor = AppColors.success;
        statusLabel = 'Selesai';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = AppColors.muted;
        statusLabel = k.status;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k.judul,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            k.deskripsi,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.foreground,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(k.tanggal),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              if (k.catatanGuru != null && k.catatanGuru!.isNotEmpty) ...[
                const Spacer(),
                const Icon(Icons.chat, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  'Ada respon guru',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.accent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
