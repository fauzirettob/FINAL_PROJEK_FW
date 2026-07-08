import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../services/whatsapp_service.dart';
import '../../models/siswa.dart';
import '../../models/absensi.dart';
import '../../providers/auth_provider.dart';

class AbsenKelasDetailScreen extends StatefulWidget {
  final String kelas;
  final DateTime tanggal;

  const AbsenKelasDetailScreen({
    super.key,
    required this.kelas,
    required this.tanggal,
  });

  @override
  State<AbsenKelasDetailScreen> createState() => _AbsenKelasDetailScreenState();
}

class _AbsenKelasDetailScreenState extends State<AbsenKelasDetailScreen> {
  late final FirestoreService _fs = FirestoreService();

  List<Siswa> _siswaList = [];
  List<Absensi> _existingAbsensi = [];
  Map<String, String> _statusMap = {}; // siswaId -> 'hadir', 'izin', 'sakit', 'alpa'

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingNotif = false;
  bool _isLocked = false;
  bool _notifikasiSent = false;

  // ── Status Configurations ──
  static const _statusList = [
    {'key': 'alpa', 'shortLabel': 'A', 'fullLabel': 'Alpa'},
    {'key': 'hadir', 'shortLabel': 'H', 'fullLabel': 'Hadir'},
    {'key': 'izin', 'shortLabel': 'I', 'fullLabel': 'Izin'},
    {'key': 'sakit', 'shortLabel': 'S', 'fullLabel': 'Sakit'},
  ];

  Color _statusColor(String key) {
    switch (key) {
      case 'hadir':
        return AppColors.success;
      case 'izin':
        return AppColors.accent;
      case 'sakit':
        return AppColors.warning;
      case 'alpa':
        return Colors.red;
      default:
        return AppColors.muted;
    }
  }

