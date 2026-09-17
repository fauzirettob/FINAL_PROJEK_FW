import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/jadwal_pelajaran.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations.dart';
import '../../widgets/tilt3d.dart';

/// Layar jadwal pelajaran khusus guru yang sedang login.
///
/// Menampilkan jadwal per hari (Senin–Jumat) berdasarkan `mapelList`
/// dan `kelasList` milik guru, sehingga guru hanya melihat jadwal
/// mengajarnya sendiri dengan info kelas yang jelas.
class JadwalGuruScreen extends StatefulWidget {
  const JadwalGuruScreen({super.key});

  @override
  State<JadwalGuruScreen> createState() => _JadwalGuruScreenState();
}

class _JadwalGuruScreenState extends State<JadwalGuruScreen> {
  /// Hari yang dipilih (default: hari ini)
  late String _selectedHari;

  static const _hariList = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT'];

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
    const hariMap = {
      1: 'SENIN',
      2: 'SELASA',
      3: 'RABU',
      4: 'KAMIS',
      5: 'JUMAT',
    };
    _selectedHari = hariMap[DateTime.now().weekday] ?? 'SENIN';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final guru = auth.guru;
    final namaGuru = guru?.nama ?? 'Guru';
    final mapelList = guru?.mapelList ?? [];
    final kelasList = guru?.kelasList ?? [];

