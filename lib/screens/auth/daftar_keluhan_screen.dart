import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/keluhan.dart';
import '../../providers/keluhan_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class DaftarKeluhanScreen extends StatefulWidget {
  const DaftarKeluhanScreen({super.key});

  @override
  State<DaftarKeluhanScreen> createState() => _DaftarKeluhanScreenState();
}

class _DaftarKeluhanScreenState extends State<DaftarKeluhanScreen> {
  final _fs = FirestoreService();
  String _filterStatus = 'semua'; // 'semua', 'pending', 'dibaca', 'selesai'

  Future<void> _showDetailKeluhan(Keluhan keluhan) async {
    final catatanController = TextEditingController(
      text: keluhan.catatanGuru ?? '',
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String selectedStatus = keluhan.status;
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
                            color: _getStatusColor(keluhan.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _getStatusIcon(keluhan.status),
                            color: _getStatusColor(keluhan.status),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detail Keluhan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              ),
                              Text(
                                _getStatusLabel(keluhan.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStatusColor(keluhan.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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

                    // Info orang tua
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(keluhan.namaOrtu,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(keluhan.hpOrtu,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.muted)),
                            ],
                          ),
                          if (keluhan.siswaNama != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.school,
                                    size: 14, color: AppColors.muted),
                                const SizedBox(width: 6),
                                Text(
                                  '${keluhan.siswaNama} (${keluhan.kelas ?? "-"})',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Judul
                    Text(
                      keluhan.judul,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(keluhan.tanggal),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),

                    // Deskripsi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        keluhan.deskripsi,
                        style: const TextStyle(
                          height: 1.5,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status dropdown
                    const Text(
                      'Ubah Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStatus,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 16, color: AppColors.warning),
                                  SizedBox(width: 8),
                                  Text('Pending'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'dibaca',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility, size: 16, color: AppColors.accent),
                                  SizedBox(width: 8),
                                  Text('Dibaca'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'selesai',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                                  SizedBox(width: 8),
                                  Text('Selesai'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedStatus = v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Catatan guru
                    const Text(
                      'Catatan Guru',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: catatanController,
                      decoration: const InputDecoration(
                        hintText: 'Tambahkan catatan...',
                        prefixIcon: Icon(Icons.edit_note),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Tombol simpan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                setDialogState(() => isLoading = true);
                                try {
                                  await _fs.updateKeluhan(keluhan.id, {
                                    'status': selectedStatus,
                                    'catatanGuru': catatanController.text.trim(),
                                    if (selectedStatus == 'selesai')
                                      'tanggalDitindak': DateTime.now(),
                                  });

                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Status keluhan diperbarui'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (e) {
                                  if (!dialogContext.mounted) return;
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Gagal: $e')),
                                  );
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
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          isLoading ? 'Menyimpan...' : 'Simpan',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'dibaca':
        return AppColors.accent;
      case 'selesai':
        return AppColors.success;
      default:
        return AppColors.muted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'dibaca':
        return Icons.visibility;
      case 'selesai':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending - Belum ditindak';
      case 'dibaca':
        return 'Dibaca - Sedang ditinjau';
      case 'selesai':
        return 'Selesai - Sudah ditindaklanjuti';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.watch<KeluhanProvider>().pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Keluhan Orang Tua'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChipKeluhan(
                    label: 'Semua',
                    isSelected: _filterStatus == 'semua',
                    onTap: () => setState(() => _filterStatus = 'semua'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipKeluhan(
                    label: 'Pending',
                    isSelected: _filterStatus == 'pending',
                    color: AppColors.warning,
                    onTap: () => setState(() => _filterStatus = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipKeluhan(
                    label: 'Dibaca',
                    isSelected: _filterStatus == 'dibaca',
                    color: AppColors.accent,
                    onTap: () => setState(() => _filterStatus = 'dibaca'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipKeluhan(
                    label: 'Selesai',
                    isSelected: _filterStatus == 'selesai',
                    color: AppColors.success,
                    onTap: () => setState(() => _filterStatus = 'selesai'),
                  ),
                ],
              ),
            ),
          ),

          // Daftar keluhan
          Expanded(
            child: StreamBuilder<List<Keluhan>>(
              stream: _fs.getKeluhanStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var list = snapshot.data!;
                if (_filterStatus != 'semua') {
                  list = list
                      .where((k) => k.status == _filterStatus)
                      .toList();
                }

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 64,
                            color: AppColors.muted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text('Belum ada keluhan',
                            style: TextStyle(color: AppColors.muted)),
                        if (_filterStatus != 'semua')
                          Text(
                            'Tidak ada keluhan dengan status "$_filterStatus"',
                            style: TextStyle(
                                color: AppColors.muted.withValues(alpha: 0.7),
                                fontSize: 12),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final k = list[index];
                    return _buildKeluhanCard(k);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeluhanCard(Keluhan k) {
    return GestureDetector(
      onTap: () => _showDetailKeluhan(k),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: k.status == 'pending'
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(k.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(k.status),
                    color: _getStatusColor(k.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${k.namaOrtu} • ${DateFormat('dd/MM/yyyy').format(k.tanggal)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(k.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(k.status).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    k.status == 'pending'
                        ? 'Pending'
                        : k.status == 'dibaca'
                            ? 'Dibaca'
                            : 'Selesai',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(k.status),
                    ),
                  ),
                ),
              ],
            ),
            if (k.siswaNama != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.school, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${k.siswaNama} (${k.kelas ?? "-"})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Deskripsi
            Text(
              k.deskripsi,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.foreground,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipKeluhan extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChipKeluhan({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : AppColors.border,
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
