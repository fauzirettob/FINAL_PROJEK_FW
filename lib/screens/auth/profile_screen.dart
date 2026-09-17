import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/notification_scheduler.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/awesome_dialogs.dart';
import '../../widgets/tilt3d.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();

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
      final siswaList = await _fs.getAllSiswa();
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
        ToastService.show(
          context,
          message: _notifEnabled
              ? '✅ Notifikasi otomatis diaktifkan (${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}${_notifKelas != null ? ' — Kelas $_notifKelas' : ''})'
              : '⏸ Notifikasi otomatis dimatikan',
        );
      }
    } catch (e) {
      debugPrint('Gagal simpan settings notifikasi: $e');
      if (mounted) {
        ToastService.show(
          context,
          message: 'Gagal menyimpan pengaturan: $e',
          backgroundColor: Colors.red.shade600,
          icon: Icons.error_outline,
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

  // ─── Upload Foto Profil ─────────────────────────────────────
  Future<void> _uploadFotoProfil() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final admin = auth.admin;
    final guru = auth.guru;

    if (!isAdmin && guru == null) return;
    if (isAdmin && admin == null) return;

    final userId = isAdmin ? admin!.id : guru!.id;
    final existingFotoUrl = isAdmin ? admin?.fotoUrl : guru?.fotoUrl;

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Foto Profil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
                ),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Gunakan kamera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Ambil dari penyimpanan'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (existingFotoUrl != null && existingFotoUrl.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Hapus Foto'),
                  subtitle: const Text('Kembali ke inisial'),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    if (source == 'delete') {
      await _hapusFotoProfil();
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      ToastService.show(context, message: 'Upload foto belum didukung di web', backgroundColor: Colors.orange.shade600, icon: Icons.info_outline);
      return;
    }

    try {
      final imageSource = source == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? picked = await _picker.pickImage(
        source: imageSource,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (picked == null || !mounted) return;

      ToastService.show(context, message: 'Menyimpan foto...');

      final appDir = await getApplicationDocumentsDirectory();
      final profilDir = Directory('${appDir.path}/profil');
      if (!await profilDir.exists()) {
        await profilDir.create(recursive: true);
      }

      final ext = picked.path.split('.').last;
      final localPath = '${profilDir.path}/$userId.$ext';
      await File(picked.path).copy(localPath);

      if (isAdmin) {
        await _fs.updateAdmin(userId, {'fotoUrl': localPath});
      } else {
        await _fs.updateGuru(userId, {'fotoUrl': localPath});
      }

      if (!mounted) return;

      if (isAdmin) {
        final updatedAdmin = await _fs.getAdmin(userId);
        if (updatedAdmin != null && mounted) {
          auth.updateAdmin(updatedAdmin);
        }
      } else {
        final updatedGuru = await _fs.getGuru(userId);
        if (updatedGuru != null && mounted) {
          auth.updateGuru(updatedGuru);
        }
      }

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil disimpan!');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal simpan foto: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── Hapus Foto Profil ───────────────────────────────────────
  Future<void> _hapusFotoProfil() async {
    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;

    if (isAdmin) {
      final admin = auth.admin;
      if (admin == null || admin.fotoUrl == null) return;
      await _hapusFotoInternal(admin.id, admin.fotoUrl!, isAdmin: true);
    } else {
      final guru = auth.guru;
      if (guru == null || guru.fotoUrl == null) return;
      await _hapusFotoInternal(guru.id, guru.fotoUrl!, isAdmin: false);
    }
  }

  Future<void> _hapusFotoInternal(String userId, String fotoUrl, {required bool isAdmin}) async {
    final auth = context.read<AuthProvider>();

    try {
      if (!kIsWeb) {
        try {
          final localFile = File(fotoUrl);
          if (await localFile.exists()) {
            await localFile.delete();
          }
        } catch (_) {}
      }

      if (isAdmin) {
        await _fs.updateAdmin(userId, {'fotoUrl': null});
      } else {
        await _fs.updateGuru(userId, {'fotoUrl': null});
      }

      if (!mounted) return;

      if (isAdmin) {
        final updatedAdmin = await _fs.getAdmin(userId);
        if (updatedAdmin != null && mounted) {
          auth.updateAdmin(updatedAdmin);
        }
      } else {
        final updatedGuru = await _fs.getGuru(userId);
        if (updatedGuru != null && mounted) {
          auth.updateGuru(updatedGuru);
        }
      }

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal hapus foto: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── Ubah Password ────────────────────────────────────────
  Future<void> _changePassword() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.55,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_reset_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ubah Password',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              'Masukkan password baru Anda',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
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
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Password Baru
                        const Text('Password Baru', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          decoration: InputDecoration(
                            hintText: 'Masukan password baru',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setModalState(() => obscureNew = !obscureNew),
                            ),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
                            if (v.length < 6) return 'Password minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Konfirmasi Password
                        const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            hintText: 'Ulangi password baru',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                              onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                            ),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Konfirmasi tidak boleh kosong';
                            if (v != newPasswordController.text) return 'Password tidak cocok';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isLoading = true);
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Ubah Password',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    final newPassword = newPasswordController.text.trim();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('changeMyPassword');
      await callable.call({
        'newPassword': newPassword,
      });
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Password berhasil diubah!',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: e.message ?? 'Gagal mengubah password',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        context,
        message: 'Gagal mengubah password: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
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

    final fotoUrl = isAdmin ? auth.admin?.fotoUrl : auth.guru?.fotoUrl;
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
                  // Avatar lingkaran — klik untuk ganti foto
                  GestureDetector(
                    onTap: _uploadFotoProfil,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                          ? (fotoUrl.startsWith('http')
                              ? NetworkImage(fotoUrl) as ImageProvider
                              : (!kIsWeb && File(fotoUrl).existsSync()
                                  ? FileImage(File(fotoUrl))
                                  : null))
                          : null,
                      child: fotoUrl == null || fotoUrl.isEmpty
                          ? Text(
                              displayNama.isNotEmpty ? _getInitials(displayNama) : initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
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

            // --- Ubah Password ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ubah Password',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _changePassword,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text(
                  'Ubah Password',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
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
      barrierDismissible: false,
      builder: (ctx) => AwesomeConfirmDialog(
        title: 'Keluar',
        message: 'Apakah Anda yakin ingin keluar dari aplikasi?',
        icon: Icons.logout_rounded,
        color: Colors.red,
        confirmText: 'Keluar',
        confirmIcon: Icons.logout_rounded,
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
    return Tilt3D(
      child: Container(
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
      ),
    );
  }
}