    // Konversi kelasList (10/11/12) ke tingkat (X/XI/XII)
    final Set<String> tingkatSet = {};
    for (final k in kelasList) {
      final tingkat = kelasToTingkat(k);
      if (tingkat != null) tingkatSet.add(tingkat);
    }
    final tingkatList = tingkatSet.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jadwal Mengajar', style: TextStyle(fontSize: 16)),
            Text(
              namaGuru,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Info Guru ──
          _buildGuruInfoHeader(namaGuru, mapelList, tingkatList),

          // ── Hari Selector Chips ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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
                          color: _hariColors[hari]!,
                          onTap: () => setState(() => _selectedHari = hari),
                        ),
                      )),
                ],
              ),
            ),
          ),

          // ── Schedule List ──
          Expanded(
            child: _selectedHari == 'SEMUA'
                ? _buildAllDaysView(mapelList, tingkatList)
                : _buildSingleDayView(
                    _selectedHari, mapelList, tingkatList),
          ),
        ],
      ),
    );
  }

  Widget _buildGuruInfoHeader(
      String namaGuru, List<String> mapelList, List<String> tingkatList) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaGuru,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tingkatList.isNotEmpty
                          ? 'Kelas: ${tingkatList.join(', ')}'
                          : 'Belum ada kelas ditugaskan',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (mapelList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: mapelList.map((m) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Tampilan semua hari: tampilkan per hari secara berurutan
  Widget _buildAllDaysView(List<String> mapelList, List<String> tingkatList) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _hariList.length,
      itemBuilder: (context, index) {
        final hari = _hariList[index];
        final color = _hariColors[hari]!;

        return EntranceAnimation(
          delay: Duration(milliseconds: index * 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Day Header ──
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      hari,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Slots ──
              ..._getSlotsForHari(hari, mapelList, tingkatList)
                  .asMap()
                  .entries
                  .map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _GuruScheduleCard(
                    slotData: entry.value,
                    mapelList: mapelList,
                    tingkatList: tingkatList,
                    color: color,
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Tampilan satu hari
  Widget _buildSingleDayView(
      String hari, List<String> mapelList, List<String> tingkatList) {
    final color = _hariColors[hari]!;
    final slots = _getSlotsForHari(hari, mapelList, tingkatList);

    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                size: 56, color: AppColors.muted.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada jadwal mengajar',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hubungi admin untuk mengatur\nmata pelajaran dan kelas',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        return EntranceAnimation(
          delay: Duration(milliseconds: index * 40),
          child: _GuruScheduleCard(
            slotData: slots[index],
            mapelList: mapelList,
            tingkatList: tingkatList,
            color: color,
          ),
        );
      },
    );
  }

  /// Ambil slot jadwal untuk hari tertentu, difilter berdasarkan
  /// mapel yang diajar guru ini.
  List<Map<String, dynamic>> _getSlotsForHari(
      String hari, List<String> mapelList, List<String> tingkatList) {
    final isJumat = hari == 'JUMAT';
    final rawSlots =
        isJumat ? jadwalDefaultJumat : jadwalDefaultSeninKamis;

    final result = <Map<String, dynamic>>[];

    for (final slot in rawSlots) {
      final keterangan = (slot['keterangan'] as String?) ?? '';
      final lower = keterangan.toLowerCase();
      final isNonPel = lower.contains('istirahat') ||
          lower.contains('ishoma') ||
          lower.contains('apel') ||
          lower.contains('break') ||
          lower.contains('morning') ||
          lower.contains('dhuha') ||
          lower.contains('al-matsurat') ||
          lower.contains('al-kahfi') ||
          lower.contains('lunch');

      // Slot non-pelajaran selalu ditampilkan
      if (isNonPel) {
        result.add({...slot, '_matchedMapel': <String, String>{}});
        continue;
      }

      // Jumat tidak punya mapelPerKelas
      if (isJumat) {
        // Tampilkan semua slot Jumat (kegiatan khusus)
        result.add({...slot, '_matchedMapel': <String, String>{}});
        continue;
      }

      // Cari mapel yang cocok dengan guru ini
      final rawMapelPerKelas = slot['mapelPerKelas'];
      if (rawMapelPerKelas == null) {
        result.add({...slot, '_matchedMapel': <String, String>{}});
        continue;
      }

      final mapelPerKelas =
          Map<String, dynamic>.from(rawMapelPerKelas as Map);
      final matchedMapel = <String, String>{}; // tingkat -> nama mapel

      for (final tingkat in tingkatList) {
        final list = mapelPerKelas[tingkat];
        if (list is List) {
          for (final m in list) {
            final name = m?.toString() ?? '';
            if (mapelList.contains(name)) {
              matchedMapel[tingkat] = name;
              break;
            }
          }
        }
      }

      // Tampilkan slot jika ada mapel yang cocok ATAU jika tidak ada filter
      // (guru masih perlu tahu kapan istirahat)
      result.add({...slot, '_matchedMapel': matchedMapel});
    }

    return result;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
// WIDGET: Guru Schedule Card
// ═══════════════════════════════════════════════════════════════════
class _GuruScheduleCard extends StatelessWidget {
  final Map<String, dynamic> slotData;
  final List<String> mapelList;
  final List<String> tingkatList;
  final Color color;

  const _GuruScheduleCard({
    required this.slotData,
    required this.mapelList,
    required this.tingkatList,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final jamKe = slotData['jamKe'] as int;
    final jamMulai = slotData['jamMulai'] as String;
    final jamSelesai = slotData['jamSelesai'] as String;
    final keterangan = slotData['keterangan'] as String;
    final matchedMapel =
        slotData['_matchedMapel'] as Map<String, String>? ?? {};

    // Cek apakah non-pelajaran
    final lower = keterangan.toLowerCase();
    final isNonPel = lower.contains('istirahat') ||
        lower.contains('ishoma') ||
        lower.contains('apel') ||
        lower.contains('break') ||
        lower.contains('morning') ||
        lower.contains('dhuha') ||
        lower.contains('al-matsurat') ||
        lower.contains('al-kahfi') ||
        lower.contains('lunch');

    final bool hasTeaching = matchedMapel.isNotEmpty;

    return Tilt3D(
      maxTilt: 3,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isNonPel
              ? AppColors.muted.withValues(alpha: 0.04)
              : hasTeaching
                  ? color.withValues(alpha: 0.04)
                  : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNonPel
                ? AppColors.border
                : hasTeaching
                    ? color.withValues(alpha: 0.2)
                    : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Waktu ──
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    if (jamKe > 0)
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: hasTeaching
                              ? color.withValues(alpha: 0.12)
                              : AppColors.muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$jamKe',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: hasTeaching ? color : AppColors.muted,
                              ),
                            ),
                            Text(
                              'Jam',
                              style: TextStyle(
                                fontSize: 6,
                                fontWeight: FontWeight.w600,
                                color: (hasTeaching ? color : AppColors.muted)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getNonPelIcon(keterangan),
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      jamMulai,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      jamSelesai,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Right: Mapel Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Keterangan / keterangan jam
                    Text(
                      keterangan,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isNonPel ? AppColors.muted : color,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Mapel yang diajar guru ini
                    if (hasTeaching)
                      ...matchedMapel.entries.map((entry) {
                        final tingkat = entry.key;
                        final namaMapel = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              // Badge kelas
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tingkat,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Nama mapel
                              Expanded(
                                child: Text(
                                  namaMapel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ),
                              // Badge ✓ Mengajar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '✓',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                    else if (isNonPel)
                      Row(
                        children: [
                          Icon(
                            _getNonPelIcon(keterangan),
                            size: 12,
                            color: AppColors.muted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            keterangan,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Tidak mengajar di jam ini',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.muted.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
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
    if (lower.contains('istirahat') ||
        lower.contains('break') ||
        lower.contains('lunch')) {
      return Icons.coffee_rounded;
    }
    if (lower.contains('ishoma')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('apel')) {
      return Icons.flag_rounded;
    }
    if (lower.contains('dhuha') ||
        lower.contains('al-matsurat') ||
        lower.contains('al-kahfi')) {
      return Icons.auto_stories_rounded;
    }
    if (lower.contains('morning')) {
      return Icons.wb_sunny_rounded;
    }
    return Icons.schedule_rounded;
  }
}
