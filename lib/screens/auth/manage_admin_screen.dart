import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/admin.dart';

class ManageAdminScreen extends StatefulWidget {
  const ManageAdminScreen({super.key});

  @override
  State<ManageAdminScreen> createState() => _ManageAdminScreenState();
}

class _ManageAdminScreenState extends State<ManageAdminScreen> {
  late final FirestoreService _fs = FirestoreService();
  List<Admin> _admins = [];
  List<Admin> _filteredAdmins = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _searchController.addListener(_filterAdmins);
  }

  Stream<int> _adminCountStream() {
    return _fs.getAdminCountStream();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAdmins);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      // Sinkronkan counter dengan jumlah admin aktual
      await _fs.syncAdminCounter();

      final admins = await _fs.getAllAdmin();
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _filterAdmins();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data admin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterAdmins() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredAdmins = List.from(_admins);
      } else {
        _filteredAdmins = _admins.where((admin) {
          return admin.nama.toLowerCase().contains(query) ||
              admin.email.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _confirmDeleteAdmin(Admin admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Hapus Admin'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus admin "${admin.nama}" (${admin.email})?\n\n'
          'Dokumen admin akan dihapus dari database. Akun Firebase Authentication tidak akan '
          'terhapus secara otomatis dan perlu dihapus manual dari Firebase Console.',
        ),
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
            child: const Text('Hapus'),
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin "${admin.nama}" berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAdmins();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus admin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
          // ── Slot Admin Indicator ──
          StreamBuilder<int>(
            stream: _adminCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              final maxSlots = 3;
              final sisa = maxSlots - count;
              final isFull = count >= maxSlots;

              return Container(
                margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isFull
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFull
                        ? Colors.orange.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFull ? Icons.info_outline : Icons.check_circle_outline,
                      size: 20,
                      color: isFull ? Colors.orange : AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFull
                            ? 'Slot admin penuh ($count/$maxSlots). Hapus salah satu admin untuk membuka slot pendaftaran.'
                            : 'Slot admin: $count/$maxSlots terpakai ($sisa slot tersedia)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isFull ? Colors.orange.shade800 : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

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
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: _filteredAdmins.length,
                          itemBuilder: (context, index) {
                            final admin = _filteredAdmins[index];
                            return _AdminCard(
                              admin: admin,
                              onDelete: () => _confirmDeleteAdmin(admin),
                            );
                          },
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
  final VoidCallback onDelete;

  const _AdminCard({
    required this.admin,
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
    return Container(
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
                Icon(Icons.admin_panel_settings, size: 12, color: AppColors.primary),
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

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: onDelete,
            tooltip: 'Hapus admin',
          ),
        ],
      ),
    );
  }
}
