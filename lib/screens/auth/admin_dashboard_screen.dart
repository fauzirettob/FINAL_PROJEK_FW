import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../models/siswa.dart';
import '../../models/guru.dart';
import '../../models/absensi.dart';
import '../../providers/auth_provider.dart';
import 'manage_admin_screen.dart';
import 'rekap_absensi_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const AdminDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  // ─── Helper: Ambil inisial dari nama ─────────────────────────
  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    final word = parts.isNotEmpty ? parts[0] : '';
    if (word.length <= 2) return word.toUpperCase();
    return word.substring(0, 2).toUpperCase();
  }

  // ─── Upload Foto Profil ─────────────────────────────────────
  Future<void> _uploadFotoProfil() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAdmin) return;
    final admin = auth.admin;
    if (admin == null) return;

    final existingFotoUrl = admin.fotoUrl;

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
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('Foto Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.foreground)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
                ),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Gunakan kamera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Pilih dari Galeri'),
                subtitle: const Text('Ambil dari penyimpanan'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (existingFotoUrl != null && existingFotoUrl.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(width: 48, height: 48,
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
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
    if (source == 'delete') { await _hapusFotoProfil(); return; }

    try {
      final imageSource = source == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? picked = await _picker.pickImage(source: imageSource, imageQuality: 80, maxWidth: 512, maxHeight: 512);
      if (picked == null || !mounted) return;

      ToastService.show(context, message: 'Menyimpan foto...');

      final appDir = await getApplicationDocumentsDirectory();
      final profilDir = Directory('${appDir.path}/profil');
      if (!await profilDir.exists()) await profilDir.create(recursive: true);

      final ext = picked.path.split('.').last;
      final localPath = '${profilDir.path}/${admin.id}.$ext';
      await File(picked.path).copy(localPath);

      await _fs.updateAdmin(admin.id, {'fotoUrl': localPath});
      if (!mounted) return;

      final updatedAdmin = await _fs.getAdmin(admin.id);
      if (updatedAdmin != null && mounted) auth.updateAdmin(updatedAdmin);

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil disimpan!');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(context, message: 'Gagal simpan foto: $e', backgroundColor: Colors.red.shade600, icon: Icons.error_outline);
    }
  }

  // ─── Hapus Foto Profil ───────────────────────────────────────
  Future<void> _hapusFotoProfil() async {
    final auth = context.read<AuthProvider>();
    final admin = auth.admin;
    if (admin == null || admin.fotoUrl == null) return;

    try {
      final localFile = File(admin.fotoUrl!);
      if (await localFile.exists()) await localFile.delete();

      await _fs.updateAdmin(admin.id, {'fotoUrl': null});
      if (!mounted) return;

      final updatedAdmin = await _fs.getAdmin(admin.id);
      if (updatedAdmin != null && mounted) auth.updateAdmin(updatedAdmin);

      if (!mounted) return;
      ToastService.show(context, message: 'Foto profil berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      ToastService.show(context, message: 'Gagal hapus foto: $e', backgroundColor: Colors.red.shade600, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = auth.admin;
    final namaAdmin = admin?.nama ?? 'Admin';
    final sapaan = _getGreeting();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppColors.gradientMain,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$sapaan ☀️",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _uploadFotoProfil,
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: admin?.fotoUrl != null && admin!.fotoUrl!.isNotEmpty
                              ? (admin!.fotoUrl!.startsWith('http')
                                  ? NetworkImage(admin!.fotoUrl!) as ImageProvider
                                  : (File(admin!.fotoUrl!).existsSync()
                                      ? FileImage(File(admin!.fotoUrl!))
                                      : null))
                              : null,
                          child: admin?.fotoUrl == null || admin!.fotoUrl!.isEmpty
                              ? Text(
                                  _getInitials(namaAdmin),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    namaAdmin,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Administrator',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Statistik ──
            StreamBuilder<List<Siswa>>(
              stream: _fs.getSiswaStream(),
              builder: (context, siswaSnapshot) {
                final totalSiswa = siswaSnapshot.data?.length ?? 0;

                return StreamBuilder<List<Guru>>(
                  stream: _getAllGuruStream(),
                  builder: (context, guruSnapshot) {
                    final totalGuru = guruSnapshot.data?.length ?? 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people_alt_rounded,
                            label: 'Total Siswa',
                            value: totalSiswa.toString(),
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.person,
                            label: 'Total Guru',
                            value: totalGuru.toString(),
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            StreamBuilder<List<Absensi>>(
              stream: _fs.getAllAbsensi(),
              builder: (context, snap) {
                final totalAbsensi = snap.data?.length ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.checklist_rounded,
                        label: 'Total Absensi',
                        value: totalAbsensi.toString(),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.calendar_today,
                        label: DateFormat('dd MMM').format(DateTime.now()),
                        value: 'Hari Ini',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Menu Admin ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Menu Admin",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.person_add_alt_1,
              color: AppColors.primary,
              label: "Tambah Data Guru",
              subtitle: "Kelola akun guru",
              onTap: () => _navigateToTab(1),
            ),
            const SizedBox(height: 8),
            _AdminMenuCard(
              icon: Icons.people,
              color: AppColors.accent,
              label: "Tambah Data Siswa",
              subtitle: "Kelola data siswa untuk absensi",
              onTap: () => _navigateToTab(2),
            ),
            const SizedBox(height: 8),
            _AdminMenuCard(
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF8B5CF6),
              label: "Rekap Absensi",
              subtitle: "Lihat rekap per kelas & tanggal",
              onTap: _openRekapAbsensi,
            ),
            const SizedBox(height: 8),
            _AdminMenuCard(
              icon: Icons.manage_search,
              color: AppColors.warning,
              label: "Olah Data",
              subtitle: "Kelola data aplikasi",
              onTap: () => _navigateToTab(3),
            ),
            const SizedBox(height: 8),
            _AdminMenuCard(
              icon: Icons.admin_panel_settings,
              color: Colors.deepOrange,
              label: "Kelola Admin",
              subtitle: "Lihat & kelola admin lain",
              onTap: () => _openManageAdmin(),
            ),
            const SizedBox(height: 8),
            _AdminMenuCard(
              icon: Icons.person,
              color: Colors.deepPurple,
              label: "Profil",
              subtitle: "Lihat informasi akun",
              onTap: () => _navigateToTab(4),
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<Guru>> _getAllGuruStream() {
    // Gunakan stream dari getAllGuru (pakai async*)
    return Stream.fromFuture(_fs.getAllGuru());
  }

  void _navigateToTab(int tabIndex) {
    widget.onNavigateToTab?.call(tabIndex);
  }

  void _openManageAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageAdminScreen()),
    );
  }

  void _openRekapAbsensi() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RekapAbsensiScreen()),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