  IconData _statusIcon(String key) {
    switch (key) {
      case 'hadir':
        return Icons.check_circle_rounded;
      case 'izin':
        return Icons.event_busy_rounded;
      case 'sakit':
        return Icons.sick_rounded;
      case 'alpa':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(String key) {
    for (final s in _statusList) {
      if (s['key'] == key) return s['fullLabel'] as String;
    }
    return key;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final semuaSiswa = await _fs.getAllSiswa();
      final siswaKelas = semuaSiswa.where((s) => s.kelas == widget.kelas).toList();

      final existingAbsensi = await _fs.getAbsensiByKelasAndDate(
        widget.kelas,
        widget.tanggal,
      );

      final isLocked = await _fs.isKelasLocked(widget.kelas, widget.tanggal);
      final notifSent = await _fs.isNotifikasiKelasSent(widget.kelas, widget.tanggal);

      // Build status map from existing absensi
      final statusMap = <String, String>{};
      for (final absen in existingAbsensi) {
        statusMap[absen.siswaId] = absen.status;
      }

      // Set default status for students without absensi (default: alpa)
      for (final siswa in siswaKelas) {
        statusMap.putIfAbsent(siswa.id, () => 'alpa');
      }

      if (mounted) {
        setState(() {
          _siswaList = siswaKelas;
          _existingAbsensi = existingAbsensi;
          _statusMap = statusMap;
          _isLocked = isLocked;
          _notifikasiSent = notifSent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.show(
          context,
          message: 'Gagal memuat data: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _setStatus(String siswaId, String status) {
    if (_isLocked) return;
    setState(() {
      _statusMap[siswaId] = status;
    });
  }

  Future<void> _simpanAbsensi() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final guruId = auth.guru?.id ?? auth.admin?.id ?? 'unknown';
      final jam = DateFormat.Hm().format(DateTime.now());
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.tanggal);

      // Ambil absensi yang sudah ada untuk update
      final existingMap = <String, Absensi>{};
      for (final absen in _existingAbsensi) {
        existingMap[absen.siswaId] = absen;
      }

      // Kumpulkan semua operasi dalam satu batch
      final batch = <(String, Map<String, dynamic>)>[];
      final batchNew = <Absensi>[];

      for (final siswa in _siswaList) {
        final status = _statusMap[siswa.id] ?? 'alpa';
        final existing = existingMap[siswa.id];

        if (existing != null) {
          if (existing.status != status) {
            // Update existing record
            batch.add((existing.id, {'status': status}));
          }
        } else {
          // Create new record
          final absensiId = 'abs_${siswa.id}_$dateStr';
          final absensi = Absensi(
            id: absensiId,
            siswaId: siswa.id,
            siswaNama: siswa.nama,
            kelas: siswa.kelas,
            tanggal: widget.tanggal,
            status: status,
            jam: jam,
            guruId: guruId,
          );
          batchNew.add(absensi);
        }
      }

      // Eksekusi batch baru dulu
      if (batchNew.isNotEmpty) {
        await _fs.batchSaveAbsensi(batchNew);
      }

      // Eksekusi update secara individual
      for (final (id, data) in batch) {
        await _fs.updateAbsensi(id, data);
      }

      // Reload data to refresh existing absensi list
      final updatedAbsensi = await _fs.getAbsensiByKelasAndDate(
        widget.kelas,
        widget.tanggal,
      );

      if (mounted) {
        setState(() {
          _existingAbsensi = updatedAbsensi;
          _isSaving = false;
        });
        ToastService.show(
          context,
          message: '✅ Absensi kelas ${widget.kelas} berhasil disimpan',
        );
      }
    } catch (e) {
      debugPrint('Gagal menyimpan: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ToastService.show(
          context,
          message: 'Gagal menyimpan: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _kunciAbsensi() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Kunci Absensi'),
          ],
        ),
        content: Text(
          'Setelah dikunci, absensi kelas ${widget.kelas} untuk hari ini '
          'tidak dapat diubah lagi.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.lock, size: 18),
            label: const Text('Kunci'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
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

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.guru?.id ?? auth.admin?.id ?? 'unknown';

      await _fs.lockKelas(widget.kelas, widget.tanggal, userId);

      if (mounted) {
        setState(() => _isLocked = true);
        ToastService.show(
          context,
          message: '🔒 Absensi kelas ${widget.kelas} telah dikunci',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(
          context,
          message: 'Gagal mengunci: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _kirimNotifikasi() async {
    if (_isSendingNotif || _notifikasiSent) return;

    final siswaDenganHp = _siswaList
        .where((s) => s.hpOrtu.trim().isNotEmpty)
        .toList();

    if (siswaDenganHp.isEmpty) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Tidak ada siswa dengan nomor HP orang tua',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.send_to_mobile, color: AppColors.whatsapp),
            const SizedBox(width: 8),
            const Text('Kirim Notifikasi'),
          ],
        ),
        content: Text(
          'Kirim notifikasi absensi ke ${siswaDenganHp.length} orang tua '
          'siswa kelas ${widget.kelas} via WhatsApp?\n\n'
          'Notifikasi hanya dikirim SEKALI untuk kelas ini.',
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

    setState(() => _isSendingNotif = true);

    int terkirim = 0;
    int gagal = 0;
    final todayStr = DateFormat('dd/MM/yyyy').format(widget.tanggal);

    final updateDikirimOps = <Future<void>>[];

    for (final siswa in siswaDenganHp) {
      final status = _statusMap[siswa.id] ?? 'alpa';
      final statusLabel = _statusLabel(status);

      final berhasil = await WhatsAppService.kirimNotifikasiRekapAbsensi(
        hpOrtu: siswa.hpOrtu,
        namaSiswa: siswa.nama,
        status: statusLabel,
        tanggal: todayStr,
      );

      if (berhasil) {
        terkirim++;
        // Update dikirim flag pada absensi record
        final existing = _existingAbsensi.where((a) => a.siswaId == siswa.id).firstOrNull;
        if (existing != null && !existing.dikirim) {
          updateDikirimOps.add(_fs.updateAbsensi(existing.id, {'dikirim': true}));
        }
      } else {
        gagal++;
      }
    }

    // Update dikirim flag secara paralel
    if (updateDikirimOps.isNotEmpty) {
      await Future.wait(updateDikirimOps);
    }

    // Mark notification as sent for this class-date
    await _fs.markNotifikasiKelasSent(widget.kelas, widget.tanggal);

    if (!mounted) return;
    setState(() {
      _isSendingNotif = false;
      _notifikasiSent = true;
    });

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
              'Notifikasi telah dikirim ke orang tua siswa.',
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
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kelas ${widget.kelas}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              dateFormat.format(widget.tanggal),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLocked)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Terkunci',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_siswaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 64,
              color: AppColors.muted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada siswa di kelas ini',
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Action Buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Save button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isLocked || _isSaving ? null : _simpanAbsensi,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Lock button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isLocked ? null : _kunciAbsensi,
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_open_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isLocked ? 'Terkunci' : 'Kunci',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isLocked ? AppColors.muted.withValues(alpha: 0.2) : AppColors.warning,
                      foregroundColor:
                          _isLocked ? AppColors.muted : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Notification button
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingNotif || _notifikasiSent
                        ? null
                        : _kirimNotifikasi,
                    icon: _isSendingNotif
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _notifikasiSent
                                ? Icons.check_circle
                                : Icons.send_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isSendingNotif
                          ? 'Mengirim...'
                          : _notifikasiSent
                              ? 'Terkirim'
                              : 'Kirim WA',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _notifikasiSent
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.whatsapp,
                      foregroundColor: _notifikasiSent
                          ? AppColors.success
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Status Panel ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatusPanel(),
        ),

        const SizedBox(height: 4),

        // ── Table Header ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Nama Siswa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              // Status label
              const SizedBox(
                width: 240,
                child: Center(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // ── Student Rows ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: _siswaList.length,
            itemBuilder: (context, index) {
              final siswa = _siswaList[index];
              final activeStatus = _statusMap[siswa.id] ?? 'alpa';
              final statusColor = _statusColor(activeStatus);

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Name + number
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: statusColor.withValues(alpha: 0.12),
                            child: Text(
                              siswa.nama.isNotEmpty
                                  ? siswa.nama[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${index + 1}.',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        siswa.nama,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppColors.foreground,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  siswa.nis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Status Chips ──
                    SizedBox(
                      width: 240,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _statusList.map((s) {
                          final key = s['key'] as String;
                          final shortLabel = s['shortLabel'] as String;
                          final isSelected = activeStatus == key;
                          final color = _statusColor(key);

                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: GestureDetector(
                              onTap: _isLocked
                                  ? null
                                  : () => _setStatus(siswa.id, key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 54,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon(key),
                                        size: 14,
                                        color: isSelected
                                            ? color
                                            : AppColors.muted,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        shortLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? color
                                              : AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
  }

  Widget _buildStatusPanel() {
    final total = _siswaList.length;
    final counts = <String, int>{};
    for (final s in _statusList) {
      counts[s['key'] as String] = 0;
    }
    for (final status in _statusMap.values) {
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Status counts
          ..._statusList.map((s) {
            final key = s['key'] as String;
            final label = s['shortLabel'] as String;
            final count = counts[key] ?? 0;
            final color = _statusColor(key);
            return Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _statusIcon(key),
                    size: 12,
                    color: color,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$label: $count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'T: $total',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
