import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/absensi.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  String? _selectedKelas;
  List<String> _kelasList = [];

  static const _statusOptions = [
    {'value': null, 'label': 'Semua Status'},
    {'value': 'hadir', 'label': 'Hadir'},
    {'value': 'izin', 'label': 'Izin'},
    {'value': 'sakit', 'label': 'Sakit'},
    {'value': 'alpa', 'label': 'Alpa'},
  ];

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKelas() async {
    final snapshot = await _fs.getAllSiswa();
    if (!mounted) return;
    final kelasList = snapshot.map((s) => s.kelas).toSet().toList()..sort();
    setState(() => _kelasList = kelasList);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedStatus = null;
      _selectedKelas = null;
      _searchController.clear();
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_startDate != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedKelas != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  List<Absensi> _applyFilters(List<Absensi> data) {
    var result = data;

    // Filter date range
    if (_startDate != null && _endDate != null) {
      final endEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      result = result.where((a) =>
          a.tanggal.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
          a.tanggal.isBefore(endEnd.add(const Duration(days: 1)))).toList();
    }

    // Filter status
    if (_selectedStatus != null) {
      result = result.where((a) => a.status == _selectedStatus).toList();
    }

    // Filter kelas
    if (_selectedKelas != null) {
      result = result.where((a) => a.kelas == _selectedKelas).toList();
    }

    // Search by name
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((a) =>
          a.siswaNama.toLowerCase().contains(query)).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Absensi"),
        actions: [
          if (_activeFilterCount > 0)
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Hapus filter',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama siswa...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Date range
                      _FilterChip(
                        icon: Icons.date_range,
                        label: _startDate != null
                            ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                            : 'Pilih Tanggal',
                        isActive: _startDate != null,
                        onTap: _pickDateRange,
                      ),
                      const SizedBox(width: 8),
                      // Status
                      _FilterChip(
                        icon: Icons.flag,
                        label: _statusOptions.firstWhere(
                          (o) => o['value'] == _selectedStatus,
                          orElse: () => _statusOptions.first,
                        )['label'] as String,
                        isActive: _selectedStatus != null,
                        onTap: () => _showStatusPicker(),
                      ),
                      const SizedBox(width: 8),
                      // Kelas
                      _FilterChip(
                        icon: Icons.class_,
                        label: _selectedKelas ?? 'Kelas',
                        isActive: _selectedKelas != null,
                        onTap: () => _showKelasPicker(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Data
          Expanded(
            child: StreamBuilder<List<Absensi>>(
              stream: _fs.getAllAbsensi(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 12),
                          Text('Gagal memuat data', style: TextStyle(color: Colors.red[300])),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allData = snapshot.data!;
                final filtered = _applyFilters(allData);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 64, color: AppColors.muted),
                        const SizedBox(height: 16),
                        Text(
                          allData.isEmpty
                              ? 'Belum ada data absensi'
                              : 'Tidak ada hasil dengan filter ini',
                          style: const TextStyle(color: AppColors.muted, fontSize: 15),
                        ),
                        if (allData.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_list_off, size: 18),
                            label: const Text('Reset Filter'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // StreamBuilder will auto-refresh
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildHistoryCard(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Filter Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ..._statusOptions.map((opt) {
              final value = opt['value'];
              final label = opt['label']!;
              final isSelected = _selectedStatus == value;
              return ListTile(
                leading: Icon(
                  value == 'hadir' ? Icons.check_circle :
                  value == 'izin' ? Icons.event_busy :
                  value == 'sakit' ? Icons.sick :
                  value == 'alpa' ? Icons.cancel :
                  Icons.all_inclusive,
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
                title: Text(label),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = value);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showKelasPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Filter Kelas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.all_inclusive, color: _selectedKelas == null ? AppColors.primary : AppColors.muted),
              title: const Text('Semua Kelas'),
              trailing: _selectedKelas == null
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedKelas = null);
                Navigator.pop(ctx);
              },
            ),
            ..._kelasList.map((k) {
              final isSelected = _selectedKelas == k;
              return ListTile(
                leading: Icon(Icons.class_, color: isSelected ? AppColors.primary : AppColors.muted),
                title: Text(k),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedKelas = k);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Absensi a) {
    final statusColors = {
      'hadir': AppColors.success,
      'izin': AppColors.accent,
      'sakit': AppColors.warning,
      'alpa': Colors.red,
    };
    final statusLabels = {
      'hadir': 'Hadir',
      'izin': 'Izin',
      'sakit': 'Sakit',
      'alpa': 'Alpa',
    };
    final color = statusColors[a.status] ?? AppColors.muted;
    final label = statusLabels[a.status] ?? a.status;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Main row with photo and info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Photo
                  GestureDetector(
                    onTap: a.fotoUrl != null && a.fotoUrl!.isNotEmpty
                        ? () => _showPhotoDialog(a.fotoUrl!, a.siswaNama)
                        : null,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.background,
                      ),
                      child: a.fotoUrl != null && a.fotoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                a.fotoUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.broken_image,
                                      color: AppColors.muted, size: 28);
                                },
                              ),
                            )
                          : const Icon(Icons.camera_alt, color: AppColors.muted, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.siswaNama,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.kelas}  •  ${dateFormat.format(a.tanggal)}  •  ${a.jam}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),

                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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

  void _showPhotoDialog(String fotoUrl, String namaSiswa) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                fotoUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Gagal memuat foto', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              namaSiswa,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppColors.primary : AppColors.foreground,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
