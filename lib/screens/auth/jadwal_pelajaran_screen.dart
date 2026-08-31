import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../services/firestore_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';

class JadwalPelajaranScreen extends StatefulWidget {
  const JadwalPelajaranScreen({super.key});

  @override
  State<JadwalPelajaranScreen> createState() => _JadwalPelajaranScreenState();
}

class _JadwalPelajaranScreenState extends State<JadwalPelajaranScreen>
    with SingleTickerProviderStateMixin {
  late final FirestoreService _fs = FirestoreService();
  late TabController _tabController;

  bool _isLoading = true;

  /// Slot jadwal Senin-Kamis
  List<JadwalSlot> _slotUtama = [];

  /// Slot jadwal Jumat
  List<JadwalSlot> _slotJumat = [];

  /// Data guru piket
  List<GuruPiket> _guruPiket = [];

  /// Hari aktif yang dipilih (untuk filter tampilan)
  String _selectedHari = 'SENIN';

  static const _hariList = ['SENIN', 'SELASA', 'RABU', 'KAMIS'];
  static const _hariColors = {
    'SENIN': Color(0xFF6366F1),
    'SELASA': Color(0xFF8B5CF6),
    'RABU': Color(0xFFEC4899),
    'KAMIS': Color(0xFFF97316),
    'JUMAT': Color(0xFF14B8A6),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load dari Firestore
      final slots = await _fs.getJadwalSlot();
      final piket = await _fs.getGuruPiket();

      if (slots.isEmpty) {
        // Gunakan default
        _initDefaultData();
      } else {
        _slotUtama = slots;
      }

      // Selalu isi slot Jumat dari default jika kosong
      // (Jumat tidak punya mapel per kelas, jadwalnya statis)
      if (_slotJumat.isEmpty) {
        _slotJumat = jadwalDefaultJumat
            .map((d) => JadwalSlot.fromMap(d, 'jumat_${d['jamKe']}'))
            .toList();
      }

      if (piket.isEmpty) {
        _guruPiket = guruPiketDefault
            .map((d) => GuruPiket.fromMap(d))
            .toList();
      } else {
        _guruPiket = piket;
      }
    } catch (e) {
      debugPrint('Gagal memuat jadwal: $e');
      _initDefaultData();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _initDefaultData() {
    _slotUtama = jadwalDefaultSeninKamis
        .map((d) => JadwalSlot.fromMap(d, '${d['jamKe']}'))
        .toList();
    _slotJumat = jadwalDefaultJumat
        .map((d) => JadwalSlot.fromMap(d, 'jumat_${d['jamKe']}'))
        .toList();
    _guruPiket = guruPiketDefault
        .map((d) => GuruPiket.fromMap(d))
        .toList();
  }

  Color _getHariColor(String hari) => _hariColors[hari] ?? AppColors.primary;

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pelajaran'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Senin - Kamis'),
            Tab(text: 'Jumat'),
            Tab(text: 'Guru Piket'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabSeninKamis(),
                _buildTabJumat(),
                _buildTabGuruPiket(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: JADWAL SENIN-KAMIS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabSeninKamis() {
    return Column(
      children: [
        // ── Hari Selector Chips ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // "Semua" chip
              _HariChip(
                label: 'Semua',
                isSelected: _selectedHari == 'SEMUA',
                color: AppColors.primary,
                onTap: () => setState(() => _selectedHari = 'SEMUA'),
              ),
              const SizedBox(width: 6),
              ..._hariList.map((hari) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _HariChip(
                      label: hari.substring(0, 3),
                      isSelected: _selectedHari == hari,
                      color: _getHariColor(hari),
                      onTap: () => setState(() => _selectedHari = hari),
                    ),
                  )),
            ],
          ),
        ),

        // ── Schedule List ──
        Expanded(
          child: _selectedHari == 'SEMUA'
              ? _buildSemuaHariView()
              : _buildSingleHariView(_selectedHari),
        ),
      ],
    );
  }

  /// Tampilan Semua Hari (Senin-Kamis side by side)
  Widget _buildSemuaHariView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _slotUtama.length,
      itemBuilder: (context, index) {
        final slot = _slotUtama[index];
        return EntranceAnimation(
          delay: Duration(milliseconds: index * 40),
          child: _SlotRowMultiDay(
            slot: slot,
            hariList: _hariList,
            hariColors: _hariColors,
          ),
        );
      },
    );
  }

  /// Tampilan Satu Hari (detail per hari)
  Widget _buildSingleHariView(String hari) {
    final color = _getHariColor(hari);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _slotUtama.length,
      itemBuilder: (context, index) {
        final slot = _slotUtama[index];
        final mapelHari = slot.mapelPerKelas[hari];

        return EntranceAnimation(
          delay: Duration(milliseconds: index * 40),
          child: _SlotCardSingleDay(
            slot: slot,
            hari: hari,
            color: color,
            mapelList: mapelHari,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: JADWAL JUMAT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTabJumat() {
    final color = _hariColors['JUMAT']!;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _slotJumat.length,
      itemBuilder: (context, index) {
        final slot = _slotJumat[index];
        return EntranceAnimation(
          delay: Duration(milliseconds: index * 50),
          child: _JumatSlotCard(slot: slot, color: color),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3: GURU PIKET
  // ═══════════════════════════════════════════════════════════════

  /// Nama hari ini dalam format uppercase (SENIN, SELASA, dll.)
  String get _hariIni {
    const hariMap = {
      1: 'SENIN',
      2: 'SELASA',
      3: 'RABU',
      4: 'KAMIS',
      5: 'JUMAT',
      6: 'SABTU',
      7: 'MINGGU',
    };
    return hariMap[DateTime.now().weekday] ?? 'SENIN';
  }

  Widget _buildTabGuruPiket() {
    // Filter hanya guru piket hari ini
    final piketHariIni = _guruPiket
        .where((p) => p.hari.toUpperCase() == _hariIni)
        .toList();

    if (piketHariIni.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded,
                size: 64, color: AppColors.muted.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              'Tidak ada guru piket $_hariIni',
              style: const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: piketHariIni.length,
      itemBuilder: (context, index) {
        final piket = piketHariIni[index];
        final color = _getHariColor(piket.hari);

        return EntranceAnimation(
          delay: Duration(milliseconds: index * 80),
          child: _GuruPiketCard(piket: piket, color: color),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Hari Chip
// ═══════════════════════════════════════════════════════════════════

class _HariChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _HariChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Slot Row Multi-Hari (Semua Hari view)
// ═══════════════════════════════════════════════════════════════════

class _SlotRowMultiDay extends StatelessWidget {
  final JadwalSlot slot;
  final List<String> hariList;
  final Map<String, Color> hariColors;

  const _SlotRowMultiDay({
    required this.slot,
    required this.hariList,
    required this.hariColors,
  });

  @override
  Widget build(BuildContext context) {
    final isNonPel = slot.isNonPelajaran;

    return Tilt3D(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isNonPel
              ? AppColors.muted.withValues(alpha: 0.04)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNonPel ? AppColors.border : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Waktu + Jam Ke ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isNonPel
                    ? AppColors.muted.withValues(alpha: 0.06)
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  // Waktu
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isNonPel
                          ? AppColors.muted.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${slot.jamMulai} - ${slot.jamSelesai}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isNonPel ? AppColors.muted : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Keterangan
                  Expanded(
                    child: Text(
                      slot.keterangan,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isNonPel
                            ? AppColors.muted
                            : AppColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Jam ke badge
                  if (slot.isJamPelajaran)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Jam ${slot.jamKe}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Grid Mapel per Hari ──
            if (!isNonPel && slot.mapelPerKelas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: hariList.map((hari) {
                    final color = hariColors[hari] ?? AppColors.primary;
                    final mapelList = slot.mapelPerKelas[hari];

                    return Expanded(
                      child: _DayColumn(
                        hari: hari,
                        color: color,
                        mapelList: mapelList,
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Non-pelajaran indicator ──
            if (isNonPel)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      _getNonPelIcon(slot.keterangan),
                      size: 14,
                      color: AppColors.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      slot.keterangan,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted.withValues(alpha: 0.7),
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

  IconData _getNonPelIcon(String keterangan) {
    final lower = keterangan.toLowerCase();
    if (lower.contains('istirahat') || lower.contains('break') || lower.contains('lunch')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('ishoma')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('apel')) {
      return Icons.flag_rounded;
    }
    if (lower.contains('dhuha') || lower.contains('al-matsurat') || lower.contains('al-kahfi')) {
      return Icons.auto_stories_rounded;
    }
    if (lower.contains('morning')) {
      return Icons.wb_sunny_rounded;
    }
    return Icons.schedule_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Day Column (dalam multi-day view)
// ═══════════════════════════════════════════════════════════════════

class _DayColumn extends StatelessWidget {
  final String hari;
  final Color color;
  final List<String>? mapelList;

  const _DayColumn({
    required this.hari,
    required this.color,
    this.mapelList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Hari label
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            hari.substring(0, 3),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Mapel list
        if (mapelList != null && mapelList!.isNotEmpty)
          ...mapelList!.map((m) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground.withValues(alpha: 0.8),
                    height: 1.2,
                  ),
                ),
              ))
        else
          Text(
            '-',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.muted.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Slot Card Single Day (detail view per hari)
// ═══════════════════════════════════════════════════════════════════

class _SlotCardSingleDay extends StatelessWidget {
  final JadwalSlot slot;
  final String hari;
  final Color color;
  final List<String>? mapelList;

  const _SlotCardSingleDay({
    required this.slot,
    required this.hari,
    required this.color,
    this.mapelList,
  });

  @override
  Widget build(BuildContext context) {
    final isNonPel = slot.isNonPelajaran;

    return Tilt3D(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isNonPel
              ? AppColors.muted.withValues(alpha: 0.04)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNonPel
                ? AppColors.border
                : color.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Waktu + Jam Ke ──
              SizedBox(
                width: 68,
                child: Column(
                  children: [
                    // Jam ke
                    if (slot.isJamPelajaran)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${slot.jamKe}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              'Jam',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: color.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getNonPelIcon(slot.keterangan),
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      slot.jamMulai,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      slot.jamSelesai,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Right: Mapel Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Keterangan
                    Text(
                      slot.keterangan,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isNonPel ? AppColors.muted : color,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Mapel per kelas
                    if (mapelList != null && mapelList!.isNotEmpty)
                      ...mapelList!.asMap().entries.map((entry) {
                        final kelas = daftarKelasJadwal[entry.key.clamp(0, daftarKelasJadwal.length - 1)];
                        final mapel = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  kelas,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  mapel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.foreground
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else if (isNonPel)
                      Text(
                        slot.keterangan,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted.withValues(alpha: 0.7),
                        ),
                      )
                    else
                      Text(
                        'Tidak ada jadwal',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNonPelIcon(String keterangan) {
    final lower = keterangan.toLowerCase();
    if (lower.contains('istirahat') || lower.contains('break') || lower.contains('lunch')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('ishoma')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('apel')) {
      return Icons.flag_rounded;
    }
    if (lower.contains('dhuha') || lower.contains('al-matsurat') || lower.contains('al-kahfi')) {
      return Icons.auto_stories_rounded;
    }
    if (lower.contains('morning')) {
      return Icons.wb_sunny_rounded;
    }
    return Icons.schedule_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Jumat Slot Card
// ═══════════════════════════════════════════════════════════════════

class _JumatSlotCard extends StatelessWidget {
  final JadwalSlot slot;
  final Color color;

  const _JumatSlotCard({required this.slot, required this.color});

  @override
  Widget build(BuildContext context) {
    final isNonPel = slot.isNonPelajaran;

    return Tilt3D(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isNonPel
              ? AppColors.muted.withValues(alpha: 0.04)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNonPel ? AppColors.border : color.withValues(alpha: 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Waktu ──
              SizedBox(
                width: 68,
                child: Column(
                  children: [
                    if (slot.isJamPelajaran)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${slot.jamKe}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              'Jam',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: color.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIcon(slot.keterangan),
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      slot.jamMulai,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      slot.jamSelesai,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ── Right: Kegiatan ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isNonPel
                            ? AppColors.muted.withValues(alpha: 0.08)
                            : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        slot.keterangan,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isNonPel ? AppColors.muted : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String keterangan) {
    final lower = keterangan.toLowerCase();
    if (lower.contains('apel') && lower.contains('dhuha')) return Icons.flag_rounded;
    if (lower.contains('al-kahfi')) return Icons.auto_stories_rounded;
    if (lower.contains('karate') || lower.contains('senam')) return Icons.sports_martial_arts_rounded;
    if (lower.contains('jumat bersih') || lower.contains('cleaning')) return Icons.cleaning_services_rounded;
    if (lower.contains('istirahat') || lower.contains('break') || lower.contains('lunch')) return Icons.coffee_rounded;
    if (lower.contains("jum'ah") || lower.contains('jumah')) return Icons.mosque_rounded;
    if (lower.contains('diniyah') || lower.contains('osis')) return Icons.school_rounded;
    if (lower.contains('pramuka')) return Icons.outdoor_grill_rounded;
    if (lower.contains('bpi')) return Icons.star_rounded;
    if (lower.contains('apel pulang')) return Icons.flag_rounded;
    return Icons.schedule_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGET: Guru Piket Card
// ═══════════════════════════════════════════════════════════════════

class _GuruPiketCard extends StatelessWidget {
  final GuruPiket piket;
  final Color color;

  const _GuruPiketCard({required this.piket, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tilt3D(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.08),
              color.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Hari Badge ──
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: color,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piket.hari,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...piket.namaGuru.map(
                      (nama) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          nama,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Count badge ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${piket.namaGuru.length} guru',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
