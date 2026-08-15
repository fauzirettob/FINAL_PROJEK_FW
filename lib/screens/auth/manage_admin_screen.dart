import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/awesome_dialogs.dart';
import '../../widgets/tilt3d.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';

class ManageAdminScreen extends StatefulWidget {
  /// Boleh di-inject untuk keperluan test; default memakai instance nyata.
  final FirestoreService? firestoreService;

  const ManageAdminScreen({super.key, this.firestoreService});

  @override
  State<ManageAdminScreen> createState() => _ManageAdminScreenState();
}

class _ManageAdminScreenState extends State<ManageAdminScreen> {
  late final FirestoreService _fs =
      widget.firestoreService ?? FirestoreService();
  List<Admin> _admins = [];
  List<Admin> _filteredAdmins = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _searchController.addListener(_filterAdmins);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAdmins);
    _searchController.dispose();
    super.dispose();
  }

  // ─── Load & Filter ──────────────────────────────────────────
  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      // Sinkronkan counter dengan jumlah admin aktual agar halaman login
      // dan firestore.rules ikut akurat. Tidak memblokir pemuatan daftar
      // bila sinkronisasi gagal (mis. gangguan jaringan).
      await _fs.syncAdminCounter().catchError((Object e) {
        debugPrint('Gagal sinkronisasi counter admin: $e');
      });

      final admins = await _fs.getAllAdmin();
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _isLoading = false;
        _updateFilteredList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
      ToastService.show(
        context,
        message: 'Gagal memuat data admin: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  /// Hitung ulang daftar admin yang tampil (tanpa setState — dipanggil
  /// di dalam blok setState milik pemanggil agar tidak setState ganda).
  void _updateFilteredList() {
    final query = _searchController.text.trim().toLowerCase();
    _filteredAdmins = _admins.where((admin) {
      if (query.isEmpty) return true;
      return admin.nama.toLowerCase().contains(query) ||
          admin.email.toLowerCase().contains(query);
    }).toList();
  }

  void _filterAdmins() {
    setState(_updateFilteredList);
  }

  // ─── Hapus admin (langsung dari database) ───────────────────
  Future<void> _confirmDeleteAdmin(Admin admin) async {
    // Jangan izinkan admin menghapus akunnya sendiri. Setelah dokumen admin
    // hilang, user kehilangan status admin sehingga semua operasi admin
    // berikutnya ditolak dengan permission-denied.
    final currentUid = context.read<AuthProvider>().user?.uid;
    if (currentUid != null && admin.id == currentUid) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text('Tidak Bisa Menghapus Akun Sendiri'),
              ),
            ],
          ),
          content: const Text(
            'Anda tidak dapat menghapus akun admin yang sedang dipakai untuk '
            'login.\n\n'
            'Minta admin lain yang menghapus akun ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AwesomeConfirmDialog(
        title: 'Hapus Admin',
        message: 'Apakah Anda yakin ingin menghapus admin '
            '"${admin.nama}" (${admin.email})?\n\n'
            'Dokumen admin akan dihapus permanen dari database. Akun Firebase '
            'Authentication tidak terhapus otomatis dan perlu dihapus manual '
            'dari Firebase Console.',
        icon: Icons.delete_forever_rounded,
        color: Colors.red,
        confirmText: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteAdmin(admin);
    }
  }

  Future<void> _deleteAdmin(Admin admin) async {
    try {
      await _fs.deleteAdmin(admin.id);
      if (!mounted) return;

      // State "hapus berhasil": centang animasi + partikel perayaan.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AwesomeSuccessDialog(
          title: 'Berhasil Dihapus',
          subtitle: '"${admin.nama}" telah dihapus dari database. Akun '
              'Firebase Authentication dapat dihapus manual di Firebase '
              'Console jika diperlukan.',
          confirmText: 'Selesai',
          confirmIcon: Icons.check_rounded,
        ),
      );

      if (mounted) _loadAdmins();
    } catch (e) {
      if (!mounted) return;
      final isPermissionDenied =
          e is FirebaseException && e.code == 'permission-denied';
      ToastService.show(
        context,
        message: isPermissionDenied
            ? 'Gagal menghapus admin: izin ditolak. Pastikan Firestore '
                'security rules yang ter-deploy sudah yang terbaru, atau '
                'minta admin lain yang menghapus.'
            : 'Gagal menghapus admin: $e',
        backgroundColor: Colors.red.shade600,
        icon: Icons.error_outline,
      );
    }
  }

  // ─── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdmins,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Slot Admin Indicator (selalu sinkron dengan daftar admin) ──
          _buildSlotIndicator(),

          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari admin...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Admin List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAdmins.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAdmins,
                        // Animasi masuk dipasang SEKALI di level daftar, bukan
                        // per kartu, agar animasi tidak berulang setiap kali
                        // pengguna mengetik di kotak pencarian.
                        child: EntranceAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: _filteredAdmins.length,
                            itemBuilder: (context, index) {
                              final admin = _filteredAdmins[index];
                              return _AdminCard(
                                admin: admin,
                                isSelf: admin.id ==
                                    context.read<AuthProvider>().user?.uid,
                                onDelete: () => _confirmDeleteAdmin(admin),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Indikator slot admin — dihitung LANGSUNG dari daftar admin yang
  /// dimuat (`_admins.length`), sehingga selalu sinkron dengan jumlah admin
  /// sebenarnya di database (tidak bergantung pada counter yang bisa
  /// tertinggal). Counter tetap disinkronkan di [_loadAdmins] agar halaman
  /// login dan firestore.rules ikut akurat.
  Widget _buildSlotIndicator() {
    const maxSlots = 3;

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Memeriksa slot admin...',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    // Saat pemuatan gagal, jangan tampilkan angka yang menyesatkan (0/3).
    if (_loadFailed) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Gagal memuat slot admin. Tarik ke bawah untuk mencoba lagi.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final count = _admins.length;
    final sisa = maxSlots - count;
    final isOverLimit = count > maxSlots;
    final isFull = count >= maxSlots;

    final Color bgColor = isOverLimit
        ? Colors.red.withValues(alpha: 0.1)
        : isFull
            ? Colors.orange.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1);
    final Color borderColor = isOverLimit
        ? Colors.red.withValues(alpha: 0.3)
        : isFull
            ? Colors.orange.withValues(alpha: 0.3)
            : AppColors.success.withValues(alpha: 0.3);
    final Color fgColor = isOverLimit
        ? Colors.red.shade700
        : isFull
            ? Colors.orange.shade800
            : AppColors.success;
    final IconData icon = isOverLimit
        ? Icons.error_outline
        : isFull
            ? Icons.info_outline
            : Icons.check_circle_outline;

    final String message;
    if (isOverLimit) {
      message = 'Jumlah admin melebihi batas ($count/$maxSlots). Hapus '
          'admin berlebih agar slot kembali normal.';
    } else if (isFull) {
      message = 'Slot admin penuh ($count/$maxSlots). Hapus salah satu '
          'admin untuk membuka slot pendaftaran.';
    } else {
      message = 'Slot admin: $count/$maxSlots terpakai ($sisa slot tersedia)';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fgColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.admin_panel_settings,
            size: 80,
            color: AppColors.muted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? 'Admin tidak ditemukan' : 'Belum ada admin',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Coba kata kunci lain'
                : 'Daftar admin akan muncul di sini',
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Admin admin;
  final bool isSelf;
  final VoidCallback onDelete;

  const _AdminCard({
    required this.admin,
    required this.isSelf,
    required this.onDelete,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return 'A';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                _getInitials(admin.nama),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    admin.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    admin.email,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bergabung ${DateFormat('dd MMM yyyy').format(admin.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Akun sendiri: tidak bisa dihapus, tampilkan label "Anda".
            if (isSelf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text(
                      'Anda',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Hapus admin',
              ),
          ],
        ),
      ),
    );
  }
}
