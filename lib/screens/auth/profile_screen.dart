import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_scheduler.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifEnabled = false;
  int _notifHour = 14;
  int _notifMinute = 0;
  String? _notifKelas;
  List<String> _kelasList = [];
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadKelasList();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationScheduler.getSettings();
      if (mounted) {
        setState(() {
          _notifEnabled = settings.enabled;
          _notifHour = settings.hour;
          _notifMinute = settings.minute;
          _notifKelas = settings.kelas;
          _isLoadingSettings = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal load settings notifikasi: $e');
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _loadKelasList() async {
    try {
      final siswaList = await FirestoreService().getAllSiswa();
      final kelas = siswaList.map((s) => s.kelas).toSet().toList()..sort();
      if (mounted) {
        setState(() => _kelasList = kelas);
      }
    } catch (e) {
      debugPrint('Gagal load daftar kelas: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await NotificationScheduler.saveSettings(
        enabled: _notifEnabled,
        hour: _notifHour,
        minute: _notifMinute,
        kelas: _notifKelas,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _notifEnabled
                  ? '✅ Notifikasi otomatis diaktifkan (${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}${_notifKelas != null ? ' — Kelas $_notifKelas' : ''})'
                  : '⏸ Notifikasi otomatis dimatikan',
            ),
            backgroundColor: _notifEnabled ? AppColors.success : AppColors.muted,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal simpan settings notifikasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
      helpText: 'Pilih jam pengiriman notifikasi',
      cancelText: 'Batal',
      confirmText: 'Simpan',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _notifHour = picked.hour;
        _notifMinute = picked.minute;
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final nama = isAdmin ? auth.admin?.nama : auth.guru?.nama;
    final email = isAdmin ? auth.admin?.email : auth.guru?.email;
    final createdAt = isAdmin ? auth.admin?.createdAt : auth.guru?.createdAt;
    final roleLabel = isAdmin ? 'Administrator' : 'Guru';
    final initials = isAdmin ? 'A' : 'G';

    final displayNama = nama ?? roleLabel;
    final displayEmail = email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Gradient Header with Avatar ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.gradientMain,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  // Avatar lingkaran dengan inisial
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      displayNama.isNotEmpty ? _getInitials(displayNama) : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayNama,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAdmin
                            ? Colors.amber.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.person,
                          size: 14,
                          color: isAdmin ? Colors.amber : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          roleLabel,
                          style: TextStyle(
                            color: isAdmin ? Colors.amber : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (createdAt != null)
                    Text(
                      'Bergabung ${DateFormat('dd MMM yyyy').format(createdAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Info Akun ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Info Akun',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _InfoCard(
              icon: Icons.badge_outlined,
              label: 'Nama Lengkap',
              value: displayNama,
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: displayEmail.isNotEmpty ? displayEmail : '-',
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
              label: 'Role',
              value: roleLabel,
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.calendar_today,
              label: 'Tanggal Bergabung',
              value: createdAt != null
                  ? DateFormat('dd MMMM yyyy').format(createdAt)
                  : '-',
            ),

            const SizedBox(height: 24),

            // --- Notifikasi Otomatis ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notifikasi Otomatis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoadingSettings)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // ── Toggle Aktifkan ──
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _notifEnabled
                                ? AppColors.whatsapp.withValues(alpha: 0.1)
                                : AppColors.muted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.send_to_mobile,
                            color: _notifEnabled ? AppColors.whatsapp : AppColors.muted,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rekap Absensi Harian',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.foreground,
                                ),
                              ),
                              Text(
                                _notifEnabled
                                    ? 'Dikirim setiap ${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}${_notifKelas != null ? ' (Kelas $_notifKelas)' : ''}'
                                    : 'Notifikasi otomatis sedang mati',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notifEnabled,
                          activeTrackColor: AppColors.whatsapp.withValues(alpha: 0.5),
                          activeThumbColor: AppColors.whatsapp,
                          onChanged: (v) async {
                            setState(() => _notifEnabled = v);
                            await _saveSettings();
                          },
                        ),
                      ],
                    ),

                    if (_notifEnabled) ...[
                      const Divider(height: 24),

                      // ── Pilih Jam ──
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.schedule,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Jam Pengiriman',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_calendar, color: AppColors.accent, size: 18),
                            ],
                          ),
                        ),
                      ),

                      // ── Filter Kelas ──
                      if (_kelasList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showKelasPicker(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.class_,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Filter Kelas',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.foreground,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _notifKelas ?? 'Semua Kelas',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _notifKelas != null
                                          ? AppColors.primary
                                          : AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (_notifKelas != null) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() => _notifKelas = null);
                                      await _saveSettings();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down, color: AppColors.muted, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.whatsapp.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.whatsapp.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.whatsapp.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _notifEnabled
                                  ? 'Notifikasi akan dikirim setiap hari pukul ${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')} ke nomor WhatsApp orang tua siswa.'
                                  : 'Aktifkan untuk mengirim rekap absensi harian ke orang tua siswa via WhatsApp secara otomatis.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.whatsapp.withValues(alpha: 0.7),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // --- Tentang ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tentang',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text('Tentang Aplikasi'),
              subtitle: const Text('Versi 1.0.0'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Absensi Siswa',
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      'Aplikasi Absensi Siswa dengan Notifikasi WhatsApp',
                );
              },
            ),

            const SizedBox(height: 32),

            // --- Logout Button ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Keluar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'G';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showKelasPicker() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pilih Kelas'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, null),
              child: Row(
                children: [
                  Icon(
                    _notifKelas == null ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18,
                    color: _notifKelas == null ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(width: 12),
                  const Text('Semua Kelas'),
                ],
              ),
            ),
            ..._kelasList.map((kelas) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, kelas),
                  child: Row(
                    children: [
                      Icon(
                        _notifKelas == kelas
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: _notifKelas == kelas ? AppColors.primary : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Text(kelas),
                    ],
                  ),
                )),
          ],
        );
      },
    );

    if (result != _notifKelas) {
      setState(() => _notifKelas = result);
      await _saveSettings();
    }
  }
}


class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
