import 'package:cloud_firestore/cloud_firestore.dart';

/// Daftar mata pelajaran yang tersedia di aplikasi.
const List<String> daftarMataPelajaran = [
  // Agama
  "Al-Qur'an Hadits",
  'Fiqih',
  'Aqidah',
  'Bahasa Arab',
  'Sejarah Kebudayaan Islam',
  // Umum
  'Matematika',
  'Bahasa Indonesia',
  'Bahasa Inggris',
  'PPKn',
  'PJOK',
  'Seni Budaya',
  'Prakarya',
  'Informatika',
  // IPA
  'IPA (Fisika)',
  'IPA (Biologi)',
  'IPA (Kimia)',
  // IPS
  'IPS (Sejarah)',
  'IPS (Geografi)',
  'IPS (Ekonomi)',
  // Tambahan (Jadwal)
  'Karate',
  'Ekstrakurikuler',
  'BPI',
];

/// Daftar nama hari dalam seminggu (Senin–Jumat).
const List<String> daftarHari = [
  'SENIN',
  'SELASA',
  'RABU',
  'KAMIS',
  'JUMAT',
];

/// Kategori mata pelajaran untuk tampilan berkelompok.
const Map<String, List<String>> kategoriMapel = {
  'Agama': [
    "Al-Qur'an Hadits",
    'Fiqih',
    'Aqidah',
    'Bahasa Arab',
    'Sejarah Kebudayaan Islam',
  ],
  'Umum': [
    'Matematika',
    'Bahasa Indonesia',
    'Bahasa Inggris',
    'PPKn',
    'PJOK',
    'Seni Budaya',
    'Prakarya',
    'Informatika',
  ],
  'IPA': [
    'IPA (Fisika)',
    'IPA (Biologi)',
    'IPA (Kimia)',
  ],
  'IPS': [
    'IPS (Sejarah)',
    'IPS (Geografi)',
    'IPS (Ekonomi)',
  ],
  'Lainnya': [
    'Karate',
    'Ekstrakurikuler',
    'BPI',
  ],
};

/// Warna per kategori untuk UI.
const Map<String, int> kategoriMapelColors = {
  'Agama': 0xFF2E7D32, // Hijau
  'Umum': 0xFF1565C0,  // Biru
  'IPA': 0xFF7B1FA2,   // Ungu
  'IPS': 0xFFE65100,   // Oranye
  'Lainnya': 0xFF00695C, // Teal
};

class Absensi {
  final String id;
  final String siswaId;
  final String siswaNama;
  final String kelas;
  final String mataPelajaran;
  final DateTime tanggal;
  final String status; // hadir, izin, sakit, alpa
  final String jam;
  final bool dikirim;
  final String guruId;
  final String? fotoUrl;

  Absensi({
    required this.id,
    required this.siswaId,
    required this.siswaNama,
    required this.kelas,
    this.mataPelajaran = '',
    required this.tanggal,
    required this.status,
    required this.jam,
    this.dikirim = false,
    required this.guruId,
    this.fotoUrl,
  });

  factory Absensi.fromMap(Map<String, dynamic> data, String id) {
    return Absensi(
      id: id,
      siswaId: data['siswaId'] ?? '',
      siswaNama: data['siswaNama'] ?? '',
      kelas: data['kelas'] ?? '',
      mataPelajaran: data['mataPelajaran'] ?? '',
      tanggal: data['tanggal'] is Timestamp
          ? (data['tanggal'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'alpa',
      jam: data['jam'] ?? '',
      dikirim: data['dikirim'] == true,
      guruId: data['guruId'] ?? '',
      fotoUrl: data['fotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'siswaId': siswaId,
      'siswaNama': siswaNama,
      'kelas': kelas,
      'mataPelajaran': mataPelajaran,
      'tanggal': Timestamp.fromDate(tanggal),
      'status': status,
      'jam': jam,
      'dikirim': dikirim,
      'guruId': guruId,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
    };
  }
}
