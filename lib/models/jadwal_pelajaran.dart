/// Model untuk satu slot waktu dalam jadwal pelajaran.
///
/// Setiap slot merepresentasikan satu baris waktu dengan nomor jam ke
/// dan daftar mapel per kelas (X, XI, XII).
class JadwalSlot {
  final String id;
  final int jamKe; // Nomor jam ke (1-13, 0 = aktivitas non-pelajaran)
  final String jamMulai; // Contoh: "07.00"
  final String jamSelesai; // Contoh: "07.30"
  final String keterangan; // Contoh: "Al-Quran", "Istirahat", "Ishoma"

  /// Map kelas -> list mata pelajaran untuk slot ini.
  /// Contoh: {'X': ['B. Inggris', 'B. Arab', 'Sejarah'], 'XI': [...], 'XII': [...]}
  final Map<String, List<String>> mapelPerKelas;

  JadwalSlot({
    required this.id,
    required this.jamKe,
    required this.jamMulai,
    required this.jamSelesai,
    this.keterangan = '',
    this.mapelPerKelas = const {},
  });

  factory JadwalSlot.fromMap(Map<String, dynamic> data, String id) {
    final rawMapel = <String, List<String>>{};
    if (data['mapelPerKelas'] != null) {
      final map = Map<String, dynamic>.from(data['mapelPerKelas']);
      for (final entry in map.entries) {
        if (entry.value is List) {
          final list = entry.value as List;
          rawMapel[entry.key] = list
              .map<String>((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    }
    return JadwalSlot(
      id: id,
      jamKe: data['jamKe'] ?? 0,
      jamMulai: data['jamMulai'] ?? '',
      jamSelesai: data['jamSelesai'] ?? '',
      keterangan: data['keterangan'] ?? '',
      mapelPerKelas: rawMapel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jamKe': jamKe,
      'jamMulai': jamMulai,
      'jamSelesai': jamSelesai,
      'keterangan': keterangan,
      'mapelPerKelas': mapelPerKelas,
    };
  }

  /// Format rentang waktu: "07.00 - 07.30"
  String get rentangWaktu => '$jamMulai - $jamSelesai';

  /// Apakah slot ini adalah aktivitas non-pelajaran
  /// (istirahat, ishoma, apel, dll.)
  bool get isNonPelajaran {
    final lower = keterangan.toLowerCase();
    return lower.contains('istirahat') ||
        lower.contains('ishoma') ||
        lower.contains('apel') ||
        lower.contains('break') ||
        lower.contains('morning') ||
        lower.contains('dhuha') ||
        lower.contains('al-matsurat') ||
        lower.contains('al-kahfi') ||
        lower.contains('lunch');
  }

  /// Apakah slot ini adalah jam pelajaran aktif (nomor jam 1-13)
  bool get isJamPelajaran => jamKe > 0;

  JadwalSlot copyWith({
    int? jamKe,
    String? jamMulai,
    String? jamSelesai,
    String? keterangan,
    Map<String, List<String>>? mapelPerKelas,
  }) {
    return JadwalSlot(
      id: id,
      jamKe: jamKe ?? this.jamKe,
      jamMulai: jamMulai ?? this.jamMulai,
      jamSelesai: jamSelesai ?? this.jamSelesai,
      keterangan: keterangan ?? this.keterangan,
      mapelPerKelas: mapelPerKelas ?? this.mapelPerKelas,
    );
  }
}

/// Model untuk guru piket per hari.
class GuruPiket {
  final String hari;
  final List<String> namaGuru;

  GuruPiket({required this.hari, required this.namaGuru});

  factory GuruPiket.fromMap(Map<String, dynamic> data) {
    return GuruPiket(
      hari: data['hari'] ?? '',
      namaGuru: (data['namaGuru'] as List?)
              ?.map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hari': hari,
      'namaGuru': namaGuru,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════
// JADWAL DEFAULT — Senin s.d. Kamis
// ═══════════════════════════════════════════════════════════════════

const List<Map<String, dynamic>> jadwalDefaultSeninKamis = [
  // ── Aktivitas Pagi (Jam ke-0) ──
  {
    'jamKe': 0,
    'jamMulai': '07.00',
    'jamSelesai': '07.30',
    'keterangan': 'Morning Motivation / Dhuha',
    'mapelPerKelas': {
      'X': ['Al-Matsurat & Asmaul Husna / Dhuha'],
      'XI': ['Al-Matsurat & Asmaul Husna / Dhuha'],
      'XII': ['Al-Matsurat & Asmaul Husna / Dhuha'],
    },
  },
  // ── Jam ke-1 ──
  {
    'jamKe': 1,
    'jamMulai': '07.30',
    'jamSelesai': '08.15',
    'keterangan': 'Al-Quran',
    'mapelPerKelas': {
      'X': ['Al-Quran'],
      'XI': ['Al-Quran'],
      'XII': ['Al-Quran'],
    },
  },
  // ── Jam ke-2 ──
  {
    'jamKe': 2,
    'jamMulai': '08.15',
    'jamSelesai': '09.00',
    'keterangan': 'Al-Quran',
    'mapelPerKelas': {
      'X': ['Al-Quran'],
      'XI': ['Al-Quran'],
      'XII': ['Al-Quran'],
    },
  },
  // ── Jam ke-3 ──
  {
    'jamKe': 3,
    'jamMulai': '09.00',
    'jamSelesai': '09.45',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['B. Inggris', 'B. Arab', 'Sejarah'],
      'XI': ['Kimia', 'Fisika', 'Matek Wajib'],
      'XII': ['B. Indonesia', 'Sejarah', 'B. Inggris'],
    },
  },
  // ── Jam ke-4 (Istirahat) ──
  {
    'jamKe': 4,
    'jamMulai': '09.45',
    'jamSelesai': '10.00',
    'keterangan': 'Istirahat',
    'mapelPerKelas': {},
  },
  // ── Jam ke-5 ──
  {
    'jamKe': 5,
    'jamMulai': '10.00',
    'jamSelesai': '10.45',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['B. Inggris', 'B. Arab', 'PAI'],
      'XI': ['Kimia', 'Fisika', 'Matek Wajib'],
      'XII': ['B. Indonesia', 'Matek Minat', 'B. Inggris'],
    },
  },
  // ── Jam ke-6 ──
  {
    'jamKe': 6,
    'jamMulai': '10.45',
    'jamSelesai': '11.30',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['Matek Wajib', 'Kimia', 'Seni Budaya'],
      'XI': ['Sejarah', 'B. Inggris', 'B. Arab'],
      'XII': ['Biologi', 'Matek Wajib', 'Kimia'],
    },
  },
  // ── Ishoma (Jam ke-7 & ke-8) ──
  {
    'jamKe': 7,
    'jamMulai': '11.30',
    'jamSelesai': '12.15',
    'keterangan': 'Ishoma',
    'mapelPerKelas': {},
  },
  {
    'jamKe': 8,
    'jamMulai': '12.15',
    'jamSelesai': '13.15',
    'keterangan': 'Ishoma',
    'mapelPerKelas': {},
  },
  // ── Jam ke-9 ──
  {
    'jamKe': 9,
    'jamMulai': '13.15',
    'jamSelesai': '14.00',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['B. Arab', 'Mandarin', 'Matek Minat'],
      'XI': ['Matek Minat', 'PAI', 'Fisika'],
      'XII': ['Fisika', 'Biologi', 'B. Arab'],
    },
  },
  // ── Jam ke-10 ──
  {
    'jamKe': 10,
    'jamMulai': '14.00',
    'jamSelesai': '14.45',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['B. Arab', 'Mandarin', 'Matek Minat'],
      'XI': ['Matek Minat', 'PAI', 'Fisika'],
      'XII': ['B. Arab', 'Seni Budaya', 'TKA'],
    },
  },
  // ── Jam ke-11 ──
  {
    'jamKe': 11,
    'jamMulai': '14.45',
    'jamSelesai': '15.15',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['PKn', 'B. Inggris', 'B. Indonesia'],
      'XI': ['B. Inggris', 'PKn', 'B. Indonesia'],
      'XII': ['Seni Budaya', 'B. Indonesia', 'PKn'],
    },
  },
  // ── Jam ke-12 ──
  {
    'jamKe': 12,
    'jamMulai': '15.15',
    'jamSelesai': '15.45',
    'keterangan': 'Pelajaran',
    'mapelPerKelas': {
      'X': ['PKn', 'B. Inggris', 'B. Indonesia'],
      'XI': ['B. Inggris', 'PKn', 'B. Indonesia'],
      'XII': ['Seni Budaya', 'B. Indonesia', 'PKn'],
    },
  },
  // ── Jam ke-13 (Apel Pulang) ──
  {
    'jamKe': 13,
    'jamMulai': '15.45',
    'jamSelesai': '16.00',
    'keterangan': 'Apel Pulang',
    'mapelPerKelas': {},
  },
];

// ═══════════════════════════════════════════════════════════════════
// JADWAL Khusus Hari Jumat
// ═══════════════════════════════════════════════════════════════════

const List<Map<String, dynamic>> jadwalDefaultJumat = [
  {
    'jamKe': 0,
    'jamMulai': '07.00',
    'jamSelesai': '07.30',
    'keterangan': 'Apel / Dhuha',
  },
  {
    'jamKe': 1,
    'jamMulai': '07.30',
    'jamSelesai': '08.00',
    'keterangan': 'Al-Kahfi',
  },
  {
    'jamKe': 2,
    'jamMulai': '08.00',
    'jamSelesai': '09.00',
    'keterangan': 'Karate / Senam',
  },
  {
    'jamKe': 3,
    'jamMulai': '09.00',
    'jamSelesai': '10.00',
    'keterangan': 'Karate / Jumat Bersih',
  },
  {
    'jamKe': 4,
    'jamMulai': '10.00',
    'jamSelesai': '10.30',
    'keterangan': 'Istirahat',
  },
  {
    'jamKe': 5,
    'jamMulai': '10.30',
    'jamSelesai': '12.00',
    'keterangan': 'BPI',
  },
  {
    'jamKe': 6,
    'jamMulai': '12.00',
    'jamSelesai': '13.30',
    'keterangan': "Break / Lunch / Jum'ah",
  },
  {
    'jamKe': 7,
    'jamMulai': '13.30',
    'jamSelesai': '14.30',
    'keterangan': 'Diniyah / OSIS',
  },
  {
    'jamKe': 8,
    'jamMulai': '14.30',
    'jamSelesai': '15.30',
    'keterangan': 'Pramuka',
  },
  {
    'jamKe': 9,
    'jamMulai': '15.30',
    'jamSelesai': '16.00',
    'keterangan': 'Apel Pulang',
  },
];

// ═══════════════════════════════════════════════════════════════════
// GURU PIKET Default
// ═══════════════════════════════════════════════════════════════════

const List<Map<String, dynamic>> guruPiketDefault = [
  {
    'hari': 'SENIN',
    'namaGuru': ['Fadly Latutuapraya, S.Pd', 'Mintarsih, S.Pd'],
  },
  {
    'hari': 'SELASA',
    'namaGuru': ['Sudarmaji Halian, M.Pd'],
  },
  {
    'hari': 'RABU',
    'namaGuru': ['Sri Wahyuni Hasan, M.Pd', 'Sarakiyah Keliwouw, S.Pd'],
  },
  {
    'hari': 'KAMIS',
    'namaGuru': ['Fatimah, S.H', 'Fitriyani Rizal, S.Pd'],
  },
  {
    'hari': 'JUMAT',
    'namaGuru': ['Elisabeth Riberu, S.Pd', 'Nurul Annisa H. Umar, S.S'],
  },
];

/// Daftar kelas yang tersedia untuk jadwal.
const List<String> daftarKelasJadwal = ['X', 'XI', 'XII'];

// ═══════════════════════════════════════════════════════════════════
// MAPPING: Kelas Siswa (kategoriKelas) -> Tingkat Jadwal (X/XI/XII)
// ═══════════════════════════════════════════════════════════════════

/// Mapping dari kelas siswa (10, 11, 12) ke tingkat jadwal (X, XI, XII).
String? kelasToTingkat(String kelas) {
  final trimmed = kelas.trim();
  if (trimmed == '10') return 'X';
  if (trimmed == '11') return 'XI';
  if (trimmed == '12') return 'XII';
  return null;
}

/// Mengambil semua mata pelajaran unik untuk satu tingkat (X/XI/XII)
/// berdasarkan jadwal Senin-Kamis.
List<String> getMapelByTingkat(String tingkat) {
  final Set<String> allMapel = {};
  for (final slot in jadwalDefaultSeninKamis) {
    final rawMap = slot['mapelPerKelas'];
    final mapelPerKelas = rawMap != null ? Map<String, dynamic>.from(rawMap) : null;
    if (mapelPerKelas != null && mapelPerKelas.containsKey(tingkat)) {
      final list = mapelPerKelas[tingkat];
      if (list is List) {
        for (final m in list) {
          final name = m?.toString() ?? '';
          if (name.isNotEmpty) allMapel.add(name);
        }
      }
    }
  }
  return allMapel.toList()..sort();
}

/// Mengambil semua mata pelajaran unik untuk kelas siswa tertentu
/// (contoh: 'IPA I' -> mapel untuk tingkat X).
List<String> getMapelByKelas(String kelas) {
  final tingkat = kelasToTingkat(kelas);
  if (tingkat == null) return [];
  return getMapelByTingkat(tingkat);
}

/// Mengambil semua mata pelajaran unik dari beberapa kelas
/// (digunakan saat guru mengajar beberapa kelas).
List<String> getMapelByMultipleKelas(List<String> kelasList) {
  final Set<String> allMapel = {};
  for (final kelas in kelasList) {
    allMapel.addAll(getMapelByKelas(kelas));
  }
  return allMapel.toList()..sort();
}

/// Mapping nama hari Indonesia ke nama hari jadwal (uppercase).
String? hariToJadwalKey(String hari) {
  final map = {
    'Senin': 'SENIN',
    'Selasa': 'SELASA',
    'Rabu': 'RABU',
    'Kamis': 'KAMIS',
    'Jumat': 'JUMAT',
  };
  return map[hari];
}

// ═══════════════════════════════════════════════════════════════════
// JADWAL TIME LOOKUP — Untuk validasi waktu absensi
// ═══════════════════════════════════════════════════════════════════

/// Informasi jadwal waktu untuk sebuah mata pelajaran di tingkat tertentu.
class JadwalMapelInfo {
  final String mataPelajaran;
  final String tingkat;
  final int jamKe;
  final String jamMulai; // Contoh: "09.00"
  final String jamSelesai; // Contoh: "09.45"
  final String keterangan; // Contoh: "Pelajaran"

  const JadwalMapelInfo({
    required this.mataPelajaran,
    required this.tingkat,
    required this.jamKe,
    required this.jamMulai,
    required this.jamSelesai,
    this.keterangan = 'Pelajaran',
  });

  /// Format rentang waktu: "09.00 - 09.45"
  String get rentangWaktu => '$jamMulai - $jamSelesai';

  @override
  String toString() => '$mataPelajaran ($tingkat) jam $jamMulai-$jamSelesai';
}

/// Mengambil jadwal waktu untuk mata pelajaran tertentu di tingkat tertentu.
///
/// Mengembalikan list karena satu mapel bisa muncul di beberapa slot waktu
/// (misalnya B. Inggris di jam ke-3 dan jam ke-5).
///
/// Contoh:
/// ```dart
/// final jadwal = getJadwalMapelByTingkat('X', 'B. Inggris');
/// // => [JadwalMapelInfo(jamKe:3, jamMulai:'09.00', jamSelesai:'09.45'), ...]
/// ```
List<JadwalMapelInfo> getJadwalMapelByTingkat(
    String tingkat, String mataPelajaran) {
  final result = <JadwalMapelInfo>[];
  for (final slot in jadwalDefaultSeninKamis) {
    final rawMap = slot['mapelPerKelas'];
    final mapelPerKelas =
        rawMap != null ? Map<String, dynamic>.from(rawMap) : null;
    if (mapelPerKelas != null && mapelPerKelas.containsKey(tingkat)) {
      final list = mapelPerKelas[tingkat];
      if (list is List) {
        final names = list
            .map<String>((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.contains(mataPelajaran)) {
          result.add(JadwalMapelInfo(
            mataPelajaran: mataPelajaran,
            tingkat: tingkat,
            jamKe: slot['jamKe'] ?? 0,
            jamMulai: slot['jamMulai'] ?? '',
            jamSelesai: slot['jamSelesai'] ?? '',
            keterangan: slot['keterangan'] ?? 'Pelajaran',
          ));
        }
      }
    }
  }
  return result;
}

/// Mengambil jadwal waktu untuk mata pelajaran berdasarkan kelas siswa
/// (contoh: '10' -> tingkat 'X').
List<JadwalMapelInfo> getJadwalMapelByKelas(
    String kelas, String mataPelajaran) {
  final tingkat = kelasToTingkat(kelas);
  if (tingkat == null) return [];
  return getJadwalMapelByTingkat(tingkat, mataPelajaran);
}

/// Cek apakah waktu sekarang masih dalam rentang jadwal untuk mapel tertentu.
///
/// Mengembalikan true jika absensi boleh dilakukan (waktu sekarang
/// masih <= jam selesai jadwal mapel).
bool isWaktuAbsensiValid(JadwalMapelInfo jadwal) {
  final now = DateTime.now();
  // Parse jam selesai dari format "HH.mm"
  final parts = jadwal.jamSelesai.split('.');
  if (parts.length != 2) return false;
  final jam = int.tryParse(parts[0]) ?? 0;
  final menit = int.tryParse(parts[1]) ?? 0;
  final jamSelesai = DateTime(now.year, now.month, now.day, jam, menit);
  // Beri toleransi 15 menit setelah jam selesai
  final batasAkhir = jamSelesai.add(const Duration(minutes: 15));
  return now.isBefore(batasAkhir);
}

/// Mengambil semua slot jadwal untuk kelas tertentu yang berisi mapel
/// (bukan istirahat/ishoma), dikembalikan sebagai JadwalMapelInfo.
List<JadwalMapelInfo> getAllJadwalMapelByTingkat(String tingkat) {
  final result = <JadwalMapelInfo>[];
  for (final slot in jadwalDefaultSeninKamis) {
    if (slot['jamKe'] == 0) continue; // Skip aktivitas non-pelajaran
    final rawMap = slot['mapelPerKelas'];
    final mapelPerKelas =
        rawMap != null ? Map<String, dynamic>.from(rawMap) : null;
    if (mapelPerKelas != null && mapelPerKelas.containsKey(tingkat)) {
      final list = mapelPerKelas[tingkat];
      if (list is List) {
        final names = list
            .map<String>((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        for (final name in names) {
          result.add(JadwalMapelInfo(
            mataPelajaran: name,
            tingkat: tingkat,
            jamKe: slot['jamKe'] ?? 0,
            jamMulai: slot['jamMulai'] ?? '',
            jamSelesai: slot['jamSelesai'] ?? '',
            keterangan: slot['keterangan'] ?? 'Pelajaran',
          ));
        }
      }
    }
  }
  return result;
}
